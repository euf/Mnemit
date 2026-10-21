import CoreGraphics
import Testing

@testable import VocTrain
@testable import VocabCore

/// `GradeSwipe` is in `Shared/`, compiled into both apps; its tests run here, on the simulator
/// without a Mac app host.
struct GradeSwipeTests {
    /// A drag of 100 points to the right, `degrees` above the horizontal.
    private func right(_ degrees: Double, length: CGFloat = 100) -> CGSize {
        let radians = degrees * .pi / 180
        return CGSize(width: length * cos(radians), height: -length * sin(radians))
    }

    @Test func theDirectionTellsTheGrade() {
        #expect(GradeSwipe.zone(CGSize(width: -100, height: 0)) == .again)
        #expect(GradeSwipe.zone(CGSize(width: -100, height: 70)) == .again)
        #expect(GradeSwipe.zone(CGSize(width: -100, height: -70)) == .again)
        #expect(GradeSwipe.zone(right(0)) == .good)
        #expect(GradeSwipe.zone(right(30)) == .good)
        #expect(GradeSwipe.zone(right(60)) == .easy)
        #expect(GradeSwipe.zone(right(-60)) == .hard)
    }

    @Test func goodTakesTheArcOfAThumb() {
        // Up to 40° above the horizontal is still Good: the thumb bends up.
        #expect(GradeSwipe.zone(right(39)) == .good)
        #expect(GradeSwipe.zone(right(41)) == .easy)
        // Down to 25° below it.
        #expect(GradeSwipe.zone(right(-24)) == .good)
        #expect(GradeSwipe.zone(right(-26)) == .hard)
        #expect(GradeSwipe.zone(right(10)) == .good)
    }

    @Test func theLimitsAreTheNamedConstants() {
        #expect(GradeSwipe.zone(right(GradeSwipe.easyAbove - 0.5)) == .good)
        #expect(GradeSwipe.zone(right(GradeSwipe.easyAbove + 0.5)) == .easy)
        #expect(GradeSwipe.zone(right(GradeSwipe.hardBelow + 0.5)) == .good)
        #expect(GradeSwipe.zone(right(GradeSwipe.hardBelow - 0.5)) == .hard)
        #expect(GradeSwipe.zone(right(GradeSwipe.verticalLimit - 0.5)) == .easy)
        #expect(GradeSwipe.zone(right(GradeSwipe.verticalLimit + 0.5)) == nil)
        #expect(GradeSwipe.zone(right(-GradeSwipe.verticalLimit + 0.5)) == .hard)
        #expect(GradeSwipe.zone(right(-GradeSwipe.verticalLimit - 0.5)) == nil)
    }

    @Test func forgotNeedsMoreLeftThanUp() {
        #expect(GradeSwipe.zone(CGSize(width: -71, height: 100)) == .again)
        #expect(GradeSwipe.zone(CGSize(width: -69, height: 100)) == nil)
        #expect(GradeSwipe.zone(CGSize(width: -69, height: -100)) == nil)
        // Left, but more up than left.
        #expect(GradeSwipe.zone(CGSize(width: -40, height: -100)) == nil)
    }

    @Test func noGradeInTheDeadZoneNorStraightUpOrDown() {
        #expect(GradeSwipe.zone(CGSize(width: 10, height: 10)) == nil)
        #expect(GradeSwipe.zone(CGSize(width: 0, height: -100)) == nil)
        #expect(GradeSwipe.zone(CGSize(width: 0, height: 100)) == nil)
        #expect(GradeSwipe.zone(CGSize(width: 5, height: -100)) == nil)
        #expect(GradeSwipe.zone(CGSize(width: 5, height: 100)) == nil)
    }

    @Test func letGoGradesAfterTheDistanceOrAFlick() {
        let slow = CGSize(width: 60, height: 0)
        // Too short, and would stop soon.
        #expect(GradeSwipe.released(translation: slow, predictedEnd: CGSize(width: 120, height: 0)) == nil)
        #expect(GradeSwipe.released(translation: CGSize(width: 99, height: 0), predictedEnd: CGSize(width: 110, height: 0)) == nil)
        // Far enough.
        #expect(GradeSwipe.released(translation: CGSize(width: 101, height: 0), predictedEnd: CGSize(width: 110, height: 0)) == .good)
        // Short, but a flick: it would carry far.
        #expect(GradeSwipe.released(translation: CGSize(width: -50, height: 0), predictedEnd: CGSize(width: -400, height: 0)) == .again)
        // A flick has to move first.
        #expect(GradeSwipe.released(translation: CGSize(width: 5, height: 0), predictedEnd: CGSize(width: 400, height: 0)) == nil)
    }

    @Test func aFlickGoesByWhereItWouldEnd() {
        // It starts out upwards, as the thumb does, and would end in the Good zone.
        let started = right(55, length: 50)
        let end = right(20, length: 400)
        #expect(GradeSwipe.zone(started) == .easy)
        #expect(GradeSwipe.released(translation: started, predictedEnd: end) == .good)
        // The same without the flick: too short to grade.
        #expect(GradeSwipe.released(translation: started, predictedEnd: right(20, length: 200)) == nil)
    }
}
