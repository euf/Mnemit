import SwiftUI
import VocabCore

/// The streak's state on screen, which shape and colour both say. The fill says done: an outline until today's streak step
/// is done, `flame.fill` once it is. The colour says whether the streak is in play today: secondary grey while the day is
/// routine and not yet kept, `Color.streak` once it is kept, and at risk, the day after a missed one until the ring closes,
/// when an orange outline carries a solid `exclamationmark.circle.fill`. The days take the flame's colour (`tint`), so the
/// pair never says two things.
enum StreakState: Equatable {
    /// Today's streak step is not done.
    case open
    /// Today's streak step is done.
    case kept
    /// The day after a missed day, until the ring closes: the streak survives only if it does.
    case atRisk

    /// The colour of the flame and of the days beside it: grey until the streak is in play today, orange once it is.
    var tint: Color { self == .open ? .secondary : .streak }
}

/// The streak's flame, drawn by the state: the one sign of the streak on every screen, always outside a ring. At risk
/// the outline is followed by a solid alert disc, so the state shows without its colour (vibrant and tinted widgets keep
/// one colour) and catches the eye at a glance. The size is the caller's font.
struct StreakFlame: View {
    var state: StreakState

    var body: some View {
        // On the text's baseline, as symbols beside text sit: the disc is a glyph of the flame's line, centred on it and on the
        // days beside it, not a badge raised to the flame's top.
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Image(systemName: state == .kept ? "flame.fill" : "flame")
            if state == .atRisk {
                Image(systemName: "exclamationmark.circle.fill")
                    .imageScale(.small)
            }
        }
        .foregroundStyle(state.tint)
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

    /// The lap a ring is on once it is past the goal, "2×": a tinted or clear widget draws every lap in one tone, so the number
    /// says what the arc over itself cannot. `nil` up to the goal.
    static func laps(_ fraction: Double) -> Int? {
        fraction > 1 ? Int(fraction.rounded(.up)) : nil
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
    /// One flat tone with a stronger track, for a tinted or clear widget (`ActivityRing.isFlat`).
    var isFlat = false
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
            progress: min(Self.maxLaps, max(0, fraction)), color: Color(head),
            tipColor: isFlat ? Color(head) : .dailyRingTail(of: head, scheme: colorScheme),
            lineWidth: lineWidth ?? Self.lineWidth(diameter: diameter), isFlat: isFlat
        )
        .animation(reduceMotion ? nil : filling, value: fraction)
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}
