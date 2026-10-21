import Foundation
import VocabCore

/// Which grade a swipe of a card gives, and where each grade sends the card: left for Forgot,
/// right for Good, up for Easy, down for Hard. "No" is only leftwards and every "yes" lies on
/// the other three sides.
///
/// The finger's direction is read in sectors around the four axes, as an angle counter-clockwise
/// from east with the screen's y turned up:
///
/// - Good, east: `-goodReach` to `goodReach`, 110° wide;
/// - Easy, north: `goodReach` to `easyEnd`;
/// - a gap in the north-west: `easyEnd` to `forgotStart`, no grade;
/// - Forgot, west: `forgotStart` to `forgotEnd`;
/// - a gap in the south-west: `forgotEnd` to `hardStart`, no grade;
/// - Hard, south: `hardStart` to `-goodReach`.
///
/// Forgot is the only "no", and Easy by mistake for it is the costly slip, so a gap on both
/// sides keeps it away from the two "yes" grades next to it. Between two "yes" grades (east and
/// north, east and south) there is no gap: a misread there costs little. In a gap the swipe
/// gives no grade: no tint, no lit button, the card moves a share (`gapTravel`) of the finger's
/// way so it reads as "not a choice", and letting go springs it back, however far the finger
/// is and however fast.
///
/// While a swipe is under way the card is not moved along the finger but along the average of the
/// finger's direction and the grade's target (`cardOffset`): a finger straight up moves the card
/// up and to the right, between north and north-east. Every "yes" card leans right, and Forgot,
/// whose target is due west, never leans up or down.
enum GradeSwipe {
    /// How far a drag must go before letting go grades, in points.
    static let commitDistance: CGFloat = 100
    /// Under this a drag has no direction yet.
    static let deadZone: CGFloat = 20
    /// A flick grades without reaching `commitDistance`: it has to move this far, and would
    /// carry this far (`DragGesture.Value.predictedEndTranslation`).
    static let flickMinimum: CGFloat = 30
    static let flickReach: CGFloat = 300

    /// Good takes this many degrees to either side of east.
    static let goodReach = 55.0
    /// Easy goes from `goodReach` to here.
    static let easyEnd = 120.0
    /// Forgot goes from here to `forgotEnd`; between `easyEnd` and here lies the gap that keeps
    /// Easy and Forgot apart.
    static let forgotStart = 150.0
    static let forgotEnd = 210.0
    /// Hard goes from here to `360 - goodReach`; between `forgotEnd` and here lies the gap that
    /// keeps Forgot and Hard apart.
    static let hardStart = 240.0
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

    /// The direction a grade pulls the card in, in degrees as `angle(of:)`: Good east, Easy
    /// north-east, Forgot west, Hard south-east.
    static func target(of grade: Grade) -> Double {
        switch grade {
        case .good: 0
        case .easy: 45
        case .again: 180
        case .hard: -45
        }
    }

    /// Where the card is for a finger at `translation` while it points into the zone of `grade`:
    /// at the finger's distance, along the normalized average of the finger's unit direction
    /// and the target's.
    static func pull(_ translation: CGSize, toward grade: Grade) -> CGSize {
        let distance = hypot(translation.width, translation.height)
        guard distance > 0 else { return .zero }
        let target = target(of: grade) * .pi / 180
        let x = translation.width / distance + cos(target)
        let y = translation.height / distance - sin(target)
        let length = hypot(x, y)
        // The sectors lie within 75° of their targets, so the two never cancel.
        guard length > 0 else { return translation }
        return CGSize(width: x / length * distance, height: y / length * distance)
    }

    /// Where the card is for a finger at `translation`: under the dead zone, with the finger;
    /// in a zone, pulled toward the grade's target; in a gap, a share of the finger's way.
    static func cardOffset(for translation: CGSize) -> CGSize {
        guard hypot(translation.width, translation.height) >= deadZone else { return translation }
        guard let grade = zone(translation) else {
            return CGSize(width: translation.width * gapTravel, height: translation.height * gapTravel)
        }
        return pull(translation, toward: grade)
    }

    /// Where a card ends when it has flown out, from where it started: along the grade's target.
    static func exit(of grade: Grade) -> CGSize {
        switch grade {
        case .again: CGSize(width: -640, height: 0)
        case .hard: CGSize(width: 560, height: 560)
        case .good: CGSize(width: 640, height: 0)
        case .easy: CGSize(width: 560, height: -560)
        }
    }
}
