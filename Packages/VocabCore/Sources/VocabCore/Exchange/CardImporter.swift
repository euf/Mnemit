import Foundation

/// Turns the rows of a table (see `DelimitedText`) into new cards for a deck.
///
/// The columns are question, answer and optional hint, unless the names of the columns say
/// otherwise: a `columns` list, or a header row, may name `Question` or `Front`, `Answer` or
/// `Back`, `Hint`, `Word Key` and `Kind` (`recognition` or `production`), which is what our
/// export writes. Further columns, such as the learning state of an export, are ignored.
/// Fields are trimmed. Rows without a question or an answer are skipped.
public enum CardImporter {
    public enum Duplicate: Hashable, Sendable {
        /// The deck already has a card with this question.
        case inDeck
        /// An earlier card of the file, with this question and answer, has the same question.
        case inFile(question: String, answer: String)
    }

    public struct Candidate: Identifiable, Sendable {
        public var card: Card
        public var duplicate: Duplicate?

        public var id: Card.ID { card.id }
    }

    public struct Result: Sendable {
        public var candidates: [Candidate]
        /// Rows left out because their question or answer is empty.
        public var skippedRows: Int
    }

    /// Where each part of a card is in a row.
    struct Layout {
        var question = 0
        var answer = 1
        var hint: Int? = 2
        var note: Int?
        var kind: Int?

        /// The columns the `names` give, by their English names in any case; what they leave
        /// out stays where a file without names has it.
        init(names: [String]?) {
            guard let names else { return }
            func index(_ titles: String...) -> Int? {
                names.firstIndex { name in titles.contains { $0.caseInsensitiveCompare(name.trimmingCharacters(in: .whitespaces)) == .orderedSame } }
            }
            question = index("Question", "Front") ?? 0
            answer = index("Answer", "Back") ?? 1
            note = index("Word Key")
            kind = index("Kind")
            // The hint takes its usual third place unless a column of ours has it.
            hint = index("Hint") ?? (note == 2 || kind == 2 ? nil : 2)
        }
    }

    /// - Parameters:
    ///   - existing: The cards of the deck, to mark duplicates.
    ///   - isHeader: Whether the first row is a header rather than a card. Its names, like
    ///     `columns`, say which column is which.
    ///   - created: The creation date of the new cards.
    ///   - columns: The names of the columns, from the `#columns` line of a file, see
    ///     `DelimitedText.decode(_:)`. Then the first row is a card, as in Anki.
    public static func candidates(
        from rows: [[String]], existing: [Card], isHeader: ([String]) -> Bool, created: Date, columns: [String]? = nil
    ) -> Result {
        var result = Result(candidates: [], skippedRows: 0)
        let inDeck = Set(existing.map { CardText.key(forQuestion: $0.question) })
        // The first card of each question in the file.
        var inFile: [String: Card] = [:]
        let header = columns == nil ? rows.first.flatMap { isHeader($0) ? $0 : nil } : nil
        let layout = Layout(names: columns ?? header)

        for (index, row) in rows.enumerated() {
            if index == 0, header != nil { continue }
            func field(_ column: Int?) -> String { column.flatMap { row.indices.contains($0) ? row[$0] : nil } ?? "" }
            guard row.count >= 2, let text = CardText(question: field(layout.question), answer: field(layout.answer), hint: field(layout.hint)) else {
                result.skippedRows += 1
                continue
            }
            let note = Card.normalized(field(layout.note))
            // A kind belongs to a word key.
            let kind = note == nil ? nil : CardKind(rawValue: field(layout.kind).trimmingCharacters(in: .whitespaces).lowercased())
            let card = Card(text: text, note: note, kind: kind, created: created)
            let key = CardText.key(forQuestion: card.question)
            let duplicate: Duplicate? = inDeck.contains(key) ? .inDeck : inFile[key].map { .inFile(question: $0.question, answer: $0.answer) }
            inFile[key] = inFile[key] ?? card
            result.candidates.append(Candidate(card: card, duplicate: duplicate))
        }
        return result
    }
}
