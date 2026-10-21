import SwiftUI
import VocabCore

/// What the app knows about a card, to read and nothing else: its texts and kind, its
/// learning state, the card of the same word in the other direction and the last reviews.
/// A long press on the card in a session opens it, before or after the answer shows;
/// cards are edited on the Mac.
///
/// Shows the card as it was when the sheet opened.
struct CardInfoSheet: View {
    var document: VocabularyDocument
    var card: Card

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Card") {
                    LabeledContent("Question") { spoken(card.question) }
                    LabeledContent("Answer") { spoken(card.answer) }
                    if !card.hint.isEmpty {
                        LabeledContent("Hint", value: card.hint)
                    }
                    if let kind = card.kind {
                        LabeledContent("Kind", value: kind.title)
                    }
                }

                Section("Learning State") {
                    if card.isSuspended {
                        Label("Suspended: no study session asks this card.", systemImage: "pause.circle")
                            .foregroundStyle(.secondary)
                    }
                    if let learningState = card.learningState {
                        state(learningState)
                    } else {
                        Text("This card has not been studied yet.")
                            .foregroundStyle(.secondary)
                    }
                }

                if let sibling {
                    Section("Sibling Card") {
                        LabeledContent("Question", value: sibling.question)
                        if let kind = sibling.kind {
                            LabeledContent("Kind", value: kind.title)
                        }
                        if sibling.isSuspended {
                            Label("Suspended: no study session asks this card.", systemImage: "pause.circle")
                                .foregroundStyle(.secondary)
                        }
                        LabeledContent("Maturity") { MaturityLabel(category: MaturityCategory(card: sibling)) }
                        if let due = sibling.learningState?.due {
                            LabeledContent("Due", value: Format.due(due, now: document.clock.now))
                        }
                    }
                }

                if !card.log.isEmpty {
                    Section("Review Log") {
                        ForEach(Array(card.log.suffix(50).reversed().enumerated()), id: \.offset) { _, entry in
                            LabeledContent(entry.date.formatted(date: .abbreviated, time: .shortened)) {
                                HStack(spacing: 6) {
                                    GradeDot(grade: entry.grade)
                                    Text(entry.grade.title)
                                    Text(entry.mode.title)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Card Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// The card of the same word that asks the other way round, if the word has one.
    private var sibling: Card? {
        guard let note = card.note else { return nil }
        return document.deck.cards.first { $0.note == note && $0.id != card.id }
    }

    /// A text with its speaker button, which is there for Greek text only.
    private func spoken(_ text: String) -> some View {
        HStack(spacing: 8) {
            Text(text)
                .multilineTextAlignment(.trailing)
            SpeakButton(text: text)
        }
    }

    @ViewBuilder
    private func state(_ learningState: LearningState) -> some View {
        LabeledContent("Maturity") { MaturityLabel(category: MaturityCategory(card: card)) }
        LabeledContent("Phase", value: learningState.phase.title)
        LabeledContent("Due", value: Format.due(learningState.due, now: document.clock.now))
        LabeledContent("Stability", value: Format.days(learningState.stability))
        LabeledContent("Difficulty", value: learningState.difficulty.formatted(.number.precision(.fractionLength(1))) + " / 10")
        if let probability = document.deck.recallProbability(of: card, at: document.clock.now, calendar: document.calendar) {
            LabeledContent("Recall Probability", value: Format.percent(probability))
        }
        LabeledContent("Reviews", value: learningState.reviews.formatted())
        LabeledContent("Lapses", value: learningState.lapses.formatted())
        LabeledContent("Last Review", value: learningState.lastReview.formatted(date: .abbreviated, time: .shortened))
    }
}
