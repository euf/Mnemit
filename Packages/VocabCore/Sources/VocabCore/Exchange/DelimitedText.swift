import Foundation

/// Tables as delimiter-separated text (CSV, TSV), for exchanging cards with
/// spreadsheets and other apps.
public enum DelimitedText {
    public enum Delimiter: Character, CaseIterable, Sendable {
        case comma = ","
        case semicolon = ";"
        case tab = "\t"

        /// How the `#separator` header line of Anki names it.
        var ankiName: String {
            switch self {
            case .comma: "comma"
            case .semicolon: "semicolon"
            case .tab: "tab"
            }
        }

        /// The delimiter that a `#separator` value names, by name or as the character itself.
        init?(ankiValue: String) {
            let value = ankiValue.lowercased()
            guard let delimiter = Self.allCases.first(where: { $0.ankiName == value || String($0.rawValue) == value }) else { return nil }
            self = delimiter
        }
    }

    /// The rows as text, following RFC 4180 with the given delimiter: fields
    /// containing the delimiter, a quote or a line break are enclosed in quotes, with
    /// quotes inside doubled. Every row ends with CRLF.
    ///
    /// With `ankiColumns`, the text starts with the header lines that Anki reads from a text
    /// file: `#separator`, `#html:false` and `#columns` with those names. Anki then imports
    /// the rows as they are. The rows must not hold a header row of their own, as Anki would
    /// take it for a note.
    public static func encode(_ rows: [[String]], delimiter: Delimiter, ankiColumns: [String]? = nil) -> String {
        let body =
            rows.map { row in
                row.map { quoted($0, delimiter: delimiter) }.joined(separator: String(delimiter.rawValue))
            }
            .joined(separator: "\r\n") + (rows.isEmpty ? "" : "\r\n")
        guard let ankiColumns else { return body }
        let columns = ankiColumns.map { quoted($0, delimiter: delimiter) }.joined(separator: String(delimiter.rawValue))
        return "#separator:\(delimiter.ankiName)\r\n#html:false\r\n#columns:\(columns)\r\n" + body
    }

    /// The rows of a text file, with its encoding and delimiter detected.
    ///
    /// The encoding is UTF-16 if the data starts with its byte order mark, otherwise
    /// UTF-8 if the data is valid UTF-8, otherwise Latin-1 (see `text(of:)`). A UTF-8
    /// byte order mark is skipped. See `detectedDelimiter(in:)` for the delimiter.
    /// Empty lines are left out.
    ///
    /// Lines at the top that start with `#` are Anki's header lines, and no rows. A
    /// `#separator` that names one of our delimiters decides it, and `#columns` gives
    /// `columns`, the names of the fields of a row; `nil` if there is no such line.
    public static func decode(_ data: Data) -> (rows: [[String]], delimiter: Delimiter, columns: [String]?) {
        let (headers, text) = headerLines(of: self.text(of: data))
        let delimiter = headers["separator"].flatMap(Delimiter.init(ankiValue:)) ?? detectedDelimiter(in: text)
        let columns = headers["columns"].flatMap { parse($0, delimiter: delimiter).first }
        return (parse(text, delimiter: delimiter), delimiter, columns)
    }

    /// The `#key:value` lines at the top of `text`, the key in lower case and the value as it
    /// stands, and the text after them. A line that starts with `#` and has no colon is a
    /// comment, which Anki ignores as well.
    private static func headerLines(of text: String) -> (headers: [String: String], rest: String) {
        var headers: [String: String] = [:]
        var rest = Substring(text)
        while rest.first == "#" {
            let end = rest.firstIndex { $0.isNewline } ?? rest.endIndex
            let line = rest[rest.index(after: rest.startIndex)..<end]
            if let colon = line.firstIndex(of: ":") {
                let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                headers[key] = headers[key] ?? String(line[line.index(after: colon)...])
            }
            rest = rest[end...].drop { $0.isNewline }
        }
        return (headers, String(rest))
    }

    /// Latin-1 is read as Windows-1252, as Excel on Windows writes it: the same
    /// characters, plus € and typographic quotes where Latin-1 has control characters.
    private static func text(of data: Data) -> String {
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]),
            let text = String(data: data, encoding: .utf16)
        {
            return text
        }
        let utf8 = data.starts(with: [0xEF, 0xBB, 0xBF]) ? data.dropFirst(3) : data
        return String(data: utf8, encoding: .utf8)
            ?? String(data: data, encoding: .windowsCP1252)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
    }

    /// The delimiter that splits the first rows most evenly: the one under which the
    /// most of them have the same number of fields, at least two. Ties go to tab,
    /// then semicolon, then comma, as tabs and semicolons rarely appear in vocabulary.
    public static func detectedDelimiter(in text: String) -> Delimiter {
        let sample = String(text.prefix(20_000))
        var best = (delimiter: Delimiter.comma, score: 0)
        for delimiter in [Delimiter.tab, .semicolon, .comma] {
            let counts = parse(sample, delimiter: delimiter).prefix(20).map(\.count).filter { $0 >= 2 }
            let mostCommon = Dictionary(counts.map { ($0, 1) }, uniquingKeysWith: +).values.max() ?? 0
            if mostCommon > best.score {
                best = (delimiter, mostCommon)
            }
        }
        return best.delimiter
    }

    /// Splits `text` into rows and fields following RFC 4180, accepting any line break.
    /// Lenient with malformed input: a quote inside an unquoted field is kept as is,
    /// and text after a closing quote is appended to the field.
    public static func parse(_ text: String, delimiter: Delimiter) -> [[String]] {
        let separator = delimiter.rawValue.unicodeScalars.first!
        var rows: [[String]] = []
        var row: [String] = []
        var field = String.UnicodeScalarView()
        var inQuotes = false
        var atFieldStart = true
        var scalars = text.unicodeScalars.makeIterator()
        var pending = scalars.next()

        func endField() {
            row.append(String(field))
            field = String.UnicodeScalarView()
            atFieldStart = true
        }

        func endRow() {
            endField()
            if row != [""] {
                rows.append(row)
            }
            row = []
        }

        while let scalar = pending {
            pending = scalars.next()
            if inQuotes {
                if scalar == "\"" {
                    if pending == "\"" {
                        field.append("\"")
                        pending = scalars.next()
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(scalar)
                }
                continue
            }
            switch scalar {
            case "\"" where atFieldStart:
                inQuotes = true
                atFieldStart = false
            case separator:
                endField()
            case "\r":
                if pending == "\n" {
                    pending = scalars.next()
                }
                endRow()
            case "\n":
                endRow()
            default:
                field.append(scalar)
                atFieldStart = false
            }
        }
        if !field.isEmpty || !row.isEmpty || inQuotes {
            endRow()
        }
        return rows
    }

    private static func quoted(_ field: String, delimiter: Delimiter) -> String {
        let needsQuotes = field.contains { $0 == delimiter.rawValue || $0 == "\"" || $0.isNewline }
        guard needsQuotes else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
