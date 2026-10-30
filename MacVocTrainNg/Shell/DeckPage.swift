import SwiftUI
import VocabCore

/// A deck's page: what its open deck shows once it is read, a spinner before, and why a deck failed to open.
struct DeckPage: View {
    var deck: OpenDeck
    var shell: Shell

    var body: some View {
        Group {
            if let document = deck.document {
                DeckPageContent(
                    document: document, isEditable: deck.isEditable, pace: shell.ring.progress?.pace, screen: Binding(get: { shell.screen }, set: { shell.showScreen($0) }),
                    showsInspector: Binding(get: { shell.showsInspector }, set: { shell.showsInspector = $0 }),
                    shownCard: shell.shownCard, request: Binding(get: { shell.request }, set: { shell.request = $0 }),
                    start: { shell.study(.deck(deck.url), entry: $0) }
                )
                // The deck opened: its parameters are fitted again if it is due, in the background and never into a stream.
                .task(id: deck.isEditable && document.isReadyToEdit) {
                    guard deck.isEditable, document.isReadyToEdit else { return }
                    await ParameterRefitter.refit(document) { shell.session == nil }
                }
            } else if let failure = deck.failure {
                ContentUnavailableView("The deck could not be opened", systemImage: "exclamationmark.triangle", description: Text(failure))
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .alert("Another version of this deck could not be merged", isPresented: isShowingFailure, presenting: deck.merger.failure) { _ in
        } message: { failure in
            Text(failure)
        }
    }

    private var isShowingFailure: Binding<Bool> {
        Binding {
            deck.merger.failure != nil
        } set: { isShowing in
            if !isShowing { deck.merger.failure = nil }
        }
    }
}

/// What a deck's page shows of a deck, from a document so a test can host it: the strip with the deck's Today card and Study
/// This Deck over the table of cards or the statistics, and in the toolbar the switch between them, Add Cards, Learning
/// Options and Study This Deck again. The sheets of the deck, its options, an import and Add Cards, come up from here.
struct DeckPageContent: View {
    @ObservedObject var document: VocabularyDocument
    /// `false` while the deck can only be viewed: nothing then changes it or starts a stream.
    var isEditable: Bool
    /// The day's pace, which prices the plan left as "≈ 4 min"; `nil` until the ring is worked out.
    var pace: Pace?
    @Binding var screen: Shell.DeckScreen
    /// Whether the cards' inspector is open, for View ▸ Show Inspector.
    @Binding var showsInspector: Bool
    /// A card Search All Cards asked the table to show.
    var shownCard: Card.ID?
    /// A sheet the menus and the strip ask for; taken at once.
    @Binding var request: Shell.DeckRequest?
    var start: (SessionViewModel.Entry) -> Void

    @State private var showingOptions = false
    @State private var addingCards = false
    @State private var importPreview: CardImport.Preview?
    /// Whether an import file is being read: an Anki package takes a while.
    @State private var isReadingImport = false
    @State private var toast: Toast?
    /// Whether Add Cards came up by itself for this page's empty deck, once, as on the iPhone.
    @State private var offeredAddCards = false
    /// The cards a sheet asked to study first, which the stream takes up once the sheet has gone.
    @State private var studyAfterSheet: [Card.ID]?

    private var canEdit: Bool { isEditable && document.isReadyToEdit }

    var body: some View {
        // The strip is a bar over the page's content, in the table's own top bar on Cards: an NSTableView that is not
        // flush with its pane draws its scroll edge effect over the views above it (macOS 26, seen live 26.10).
        Group {
            switch screen {
            case .cards:
                CardListView(
                    document: document, isEditable: canEdit, shownCard: shownCard, addCards: { addingCards = true }, inspector: $showsInspector,
                    header: AnyView(stripBar))
            case .statistics:
                StatisticsView(document: document)
                    .safeAreaBar(edge: .top, spacing: 0) { stripBar }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $screen) {
                    Text("Cards").tag(Shell.DeckScreen.cards)
                    Text("Statistics").tag(Shell.DeckScreen.statistics)
                }
                .pickerStyle(.segmented)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Add Cards", systemImage: "text.badge.plus") { addingCards = true }
                    .help("Add Cards…")
                    .disabled(!canEdit)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Learning Options", systemImage: "slider.horizontal.3") { showingOptions = true }
                    .help("Learning Options")
                    .disabled(!canEdit)
            }
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) { studyButton }
        }
        .sheet(isPresented: $showingOptions) {
            DeckOptionsView(document: document)
        }
        .sheet(item: $importPreview, onDismiss: studyAddedCards) { preview in
            ImportPreviewView(document: document, preview: preview) { studyAfterSheet = $0 }
        }
        .sheet(isPresented: $addingCards, onDismiss: studyAddedCards) {
            AddCardsView(
                document: document,
                onAdded: { count in toast = Toast(String(localized: "Added \(count) cards. Meaning → Word comes once a word is learned.")) },
                studyNow: { studyAfterSheet = $0 })
        }
        .overlay {
            if isReadingImport {
                ProgressView("Reading cards…")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                ToastView(toast: toast) { self.toast = nil }
            }
        }
        .animation(.easeOut(duration: 0.2), value: toast)
        .onChange(of: request, initial: true) { takeRequest() }
        .onChange(of: canEdit, initial: true) { takeRequest() }
        // An empty deck has one thing to do: a new deck goes straight on to its first cards.
        .onChange(of: canEdit && document.deck.cards.isEmpty, initial: true) { _, isEmpty in
            guard isEmpty, !offeredAddCards else { return }
            offeredAddCards = true
            addingCards = true
        }
    }

    /// The deck's Today card and its one button: the time and the counts of today's plan, Done with the next review or
    /// Paused, and Study This Deck, or Learn 10 New Words once nothing is left.
    private var stripBar: some View {
        VStack(spacing: 0) {
            strip
            Divider()
        }
    }

    private var strip: some View {
        let isPaused = document.deck.learningOptions.isPaused
        let counts = document.dueCards.counts
        let now = document.clock.now
        let headline = DeckHeadline(counts: counts, pace: pace, isPaused: isPaused, hasCards: !document.deck.cards.isEmpty, now: now)
        return HStack(spacing: Spacing.gap) {
            if let headline {
                DeckTodayCard(headline: headline, counts: counts, pace: pace, isPaused: isPaused, now: now)
            }
            Spacer()
            studyButton
                .controlSize(.large)
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.vertical, Spacing.gap)
    }

    /// Study This Deck while cards are due, Learn 10 New Words when nothing is: in the strip and in the toolbar.
    private var studyButton: some View {
        let isDue = document.dueCards.counts.total > 0
        return Button {
            start(isDue ? .study : .pushOn)
        } label: {
            Text(isDue ? "Study This Deck" : "Learn 10 New Words")
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.appAccent)
        .disabled(!canEdit || document.deck.cards.isEmpty)
    }

    /// Study These Now: the sheet has gone, the stream of this deck puts the cards it added first.
    private func studyAddedCards() {
        guard let ids = studyAfterSheet else { return }
        studyAfterSheet = nil
        start(.studyNow(ids))
    }

    /// Opens the sheet a menu or the strip asked for, once the deck can be changed.
    private func takeRequest() {
        guard canEdit, let asked = request else { return }
        request = nil
        switch asked {
        case .options: showingOptions = true
        case .addCards: addingCards = true
        case .importCards: importCards()
        case let .importFile(file):
            // The deck was made for these cards: its own first sheet is their preview, not Add Cards.
            offeredAddCards = true
            importCards(from: file)
        }
    }

    /// Asks for a file, or takes `file`, the one this empty deck was made for, and shows its cards to choose from.
    private func importCards(from file: ImportFile? = nil) {
        guard !isReadingImport, let url = file?.url ?? CardImport.chooseFile() else { return }
        isReadingImport = true
        Task {
            defer { isReadingImport = false }
            guard let preview = await CardImport.preview(ofFileAt: url, for: document, isNewDeck: file != nil, package: file?.package) else { return }
            importPreview = preview
        }
    }
}
