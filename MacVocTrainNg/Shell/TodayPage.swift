import AppKit
import SwiftUI
import VocabCore

/// The Today page of the Mac's window, from what it is given so a test can draw it: the iPhone's hero at 200 pt, a
/// button to Progress, with the day's one button under it (`DayAction`: Study, Catch Up or Learn 10 New Words). Without
/// a deck, the empty ring and the ways to get one.
struct TodayPageContent: View {
    var hasDecks: Bool
    /// The cards of the plan not done yet, over the decks of the day.
    var due: Int
    var progress: DailyProgress?
    var nextDue: Date?
    var now: Date
    /// `false` until the ring and the decks are read: the figures are placeholders then.
    var isLoaded: Bool
    var action: DayAction
    var canStudy: Bool
    var study: () -> Void = {}
    var showProgress: () -> Void = {}
    var newDeck: () -> Void = {}
    var chooseFolder: () -> Void = {}
    var sharedDecks: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.section) {
                if hasDecks {
                    day
                } else {
                    empty
                }
            }
            .frame(maxWidth: 360)
            .padding(Spacing.section)
            .frame(maxWidth: .infinity)
        }
    }

    /// The hero is a button, as on the iPhone: it opens Progress.
    @ViewBuilder
    private var day: some View {
        Button(action: showProgress) {
            TodayHero(due: due, progress: isLoaded ? progress : nil, nextDue: nextDue, now: now, isLoaded: isLoaded, ringSize: 200, showsWeek: true)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Progress")
        .disabled(progress == nil)
        Button(action: study) {
            Text(action.title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(action == .study ? Color.appAccent : .secondary)
        .controlSize(.extraLarge)
        .keyboardShortcut(.defaultAction)
        .disabled(!canStudy)
    }

    /// No deck yet: the hero ring, empty, over the ways to get one.
    @ViewBuilder
    private var empty: some View {
        StreakHeroRing(fraction: 0, days: 0, state: .open, diameter: 200)
        Text("Make a deck for the words you are learning, or use the Mnemit folder in iCloud Drive to find the decks you have.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        VStack(spacing: Spacing.gap) {
            Button(action: newDeck) {
                Text("New Deck").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appAccent)
            Button(action: chooseFolder) {
                Text("Use iCloud Drive Folder").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            Button("Shared Decks on AnkiWeb…", action: sharedDecks)
                .buttonStyle(.link)
        }
        .controlSize(.large)
    }
}

/// The Today page: `TodayPageContent` over the shell's day, with Study in the toolbar (⌘L is the Study menu's), the
/// medals of earlier days as toasts and the month's recap.
struct TodayPage: View {
    var shell: Shell
    var newDeck: () -> Void
    /// The medals of earlier days this Mac never celebrated, earned on the iPhone, say, once as toasts.
    @State private var toasts = MedalToasts()
    /// The month's screen, shown on the first open of a new month after a month with study, as on the iPhone.
    @State private var monthRecap: MonthRecap?
    @AppStorage("shownMonthRecap") private var shownMonthRecap = ""

    var body: some View {
        let ring = shell.ring
        TodayPageContent(
            hasDecks: !shell.known.isEmpty, due: shell.due, progress: ring.progress, nextDue: shell.nextDue, now: Date(), isLoaded: shell.isDayReady,
            action: shell.dayAction, canStudy: shell.canStudyDay, study: { shell.study(.day) }, showProgress: { shell.select(.progress) },
            newDeck: newDeck, chooseFolder: chooseFolder, sharedDecks: { DeckWebWindow.show() }
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(shell.dayAction.title) { shell.study(.day) }
                    .buttonStyle(.borderedProminent)
                    .tint(shell.dayAction == .study ? Color.appAccent : .secondary)
                    .disabled(!shell.canStudyDay)
                    .help("Study today's plan")
            }
        }
        .medalToast(toasts)
        .onChange(of: ring.progress, initial: true) {
            toasts.offer(ring.progress, earlierDays: true)
            showMonthRecapIfDue()
        }
        .sheet(item: $monthRecap) { recap in
            MonthRecapSheet(recap: recap) {
                monthRecap = nil
                shell.select(.progress)
            } done: {
                monthRecap = nil
            }
        }
    }

    private func chooseFolder() {
        shell.folder.choose()
        shell.refresh()
    }

    /// The month's screen once, on the first open of a month after a month with study; never in a test run.
    private func showMonthRecapIfDue() {
        guard monthRecap == nil, !GreekSpeech.isUnderTest, let progress = shell.ring.progress,
            let recap = MonthRecapPlan.pending(records: progress.records, calendar: StudyCalendar(), shown: shownMonthRecap)
        else { return }
        shownMonthRecap = MonthRecapPlan.key(year: recap.year, month: recap.month)
        monthRecap = recap
    }
}

/// The cards Search All Cards found, each with its deck; a click shows the card in its deck's table.
struct SearchResults: View {
    var query: String
    var hits: [AllCardsSearch.Hit]
    var isSearching: Bool
    var showCard: (AllCardsSearch.Hit) -> Void

    var body: some View {
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
        .overlay {
            if isSearching {
                ProgressView()
            } else if hits.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }
}
