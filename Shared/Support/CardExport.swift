import Foundation
import UniformTypeIdentifiers
import VocabCore

/// The cards of a deck as CSV or TSV that Anki imports as it is, on the Mac ("Export
/// Cards…") and on the iPhone (the share sheet of the deck screen).
///
/// The file starts with Anki's header lines, `#separator`, `#html:false` and `#columns`, see
/// `DelimitedText.encode(_:delimiter:ankiColumns:)`, and has no header row. The columns are
/// question, answer, hint, word key and kind, then optionally the learning state in readable
/// form, which Anki has no use for. `CardImport` reads the file back, so a deck can go to
/// Anki and come back.
enum CardExport {
    enum Format: String, CaseIterable {
        case csv, tsv

        var contentType: UTType {
            switch self {
            case .csv: .commaSeparatedText
            case .tsv: .tabSeparatedText
            }
        }

        var delimiter: DelimitedText.Delimiter {
            switch self {
            case .csv: .comma
            case .tsv: .tab
            }
        }

        var title: String {
            switch self {
            case .csv: String(localized: "CSV (comma-separated)")
            case .tsv: String(localized: "TSV (tab-separated)")
            }
        }
    }

    /// The names of the columns, the same in every language, so that Anki and the import
    /// of any language know them. Front and Back are the names of the fields of Anki's
    /// basic note types, which lets its import dialog map the first two columns by itself.
    /// With the learning state, three columns follow: the maturity, the study day the card
    /// is due on and the number of reviews.
    static func columns(includingLearningState: Bool) -> [String] {
        ["Front", "Back", "Hint", "Word Key", "Kind"] + (includingLearningState ? ["Maturity", "Due", "Reviews"] : [])
    }

    /// One row per card, in the order of `columns(includingLearningState:)`. The kind is
    /// `recognition` or `production` and is empty for a card without a word key; the due
    /// day is ISO 8601 and empty for new cards.
    static func rows(of cards: [Card], includingLearningState: Bool, calendar: StudyCalendar) -> [[String]] {
        cards.map { card in
            var row = [card.question, card.answer, card.hint, card.note ?? "", card.kind?.rawValue ?? ""]
            if includingLearningState {
                let due = card.learningState.map { CivilDate(dayNumber: calendar.dayNumber(for: $0.due)).isoString }
                row += [MaturityCategory(card: card).title, due ?? "", String(card.learningState?.reviews ?? 0)]
            }
            return row
        }
    }

    /// The file contents: UTF-8 with a byte order mark, which spreadsheets such as Excel
    /// need to recognise the encoding, and which Anki skips.
    static func data(of cards: [Card], format: Format, includingLearningState: Bool, calendar: StudyCalendar) -> Data {
        let rows = rows(of: cards, includingLearningState: includingLearningState, calendar: calendar)
        let text = DelimitedText.encode(rows, delimiter: format.delimiter, ankiColumns: columns(includingLearningState: includingLearningState))
        return Data(("\u{FEFF}" + text).utf8)
    }
}
