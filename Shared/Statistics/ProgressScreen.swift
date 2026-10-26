import SwiftUI
import VocabCore

/// Progress, pushed from the header of Today on the iPhone, a page of the window on the Mac, a summary of four blocks (`references/learning-flow.md`,
/// "Milestones, achievements and the Progress screen"): the streak hero, as on Today but larger, with the four totals,
/// the calendar of the last 13 weeks with the runs of kept days joined, the latest medals and the way to all of them,
/// and the ladder of memory. Everything is worked out from the review logs as the ring is, `DailyProgress.records`.
///
/// The true retention of the last 30 days is not here: no screen of the iPhone app reads the decks' review logs
/// into it across decks, the deck statistics do it for one deck.
struct ProgressScreen<Trailing: View>: View {
    var progress: DailyProgress
    var calendar = StudyCalendar()
    /// The last section: How It Works, which each app opens its own way.
    @ViewBuilder var trailing: Trailing

    private var records: [DayRecord] { progress.records }

    var body: some View {
        List {
            Section { streak }
            Section {
                WeeksGrid(records: records)
            } header: {
                WeeksGrid(records: records).title
            }
            Section("Medals") {
                latestMedals
                NavigationLink {
                    MedalsScreen(progress: progress, calendar: calendar)
                } label: {
                    Text("All Medals")
                }
            }
            if progress.ladder.reduce(0, +) > 0 {
                Section("Memory") { ladder }
            }
            if !(trailing is EmptyView) {
                Section {
                    trailing
                } footer: {
                    Text("The plan, the day's time and the FSRS parameters behind the ring.")
                }
            }
        }
        .groupedList()
        .navigationTitle("Progress")
    }

    // MARK: The streak

    private var longest: Int {
        max(progress.streak.days, records.map(\.streak).max() ?? 0)
    }

    private var ringsClosed: Int {
        records.filter { $0.closed && $0.done > 0 }.count
    }

    /// The streak hero of Today, the ring with the flame and the days in it, larger and with the words in memory under
    /// it; and the main totals, two by two.
    private var streak: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            VStack(spacing: Spacing.gap) {
                StreakHeroRing(fraction: progress.ring.fraction, days: progress.streak.days, state: progress.streakState, diameter: 220)
                MemoryLine(memory: progress.memory)
                    .font(.subheadline)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 2), alignment: .leading, spacing: Spacing.tight) {
                total("Longest streak") { Text("\(longest) days") }
                total("Rings closed") { Text(ringsClosed, format: .number) }
                total("Days studied") { Text(records.filter { $0.done > 0 }.count, format: .number) }
                total("Cards done") { Text(records.reduce(0) { $0 + $1.done }, format: .number) }
            }
        }
        .padding(.vertical, Spacing.tight)
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

/// Medals three to a row on an iPhone, more in a wider Mac window: a medal is 97 pt wide, so its title of two lines
/// fits.
let medalColumns = [GridItem(.adaptive(minimum: 97), spacing: Spacing.hairline, alignment: .top)]

/// The calendar of the last 13 weeks: a column per weekday, Monday to Sunday, under its initial, and a row per
/// week from the one of the first study day to this one, the oldest on top, at most 13. A closed ring is full, a
/// partial day has its ring at the share of the goal done (`DayRecord.ringShare`), a missed study day an empty
/// track; the days of this week still to come are a faint track, and the days before the first study day are blank.
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

    /// The runs of kept days within one week, as the columns they span: two days or more in a row. A single kept day
    /// is its ring; a run does not go on into the next week's row.
    static func runs(ofKept kept: [Bool]) -> [ClosedRange<Int>] {
        var runs: [ClosedRange<Int>] = []
        var start: Int?
        for (column, isKept) in (kept + [false]).enumerated() {
            if isKept {
                start = start ?? column
            } else if let first = start {
                if column - first >= 2 { runs.append(first...(column - 1)) }
                start = nil
            }
        }
        return runs
    }

    /// The initial of the weekday of `column`.
    private func initial(_ column: Int) -> String {
        Calendar.current.veryShortWeekdaySymbols[(column + 1) % 7]
    }

    var body: some View {
        let byDay = Dictionary(records.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
        let today = records.last?.day ?? 0
        let first = records.first?.day ?? 0
        // Rows of seven equal cells, so a run's band can be laid over the columns it spans.
        VStack(spacing: Spacing.tight) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { column in
                    Text(verbatim: initial(column))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(cells.indices, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(cells[row], id: \.self) { day in
                        Group {
                            if day > today {
                                ProgressRing(fraction: 0, diameter: diameter).opacity(0.3)
                            } else if day >= first, let record = byDay[day] {
                                ProgressRing(fraction: record.ringShare, diameter: diameter)
                            } else {
                                Color.clear.frame(width: diameter, height: diameter)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .background {
                    bands(Self.runs(ofKept: cells[row].map { $0 >= first && $0 <= today && byDay[$0]?.kept == true }))
                }
            }
        }
        .padding(.vertical, Spacing.tight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(Text("\(records.suffix(Self.weeks * 7).filter { $0.closed && $0.done > 0 }.count) rings closed"))
    }

    /// A capsule in the streak's colour behind each run of a row, from the left of its first column to the right of
    /// its last.
    private func bands(_ runs: [ClosedRange<Int>]) -> some View {
        GeometryReader { geometry in
            let column = geometry.size.width / 7
            ForEach(runs, id: \.lowerBound) { run in
                Capsule()
                    .fill(Color.streak.opacity(0.18))
                    .frame(width: column * CGFloat(run.count) - 4, height: diameter + 8)
                    .position(x: column * (CGFloat(run.lowerBound) + CGFloat(run.count) / 2), y: geometry.size.height / 2)
            }
        }
        .accessibilityHidden(true)
    }

}

extension ProgressScreen where Trailing == EmptyView {
    init(progress: DailyProgress, calendar: StudyCalendar = StudyCalendar()) {
        self.init(progress: progress, calendar: calendar) { EmptyView() }
    }
}

extension View {
    /// The grouped list of both apps: inset grouped on the iPhone, inset on the Mac.
    func groupedList() -> some View {
        #if os(iOS)
        listStyle(.insetGrouped)
        #else
        listStyle(.inset)
        #endif
    }
}
