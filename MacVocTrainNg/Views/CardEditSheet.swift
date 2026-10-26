import SwiftUI
import VocabCore

/// Edits question, answer, hint and word key of one card in a sheet.
///
/// The fields hold a draft; the deck changes only when the learner saves it, as one
/// change with one undo action (#241): the texts and the key are two changes of the
/// deck, which the undo manager groups as the one event of the Save button. Cancel drops the draft, and so does quitting
/// while the sheet is open, as with the learning options: the deck holds what the
/// learner confirmed. Typing registers with the undo manager of the sheet's own window
/// (#48), so ⌘Z in the sheet takes back typing, never a change to the deck.
///
/// A session that is still asking the card opens it with `hidesAnswer` (#289): the
/// sheet then shows neither the answer nor that of a card with the same question, and
/// saving keeps the answer as the deck holds it. It leaves out the word key, too: that
/// of a translation card is the Greek word, its answer.
struct CardEditSheet: View {
    @ObservedObject var document: VocabularyDocument
    let cardID: Card.ID
    let hidesAnswer: Bool
    /// Runs after a save, once the card is changed: the study stream's leech moment goes on with it.
    var onSave: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var question: String
    @State private var answer: String
    @State private var hint: String
    @State private var note: String

    init(document: VocabularyDocument, card: Card, hidesAnswer: Bool = false, onSave: @escaping () -> Void = {}) {
        self.document = document
        self.onSave = onSave
        cardID = card.id
        self.hidesAnswer = hidesAnswer
        _question = State(initialValue: card.question)
        _answer = State(initialValue: card.answer)
        _hint = State(initialValue: card.hint)
        _note = State(initialValue: card.note ?? "")
    }

    /// The answer saved with the draft; while it is hidden, the card's own as the deck
    /// holds it now, e.g. after a merge.
    private var savedAnswer: String {
        hidesAnswer ? document.card(withID: cardID)?.answer ?? answer : answer
    }

    /// `nil` while question or answer is empty and has no media; Save is disabled then.
    private var text: CardText? { CardText(question: question, answer: savedAnswer, hint: hint, media: document.card(withID: cardID)?.media ?? CardMedia()) }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Question", text: $question)
                    if !hidesAnswer {
                        TextField("Answer", text: $answer)
                    }
                    TextField("Hint", text: $hint, prompt: Text("Hint (optional)"))
                    if !hidesAnswer {
                        TextField("Word Key", text: $note, prompt: Text("Word key (optional)"))
                            .help("Cards of one word share a key; a day asks only one of them")
                    }
                } footer: {
                    // As in the form for new cards, but the edited card doesn't count.
                    let duplicate = document.deck.cards(withQuestion: question).first { $0.id != cardID }
                    if hidesAnswer || duplicate != nil {
                        VStack(alignment: .leading, spacing: 6) {
                            if hidesAnswer {
                                Text("The answer stays hidden until you have responded.")
                            }
                            if let duplicate {
                                Label(duplicateNote(for: duplicate), systemImage: "exclamationmark.triangle")
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            // A form scrolls: at its own height the sheet grows with the note about a
            // duplicate instead of cutting it off.
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(text == nil)
            }
            .padding()
        }
        .frame(width: 460)
        .navigationTitle("Edit Card")
    }

    /// Names the card with the same question; without its answer while the answer is hidden.
    private func duplicateNote(for duplicate: Card) -> String {
        hidesAnswer
            ? String(localized: "Already in this deck: \(duplicate.question)")
            : String(localized: "Already in this deck: \(duplicate.question) → \(duplicate.answer)")
    }

    /// Changes the card once, with the whole draft. A card that left the deck while the
    /// sheet was open stays out: `editText(of:to:)` changes nothing then. A hidden answer
    /// leaves the word key as it is.
    private func save() {
        guard let text else { return }
        document.editText(of: cardID, to: text)
        if !hidesAnswer {
            document.setNote(note, of: cardID)
        }
        onSave()
        dismiss()
    }
}
