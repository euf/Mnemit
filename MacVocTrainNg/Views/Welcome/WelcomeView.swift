import AppKit
import SwiftUI
import VocabCore

/// The Mac's Today, the window of the welcome: reads the Mnemit folder, the day's ring over its decks and their
/// counts, and hands them to `TodayWindowContent`, which draws them. Reads again whenever the window comes to the
/// front and once a minute, as the day turns.
struct WelcomeView: View {
    private var folder = DeckFolder.shared
    @State private var recent = NSDocumentController.shared.recentDocumentURLs
    @State private var ring = DailyRingModel()
    @State private var counts = KnownDeckCounts()
    @State private var query = ""
    @State private var search = AllCardsSearch()
    /// The medals of earlier days this Mac never celebrated, earned on the iPhone, say, once as toasts.
    @State private var toasts = MedalToasts()
    /// The month's screen, shown on the first open of a new month after a month with study, as on the iPhone.
    @State private var monthRecap: MonthRecap?
    @AppStorage("shownMonthRecap") private var shownMonthRecap = ""

    var body: some View {
        TodayWindowContent(
            folder: folder.url, decks: folder.decks, recent: recent, progress: ring.progress, counts: counts.counts, paused: counts.paused,
            isRead: counts.isRead, now: Date(), chooseFolder: { folder.choose() }, study: study, query: $query,
            hits: search.hits(for: query), isSearching: !search.isLoaded, showCard: { WelcomeRequest.requestCard($0.card, of: $0.deck.url) }
        )
        // The decks are read for the search once there is something to search for, and again after they may have changed.
        .task(id: query.isEmpty) {
            if !query.isEmpty { await search.load(folder.decks.map(KnownDeck.init(url:))) }
        }
        .medalToast(toasts)
        .onChange(of: ring.progress) {
            toasts.offer(ring.progress, earlierDays: true)
            showMonthRecapIfDue()
        }
        .sheet(item: $monthRecap) { recap in
            MonthRecapSheet(recap: recap) {
                monthRecap = nil
                ProgressWindow.show()
            } done: {
                monthRecap = nil
            }
        }
        .onAppear(perform: refresh)
        // The decks may have changed while the window was behind others.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in refresh() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                refresh()
            }
        }
    }

    /// Opens the decks of the day and starts one stream over all of them, as the iPhone's Study does: in the window
    /// of the deck used last, mixing the others in, each card from the deck whose next card is most urgent. Study
    /// and Catch Up take the decks with cards left; Push On every active deck, as each may give new cards.
    private func study(_ action: DayAction) {
        let active = folder.decks.filter { !counts.paused.contains($0) }
        let used = recent.map(\.standardizedFileURL)
        let byUse = active.sorted { (used.firstIndex(of: $0.standardizedFileURL) ?? .max) < (used.firstIndex(of: $1.standardizedFileURL) ?? .max) }
        let decks = action == .pushOn ? byUse : byUse.filter { (counts.counts[$0]?.total ?? 0) > 0 }
        guard let first = decks.first else { return }
        WelcomeRequest.requestStudy(of: first, entry: action == .pushOn ? .pushOn : .study, with: Array(decks.dropFirst()))
    }

    /// The month's screen once, on the first open of a month after a month with study; never in a test run.
    private func showMonthRecapIfDue() {
        guard monthRecap == nil, !GreekSpeech.isUnderTest, let progress = ring.progress,
            let recap = MonthRecapPlan.pending(records: progress.records, calendar: StudyCalendar(), shown: shownMonthRecap)
        else { return }
        shownMonthRecap = MonthRecapPlan.key(year: recap.year, month: recap.month)
        monthRecap = recap
    }

    /// Reads the folder, the day's ring over its decks and their counts, the open decks as their documents have them.
    private func refresh() {
        folder.refresh()
        search.invalidate()
        if !query.isEmpty { Task { await search.load(folder.decks.map(KnownDeck.init(url:))) } }
        recent = NSDocumentController.shared.recentDocumentURLs
        let urls = folder.decks
        Task {
            await ring.refreshAllDecks(reloadFiles: true, delay: .zero).value
            await counts.refresh(urls)
        }
    }
}

/// What the Today window shows, from what it is given, so a test can draw it: the day over every deck of the
/// folder on the left, as the iPhone's Today has it (`TodayHero`: the ring with the streak, what the day asks next,
/// the words in memory), and the one button of the day (`DayAction`: Study, Catch Up or Learn 10 New Words); the decks with
/// what today's plan takes from each on the right. Before the learner chose the folder, the app's name and the ways in.
struct TodayWindowContent: View {
    var folder: URL?
    var decks: [URL]
    var recent: [URL]
    var progress: DailyProgress?
    var counts: [URL: StudyCounts]
    var paused: Set<URL>
    var isRead: Bool
    var now: Date
    var chooseFolder: () -> Void
    var study: (DayAction) -> Void
    /// What the search field holds; the cards it finds over every deck of the folder, which a click shows in the
    /// deck's window.
    var query: Binding<String> = .constant("")
    var hits: [AllCardsSearch.Hit] = []
    var isSearching = false
    var showCard: (AllCardsSearch.Hit) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if folder == nil {
                    welcome
                } else {
                    today
                }
            }
            .frame(width: 340)
            Divider()
            VStack(spacing: 0) {
                if folder != nil {
                    TextField("Search All Cards", text: query, prompt: Text("Search All Cards"))
                        .textFieldStyle(.roundedBorder)
                        .padding([.horizontal, .top], Spacing.margin)
                        .padding(.bottom, Spacing.tight)
                }
                if query.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty {
                    deckList
                } else {
                    results
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary.opacity(0.5))
        }
        .frame(width: 760, height: 460)
    }

    // MARK: The day

    /// The decks the day counts: those of the folder that are not paused.
    private var active: [URL] { decks.filter { !paused.contains($0) } }

    /// The cards left of today's plan, all decks.
    private var due: Int { active.reduce(0) { $0 + (counts[$1]?.total ?? 0) } }

    private var isDayReady: Bool { progress != nil && isRead }

    private var action: DayAction { isDayReady ? DayAction(due: due, progress: progress) : .study }

    private var today: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            // The hero is a button, as on the iPhone: it opens Progress. Until the Today page replaces this window
            // (`references/quality-plan.md` §5.1) it is a small ring without the week.
            Button(action: ProgressWindow.show) {
                TodayHero(
                    due: due, progress: isDayReady ? progress : nil, nextDue: counts.values.compactMap(\.nextDue).min(), now: now,
                    isLoaded: isDayReady, ringSize: 96, showsWeek: false
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Progress")
            .disabled(progress == nil)
            Button {
                study(action)
            } label: {
                Text(action.title)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(action == .study ? Color.appAccent : .secondary)
            .controlSize(.extraLarge)
            .keyboardShortcut(.defaultAction)
            .disabled(active.isEmpty)
            Spacer(minLength: 0)
            ways
        }
        .padding(Spacing.section)
    }

    // MARK: Before the folder

    private var welcome: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 88, height: 88)
                .accessibilityHidden(true)
            Text(verbatim: "Mnemit")
                .font(.system(size: 30, weight: .bold))
            Text("Remember a little every day")
                .foregroundStyle(.secondary)
            Text("Version \(version)")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Button(action: chooseFolder) {
                Text("Open Mnemit Folder…")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(width: 240)
            .padding(.top, 20)
            ways
                .padding(.top, Spacing.tight)
            Spacer()
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    /// The other ways in, as links: the same on both sides of the folder.
    private var ways: some View {
        VStack(alignment: folder == nil ? .center : .leading, spacing: Spacing.hairline) {
            if folder != nil {
                Button("Choose Mnemit Folder…", action: chooseFolder)
            }
            Button("New Deck") { NSDocumentController.shared.newDocument(nil) }
            Button("Import Cards…", action: importCards)
            Button("Open Deck…") { NSDocumentController.shared.openDocument(nil) }
            Button("Shared Decks on AnkiWeb…") { DeckWebWindow.show() }
        }
        .buttonStyle(.link)
    }

    // MARK: The decks

    private var deckList: some View {
        List {
            if let folder {
                Section {
                    ForEach(decks, id: \.self) { deck in
                        DeckRow(name: deck.deletingPathExtension().lastPathComponent, subtitle: subtitle(of: deck), count: counts[deck]?.total) {
                            DeckFolder.open(deck)
                        }
                        .contextMenu { deckMenu(deck) }
                    }
                } header: {
                    Text("Decks in “\(folder.lastPathComponent)”")
                }
            }
            if !others.isEmpty {
                Section {
                    ForEach(others, id: \.self) { deck in
                        DeckRow(name: deck.deletingPathExtension().lastPathComponent, subtitle: Text(verbatim: deck.deletingLastPathComponent().lastPathComponent)) {
                            DeckFolder.open(deck)
                        }
                    }
                } header: {
                    Text("Recent Decks")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .overlay {
            if folder == nil, recent.isEmpty {
                ContentUnavailableView {
                    Label("No Decks Yet", systemImage: "rectangle.stack")
                } description: {
                    Text("Open your Mnemit folder to see the decks in it, or import cards from a table.")
                }
            }
        }
    }

    /// What the iPhone's swipe and menu on a deck row do: study the deck alone, pause or resume it, and here also
    /// show it in Finder.
    @ViewBuilder
    private func deckMenu(_ deck: URL) -> some View {
        let isPaused = paused.contains(deck)
        Button("Study This Deck", systemImage: "play.rectangle") {
            WelcomeRequest.requestStudy(of: deck, entry: (counts[deck]?.total ?? 0) > 0 ? .study : .pushOn)
        }
        .disabled(isPaused)
        Button(isPaused ? "Resume Deck" : "Pause Deck", systemImage: isPaused ? "play.circle" : "pause.circle") {
            WelcomeRequest.requestPause(of: deck, isPaused: !isPaused)
        }
        Divider()
        Button("Show in Finder", systemImage: "folder") {
            NSWorkspace.shared.activateFileViewerSelecting([deck])
        }
    }

    /// The cards the search found, each with its deck; a click shows the card in its deck's window.
    private var results: some View {
        List(hits) { hit in
            Button {
                showCard(hit)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.gap) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hit.question)
                            .lineLimit(2)
                        Text(hit.answer.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? hit.answer)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: Spacing.tight)
                    Text(hit.deck.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 2)
        }
        .scrollContentBackground(.hidden)
        .overlay {
            if isSearching {
                ProgressView()
            } else if hits.isEmpty {
                ContentUnavailableView.search(text: query.wrappedValue)
            }
        }
    }

    /// What today's plan takes from the deck, "4 new · 10 review"; when nothing, the next review; "Paused" for a
    /// paused deck; nothing until it is read.
    private func subtitle(of deck: URL) -> Text? {
        if paused.contains(deck) { return Text("Paused") }
        guard let deckCounts = counts[deck] else { return nil }
        if deckCounts.total > 0 { return Text(verbatim: deckCounts.parts) }
        return deckCounts.nextDue.map { Text("Next review \(Format.due($0, now: now))") }
    }

    /// The recent decks that the folder doesn't list already.
    private var others: [URL] {
        recent.filter { deck in decks.allSatisfy { $0.standardizedFileURL != deck.standardizedFileURL } }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    /// Imports into a new deck, which the learner saves after: the import starts as its
    /// window opens, see `DocumentView`.
    private func importCards() {
        WelcomeRequest.requestImportCards()
        NSDocumentController.shared.newDocument(nil)
    }
}

/// A deck of the list: its name, what today asks of it, and the cards left or a checkmark; a click opens it.
private struct DeckRow: View {
    var name: String
    var subtitle: Text?
    var count: Int?
    var open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.stack")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: name)
                        .fontWeight(.semibold)
                    if let subtitle {
                        subtitle
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                Spacer()
                if let count {
                    if count > 0 {
                        Text(count, format: .number)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }
}
