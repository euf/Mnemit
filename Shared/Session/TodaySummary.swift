import SwiftUI
import VocabCore

/// The one line under Today's ring, by the state of the day: "≈ 2 min to keep your streak" before the streak step,
/// "20 cards left · ≈ 5 min" while the ring is open, "Ring closed · 3 left", "All done", "Nothing due · next tomorrow",
/// and the day after a missed one "Close the ring to save your 12-day streak". The same on both apps.
enum TodayHeadline {
    /// - Parameters:
    ///   - due: The cards of today's plan not done yet, "N cards left": not the cards that are due in all.
    ///   - nextDue: When something comes back that today's plans leave out.
    static func text(due: Int, progress: DailyProgress, nextDue: Date?, now: Date) -> String {
        text(
            due: due, ring: progress.ring, isStreakAtRisk: progress.isStreakAtRisk, streakDays: progress.streak.days, round: RoundStatus(progress),
            secondsPerCard: progress.secondsPerCardLeft, nextDue: nextDue, now: now)
    }

    /// The same line from the figures alone, which the widget's snapshot holds: `round` and `secondsPerCard` are `nil`
    /// where it has none, and the line then has no time.
    static func text(
        due: Int, ring: DailyRing, isStreakAtRisk: Bool, streakDays: Int, round: RoundStatus?, secondsPerCard: Double?, nextDue: Date?, now: Date
    ) -> String {
        if isStreakAtRisk {
            return String(localized: "Close the ring to save your \(streakDays)-day streak")
        }
        if due > 0 {
            if ring.isGoalMet {
                return [String(localized: "Ring closed"), String(localized: "\(due) left")].joined(separator: " · ")
            }
            if let title = round?.line { return title }
            // The cards to close the ring: the plan may hold more after a break, and those come after the ring.
            let cards = ring.goal > 0 ? min(due, ring.goal - ring.done) : due
            let time = secondsPerCard.flatMap { DailyGoal.minutesLeft(cards: cards, secondsPerCard: $0) }.map(Format.timeLeft(minutes:))
            return ([String(localized: "\(cards) cards left")] + [time].compactMap { $0 }).joined(separator: " · ")
        }
        if ring.done > 0 { return String(localized: "All done") }
        if let nextDue { return String(localized: "Nothing due · next \(Format.due(nextDue, now: now))") }
        return String(localized: "Nothing due")
    }

    /// The lines the day will have, for the placeholders before the decks are read.
    static let placeholder = [String(localized: "\(20) cards left"), Format.timeLeft(minutes: 5)].joined(separator: " · ")
}

/// A ring with the streak's number in it, for the hero of Today: the flame, the days large and "day streak" under
/// them; at 0 days the outlined flame and "Start your streak". The ring is the day's goal, its thickness a tenth of
/// its size. The middle scales its text down before it would leave the ring.
struct StreakHeroRing: View {
    var fraction: Double
    /// The streak in days; 0 starts a streak. `nil` while the day is not read: placeholders.
    var days: Int?
    var state: StreakState
    var diameter: CGFloat = 168

    /// 18 pt at 168 pt.
    private var lineWidth: CGFloat { diameter * 18 / 168 }

    var body: some View {
        ProgressRing(fraction: fraction, diameter: diameter, filling: .smooth(duration: 1.4), lineWidth: lineWidth)
            .overlay { center }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: spoken))
    }

    private var spoken: String {
        guard let days, days > 0 else { return String(localized: "Start your streak") }
        return RingCenter.streak(days: days, state: state).spokenLabel ?? ""
    }

    /// "day streak": the plural form of "12 day streak" without its number, which stands large above it. A language
    /// that does not put the number first shows the whole phrase.
    static func caption(days: Int) -> String {
        let phrase = String(localized: "\(days) day streak")
        let number = days.formatted()
        guard phrase.hasPrefix(number) else { return phrase }
        return String(phrase.dropFirst(number.count)).trimmingCharacters(in: .whitespaces)
    }

    private var center: some View {
        VStack(spacing: 2) {
            StreakFlame(state: state)
                .font(.system(size: 28 * diameter / 168, weight: .semibold))
            if days == 0 {
                Text("Start your streak")
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
            } else {
                let shown = days ?? 12
                Text(shown, format: .number.grouping(.never))
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                Text(verbatim: Self.caption(days: shown))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        // The ring does not grow with the text: the middle stops growing at xxxLarge and scales down from there.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .frame(width: (diameter - 2 * lineWidth) * 0.72, height: (diameter - 2 * lineWidth) * 0.72)
        .redacted(reason: days == nil ? .placeholder : [])
    }
}

/// Today's hero: the ring with the streak in it, one headline for the state of the day, one gain line, and the
/// week's rings. On the iPhone's Today at 168 pt, with the whole hero a button to Progress; the Mac's Today at
/// its own size.
struct TodayHero: View {
    /// The cards of the plan not done yet, "N cards left": not the cards that are due in all.
    var due: Int
    var progress: DailyProgress?
    /// When something comes back that today's plans leave out.
    var nextDue: Date?
    var now: Date
    /// `false` until the decks are read: the figures are placeholders then.
    var isLoaded: Bool
    var ringSize: CGFloat = 168
    var showsWeek = true
    /// A chevron at the end of the week's row: this hero opens Progress.
    var showsChevron = false

    var body: some View {
        // 24 pt between the parts: the ring, the two lines, the week.
        VStack(spacing: 24) {
            StreakHeroRing(
                fraction: progress?.ring.fraction ?? 0, days: isLoaded ? (progress?.streak.days ?? 0) : nil,
                state: progress?.streakState ?? .open, diameter: ringSize)
            VStack(spacing: 4) {
                headline
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                gain
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .redacted(reason: isLoaded ? [] : .placeholder)
            if showsWeek { week }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var headline: some View {
        if isLoaded, let progress {
            Text(verbatim: TodayHeadline.text(due: due, progress: progress, nextDue: nextDue, now: now))
        } else {
            Text(verbatim: TodayHeadline.placeholder)
        }
    }

    @ViewBuilder
    private var gain: some View {
        if let memory = progress?.memory, isLoaded {
            MemoryLine(memory: memory)
        } else if !isLoaded {
            Text("\(412) words in memory")
        }
    }

    private var week: some View {
        let loaded = isLoaded ? progress : nil
        return WeekRings(week: loaded?.week.count == 7 ? loaded!.week : Array(repeating: nil, count: 7), today: loaded?.ring.fraction ?? 0, now: now)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
                if showsChevron {
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
    }
}

/// "412 words in memory · +15 today" on one line, or on the day a milestone was passed "50 words in memory!"
/// with a glyph in the accent: the accent is never small text. Where the line is too long, at a large type size,
/// it is one text that wraps, not the gain stacked under the words.
struct MemoryLine: View {
    var memory: MemoryEstimate

    var body: some View {
        if let milestone = memory.milestoneLine {
            HStack(spacing: 4) {
                // The glyph bursts the first time the line shows for a milestone.
                MilestoneSparkles(milestone: memory.milestoneReachedToday)
                Text(milestone)
                    .fontWeight(.semibold)
            }
        } else if let line = memory.line {
            Text(verbatim: line)
                .foregroundStyle(.secondary)
        }
    }
}

/// What Today's one button does next, named with the words of the rests: **Study** while the ring is open; **Catch
/// Up** once the ring is closed and the plan has cards left; **Learn 10 New Words** (case `pushOn`) once the day's
/// stack is done, ten new cards at once. The iPhone's Today and the Mac's Today window say the same.
enum DayAction: Equatable {
    case study, catchUp, pushOn

    /// What the button does for a day with `due` cards of the plan left.
    init(due: Int, progress: DailyProgress?) {
        if due == 0 {
            self = .pushOn
        } else if progress?.ring.isGoalMet == true {
            self = .catchUp
        } else {
            self = .study
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .study: "Study"
        case .catchUp: "Catch Up"
        case .pushOn: "Learn 10 New Words"
        }
    }
}
