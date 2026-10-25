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

    var body: some View {
        TodayWindowContent(
            folder: folder.url, decks: folder.decks, recent: recent, progress: ring.progress, counts: counts.counts, paused: counts.paused,
            isRead: counts.isRead, now: Date(), chooseFolder: { folder.choose() }, study: study
        )
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

    /// Opens the deck the day goes on with and starts its stream there: the deck with cards left that was used
    /// last, or the first; for Push On the deck used last.
    private func study(_ action: DayAction) {
        let active = folder.decks.filter { !counts.paused.contains($0) }
        let used = recent.map(\.standardizedFileURL)
        let byUse = active.sorted { (used.firstIndex(of: $0.standardizedFileURL) ?? .max) < (used.firstIndex(of: $1.standardizedFileURL) ?? .max) }
        let deck = action == .pushOn ? byUse.first : byUse.first { (counts.counts[$0]?.total ?? 0) > 0 }
        guard let deck else { return }
        WelcomeRequest.requestStudy(of: deck, entry: action == .pushOn ? .pushOn : .study)
    }

    /// Reads the folder, the day's ring over its decks and their counts, the open decks as their documents have them.
    private func refresh() {
        folder.refresh()
        recent = NSDocumentController.shared.recentDocumentURLs
        let urls = folder.decks
        Task {
            await ring.refreshAllDecks(reloadFiles: true, delay: .zero).value
            await counts.refresh(urls)
        }
    }
}

/// What the Today window shows, from what it is given, so a test can draw it: the day over every deck of the
/// folder on the left, as the iPhone's Today has it (`SummaryRow`: the ring with the streak, what the day asks next,
/// the words in memory), and the one button of the day (`DayAction`: Study, Catch Up or Push On); the decks with
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
            deckList
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
            // The day is a button with a chevron, as on the iPhone: it opens Progress.
            Button(action: ProgressWindow.show) {
                HStack(spacing: Spacing.gap) {
                    SummaryRow(
                        due: due, newDue: active.reduce(0) { $0 + (counts[$1]?.newAtDayStart ?? 0) }, progress: isDayReady ? progress : nil,
                        nextDue: counts.values.compactMap(\.nextDue).min(), now: now, isLoaded: isDayReady, ringSize: 80
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Progress")
            .disabled(progress == nil)
            VStack(spacing: Spacing.hairline) {
                Button {
                    study(action)
                } label: {
                    Text(action.title)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(action == .study ? nil : .secondary)
                .controlSize(.extraLarge)
                .keyboardShortcut(.defaultAction)
                .disabled(active.isEmpty)
                if action == .pushOn {
                    Text("More reviews in the days ahead")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
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
