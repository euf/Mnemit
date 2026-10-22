import SwiftUI
import VocabCore

/// The root of the app: Today (`TodayScreen`) with the decks it has opened (#288), what is
/// due and the daily ring. The app starts here, not in the deck it showed last: Study and a
/// deck's Study This Deck each show the first card with one tap. Decks it doesn't know yet open
/// through the file picker, or from the Files app, and join the list.
///
/// The learner can also choose the folder that holds the decks: every deck in it is
/// listed, and pulling the list down looks for new ones. At the first launch the
/// introduction covers the screen, `OnboardingView`; Settings brings it back. The daily
/// reminder and the number on the app icon follow the counts, see `Reminders`.
///
/// A tap on a deck pushes its screen (`DeckScreen`) on the stack of Today, and a card the
/// search found pushes the card. The decks of the stack are held open by `PushedDecks`: opened
/// when the route is pushed, closed once it has left the path. A study stream covers the screen
/// (`StudyRunView`); one started from a deck's screen studies the deck the screen holds.
struct StartScreen: View {
    @State private var knownDecks = KnownDecks()
    @State private var deckCounts = KnownDeckCounts()
    @State private var reminders = Reminders()
    /// Today's reviews against the goal and the streak, over all known decks.
    @State private var ring = DailyRingModel()
    /// Keeps what the home-screen widget shows up to date, see `WidgetSync`.
    @State private var widget = WidgetSync()
    @State private var run: StudyRun?
    @State private var path: [DeckRoute] = []
    @State private var pushed = PushedDecks()
    @State private var search = AllCardsSearch()
    @State private var query = ""
    /// The deck whose Add Cards sheet is up, from the + menu.
    @State private var addingCards: OpenDeck?
    /// The file the + menu's Import… picked, which the sheet of `addingCards` shows the cards of;
    /// `nil` for Add Cards.
    @State private var fileToImport: ImportedFile?
    @State private var isChoosingImport = false
    @State private var showsNewDeck = false
    /// The deck a new deck's sheet leaves to push once it has gone.
    @State private var openAfterSheet: PushedDecks.Slot?
    /// The name of a deck that was set aside instead of going to the Trash.
    @State private var setAsideDeck: String?
    @State private var isChoosing = false
    @State private var choosesFolder = false
    @State private var showsSettings = false
    @State private var showsIntroduction = false
    @State private var wantsIntroduction = false
    @AppStorage("IntroductionSeen") private var hasSeenIntroduction = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack(path: $path) {
            TodayScreen(
                decks: knownDecks.byName, counts: deckCounts.counts, progress: ring.progress, now: Date(), query: $query,
                hits: search.hits(for: query), isSearching: !search.isLoaded,
                canForget: { !knownDecks.isInFolder($0.url) }, study: study, showDeck: showDeck, showCard: showCard,
                forget: { knownDecks.forget($0.url) }, addCards: { openLastDeck(importing: nil) }, newDeck: { showsNewDeck = true },
                chooseFolder: { choose(folder: true) }, openDeck: { choose(folder: false) },
                showSettings: { showsSettings = true }, refresh: refreshAll, importCards: { isChoosingImport = true }
            )
            // Not on the stack, which has the deck picker: two file pickers on a view cancel each other.
            .cardFileImporter(isPresented: $isChoosingImport) { openLastDeck(importing: $0) }
            .navigationDestination(for: DeckRoute.self, destination: destination)
        }
        .deckPicker(isPresented: $isChoosing, choosesFolder: choosesFolder) { url in
            if url.isDeck {
                add(deckAt: url)
            } else if knownDecks.chooseFolder(url) > 0 {
                Task { await refreshCounts() }
            }
        }
        // The introduction covers the screen once the sheet has gone.
        .sheet(isPresented: $showsSettings, onDismiss: showIntroductionAfterSettings) {
            SettingsView(reminders: reminders) { wantsIntroduction = true }
        }
        .sheet(isPresented: $showsNewDeck, onDismiss: openNewDeck) {
            NewDeckSheet(onCreate: createDeck)
        }
        .sheet(item: $addingCards) { deck in
            AddCardsHost(deck: deck, file: fileToImport)
        }
        .fullScreenCover(item: $run) { run in
            StudyRunView(run: run, ring: ring, knownDecks: knownDecks, counts: deckCounts.counts) { self.run = nil }
        }
        .fullScreenCover(isPresented: $showsIntroduction) {
            OnboardingView(knownDecks: knownDecks, reminders: reminders, onFinish: finishIntroduction)
        }
        .alert("Deck Moved", isPresented: Binding(get: { setAsideDeck != nil }, set: { if !$0 { setAsideDeck = nil } })) {
            Button("OK") {}
        } message: {
            Text("This place has no Trash, so “\(setAsideDeck ?? "")” was moved to the folder “\(DeckFiles.setAsideFolderName)” next to it. Files can put it back.")
        }
        .onOpenURL(perform: open)
        .onAppear {
            if !hasSeenIntroduction {
                showsIntroduction = true
            }
        }
        .onChange(of: run) { previous, current in
            if current == nil, let previous {
                Task {
                    if previous.ownsDeck {
                        // The deck saves what it changed before the list reads the file.
                        await previous.close()
                        await refreshAll()
                    } else {
                        // The screen that holds the deck goes on with it: the reviews of the
                        // stream are not for its Undo.
                        previous.deck.undoManager.removeAllActions()
                    }
                }
            }
        }
        .onChange(of: path) {
            Task {
                // What has left the path saves and closes; back on Today, the lists read the files.
                await pushed.close(except: Set(path.map(\.slot)))
                if path.isEmpty {
                    search.invalidate()
                    await refreshAll()
                    await searchAgain()
                }
            }
        }
        .onChange(of: query) {
            Task { await searchAgain() }
        }
        .onChange(of: addingCards) { previous, current in
            if current == nil, let previous {
                Task {
                    await previous.close()
                    search.invalidate()
                    await refreshAll()
                    await searchAgain()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                run?.deck.suspend()
                pushed.suspend()
                addingCards?.suspend()
                reminders.rescheduleBeforeSuspending(decks: knownDecks.byName, open: openDeck)
                if let inputs = widgetInputs { widget.flushBeforeSuspending(inputs) }
            case .active:
                run?.deck.resume()
                pushed.resume()
                addingCards?.resume()
            default: break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            undoOnShake()
        }
        .onChange(of: widgetTrigger) { syncWidget() }
        .onChange(of: reminders.isEnabled) { Task { await rescheduleReminders() } }
        .onChange(of: reminders.minutes) { Task { await rescheduleReminders() } }
        // At launch and whenever the app comes back to the front. A deck that is open shows
        // its own figures, and Today reads again once it is closed.
        .task(id: scenePhase) {
            if scenePhase == .active, run == nil, path.isEmpty, addingCards == nil {
                await refreshAll()
            }
            if scenePhase == .active { syncWidget() }
        }
    }

    // MARK: Routes

    @ViewBuilder
    private func destination(_ route: DeckRoute) -> some View {
        PushedDeckView(pushed: pushed, slot: route.slot) { deck in
            switch route {
            case let .deck(slot):
                DeckScreen(
                    deck: deck, knownCounts: deckCounts.counts[deck.url], start: { studyDeck(deck, entry: $0) },
                    rename: { try await rename(slot, to: $0) }, delete: { try await trash(slot) })
            case let .card(_, id):
                CardHost(deck: deck, id: id)
            }
        }
    }

    private func showDeck(_ deck: KnownDeck) {
        guard run == nil else { return }
        path.append(.deck(pushed.open(deck.url)))
    }

    private func showCard(_ hit: AllCardsSearch.Hit) {
        guard run == nil else { return }
        path.append(.card(pushed.open(hit.deck.url), hit.card))
    }

    /// A shake takes back the last change of the deck on the screen, unless a sheet is up: it
    /// is for the sheet then, and the study stream has its own.
    private func undoOnShake() {
        guard UIApplication.shared.isShowingNoPresentation, let slot = path.last?.slot, let deck = pushed.deck(slot),
            deck.undoManager.canUndo
        else { return }
        deck.undoManager.undo()
    }

    // MARK: Study

    /// Starts the stream of one deck, or of every deck with cards due, one after the other.
    private func study(_ scope: StudyScope) {
        guard run == nil else { return }
        let urls: [URL]
        switch scope {
        case let .deck(url): urls = [url]
        case .all: urls = queue()
        }
        guard let first = urls.first else { return }
        run = StudyRun(deck: OpenDeck(url: first), upcoming: Array(urls.dropFirst()))
    }

    /// Starts the stream of the deck whose screen is open, on the deck the screen holds.
    private func studyDeck(_ deck: OpenDeck, entry: StudyModel.Entry) {
        guard run == nil else { return }
        run = StudyRun(deck: deck, entry: entry, ownsDeck: false)
    }

    /// The decks with cards due, the one studied last first and the others in the order of the
    /// list. With nothing due, the deck studied last alone: its stream rests at once and offers
    /// to go on. Before the decks are read every deck counts as due.
    private func queue() -> [URL] {
        let urls = knownDecks.byName.map(\.url)
        let isRead = !deckCounts.counts.isEmpty
        var due = urls.filter { deckCounts.counts[$0].map { $0.total > 0 } ?? !isRead }
        let last = lastUsed(in: urls)
        if let last, let index = due.firstIndex(of: last) {
            due.insert(due.remove(at: index), at: 0)
        }
        if due.isEmpty, let rest = last ?? urls.first {
            return [rest]
        }
        return due
    }

    /// The deck used last, as the list spells its file.
    private func lastUsed(in urls: [URL]) -> URL? {
        knownDecks.last.flatMap { last in urls.first { KnownDecks.isSameFile($0, last) } }
    }

    // MARK: Adding and creating

    /// Opens the sheet that adds cards to the deck used last, or to the first of the list: the
    /// sheet of Add Cards, or the preview of the `file` to import.
    private func openLastDeck(importing file: ImportedFile?) {
        guard run == nil, addingCards == nil, path.isEmpty else { return }
        let urls = knownDecks.byName.map(\.url)
        guard let url = lastUsed(in: urls) ?? urls.first else { return }
        knownDecks.remember(url)
        fileToImport = file
        addingCards = OpenDeck(url: url)
    }

    /// Makes the deck in the folder of decks, which is the app's own folder on the iPhone while the
    /// learner has chosen none, and prepares its screen: an empty deck is for adding cards.
    private func createDeck(named name: String) async throws {
        if knownDecks.folder == nil {
            knownDecks.useLocalFolder()
        }
        guard let folder = knownDecks.folder else { return }
        let url = try await DeckFiles.create(named: name, in: folder)
        knownDecks.remember(url)
        knownDecks.refreshFolder()
        openAfterSheet = pushed.open(url)
        showsNewDeck = false
    }

    /// The sheet of the new deck has gone: the deck's screen.
    private func openNewDeck() {
        if let slot = openAfterSheet {
            openAfterSheet = nil
            path = [.deck(slot)]
        }
    }

    // MARK: Renaming and deleting

    /// Gives the deck of `slot` a new name. The deck is closed for it, as the file is moved;
    /// it opens again at its new place, in the same slot, so its screen stays.
    private func rename(_ slot: PushedDecks.Slot, to name: String) async throws {
        guard let deck = pushed.deck(slot) else { return }
        let old = deck.url
        await pushed.close(slot)
        do {
            let new = try await DeckFiles.rename(old, to: name)
            knownDecks.replace(old, with: new)
            knownDecks.refreshFolder()
            pushed.reopen(slot, at: new)
        } catch {
            pushed.reopen(slot, at: old)
            throw error
        }
    }

    /// Moves the deck of `slot` to the Trash and goes back to Today. A place without a Trash
    /// keeps the deck in a folder of its own, which the learner is told.
    private func trash(_ slot: PushedDecks.Slot) async throws {
        guard let deck = pushed.deck(slot) else { return }
        let url = deck.url
        await pushed.close(slot)
        let outcome: DeckFiles.Trashed
        do {
            outcome = try await DeckFiles.trash(url)
        } catch {
            pushed.reopen(slot, at: url)
            throw error
        }
        knownDecks.forget(url)
        knownDecks.refreshFolder()
        path = []
        if case .setAside = outcome {
            setAsideDeck = deck.name
        }
    }

    // MARK: Lists

    private func choose(folder: Bool) {
        choosesFolder = folder
        isChoosing = true
    }

    /// A deck file the learner opened from the Files app joins the list; a link from the
    /// widget (`mnemit://study`) starts Study.
    private func open(_ url: URL) {
        guard WidgetLink.isStudy(url) else {
            add(deckAt: url)
            return
        }
        // The introduction comes first, and there are no decks before it.
        guard hasSeenIntroduction else { return }
        Task { await studyFromWidget() }
    }

    /// One tap on the widget is the first card: what covers Today closes first, the decks are
    /// read if the app has just started, and then Study runs as from its button.
    private func studyFromWidget() async {
        let isCovered = showsSettings || addingCards != nil || showsNewDeck || isChoosing || !path.isEmpty
        showsSettings = false
        addingCards = nil
        showsNewDeck = false
        isChoosing = false
        path = []
        if isCovered {
            try? await Task.sleep(for: .milliseconds(600))
        }
        if deckCounts.counts.isEmpty {
            await refreshAll()
        }
        study(.all)
    }

    /// A deck the learner opened with the picker or from the Files app joins the list.
    private func add(deckAt url: URL) {
        knownDecks.remember(url)
        Task { await refreshCounts() }
    }

    /// Looks for decks that arrived in the folder, then reads the counts and the ring.
    private func refreshAll() async {
        knownDecks.refreshFolder()
        await refreshCounts()
    }

    /// Reads the counts of every deck and the ring over them, and then sets the reminders by them.
    private func refreshCounts() async {
        ring.refresh(documents: [], files: knownDecks.byName.map(\.url), reloadFiles: true, delay: .zero)
        await deckCounts.refresh(knownDecks.byName)
        await rescheduleReminders()
    }

    /// Reads the cards of all decks for the search, while there is something to search for.
    private func searchAgain() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        await search.load(knownDecks.byName)
    }

    /// The deck that is open outside the lists, for the reminders: they count its cards as the
    /// document has them, not as the file does.
    private var openDeck: OpenDeck? {
        run?.deck ?? addingCards ?? pushed.openDecks.first
    }

    /// What the widget's snapshot depends on; a change asks for a new one.
    private struct WidgetTrigger: Equatable {
        var progress: DailyProgress?
        var decks: [KnownDeck]
        var counts: [URL: StudyCounts]
        var nextReminder: Date?
    }

    private var widgetTrigger: WidgetTrigger {
        WidgetTrigger(progress: ring.progress, decks: knownDecks.byName, counts: deckCounts.counts, nextReminder: reminders.nextFire)
    }

    /// `nil` before the ring is evaluated: the widget keeps its old figures until there are new.
    private var widgetInputs: WidgetSync.Inputs? {
        guard let progress = ring.progress else { return nil }
        let open = openDeck
        let decks = knownDecks.byName.map { known -> WidgetSync.Source in
            if let open, KnownDecks.isSameFile(open.url, known.url), let document = open.document {
                return .open(document.deck, document.calendar)
            }
            return .file(known.url)
        }
        return WidgetSync.Inputs(progress: progress, decks: decks, nextReminder: reminders.nextFire)
    }

    private func syncWidget() {
        if let inputs = widgetInputs { widget.request(inputs) }
    }

    private func rescheduleReminders() async {
        await reminders.reschedule(decks: knownDecks.byName, open: openDeck)
    }

    private func showIntroductionAfterSettings() {
        if wantsIntroduction {
            wantsIntroduction = false
            showsIntroduction = true
        }
    }

    private func finishIntroduction() {
        hasSeenIntroduction = true
        showsIntroduction = false
        Task { await refreshAll() }
    }
}
