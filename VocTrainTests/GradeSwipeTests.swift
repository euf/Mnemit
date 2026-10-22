import CoreGraphics
import Testing

@testable import VocTrain
@testable import VocabCore

/// `GradeSwipe` is in `Shared/`, compiled into both apps; its tests run here, on the simulator
/// without a Mac app host.
struct GradeSwipeTests {
    /// A drag of `length` points in the direction `degrees` counter-clockwise from east, with
    /// the screen's y turned up: 90 is straight up the screen.
    private func swipe(_ degrees: Double, length: CGFloat = 100) -> CGSize {
        let radians = degrees * .pi / 180
        return CGSize(width: length * cos(radians), height: -length * sin(radians))
    }

    /// The direction of a size in degrees, as `GradeSwipe.angle(of:)`.
    private func direction(_ size: CGSize) -> Double {
        GradeSwipe.angle(of: size)
    }

    // MARK: Sectors

    @Test func theCentreOfEachSectorGivesItsGrade() {
        #expect(GradeSwipe.zone(swipe(0)) == .good)
        #expect(GradeSwipe.zone(swipe(90)) == .easy)
        #expect(GradeSwipe.zone(swipe(180)) == .again)
        #expect(GradeSwipe.zone(swipe(270)) == .hard)
        #expect(GradeSwipe.zone(swipe(-90)) == .hard)
        // The straight drags as the screen reports them: y grows downwards.
        #expect(GradeSwipe.zone(CGSize(width: 100, height: 0)) == .good)
        #expect(GradeSwipe.zone(CGSize(width: 0, height: -100)) == .easy)
        #expect(GradeSwipe.zone(CGSize(width: -100, height: 0)) == .again)
        #expect(GradeSwipe.zone(CGSize(width: 0, height: 100)) == .hard)
    }

    @Test func theSectorsAreTheOnesTheOwnerChose() {
        // Good -55° to 55°, Easy 55° to 120°, a gap to 150°, Forgot 150° to 210°, a gap to 240°,
        // Hard 240° to 305°.
        let sectors: [(from: Double, to: Double, grade: Grade?)] = [
            (0, 54.5, .good), (55.5, 119.5, .easy), (120.5, 149.5, nil), (150.5, 209.5, .again),
            (210.5, 239.5, nil), (240.5, 304.5, .hard), (305.5, 359.5, .good),
        ]
        for (from, to, grade) in sectors {
            for degrees in stride(from: from, through: to, by: 0.5) {
                #expect(GradeSwipe.zone(swipe(degrees)) == grade, "at \(degrees)°")
            }
        }
        #expect(GradeSwipe.goodReach == 55)
        #expect(GradeSwipe.easyEnd == 120)
        #expect(GradeSwipe.forgotStart == 150)
        #expect(GradeSwipe.forgotEnd == 210)
        #expect(GradeSwipe.hardStart == 240)
    }

    @Test func theEdgesAreTheNamedConstants() {
        func zone(_ degrees: Double) -> Grade? { GradeSwipe.zone(swipe(degrees)) }
        // Good and Easy, Good and Hard: no gap between two kinds of "yes".
        #expect(zone(GradeSwipe.goodReach - 0.5) == .good)
        #expect(zone(GradeSwipe.goodReach + 0.5) == .easy)
        #expect(zone(-GradeSwipe.goodReach + 0.5) == .good)
        #expect(zone(-GradeSwipe.goodReach - 0.5) == .hard)
        // Easy, the gap, Forgot.
        #expect(zone(GradeSwipe.easyEnd - 0.5) == .easy)
        #expect(zone(GradeSwipe.easyEnd + 0.5) == nil)
        #expect(zone(GradeSwipe.forgotStart - 0.5) == nil)
        #expect(zone(GradeSwipe.forgotStart + 0.5) == .again)
        // Forgot, the gap, Hard.
        #expect(zone(GradeSwipe.forgotEnd - 0.5) == .again)
        #expect(zone(GradeSwipe.forgotEnd + 0.5) == nil)
        #expect(zone(GradeSwipe.hardStart - 0.5) == nil)
        #expect(zone(GradeSwipe.hardStart + 0.5) == .hard)
    }

    @Test func eachSectorLiesWithinReachOfItsTarget() {
        // The two never cancel when they are averaged: no sector goes 90° from its target.
        for degrees in stride(from: 0.0, to: 360.0, by: 1) {
            guard let grade = GradeSwipe.zone(swipe(degrees)) else { continue }
            var apart = abs(degrees - GradeSwipe.target(of: grade)).truncatingRemainder(dividingBy: 360)
            if apart > 180 { apart = 360 - apart }
            #expect(apart < 90, "\(grade) at \(degrees)°")
        }
    }

    @Test func aGapGivesNoGradeNorADirectionWithinTheDeadZone() {
        #expect(GradeSwipe.zone(swipe(135)) == nil)
        #expect(GradeSwipe.zone(swipe(225)) == nil)
        #expect(GradeSwipe.isInGap(swipe(135)))
        #expect(GradeSwipe.isInGap(swipe(225)))
        // Under the dead zone there is no direction yet, so no gap either.
        #expect(GradeSwipe.zone(swipe(0, length: 10)) == nil)
        #expect(!GradeSwipe.isInGap(swipe(135, length: 10)))
        #expect(!GradeSwipe.isInGap(swipe(90)))
        #expect(GradeSwipe.zone(.zero) == nil)
    }

    @Test func forgotIsFarFromTheTwoYesGradesItWouldBeMistakenFor() {
        // From the middle of Easy to the middle of Forgot, and Forgot to Hard: 90° and a gap
        // between; Forgot and Easy never share an edge.
        #expect(GradeSwipe.forgotStart - GradeSwipe.easyEnd >= 30)
        #expect(GradeSwipe.hardStart - GradeSwipe.forgotEnd >= 30)
    }

    // MARK: Letting go

    @Test func letGoGradesAfterTheDistanceOrAFlick() {
        let slow = CGSize(width: 60, height: 0)
        // Too short, and would stop soon.
        #expect(GradeSwipe.released(translation: slow, predictedEnd: CGSize(width: 120, height: 0)) == nil)
        #expect(GradeSwipe.released(translation: CGSize(width: 99, height: 0), predictedEnd: CGSize(width: 110, height: 0)) == nil)
        // Far enough, in each direction.
        #expect(GradeSwipe.released(translation: CGSize(width: 101, height: 0), predictedEnd: CGSize(width: 110, height: 0)) == .good)
        #expect(GradeSwipe.released(translation: CGSize(width: -101, height: 0), predictedEnd: CGSize(width: -110, height: 0)) == .again)
        #expect(GradeSwipe.released(translation: CGSize(width: 0, height: -101), predictedEnd: CGSize(width: 0, height: -110)) == .easy)
        #expect(GradeSwipe.released(translation: CGSize(width: 0, height: 101), predictedEnd: CGSize(width: 0, height: 110)) == .hard)
        // Short, but a flick: it would carry far.
        #expect(GradeSwipe.released(translation: CGSize(width: -50, height: 0), predictedEnd: CGSize(width: -400, height: 0)) == .again)
        #expect(GradeSwipe.released(translation: CGSize(width: 0, height: -50), predictedEnd: CGSize(width: 0, height: -400)) == .easy)
        #expect(GradeSwipe.released(translation: CGSize(width: 0, height: 50), predictedEnd: CGSize(width: 0, height: 400)) == .hard)
        // A flick has to move first.
        #expect(GradeSwipe.released(translation: CGSize(width: 5, height: 0), predictedEnd: CGSize(width: 400, height: 0)) == nil)
    }

    @Test func aFlickGoesByWhereItWouldEnd() {
        // It starts out upwards, as the thumb does, and would end in the Good zone.
        let started = swipe(70, length: 50)
        let end = swipe(20, length: 400)
        #expect(GradeSwipe.zone(started) == .easy)
        #expect(GradeSwipe.released(translation: started, predictedEnd: end) == .good)
        // The same without the flick: too short to grade.
        #expect(GradeSwipe.released(translation: started, predictedEnd: swipe(20, length: 200)) == nil)
    }

    @Test func letGoInAGapSpringsBackFarOrFast() {
        for degrees in [125.0, 135, 145, 215, 225, 235] {
            // Past the commit distance, far beyond it.
            #expect(GradeSwipe.released(translation: swipe(degrees, length: 120), predictedEnd: swipe(degrees, length: 120)) == nil)
            #expect(GradeSwipe.released(translation: swipe(degrees, length: 400), predictedEnd: swipe(degrees, length: 400)) == nil)
            // A flick that is in the gap, and one that would end in a zone but starts in the gap.
            #expect(GradeSwipe.released(translation: swipe(degrees, length: 50), predictedEnd: swipe(degrees, length: 400)) == nil)
            #expect(GradeSwipe.released(translation: swipe(degrees, length: 50), predictedEnd: swipe(0, length: 400)) == nil)
            #expect(GradeSwipe.released(translation: swipe(degrees, length: 50), predictedEnd: swipe(90, length: 400)) == nil)
            #expect(GradeSwipe.released(translation: swipe(degrees, length: 50), predictedEnd: swipe(180, length: 400)) == nil)
            // A flick that starts in a zone and would end in the gap.
            #expect(GradeSwipe.released(translation: swipe(0, length: 50), predictedEnd: swipe(degrees, length: 400)) == nil)
        }
    }

    // MARK: The way of the card

    @Test func theFingerAndTheTargetAreAveraged() {
        func card(_ degrees: Double, _ grade: Grade, length: CGFloat = 100) -> (angle: Double, length: Double) {
            let moved = GradeSwipe.pull(swipe(degrees, length: length), toward: grade)
            return (direction(moved), hypot(moved.width, moved.height))
        }
        // A finger straight up moves the card up and to the right, between north and north-east.
        #expect(abs(card(90, .easy).angle - 67.5) < 0.001)
        // Straight down, down and to the right.
        #expect(abs(card(270, .hard).angle - 292.5) < 0.001)
        // Along the target there is nothing to bend.
        #expect(abs(card(0, .good).angle - 0) < 0.001 || abs(card(0, .good).angle - 360) < 0.001)
        #expect(abs(card(180, .again).angle - 180) < 0.001)
        #expect(abs(card(45, .easy).angle - 45) < 0.001)
        // The edges of the sectors.
        #expect(abs(card(55, .easy).angle - 50) < 0.001)
        #expect(abs(card(120, .easy).angle - 82.5) < 0.001)
        #expect(abs(card(55, .good).angle - 27.5) < 0.001)
        #expect(abs(card(-55, .good).angle - (360 - 27.5)) < 0.001)
        #expect(abs(card(150, .again).angle - 165) < 0.001)
        #expect(abs(card(210, .again).angle - 195) < 0.001)
        // At the finger's distance, whatever the angle and the length.
        for grade in Grade.allCases {
            for length in [20.0, 60, 100, 250] {
                #expect(abs(card(GradeSwipe.target(of: grade) + 20, grade, length: CGFloat(length)).length - length) < 0.001)
            }
        }
    }

    @Test func everyYesLeansRightAndForgotNeverLeansUpOrDown() {
        for degrees in stride(from: 0.0, to: 360.0, by: 1) {
            let finger = swipe(degrees)
            guard let grade = GradeSwipe.zone(finger) else { continue }
            let moved = GradeSwipe.pull(finger, toward: grade)
            if grade == .again {
                // Forgot's target is due west: it pulls the card toward the horizontal, never away.
                #expect(abs(moved.height) <= abs(finger.height) + 0.001)
                #expect(moved.width < 0)
            } else {
                #expect(moved.width > 0, "\(grade) at \(degrees)°")
            }
        }
    }

    @Test func theCardGoesAHalfWayInAGapAndWithTheFingerBelowTheDeadZone() {
        let gap = swipe(135, length: 120)
        let half = GradeSwipe.cardOffset(for: gap)
        #expect(abs(half.width - gap.width * GradeSwipe.gapTravel) < 0.001)
        #expect(abs(half.height - gap.height * GradeSwipe.gapTravel) < 0.001)
        #expect(GradeSwipe.gapTravel == 0.5)
        // Under the dead zone: the finger, whatever its direction.
        let short = swipe(90, length: 15)
        #expect(GradeSwipe.cardOffset(for: short) == short)
        // In a zone: bent.
        let up = GradeSwipe.cardOffset(for: swipe(90))
        #expect(abs(direction(up) - 67.5) < 0.001)
    }

    @Test func aCardFliesOffAlongTheTargetOfItsGrade() {
        for grade in Grade.allCases {
            var apart = abs(direction(GradeSwipe.exit(of: grade)) - GradeSwipe.target(of: grade)).truncatingRemainder(dividingBy: 360)
            if apart > 180 { apart = 360 - apart }
            #expect(apart < 0.001, "\(grade)")
        }
    }
}

/// What `CardFlight` does with a drag: the card's way, the tint, the lit button and the tick.
@MainActor
struct CardFlightSwipeTests {
    private func swipe(_ degrees: Double, length: CGFloat = 100) -> CGSize {
        let radians = degrees * .pi / 180
        return CGSize(width: length * cos(radians), height: -length * sin(radians))
    }

    private func direction(_ size: CGSize) -> Double {
        GradeSwipe.angle(of: size)
    }

    @Test func aSwipeUpMovesTheCardUpAndToTheRightInTheColourOfEasy() {
        let flight = CardFlight()
        flight.drag(swipe(90, length: 120), isRevealed: true)
        #expect(abs(direction(flight.offset) - 67.5) < 0.001)
        #expect(abs(hypot(flight.offset.width, flight.offset.height) - 120) < 0.001)
        #expect(flight.zone == .easy)
        #expect(flight.tint == .easy)
        #expect(flight.highlighted == .easy)
        #expect(flight.committing == .easy)
        // Turns the way it moves.
        #expect(flight.rotation.degrees > 0)
    }

    @Test func eachGradeBendsTheCardTowardItsTarget() {
        let cases: [(finger: Double, grade: Grade, card: Double)] = [
            (90, .easy, 67.5), (270, .hard, 292.5), (0, .good, 0), (180, .again, 180), (160, .again, 170),
        ]
        for (finger, grade, card) in cases {
            let flight = CardFlight()
            flight.drag(swipe(finger), isRevealed: true)
            let moved = direction(flight.offset)
            #expect(abs(moved - card) < 0.001 || abs(moved - card - 360) < 0.001, "\(grade)")
            #expect(flight.zone == grade)
            #expect(flight.highlighted == grade)
        }
    }

    @Test func inAGapTheCardGoesHalfWayWithoutGradeTintOrLitButton() {
        for degrees in [135.0, 225] {
            let flight = CardFlight()
            let finger = swipe(degrees, length: 140)
            flight.drag(finger, isRevealed: true)
            #expect(abs(flight.offset.width - finger.width * 0.5) < 0.001)
            #expect(abs(flight.offset.height - finger.height * 0.5) < 0.001)
            #expect(flight.zone == nil)
            #expect(flight.isInGap)
            #expect(flight.tintStrength == 0)
            #expect(flight.highlighted == nil)
            // Past the commit distance too.
            #expect(flight.committing == nil)
        }
    }

    @Test func movingFromAZoneIntoAGapTakesTheGradeBack() {
        let flight = CardFlight()
        flight.drag(swipe(90, length: 130), isRevealed: true)
        #expect(flight.highlighted == .easy)
        flight.drag(swipe(135, length: 130), isRevealed: true)
        #expect(flight.zone == nil)
        #expect(flight.highlighted == nil)
        #expect(flight.committing == nil)
        flight.drag(swipe(170, length: 130), isRevealed: true)
        #expect(flight.zone == .again)
        #expect(!flight.isInGap)
    }

    /// One haptic per grade: at the commit distance for a swipe, none again when the committed
    /// card flies; at the flight for a grade given without a commit (button, key, flick).
    @Test func oneHapticPerGrade() {
        let flight = CardFlight()
        flight.drag(swipe(0, length: 50), isRevealed: true)
        #expect(flight.gradeFeedback == 0)
        flight.drag(swipe(0, length: 130), isRevealed: true)
        #expect(flight.gradeFeedback == 1)
        flight.drag(swipe(5, length: 140), isRevealed: true)
        #expect(flight.gradeFeedback == 1)
        // Another grade at the commit distance is felt; a gap is not.
        flight.drag(swipe(90, length: 130), isRevealed: true)
        #expect(flight.gradeFeedback == 2)
        flight.drag(swipe(135, length: 130), isRevealed: true)
        #expect(flight.gradeFeedback == 2)
        flight.drag(swipe(90, length: 130), isRevealed: true)
        #expect(flight.gradeFeedback == 3)
        flight.fly(.easy, reduceMotion: true) {}
        #expect(flight.gradeFeedback == 3)

        let button = CardFlight()
        button.fly(.good, reduceMotion: true) {}
        #expect(button.gradeFeedback == 1)
    }

    @Test func beforeTheAnswerTheCardOnlyGivesWay() {
        let flight = CardFlight()
        let finger = swipe(90, length: 120)
        flight.drag(finger, isRevealed: false)
        #expect(abs(flight.offset.width - finger.width * 0.25) < 0.001)
        #expect(abs(flight.offset.height - finger.height * 0.25) < 0.001)
        #expect(flight.zone == nil)
        #expect(!flight.isInGap)
        #expect(flight.tintStrength == 0)
    }

    @Test func belowTheDeadZoneTheCardGoesWithTheFinger() {
        let flight = CardFlight()
        let finger = swipe(90, length: 12)
        flight.drag(finger, isRevealed: true)
        #expect(flight.offset == finger)
        #expect(flight.zone == nil)
        #expect(!flight.isInGap)
    }

    @Test func springingBackClearsTheGapToo() {
        let flight = CardFlight()
        flight.drag(swipe(135, length: 140), isRevealed: true)
        #expect(flight.isInGap)
        flight.springBack()
        #expect(!flight.isInGap)
        #expect(flight.zone == nil)
        #expect(flight.committing == nil)
    }
}
