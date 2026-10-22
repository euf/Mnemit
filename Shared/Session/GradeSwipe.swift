import Foundation
import VocabCore

/// Which grade a swipe of a card gives, and where each grade sends the card: left for Forgot,
/// right for Good, up for Easy, down for Hard. "No" is only leftwards and every "yes" lies on
/// the other three sides.
///
/// The sectors are drawn on a clock face, 0 at the top, clockwise (compass degrees). The code
/// measures the finger's direction the other way round, as an angle counter-clockwise from east
/// with the screen's y turned up (math degrees, math = 90 - compass):
///
/// | Grade | Compass | Math | Reference (compass / math) |
/// |---|---|---|---|
/// | Easy, up | 330°…45° | `goodReach`…`easyEnd` = 45°…120° | 15° / `easyReference` 75° |
/// | Good, right | 45°…135° | `-goodReach`…`goodReach` = -45°…45° | 90° / `goodReference` 0° |
/// | Hard, down | 135°…210° | `hardStart`…`360 - goodReach` = 240°…315° | 165° / `hardReference` 285° |
/// | gap | 210°…240° | `forgotEnd`…`hardStart` = 210°…240° | none |
/// | Forgot, left | 240°…300° | `forgotStart`…`forgotEnd` = 150°…210° | 270° / `forgotReference` 180° |
/// | gap | 300°…330° | `easyEnd`…`forgotStart` = 120°…150° | none |
///
/// For a right-handed thumb the diagonal from the lower left to the upper right and the vertical
/// are the fast directions and the horizontal the slowest but most precise (Trudeau et al.,
/// Human Factors 2012), so Easy and Hard are wide and reach toward that diagonal, Forgot stays
/// 60° wide, and Good is a clean 90°.
///
/// Forgot is the only "no", and Easy by mistake for it is the costly slip, so a gap on both
/// sides keeps it away from the two "yes" grades next to it. Between two "yes" grades (right and
/// up, right and down) there is no gap: a misread there costs little. In a gap the swipe
/// gives no grade: no tint, no lit button, the card moves a share (`gapTravel`) of the finger's
/// way so it reads as "not a choice", and letting go springs it back, however far the finger
/// is and however fast.
///
/// While a swipe is under way the card is not moved along the finger but along the average of the
/// finger's direction and the grade's reference direction (`cardOffset`): a finger straight up
/// moves the card 7.5° to the right of up, Good goes right, and Forgot, whose reference is due
/// west, never leans up or down. Easy's card goes between 7.5° left of up and 30° right of up,
/// Hard's between 7.5° left of down and 30° right of down.
enum GradeSwipe {
    /// How far a drag must go before letting go grades, in points.
    static let commitDistance: CGFloat = 100
    /// Under this a drag has no direction yet.
    static let deadZone: CGFloat = 20
    /// A flick grades without reaching `commitDistance`: it has to move this far, and would
    /// carry this far (`DragGesture.Value.predictedEndTranslation`).
    static let flickMinimum: CGFloat = 30
    static let flickReach: CGFloat = 300

    /// Good takes this many degrees to either side of east: compass 45° to 135°.
    static let goodReach = 45.0
    /// Easy goes from `goodReach` to here: compass 330° to 45°.
    static let easyEnd = 120.0
    /// Forgot goes from here to `forgotEnd`: compass 240° to 300°. Between `easyEnd` and here
    /// lies the gap (compass 300° to 330°) that keeps Easy and Forgot apart.
    static let forgotStart = 150.0
    static let forgotEnd = 210.0
    /// Hard goes from here to `360 - goodReach`: compass 135° to 210°. Between `forgotEnd` and
    /// here lies the gap (compass 210° to 240°) that keeps Forgot and Hard apart.
    static let hardStart = 240.0

    /// The direction each grade pulls the card in, in degrees as `angle(of:)`, and the direction
    /// it flies off in: compass 15° for Easy (right of up), 90° for Good, 165° for Hard (right
    /// of down) and 270° for Forgot. Each lies inside its sector, within 45° of every direction
    /// of it, so the average with the finger never cancels.
    static let easyReference = 75.0
    static let goodReference = 0.0
    static let hardReference = 285.0
    static let forgotReference = 180.0

    /// How far a card flies off, in points, along its grade's reference direction.
    static let exitDistance: CGFloat = 640
    /// The share of the finger's way the card follows in a gap.
    static let gapTravel: CGFloat = 0.5

    /// The direction of a drag in degrees, 0 to under 360, counter-clockwise from east, with
    /// the screen's y (down) turned up.
    static func angle(of translation: CGSize) -> Double {
        let degrees = atan2(-translation.height, translation.width) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }

    /// The grade the direction of a drag stands for; `nil` in the dead zone and in the gaps.
    static func zone(_ translation: CGSize) -> Grade? {
        guard hypot(translation.width, translation.height) >= deadZone else { return nil }
        let degrees = angle(of: translation)
        if degrees <= goodReach || degrees >= 360 - goodReach { return .good }
        if degrees <= easyEnd { return .easy }
        if degrees >= forgotStart, degrees <= forgotEnd { return .again }
        if degrees >= hardStart { return .hard }
        return nil
    }

    /// Whether a drag is past the dead zone but points into a gap, where no grade is given.
    static func isInGap(_ translation: CGSize) -> Bool {
        hypot(translation.width, translation.height) >= deadZone && zone(translation) == nil
    }

    /// The grade that letting go of a drag gives, if any: a drag that went `commitDistance`
    /// goes by where it is, a flick by where it would end. A drag that points into a gap gives
    /// nothing, far or fast, and a flick has to start in a zone and end in one.
    static func released(translation: CGSize, predictedEnd: CGSize) -> Grade? {
        guard let grade = zone(translation) else { return nil }
        if hypot(translation.width, translation.height) >= commitDistance { return grade }
        guard hypot(translation.width, translation.height) >= flickMinimum,
            hypot(predictedEnd.width, predictedEnd.height) >= flickReach
        else { return nil }
        return zone(predictedEnd)
    }

    /// Whether letting go of a drag was a swipe that a gap sprang back: it went `commitDistance`
    /// or was a flick, and `released` gave no grade. Past the dead zone that is only so when the
    /// drag, or for a flick its predicted end, points into a gap.
    static func endedInGap(translation: CGSize, predictedEnd: CGSize) -> Bool {
        guard released(translation: translation, predictedEnd: predictedEnd) == nil else { return false }
        let moved = hypot(translation.width, translation.height)
        return moved >= commitDistance || (moved >= flickMinimum && hypot(predictedEnd.width, predictedEnd.height) >= flickReach)
    }

    /// The reference direction of a grade, in degrees as `angle(of:)`.
    static func reference(of grade: Grade) -> Double {
        switch grade {
        case .good: goodReference
        case .easy: easyReference
        case .again: forgotReference
        case .hard: hardReference
        }
    }

    /// Where the card is for a finger at `translation` while it points into the zone of `grade`:
    /// at the finger's distance, along the normalized average of the finger's unit direction
    /// and the grade's reference direction.
    static func pull(_ translation: CGSize, toward grade: Grade) -> CGSize {
        let distance = hypot(translation.width, translation.height)
        guard distance > 0 else { return .zero }
        let reference = reference(of: grade) * .pi / 180
        let x = translation.width / distance + cos(reference)
        let y = translation.height / distance - sin(reference)
        let length = hypot(x, y)
        // The sectors lie within 45° of their references, so the two never cancel.
        guard length > 0 else { return translation }
        return CGSize(width: x / length * distance, height: y / length * distance)
    }

    /// Where the card is for a finger at `translation`: under the dead zone, with the finger;
    /// in a zone, pulled toward the grade's reference; in a gap, a share of the finger's way.
    static func cardOffset(for translation: CGSize) -> CGSize {
        guard hypot(translation.width, translation.height) >= deadZone else { return translation }
        guard let grade = zone(translation) else {
            return CGSize(width: translation.width * gapTravel, height: translation.height * gapTravel)
        }
        return pull(translation, toward: grade)
    }

    /// Where a card ends when it has flown out, from where it started: `exitDistance` along the
    /// grade's reference direction.
    static func exit(of grade: Grade) -> CGSize {
        let reference = reference(of: grade) * .pi / 180
        return CGSize(width: exitDistance * cos(reference), height: -exitDistance * sin(reference))
    }
}
