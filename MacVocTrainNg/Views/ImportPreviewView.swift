import SwiftUI
import VocabCore

/// The cards of an import file, to choose which ones to add to the deck.
///
/// A deck that had no card yet, a new one, also offers Study These Now for a lesson's worth of cards: it imports the
/// checked cards, closes and hands the new ones to `studyNow`, so the first cards of the deck are studied at once.
struct ImportPreviewView: View {
    @ObservedObject var document: VocabularyDocument
    @Bindable var preview: CardImport.Preview
    private var studyNow: (([Card.ID]) -> Void)?
    /// Whether the deck had no card when the sheet opened.
    @State private var isNewDeck: Bool
    @Environment(\.dismiss) private var dismiss

    init(document: VocabularyDocument, preview: CardImport.Preview, studyNow: (([Card.ID]) -> Void)? = nil) {
        self.document = document
        self.preview = preview
        self.studyNow = studyNow
        _isNewDeck = State(initialValue: document.deck.cards.isEmpty)
    }

    /// The most cards Study These Now takes from an import, as the iPhone's.
    static let studyNowLimit = 50

    /// A lesson's worth of new cards from a table: a package brings its own history and a library of cards is no
    /// lesson, the plan paces both.
    private var offersStudyNow: Bool {
        let cards = preview.selectedCards
        return isNewDeck && studyNow != nil && preview.anki == nil && (1...Self.studyNowLimit).contains(cards.count) && cards.contains(where: \.isNew)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Import Cards")
                    .font(.title2.weight(.semibold))
                if let anki = preview.anki {
                    Text(anki.deckTitle)
                        .fontWeight(.semibold)
                }
                Text("\(preview.candidates.count) cards in “\(preview.fileName)”")
                    .foregroundStyle(.secondary)
                ForEach(preview.anki?.lines ?? [], id: \.self) { line in
                    Text(line)
                        .foregroundStyle(.secondary)
                }
                ForEach(preview.otherDeckLines, id: \.self) { line in
                    Text(line)
                        .foregroundStyle(.secondary)
                }
                if preview.skippedRows > 0 {
                    Text("\(preview.skippedRows) rows without a question or an answer are left out.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)

            Table(preview.candidates) {
                TableColumn(Text(verbatim: "")) { candidate in
                    Toggle("Import", isOn: isSelected(candidate.id))
                        .labelsHidden()
                }
                .width(20)
                TableColumn("Question", value: \.card.question)
                TableColumn("Answer", value: \.card.answer)
                TableColumn("Hint", value: \.card.hint)
                TableColumn("Note") { candidate in
                    switch candidate.duplicate {
                    case .inDeck:
                        Label("Already in this deck", systemImage: "exclamationmark.triangle")
                    case let .inFile(question, answer):
                        Label("Already earlier in the file: \(question) → \(answer)", systemImage: "exclamationmark.triangle")
                    case let .inOtherDeck(match):
                        Label(match.alsoInLine, systemImage: "exclamationmark.triangle")
                    case nil:
                        if let similar = candidate.similar {
                            Label(similar.similarLine, systemImage: "info.circle")
                        }
                    }
                }
                .width(min: 120, ideal: 160)
            }

            Divider()

            HStack {
                Button("Select All") {
                    preview.selection = Set(preview.candidates.map(\.id))
                }
                Button("Select None") {
                    preview.selection = []
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                if offersStudyNow, let studyNow {
                    Button("Study These Now") {
                        let ids = add()
                        dismiss()
                        studyNow(ids)
                    }
                }
                Button("Import \(preview.selection.count) Cards") {
                    add()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(preview.selection.isEmpty)
            }
            .padding(16)
        }
        .frame(minWidth: 680, idealWidth: 760, minHeight: 440, idealHeight: 540)
    }

    /// Imports the checked cards as one change; returns their ids.
    @discardableResult
    private func add() -> [Card.ID] {
        let cards = preview.selectedCards
        document.importCards(cards, learningOptions: preview.learningOptions, media: preview.media)
        return cards.map(\.id)
    }

    private func isSelected(_ id: Card.ID) -> Binding<Bool> {
        Binding(
            get: { preview.selection.contains(id) },
            set: { isOn in
                if isOn {
                    preview.selection.insert(id)
                } else {
                    preview.selection.remove(id)
                }
            }
        )
    }
}
