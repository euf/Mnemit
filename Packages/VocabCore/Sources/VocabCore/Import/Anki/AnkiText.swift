import Foundation

/// Reduces the HTML of an Anki field to plain text.
///
/// - Tags are dropped; `<br>` becomes a line break, and so does the start or end of a
///   block (`div`, `p`, `li`, headings, table rows), unless the text is at a line break
///   already.
/// - Entities are decoded: the common named ones and every numeric one.
/// - `<img>` and `[sound:…]` are removed and reported, so the caller can count fields that
///   lose media.
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
