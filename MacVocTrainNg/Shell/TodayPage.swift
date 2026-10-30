import AppKit
import SwiftUI
import VocabCore

/// The Today page of the Mac's window, from what it is given so a test can draw it: the iPhone's Today card (`TodayCard`: the
/// ring, Day streak, the next moment, Words learned, the week; a button to Progress) on a ground of its own, centred at a
/// readable width, with the day's one button under it (`DayAction`: Study, Keep Going or Learn 10 New Words). No large title: the
/// window's title bar has "Today" and the date. Without a deck, the empty card and the ways to get one.
struct TodayPageContent: View {
    var hasDecks: Bool
    /// Whether the Mnemit folder can't be reached (`DeckFolder.isLost`): the page says it and asks for the folder again.
    var folderLost = false
    var progress: DailyProgress?
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
            .frame(maxWidth: 560)
            .padding(Spacing.section)
            .frame(maxWidth: .infinity)
        }
    }

    /// The card is a button, as on the iPhone: it opens Progress.
    @ViewBuilder
    private var day: some View {
        TodayCard(progress: isLoaded ? progress : nil, now: now, isLoaded: isLoaded, open: progress == nil ? nil : showProgress)
            .background(Color.tileGround, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .help("Progress")
        Button(action: study) {
            Text(action.title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.appAccent)
        .controlSize(.extraLarge)
        .keyboardShortcut(.defaultAction)
        .disabled(!canStudy)
    }

    /// No deck yet: the card with the empty ring over the ways to get one: a new deck, shared decks, the iCloud folder as a link.
    @ViewBuilder
    private var empty: some View {
        if folderLost {
            LostFolderCard(choose: chooseFolder)
                .background(Color.tileGround, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            emptyActions
        }
    }

    @ViewBuilder
    private var emptyActions: some View {
        EmptyTodayCard()
            .background(Color.tileGround, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        VStack(spacing: Spacing.gap) {
            Button(action: newDeck) {
                Text("New Deck").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appAccent)
            Button(action: sharedDecks) {
                Text("Shared Decks").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            Button("Use iCloud Drive Folder", action: chooseFolder)
                .buttonStyle(.link)
                .font(.footnote)
                .controlSize(.regular)
                .padding(.top, Spacing.hairline)
        }
        .controlSize(.large)
    }
}

/// The Today page: `TodayPageContent` over the shell's day, with Study in the toolbar (⌘L is the Study menu's), the
/// medals of earlier days as toasts and the month's recap.
struct TodayPage: View {
    var shell: Shell
    var newDeck: () -> Void
    /// The medals of earlier days this Mac never celebrated, earned on the iPhone, say, once as toasts, under the button.
    @State private var toasts: MedalToasts
    /// The month's screen, shown on the first open of a new month after a month with study, as on the iPhone.
    @State private var monthRecap: MonthRecap?
    @AppStorage("shownMonthRecap") private var shownMonthRecap = ""

    /// - Parameter toasts: The medals' toasts; a test passes one with a toast frozen in.
    init(shell: Shell, newDeck: @escaping () -> Void, toasts: MedalToasts? = nil) {
        self.shell = shell
        self.newDeck = newDeck
        _toasts = State(initialValue: toasts ?? MedalToasts())
    }

    var body: some View {
        let ring = shell.ring
        TodayPageContent(
            hasDecks: !shell.known.isEmpty, folderLost: shell.folder.isLost, progress: ring.progress, now: Date(), isLoaded: shell.isDayReady,
            action: shell.dayAction, canStudy: shell.canStudyDay, study: { shell.study(.day) }, showProgress: { shell.select(.progress) },
            newDeck: newDeck, chooseFolder: chooseFolder, sharedDecks: { DeckWebWindow.show() }
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(shell.dayAction.title) { shell.study(.day) }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appAccent)
                    .disabled(!shell.canStudyDay)
                    .help("Study today's plan")
            }
        }
        .medalToast(toasts, at: .inset)
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
