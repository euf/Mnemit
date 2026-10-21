import Foundation
import VocabCore

/// Which grade a swipe of a card gives, and where each grade sends the card: left for
/// Forgot, right for Good, up on the right for Easy, down on the right for Hard. "No" is only
/// leftwards and every "yes" rightwards, so the direction tells which kind of answer it is.
///
/// The zones follow the arc of a right thumb. The thumb pivots at its base, low in the right
/// corner of the phone, so a swipe meant as "plain right" sweeps an arc that bends upwards and
/// often ends above the horizontal; with 25° on each side of it, such a swipe landed in Easy.
/// Good therefore takes -25° to +40°, 65° of arc centred 7.5° above the horizontal; Easy is
/// above it and Hard below, where it takes a deliberate curl of the thumb to go down. Forgot
/// takes a generous wedge to the left (±55° around the horizontal), as it is the only way
/// leftwards and the arc leans there too.
enum GradeSwipe {
    /// How far a drag must go before letting go grades, in points.
    static let commitDistance: CGFloat = 100
    /// Under this a drag has no direction yet.
    static let deadZone: CGFloat = 20
    /// A flick grades without reaching `commitDistance`: it has to move this far, and would
    /// carry this far (`DragGesture.Value.predictedEndTranslation`).
    static let flickMinimum: CGFloat = 30
    static let flickReach: CGFloat = 300
    /// To the left a drag is Forgot while its horizontal part is at least this share of its
    /// vertical part (tan 55° = 1 / 0.7).
    static let forgotSlope: CGFloat = 0.7
    /// To the right, in degrees above the horizontal: Easy above `easyAbove`, Hard below
    /// `hardBelow`, Good in between.
    static let easyAbove = 40.0
    static let hardBelow = -25.0
    /// Beyond this angle from the horizontal a drag to the right goes straight up or down, and
    /// gives no grade.
    static let verticalLimit = 85.0

    /// The grade the direction of a drag stands for; `nil` in the dead zone and for drags
    /// that go mostly up or down.
    static func zone(_ translation: CGSize) -> Grade? {
        let (dx, dy) = (translation.width, translation.height)
        guard hypot(dx, dy) >= deadZone else { return nil }
        if dx < 0 { return -dx >= abs(dy) * forgotSlope ? .again : nil }
        guard dx > 0 else { return nil }
        let angle = atan2(-dy, dx) * 180 / .pi
        guard abs(angle) <= verticalLimit else { return nil }
        return angle > easyAbove ? .easy : angle < hardBelow ? .hard : .good
    }

    /// The grade that letting go of a drag gives, if any: a flick, which goes by where it would
    /// end, or a drag that went `commitDistance`, which goes by where it is.
    static func released(translation: CGSize, predictedEnd: CGSize) -> Grade? {
        let distance = hypot(translation.width, translation.height)
        if distance >= commitDistance { return zone(translation) }
        guard distance >= flickMinimum, hypot(predictedEnd.width, predictedEnd.height) >= flickReach else { return nil }
        return zone(predictedEnd)
    }

    /// Where a card ends when it has flown out, from where it started.
    static func exit(of grade: Grade) -> CGSize {
        switch grade {
        case .again: CGSize(width: -640, height: 30)
        case .hard: CGSize(width: 560, height: 420)
        case .good: CGSize(width: 640, height: 0)
        case .easy: CGSize(width: 560, height: -420)
        }
    }
}
