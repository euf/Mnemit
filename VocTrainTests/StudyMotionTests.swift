import SwiftUI
import Testing

@testable import VocTrain
@testable import VocabCore

/// What `StudyMotion` keeps apart from the pictures: the cards that leave and are gone, the ring that
/// steps ahead of the figures, the rest that comes and goes. The pictures are `StudyScreenSnapshotTests`.
@MainActor
struct StudyMotionTests {
    let created = Date(timeIntervalSince1970: 1_791_216_000)

    private func document(cards: Int) throws -> (VocabularyDocument, UndoManager) {
        let cards = (0..<cards).map { Card(text: CardText(question: "q\($0)", answer: "a")!, created: created) }
        let document = try VocabularyDocument(deck: Deck(cards: cards), clock: StudyClock { [created] in created.addingTimeInterval(60) })
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        return (document, undoManager)
    }

    private func motion(ring: DailyRingModel? = nil) -> StudyMotion {
        let motion = StudyMotion(ring: ring)
        motion.cardSlot = CGRect(x: 16, y: 100, width: 343, height: 500)
        motion.ringHome = CGRect(x: 120, y: 60, width: 30, height: 30)
        return motion
    }

    private func release() -> CardFlight.Release {
        CardFlight.Release(offset: CGSize(width: 40, height: 10), rotation: .degrees(4), pivot: UnitPoint(x: 0.5, y: 0.3), tint: .good, tintStrength: 0.4, size: CGSize(width: 343, height: 500))
    }

    private func card() -> Card { Card(text: CardText(question: "q", answer: "a")!, created: created) }

    /// Waits for `condition`, which a timer on the main actor makes true; the full run keeps the main actor busy
    /// with other tests, so a fixed sleep would be a guess.
    private func wait(for condition: () -> Bool, seconds: Double = 5) async throws {
        let deadline = ContinuousClock.now + .seconds(seconds)
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test func eachDestinationHasItsOwnWay() throws {
        let motion = motion()
        // Into the ring: the way is from the card's place to the ring's, small at the end.
        motion.depart(card(), receipt: GradeReceipt(grade: .good, interval: .days(8)), release: release(), velocity: .zero, behind: 2, peek: 6, reduceMotion: false)
        let ring = try #require(motion.departures.last)
        #expect(ring.destination == .ring)
        #expect(ring.label == "in 8 days")
        let path = try #require(ring.path)
        #expect(path.end.width == motion.ringHome.midX - motion.cardSlot.midX)
        #expect(path.end.height == motion.ringHome.midY - motion.cardSlot.midY)
        #expect(path.endScale < 0.1 && path.fades)

        // Under the stack: below the card, at the pose after the last of the cards waiting.
        motion.depart(card(), receipt: GradeReceipt(grade: .again, interval: .learning), release: release(), velocity: .zero, behind: 2, peek: 6, reduceMotion: false)
        let stack = try #require(motion.departures.last?.path)
        #expect(stack.end.width == 0)
        #expect(stack.end.height == StackPose.offset(3, height: 500, peek: 6))
        #expect(stack.endScale == StackPose.scale(3))
        // With no cards waiting it goes under nothing, at the pose of the first edge; the edges stop at three.
        motion.depart(card(), receipt: GradeReceipt(grade: .again, interval: .learning), release: release(), velocity: .zero, behind: 9, peek: 6, reduceMotion: false)
        #expect(motion.departures.last?.path?.endScale == StackPose.scale(StackPose.maxEdges + 1))

        // A practice flies off the way it always did.
        motion.depart(card(), receipt: GradeReceipt(grade: .easy, interval: nil), release: release(), velocity: .zero, behind: 0, peek: 6, reduceMotion: false)
        #expect(motion.departures.last?.path?.end == GradeSwipe.exit(of: .easy))
        #expect(motion.departures.last?.label == nil)

        // Reduce Motion: no way at all, the card stays where it is, and the label stays.
        motion.depart(card(), receipt: GradeReceipt(grade: .good, interval: .days(1)), release: release(), velocity: .zero, behind: 0, peek: 6, reduceMotion: true)
        let still = try #require(motion.departures.last)
        #expect(still.path == nil)
        #expect(still.release.offset == .zero)
        #expect(still.label == "tomorrow")
        #expect(still.lifetime == StudyMotion.Timing.fade)
    }

    /// A card in the ring steps it at once, ahead of the figures; the figures that come after take over,
    /// and a card that is still on its way holds them back.
    @Test func theRingStepsAheadOfTheFigures() async throws {
        let (document, undoManager) = try document(cards: 4)
        let model = StudyModel(document: document)
        for _ in 0..<2 {
            model.reveal()
            undoManager.beginUndoGrouping()
            model.grade(.easy)
            undoManager.endUndoGrouping()
        }
        let ring = DailyRingModel()
        await ring.refresh(documents: [document], delay: .zero).value
        let done = try #require(ring.progress?.ring.done)
        #expect(done == 2)

        let motion = motion(ring: ring)
        #expect(motion.shownDone == nil)
        motion.depart(card(), receipt: GradeReceipt(grade: .good, interval: .days(8)), release: release(), velocity: .zero, behind: 0, peek: 6, reduceMotion: false)
        // On its way: the figures arriving now are held back until it lands.
        motion.figuresChanged()
        #expect(motion.landings == 0)
        try await wait(for: { motion.landings == 1 })
        #expect(motion.landings == 1)
        #expect(motion.shownDone == done + 1)

        // The figures caught up with the card that landed.
        motion.figuresChanged()
        #expect(motion.shownDone == nil)

        // It is gone when its time is up.
        try await wait(for: { motion.departures.isEmpty })
        #expect(motion.departures.isEmpty)

        // Undo takes the step back.
        motion.retractStep()
        #expect(motion.shownDone == done - 1)
    }

    /// The rest: the ring waits for the card to land, comes down, and the lines come once it has; Next Round takes
    /// it back up and the cards are dealt as it nears the bar.
    @Test func theRestIsReachedByTheRingsWayAndLeftBackwards() async throws {
        let motion = motion()
        motion.restBegan(afterLanding: true, reduceMotion: false)
        #expect(motion.showsRest && motion.travels && !motion.hasArrived && motion.showsSlot)
        #expect(motion.travel == 0)
        try await wait(for: { motion.travel == 1 })
        #expect(motion.travel == 1)
        try await wait(for: { motion.hasArrived })
        #expect(motion.hasArrived && !motion.showsSlot && motion.burstStartedAt != nil)
        #expect(motion.isChoreographing == false)

        var applied = false
        var dealt = false
        motion.leaveRest(
            snapshot: StreamRest(isPracticeOnly: false, recap: StudyStream.Recap(), nextDue: nil, now: created, canKeepGoing: false), reduceMotion: false,
            cardsAfter: 0.2, arrival: .rises, apply: { applied = true }, didLeave: { true }, then: { dealt = true })
        #expect(applied && !dealt && motion.showsRest && !motion.hasArrived && motion.travel == 0)
        #expect(motion.restSnapshot != nil)
        try await wait(for: { dealt })
        #expect(dealt && !motion.showsRest && motion.arrival == .rises)
        try await wait(for: { !motion.travels })
        #expect(!motion.travels && !motion.isChoreographing)
    }

    /// Without travel (Reduce Motion) the rest is there at once, with no ring on the way and no burst.
    @Test func withoutTravelTheRestComesAtOnce() {
        let motion = motion()
        motion.restBegan(afterLanding: true, reduceMotion: true)
        #expect(motion.showsRest && !motion.travels && motion.hasArrived && !motion.showsSlot && motion.burstStartedAt == nil)
        motion.leaveRest(
            snapshot: StreamRest(isPracticeOnly: false, recap: StudyStream.Recap(), nextDue: nil, now: created, canKeepGoing: false), reduceMotion: true,
            cardsAfter: 0.2, arrival: .rises, apply: {}, didLeave: { true }, then: {})
        #expect(!motion.showsRest && motion.arrival == .rises)
    }

    /// A move that did not leave the rest leaves the screen as it was.
    @Test func aMoveThatDidNotLeaveTheRestChangesNothing() {
        let motion = motion()
        motion.snapRest(true)
        motion.leaveRest(
            snapshot: StreamRest(isPracticeOnly: false, recap: StudyStream.Recap(), nextDue: nil, now: created, canKeepGoing: false), reduceMotion: false,
            cardsAfter: 0.2, arrival: .rises, apply: {}, didLeave: { false }, then: {})
        #expect(motion.showsRest && motion.hasArrived && motion.restSnapshot == nil && !motion.isChoreographing)
    }

    /// Undo's card returns by the way its grade took, as a way of its own; after a grade that went nowhere, or
    /// without travel, it is simply there.
    @Test func undoReturnsByTheWayTheGradeWent() {
        let motion = motion()
        if case let .returns(path) = motion.returnArrival(from: .ring, behind: 1, peek: 6, reduceMotion: false) {
            #expect(path.end == CGSize(width: motion.ringHome.midX - motion.cardSlot.midX, height: motion.ringHome.midY - motion.cardSlot.midY))
        } else {
            Issue.record("the card should come back out of the ring")
        }
        if case let .returns(path) = motion.returnArrival(from: .stack, behind: 1, peek: 6, reduceMotion: false) {
            #expect(path.end.height == StackPose.offset(2, height: 500, peek: 6))
        } else {
            Issue.record("the card should come back up from under the stack")
        }
        #expect(motion.returnArrival(from: .away, behind: 1, peek: 6, reduceMotion: false) == .still)
        #expect(motion.returnArrival(from: .ring, behind: 1, peek: 6, reduceMotion: true) == .still)
    }

    /// The pose of level n: scaled by 4 % a level, and so low that its lower edge is `peek` points below that of the
    /// level above.
    @Test func theEdgesOfTheStackShowBelowTheCardByPeek() {
        for level in 1...StackPose.maxEdges {
            let height: CGFloat = 500
            let peek: CGFloat = 6
            let bottom = height / 2 + StackPose.offset(level, height: height, peek: peek) + StackPose.scale(level) * height / 2
            #expect(abs(bottom - (height + peek * CGFloat(level))) < 0.001)
        }
    }

    @Test func theBurstSwellsAndFades() {
        #expect(RingBurstFrame<EmptyView>.scale(at: 0) == 1)
        #expect(abs(RingBurstFrame<EmptyView>.scale(at: RingBurstTiming.swell / 2) - RingBurstTiming.peakScale) < 0.0001)
        #expect(RingBurstFrame<EmptyView>.scale(at: RingBurstTiming.swell) == 1)
        #expect(RingBurstFrame<EmptyView>.scale(at: RingBurstTiming.duration) == 1)
    }

    /// The milestone's burst is once for each milestone.
    @Test func aMilestoneBurstsOnce() throws {
        let suite = "MilestoneCelebrationTests"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(MilestoneCelebration.claim(50, defaults: defaults))
        #expect(!MilestoneCelebration.claim(50, defaults: defaults))
        #expect(MilestoneCelebration.claim(100, defaults: defaults))
    }
}
