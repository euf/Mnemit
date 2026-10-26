import CoreGraphics
import Foundation
import SwiftUI
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

    // MARK: Keys

    /// The Mac's arrow keys are the directions of the swipes, and each grade's button shows its
    /// arrow: swapping two keys in `Grade.arrowKey`, or two glyphs in `Grade.arrow`, fails here.
    @Test func theArrowKeysAreTheDirectionsOfTheSwipes() throws {
        let swipes: [(translation: CGSize, key: KeyEquivalent, glyph: String)] = [
            (CGSize(width: -100, height: 0), .leftArrow, "←"),
            (CGSize(width: 0, height: 100), .downArrow, "↓"),
            (CGSize(width: 100, height: 0), .rightArrow, "→"),
            (CGSize(width: 0, height: -100), .upArrow, "↑"),
        ]
        #expect(swipes.map { GradeSwipe.zone($0.translation) } == [.again, .hard, .good, .easy])
        for swipe in swipes {
            let grade = try #require(GradeSwipe.zone(swipe.translation))
            #expect(grade.arrowKey == swipe.key)
            #expect(grade.arrow == swipe.glyph)
        }
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

    @Test func theSectorsAreTheOnesOfTheClockFace() {
        // The clock face, 0 at the top, clockwise. Easy 330° to 45°, Good 45° to 135°, Hard 135° to 210°,
        // a gap to 240°, Forgot 240° to 300°, a gap to 330°.
        let sectors: [(from: Double, to: Double, grade: Grade?)] = [
            (330.5, 359.5, .easy), (0, 44.5, .easy), (45.5, 134.5, .good), (135.5, 209.5, .hard),
            (210.5, 239.5, nil), (240.5, 299.5, .again), (300.5, 329.5, nil),
        ]
        for (from, to, grade) in sectors {
            for degrees in stride(from: from, through: to, by: 0.5) {
                #expect(GradeSwipe.zone(compass(degrees)) == grade, "at compass \(degrees)°")
            }
        }
        // The named constants are those edges, in the code's degrees.
        #expect(GradeSwipe.goodReach == 45)
        #expect(GradeSwipe.easyEnd == 120)
        #expect(GradeSwipe.forgotStart == 150)
        #expect(GradeSwipe.forgotEnd == 210)
        #expect(GradeSwipe.hardStart == 240)
        #expect(bearing(ofMath: GradeSwipe.easyEnd) == 330)
        #expect(bearing(ofMath: GradeSwipe.goodReach) == 45)
        #expect(bearing(ofMath: -GradeSwipe.goodReach) == 135)
        #expect(bearing(ofMath: GradeSwipe.hardStart) == 210)
        #expect(bearing(ofMath: GradeSwipe.forgotEnd) == 240)
        #expect(bearing(ofMath: GradeSwipe.forgotStart) == 300)
        #expect(bearing(ofMath: 360 - GradeSwipe.goodReach) == 135)
    }

    @Test func theInsideOfEachSectorIsItsGradeAtAnyLength() {
        // The reference direction of each grade, from the dead zone to far beyond the commit distance.
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

    @Test func theReferencesLieInsideTheirSectors() {
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
        // Compass 315° and 225°: the middles of the two gaps.
        #expect(GradeSwipe.zone(compass(315)) == nil)
        #expect(GradeSwipe.zone(compass(225)) == nil)
        #expect(GradeSwipe.isInGap(compass(315)))
        #expect(GradeSwipe.isInGap(compass(225)))
        // Under the dead zone there is no direction yet, so no gap either.
        #expect(GradeSwipe.zone(swipe(0, length: 10)) == nil)
        #expect(!GradeSwipe.isInGap(compass(315, length: 10)))
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
        #expect(abs(card(120, .easy).angle - 97.5) < 0.001)
        #expect(abs(card(45, .good).angle - 22.5) < 0.001)
        #expect(abs(card(-45, .good).angle - (360 - 22.5)) < 0.001)
        #expect(abs(card(150, .again).angle - 165) < 0.001)
        #expect(abs(card(210, .again).angle - 195) < 0.001)
        #expect(abs(card(240, .hard).angle - 262.5) < 0.001)
        #expect(abs(card(315, .hard).angle - 300) < 0.001)
        // At the finger's distance, whatever the angle and the length.
        for grade in Grade.allCases {
            for length in [20.0, 60, 100, 250] {
                #expect(abs(card(GradeSwipe.reference(of: grade) + 20, grade, length: CGFloat(length)).length - length) < 0.001)
            }
        }
    }

    @Test func theCardStaysNearItsReferenceAndForgotNeverLeansUpOrDown() {
        for degrees in stride(from: 0.0, to: 360.0, by: 1) {
            let finger = swipe(degrees)
            guard let grade = GradeSwipe.zone(finger) else { continue }
            let moved = GradeSwipe.pull(finger, toward: grade)
            let way = direction(moved)
            switch grade {
            case .again:
                // Forgot's reference is due west: it pulls the card toward the horizontal, never away.
                #expect(abs(moved.height) <= abs(finger.height) + 0.001)
                #expect(moved.width < 0)
            case .good:
                #expect(moved.width > 0, "\(grade) at \(degrees)°")
            case .easy:
                // Between 30° right of up (the near edge) and 7.5° left of up (the far edge).
                #expect(way > 60 - 0.001 && way < 97.5 + 0.001, "\(grade) at \(degrees)°")
            case .hard:
                #expect(way > 262.5 - 0.001 && way < 300 + 0.001, "\(grade) at \(degrees)°")
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

    // MARK: Swipes that a gap sprang back

    @Test func aSwipeEndsInAGapOnlyWhenItTriedToGradeAndPointedIntoOne() {
        func ended(_ translation: CGSize, _ predictedEnd: CGSize) -> Bool {
            GradeSwipe.endedInGap(translation: translation, predictedEnd: predictedEnd)
        }
        // Compass 315° and 225° are the middles of the gaps: far, and a flick.
        for bearing in [315.0, 225] {
            #expect(ended(compass(bearing, length: 120), compass(bearing, length: 120)))
            #expect(ended(compass(bearing, length: 400), compass(bearing, length: 400)))
            #expect(ended(compass(bearing, length: 50), compass(bearing, length: 400)))
            // A flick that starts in a zone and would end in the gap, and the other way round.
            #expect(ended(compass(0, length: 50), compass(bearing, length: 400)))
            #expect(ended(compass(bearing, length: 50), compass(90, length: 400)))
        }
        // A swipe that graded is no gap miss.
        #expect(!ended(compass(0, length: 120), compass(0, length: 120)))
        #expect(!ended(compass(90, length: 50), compass(90, length: 400)))
        // Short and slow, in a gap: it tried nothing.
        #expect(!ended(compass(315, length: 60), compass(315, length: 120)))
        #expect(!ended(compass(315, length: 99), compass(315, length: 250)))
        // Not moved far enough for a flick, or inside the dead zone.
        #expect(!ended(compass(315, length: 25), compass(315, length: 400)))
        #expect(!ended(compass(315, length: 10), compass(315, length: 400)))
    }

    @MainActor
    @Test func theTallyCountsGradedSwipesAndGapMissesOfTheStudyDay() {
        let calendar = StudyCalendar(timeZone: TimeZone(identifier: "UTC")!, rolloverHour: 4)
        let now = Date(timeIntervalSince1970: 1_791_216_000)
        let tally = SwipeTally()
        #expect(tally.counts(at: now, calendar: calendar) == SwipeTally.Counts())
        func release(_ translation: CGSize, _ predictedEnd: CGSize) -> Grade? {
            tally.released(translation: translation, predictedEnd: predictedEnd, at: now, calendar: calendar)
        }
        // Three that graded: far, far, and a flick. The grade is what `GradeSwipe.released` says.
        #expect(release(compass(0, length: 120), compass(0, length: 120)) == .easy)
        #expect(release(compass(90, length: 120), compass(90, length: 120)) == .good)
        #expect(release(compass(270, length: 50), compass(270, length: 400)) == .again)
        #expect(tally.counts(at: now, calendar: calendar) == SwipeTally.Counts(graded: 3, gapMisses: 0))
        // Four that a gap sprang back: far, far in the other gap, a flick, a flick from a zone into a gap.
        #expect(release(compass(315, length: 120), compass(315, length: 120)) == nil)
        #expect(release(compass(225, length: 400), compass(225, length: 400)) == nil)
        #expect(release(compass(315, length: 50), compass(315, length: 400)) == nil)
        #expect(release(compass(0, length: 50), compass(225, length: 400)) == nil)
        // Not swipes that tried: a touch, a short drag in a zone, a slow one in a gap.
        #expect(release(compass(90, length: 10), compass(90, length: 10)) == nil)
        #expect(release(compass(90, length: 60), compass(90, length: 120)) == nil)
        #expect(release(compass(315, length: 60), compass(315, length: 120)) == nil)
        let counts = tally.counts(at: now, calendar: calendar)
        #expect(counts == SwipeTally.Counts(graded: 3, gapMisses: 4))
        #expect(counts.total == 7)
    }

    @MainActor
    @Test func theTallyStartsAgainWithTheNextStudyDay() {
        let calendar = StudyCalendar(timeZone: TimeZone(identifier: "UTC")!, rolloverHour: 4)
        let day = calendar.dayNumber(for: Date(timeIntervalSince1970: 1_791_216_000))
        let evening = calendar.start(ofDay: day).addingTimeInterval(14 * 3600)
        let night = calendar.start(ofDay: day + 1).addingTimeInterval(-3600)
        let morning = calendar.start(ofDay: day + 1).addingTimeInterval(3600)
        let tally = SwipeTally()
        _ = tally.released(translation: compass(315, length: 120), predictedEnd: compass(315, length: 120), at: evening, calendar: calendar)
        _ = tally.released(translation: compass(90, length: 120), predictedEnd: compass(90, length: 120), at: evening, calendar: calendar)
        #expect(tally.counts(at: evening, calendar: calendar) == SwipeTally.Counts(graded: 1, gapMisses: 1))
        // After midnight and before the rollover it is the same study day.
        #expect(tally.counts(at: night, calendar: calendar) == SwipeTally.Counts(graded: 1, gapMisses: 1))
        // The next study day has none, and its first swipe counts alone.
        #expect(tally.counts(at: morning, calendar: calendar) == SwipeTally.Counts())
        _ = tally.released(translation: compass(315, length: 120), predictedEnd: compass(315, length: 120), at: morning, calendar: calendar)
        #expect(tally.counts(at: morning, calendar: calendar) == SwipeTally.Counts(graded: 0, gapMisses: 1))
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
