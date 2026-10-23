import SwiftUI
import VocabCore

/// All medals, pushed from Progress: the lines of one medal each together first, then the streak, the rings in a
/// day and the big day, each with the medals earned and the next one in grey.
struct MedalsScreen: View {
    var progress: DailyProgress
    var calendar = StudyCalendar()

    var body: some View {
        List {
            Section {
                MedalLine(lines: AchievementLine.single, progress: progress, calendar: calendar)
                ForEach(AchievementLine.tiered, id: \.self) { line in
                    MedalLine(lines: [line], progress: progress, calendar: calendar)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Medals")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The medals of some lines in one grid: of each line the earned ones in order, then the next as a grey medal
/// with how far there is to go, and nothing beyond it. A line that repeats shows one medal with its count as a
/// badge, or the grey one before the first.
private struct MedalLine: View {
    var lines: [AchievementLine]
    var progress: DailyProgress
    var calendar: StudyCalendar

    var body: some View {
        LazyVGrid(columns: medalColumns, spacing: Spacing.gap) {
            ForEach(lines, id: \.self) { line in
                let earned = progress.achievements.filter { $0.kind.line == line }.medals
                let next = NextTier.of(line, earned: progress.achievements, records: progress.records, streak: progress.streak.days)
                ForEach(earned, id: \.kind) { medal in
                    Medal(kind: medal.kind, date: calendar.start(ofDay: medal.day), count: medal.count)
                }
                if let next, !(line.repeats && !earned.isEmpty) {
                    Medal(kind: next.kind, isEarned: false, hint: next.hint)
                }
            }
        }
        .padding(.vertical, Spacing.tight)
    }
}
