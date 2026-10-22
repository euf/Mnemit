import SwiftUI
import VocabCore

/// "Add Lesson Words…": the words of a lesson typed one per line, "greek = translation",
/// with a preview of the cards they make, two for each word, see `LessonWords`. The
/// cards join the deck as one change, which one undo takes back.
struct LessonWordsSheet: View {
    @ObservedObject var document: VocabularyDocument
    /// The name of the deck, for the button.
    var deckName: String
    /// Called with the number of cards added, once the sheet has done its work.
    var onAdded: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        let parsed = LessonWords.parse(text)
        let plan = LessonWords.plan(for: parsed.entries, existingNotes: document.deck.cards.compactMap(\.note), created: document.clock.now)

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add Lesson Words")
                    .font(.title2.weight(.semibold))
                Text("One word per line: the Greek word, an equals sign, a dash or a hyphen with spaces around it, then the translation.")
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(4)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(.separator) }
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(verbatim: "κλέβω = to steal\nη κλοπή = theft\nο κλέφτης = thief")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .frame(height: 110)
                .accessibilityLabel(Text("Lesson words"))

            skipped(parsed: parsed, plan: plan)

            HStack {
                Text("Preview")
                    .font(.headline)
                Spacer()
                Label("The production card unlocks after the recognition card is learned", systemImage: "lock")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            preview(plan)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                // Return belongs to the text; ⌘Return adds.
                Button("Add \(plan.cards.count) cards to \(deckName)") { add(plan) }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(plan.cards.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 560, idealWidth: 660, minHeight: 440, idealHeight: 520)
    }

    /// What the preview leaves out, and why.
    @ViewBuilder
    private func skipped(parsed: LessonWords.Parsed, plan: LessonWords.Plan) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if !parsed.invalidLines.isEmpty {
                Text("\(parsed.invalidLines.count) lines without a word and a translation are left out.")
            }
            if !plan.skipped.isEmpty {
                Text("\(plan.skipped.count) words are in the deck already, or earlier in the list, and are left out.")
            }
        }
        .font(.callout)
        .foregroundStyle(.orange)
    }

    private func preview(_ plan: LessonWords.Plan) -> some View {
        Table(plan.cards) {
            TableColumn("Direction") { card in
                if card.kind == .production {
                    Label("Production", systemImage: "lock")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Recognition")
                }
            }
            .width(min: 90, ideal: 110)
            TableColumn("Question", value: \.question)
            TableColumn("Answer", value: \.answer)
        }
        .overlay {
            if plan.cards.isEmpty {
                Text("Type a word and its translation to see its cards.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func add(_ plan: LessonWords.Plan) {
        let count = document.addLessonCards(plan.cards)
        dismiss()
        if count > 0 {
            onAdded(count)
        }
    }
}
