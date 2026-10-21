import SwiftUI
import VocabCore

/// The root of the app: Today (`TodayScreen`) with the decks it has opened (#288), what is
/// due and the daily ring. The app starts here, not in the deck it showed last: Study and a
/// deck row each show the first card with one tap. Decks it doesn't know yet open through the
/// file picker, or from the Files app, and join the list.
///
/// The learner can also choose the folder that holds the decks: every deck in it is
/// listed, and pulling the list down looks for new ones. At the first launch the
/// introduction covers the screen, `OnboardingView`; Settings brings it back. The daily
/// reminder and the number on the app icon follow the counts, see `Reminders`.
///
/// A study stream covers the screen (`StudyRunView`); the info button of a row opens the
/// deck's details in a sheet (`DeckDetailsSheet`).
struct StartScreen: View {
    @State private var knownDecks = KnownDecks()
    @State private var deckCounts = KnownDeckCounts()
    @State private var reminders = Reminders()
    /// Today's reviews against the goal and the streak, over all known decks.
    @State private var ring = DailyRingModel()
    /// Keeps what the home-screen widget shows up to date, see `WidgetSync`.
    @State private var widget = WidgetSync()
    @State private var run: StudyRun?
    @State private var details: OpenDeck?
    /// A stream started from the details: it covers the screen once the sheet has gone.
    @State private var pendingRun: StudyRun?
    @State private var isChoosing = false
    @State private var choosesFolder = false
    @State private var showsSettings = false
    @State private var showsIntroduction = false
    @State private var wantsIntroduction = false
    @AppStorage("IntroductionSeen") private var hasSeenIntroduction = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            TodayScreen(
                decks: knownDecks.byName, counts: deckCounts.counts, progress: ring.progress, now: Date(),
                canForget: { !knownDecks.isInFolder($0.url) }, study: study, showDetails: showDetails,
                forget: { knownDecks.forget($0.url) }, chooseFolder: { choose(folder: true) },
                openDeck: { choose(folder: false) }, showSettings: { showsSettings = true }, refresh: refreshAll)
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
        .sheet(item: $details, onDismiss: startPendingRun) { deck in
            DeckDetailsSheet(deck: deck, knownCounts: deckCounts.counts[deck.url]) { entry in
                pendingRun = StudyRun(deck: deck, entry: entry)
                details = nil
            }
        }
        .fullScreenCover(item: $run) { run in
            StudyRunView(run: run, ring: ring, knownDecks: knownDecks, counts: deckCounts.counts) { self.run = nil }
        }
        .fullScreenCover(isPresented: $showsIntroduction) {
            OnboardingView(knownDecks: knownDecks, reminders: reminders, onFinish: finishIntroduction)
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
                    // The deck saves what it changed before the list reads the file.
                    await previous.close()
                    await refreshAll()
                }
            }
        }
        .onChange(of: details) { previous, current in
            // A stream started from the details takes the deck over, and closes it.
            if current == nil, let previous, pendingRun?.deck !== previous {
                Task {
                    await previous.close()
                    await refreshCounts()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                run?.deck.suspend()
                details?.suspend()
                reminders.rescheduleBeforeSuspending(decks: knownDecks.byName, open: run?.deck)
                if let inputs = widgetInputs { widget.flushBeforeSuspending(inputs) }
            case .active:
                run?.deck.resume()
                details?.resume()
            default: break
            }
        }
        .onChange(of: widgetTrigger) { syncWidget() }
        .onChange(of: reminders.isEnabled) { Task { await rescheduleReminders() } }
        .onChange(of: reminders.minutes) { Task { await rescheduleReminders() } }
        // At launch and whenever the app comes back to the front. A deck that is open shows
        // its own figures, and Today reads again once it is closed.
        .task(id: scenePhase) {
            if scenePhase == .active, run == nil, details == nil {
                await refreshAll()
            }
            if scenePhase == .active { syncWidget() }
        }
    }

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

    /// The decks with cards due, the one studied last first and the others in the order of the
    /// list. With nothing due, the deck studied last alone: its stream rests at once and offers
    /// to go on. Before the decks are read every deck counts as due.
    private func queue() -> [URL] {
        let urls = knownDecks.byName.map(\.url)
        let isRead = !deckCounts.counts.isEmpty
        var due = urls.filter { deckCounts.counts[$0].map { $0.total > 0 } ?? !isRead }
        let last = knownDecks.last.flatMap { last in urls.first { KnownDecks.isSameFile($0, last) } }
        if let last, let index = due.firstIndex(of: last) {
            due.insert(due.remove(at: index), at: 0)
        }
        if due.isEmpty, let rest = last ?? urls.first {
            return [rest]
        }
        return due
    }

    private func showDetails(_ deck: KnownDeck) {
        guard details == nil, run == nil else { return }
        details = OpenDeck(url: deck.url)
    }

    private func startPendingRun() {
        if let pendingRun {
            run = pendingRun
            self.pendingRun = nil
        }
    }

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
        let isCovered = showsSettings || details != nil || isChoosing
        showsSettings = false
        details = nil
        isChoosing = false
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
        let open = run?.deck
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
        await reminders.reschedule(decks: knownDecks.byName, open: run?.deck)
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
