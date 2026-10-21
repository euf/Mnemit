import Foundation
import VocabCore

/// A problem with the input or the deck, reported to the user as it is.
public struct SyncError: Error, CustomStringConvertible {
    public var description: String

    public init(_ description: String) {
        self.description = description
    }
}

/// One row of a note TSV: a card of a word (`note`), asked in one direction (`kind`).
public struct SyncRow: Equatable, Sendable {
    public var note: String
    public var kind: CardKind
    public var text: CardText
    /// The row's number in the file, counting the header as 1, for messages.
    public var number: Int

    /// What identifies the card across runs.
    public var key: String { SyncRow.key(note: note, kind: kind) }

    public static func key(note: String, kind: CardKind) -> String {
        "\(SyncRow.normalized(note))|\(kind.rawValue)"
    }

    /// Notes are compared trimmed and in composed Unicode form, so a Greek word typed
    /// with a combining accent equals the precomposed one.
    public static func normalized(_ note: String) -> String {
        CardText.trimmed(note).precomposedStringWithCanonicalMapping
    }
}

/// What a TSV holds.
public enum SyncInput: Equatable, Sendable {
    /// `note⇥kind⇥question⇥answer⇥hint` under a header.
    case notes([SyncRow])
    /// The older headerless `question⇥answer⇥hint`, in the format of File → Import Cards.
    case plain([[String]])
}

public enum TSVReader {
    /// The columns of the header, `hint` optional.
    static let header = ["note", "kind", "question", "answer"]

    /// Reads a note TSV if its first row is the header, otherwise the plain
    /// question/answer/hint table with its delimiter detected like the Mac app does.
    ///
    /// In a note TSV the delimiter is the tab, and `\n` in a field means a line break.
    ///
    /// - Throws: `SyncError` listing every bad row of a note TSV.
    public static func read(_ data: Data) throws -> SyncInput {
        var text = String(decoding: data, as: UTF8.self)
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        let firstLine = text.prefix { !$0.isNewline }
        let columns = firstLine.split(separator: "\t", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        guard columns.count >= header.count, Array(columns.prefix(header.count)) == header else {
            return .plain(DelimitedText.decode(data).rows)
        }

        var rows: [SyncRow] = []
        var problems: [String] = []
        var seen: [String: Int] = [:]
        for (index, cells) in DelimitedText.parse(text, delimiter: .tab).enumerated().dropFirst() {
            let number = index + 1
            let cells = cells + Array(repeating: "", count: max(0, 5 - cells.count))
            let note = SyncRow.normalized(cells[0])
            guard !note.isEmpty else {
                problems.append("row \(number): empty note")
                continue
            }
            guard let kind = CardKind(rawValue: CardText.trimmed(cells[1]).lowercased()) else {
                problems.append("row \(number): kind must be recognition or production, not “\(CardText.trimmed(cells[1]))”")
                continue
            }
            guard let text = CardText(question: unescaped(cells[2]), answer: unescaped(cells[3]), hint: unescaped(cells[4])) else {
                problems.append("row \(number): empty question or answer")
                continue
            }
            let row = SyncRow(note: note, kind: kind, text: text, number: number)
            if let first = seen[row.key] {
                problems.append("row \(number): \(note) \(kind.rawValue) already in row \(first)")
                continue
            }
            seen[row.key] = number
            rows.append(row)
        }
        guard problems.isEmpty else {
            throw SyncError(problems.joined(separator: "\n"))
        }
        return .notes(rows)
    }

    /// `\n` as the two characters backslash and n stands for a line break.
    static func unescaped(_ field: String) -> String {
        field.replacingOccurrences(of: "\\n", with: "\n")
    }
}
