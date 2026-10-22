import SwiftUI
import VocabCore

/// Progress, pushed from the header of Today: the streak and its record, the rings of the last 13 weeks, the
/// ladder of memory, the achievements and the records (`references/learning-flow.md`, "Milestones, achievements
/// and the Progress screen"). Everything is worked out from the review logs as the ring is, `DailyProgress.records`.
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
            Section("Last 13 weeks") { WeeksGrid(records: records) }
            if progress.ladder.reduce(0, +) > 0 {
                Section("Memory") { ladder }
            }
            Section("Achievements") {
                ForEach(AchievementLine.allCases, id: \.self) { line in
                    MedalLine(line: line, progress: progress, calendar: calendar)
                }
            }
            Section("Records") { recordRows }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Progress")
    }

    // MARK: The streak

    private var longest: Int {
        max(progress.streak.days, records.map(\.streak).max() ?? 0)
    }

    private var isAtRisk: Bool {
        progress.streak.repairCards != nil && !progress.ring.isGoalMet
    }

    /// The streak large, with its record under it.
    private var streak: some View {
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            HStack(spacing: Spacing.tight) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(progress.streakKeptToday && !isAtRisk ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)
                Text(progress.streak.days, format: .number)
                    .monospacedDigit()
            }
            .font(.largeTitle.weight(.bold))
            if longest > 0 {
                Text("Longest: \(longest) days")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Spacing.hairline)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(progress.streak.days)-day streak"))
        .accessibilityValue(longest > 0 ? Text("Longest: \(longest) days") : Text(verbatim: ""))
    }

    // MARK: The ladder of memory

    @ViewBuilder
    private var ladder: some View {
        LadderBar(ladder: progress.ladder, height: 12)
            .padding(.vertical, Spacing.hairline)
        ForEach(MaturityCategory.allCases, id: \.rawValue) { step in
            HStack(spacing: Spacing.gap) {
                Circle()
                    .fill(step.color)
                    .overlay { Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 0.5) }
                    .frame(width: 10, height: 10)
                    .accessibilityHidden(true)
                Text(step.title)
                Spacer(minLength: 0)
                Text(step.rawValue < progress.ladder.count ? progress.ladder[step.rawValue] : 0, format: .number)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Records

    @ViewBuilder
    private var recordRows: some View {
        let mostLaps = records.map { $0.goal > 0 ? $0.done / $0.goal : 0 }.max() ?? 0
        row("Most cards in a day", symbol: "rectangle.stack") { Text(records.map(\.done).max() ?? 0, format: .number) }
        row("Most laps in a day", symbol: "repeat") { Text(verbatim: "×\(mostLaps)") }
        row("Rings closed", symbol: "circle.circle") { Text(records.filter { $0.closed && $0.done > 0 }.count, format: .number) }
        row("Days studied", symbol: "calendar") { Text(records.filter { $0.done > 0 }.count, format: .number) }
        row("Cards done", symbol: "checkmark.circle") { Text(records.reduce(0) { $0 + $1.done }, format: .number) }
    }

    private func row(_ title: LocalizedStringKey, symbol: String, @ViewBuilder value: () -> some View) -> some View {
        LabeledContent {
            value().monospacedDigit()
        } label: {
            Label(title, systemImage: symbol)
        }
    }
}

/// The medals of one line: the earned ones in order, then the next as a grey medal with how far there is to go,
/// and nothing beyond it. A line that repeats shows one medal with its count, or the grey one before the first.
private struct MedalLine: View {
    var line: AchievementLine
    var progress: DailyProgress
    var calendar: StudyCalendar

    var body: some View {
        let earned = progress.achievements.filter { $0.kind.line == line }.medals
        let next = NextTier.of(line, earned: progress.achievements, records: progress.records, streak: progress.streak.days)
        LazyVGrid(columns: medalColumns, spacing: Spacing.gap) {
            ForEach(earned, id: \.kind) { medal in
                Medal(kind: medal.kind, date: calendar.start(ofDay: medal.day), count: medal.count)
            }
            if let next, !(line.repeats && !earned.isEmpty) {
                Medal(kind: next.kind, isEarned: false, hint: next.hint)
            }
        }
        .padding(.vertical, Spacing.tight)
    }
}

/// Medals three to a row on an iPhone: a medal is 97 pt wide, so its title of two lines fits.
let medalColumns = [GridItem(.adaptive(minimum: 97), spacing: Spacing.hairline, alignment: .top)]

/// The rings of the last 13 weeks, a column per week and a row per weekday, today last: a closed ring is full, a day
/// kept but not closed has its ring at the share of the goal done, a missed study day an empty track, and before the
/// first study day, or after today, there is nothing.
struct WeeksGrid: View {
    var records: [DayRecord]
    static let weeks = 13
    private let diameter: CGFloat = 18
    private let gap: CGFloat = 5

    /// The study day of the cell in `week` (0 the oldest) and `row` (0 the first weekday of the locale).
    private var cells: [[Int]] {
        guard let today = records.last?.day else { return [] }
        let todayRow = (CivilDate.weekday(ofDayNumber: today) - Calendar.current.firstWeekday + 7) % 7
        let start = today - todayRow - 7 * (Self.weeks - 1)
        return (0..<7).map { row in (0..<Self.weeks).map { start + 7 * $0 + row } }
    }

    var body: some View {
        let byDay = Dictionary(records.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
        let today = records.last?.day ?? 0
        Grid(horizontalSpacing: gap, verticalSpacing: gap) {
            ForEach(cells.indices, id: \.self) { row in
                GridRow {
                    ForEach(cells[row], id: \.self) { day in
                        if day <= today, let record = byDay[day] {
                            ProgressRing(fraction: Self.fraction(record, isToday: day == today), diameter: diameter)
                        } else {
                            Color.clear.frame(width: diameter, height: diameter)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.tight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Last 13 weeks"))
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
