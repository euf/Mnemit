import SwiftUI
import VocabCore

/// What the Study button runs: every deck with cards due, one stream after the other, or
/// one deck.
enum StudyScope: Hashable {
    case all
    case deck(URL)
}

/// Today: the root of the app. The Today card (`TodayCard`: the daily ring, its figures Day streak, the next moment and
/// Words learned, and the week) as the first section of the list, the decks under it with the cards left of today's plan in
/// each, and Study. The date of the study day is the navigation subtitle. A tap on Study shows the first card at once; a tap
/// on a deck opens its screen; the card opens Progress. The search finds a card in any deck.
///
/// A paused deck (`LearningOptions.isPaused`) is no part of the day's plan: it sits in a section of its own at the
/// bottom, without counts, Study leaves it out, and the ring doesn't wait for it.
///
/// Shows what it is given and holds no state but the search text it is bound to, so the
/// snapshot test can render it, see `StartScreen` for where the figures come from.
struct TodayScreen: View {
    var decks: [KnownDeck]
    /// What today's plan takes from each deck; a deck missing here is not read yet, or can't be, or is paused.
    var counts: [URL: StudyCounts]
    /// The decks that were read as paused.
    var paused: Set<URL> = []
    /// The decks that can't be read, with why (`KnownDeckCounts.failed`): their rows say it.
    var failed: [URL: String] = [:]
    /// Whether the Mnemit folder can't be reached (`KnownDecks.folderLost`): Today says it and asks for the folder again.
    var folderLost = false
    /// `nil` until evaluated.
    var progress: DailyProgress?
    /// A streak that ended, told under the card once (`EndedStreak`).
    var endedStreak: EndedStreak?
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
    /// Learn 10 New Words from Today, once the day's stack is done: ten new cards from all the decks, at once.
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
    @State var toasts = MedalToasts()

    /// Whether the decks were read: until then the figures are placeholders.
    private var isRead: Bool {
        !counts.isEmpty || !paused.isEmpty
    }

    /// Whether the day can be told at once: every deck read and the ring evaluated. They come in on their
    /// own, so until both are there the header holds its placeholders, and it changes once instead of
    /// going from a closed ring to an open one as each figure arrives.
    private var isDayReady: Bool {
        progress != nil && TodayDecks(decks, paused: paused).isRead(counts, failed: failed) && (!decks.isEmpty || !paused.isEmpty)
    }

    /// The cards left of today's plan, all decks: every card due, overdue ones included.
    private var due: Int {
        decks.reduce(0) { $0 + (counts[$1.url]?.total ?? 0) }
    }

    var body: some View {
        Group {
            if decks.isEmpty {
                empty
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
                .searchToolbarBehavior(.minimize)
                .toolbar {
                    // Study with Search All Cards minimised beside it: one bottom bar, not two.
                    ToolbarItem(placement: .bottomBar) { studyButton }
                    ToolbarSpacer(.fixed, placement: .bottomBar)
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                }
            }
        }
        .navigationTitle("Today")
        .todaySubtitle(now)
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

    /// No deck yet: the card with the empty ring and what to do, over the ways to get one, buttons in the content, not glass.
    private var empty: some View {
        ScrollView {
            VStack(spacing: Spacing.section) {
                if folderLost {
                    // A new deck would have no folder to go to: the one way on is the folder.
                    LostFolderCard(choose: chooseFolder)
                        .background(Color.tileGround, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                } else {
                    emptyActions
                }
            }
            .padding(Spacing.margin)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private var emptyActions: some View {
        EmptyTodayCard()
            .background(Color.tileGround, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        VStack(spacing: Spacing.gap) {
            Button(action: newDeck) {
                Text("New Deck").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appAccent)
            Button(action: showAnkiWeb) {
                Text("Shared Decks").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            Button("Use iCloud Drive Folder", action: chooseFolder)
                .font(.footnote)
                .controlSize(.regular)
                .padding(.top, Spacing.hairline)
        }
        .controlSize(.large)
    }

    /// Queues the medals of earlier days this device never celebrated, once the day is shown.
    private func celebrateMissedMedals() {
        if isDayReady { toasts.offer(progress, earlierDays: true) }
    }

    private var list: some View {
        List {
            if folderLost {
                Section {
                    LostFolderCard(choose: chooseFolder)
                }
            }
            Section {
                // The list's own card; the whole of it is a button to Progress, its week row ends in the chevron the deck rows draw too.
                TodayCard(progress: isDayReady ? progress : nil, now: now, isLoaded: isDayReady, open: progress == nil ? nil : showProgress)
                    .listRowInsets(EdgeInsets())
            } footer: {
                if let endedStreak { StreakEndedNote(streak: endedStreak) }
            }
            let sections = TodayDecks(decks, paused: paused)
            if !sections.active.isEmpty {
                Section("Decks") {
                    ForEach(sections.active) { deck in
                        DeckRow(name: deck.name, counts: counts[deck.url], pace: progress?.pace, failure: failed[deck.url]) { showDeck(deck) }
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
                        DeckRow(name: deck.name, counts: nil, isPaused: true) { showDeck(deck) }
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
        .medalToast(toasts, at: .title)
    }

    /// The day's one action, in the bottom bar beside the search: named by what it does next, prominent while the
    /// ring is open.
    private var studyButton: some View {
        let stage = isDayReady ? DayAction(due: due, progress: progress) : .study
        return Button {
            stage == .pushOn ? pushOn() : study(.all)
        } label: {
            Text(stage.title)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                // The bar sizes its items to their content: the button takes the width the search button and its gap leave
                // (the bar's 291 pt at 375 pt: 211 for the button, room for "Learn 10 New Words" at 17 pt in one line).
                .containerRelativeFrame(.horizontal) { width, _ in max(180, width - 80) }
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.appAccent)
        .disabled(TodayDecks(decks, paused: paused).active.isEmpty)
        .accessibilityValue(due > 0 ? Text("\(due) cards left") : Text(verbatim: ""))
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

/// A deck: its name and what is left of today's plan in it, "≈ 4 min", a ✓ when nothing is; a tap opens its screen.
/// The chevron is drawn by hand, as the row is a button, not a `NavigationLink`: the deck has
/// to be opened before the push, see `PushedDecks`.
///
/// A paused deck has no counts: its name in the secondary colour, in the section "Paused".
struct DeckRow: View {
    var name: String
    var counts: StudyCounts?
    /// The day's pace, which prices the cards; `nil` until the ring is evaluated.
    var pace: Pace?
    var isPaused = false
    /// Why the deck has no figures: it can't be read. The row says it under the name, with a warning sign for the time.
    var failure: String?
    var open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .foregroundStyle(isPaused ? .secondary : .primary)
                    if let failure {
                        Text(failure)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if failure != nil {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                } else if let counts {
                    if counts.isDone {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.secondary)
                    } else if let minutes = DeckMinutes.minutes(counts, pace: pace) {
                        Text(verbatim: Format.timeLeft(minutes: minutes))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    } else {
                        Text(verbatim: Format.timeLeft(minutes: 2))
                            .redacted(reason: .placeholder)
                    }
                } else if !isPaused {
                    // Until the deck is read: the time it will have.
                    Text(verbatim: Format.timeLeft(minutes: 2))
                        .redacted(reason: .placeholder)
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
}
