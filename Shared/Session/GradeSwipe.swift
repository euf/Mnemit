import Foundation
import VocabCore

/// Which grade a swipe of a card gives, and where each grade sends the card: left for
/// Forgot, right for Good, right and up for Easy, right and down for Hard. "No" is only
/// leftwards and every "yes" rightwards, so the direction tells which kind of answer it is.
enum GradeSwipe {
    /// How far a drag must go before letting go grades, in points.
    static let commitDistance: CGFloat = 110
    /// Under this a drag has no direction yet.
    static let deadZone: CGFloat = 20
    /// A flick grades without reaching `commitDistance`: it has to move this far, and would
    /// carry this far (`DragGesture.Value.predictedEndTranslation`).
    static let flickMinimum: CGFloat = 30
    static let flickReach: CGFloat = 300
    /// Beyond this angle from the horizontal, to the right, a drag is Easy (up) or Hard (down).
    static let slope = 25.0

    /// The grade the direction of a drag stands for; `nil` in the dead zone and for drags
    /// that go up or down more than left.
    static func zone(_ translation: CGSize) -> Grade? {
        let (dx, dy) = (translation.width, translation.height)
        guard hypot(dx, dy) >= deadZone else { return nil }
        if dx < 0 { return abs(dx) >= abs(dy) * 0.8 ? .again : nil }
        guard dx > 0 else { return nil }
        let angle = atan2(-dy, dx) * 180 / .pi
        return angle > slope ? .easy : angle < -slope ? .hard : .good
    }

    /// The grade that letting go of a drag gives, if any: the drag went far enough, or was
    /// a flick that would have.
    static func released(translation: CGSize, predictedEnd: CGSize) -> Grade? {
        if hypot(translation.width, translation.height) >= commitDistance { return zone(translation) }
        guard hypot(translation.width, translation.height) >= flickMinimum, hypot(predictedEnd.width, predictedEnd.height) >= flickReach else { return nil }
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
