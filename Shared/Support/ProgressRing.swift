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

/// What stands in the middle of a ring: the ring's own quantity, the cards left to close it, or a check once it is
/// closed. The size of the ring decides how much of it shows (`shown(at:)`): the figure from 56 pt on, its caption
/// from 88 pt, nothing in the rings of the bars and of the week. The streak is never in a ring (`StreakChip`).
enum RingCenter: Equatable {
    case none
    /// The cards that close the ring, 1 or more.
    case cardsLeft(Int)
    /// The ring is closed.
    case done

    /// The figure from this diameter on.
    static let figureDiameter: CGFloat = 56
    /// "cards left" under the figure from this diameter on.
    static let captionDiameter: CGFloat = 88

    /// The middle of `progress`' ring: the cards left, a check once none are; nothing before the first evaluation.
    init(_ progress: DailyProgress?) {
        guard let progress else {
            self = .none
            return
        }
        let left = progress.cardsToClose
        self = left > 0 ? .cardsLeft(left) : .done
    }

    /// What a ring of `diameter` shows of this middle: all of it, or nothing where there is no room.
    func shown(at diameter: CGFloat) -> RingCenter {
        diameter >= Self.figureDiameter ? self : .none
    }

    /// Whether a ring of `diameter` puts the caption under the figure.
    func showsCaption(at diameter: CGFloat) -> Bool {
        if case .cardsLeft = self { return diameter >= Self.captionDiameter }
        return false
    }

    /// The figure: "12".
    var text: String? {
        guard case .cardsLeft(let count) = self else { return nil }
        return count.formatted(.number.grouping(.never))
    }

    /// "cards left", the caption under the figure, in the plural form of the count: the phrase "8 cards left" without its
    /// number, which stands large above it. A language that does not put the number first shows the whole phrase.
    var caption: String? {
        guard case .cardsLeft(let count) = self else { return nil }
        let phrase = String(localized: "\(count) cards left (caption)")
        let number = count.formatted()
        guard phrase.hasPrefix(number) else { return phrase }
        return String(phrase.dropFirst(number.count)).trimmingCharacters(in: .whitespaces)
    }

    /// What VoiceOver reads for the ring: "12 cards left", "Ring closed".
    var spokenLabel: String? {
        switch self {
        case .none: nil
        case .cardsLeft(let count): String(localized: "\(count) cards left")
        case .done: String(localized: "Ring closed")
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

/// Today's cards done against the goal as an `ActivityRing` from a lighter tint of the accent to the
/// accent, with the cards left or a check in the middle where the ring is big enough (`RingCenter`).
///
/// One ring for every surface. Without `speaksCenter` it is decoration, the text beside it says the figures; the caller
/// combines them for VoiceOver. `fraction` animates, except under Reduce Motion.
struct ProgressRing: View {
    /// 0.4 is two fifths of the goal; 1 is a closed ring, and past 1 the ring goes on over itself, a second lap and a
    /// third, which is as far as it is drawn (`maxLaps`).
    var fraction: Double
    var diameter: CGFloat
    var center: RingCenter = .none
    /// Whether VoiceOver reads what is in the middle ("12 cards left") as part of the element this ring
    /// sits in, for a caller that combines the ring with its figures. Otherwise the ring is hidden.
    var speaksCenter = false
    /// How the ring fills to a new fraction: quick in the study bar, slow enough to watch on Today.
    var filling: Animation = .smooth
    /// The stroke's thickness; `nil` takes `lineWidth(diameter:)`.
    var lineWidth: CGFloat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The laps drawn at most: three times the goal.
    static let maxLaps = DayRecord.maxLaps

    /// The thickness of the stroke: as much as the Fitness rings take, at least 3 pt.
    static func lineWidth(diameter: CGFloat) -> CGFloat {
        max(3, diameter * 0.15)
    }

    var body: some View {
        let lineWidth = lineWidth ?? Self.lineWidth(diameter: diameter)
        let ring = ZStack {
            ActivityRing(progress: min(Self.maxLaps, max(0, fraction)), color: .dailyRing, tipColor: .dailyRingTail, lineWidth: lineWidth)
                .animation(reduceMotion ? nil : filling, value: fraction)
            RingCenterLabel(center: center, diameter: diameter, lineWidth: lineWidth)
        }
        .frame(width: diameter, height: diameter)
        if speaksCenter, let spoken = center.shown(at: diameter).spokenLabel {
            ring
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: spoken))
        } else {
            ring.accessibilityHidden(true)
        }
    }
}

/// The middle of a ring: the cards left as a large figure with "cards left" under it where the ring is big enough for
/// both, the figure alone in a smaller one, or a check once the ring is closed. The text scales with the ring, not
/// with the text size: the ring does not grow with it either.
private struct RingCenterLabel: View {
    var center: RingCenter
    var diameter: CGFloat
    var lineWidth: CGFloat

    var body: some View {
        switch center.shown(at: diameter) {
        case .none:
            EmptyView()
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: diameter * 0.36, weight: .bold))
                .foregroundStyle(Color.dailyRing)
        case .cardsLeft:
            let showsCaption = center.showsCaption(at: diameter)
            VStack(spacing: -diameter * 0.02) {
                Text(verbatim: center.text ?? "")
                    .font(.system(size: diameter * (showsCaption ? 0.32 : 0.4), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if showsCaption, let caption = center.caption {
                    Text(verbatim: caption)
                        .font(.system(size: max(10, diameter * 0.085)))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(width: diameter - 2 * lineWidth, height: diameter - 2 * lineWidth)
        }
    }
}
