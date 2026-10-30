import SwiftUI
import VocabCore

/// The cards of a deck, to find, read and tidy: a search over question, answer, hint and word
/// key, the filters All, Due, New, Learning, Suspended and Leeches with their counts, five
/// sorts, and a row per card that opens the card. Swipe a row to delete or suspend it, press
/// it for more, or choose Select to act on several cards at once.
///
/// Deleting one card asks nothing, Undo takes it back (the button in the bar, or a shake, see
/// `StartScreen`); deleting several asks once.
struct CardBrowserScreen: View {
    @ObservedObject var document: VocabularyDocument
    /// Whether the deck can be changed now, see `OpenDeck.isEditable`.
    var canEdit: Bool
    var addCards: () -> Void

    @State private var filter: CardFilter
    @State private var sort: BrowserSort
    @State private var query = ""
    @State private var selection: Set<Card.ID>
    @State private var editMode: EditMode
    @State private var editing: Card?
    /// The cards the learner is about to delete with the others of the selection.
    @State private var deleting: Set<Card.ID> = []
    @State private var memo = CardBrowserMemo()
    @State private var undo: UndoWatch

    /// - Parameters:
    ///   - filter: What the list starts with; a test chooses it.
    ///   - selecting: Starts in the mode that selects cards, with `selection` chosen.
    init(
        document: VocabularyDocument, canEdit: Bool, addCards: @escaping () -> Void = {}, filter: CardFilter = .all,
        sort: BrowserSort = .due, query: String = "", selecting: Set<Card.ID>? = nil
    ) {
        self.document = document
        self.canEdit = canEdit
        self.addCards = addCards
        _filter = State(initialValue: filter)
        _sort = State(initialValue: sort)
        _query = State(initialValue: query)
        _selection = State(initialValue: selecting ?? [])
        _editMode = State(initialValue: selecting == nil ? .inactive : .active)
        _undo = State(initialValue: UndoWatch(document.undoManager))
    }

    private var isEditable: Bool { canEdit && document.isReadyToEdit }

    private var isSelecting: Bool { editMode == .active }

    /// What the bar says: the screen, or while selecting how many cards the buttons below act on.
    private var title: String {
        guard isSelecting else { return String(localized: "Cards") }
        return selection.isEmpty ? String(localized: "Select Cards") : String(localized: "\(selection.count) selected")
    }

    var body: some View {
        let now = document.clock.now
        let threshold = document.deck.learningOptions.leechThreshold
        let output = memo.output(deck: document.deck, filter: filter, sort: sort, query: query, now: now)
        Group {
            if document.deck.cards.isEmpty {
                ContentUnavailableView {
                    Label("No Cards", systemImage: "rectangle.on.rectangle.slash")
                } description: {
                    Text("Add the words you are learning.")
                } actions: {
                    Button("Add Cards", action: addCards)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.appAccent)
                        .disabled(!isEditable)
                }
            } else {
                list(output.rows, now: now, threshold: threshold)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: Text("Search Cards"))
        // The rows end in a hard edge above the search pill and the bar of a selection: the glass over them is clear, and a row's
        // second line ran through its text.
        .scrollEdgeEffectStyle(.hard, for: .bottom)
        .safeAreaBar(edge: .top) {
            if !document.deck.cards.isEmpty {
                FilterBar(selection: $filter, counts: output.counts)
            }
        }
        .safeAreaBar(edge: .bottom) {
            if isSelecting { selectionBar }
        }
        .environment(\.editMode, $editMode)
        .toolbar { toolbar }
        .onChange(of: output.rows.map(\.id)) { _, ids in
            // What the filter or the search hides can't be chosen: the buttons below act on
            // what the learner sees.
            selection.formIntersection(ids)
        }
        .sheet(item: $editing) { card in
            EditCardSheet(document: document, card: card)
        }
        .confirmationDialog(
            Text("Delete \(deleting.count) cards?"), isPresented: Binding(get: { !deleting.isEmpty }, set: { if !$0 { deleting = [] } }),
            titleVisibility: .visible
        ) {
            Button("Delete \(deleting.count) cards", role: .destructive) {
                document.delete(deleting)
                selection.subtract(deleting)
                deleting = []
            }
        } message: {
            Text("You can take this back with Undo.")
        }
    }

    // MARK: List

    @ViewBuilder
    private func list(_ rows: [Card], now: Date, threshold: Int) -> some View {
        List(selection: $selection) {
            ForEach(rows) { card in
                NavigationLink {
                    CardDetailScreen(document: document, cardID: card.id, canEdit: canEdit)
                } label: {
                    CardRow(
                        card: card, state: BrowserState(card, leechThreshold: threshold), now: now,
                        showsDirection: !query.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .swipeActions(edge: .trailing) {
                    if isEditable {
                        Button("Delete", systemImage: "trash", role: .destructive) { document.delete([card.id]) }
                        suspendButton(card)
                    }
                }
                .contextMenu {
                    menu(card)
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if rows.isEmpty {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    ContentUnavailableView("No Cards", systemImage: "line.3.horizontal.decrease.circle", description: Text("No cards match this filter."))
                } else {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
    }

    private func suspendButton(_ card: Card) -> some View {
        Button(card.isSuspended ? "Resume" : "Suspend", systemImage: card.isSuspended ? "play.circle" : "pause.circle") {
            document.setSuspended(!card.isSuspended, of: [card.id])
        }
        .tint(Color.appAccent)
    }

    @ViewBuilder
    private func menu(_ card: Card) -> some View {
        Button("Edit", systemImage: "pencil") { editing = card }
            .disabled(!isEditable)
        if let spoken = card.spokenText {
            Button("Speak", systemImage: "speaker.wave.2") { GreekSpeech.shared.speak(spoken) }
        }
        Button(card.isSuspended ? "Resume" : "Suspend", systemImage: card.isSuspended ? "play.circle" : "pause.circle") {
            document.setSuspended(!card.isSuspended, of: [card.id])
        }
        .disabled(!isEditable)
        if !card.isNew {
            Button("Reset Progress", systemImage: "arrow.counterclockwise") { document.resetLearningState(of: [card.id]) }
                .disabled(!isEditable)
        }
        Button("Delete", systemImage: "trash", role: .destructive) { document.delete([card.id]) }
            .disabled(!isEditable)
    }

    // MARK: Bar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if undo.canUndo, !isSelecting {
            ToolbarItem(placement: .primaryAction) {
                Button("Undo", systemImage: "arrow.uturn.backward") { undo.undo() }
                    .labelStyle(.iconOnly)
                    .accessibilityLabel(Text("Undo \(undo.actionName)"))
            }
        }
        if isSelecting {
            ToolbarItem(placement: .primaryAction) {
                let shown = memo.output(deck: document.deck, filter: filter, sort: sort, query: query, now: document.clock.now).rows.map(\.id)
                Button("Select All") { selection = Set(shown) }
                    .disabled(shown.isEmpty || selection.count == shown.count)
            }
        } else {
            ToolbarItem(placement: .primaryAction) {
                Menu("Sort", systemImage: "arrow.up.arrow.down") {
                    Picker("Sort", selection: $sort) {
                        ForEach(BrowserSort.allCases) { sort in
                            Text(sort.title).tag(sort)
                        }
                    }
                }
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button(isSelecting ? "Done" : "Select") {
                withAnimation {
                    editMode = isSelecting ? .inactive : .active
                }
                selection = []
            }
            .disabled(document.deck.cards.isEmpty)
        }
    }

    /// What the selection can do, each action a symbol with its word under it: bare glyphs leave a learner guessing what
    /// the circular arrow does, and four short words fit the narrowest iPhone when they are stacked. Not in the toolbar,
    /// which shows only the symbols.
    private var selectionBar: some View {
        HStack(spacing: Spacing.tight) {
            barButton("Suspend", "pause.circle") { document.setSuspended(true, of: selection) }
            barButton("Resume", "play.circle") { document.setSuspended(false, of: selection) }
            barButton("Reset", "arrow.counterclockwise") { document.resetLearningState(of: selection) }
            barButton("Delete", "trash", role: .destructive) { delete(selection) }
        }
        .disabled(!(isEditable && !selection.isEmpty))
        .padding(.horizontal, Spacing.margin)
        .padding(.bottom, Spacing.tight)
    }

    private func barButton(_ title: LocalizedStringKey, _ symbol: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: symbol)
                .labelStyle(StackedLabelStyle())
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
    }

    /// One card goes at once, as Undo covers it; several ask first.
    private func delete(_ ids: Set<Card.ID>) {
        if ids.count == 1 {
            document.delete(ids)
            selection.subtract(ids)
        } else {
            deleting = ids
        }
    }
}

/// The icon over its title, in the small type of a tab bar.
private struct StackedLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 2) {
            configuration.icon
            configuration.title
                .font(.caption2)
        }
    }
}

/// The filters in a row under the bar, each with how many cards it holds. A tap chooses
/// one; the chosen one is the prominent button.
struct FilterBar: View {
    @Binding var selection: CardFilter
    var counts: [CardFilter: Int]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.tight) {
                    ForEach(CardFilter.allCases) { filter in
                        chip(filter)
                            .id(filter)
                    }
                }
                .padding(.horizontal, Spacing.margin)
                .padding(.vertical, Spacing.tight)
            }
            .scrollClipDisabled()
            // The chosen chip is in view when the screen opens with it chosen too.
            .onChange(of: selection, initial: true) {
                withAnimation { proxy.scrollTo(selection, anchor: .center) }
            }
        }
    }

    @ViewBuilder
    private func chip(_ filter: CardFilter) -> some View {
        let isSelected = selection == filter
        let count = counts[filter] ?? 0
        let label = Button {
            selection = filter
        } label: {
            // The count in the secondary colour on the quiet chips, so the title reads first.
            Text("\(filter.title) \(Text(count, format: .number).monospacedDigit().foregroundStyle(isSelected ? .white : .secondary))")
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        Group {
            if isSelected {
                label.buttonStyle(.borderedProminent).tint(Color.appAccent)
            } else {
                label.buttonStyle(.bordered).tint(.secondary)
            }
        }
        .accessibilityLabel(Text("\(filter.title), \(count) cards"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A card in the list: the question, the answer under it, and at the right what state the card
/// is in. Only the first line of the answer shows, the example sentence belongs on the card's
/// own screen.
struct CardRow: View {
    var card: Card
    var state: BrowserState
    var now: Date
    /// Whether the row says which way the card asks: in a search the two cards of a word sit side by side.
    var showsDirection = false
    @Environment(\.dynamicTypeSize) private var typeSize

    private var answer: String {
        card.answer.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? card.answer
    }

    var body: some View {
        // At the accessibility sizes the state goes under the answer: beside the question it
        // would leave the words a column of their own.
        let layout =
            typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.hairline))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.gap))
        layout {
            VStack(alignment: .leading, spacing: 2) {
                SideText(text: card.question, image: card.questionImage, audio: card.questionAudio)
                    .lineLimit(2)
                SideText(text: answer, image: card.answerImage, audio: card.answerAudio)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if showsDirection, let kind = card.kind {
                    Text(kind.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if !typeSize.isAccessibilitySize {
                Spacer(minLength: Spacing.tight)
            }
            HStack(spacing: Spacing.hairline) {
                if let symbol = state.symbol {
                    Image(systemName: symbol)
                        .imageScale(.small)
                }
                Text(state.text(now: now))
                    .monospacedDigit()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

extension Card {
    /// What the speaker says: the question if it is Greek, else the answer if that is.
    @MainActor var spokenText: String? {
        if GreekSpeech.shared.canSpeak(question) { return question }
        let head = answer.prefix { !$0.isNewline }
        return GreekSpeech.shared.canSpeak(String(head)) ? String(head) : nil
    }
}
