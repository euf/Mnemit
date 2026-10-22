import Foundation
import Observation
import VocabCore

/// "Import Cards…" on both platforms: reads cards from a CSV or TSV file, or an Anki package
/// (`CardImport+Anki.swift`), into a preview, from which the chosen cards are appended to the
/// open deck. The Mac asks for the file with an open panel, the iPhone with the file picker;
/// the preview and its rules are the same.
///
/// A file of our own export, or one that Anki wrote, starts with header lines (see
/// `DelimitedText.decode(_:)`) that name the columns: `CardImporter` finds the word key and
/// the kind among them.
@MainActor
enum CardImport {
    /// The cards of a file, before they are added to the deck.
    @Observable
    final class Preview: Identifiable {
        let fileName: String
        let candidates: [CardImporter.Candidate]
        let skippedRows: Int
        /// What an Anki package brought and left out; `nil` for a CSV or TSV file.
        let anki: AnkiSummary?
        /// The cards to add; duplicates start out unselected.
        var selection: Set<Card.ID>

        init(fileName: String, candidates: [CardImporter.Candidate], skippedRows: Int, anki: AnkiSummary? = nil) {
            self.fileName = fileName
            self.candidates = candidates
            self.skippedRows = skippedRows
            self.anki = anki
            selection = Set(candidates.filter { $0.duplicate == nil }.map(\.id))
        }

        convenience init(fileName: String, result: CardImporter.Result) {
            self.init(fileName: fileName, candidates: result.candidates, skippedRows: result.skippedRows)
        }

        /// The selected cards in file order.
        var selectedCards: [Card] {
            candidates.filter { selection.contains($0.id) }.map(\.card)
        }
    }

    static func preview(of data: Data, fileName: String, existing: [Card], created: Date) -> Preview {
        let table = DelimitedText.decode(data)
        let result = CardImporter.candidates(from: table.rows, existing: existing, isHeader: isHeader, created: created, columns: table.columns)
        return Preview(fileName: fileName, result: result)
    }

    /// Whether `row` starts with the column titles of an export, in any language of
    /// the app, so files exported in another language are recognised as well.
    nonisolated static func isHeader(_ row: [String]) -> Bool {
        guard row.count >= 2 else { return false }
        func matches(_ field: String, _ key: String) -> Bool {
            let field = field.trimmingCharacters(in: .whitespacesAndNewlines)
            return titles(for: key).contains { $0.compare(field, options: .caseInsensitive) == .orderedSame }
        }
        return matches(row[0], "Question") && matches(row[1], "Answer")
    }

    /// The key itself, which is the English title, and its translations.
    private nonisolated static func titles(for key: String) -> [String] {
        let translations = Bundle.main.localizations.compactMap { language in
            Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:))
        }
        .map { $0.localizedString(forKey: key, value: key, table: nil) }
        return [key] + translations
    }
}
