import SwiftUI
import VocabCore

/// What leads the gain line under the streak chip, by the state of the day: the time that closes the ring, "≈ 5 min",
/// while it is open; "3 left" of the plan once it is closed; "Nothing due · next tomorrow" on a day without cards. The
/// ring says the cards left and the chip the streak, so neither is repeated here; `nil` when there is nothing to add.
enum TodayLead {
    static func text(due: Int, progress: DailyProgress, nextDue: Date?, now: Date) -> String? {
        text(due: due, ring: progress.ring, secondsPerCard: progress.secondsPerCardLeft, nextDue: nextDue, now: now)
    }

    /// The same from the figures alone, which the widget's snapshot holds: `secondsPerCard` is `nil` where it has none,
    /// and the line then has no time.
    static func text(due: Int, ring: DailyRing, secondsPerCard: Double?, nextDue: Date?, now: Date) -> String? {
        if due > 0 {
            if ring.isGoalMet { return String(localized: "\(due) left") }
            // The cards to close the ring: the plan may hold more after a break, and those come after the ring.
            let cards = ring.goal > 0 ? min(due, ring.goal - ring.done) : due
            return secondsPerCard.flatMap { DailyGoal.minutesLeft(cards: cards, secondsPerCard: $0) }.map(Format.timeLeft(minutes:))
        }
        if ring.done > 0 { return nil }
        if let nextDue { return String(localized: "Nothing due · next \(Format.due(nextDue, now: now))") }
        return String(localized: "Nothing due")
    }
}

/// Today's ring at hero size, 168 pt on the iPhone: the cards left or a check in the middle, its stroke a tenth of its
/// size, filling slowly. With no figures (`progress` is `nil`) an empty ring. The same ring as everywhere
/// (`ProgressRing`); only the size and the speed of the fill are Today's.
struct HeroRing: View {
    var progress: DailyProgress?
    var diameter: CGFloat = 168

    var body: some View {
        ProgressRing(
            fraction: DailyRingFigure.fraction(progress, shown: nil), diameter: diameter, center: RingCenter(progress), speaksCenter: true,
            filling: .smooth(duration: 1.4), lineWidth: diameter * 18 / 168)
    }
}

/// Today's hero: the ring with the cards left in it, the streak chip under it, one gain line (the time that closes the
/// ring and the words in memory) and the week's rings. On the iPhone's Today at 168 pt, with the whole hero a button to
/// Progress; the Mac's Today at its own size.
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
        // 24 pt between the parts: the ring, the chip with its line, the week.
        VStack(spacing: 24) {
            HeroRing(progress: isLoaded ? progress : nil, diameter: ringSize)
            VStack(spacing: 12) {
                StreakChip(
                    days: isLoaded ? (progress?.streak.days ?? 0) : nil, state: progress?.streakState ?? .open,
                    minutesToKeep: progress.flatMap { RoundStatus($0).minutesToKeep })
                gain
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .redacted(reason: isLoaded ? [] : .placeholder)
            }
            if showsWeek { week }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// "≈ 5 min · 28 words in memory": the lead of the day (`TodayLead`) and the words, one line.
    @ViewBuilder
    private var gain: some View {
        if let progress, isLoaded {
            MemoryLine(memory: progress.memory, lead: TodayLead.text(due: due, progress: progress, nextDue: nextDue, now: now))
        } else if !isLoaded {
            Text("\(412) words in memory")
        }
    }

    private var week: some View {
        let loaded = isLoaded ? progress : nil
        return WeekRings(week: loaded?.week.count == 7 ? loaded!.week : Array(repeating: nil, count: 7), rings: loaded?.weekRings, today: DailyRingFigure.fraction(loaded, shown: nil), now: now)
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
/// with a glyph in the accent: the accent is never small text. A `lead`, "≈ 5 min", goes in front of either as one
/// more part of the line. Where the line is too long, at a large type size, it is one text that wraps, not the gain
/// stacked under the words.
struct MemoryLine: View {
    var memory: MemoryEstimate
    var lead: String?

    var body: some View {
        if let milestone = memory.milestoneLine {
            HStack(spacing: 4) {
                // The glyph bursts the first time the line shows for a milestone.
                MilestoneSparkles(milestone: memory.milestoneReachedToday)
                Text(verbatim: joined(String(localized: milestone)) ?? "")
                    .fontWeight(.semibold)
            }
        } else if let line = joined(memory.line) {
            Text(verbatim: line)
                .foregroundStyle(.secondary)
        }
    }

    private func joined(_ line: String?) -> String? {
        let parts = [lead, line].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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
