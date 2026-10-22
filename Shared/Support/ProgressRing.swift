import SwiftUI
import VocabCore

/// What stands in the middle of a ring. Streak or lap, never both: the stream shows the lap
/// the learner is in, every other place the streak.
enum RingCenter: Equatable {
    case none
    /// The streak in days, 1 or more.
    case streak(days: Int)
    /// The lap the ring is in, 2 or more: the first lap shows nothing.
    case lap(Int)

    /// The middle of the ring for `progress`. `inStream` picks the lap: empty during the first
    /// lap, "×2" once the goal is reached, "×3" after the second lap. Otherwise the streak, and
    /// nothing at 0 days. Nothing before the first evaluation.
    init(_ progress: DailyProgress?, inStream: Bool) {
        guard let progress else {
            self = .none
            return
        }
        if inStream {
            self = progress.ring.laps >= 1 ? .lap(progress.ring.laps + 1) : .none
        } else {
            self = progress.streak.days > 0 ? .streak(days: progress.streak.days) : .none
        }
    }

    /// The big figure: "12", "×2".
    var text: String? {
        switch self {
        case .none: nil
        case .streak(let days): days.formatted(.number.grouping(.never))
        case .lap(let lap): "×" + lap.formatted(.number.grouping(.never))
        }
    }

    /// The small word under a streak, where the ring is big enough for one.
    var caption: String? {
        guard case .streak(let days) = self else { return nil }
        return days == 1 ? String(localized: "day") : String(localized: "days")
    }

    /// What VoiceOver reads for the ring, before the progress: "Day streak: 5 days", "Lap 2".
    var spokenLabel: String? {
        switch self {
        case .none: nil
        case .streak(let days): String(localized: "Day streak: \(days) days")
        case .lap(let lap): String(localized: "Lap \(lap)")
        }
    }
}

/// Today's cards done against the goal as an `ActivityRing` from a lighter tint of the accent to the
/// accent, with the figure of `RingCenter` in the middle.
///
/// Decoration only, the text beside it says the figures; the caller combines them for
/// VoiceOver. `fraction` animates, except under Reduce Motion.
struct ProgressRing: View {
    /// 0.4 is two fifths of the goal, 1.6 the second lap at three fifths.
    var fraction: Double
    var diameter: CGFloat
    var center: RingCenter = .none
    /// Whether VoiceOver reads what is in the middle ("Lap 2") as part of the element this ring
    /// sits in, for a caller that combines the ring with its figures. Otherwise the ring is hidden.
    var speaksCenter = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The thickness of the stroke: as much as the Fitness rings take, at least 3 pt.
    static func lineWidth(diameter: CGFloat) -> CGFloat {
        max(3, diameter * 0.15)
    }

    var body: some View {
        let lineWidth = Self.lineWidth(diameter: diameter)
        let ring = ZStack {
            ActivityRing(progress: max(0, fraction), color: .dailyRing, tipColor: .dailyRingTail, lineWidth: lineWidth)
                .animation(reduceMotion ? nil : .smooth, value: fraction)
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

/// The figure in the middle of a ring, with its caption where the ring is big enough.
private struct RingCenterLabel: View {
    var center: RingCenter
    var diameter: CGFloat
    var lineWidth: CGFloat

    /// From this diameter on, a streak has its word under the number.
    private static let captionDiameter: CGFloat = 56

    var body: some View {
        if let text = center.text {
            let caption = diameter >= Self.captionDiameter ? center.caption : nil
            VStack(spacing: 0) {
                Text(verbatim: text)
                    .font(.system(size: diameter * (caption == nil ? 0.38 : 0.34), weight: .bold, design: .rounded))
                    .monospacedDigit()
                if let caption {
                    Text(verbatim: caption)
                        .font(.system(size: max(9, diameter * 0.14), weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: diameter - 2 * lineWidth, height: diameter - 2 * lineWidth)
        }
    }
}
