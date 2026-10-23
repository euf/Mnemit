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
    private func wait(for condition: () -> Bool, seconds: Double = 30) async throws {
        let deadline = ContinuousClock.now + .seconds(seconds)
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    /// Every card leaves past the edge of the screen, along the direction of its grade, and nothing rides on it; what
    /// follows is the destination's. Reduce Motion has no way at all: the card stays where it is and fades.
    @Test func everyCardLeavesPastTheEdge() throws {
        let motion = motion()
        let receipts: [(GradeReceipt, GradeReceipt.Destination)] = [
            (GradeReceipt(grade: .good, interval: .days(8)), .ring),
            (GradeReceipt(grade: .again, interval: .learning), .stack),
            (GradeReceipt(grade: .easy, interval: nil), .away),
            (GradeReceipt(grade: .again, interval: .days(3), isLeech: true), .away),
        ]
        for (receipt, destination) in receipts {
            motion.depart(card(), receipt: receipt, release: release(), velocity: .zero, behind: 2, reduceMotion: false)
            let departure = try #require(motion.departures.last)
            #expect(departure.destination == destination)
            #expect(departure.path == CardPath(end: GradeSwipe.exit(of: receipt.grade), endScale: 1, fades: false))
        }
        motion.depart(card(), receipt: GradeReceipt(grade: .good, interval: .days(1)), release: release(), velocity: .zero, behind: 0, reduceMotion: true)
        let still = try #require(motion.departures.last)
        #expect(still.path == nil)
        #expect(still.release.offset == .zero)
        #expect(still.lifetime == StudyMotion.Timing.fade)
    }

    /// A card that goes back today comes in again as a blank sheet by the edge it left by, once it is past it, and slides
    /// under the stack to its deepest edge; until it is there the stack lacks that edge, and then it has it.
    @Test func aCardBackTodayComesInAsASheetUnderTheStack() async throws {
        let motion = motion()
        let receipt = GradeReceipt(grade: .again, interval: .learning)
        #expect(motion.edges(cardsBehind: 3) == 3)
        motion.depart(card(), receipt: receipt, release: release(), velocity: .zero, behind: 3, reduceMotion: false)
        #expect(motion.sheetsAway == 1 && motion.sheets.isEmpty)
        #expect(motion.edges(cardsBehind: 3) == 2)
        try await wait(for: { !motion.sheets.isEmpty })
        let sheet = try #require(motion.sheets.first)
        #expect(sheet.from == GradeSwipe.exit(of: .again))
        #expect(sheet.level == 3)
        try await wait(for: { motion.sheetsAway == 0 })
        #expect(motion.sheets.isEmpty)
        #expect(motion.edges(cardsBehind: 3) == 3)

        // Past the last edge it goes under the deepest one there is; Reduce Motion has no sheet.
        motion.depart(card(), receipt: receipt, release: release(), velocity: .zero, behind: 9, reduceMotion: false)
        try await wait(for: { !motion.sheets.isEmpty })
        #expect(motion.sheets.first?.level == StackPose.maxEdges)
        try await wait(for: { motion.sheetsAway == 0 })
        motion.depart(card(), receipt: receipt, release: release(), velocity: .zero, behind: 3, reduceMotion: true)
        #expect(motion.sheetsAway == 0)
    }

    /// A grade steps the ring by its gain at once, ahead of the figures: a done card bumps and bursts it and names its
    /// interval beside it for a moment, a card back today with a part to give steps it quietly, Forgot moves nothing.
    /// The figures that come after take over, and a card that is still leaving holds them back.
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
        #expect(motion.shown == nil && motion.interval == nil && motion.barBurstAt == nil)
        let doneCard = GradeReceipt(grade: .good, interval: .days(8), gain: 1)
        motion.depart(card(), receipt: doneCard, release: release(), velocity: .zero, behind: 0, reduceMotion: false)
        #expect(motion.shown == Double(done + 1))
        #expect(motion.landings == 1 && motion.barBurstAt != nil)
        #expect(motion.interval == "in 8 days")
        // On its way: the figures arriving now are held back until it is gone.
        motion.figuresChanged()
        #expect(motion.shown == Double(done + 1))
        try await wait(for: { motion.departures.isEmpty })
        #expect(motion.shown == nil, "the figures that were held back are shown once the card is gone")

        // A step in a card's way: the ring moves, without bump or burst, and the interval stays what it was.
        let burst = motion.barBurstAt
        motion.depart(card(), receipt: GradeReceipt(grade: .hard, interval: .learning, gain: 0.5), release: release(), velocity: .zero, behind: 1, reduceMotion: false)
        #expect(motion.shown == Double(done) + 0.5)
        #expect(motion.landings == 1 && motion.barBurstAt == burst)
        // Forgot gives nothing.
        motion.depart(card(), receipt: GradeReceipt(grade: .again, interval: .learning), release: release(), velocity: .zero, behind: 1, reduceMotion: false)
        #expect(motion.shown == Double(done) + 0.5)

        // The figures catch up with the grades that have left.
        try await wait(for: { motion.departures.isEmpty })
        motion.figuresChanged()
        #expect(motion.shown == nil)

        // The interval is gone after its time.
        try await wait(for: { motion.interval == nil })
        #expect(motion.interval == nil)

        // Undo takes the step back by the gain of the grade it undoes, and the interval with it.
        motion.depart(card(), receipt: doneCard, release: release(), velocity: .zero, behind: 0, reduceMotion: true)
        motion.undone(doneCard, reduceMotion: false)
        #expect(motion.shown == Double(done))
        #expect(motion.interval == nil)
    }

    /// The rest: the ring waits for the card to land and comes down with the slot showing; Next Round takes it back up
    /// and applies the round at once. Only the states each call sets are checked: the timed steps between them run on
    /// the main actor, which a full parallel run can hold up for seconds, and the frozen frames of
    /// `StudyScreenSnapshotTests` (rest travel half and end, burst peak) show them.
    @Test func theRestIsReachedByTheRingsWayAndLeftBackwards() {
        let motion = motion()
        motion.restBegan(afterExit: true, reduceMotion: false)
        #expect(motion.showsRest && motion.travels && !motion.hasArrived && motion.showsSlot)
        #expect(motion.travel == 0)

        var applied = false
        var dealt = false
        motion.leaveRest(
            snapshot: StreamRest(isPracticeOnly: false, recap: StudyStream.Recap(), nextDue: nil, now: created), reduceMotion: false,
            cardsAfter: 0.2, arrival: .rises, apply: { applied = true }, didLeave: { true }, then: { dealt = true })
        #expect(applied && !dealt && motion.showsRest && !motion.hasArrived && motion.travel == 0)
        #expect(motion.restSnapshot != nil)
    }

    /// Without travel (Reduce Motion) the rest is there at once, with no ring on the way and no burst.
    @Test func withoutTravelTheRestComesAtOnce() {
        let motion = motion()
        motion.restBegan(afterExit: true, reduceMotion: true)
        #expect(motion.showsRest && !motion.travels && motion.hasArrived && !motion.showsSlot && motion.burstStartedAt == nil)
        motion.leaveRest(
            snapshot: StreamRest(isPracticeOnly: false, recap: StudyStream.Recap(), nextDue: nil, now: created), reduceMotion: true,
            cardsAfter: 0.2, arrival: .rises, apply: {}, didLeave: { true }, then: {})
        #expect(!motion.showsRest && motion.arrival == .rises)
    }

    /// A move that did not leave the rest leaves the screen as it was.
    @Test func aMoveThatDidNotLeaveTheRestChangesNothing() {
        let motion = motion()
        motion.snapRest(true)
        motion.leaveRest(
            snapshot: StreamRest(isPracticeOnly: false, recap: StudyStream.Recap(), nextDue: nil, now: created), reduceMotion: false,
            cardsAfter: 0.2, arrival: .rises, apply: {}, didLeave: { false }, then: {})
        #expect(motion.showsRest && motion.hasArrived && motion.restSnapshot == nil && !motion.isChoreographing)
    }

    /// Undo's card comes back in from the edge its grade took it past, whatever became of it; after a step that gave no
    /// grade, or without travel, it is simply there. A card that comes out from under the stack takes its deepest edge
    /// with it for a moment.
    @Test func undoBringsTheCardBackInFromTheEdge() async throws {
        let motion = motion()
        for destinationReceipt in [
            GradeReceipt(grade: .easy, interval: .days(8)), GradeReceipt(grade: .again, interval: .learning), GradeReceipt(grade: .good, interval: nil),
        ] {
            #expect(
                motion.returnArrival(destinationReceipt, reduceMotion: false)
                    == .returns(CardPath(end: GradeSwipe.exit(of: destinationReceipt.grade), endScale: 1, fades: false)))
        }
        #expect(motion.returnArrival(nil, reduceMotion: false) == .still)
        #expect(motion.returnArrival(GradeReceipt(grade: .easy, interval: .days(8)), reduceMotion: true) == .still)

        #expect(motion.edges(cardsBehind: 4) == 4)
        motion.undone(GradeReceipt(grade: .again, interval: .learning), reduceMotion: false)
        #expect(motion.edges(cardsBehind: 4) == 3)
        try await wait(for: { motion.edges(cardsBehind: 4) == 4 })
        #expect(motion.edges(cardsBehind: 4) == 4)
    }

    /// The edges of the stack: 3 pt lower and 2 pt narrower on each side than the one above, five at most, fainter with
    /// depth, and the room under the card is the same whether or not there are any.
    @Test func theEdgesAreLowerAndNarrowerWithDepth() {
        #expect(StackPose.maxEdges == 4)
        for level in 1...StackPose.maxEdges {
            #expect(StackPose.drop(level) == 6 * CGFloat(level))
            #expect(StackPose.width(level, cardWidth: 343) == 343 - 12 * CGFloat(level))
            #expect(StackPose.faintness(level) > 0 && StackPose.faintness(level) <= 1)
            if level > 1 { #expect(StackPose.faintness(level) < StackPose.faintness(level - 1)) }
        }
        #expect(StackPose.reserve == StackPose.drop(StackPose.maxEdges))
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
