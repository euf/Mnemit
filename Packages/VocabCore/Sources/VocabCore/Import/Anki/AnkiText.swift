import Foundation

/// Reduces the HTML of an Anki field to plain text.
///
/// - Tags are dropped; `<br>` becomes a line break, and so does the start or end of a
///   block (`div`, `p`, `li`, headings, table rows), unless the text is at a line break
///   already.
/// - Entities are decoded: the common named ones and every numeric one.
/// - `<img>` and `[sound:…]` are removed and reported, so the caller can count fields that
///   lose media; `mediaReferences(in:)` lists the files they name.
/// - Non-breaking spaces become spaces; the result has no surrounding whitespace.
enum AnkiText {
    static func plain(_ html: String) -> (text: String, hadMedia: Bool) {
        let input = Array(html.unicodeScalars)
        var output = String.UnicodeScalarView()
        var hadMedia = false
        var index = 0

        func lineBreak(always: Bool) {
            if always || (!output.isEmpty && output.last != "\n") { output.append("\n") }
        }

        while index < input.count {
            let scalar = input[index]
            if scalar == "<", index + 1 < input.count, input[index + 1].properties.isAlphabetic || "/!".unicodeScalars.contains(input[index + 1]) {
                // Anki escapes a literal "<" as "&lt;", so a "<" before a letter opens a tag.
                guard let close = input[index...].firstIndex(of: ">") else {
                    output.append(scalar)
                    index += 1
                    continue
                }
                let name = String(String.UnicodeScalarView(input[(index + 1)..<close].drop { $0 == "/" }.prefix { $0.properties.isAlphabetic || ("0"..."9").contains($0) })).lowercased()
                switch name {
                case "img": hadMedia = true
                case "br": lineBreak(always: true)
                case "div", "p", "li", "ul", "ol", "tr", "table", "h1", "h2", "h3", "h4", "h5", "h6": lineBreak(always: false)
                default: break
                }
                index = close + 1
            } else if scalar == "[", let end = soundEnd(in: input, at: index) {
                hadMedia = true
                index = end
            } else if scalar == "&", let (decoded, end) = entity(in: input, at: index) {
                output.append(decoded)
                index = end
            } else {
                output.append(scalar)
                index += 1
            }
        }
        let text = String(output).replacingOccurrences(of: "\u{00A0}", with: " ")
        return (CardText.trimmed(text), hadMedia)
    }

    /// A file a field refers to: the `src` of an `<img>`, or the name in `[sound:…]`.
    struct MediaReference: Equatable {
        enum Kind { case image, sound }
        var kind: Kind
        /// As the field has it, with the entities of HTML decoded; Anki may have percent-encoded it.
        var name: String
    }

    private static let tag = try! NSRegularExpression(pattern: #"<img\b[^>]*>"#, options: .caseInsensitive)
    private static let source = try! NSRegularExpression(pattern: #"\ssrc\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>"']+))"#, options: .caseInsensitive)
    private static let sound = try! NSRegularExpression(pattern: #"\[sound:([^\]]*)\]"#)

    /// The images and sounds `html` refers to, in the order they stand.
    static func mediaReferences(in html: String) -> [MediaReference] {
        let whole = NSRange(html.startIndex..., in: html)
        var found: [(position: Int, reference: MediaReference)] = []
        for match in tag.matches(in: html, range: whole) {
            guard let source = source.firstMatch(in: html, range: match.range),
                let name = (1...3).lazy.compactMap({ Range(source.range(at: $0), in: html) }).first.map({ String(html[$0]) })
            else { continue }
            found.append((match.range.location, MediaReference(kind: .image, name: decoded(name))))
        }
        for match in sound.matches(in: html, range: whole) {
            guard let range = Range(match.range(at: 1), in: html) else { continue }
            found.append((match.range.location, MediaReference(kind: .sound, name: decoded(String(html[range])))))
        }
        return found.sorted { $0.position < $1.position }.map(\.reference)
    }

    /// `text` with the entities of HTML decoded, as in a field.
    private static func decoded(_ text: String) -> String {
        guard text.contains("&") else { return text }
        let input = Array(text.unicodeScalars)
        var output = String.UnicodeScalarView()
        var index = 0
        while index < input.count {
            if input[index] == "&", let (scalar, end) = entity(in: input, at: index) {
                output.append(scalar)
                index = end
            } else {
                output.append(input[index])
                index += 1
            }
        }
        return String(output)
    }

    /// The index after `[sound:…]` starting at `index`, if there is one.
    private static func soundEnd(in input: [Unicode.Scalar], at index: Int) -> Int? {
        let prefix = Array("[sound:".unicodeScalars)
        guard index + prefix.count <= input.count, zip(prefix, input[index...]).allSatisfy({ $0 == $1 }) else { return nil }
        return input[index...].firstIndex(of: "]").map { $0 + 1 }
    }

    private static let named: [String: Unicode.Scalar] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
        "hellip": "…", "ndash": "–", "mdash": "—", "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”",
        "laquo": "«", "raquo": "»", "euro": "€", "copy": "©", "middot": "·", "times": "×",
    ]

    /// The scalar of the entity at `index` and the index after it. `nil` for anything
    /// that isn't a known entity; the "&" then stays as it is.
    private static func entity(in input: [Unicode.Scalar], at index: Int) -> (Unicode.Scalar, Int)? {
        // The longest entity worth decoding is "&#x10FFFF;".
        guard let semicolon = input[(index + 1)..<min(index + 11, input.count)].firstIndex(of: ";") else { return nil }
        let body = String(String.UnicodeScalarView(input[(index + 1)..<semicolon]))
        if body.hasPrefix("#") {
            let digits = body.dropFirst()
            let code = digits.first == "x" || digits.first == "X" ? UInt32(digits.dropFirst(), radix: 16) : UInt32(digits)
            return code.flatMap(Unicode.Scalar.init).map { ($0, semicolon + 1) }
        }
        return named[body].map { ($0, semicolon + 1) }
    }
}
