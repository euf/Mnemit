import CoreGraphics
import Testing

@testable import MacVocTrain
@testable import VocabCore

struct GradeSwipeTests {
    @Test func theDirectionTellsTheGrade() {
        #expect(GradeSwipe.zone(CGSize(width: -100, height: 0)) == .again)
        #expect(GradeSwipe.zone(CGSize(width: -100, height: 70)) == .again)
        #expect(GradeSwipe.zone(CGSize(width: 100, height: 0)) == .good)
        #expect(GradeSwipe.zone(CGSize(width: 100, height: -30)) == .good)
        #expect(GradeSwipe.zone(CGSize(width: 100, height: 30)) == .good)
        #expect(GradeSwipe.zone(CGSize(width: 100, height: -60)) == .easy)
        #expect(GradeSwipe.zone(CGSize(width: 100, height: 60)) == .hard)
    }

    @Test func noGradeInTheDeadZoneNorStraightUpOrDown() {
        #expect(GradeSwipe.zone(CGSize(width: 10, height: 10)) == nil)
        #expect(GradeSwipe.zone(CGSize(width: 0, height: -100)) == nil)
        // Left, but more up than left.
        #expect(GradeSwipe.zone(CGSize(width: -40, height: -100)) == nil)
    }

    @Test func letGoGradesAfterTheDistanceOrAFlick() {
        let slow = CGSize(width: 60, height: 0)
        // Too short, and would stop soon.
        #expect(GradeSwipe.released(translation: slow, predictedEnd: CGSize(width: 120, height: 0)) == nil)
        // Far enough.
        #expect(GradeSwipe.released(translation: CGSize(width: 120, height: 0), predictedEnd: CGSize(width: 130, height: 0)) == .good)
        // Short, but a flick: it would carry far.
        #expect(GradeSwipe.released(translation: CGSize(width: -50, height: 0), predictedEnd: CGSize(width: -400, height: 0)) == .again)
        // A flick has to move first.
        #expect(GradeSwipe.released(translation: CGSize(width: 5, height: 0), predictedEnd: CGSize(width: 400, height: 0)) == nil)
    }
}
