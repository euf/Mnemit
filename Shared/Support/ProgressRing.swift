import SwiftUI
import VocabCore

/// The streak's state on screen, which shape and colour both say: `flame` outlined in secondary grey until today's
/// streak step is done, `flame.fill` in `Color.streak` after, and, the day after a missed one, an outline in
/// `Color.streak` until the ring closes.
enum StreakState: Equatable {
    /// Today's streak step is not done.
    case open
    /// Today's streak step is done.
    case kept
    /// The day after a missed day, until the ring closes: the streak survives only if it does.
    case atRisk
}

/// The streak's flame, drawn by the state: the one sign of the streak on every screen. The size is the caller's font.
struct StreakFlame: View {
    var state: StreakState

    var body: some View {
        Image(systemName: state == .kept ? "flame.fill" : "flame")
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(state == .open ? Color.secondary : Color.streak)
    }
}

/// What stands in the middle of a ring: the streak, a flame over its days, the flame alone, or nothing. The flame is
/// the streak's sign everywhere it shows (Today, the rests, the widget, the Mac), by `StreakState`.
enum RingCenter: Equatable {
    case none
    /// The streak in days, 1 or more.
    case streak(days: Int, state: StreakState)
    /// The flame alone, for the ring in the study bar, which has no room for the days.
    case flame(days: Int, state: StreakState)

    /// The streak of `progress`; nothing at 0 days, and nothing before the first evaluation.
    init(_ progress: DailyProgress?) {
        guard let progress, progress.streak.days > 0 else {
            self = .none
            return
        }
        self = .streak(days: progress.streak.days, state: progress.streakState)
    }

    /// The flame alone for `progress`: outlined before the first evaluation and before the first streak.
    static func flame(_ progress: DailyProgress?) -> RingCenter {
        .flame(days: progress?.streak.days ?? 0, state: progress?.streakState ?? .open)
    }

    /// The days: "12".
    var text: String? {
        guard case .streak(let days, _) = self else { return nil }
        return days.formatted(.number.grouping(.never))
    }

    /// What VoiceOver reads for the ring, before the progress: "12-day streak, kept today".
    var spokenLabel: String? {
        switch self {
        case .none: nil
        case .streak(let days, let state), .flame(let days, let state):
            switch state {
            case .kept: String(localized: "\(days)-day streak, kept today")
            case .open: String(localized: "\(days)-day streak, not kept yet")
            case .atRisk: String(localized: "\(days)-day streak, at risk")
            }
        }
    }
}

extension DailyProgress {
    /// The state of the streak's flame: at risk after a missed day until the ring closes, else by today's streak step.
    var streakState: StreakState {
        if isStreakAtRisk { return .atRisk }
        return streakKeptToday ? .kept : .open
    }

    /// The day after a missed day, until the ring closes: the streak survives only if it does.
    var isStreakAtRisk: Bool {
        streak.repairCards != nil && !ring.isGoalMet
    }
}

enum DailyRingFigure {
    /// The ring's fraction: the figures', or `shown` cards (done and the parts of those underway) of the
    /// goal while the ring is ahead of them.
    static func fraction(_ progress: DailyProgress?, shown: Double?) -> Double {
        guard let ring = progress?.ring else { return 0 }
        return shown.map { $0 / Double(max(1, ring.goal)) } ?? ring.fraction
    }
}

/// Today's cards done against the goal as an `ActivityRing` from a lighter tint of the accent to the
/// accent, with the figure of `RingCenter` in the middle.
///
/// Decoration only, the text beside it says the figures; the caller combines them for
/// VoiceOver. `fraction` animates, except under Reduce Motion.
struct ProgressRing: View {
    /// 0.4 is two fifths of the goal; 1 and more is a closed ring.
    var fraction: Double
    var diameter: CGFloat
    var center: RingCenter = .none
    /// Whether VoiceOver reads what is in the middle ("Day streak: 5 days") as part of the element this ring
    /// sits in, for a caller that combines the ring with its figures. Otherwise the ring is hidden.
    var speaksCenter = false
    /// How the ring fills to a new fraction: quick in the study bar, slow enough to watch on Today.
    var filling: Animation = .smooth
    /// The stroke's thickness; `nil` takes `lineWidth(diameter:)`.
    var lineWidth: CGFloat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The thickness of the stroke: as much as the Fitness rings take, at least 3 pt.
    static func lineWidth(diameter: CGFloat) -> CGFloat {
        max(3, diameter * 0.15)
    }

    var body: some View {
        let lineWidth = lineWidth ?? Self.lineWidth(diameter: diameter)
        let ring = ZStack {
            ActivityRing(progress: min(1, max(0, fraction)), color: .dailyRing, tipColor: .dailyRingTail, lineWidth: lineWidth)
                .animation(reduceMotion ? nil : filling, value: fraction)
            RingCenterLabel(center: center, diameter: diameter, lineWidth: lineWidth)
        }
        .frame(width: diameter, height: diameter)
        if speaksCenter, let spoken = center.spokenLabel {
            ring
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: spoken))
        } else {
            ring.accessibilityHidden(true)
        }
    }
}

/// The streak in the middle of a ring: a flame over the days where the ring is big enough for both, the days alone
/// in a small one, or the flame alone.
private struct RingCenterLabel: View {
    var center: RingCenter
    var diameter: CGFloat
    var lineWidth: CGFloat

    /// From this diameter on, the flame stands over the days.
    private static let flameDiameter: CGFloat = 44

    var body: some View {
        switch center {
        case .none:
            EmptyView()
        case .flame(_, let state):
            StreakFlame(state: state)
                .font(.system(size: diameter * 0.42, weight: .semibold))
        case .streak(_, let state):
            if let text = center.text {
                let showsFlame = diameter >= Self.flameDiameter
                VStack(spacing: -diameter * 0.03) {
                    if showsFlame {
                        StreakFlame(state: state)
                            .font(.system(size: diameter * 0.23, weight: .semibold))
                    }
                    Text(verbatim: text)
                        .font(.system(size: diameter * (showsFlame ? 0.3 : 0.38), weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: diameter - 2 * lineWidth, height: diameter - 2 * lineWidth)
            }
        }
    }
}
