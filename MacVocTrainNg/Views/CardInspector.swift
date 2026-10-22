import SwiftUI
import VocabCore

/// Details of the selected card, in the sections of the iPhone's Card Detail: the card with
/// its kind, word key and sibling, its memory, and the history of its reviews.
///
/// The texts are only shown. "Edit…" opens the sheet that edits them, so the deck
/// changes only once the learner saves the edit (#241).
struct CardInspector: View {
    @ObservedObject var document: VocabularyDocument
    var selection: Set<Card.ID>
    /// `false` while the deck can only be viewed: the inspector then only shows the cards.
    var isEditable: Bool
    /// Opens the sheet that edits a card, which the card list presents.
    var onEdit: (Card.ID) -> Void
    /// Deletes cards and takes them out of the selection, which belongs to the card list.
    var onDelete: (Set<Card.ID>) -> Void
    /// Selects a card in the table, which belongs to the card list: the link to a sibling.
    var onSelect: (Card.ID) -> Void
    /// The words of the other open decks, read when the inspector appears.
    @State private var elsewhere = WordIndex()

    var body: some View {
        Group {
            if selection.count == 1, let id = selection.first, let card = document.card(withID: id) {
                CardDetail(document: document, card: card, isEditable: isEditable, onEdit: onEdit, onDelete: onDelete, onSelect: onSelect, elsewhere: elsewhere)
                    .id(card.id)
            } else if selection.count > 1 {
                VStack(spacing: 12) {
                    Text("\(selection.count) cards selected")
                        .font(.headline)
                    Group {
                        SuspensionButtons(document: document, ids: selection)
                        Button("Reset Learning State") {
                            document.resetLearningState(of: selection)
                        }
                        Button("Delete", role: .destructive) {
                            onDelete(selection)
                        }
                    }
                    .disabled(!isEditable)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("No Selection", systemImage: "rectangle.on.rectangle.slash", description: Text("Select a card to see its details."))
            }
        }
        .task { elsewhere = await OpenDecks.shared.wordIndex(excluding: document) }
    }
}

private struct CardDetail: View {
    @ObservedObject var document: VocabularyDocument
    let card: Card
    let isEditable: Bool
    let onEdit: (Card.ID) -> Void
    let onDelete: (Set<Card.ID>) -> Void
    let onSelect: (Card.ID) -> Void
    /// The words of the other open decks, for the line that says the word is in another deck.
    let elsewhere: WordIndex

    var body: some View {
        Form {
            Section("Card") {
                LabeledContent("Question") { Text(card.question).textSelection(.enabled) }
                LabeledContent("Answer") { Text(card.answer).textSelection(.enabled) }
                if !card.hint.isEmpty {
                    LabeledContent("Hint") { Text(card.hint).textSelection(.enabled) }
                }
                if let kind = card.kind {
                    LabeledContent("Kind", value: kind.title)
                }
                if let note = card.note {
                    LabeledContent("Word Key") { Text(note).textSelection(.enabled) }
                }
                ForEach(document.deck.siblings(of: card)) { sibling in
                    LabeledContent("Sibling Card") {
                        Button(sibling.question) { onSelect(sibling.id) }
                            .buttonStyle(.link)
                            .help("Show the sibling card in the list")
                    }
                }
                if case let .same(match)? = elsewhere.match(card) {
                    LabeledContent("Also in \(match.deck)") { Text(verbatim: "\(match.question) → \(match.answer)").textSelection(.enabled) }
                }
                Button("Edit…") { onEdit(card.id) }
                    .disabled(!isEditable)
            }

            Section("Memory") {
                if card.isSuspended {
                    Label("Suspended: no study session asks this card.", systemImage: "pause.circle")
                        .foregroundStyle(.secondary)
                }
                if document.deck.isLeech(card) {
                    Label {
                        Text("Difficult: you keep forgetting this card.")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    .foregroundStyle(.secondary)
                    .help("The card has been forgotten as often as the leech threshold in the learning options asks. A session suspends it; resume it to keep learning it.")
                }
                LabeledContent("State") {
                    HStack(spacing: 8) {
                        MaturityLabel(category: MaturityCategory(card: card))
                        if let phase = card.learningState?.phase {
                            Text(phase.title)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if let learningState = card.learningState {
                    // Due date and recall probability change as time passes, so these rows
                    // are re-evaluated every minute.
                    TimelineView(.everyMinute) { _ in
                        LabeledContent("Next Review", value: Format.due(learningState.due, now: document.clock.now))
                    }
                    LabeledContent("Stability", value: Format.days(learningState.stability))
                    LabeledContent("Difficulty", value: learningState.difficulty.formatted(.number.precision(.fractionLength(1))) + " / 10")
                    TimelineView(.everyMinute) { _ in
                        if let probability = document.deck.recallProbability(of: card, at: document.clock.now, calendar: document.calendar) {
                            LabeledContent("Recall Now", value: Format.percent(probability))
                        }
                    }
                    LabeledContent("Reviews", value: learningState.reviews.formatted())
                    LabeledContent("Lapses", value: learningState.lapses.formatted())
                    LabeledContent("Last Review", value: learningState.lastReview.formatted(date: .abbreviated, time: .shortened))
                } else {
                    Text("This card has not been studied yet.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Group {
                    SuspensionButtons(document: document, ids: [card.id])
                    if !card.isNew {
                        Button("Reset Learning State") {
                            document.resetLearningState(of: [card.id])
                        }
                    }
                    Button("Delete", role: .destructive) {
                        onDelete([card.id])
                    }
                }
                .disabled(!isEditable)
            }

            if !card.log.isEmpty {
                Section("History") {
                    ForEach(Array(card.log.suffix(50).reversed().enumerated()), id: \.offset) { _, entry in
                        LabeledContent(entry.date.formatted(date: .abbreviated, time: .shortened)) {
                            HStack(spacing: 6) {
                                Text(entry.grade.arrow)
                                    .foregroundStyle(.secondary)
                                GradeDot(grade: entry.grade)
                                Text(entry.grade.title)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
