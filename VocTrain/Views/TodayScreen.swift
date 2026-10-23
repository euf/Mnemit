import SwiftUI
import VocabCore

/// What the Study button runs: every deck with cards due, one stream after the other, or
/// one deck.
enum StudyScope: Hashable {
    case all
    case deck(URL)
}

/// Today: the root of the app. The day in rounds over all decks, the cards done and left of today's
/// plan, the daily ring, the streak and the words in memory, the decks with what today's plan takes from
/// each, and Study. A tap on Study shows the
/// first card at once; a tap on a deck opens its screen. The search finds a card in any deck.
///
/// A paused deck (`LearningOptions.isPaused`) is no part of the day: it sits in a section of its own at the
/// bottom, without counts, and Study leaves it out.
///
/// Shows what it is given and holds no state but the search text it is bound to, so the
/// snapshot test can render it, see `StartScreen` for where the figures come from.
struct TodayScreen: View {
    var decks: [KnownDeck]
    /// What today's plan takes from each deck; a deck missing here is not read yet, or can't be, or is paused.
    var counts: [URL: StudyCounts]
    /// The decks that were read as paused.
    var paused: Set<URL> = []
    /// `nil` until evaluated.
    var progress: DailyProgress?
    var now: Date
    /// What the search field holds.
    @Binding var query: String
    /// The cards that match `query`, over all decks.
    var hits: [AllCardsSearch.Hit]
    /// Whether the decks are being read for the search.
    var isSearching: Bool
    /// Whether the deck can be taken off the list, which it can't in the folder: the list
    /// would take it up again.
    var canForget: (KnownDeck) -> Bool
    var study: (StudyScope) -> Void
    /// Push On from Today, once the day's stack is done: ten new cards from all the decks, at once.
    var pushOn: () -> Void = {}
    var showDeck: (KnownDeck) -> Void
    var showCard: (AllCardsSearch.Hit) -> Void
    var forget: (KnownDeck) -> Void
    /// Pauses the deck, or resumes it.
    var setPaused: (KnownDeck, Bool) -> Void = { _, _ in }
    var addCards: () -> Void
    var newDeck: () -> Void
    var chooseFolder: () -> Void
    var openDeck: () -> Void
    var showSettings: () -> Void
    /// Pushes the Progress screen: the header of the day is its button.
    var showProgress: () -> Void = {}
    var refresh: () async -> Void
    var importCards: () -> Void = {}
    /// Opens the browser of the shared decks.
    var showAnkiWeb: () -> Void = {}

    /// The medals earned on earlier days and not celebrated yet, say on the Mac, come once as a toast over the list.
    @State private var toasts = MedalToasts()

    /// Whether the decks were read: until then the figures are placeholders.
    private var isRead: Bool {
        !counts.isEmpty || !paused.isEmpty
    }

    /// Whether the day can be told at once: every deck read and the ring evaluated. They come in on their
    /// own, so until both are there the header holds its placeholders, and it changes once instead of
    /// going from "All done" to "Ring closed · 3 left" as each figure arrives.
    private var isDayReady: Bool {
        progress != nil && decks.allSatisfy { counts[$0.url] != nil } && (!decks.isEmpty || !paused.isEmpty)
    }

    /// The cards left of today's plan, all decks: every card due, overdue ones included.
    private var due: Int {
        decks.reduce(0) { $0 + (counts[$1.url]?.total ?? 0) }
    }

    /// Of `due`, the cards that were new when the day began, which the time left prices as new.
    private var newDue: Int {
        decks.reduce(0) { $0 + (counts[$1.url]?.newAtDayStart ?? 0) }
    }

    var body: some View {
        Group {
            if decks.isEmpty {
                ContentUnavailableView {
                    Label("No Decks", systemImage: "rectangle.stack")
                } description: {
                    Text("Make a deck for the words you are learning, or use the Mnemit folder in iCloud Drive to find the decks you have.")
                } actions: {
                    VStack(spacing: Spacing.gap) {
                        Button(action: newDeck) {
                            Text("New Deck").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        Button(action: chooseFolder) {
                            Text("Use iCloud Drive Folder").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        AnkiWebLink(action: showAnkiWeb)
                            .padding(.top, Spacing.hairline)
                    }
                    .controlSize(.large)
                    .frame(maxWidth: 320)
                }
            } else {
                // One view carries the search field, so it keeps its focus as the first letter
                // turns the list into the results.
                Group {
                    if query.trimmingCharacters(in: .whitespaces).isEmpty {
                        list
                    } else {
                        results
                    }
                }
                .searchable(text: $query, prompt: Text("Search All Cards"))
            }
        }
        .navigationTitle("Today")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu("Add", systemImage: "plus") {
                    Button("Add Cards", systemImage: "plus.rectangle.on.rectangle", action: addCards)
                        .disabled(decks.isEmpty)
                    Button("Import…", systemImage: "square.and.arrow.down", action: importCards)
                        .disabled(decks.isEmpty)
                    AnkiWebLink(action: showAnkiWeb)
                    Button("New Deck", systemImage: "rectangle.stack.badge.plus", action: newDeck)
                }
                Menu("More", systemImage: "ellipsis") {
                    Button("Choose Mnemit Folder…", systemImage: "folder", action: chooseFolder)
                    Button("Open Deck…", systemImage: "doc", action: openDeck)
                    Divider()
                    Button("Settings", systemImage: "gearshape", action: showSettings)
                }
            }
        }
    }

    /// Queues the medals of earlier days this device never celebrated, once the day is shown.
    private func celebrateMissedMedals() {
        if isDayReady { toasts.offer(progress, earlierDays: true) }
    }

    private var list: some View {
        List {
            Section {
                // A button with the chevron of the deck rows, which draw it by hand too.
                Button(action: showProgress) {
                    HStack(spacing: 12) {
                        SummaryRow(
                            due: due, newDue: newDue, progress: isDayReady ? progress : nil,
                            nextDue: counts.values.compactMap(\.nextDue).min(), now: now, isLoaded: isDayReady
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
                .disabled(progress == nil)
            }
            let sections = TodayDecks(decks, paused: paused)
            if !sections.active.isEmpty {
                Section("Decks") {
                    ForEach(sections.active) { deck in
                        DeckRow(name: deck.name, counts: counts[deck.url], now: now) { showDeck(deck) }
                            .swipeActions(allowsFullSwipe: !canForget(deck)) {
                                pauseButton(deck, pausing: true)
                                removeButton(deck)
                            }
                            .contextMenu { pauseButton(deck, pausing: true) }
                    }
                }
            }
            if !sections.paused.isEmpty {
                Section("Paused") {
                    ForEach(sections.paused) { deck in
                        DeckRow(name: deck.name, counts: nil, now: now, isPaused: true) { showDeck(deck) }
                            .swipeActions(allowsFullSwipe: !canForget(deck)) {
                                pauseButton(deck, pausing: false)
                                removeButton(deck)
                            }
                            .contextMenu { pauseButton(deck, pausing: false) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await refresh() }
        .onChange(of: progress, initial: true) { celebrateMissedMedals() }
        .onChange(of: isDayReady) { celebrateMissedMedals() }
        .medalToast(toasts)
        .safeAreaBar(edge: .bottom) {
            StudyButton(stage: isDayReady ? DayAction(due: due, progress: progress) : .study, due: due) { stage in
                stage == .pushOn ? pushOn() : study(.all)
            }
            .disabled(TodayDecks(decks, paused: paused).active.isEmpty)
        }
    }

    /// "Pause Deck", or "Resume Deck" for a deck that is paused.
    @ViewBuilder
    private func pauseButton(_ deck: KnownDeck, pausing: Bool) -> some View {
        if pausing {
            Button("Pause Deck", systemImage: "pause.circle") { setPaused(deck, true) }
                .tint(.indigo)
        } else {
            Button("Resume Deck", systemImage: "play.circle") { setPaused(deck, false) }
                .tint(.indigo)
        }
    }

    @ViewBuilder
    private func removeButton(_ deck: KnownDeck) -> some View {
        if canForget(deck) {
            Button("Remove from List", systemImage: "minus.circle", role: .destructive) { forget(deck) }
        }
    }

    /// The cards the search found, each with its deck when there is more than one.
    private var results: some View {
        List(hits) { hit in
            Button {
                showCard(hit)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hit.question)
                            .lineLimit(2)
                        Text(hit.answer.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? hit.answer)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    if decks.count > 1 {
                        Text(hit.deck.name)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .overlay {
            if isSearching {
                ProgressView()
            } else if hits.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }
}

/// The one button of the screen, named after what it does next, with the words of the rests: **Study** while the
/// ring is open, the one prominent button; **Catch Up** once the ring is closed and the plan has cards left;
/// **Push On** once the day's stack is done, ten new cards at once, with what they cost under it.
struct StudyButton: View {
    var stage: DayAction
    var due: Int
    /// What the button says while the ring is open.
    var studyTitle: LocalizedStringKey = "Study"
    var action: (DayAction) -> Void

    private var title: LocalizedStringKey { stage == .study ? studyTitle : stage.title }

    var body: some View {
        let label = Button {
            action(stage)
        } label: {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        VStack(spacing: Spacing.hairline) {
            Group {
                if stage == .study {
                    label.buttonStyle(.glassProminent)
                } else {
                    label.buttonStyle(.glass)
                }
            }
            .controlSize(.large)
            if stage == .pushOn {
                Text("More reviews in the days ahead")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .accessibilityValue(due > 0 ? Text("\(due) cards left") : Text(verbatim: ""))
    }
}

/// A deck: its name, what today's plan takes from it, the total, and the overdue cards the plan
/// leaves for the days after; a tap opens its screen.
/// The chevron is drawn by hand, as the row is a button, not a `NavigationLink`: the deck has
/// to be opened before the push, see `PushedDecks`.
///
/// A paused deck has no counts: its name and "Paused" in the secondary colour.
struct DeckRow: View {
    var name: String
    var counts: StudyCounts?
    var now: Date
    var isPaused = false
    var open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .foregroundStyle(isPaused ? .secondary : .primary)
                    if let subtitle {
                        subtitle
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    } else if counts == nil {
                        // Until the deck is read: the line it will have, so the row doesn't grow and the list jump.
                        Text("\(0) new · \(0) learning · \(0) review")
                            .font(.subheadline)
                            .redacted(reason: .placeholder)
                    }
                }
                Spacer(minLength: 0)
                if let counts {
                    if counts.total > 0 {
                        Text(counts.total, format: .number)
                            .monospacedDigit()
                    } else {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.secondary)
                    }
                }
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var subtitle: Text? {
        if isPaused { return Text("Paused") }
        guard let counts else { return nil }
        if counts.total > 0 {
            return Text(verbatim: counts.parts)
        }
        return counts.nextDue.map { Text("Next review \(Format.due($0, now: now))") }
    }
}
