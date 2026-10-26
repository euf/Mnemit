import SwiftUI
import VocabCore

/// The streak's state on screen, which shape and colour both say: `flame` outlined in secondary grey until today's
/// streak step is done, `flame.fill` in `Color.streak` after, and, the day after a missed one, an outline in
/// `Color.streak` followed by an `exclamationmark` until the ring closes.
enum StreakState: Equatable {
    /// Today's streak step is not done.
    case open
    /// Today's streak step is done.
    case kept
    /// The day after a missed day, until the ring closes: the streak survives only if it does.
    case atRisk
}

/// The streak's flame, drawn by the state: the one sign of the streak on every screen, always outside a ring. At risk
/// the outline is followed by an `exclamationmark`, so the state shows without its colour (vibrant and tinted
/// widgets keep one colour). The size is the caller's font.
struct StreakFlame: View {
    var state: StreakState

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: state == .kept ? "flame.fill" : "flame")
                .foregroundStyle(state == .open ? Color.secondary : Color.streak)
            if state == .atRisk {
                Image(systemName: "exclamationmark")
                    .foregroundStyle(Color.streak)
            }
        }
        .symbolRenderingMode(.monochrome)
    }
}

extension DailyProgress {
    /// The state of the streak's flame: at risk after a missed day until the ring closes, else by today's streak step.
    var streakState: StreakState {
        if isStreakAtRisk { return .atRisk }
        // No days, nothing kept: a day with an empty plan counts as kept, but a streak of 0 has no flame to fill.
        return streakKeptToday && streak.days > 0 ? .kept : .open
    }

    /// The day after a missed day, until the ring closes: the streak survives only if it does.
    var isStreakAtRisk: Bool {
        streak.repairCards != nil && !ring.isGoalMet
    }

    /// The cards that close the ring, what its middle counts and "N cards left" meant on Today: 0 once it is closed.
    /// The plan may hold more, after a break, and those come after the ring.
    var cardsToClose: Int {
        ring.isGoalMet ? 0 : max(0, min(cardsLeft, ring.goal - ring.done))
    }
}

enum DailyRingFigure {
    /// The ring's fraction, in laps of the goal: the figures' (done and the parts of the cards underway), or `shown`
    /// cards of them while the ring is ahead of the figures. Past 1 the ring goes on over itself, as the Fitness
    /// rings do, up to `ProgressRing.maxLaps`.
    static func fraction(_ progress: DailyProgress?, shown: Double?) -> Double {
        guard let ring = progress?.ring else { return 0 }
        let cards = shown ?? Double(ring.done) + ring.underway
        return min(ProgressRing.maxLaps, cards / Double(max(1, ring.goal)))
    }
}

/// Today's cards done against the goal as an `ActivityRing` from a lighter tint of the accent to the accent: a picture, with
/// nothing in its middle (the sentence beside it says the day, `NextStep`).
///
/// One ring for every surface, decoration for VoiceOver: the text beside it says the figures. `fraction` animates, except
/// under Reduce Motion.
struct ProgressRing: View {
    /// 0.4 is two fifths of the goal; 1 is a closed ring, and past 1 the ring goes on over itself, a second lap and a
    /// third, which is as far as it is drawn (`maxLaps`).
    var fraction: Double
    var diameter: CGFloat
    /// How the ring fills to a new fraction: quick in the study bar, slow enough to watch on Today.
    var filling: Animation = .smooth
    /// The stroke's thickness; `nil` takes `lineWidth(diameter:)`.
    var lineWidth: CGFloat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.self) private var environment

    /// The laps drawn at most: three times the goal.
    static let maxLaps = DayRecord.maxLaps

    /// The thickness of the stroke: as much as the Fitness rings take, at least 3 pt.
    static func lineWidth(diameter: CGFloat) -> CGFloat {
        max(3, diameter * 0.15)
    }

    var body: some View {
        let head = Color.dailyRing.resolve(in: environment)
        ActivityRing(
            progress: min(Self.maxLaps, max(0, fraction)), color: Color(head), tipColor: .dailyRingTail(of: head, scheme: colorScheme),
            lineWidth: lineWidth ?? Self.lineWidth(diameter: diameter)
        )
        .animation(reduceMotion ? nil : filling, value: fraction)
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}
