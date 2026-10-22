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
    var refresh: () async -> Void
    var importCards: () -> Void = {}
    /// Opens the browser of the shared decks.
    var showAnkiWeb: () -> Void = {}

    /// Whether the decks were read: until then the figures are placeholders.
    private var isRead: Bool {
        !counts.isEmpty || !paused.isEmpty
    }

    /// The cards left of today's plan, all decks: its share of the backlog included, never the backlog.
    private var due: Int {
        decks.reduce(0) { $0 + (counts[$1.url]?.total ?? 0) }
    }

    /// Of `due`, the cards that were new when the day began, which the time left prices as new.
    private var newDue: Int {
        decks.reduce(0) { $0 + (counts[$1.url]?.newAtDayStart ?? 0) }
    }

    /// The catch-up, the overdue review cards the plan leaves for the days after.
    private var catchUp: Int {
        decks.reduce(0) { $0 + (counts[$1.url]?.catchUp ?? 0) }
    }

    var body: some View {
        Group {
            if decks.isEmpty {
                ContentUnavailableView {
                    Label("No Decks", systemImage: "rectangle.stack")
                } description: {
                    Text("Make a deck for the words you are learning, or use the Mnemit folder in iCloud Drive to find the decks you have.")
                } actions: {
                    Button("New Deck", action: newDeck)
                        .buttonStyle(.borderedProminent)
                    Button("Use iCloud Drive Folder", action: chooseFolder)
                    Button("Open Deck…", action: openDeck)
                    AnkiWebLink(action: showAnkiWeb)
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
            ToolbarItem(placement: .topBarLeading) {
                HowTodayWorksButton(decks: decks, now: now)
            }
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

    private var list: some View {
        List {
            Section {
                SummaryRow(
                    due: due, newDue: newDue, catchUp: catchUp, progress: progress, nextDue: counts.values.compactMap(\.nextDue).min(),
                    now: now, isLoaded: isRead)
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
        .safeAreaBar(edge: .bottom) {
            StudyButton(isDue: due > 0 || !isRead, due: due) { study(.all) }
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

/// The one prominent button of the screen. With nothing due it is not prominent: Keep Going
/// opens the stream at its rest, which offers review ahead and new cards.
struct StudyButton: View {
    /// Whether to study: cards are due, or the decks are not read yet.
    var isDue: Bool
    var due: Int
    /// What the button says while cards are due.
    var title: LocalizedStringKey = "Study"
    var action: () -> Void

    var body: some View {
        let label = Button(action: action) {
            Text(isDue ? title : "Keep Going")
                .frame(maxWidth: .infinity)
        }
        Group {
            if isDue {
                label.buttonStyle(.glassProminent)
            } else {
                label.buttonStyle(.glass)
            }
        }
        .controlSize(.large)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .accessibilityValue(due > 0 ? Text("\(due) cards left") : Text(verbatim: ""))
    }
}

/// The day in rounds and the cards done and left of today's plan, the daily ring, the streak and the
/// words in memory, and the catch-up the plan leaves for the days after.
struct SummaryRow: View {
    /// The cards of the plan not done yet, "N cards left": not the cards that are due in all.
    var due: Int
    /// Of `due`, the cards that were new when the day began.
    var newDue = 0
    /// The overdue review cards beyond today's share of the backlog.
    var catchUp = 0
    var progress: DailyProgress?
    /// When something comes back that today's plans leave out.
    var nextDue: Date?
    var now: Date
    /// `false` until the decks are read: the figures are placeholders then.
    var isLoaded: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title2) private var diameter = 72

    var body: some View {
        let layout =
            typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 16))
        // The words in memory take the width of the row under the ring: beside it, on a 375 pt screen, "+15 today"
        // would not fit on the line of the words.
        VStack(alignment: .leading, spacing: 8) {
            layout {
                ProgressRing(fraction: progress?.ring.fraction ?? 0, diameter: min(diameter, 96), center: RingCenter(progress, inStream: false))
                VStack(alignment: .leading, spacing: 2) {
                    headline
                        .font(.title2.weight(.semibold))
                    detail
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if catchUp > 0 {
                        Text("+\(catchUp) to catch up this week")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let progress, progress.streak.days > 0 {
                        // Not a Label: in a list it puts its icon in a column of its own.
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(progress.streakKeptToday ? Color.accentColor : Color.secondary)
                            Group {
                                if progress.streakKeptToday {
                                    Text("\(progress.streak.days)-day streak · kept today")
                                } else {
                                    Text("\(progress.streak.days)-day streak")
                                }
                            }
                            .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
                .monospacedDigit()
            }
            if let memory = progress?.memory {
                MemoryLine(memory: memory)
                    .font(.subheadline)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 8)
        .redacted(reason: isLoaded ? [] : .placeholder)
        .accessibilityElement(children: .combine)
    }

    /// "≈ 7 min": the cards left at the learner's pace, new cards and others each at its own, once the decks are read.
    private var timeLeft: String? {
        guard let progress, let minutes = DailyGoal.minutesLeft(newCards: newDue, otherCards: due - newDue, pace: progress.pace) else { return nil }
        return Format.timeLeft(minutes: minutes)
    }

    /// What the day asks next, in rounds: "≈ 2 min to keep your streak" before the first, "Round 2 of 4 · ≈ 2
    /// min" after it, "Ring closed" once they are done. Without rounds, which is before the decks are read, the
    /// cards left, and nothing at all once none is left.
    @ViewBuilder
    private var headline: some View {
        let status = progress.map(RoundStatus.init)
        if due > 0, let title = status?.title {
            if let time = status?.time {
                // "Round 2 of 4 · ≈ 2 min", the time under it where the line is too long.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(title)
                        Text(verbatim: "· " + time)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(title)
                        Text(verbatim: time)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(title)
            }
        } else if due > 0 {
            let cardsLeft = Text("\(due) cards left")
            if let timeLeft {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        cardsLeft
                        Text(verbatim: "· " + timeLeft)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        cardsLeft
                        Text(verbatim: timeLeft)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                cardsLeft
            }
        } else if let ring = progress?.ring, ring.done > 0 {
            Text("All done")
        } else {
            Text("Nothing due")
        }
    }

    /// "12 of 24 cards · 12 left": the done cards against the goal, and what is left of the plan.
    @ViewBuilder
    private var detail: some View {
        if let ring = progress?.ring, due > 0 {
            Text(verbatim: [String(localized: "\(ring.done) of \(ring.goal) cards"), String(localized: "\(due) left")].joined(separator: " · "))
        } else if let ring = progress?.ring, ring.done > 0 {
            Text("\(ring.done) cards today")
        } else if due == 0, let nextDue {
            Text("Next review \(Format.due(nextDue, now: now))")
        }
    }
}

/// "≈ 28 words in memory · +15 today" on one line, or on the day a milestone was passed "50 words in memory!"
/// with a glyph in the accent: the accent is never small text. Where the line is too long, at a large type size,
/// it is one text that wraps, not the gain stacked under the words.
struct MemoryLine: View {
    var memory: MemoryEstimate

    var body: some View {
        if let milestone = memory.milestoneLine {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.accentColor)
                Text(milestone)
                    .fontWeight(.semibold)
            }
        } else if let line = memory.line {
            Text(verbatim: line)
                .foregroundStyle(.secondary)
        }
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
                    }
                    if let catchUp = counts?.catchUp, catchUp > 0 {
                        Text("+\(catchUp) to catch up this week")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
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
            return Text("\(counts.new) new · \(counts.learning) learning · \(counts.review) review")
        }
        return counts.nextDue.map { Text("Next review \(Format.due($0, now: now))") }
    }
}
