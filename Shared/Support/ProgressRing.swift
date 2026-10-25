import SwiftUI
import VocabCore

/// What stands in the middle of a ring: the streak, a flame over its days, or nothing. The flame is the streak's
/// sign everywhere it shows (Today, the rests, the widget, the Mac), lit in `Color.streak` once today keeps it.
enum RingCenter: Equatable {
    case none
    /// The streak in days, 1 or more; `isLit` once today keeps it and no missed day waits for the ring.
    case streak(days: Int, isLit: Bool)

    /// The streak of `progress`; nothing at 0 days, and nothing before the first evaluation.
    init(_ progress: DailyProgress?) {
        guard let progress, progress.streak.days > 0 else {
            self = .none
            return
        }
        self = .streak(days: progress.streak.days, isLit: progress.isStreakLit)
    }

    /// The days: "12".
    var text: String? {
        guard case .streak(let days, _) = self else { return nil }
        return days.formatted(.number.grouping(.never))
    }

    /// What VoiceOver reads for the ring, before the progress: "Day streak: 5 days".
    var spokenLabel: String? {
        guard case .streak(let days, _) = self else { return nil }
        return String(localized: "Day streak: \(days) days")
    }
}

extension DailyProgress {
    /// Whether the streak's flame is lit: today keeps the streak, and no missed day waits for the ring to close.
    var isStreakLit: Bool {
        streakKeptToday && !isStreakAtRisk
    }

    /// The study day before today, when the learner studied on it: Today names it until today's first card.
    var yesterday: DayRecord? {
        guard records.count >= 2, let today = records.last?.day else { return nil }
        let record = records[records.count - 2]
        return record.day == today - 1 && record.done > 0 ? record : nil
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The thickness of the stroke: as much as the Fitness rings take, at least 3 pt.
    static func lineWidth(diameter: CGFloat) -> CGFloat {
        max(3, diameter * 0.15)
    }

    var body: some View {
        let lineWidth = Self.lineWidth(diameter: diameter)
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
/// in a small one.
private struct RingCenterLabel: View {
    var center: RingCenter
    var diameter: CGFloat
    var lineWidth: CGFloat

    /// From this diameter on, the flame stands over the days.
    private static let flameDiameter: CGFloat = 44

    var body: some View {
        if case .streak(_, let isLit) = center, let text = center.text {
            let showsFlame = diameter >= Self.flameDiameter
            VStack(spacing: -diameter * 0.03) {
                if showsFlame {
                    Image(systemName: "flame.fill")
                        .font(.system(size: diameter * 0.23, weight: .semibold))
                        .foregroundStyle(isLit ? Color.streak : Color.secondary)
                        .symbolRenderingMode(.monochrome)
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
