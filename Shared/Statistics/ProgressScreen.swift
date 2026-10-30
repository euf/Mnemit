import SwiftUI
import VocabCore

/// Progress, pushed from the header of Today on the iPhone, a page of the window on the Mac, in the grammar of the screens
/// (`references/product-model.md`, "The grammar of the screens"): the streak as a card, the totals as tiles two to a row on
/// the page, the calendar of the last 13 weeks with the runs of kept days joined, the latest medals and the way to all of
/// them, and the ladder of memory. Everything is worked out from the review logs as the ring is, `DailyProgress.records`.
///
/// The true retention of the last 30 days is not here: no screen of the iPhone app reads the decks' review logs
/// into it across decks, the deck statistics do it for one deck.
struct ProgressScreen<Trailing: View>: View {
    var progress: DailyProgress
    var calendar = StudyCalendar()
    /// The last section: How It Works, which each app opens its own way.
    @ViewBuilder var trailing: Trailing

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var records: [DayRecord] { progress.records }

    var body: some View {
        Form {
            Section {
                StreakCard(days: progress.streak.days, state: progress.streakState, best: longest)
            }
            Section {
                #if os(iOS)
                tiles
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                #else
                tiles
                #endif
            }
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
                    Text("Show All")
                }
            }
            if progress.ladder.reduce(0, +) > 0 {
                Section("Memory") {
                    if let line = progress.memory.line {
                        Text(verbatim: line)
                            .font(.subheadline)
                            .monospacedDigit()
                    }
                    ladder
                }
            }
            if !(trailing is EmptyView) {
                Section {
                    trailing
                } footer: {
                    Text("What's behind the ring.")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Progress")
    }

    // MARK: The streak and the totals

    private var longest: Int {
        max(progress.streak.days, records.map(\.streak).max() ?? 0)
    }

    private var ringsClosed: Int {
        records.filter(\.closedWithWork).count
    }

    /// The totals as tiles, two to a row (one column at accessibility sizes) on the page, not inside a card: days studied,
    /// rings closed of the days since the first, words learned and the ring's size. There is no ring here: the day's ring is
    /// on Today.
    private var tiles: some View {
        let ring = RingSize(progress)
        return LazyVGrid(
            columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 150), spacing: Spacing.gap)],
            spacing: Spacing.gap
        ) {
            total(Text("Days studied"), Text(records.filter { $0.done > 0 }.count, format: .number), footnote: Self.blank)
            total(Text("Rings closed"), Text(ringsClosed, format: .number), footnote: Text("of \(records.count) days"))
            total(Text("Words learned"), Text(progress.learned.words, format: .number), footnote: Self.blank)
            total(Text("Your ring"), Text(verbatim: ring.value), unit: Text("min"), footnote: Text(verbatim: ring.footnote), tint: .appAccentText)
        }
    }

    /// A total: a tile on the iPhone's page; on the Mac, whose grouped form keeps its card behind the row, the figure alone,
    /// so the four share one card and no box stands in a box.
    @ViewBuilder
    private func total(_ label: Text, _ value: Text, unit: Text? = nil, footnote: Text, tint: Color = .primary) -> some View {
        #if os(iOS)
        FigureTile(label: label, value: value, unit: unit, footnote: footnote, tint: tint)
        #else
        VStack(alignment: .leading, spacing: 2) {
            Figure(label: label, value: value, unit: unit, tint: tint)
            footnote
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        #endif
    }

    /// The line under a value that has nothing to say, so the tiles of a row are of one height.
    private static var blank: Text { Text(verbatim: " ") }

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
                            .overlay { Circle().strokeBorder(Color.primary.opacity(0.3), lineWidth: 1) }
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

/// The size of the learner's ring, which grows with them: today's time in minutes and the time of the first day, the tile
/// "Your ring 8 min" over "a day · started at 2.5". The first day's alone, as it was, when the ring has not moved.
struct RingSize: Equatable {
    /// Today's time and the first study day's, in minutes.
    var minutes: Double
    var started: Double

    init(_ progress: DailyProgress) {
        minutes = progress.time / 60
        started = (progress.ringDays.first?.time ?? progress.time) / 60
    }

    /// The minutes, "8" and "2.5".
    var value: String { Self.format(minutes) }

    /// "a day · started at 2.5", or "a day" while the ring has not moved.
    var footnote: String {
        let began = Self.format(started)
        return began == value ? String(localized: "a day") : String(localized: "a day · started at \(began)")
    }

    /// One decimal at most, "8" and "2.5".
    private static func format(_ minutes: Double) -> String {
        minutes.formatted(.number.precision(.fractionLength(0...1)).grouping(.never))
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
    @Environment(\.colorScheme) private var colorScheme

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
                                if day < today, record.ringShare == 0 {
                                    MissedDayMark(diameter: diameter)
                                } else {
                                    ProgressRing(fraction: record.ringShare, diameter: diameter)
                                }
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
        .accessibilityValue(Text("\(records.suffix(Self.weeks * 7).filter(\.closedWithWork).count) rings closed"))
    }

    /// A capsule in the streak's colour behind each run of a row, from the left of its first column to the right of
    /// its last.
    private func bands(_ runs: [ClosedRange<Int>]) -> some View {
        GeometryReader { geometry in
            let column = geometry.size.width / 7
            ForEach(runs, id: \.lowerBound) { run in
                Capsule()
                    .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.streak.opacity(0.18))
                    // In dark the band is darker than the card, with an outline in the streak's colour: a band lighter than the
                    // card, brown at any opacity, takes a ring's head from 3.0:1 to under 2.5.
                    .overlay { Capsule().strokeBorder(Color.streak.opacity(colorScheme == .dark ? 0.45 : 0), lineWidth: 1) }
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

/// The streak at the top of Progress, a card: "Day streak" over the flame and the days large in the streak's colour, and
/// "Best: 21" after them when the best run is not the current one. At 0 days the outlined flame and "Start your streak".
private struct StreakCard: View {
    var days: Int
    var state: StreakState
    /// The longest run, the current one included.
    var best: Int
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if days == 0 {
                HStack(spacing: Spacing.tight) {
                    StreakFlame(state: state)
                        .font(.title2)
                    Text("Start your streak")
                        .font(.title3.weight(.semibold))
                }
            } else {
                Text("Day streak")
                    .font(.subheadline)
                HStack(alignment: .firstTextBaseline, spacing: Spacing.tight) {
                    StreakFlame(state: state)
                        .font(.system(size: size * 0.7, weight: .semibold))
                    Text(days, format: .number.grouping(.never))
                        .font(.system(size: size, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.streak)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    if best > days {
                        Text("Best: \(best)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.hairline)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: days == 0 ? String(localized: "Start your streak") : String(localized: "\(days) day streak")))
        .accessibilityValue(best > days ? Text("Best: \(best)") : Text(verbatim: ""))
    }
}
