import AppKit
import Combine
import Observation
import SwiftUI
import VocabCore

/// The Mac's one window, as a model: what the sidebar lists, what it selects, the decks held open for the
/// pages and for the stream, and the stream that takes the whole window (§5.13 of the quality plan).
///
/// The decks are the iPhone's `OpenDeck`s in the `OpenDecks` registry: a deck opens when it is selected or
/// studied and stays open until the app quits, a deck is renamed or it is deleted, so its undo steps
/// survive a switch to another deck and a stream always runs on the deck a page shows.
@MainActor @Observable
final class Shell {
    static let shared = Shell()

    enum Item: Hashable {
        case today
        case progress
        case deck(URL)
    }

    /// What a deck's page shows under the strip: its cards, or its statistics.
    enum DeckScreen: String, CaseIterable {
        case cards, statistics
    }

    /// What the menus and the strip ask a deck's page for: a sheet.
    enum DeckRequest: Hashable {
        case options, addCards, importCards
        /// The cards of a file that made this deck, as the learner chose it before the deck existed.
        case importFile(ImportFile)
    }

    /// What Study runs over.
    enum Scope {
        /// The day: every deck with cards left, one stream, as the iPhone's Today.
        case day
        case deck(URL)
    }

    let folder: DeckFolder
    let decks: OpenDecks
    let counts = KnownDeckCounts()
    /// The one ring of the window, over every deck (`AllDecks`).
    let ring = DailyRingModel()
    let search = AllCardsSearch()
    /// The cheat sheet of the stream's keys; it watches the keys of the window.
    let shortcuts = ShortcutsHelp()

    /// Decks opened from outside the folder, until the app quits.
    private(set) var others: [URL] = []
    private(set) var selection = Item.today
    var screen = DeckScreen.cards
    /// A card Search All Cards asked the table to show.
    var shownCard: Card.ID?
    var request: DeckRequest?
    /// Whether the sheet that names a new deck is up.
    var isNamingDeck = false
    /// Whether the cards' inspector is open; View ▸ Show Inspector and the toolbar's button turn it on and off.
    var showsInspector = false
    /// Brings the window forward, opening it again after ⌘W; the window sets it once it is there.
    @ObservationIgnored var showWindow: () -> Void = { NSApp.activate() }
    /// What the search field holds; the cards it finds are in `hits`.
    var query = "" {
        didSet {
            if query != oldValue { shownCard = nil }
        }
    }
    /// `.all` or `.detailOnly`, never `.automatic`: after `.detailOnly` the split view keeps the sidebar hidden on
    /// `.automatic`, so Done would not bring it back.
    private(set) var columnVisibility = NavigationSplitViewVisibility.all
    /// Why a change of a deck from the sidebar failed, for an alert.
    var notice: String?

    /// The stream and the decks it runs over, from the click on Study until Done. `session` is there once
    /// every deck is read.
    private(set) var run: StudyRun?
    private(set) var session: SessionViewModel?
    private(set) var runFailure: String?
    private(set) var nextDeck: NextDeck?

    /// Counts up whenever what the sidebar and the pages read from the open decks may have changed.
    private(set) var revision = 0

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var subscriptions: [String: AnyCancellable] = [:]
    @ObservationIgnored private var visibilityBeforeStudy = NavigationSplitViewVisibility.all

    static let lastStudiedKey = "LastStudiedDeck"

    init(folder: DeckFolder = .shared, decks: OpenDecks = .shared, defaults: UserDefaults = .standard) {
        self.folder = folder
        self.decks = decks
        self.defaults = defaults
    }

    // MARK: - The decks

    /// Every deck the day counts: those of the folder, then those opened from elsewhere.
    var known: [URL] { folder.decks + others }

    /// The URL by which the sidebar lists the deck at `url`, however it is spelled; `nil` for a deck it doesn't list.
    func listed(_ url: URL) -> URL? {
        let key = OpenDecks.key(url)
        return known.first { OpenDecks.key($0) == key }
    }

    /// The deck at `url`, opened if it isn't yet, and watched so the sidebar follows its changes.
    @discardableResult
    func deck(for url: URL) -> OpenDeck {
        let deck = decks.open(url)
        watch(deck)
        return deck
    }

    var selectedURL: URL? {
        if case let .deck(url) = selection { url } else { nil }
    }

    var selectedDeck: OpenDeck? {
        selectedURL.flatMap { decks.deck(for: $0) }
    }

    private func watch(_ deck: OpenDeck) {
        let key = OpenDecks.key(deck.url)
        guard subscriptions[key] == nil else { return }
        subscriptions[key] = AnyCancellable {}
        Task { [weak self, weak deck] in
            guard let deck, let document = await deck.editableDocument(), let self, self.subscriptions[key] != nil else { return }
            self.subscriptions[key] = document.deckDidChange.sink { [weak self] _ in self?.deckDidChange() }
            self.revision += 1
        }
    }

    private func deckDidChange() {
        revision += 1
        ring.refreshAllDecks(decks: decks, folder: folder)
    }

    /// Saves and closes the deck, before its file is renamed or deleted.
    private func forget(_ url: URL) async {
        subscriptions.removeValue(forKey: OpenDecks.key(url))
        await decks.close(url)
    }

    // MARK: - Selecting

    /// Selects a page, opening the deck of a deck's page. While a stream runs, the window shows nothing else.
    func select(_ item: Item) {
        guard run == nil, item != selection else { return }
        selection = item
        shownCard = nil
        if case let .deck(url) = item {
            deck(for: url)
        }
    }

    /// Shows the Cards or the Statistics of the selected deck.
    func showScreen(_ screen: DeckScreen) {
        guard run == nil, selectedURL != nil else { return }
        self.screen = screen
    }

    /// Finder, the Dock or File ▸ Open hands over decks: a deck of the folder is selected, one from elsewhere
    /// joins the Other Decks until the app quits and is selected.
    func open(_ urls: [URL]) {
        for url in urls {
            if listed(url) == nil {
                others.append(url.standardizedFileURL)
            }
        }
        if let last = urls.last, let listed = listed(last) {
            select(.deck(listed))
        }
        refresh(reload: false)
    }

    /// The card a hit of Search All Cards found, in its deck's table.
    func showCard(_ hit: AllCardsSearch.Hit) {
        guard run == nil, let url = listed(hit.deck.url) else { return }
        query = ""
        select(.deck(url))
        screen = .cards
        shownCard = hit.card
    }

    // MARK: - What the day says

    /// Whether the deck is paused, as its document has it when it is open, else as its file read.
    func isPaused(_ url: URL) -> Bool {
        _ = revision
        if let document = decks.deck(for: url)?.document { return document.deck.learningOptions.isPaused }
        return counts.paused.contains(url)
    }

    /// What today's plan takes from the deck: the open document's, with the reviews not saved yet, else what
    /// the file says; `nil` before it is read and for a paused deck.
    func studyCounts(_ url: URL) -> StudyCounts? {
        _ = revision
        if let document = decks.deck(for: url)?.document { return document.deck.learningOptions.isPaused ? nil : document.dueCards.counts }
        return counts.counts[url]
    }

    /// The decks of the day and the paused ones.
    var dayDecks: TodayDecks {
        TodayDecks(known.map(KnownDeck.init(url:)), paused: Set(known.filter(isPaused)))
    }

    /// The cards left of today's plan, over the decks of the day.
    var due: Int {
        dayDecks.active.reduce(0) { $0 + (studyCounts($1.url)?.total ?? 0) }
    }

    /// Whether the day can be told: the ring is worked out for today and the decks are read.
    var isDayReady: Bool {
        ring.progress != nil && !ring.isStale && counts.isRead
    }

    var dayAction: DayAction {
        isDayReady ? DayAction(due: due, progress: ring.progress) : .study
    }

    var hits: [AllCardsSearch.Hit] {
        search.hits(for: query)
    }

    var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Reads the folder, the ring over all decks and the counts of the decks that are not open.
    func refresh(reload: Bool = true) {
        folder.refresh()
        others.removeAll { url in folder.decks.contains { OpenDecks.key($0) == OpenDecks.key(url) } }
        search.invalidate()
        loadSearch()
        let urls = known
        Task {
            await ring.refreshAllDecks(decks: decks, folder: folder, reloadFiles: reload, delay: .zero).value
            await counts.refresh(urls)
            revision += 1
        }
    }

    /// Reads the decks for the search once there is something to search for.
    func loadSearch() {
        guard isSearching else { return }
        Task { await search.load(known.map(KnownDeck.init(url:))) }
    }

    // MARK: - Study

    private var lastStudied: URL? {
        defaults.string(forKey: Self.lastStudiedKey).flatMap { path in known.first { OpenDecks.key($0) == path } }
    }

    /// The decks the day's Study runs over: those with cards left, the one studied last first; Learn 10 New
    /// Words takes every deck of the day, as each may give new cards.
    func queue(for action: DayAction) -> [URL] {
        let day = dayDecks
        guard action == .pushOn else {
            let counts = known.reduce(into: [URL: StudyCounts]()) { $0[$1] = studyCounts($1) }
            return day.studyQueue(counts: counts, isRead: self.counts.isRead, last: lastStudied)
        }
        var urls = day.active.map(\.url)
        if let last = lastStudied, let index = urls.firstIndex(of: last) {
            urls.insert(urls.remove(at: index), at: 0)
        }
        return urls
    }

    /// Whether Study has a deck to run over.
    var canStudyDay: Bool { run == nil && !dayDecks.active.isEmpty }

    /// Starts the stream over the day or over one deck, and covers the window with it: Learn 10 New Words
    /// when nothing is left of the deck's plan, else Study. The stream starts once every deck is read.
    func study(_ scope: Scope, entry requested: SessionViewModel.Entry? = nil) {
        guard run == nil else { return }
        let urls: [URL]
        let entry: SessionViewModel.Entry
        switch scope {
        case let .deck(url):
            urls = [url]
            entry = requested ?? ((studyCounts(url)?.total ?? 1) > 0 ? .study : .pushOn)
        case .day:
            let action = dayAction
            urls = queue(for: action)
            entry = action == .pushOn ? .pushOn : .study
        }
        guard let first = urls.first else { return }
        defaults.set(OpenDecks.key(first), forKey: Self.lastStudiedKey)
        let run = StudyRun(deck: deck(for: first), entry: entry, upcoming: Array(urls.dropFirst()), ownsDeck: false) { [unowned self] in deck(for: $0) }
        self.run = run
        runFailure = nil
        visibilityBeforeStudy = columnVisibility
        columnVisibility = .detailOnly
        Task { await begin(run) }
    }

    /// Opens the stream once every deck of the run is read or failed.
    private func begin(_ run: StudyRun) async {
        var ready: [VocabularyDocument] = []
        for deck in run.decks {
            if let document = await deck.editableDocument() { ready.append(document) }
        }
        guard self.run === run else { return }
        guard !ready.isEmpty else {
            runFailure = run.decks.compactMap(\.failure).first ?? String(localized: "The deck could not be read.")
            return
        }
        let model = SessionViewModel(documents: ready, entry: run.entry, ring: ring)
        // A practice with nothing to practise doesn't open.
        guard run.entry == .study || run.entry == .pushOn || !model.isResting else { return endStudy() }
        session = model
        for deck in run.decks { deck.merger.isInSession = true }
        shortcuts.showForFirstSession()
    }

    /// Done: the stream goes, the sidebar comes back and the figures are read again.
    func endStudy() {
        session = nil
        nextDeck = nil
        runFailure = nil
        let finished = run
        for deck in finished?.decks ?? [] { deck.merger.isInSession = false }
        run = nil
        columnVisibility = visibilityBeforeStudy
        Task { await finished?.close() }
        refresh()
    }

    /// At the rest at the end of the run's plan: another deck of the day with cards left, which Done leaves for.
    func updateNextDeck() {
        nextDeck = nil
        guard let session, let run, session.isResting, session.rest.roundEnd == nil, !session.rest.isPracticeOnly else { return }
        let inRun = Set(run.decks.map { OpenDecks.key($0.url) })
        guard let next = dayDecks.active.first(where: { !inRun.contains(OpenDecks.key($0.url)) && (studyCounts($0.url)?.total ?? 0) > 0 }) else { return }
        nextDeck = NextDeck(name: next.name, cards: studyCounts(next.url)?.total ?? 0) { [weak self] in self?.continue(with: next.url) }
    }

    /// Ends this stream and starts the one of the deck at `url`, with the sidebar still away.
    private func `continue`(with url: URL) {
        let saved = visibilityBeforeStudy
        for deck in run?.decks ?? [] { deck.merger.isInSession = false }
        session = nil
        nextDeck = nil
        run = nil
        study(.deck(url))
        visibilityBeforeStudy = saved
    }

    /// The sidebar's toggle, and the View menu's: not while the stream has the window.
    func setVisibility(_ visibility: NavigationSplitViewVisibility) {
        columnVisibility = run == nil ? visibility : .detailOnly
    }

    // MARK: - Changing decks

    /// Makes the deck `name` in the folder and shows it. A learner who has no folder yet chooses one first.
    @discardableResult
    func newDeck(named name: String) async throws -> URL {
        if folder.url == nil {
            folder.choose(requiringDecks: false)
        }
        guard let folderURL = folder.url else { throw CocoaError(.userCancelled) }
        let url = try await DeckFiles.create(named: name, in: folderURL)
        folder.refresh()
        if let listed = listed(url) { select(.deck(listed)) }
        refresh(reload: false)
        return url
    }

    /// Renames the deck's file, which closes the deck first and opens it again under its new name.
    func rename(_ url: URL, to name: String) async throws {
        guard run == nil else { return }
        let wasSelected = selectedURL == url
        await forget(url)
        do {
            let renamed = try await DeckFiles.rename(url, to: name)
            if let index = others.firstIndex(of: url) {
                others[index] = renamed.standardizedFileURL
            }
            folder.refresh()
            if wasSelected {
                selection = .today
                if let listed = listed(renamed) { select(.deck(listed)) }
            }
        } catch {
            if wasSelected {
                selection = .today
                select(.deck(url))
            }
            throw error
        }
        refresh(reload: false)
    }

    /// Moves the deck's file to the Trash, which closes the deck first.
    func delete(_ url: URL) async throws {
        guard run == nil else { return }
        let wasSelected = selectedURL == url
        await forget(url)
        do {
            try await DeckFiles.trash(url)
        } catch {
            if wasSelected {
                selection = .today
                select(.deck(url))
            }
            throw error
        }
        others.removeAll { OpenDecks.key($0) == OpenDecks.key(url) }
        folder.refresh()
        if wasSelected { selection = .today }
        refresh(reload: false)
    }

    /// Pauses or resumes the deck from the sidebar: the deck is opened, changed through its document and
    /// stays open.
    func setPaused(_ url: URL, _ isPaused: Bool) async {
        guard run == nil, let document = await deck(for: url).editableDocument() else {
            notice = String(localized: "The deck could not be opened")
            return
        }
        document.setPaused(isPaused)
        revision += 1
        refresh(reload: false)
    }

    /// Saves and closes every open deck, when the app quits.
    func closeAll() async {
        subscriptions = [:]
        await decks.closeAll()
    }

    // MARK: - Undo

    /// The undo manager Edit ▸ Undo goes to: the selected deck's, whose steps survive a switch to another
    /// page. Today, Progress and the stream have none (the stream's ⌘Z is its own button).
    var undoManagerForWindow: UndoManager? {
        run == nil ? selectedDeck?.undoManager : nil
    }
}
