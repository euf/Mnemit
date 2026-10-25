import SwiftUI
import VocabCore

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
            .groupedList()
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
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 540)
        #endif
    }
}
