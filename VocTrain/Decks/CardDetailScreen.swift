import SwiftUI
import VocabCore

/// One card: both sides large with the speaker, its direction and the card of the same word the
/// other way round, where it stands in memory as one line, and its history; stability, difficulty
/// and the other figures are one tap away under Details. Edit, Suspend or Resume, Reset Progress
/// and Delete act on it.
///
/// Pushed from the card browser and from a search result on Today, and shown in a sheet by
/// a long press on a card of the study stream (`CardInfoSheet`). It looks the card up by its
/// ID, so it shows the card as the deck holds it now. Deleting the card leaves the screen
/// in place with Undo, so the deletion can be taken back from wherever the screen was reached.
struct CardDetailScreen: View {
    @ObservedObject var document: VocabularyDocument
    var cardID: Card.ID
    /// Whether the deck can be changed now, see `OpenDeck.isEditable`.
    var canEdit: Bool
    @State private var editing: Card?
    @State private var undo: UndoWatch

    init(document: VocabularyDocument, cardID: Card.ID, canEdit: Bool, editing: Card? = nil) {
        self.document = document
        self.cardID = cardID
        self.canEdit = canEdit
        _editing = State(initialValue: editing)
        _undo = State(initialValue: UndoWatch(document.undoManager))
    }

    private var isEditable: Bool { canEdit && document.isReadyToEdit }

    var body: some View {
        Group {
            if let card = document.card(withID: cardID) {
                CardDetailList(document: document, card: card, isEditable: isEditable, canEdit: canEdit)
            } else {
                ContentUnavailableView {
                    Label("Card Deleted", systemImage: "trash")
                } actions: {
                    Button("Undo", systemImage: "arrow.uturn.backward") { undo.undo() }
                        .disabled(!undo.canUndo)
                }
            }
        }
        .navigationTitle("Card")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if undo.canUndo {
                ToolbarItem(placement: .primaryAction) {
                    Button("Undo", systemImage: "arrow.uturn.backward") { undo.undo() }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel(Text("Undo \(undo.actionName)"))
                }
            }
            if let card = document.card(withID: cardID) {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { editing = card }
                        .disabled(!isEditable)
                }
            }
        }
        .sheet(item: $editing) { card in
            EditCardSheet(document: document, card: card)
        }
    }
}

private struct CardDetailList: View {
    @ObservedObject var document: VocabularyDocument
    var card: Card
    var isEditable: Bool
    var canEdit: Bool
    @Environment(\.knownDeckFiles) private var knownDeckFiles
    /// The words of the other decks, once they are read.
    @State private var elsewhere = WordIndex()
    @State private var showsDetails = false

    /// The same word in another deck, if there is one: a separate card there, with its own progress.
    private var otherCopy: WordIndex.Match? {
        if case let .same(match)? = elsewhere.match(card) { match } else { nil }
    }

    /// The card of the same word that asks the other way round, if the word has one.
    private var sibling: Card? {
        guard let note = card.note else { return nil }
        let others = document.deck.cards.filter { $0.note == note && $0.id != card.id }
        return others.first { $0.kind != card.kind } ?? others.first
    }

    var body: some View {
        let now = document.clock.now
        List {
            Section {
                CardTexts(card: card, media: document.deck.media)
            }
            if card.kind != nil || sibling != nil || otherCopy != nil {
                directionSection
            }
            memorySection(now: now)
            if !card.log.isEmpty {
                Section("History") {
                    ForEach(Array(card.log.suffix(50).reversed().enumerated()), id: \.offset) { offset, entry in
                        HistoryRow(entry: entry, isFirst: offset == card.log.count - 1)
                    }
                }
            }
            Section {
                Button(card.isSuspended ? "Resume Card" : "Suspend Card", systemImage: card.isSuspended ? "play.circle" : "pause.circle") {
                    document.setSuspended(!card.isSuspended, of: [card.id])
                }
                if !card.isNew {
                    Button("Reset Progress", systemImage: "arrow.counterclockwise", role: .destructive) {
                        document.resetLearningState(of: [card.id])
                    }
                }
                Button("Delete Card", systemImage: "trash", role: .destructive) {
                    document.delete([card.id])
                }
            }
            .disabled(!isEditable)
        }
        .listStyle(.insetGrouped)
        .task { elsewhere = await knownDeckFiles.wordIndex(excluding: document.packageURL) }
    }

    private var directionSection: some View {
        Section {
            if let kind = card.kind {
                LabeledContent("Direction", value: kind.title)
            }
            if let sibling {
                NavigationLink {
                    CardDetailScreen(document: document, cardID: sibling.id, canEdit: canEdit)
                } label: {
                    VStack(alignment: .leading, spacing: Spacing.hairline) {
                        Text(sibling.kind.map { String(localized: "Other direction: \($0.title)") } ?? String(localized: "Other direction"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(sibling.question)
                    }
                }
            }
            if let otherCopy {
                VStack(alignment: .leading, spacing: Spacing.hairline) {
                    Text("Also in \(otherCopy.deck)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(verbatim: "\(otherCopy.question) → \(otherCopy.answer)")
                }
            }
        }
    }

    @ViewBuilder
    private func memorySection(now: Date) -> some View {
        Section("Memory") {
            if card.isSuspended {
                // Not "due now": no session asks a suspended card.
                Text(verbatim: MaturityCategory(card: card).cardTitle)
            } else {
                CardMemoryLine(card: card, now: now)
            }
            if card.isSuspended {
                Label("Suspended: no session asks it.", systemImage: "pause.circle")
                    .foregroundStyle(.secondary)
            }
            if document.deck.isLeech(card) {
                Label("Leech: you keep forgetting this card.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }
            if card.learningState != nil || card.note != nil {
                DisclosureGroup("Details", isExpanded: $showsDetails) {
                    details(now: now)
                }
            }
        }
        .monospacedDigit()
    }

    /// The figures the scheduler keeps, for the learner who wants them; the word key.
    @ViewBuilder
    private func details(now: Date) -> some View {
        if let learningState = card.learningState {
            LabeledContent("State", value: card.stateTitle)
            LabeledContent("Stability", value: Format.days(learningState.stability))
            LabeledContent("Difficulty", value: Format.difficulty(learningState.difficulty))
            if let probability = document.deck.recallProbability(of: card, at: now, calendar: document.calendar) {
                LabeledContent("Recall Now", value: Format.percent(probability))
            }
            LabeledContent("Reviews", value: learningState.reviews.formatted())
            LabeledContent("Lapses", value: learningState.lapses.formatted())
        }
        if let note = card.note {
            LabeledContent("Word Key", value: note)
        }
    }
}

/// Question and answer, both large, each Greek word with its speaker. Like the face of a
/// card of the study stream, but left aligned and without a card around it.
private struct CardTexts: View {
    var card: Card
    /// The deck's media, for the images and sounds of the card.
    var media: DeckMedia

    /// The answer split at its first line break: the head, which the speaker says, and an
    /// example sentence, if there is one.
    private var answer: (head: String, example: String?) {
        let lines = card.answer.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
        return (lines.first.map(String.init) ?? card.answer, lines.count > 1 ? String(lines[1]) : nil)
    }

    private func font(for text: String) -> Font {
        text.containsGreek ? .largeTitle.weight(.semibold) : .title.weight(.semibold)
    }

    /// The image of a side, left aligned like the texts.
    @ViewBuilder
    private func image(_ name: String?) -> some View {
        if name != nil {
            SideImage(name: name, media: media, maxHeight: 240, alignment: .leading)
        }
    }

    var body: some View {
        let answer = answer
        VStack(alignment: .leading, spacing: Spacing.gap) {
            image(card.questionImage)
            if !card.question.isEmpty || card.questionAudio != nil {
                SpokenWord(text: card.question, font: font(for: card.question), sound: card.questionAudio, media: media)
            }
            if !card.hint.isEmpty {
                Text(card.hint)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Divider()
            image(card.answerImage)
            if !answer.head.isEmpty || card.answerAudio != nil {
                SpokenWord(text: answer.head, font: font(for: answer.head), sound: card.answerAudio, media: media)
            }
            if let example = answer.example {
                Text(example)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.tight)
        .textSelection(.enabled)
        .accessibilityElement(children: .contain)
    }
}

/// A review: the grade as a disc of its colour with the arrow of its swipe, its name, the
/// date, and "Typed" on a review made by typing, in an older version or an upstream deck.
private struct HistoryRow: View {
    var entry: ReviewLogEntry
    /// The card's first review: its Again is "Don't know".
    var isFirst: Bool

    var body: some View {
        HStack(spacing: Spacing.gap) {
            Image(systemName: entry.grade.arrowSymbol)
                .font(.footnote.weight(.bold))
                .foregroundStyle(entry.grade.onColor)
                .frame(width: 28, height: 28)
                .background(entry.grade.color, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.grade.buttonTitle(isNew: isFirst))
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Spacing.tight)
            if entry.mode == .typed {
                Text("Typed")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

extension Card {
    /// Where the card is in its life: New, Learning, Review or Relearning.
    var stateTitle: String {
        switch learningState?.phase {
        case nil: String(localized: "New")
        case .learning: String(localized: "Learning")
        case .review: String(localized: "Review")
        case .relearning: String(localized: "Relearning")
        }
    }
}
