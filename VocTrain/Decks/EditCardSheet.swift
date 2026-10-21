import SwiftUI
import VocabCore

/// Edits the texts of a card: question, answer and hint, and under Advanced its word key.
/// Nothing changes until Save; the document then takes the edit as one undo step, see
/// `VocabularyDocument.editCard(_:text:note:)`.
struct EditCardSheet: View {
    var document: VocabularyDocument
    var card: Card
    @State private var question: String
    @State private var answer: String
    @State private var hint: String
    @State private var note: String
    @State private var showsAdvanced: Bool
    @Environment(\.dismiss) private var dismiss

    init(document: VocabularyDocument, card: Card, showsAdvanced: Bool = false) {
        self.document = document
        self.card = card
        _question = State(initialValue: card.question)
        _answer = State(initialValue: card.answer)
        _hint = State(initialValue: card.hint)
        _note = State(initialValue: card.note ?? "")
        _showsAdvanced = State(initialValue: showsAdvanced)
    }

    /// The text as it would be saved, `nil` while the question or the answer is empty.
    private var text: CardText? {
        CardText(question: question, answer: answer, hint: hint)
    }

    private var key: String? {
        let trimmed = CardText.trimmed(note)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var hasChanged: Bool {
        text.map { $0.question != card.question || $0.answer != card.answer || $0.hint != card.hint } == true || key != card.note
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Question") {
                    TextField("Question", text: $question, axis: .vertical)
                        .lineLimit(1...4)
                }
                Section {
                    TextField("Answer", text: $answer, axis: .vertical)
                        .lineLimit(1...8)
                } header: {
                    Text("Answer")
                } footer: {
                    Text("A second line is shown smaller, as an example.")
                }
                Section("Hint") {
                    TextField("Hint", text: $hint, axis: .vertical)
                        .lineLimit(1...4)
                }
                Section {
                    DisclosureGroup("Advanced", isExpanded: $showsAdvanced) {
                        TextField("Word Key", text: $note)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Text("Cards with the same word key belong to one word, like the two directions of a translation.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let text {
                            document.editCard(card.id, text: text, note: key)
                        }
                        dismiss()
                    }
                    .disabled(text == nil || !hasChanged || !document.isReadyToEdit)
                }
            }
        }
    }
}
