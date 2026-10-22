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

    /// A drag of `length` points on the compass bearing `bearing`: 0 is straight up the screen,
    /// 90 to the right, clockwise, as in the owner's diagram.
    private func compass(_ bearing: Double, length: CGFloat = 100) -> CGSize {
        swipe(90 - bearing, length: length)
    }

    /// The compass bearing of an angle in the code's own degrees (counter-clockwise from east).
    private func bearing(ofMath degrees: Double) -> Double {
        let bearing = (90 - degrees).truncatingRemainder(dividingBy: 360)
        return bearing < 0 ? bearing + 360 : bearing
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

    @Test func theSectorsAreTheOnesOfTheOwnersDiagram() {
        // The clock face of 24 sectors of 15°, 0 at the top, clockwise. Easy 345° to 45°, Good 45° to
        // 135°, Hard 135° to 195°, a gap to 225°, Forgot 225° to 315°, a gap to 345°.
        let sectors: [(from: Double, to: Double, grade: Grade?)] = [
            (345.5, 359.5, .easy), (0, 44.5, .easy), (45.5, 134.5, .good), (135.5, 194.5, .hard),
            (195.5, 224.5, nil), (225.5, 314.5, .again), (315.5, 344.5, nil),
        ]
        for (from, to, grade) in sectors {
            for degrees in stride(from: from, through: to, by: 0.5) {
                #expect(GradeSwipe.zone(compass(degrees)) == grade, "at compass \(degrees)°")
            }
        }
        // The named constants are those edges, in the code's degrees.
        #expect(GradeSwipe.goodReach == 45)
        #expect(GradeSwipe.easyEnd == 105)
        #expect(GradeSwipe.forgotStart == 135)
        #expect(GradeSwipe.forgotEnd == 225)
        #expect(GradeSwipe.hardStart == 255)
        #expect(bearing(ofMath: GradeSwipe.easyEnd) == 345)
        #expect(bearing(ofMath: GradeSwipe.goodReach) == 45)
        #expect(bearing(ofMath: -GradeSwipe.goodReach) == 135)
        #expect(bearing(ofMath: GradeSwipe.hardStart) == 195)
        #expect(bearing(ofMath: GradeSwipe.forgotEnd) == 225)
        #expect(bearing(ofMath: GradeSwipe.forgotStart) == 315)
        #expect(bearing(ofMath: 360 - GradeSwipe.goodReach) == 135)
    }

    @Test func theInsideOfEachSectorIsItsGradeAtAnyLength() {
        // The middle of each sector, from the dead zone to far beyond the commit distance.
        let middles: [(bearing: Double, grade: Grade)] = [(15, .easy), (90, .good), (165, .hard), (270, .again)]
        for (bearing, grade) in middles {
            for length in [20.0, 60, 100, 400] {
                #expect(GradeSwipe.zone(compass(bearing, length: CGFloat(length))) == grade, "\(grade) at \(length) pt")
            }
        }
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

    @Test func theReferencesAreTheMiddlesOfTheirSectors() {
        // Compass: Easy 15° (right of up), Good 90°, Hard 165° (right of down), Forgot 270°.
        #expect(GradeSwipe.easyReference == 75)
        #expect(GradeSwipe.goodReference == 0)
        #expect(GradeSwipe.hardReference == 285)
        #expect(GradeSwipe.forgotReference == 180)
        #expect(bearing(ofMath: GradeSwipe.reference(of: .easy)) == 15)
        #expect(bearing(ofMath: GradeSwipe.reference(of: .good)) == 90)
        #expect(bearing(ofMath: GradeSwipe.reference(of: .hard)) == 165)
        #expect(bearing(ofMath: GradeSwipe.reference(of: .again)) == 270)
        for grade in Grade.allCases {
            #expect(GradeSwipe.zone(swipe(GradeSwipe.reference(of: grade))) == grade)
        }
    }

    @Test func eachSectorLiesWithinReachOfItsReference() {
        // The two never cancel when they are averaged: no sector goes 45° beyond its reference.
        for degrees in stride(from: 0.0, to: 360.0, by: 1) {
            guard let grade = GradeSwipe.zone(swipe(degrees)) else { continue }
            var apart = abs(degrees - GradeSwipe.reference(of: grade)).truncatingRemainder(dividingBy: 360)
            if apart > 180 { apart = 360 - apart }
            #expect(apart < 45.001, "\(grade) at \(degrees)°")
        }
    }

    @Test func aGapGivesNoGradeNorADirectionWithinTheDeadZone() {
        // Compass 330° and 210°: the middles of the two gaps.
        #expect(GradeSwipe.zone(compass(330)) == nil)
        #expect(GradeSwipe.zone(compass(210)) == nil)
        #expect(GradeSwipe.isInGap(compass(330)))
        #expect(GradeSwipe.isInGap(compass(210)))
        // Under the dead zone there is no direction yet, so no gap either.
        #expect(GradeSwipe.zone(swipe(0, length: 10)) == nil)
        #expect(!GradeSwipe.isInGap(compass(330, length: 10)))
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
        for degrees in [110.0, 120, 130, 230, 240, 250] {
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

    @Test func theFingerAndTheReferenceAreAveraged() {
        func card(_ degrees: Double, _ grade: Grade, length: CGFloat = 100) -> (angle: Double, length: Double) {
            let moved = GradeSwipe.pull(swipe(degrees, length: length), toward: grade)
            return (direction(moved), hypot(moved.width, moved.height))
        }
        // A finger straight up is pulled to 7.5° right of up: compass 7.5°, 82.5° in the code's degrees.
        #expect(abs(card(90, .easy).angle - 82.5) < 0.001)
        #expect(abs(bearing(ofMath: card(90, .easy).angle) - 7.5) < 0.001)
        // Straight down, 7.5° right of down: compass 172.5°.
        #expect(abs(bearing(ofMath: card(270, .hard).angle) - 172.5) < 0.001)
        // Straight left stays at west, straight right at east.
        #expect(abs(card(180, .again).angle - 180) < 0.001)
        #expect(abs(card(0, .good).angle - 0) < 0.001 || abs(card(0, .good).angle - 360) < 0.001)
        // Along the reference there is nothing to bend.
        #expect(abs(card(75, .easy).angle - 75) < 0.001)
        #expect(abs(card(285, .hard).angle - 285) < 0.001)
        // The edges of the sectors: halfway to the reference.
        #expect(abs(card(45, .easy).angle - 60) < 0.001)
        #expect(abs(card(105, .easy).angle - 90) < 0.001)
        #expect(abs(card(45, .good).angle - 22.5) < 0.001)
        #expect(abs(card(-45, .good).angle - (360 - 22.5)) < 0.001)
        #expect(abs(card(135, .again).angle - 157.5) < 0.001)
        #expect(abs(card(225, .again).angle - 202.5) < 0.001)
        #expect(abs(card(255, .hard).angle - 270) < 0.001)
        #expect(abs(card(315, .hard).angle - 300) < 0.001)
        // At the finger's distance, whatever the angle and the length.
        for grade in Grade.allCases {
            for length in [20.0, 60, 100, 250] {
                #expect(abs(card(GradeSwipe.reference(of: grade) + 20, grade, length: CGFloat(length)).length - length) < 0.001)
            }
        }
    }

    @Test func goodLeansRightEasyAndHardNeverLeftAndForgotNeverLeansUpOrDown() {
        for degrees in stride(from: 0.0, to: 360.0, by: 1) {
            let finger = swipe(degrees)
            guard let grade = GradeSwipe.zone(finger) else { continue }
            let moved = GradeSwipe.pull(finger, toward: grade)
            switch grade {
            case .again:
                // Forgot's reference is due west: it pulls the card toward the horizontal, never away.
                #expect(abs(moved.height) <= abs(finger.height) + 0.001)
                #expect(moved.width < 0)
            case .good:
                #expect(moved.width > 0, "\(grade) at \(degrees)°")
            case .easy, .hard:
                // The left edge of Easy and Hard is as far left of vertical as the reference is right of it:
                // the card goes straight up or down there, and not left.
                #expect(moved.width > -0.001, "\(grade) at \(degrees)°")
            }
        }
    }

    @Test func theCardGoesAHalfWayInAGapAndWithTheFingerBelowTheDeadZone() {
        let gap = swipe(120, length: 120)
        let half = GradeSwipe.cardOffset(for: gap)
        #expect(abs(half.width - gap.width * GradeSwipe.gapTravel) < 0.001)
        #expect(abs(half.height - gap.height * GradeSwipe.gapTravel) < 0.001)
        #expect(GradeSwipe.gapTravel == 0.5)
        // Under the dead zone: the finger, whatever its direction.
        let short = swipe(90, length: 15)
        #expect(GradeSwipe.cardOffset(for: short) == short)
        // In a zone: bent.
        let up = GradeSwipe.cardOffset(for: swipe(90))
        #expect(abs(direction(up) - 82.5) < 0.001)
    }

    @Test func aCardFliesOffAlongTheReferenceOfItsGrade() {
        for grade in Grade.allCases {
            var apart = abs(direction(GradeSwipe.exit(of: grade)) - GradeSwipe.reference(of: grade)).truncatingRemainder(dividingBy: 360)
            if apart > 180 { apart = 360 - apart }
            #expect(apart < 0.001, "\(grade)")
            let exit = GradeSwipe.exit(of: grade)
            #expect(abs(hypot(exit.width, exit.height) - GradeSwipe.exitDistance) < 0.001)
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

    @Test func aSwipeUpMovesTheCardUpAndSlightlyRightInTheColourOfEasy() {
        let flight = CardFlight()
        flight.drag(swipe(90, length: 120), isRevealed: true)
        #expect(abs(direction(flight.offset) - 82.5) < 0.001)
        #expect(abs(hypot(flight.offset.width, flight.offset.height) - 120) < 0.001)
        #expect(flight.zone == .easy)
        #expect(flight.tint == .easy)
        #expect(flight.highlighted == .easy)
        #expect(flight.committing == .easy)
        // Turns the way it moves.
        #expect(flight.rotation.degrees > 0)
    }

    @Test func eachGradeBendsTheCardTowardItsReference() {
        let cases: [(finger: Double, grade: Grade, card: Double)] = [
            (90, .easy, 82.5), (270, .hard, 277.5), (0, .good, 0), (180, .again, 180), (160, .again, 170),
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
        for degrees in [120.0, 240] {
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
        flight.drag(swipe(120, length: 130), isRevealed: true)
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
        flight.drag(swipe(120, length: 130), isRevealed: true)
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
        flight.drag(swipe(120, length: 140), isRevealed: true)
        #expect(flight.isInGap)
        flight.springBack()
        #expect(!flight.isInGap)
        #expect(flight.zone == nil)
        #expect(flight.committing == nil)
    }
}
