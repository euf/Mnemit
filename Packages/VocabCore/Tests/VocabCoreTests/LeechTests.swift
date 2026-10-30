import Foundation
import Testing

@testable import VocabCore

/// A card that keeps lapsing meets a leech moment at the deck's threshold and at every half threshold after
/// it; the deck's leech action says whether the card is suspended then. The lapse count says which cards
/// are leeches, with no flag of their own.
struct LeechTests {
    let calendar = StudyCalendar.testing
    /// 2026-10-05 18:00 in Berlin.
    let now = Date(timeIntervalSince1970: 1_791_216_000)

    /// A card in the review phase, due now, that has lapsed `lapses` times.
    func reviewCard(lapses: Int, phase: LearningPhase = .review) -> Card {
        let state = LearningState(phase: phase, stability: 10, difficulty: 5, lastReview: now.addingTimeInterval(-10 * 86400), due: now.addingTimeInterval(-3600), reviews: lapses + 5, lapses: lapses)
        return Card(question: "dom", answer: "Haus", learningState: state)
    }

    func deck(_ cards: [Card], threshold: Int = 8, action: LeechAction = .suspend) throws -> Deck {
        var options = LearningOptions()
        options.fuzzing = false
        options.leechThreshold = threshold
        options.leechAction = action
        return try Deck(learningOptions: options, cards: cards)
    }

    /// Grades the current card of a new session at `time`; returns the card as stored and
    /// the session after the review.
    func review(_ grade: Grade, in deck: inout Deck, at time: Date? = nil) throws -> (card: Card, session: Session) {
        var study = StudySession(deck: deck, at: time ?? now, calendar: calendar, random: SeededRandom(seed: 1))
        let id = try #require(study.session.currentCardID)
        let reviewed = study.review(grade, of: deck.card(withID: id)!, with: deck.learningOptions, at: time ?? now, calendar: calendar)
        let card = try #require(reviewed)
        deck.cards[deck.index(of: id)!] = card
        return (card, study.session)
    }

    // MARK: Rule

    @Test func aCardIsALeechFromTheThresholdOn() {
        #expect(!reviewCard(lapses: 7).isLeech(threshold: 8))
        #expect(reviewCard(lapses: 8).isLeech(threshold: 8))
        #expect(reviewCard(lapses: 20).isLeech(threshold: 8))
        #expect(!reviewCard(lapses: 20).isLeech(threshold: 0))
        #expect(!Card(question: "dom", answer: "Haus").isLeech(threshold: 1))
    }

    @Test func theThresholdIsEightAndZeroSwitchesItOff() throws {
        #expect(LearningOptions().leechThreshold == 8)
        var options = LearningOptions()
        options.leechThreshold = 500
        options.sanitize()
        #expect(options.leechThreshold == 99)
        options.leechThreshold = -3
        options.sanitize()
        #expect(options.leechThreshold == 0)

        let deck = try deck([reviewCard(lapses: 8)])
        #expect(deck.isLeech(deck.cards[0]))
        let off = try self.deck([reviewCard(lapses: 8)], threshold: 0)
        #expect(!off.isLeech(off.cards[0]))
    }

    // MARK: Moments

    @Test func theMomentsAreTheThresholdAndEveryHalfThresholdAfterIt() {
        func moments(threshold: Int) -> [Int] { (0...30).filter { StudySession.isLeechMoment(lapses: $0, threshold: threshold) } }
        #expect(moments(threshold: 8) == [8, 12, 16, 20, 24, 28])
        #expect(moments(threshold: 5) == [5, 8, 11, 14, 17, 20, 23, 26, 29])
        #expect(moments(threshold: 1) == Array(1...30))
        #expect(moments(threshold: 0).isEmpty)
    }

    @Test(arguments: [(threshold: 8, lapses: [8, 12, 16, 20]), (threshold: 5, lapses: [5, 8, 11])])
    func aLapseOntoAMomentIsOneAndAnyOtherIsNot(threshold: Int, lapses: [Int]) throws {
        for before in 0...(lapses.last! + 1) {
            var deck = try deck([reviewCard(lapses: before)], threshold: threshold, action: .keep)
            let (card, session) = try review(.again, in: &deck)
            #expect(session.leechIDs == (lapses.contains(before + 1) ? [card.id] : []), "lapse \(before + 1) of threshold \(threshold)")
        }
    }

    @Test func theLapseThatReachesTheThresholdSuspendsTheCardUnderSuspendAndEndsItsPlaceInTheSession() throws {
        var deck = try deck([reviewCard(lapses: 7)])
        let (card, session) = try review(.again, in: &deck)
        #expect(card.learningState?.lapses == 8)
        #expect(card.learningState?.phase == .relearning)
        #expect(card.isSuspended)
        #expect(card.suspensionChanged == now)
        #expect(deck.isLeech(card))
        #expect(!card.isDue(at: now.addingTimeInterval(86400)))
        // The card was asked once and leaves the session, instead of coming back to relearn.
        #expect(session.isFinished)
        #expect(session.leechIDs == [card.id])
        #expect(session.suspendedCount == 1)
        #expect(session.mistakeIDs == [card.id])
        #expect(session.reviewCount == 1)
        #expect(session.completedCount == session.totalCount)
    }

    @Test func underKeepTheCardStaysInRotationAndTheSessionStillReportsTheMoment() throws {
        var deck = try deck([reviewCard(lapses: 7)], action: .keep)
        let (card, session) = try review(.again, in: &deck)
        #expect(card.learningState?.lapses == 8)
        #expect(!card.isSuspended)
        #expect(card.suspensionChanged == nil)
        #expect(deck.isLeech(card))
        #expect(session.leechIDs == [card.id])
        #expect(session.suspendedCount == 0)
        // It relearns in this session, like any lapsed card.
        #expect(!session.isFinished)
        #expect(session.currentCardID == card.id)
    }

    @Test func theLeechActionDefaultsToKeep() {
        #expect(LearningOptions().leechAction == .keep)
        #expect(LeechAction.allCases == [.keep, .suspend])
    }

    @Test func aLapseBelowTheThresholdLeavesTheCardInTheSession() throws {
        var deck = try deck([reviewCard(lapses: 6)])
        let (card, session) = try review(.again, in: &deck)
        #expect(card.learningState?.lapses == 7)
        #expect(!card.isSuspended)
        #expect(card.suspensionChanged == nil)
        #expect(!session.isFinished)
        #expect(session.leechIDs.isEmpty)
        #expect(session.suspendedCount == 0)
    }

    @Test func aThresholdOfZeroNeverSuspends() throws {
        var deck = try deck([reviewCard(lapses: 7)], threshold: 0)
        let (card, session) = try review(.again, in: &deck)
        #expect(card.learningState?.lapses == 8)
        #expect(!card.isSuspended)
        #expect(session.leechIDs.isEmpty)
    }

    @Test func recallsNeverSuspendACardThatIsALeechAlready() throws {
        for grade in [Grade.hard, .good, .easy] {
            var deck = try deck([reviewCard(lapses: 8)])
            let (card, session) = try review(grade, in: &deck)
            #expect(!card.isSuspended)
            #expect(card.learningState?.lapses == 8)
            #expect(session.leechIDs.isEmpty)
        }
    }

    @Test func onlyLapsesCountNotAgainWhileRelearning() throws {
        // Seven lapses, now relearning: Again on it is no new lapse.
        var deck = try deck([reviewCard(lapses: 7, phase: .relearning)])
        let (card, session) = try review(.again, in: &deck)
        #expect(card.learningState?.lapses == 7)
        #expect(!card.isSuspended)
        #expect(session.leechIDs.isEmpty)

        var new = try self.deck([Card(question: "kot", answer: "Katze")], threshold: 1)
        let newCard = try review(.again, in: &new).card
        #expect(!newCard.isSuspended)
    }

    @Test func aResumedLeechIsSuspendedAgainAtTheNextMoment() throws {
        var deck = try deck([reviewCard(lapses: 8)])
        // Resumed by the learner; the ninth lapse suspends nothing.
        let ninth = try review(.again, in: &deck).card
        #expect(ninth.learningState?.lapses == 9)
        #expect(!ninth.isSuspended)

        // At 12 lapses, half a threshold on, it does, again.
        var later = try self.deck([reviewCard(lapses: 11)])
        let (card, session) = try review(.again, in: &later)
        #expect(card.learningState?.lapses == 12)
        #expect(card.isSuspended)
        #expect(session.leechIDs == [card.id])
    }

    /// Lapses come on different study days, the card relearns in between, and the third
    /// one suspends it.
    @Test func lapsesOverSeveralDaysEndInASuspension() throws {
        var deck = try deck([Card(question: "dom", answer: "Haus")], threshold: 3, action: .suspend)
        var day = 0
        func play(_ grades: [Grade]) throws -> Card {
            let time = now.addingTimeInterval(Double(day) * 86400)
            var study = StudySession(deck: deck, at: time, calendar: calendar, random: SeededRandom(seed: 1))
            for grade in grades {
                let reviewed = study.review(grade, of: deck.cards[0], with: deck.learningOptions, at: time, calendar: calendar)
                deck.cards[0] = try #require(reviewed)
            }
            day += 60
            return deck.cards[0]
        }
        // Learned in two Goods; then three lapses, each followed by relearning.
        _ = try play([.good, .good])
        for lapse in 1...2 {
            let card = try play([.again, .good, .good])
            #expect(card.learningState?.lapses == lapse)
            #expect(!card.isSuspended)
            #expect(card.learningState?.phase == .review)
        }
        let card = try play([.again])
        #expect(card.learningState?.lapses == 3)
        #expect(card.isSuspended)
        #expect(deck.isLeech(card))
    }

    // MARK: Through the deck

    @Test func theChangeOfTheReviewHoldsTheSuspensionAndUndoTakesItBack() throws {
        var deck = try deck([reviewCard(lapses: 7)])
        var mode = SessionMode.study(StudySession(deck: deck, at: now, calendar: calendar, random: SeededRandom(seed: 1)))
        let graded = mode.grade(.again, in: deck, at: now, calendar: calendar)
        guard case let .rescheduled(change)? = graded else {
            Issue.record("A study session reschedules.")
            return
        }
        let before = deck.cards[0]
        let inverse = deck.apply(change, at: now, calendar: calendar)
        #expect(deck.cards[0].isSuspended)
        #expect(deck.cards[0].learningState?.lapses == 8)
        // A review, even one that suspends, leaves the content stamp alone.
        #expect(deck.contentModified == nil)
        // The suspended leech is out of today's counts and of the next session.
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == 0)
        #expect(StudySession(deck: deck, at: now, calendar: calendar).session.isFinished)

        _ = deck.apply(inverse, at: now, calendar: calendar)
        // The card as it was, but for the note that the review was taken back.
        #expect(deck.cards[0].undone.count == 1)
        deck.cards[0].undone = []
        #expect(deck.cards[0] == before)
    }

    /// Under Keep the learner sets the card aside at the moment: it is suspended, and the session drops it
    /// without counting it as done.
    @Test func settingAsideAKeptLeechDropsItFromTheSession() throws {
        var deck = try deck([reviewCard(lapses: 7), reviewCard(lapses: 7)], action: .keep)
        var stream = StudyStream(deck: deck, at: now, calendar: calendar, random: SeededRandom(seed: 1))
        let id = try #require(stream.session.currentCardID)
        let other = try #require(deck.cards.first { $0.id != id })
        guard case let .rescheduled(change)? = stream.grade(.again, in: deck, at: now, calendar: calendar) else {
            Issue.record("A study session reschedules.")
            return
        }
        _ = deck.apply(change, at: now, calendar: calendar)
        #expect(stream.session.leechIDs == [id])
        let remaining = stream.session.remainingCount
        let completed = stream.session.completedCount
        let steps = stream.stepCount

        stream.perform(.setAside(id))
        #expect(stream.session.remainingCount == remaining - 1)
        #expect(stream.session.completedCount == completed)
        #expect(stream.session.suspendedCount == 1)
        #expect(stream.stepCount == steps + 1)
        #expect(stream.session.currentCardID == other.id)
    }

    /// Under Suspend the learner keeps the card at the moment: the driver resumes it, and the session asks it again.
    @Test func keepingASuspendedLeechBringsItBackIntoTheSession() throws {
        var deck = try deck([reviewCard(lapses: 7)], action: .suspend)
        var stream = StudyStream(deck: deck, at: now, calendar: calendar, random: SeededRandom(seed: 1))
        let id = try #require(stream.session.currentCardID)
        guard case let .rescheduled(change)? = stream.grade(.again, in: deck, at: now, calendar: calendar) else {
            Issue.record("A study session reschedules.")
            return
        }
        _ = deck.apply(change, at: now, calendar: calendar)
        #expect(deck.cards[0].isSuspended)
        #expect(stream.session.isFinished)
        let steps = stream.stepCount

        stream.perform(.keep(id))
        #expect(stream.session.currentCardID == id)
        #expect(stream.session.suspendedCount == 0)
        #expect(stream.stepCount == steps + 1)
    }

    @Test func aPracticeOfMistakesNeverMakesALeech() throws {
        let deck = try deck([reviewCard(lapses: 7)])
        var mode = SessionMode.practice(Practice(practicing: [deck.cards[0].id], at: now))
        guard case .practiced? = mode.grade(.again, in: deck, at: now, calendar: calendar) else {
            Issue.record("Practice only counts the review.")
            return
        }
        #expect(mode.session.leechIDs.isEmpty)
    }
}
