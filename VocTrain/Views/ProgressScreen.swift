import SwiftUI
import VocabCore

/// Progress, pushed from the header of Today, a summary of four blocks (`references/learning-flow.md`,
/// "Milestones, achievements and the Progress screen"): the streak with the main totals, the latest medals and the
/// way to all of them, the calendar of the last 13 weeks, and the ladder of memory. Everything is worked out from
/// the review logs as the ring is, `DailyProgress.records`.
///
/// The true retention of the last 30 days is not here: no screen of the iPhone app reads the decks' review logs
/// into it across decks, the deck statistics do it for one deck.
struct ProgressScreen: View {
    var progress: DailyProgress
    var calendar = StudyCalendar()

    private var records: [DayRecord] { progress.records }

    var body: some View {
        List {
            Section { streak }
            Section("Medals") {
                latestMedals
                NavigationLink {
                    MedalsScreen(progress: progress, calendar: calendar)
                } label: {
                    Text("All Medals")
                }
            }
            Section {
                WeeksGrid(records: records)
            } header: {
                WeeksGrid(records: records).title
            }
            if progress.ladder.reduce(0, +) > 0 {
                Section("Memory") { ladder }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Progress")
    }

    // MARK: The streak

    private var longest: Int {
        max(progress.streak.days, records.map(\.streak).max() ?? 0)
    }

    private var ringsClosed: Int {
        records.filter { $0.closed && $0.done > 0 }.count
    }

    private var isAtRisk: Bool {
        progress.streak.repairCards != nil && !progress.ring.isGoalMet
    }

    /// The streak large, and under it the main totals, two by two.
    private var streak: some View {
        VStack(alignment: .leading, spacing: Spacing.gap) {
            HStack(spacing: Spacing.tight) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(progress.streakKeptToday && !isAtRisk ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)
                Text(progress.streak.days, format: .number)
                    .monospacedDigit()
            }
            .font(.largeTitle.weight(.bold))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(progress.streak.days)-day streak"))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 2), alignment: .leading, spacing: Spacing.tight) {
                total("Longest streak") { Text("\(longest) days") }
                total("Rings closed") { Text(ringsClosed, format: .number) }
                total("Days studied") { Text(records.filter { $0.done > 0 }.count, format: .number) }
                total("Cards done") { Text(records.reduce(0) { $0 + $1.done }, format: .number) }
            }
        }
        .padding(.vertical, Spacing.hairline)
    }

    /// A figure of the totals: its title in footnote over the number.
    private func total(_ title: LocalizedStringKey, @ViewBuilder value: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            value()
                .font(.subheadline)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: The medals

    /// The medals earned last, up to five, the newest first; before the first, the one to earn first in grey.
    @ViewBuilder
    private var latestMedals: some View {
        let latest = progress.achievements.recentMedals
        if latest.isEmpty {
            if let next = AchievementLine.single.lazy.compactMap({ NextTier.of($0, earned: [], records: records, streak: progress.streak.days) }).first {
                Medal(kind: next.kind, isEarned: false)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.tight)
            }
        } else {
            HStack(spacing: Spacing.gap) {
                ForEach(latest, id: \.kind) { medal in
                    MedalDisc(kind: medal.kind, count: medal.count)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            Text(verbatim: [medal.kind.title, calendar.start(ofDay: medal.day).formatted(date: .long, time: .omitted)].joined(separator: ", ")))
                }
            }
            .padding(.vertical, Spacing.tight)
        }
    }

    // MARK: The ladder of memory

    /// The cards not started, which the bar leaves out.
    private var notStarted: Int { progress.ladder.first ?? 0 }

    /// The bar of the cards started, what is not started under it, and the five steps as a legend of three columns.
    private var ladder: some View {
        VStack(alignment: .leading, spacing: Spacing.tight) {
            LadderBar(ladder: progress.ladder, height: 12)
            if notStarted > 0 {
                Text("\(notStarted) not started")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.tight, alignment: .leading), count: 3), alignment: .leading, spacing: Spacing.tight) {
                ForEach(MaturityCategory.allCases.filter { $0 != .new }, id: \.rawValue) { step in
                    HStack(spacing: Spacing.hairline) {
                        Circle()
                            .fill(step.color)
                            .overlay { Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 0.5) }
                            .frame(width: 10, height: 10)
                            .accessibilityHidden(true)
                        Text(step.title)
                        Text(step.rawValue < progress.ladder.count ? progress.ladder[step.rawValue] : 0, format: .number)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(.vertical, Spacing.hairline)
    }
}

/// Medals three to a row on an iPhone: a medal is 97 pt wide, so its title of two lines fits.
let medalColumns = [GridItem(.adaptive(minimum: 97), spacing: Spacing.hairline, alignment: .top)]

/// The calendar of the last 13 weeks: a column per weekday, Monday to Sunday, under its initial, and a row per
/// week from the one of the first study day to this one, the oldest on top, at most 13. A closed ring is full, a
/// day kept but not closed has its ring at the share of the goal done, a missed study day an empty track; the
/// days of this week still to come are a faint track, and the days before the first study day are blank.
struct WeeksGrid: View {
    var records: [DayRecord]
    static let weeks = 13
    private let diameter: CGFloat = 20

    /// The column of a day, 0 for Monday.
    private static func column(_ day: Int) -> Int { (CivilDate.weekday(ofDayNumber: day) + 5) % 7 }

    /// How many weeks are shown: from the week of the first study day to this one, at most 13.
    static func weekCount(_ records: [DayRecord]) -> Int {
        guard let first = records.first?.day, let today = records.last?.day else { return 0 }
        return min(weeks, ((today - column(today)) - (first - column(first))) / 7 + 1)
    }

    /// "Last 13 weeks" once there are 13 of them, else "Calendar".
    var title: Text { Self.weekCount(records) == Self.weeks ? Text("Last 13 weeks") : Text("Calendar") }

    /// The study day of each cell, a row per week, the oldest first.
    private var cells: [[Int]] {
        guard let today = records.last?.day else { return [] }
        let count = Self.weekCount(records)
        let start = today - Self.column(today) - 7 * (count - 1)
        return (0..<count).map { week in (0..<7).map { start + 7 * week + $0 } }
    }

    /// The initial of the weekday of `column`.
    private func initial(_ column: Int) -> String {
        Calendar.current.veryShortWeekdaySymbols[(column + 1) % 7]
    }

    var body: some View {
        let byDay = Dictionary(records.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
        let today = records.last?.day ?? 0
        let first = records.first?.day ?? 0
        Grid(horizontalSpacing: 0, verticalSpacing: Spacing.tight) {
            GridRow {
                ForEach(0..<7, id: \.self) { column in
                    Text(verbatim: initial(column))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(cells.indices, id: \.self) { row in
                GridRow {
                    ForEach(cells[row], id: \.self) { day in
                        Group {
                            if day > today {
                                ProgressRing(fraction: 0, diameter: diameter).opacity(0.3)
                            } else if day >= first, let record = byDay[day] {
                                ProgressRing(fraction: Self.fraction(record, isToday: day == today), diameter: diameter)
                            } else {
                                Color.clear.frame(width: diameter, height: diameter)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.vertical, Spacing.tight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(Text("\(records.suffix(Self.weeks * 7).filter { $0.closed && $0.done > 0 }.count) rings closed"))
    }

    /// How full a day's ring is drawn. Today's ring, not kept yet, is not missed: it shows what is done.
    static func fraction(_ record: DayRecord, isToday: Bool) -> Double {
        if record.closed { return 1 }
        guard record.kept || isToday else { return 0 }
        return min(1, Double(record.done) / Double(max(1, record.goal)))
    }
}

// MARK: The month's screen

extension MonthRecap: @retroactive Identifiable {
    public var id: Int { year * 100 + month }
}

/// What decides whether the month's screen shows, and the key of the month it showed.
enum MonthRecapPlan {
    /// "2026-10": the value of `shownMonthRecap`.
    static func key(year: Int, month: Int) -> String {
        String(format: "%04d-%02d", year, month)
    }

    /// The recap of the month before today's, if it holds a day of study and `shown` is not its key; `nil`
    /// otherwise: this month's screen is the one of the first open of the month, and shows once.
    static func pending(records: [DayRecord], calendar: StudyCalendar, shown: String?) -> MonthRecap? {
        guard let today = records.last?.day else { return nil }
        let now = CivilDate(dayNumber: today)
        let year = now.month == 1 ? now.year - 1 : now.year
        let month = now.month == 1 ? 12 : now.month - 1
        guard key(year: year, month: month) != shown else { return nil }
        let first = CivilDate(year: year, month: month, day: 1).dayNumber
        guard let recap = Achievements.recap(ofMonthContaining: first, records: records, calendar: calendar), recap.daysStudied > 0 else { return nil }
        return recap
    }
}

/// The month after it: its name, the rings closed of the days studied, the cards done, the best streak, what was
/// earned in it, and the way on to Progress.
struct MonthRecapSheet: View {
    var recap: MonthRecap
    var calendar = StudyCalendar()
    var seeAll: () -> Void
    var done: () -> Void

    private var name: String {
        let first = calendar.start(ofDay: CivilDate(year: recap.year, month: recap.month, day: 1).dayNumber)
        return first.formatted(.dateTime.month(.wide).year())
    }

    /// The milestone the best streak of the month reached, in words; under 3 days, the days.
    private var bestStreak: String {
        guard let days = Achievements.streakMilestones.last(where: { $0 <= recap.bestStreak }) else {
            return String(localized: "\(recap.bestStreak) days")
        }
        return AchievementKind.streak(days: days).title
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Rings closed") { Text("\(recap.ringsClosed) of \(recap.daysStudied) days") }
                    LabeledContent("Cards done") { Text(recap.cardsDone, format: .number) }
                    LabeledContent("Best streak") { Text(verbatim: bestStreak) }
                }
                .monospacedDigit()
                if !recap.achievements.isEmpty {
                    Section("Achievements") {
                        LazyVGrid(columns: medalColumns, spacing: Spacing.gap) {
                            ForEach(recap.achievements.medals, id: \.kind) { medal in
                                Medal(kind: medal.kind, date: calendar.start(ofDay: medal.day), count: medal.count)
                            }
                        }
                        .padding(.vertical, Spacing.tight)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text(verbatim: name))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: done)
                }
            }
            .safeAreaBar(edge: .bottom) {
                Button(action: seeAll) {
                    Text("See All Progress")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .padding(.horizontal, Spacing.margin)
                .padding(.bottom, Spacing.tight)
            }
        }
    }
}
