import Foundation
import Testing

@testable import VocabCore

/// "Study These Now": the cards just added go first in the stream, ahead of the plan.
extension StudyStreamTests {
    /// Grades the card the stream asks with `grade` and returns which card it was.
    func gradeCurrent(_ run: inout Run, _ grade: Grade) throws -> Card.ID {
        let id = try #require(run.currentID)
        run.grade(grade)
        return id
    }

    @Test func addedCardsAreAskedFirstAndBeyondThePlan() throws {
        var options = options()
        options.newCardsPerSession = 1
        let due = [review("r1"), review("r2")]
        let planned = fresh("planned")
        let given = [fresh("g1"), fresh("g2")]
        var run = try run(due + [planned] + given, options: options)
        let plan = StudySession.counts(for: run.deck, at: now, calendar: calendar)
        #expect(plan.total == 3 && plan.new == 1)

        let added1 = run.stream.addCards(given.map(\.id), in: run.deck, at: now, calendar: calendar)
        #expect(added1)
        // Entering the cards changes no count of the plan.
        #expect(StudySession.counts(for: run.deck, at: now, calendar: calendar) == plan)
        #expect(run.stream.stage == .plan)
        #expect(run.stream.session.totalCount == 2)

        // The two added cards come before any card of the plan, whatever their urgency.
        let first = try gradeCurrent(&run, .easy)
        let second = try gradeCurrent(&run, .easy)
        #expect(Set([first, second]) == Set(given.map(\.id)))
        // Released to other days at once, they count as done like any card done.
        #expect(run.deck.doneCards(onDayOf: now, calendar: calendar) == 2)
        // The plan comes next, with its due cards.
        let next = try #require(run.currentID)
        #expect(due.map(\.id).contains(next))
    }

    @Test func theAddedCardsThatNeedMoreStepsStayInTheirSegmentUntilTheyAreDone() throws {
        let given = fresh("g")
        var run = try run([review("r"), given], newCardAllowance: 0)
        let added2 = run.stream.addCards([given.id], in: run.deck, at: now, calendar: calendar)
        #expect(added2)
        // The steps of a new card: two goods, and in between nothing else is asked.
        let one = try gradeCurrent(&run, .good)
        #expect(one == given.id)
        #expect(run.deck.doneCards(onDayOf: now, calendar: calendar) == 0)
        let two = try gradeCurrent(&run, .good)
        #expect(two == given.id)
        #expect(run.deck.doneCards(onDayOf: now, calendar: calendar) == 1)
        let three = try gradeCurrent(&run, .good)
        #expect(three == run.deck.cards[0].id)
    }

    @Test func addedCardsReviewedTodayCountAgainstTheDaysNewCardLimit() throws {
        // They are new cards introduced today like any other: once reviewed, the limit that
        // the plan's own new cards share has them in it.
        var options = options()
        options.newCardsPerSession = 1
        let planned = fresh("planned")
        let given = fresh("g")
        var run = try run([planned, given], options: options)
        #expect(StudySession.counts(for: run.deck, at: now, calendar: calendar).new == 1)
        let added3 = run.stream.addCards([given.id], in: run.deck, at: now, calendar: calendar)
        #expect(added3)
        _ = try gradeCurrent(&run, .easy)
        #expect(StudySession.counts(for: run.deck, at: now, calendar: calendar).new == 0)
        #expect(run.stream.stage == .rest)
    }

    @Test func theAddedCardsKeepTheLockTheBuryingAndSkipWhatIsNotNewOrNotThere() throws {
        let options = options()
        let learned = review("learned", note: "a", kind: .recognition, interval: 40, dueInDays: 30)
        let unlockedProduction = fresh("pa", note: "a", kind: .production)
        let recognitionB = fresh("rb", note: "b", kind: .recognition)
        let lockedProductionB = fresh("pb", note: "b", kind: .production)
        let firstOfC = fresh("c1", note: "c", kind: .recognition)
        let secondOfC = fresh("c2", note: "c", kind: .recognition)
        var suspended = fresh("s")
        suspended.suspend(at: now)
        let alreadyStudied = review("studied", interval: 5, dueInDays: 5)
        let plain = fresh("plain")
        let deck = try Deck(
            learningOptions: options,
            cards: [learned, unlockedProduction, recognitionB, lockedProductionB, firstOfC, secondOfC, suspended, alreadyStudied, plain])
        let asked = [secondOfC, plain, recognitionB, lockedProductionB, firstOfC, suspended, alreadyStudied, unlockedProduction].map(\.id)
        let addable = StudyStream.addableCards(asked + [plain.id, UUID()], in: deck, at: now, calendar: calendar)
        // In the order given, a word once (the first card of it that was given), duplicates and strangers out.
        #expect(addable == [secondOfC, plain, recognitionB, unlockedProduction].map(\.id))

        var stream = StudyStream(deck: deck, at: now, calendar: calendar, random: SeededRandom(seed: 5), newCardAllowance: 0)
        #expect(stream.stage == .rest)
        let added4 = stream.addCards(asked, in: deck, at: now, calendar: calendar)
        #expect(added4)
        #expect(stream.session.totalCount == 4)
        #expect(stream.stage == .plan)
    }

    @Test func aWordWithACardReviewedTodayBuriesItsAddedCards() throws {
        let options = options()
        var studied = review("c1", note: "c", kind: .recognition, interval: 5, dueInDays: 5)
        studied.learningState?.lastReview = now.addingTimeInterval(-3600)
        let sibling = fresh("c2", note: "c", kind: .recognition)
        let deck = try Deck(learningOptions: options, cards: [studied, sibling])
        #expect(StudyStream.addableCards([sibling.id], in: deck, at: now, calendar: calendar).isEmpty)
    }

    @Test func nothingAddableLeavesTheStreamAsItWasAndAPracticeTakesNoAddedCards() throws {
        let given = fresh("g")
        var run = try run([review("r"), given])
        let before = run.stream.session.currentCardID
        let added5 = run.stream.addCards([], in: run.deck, at: now, calendar: calendar)
        #expect(!added5)
        let added6 = run.stream.addCards([UUID()], in: run.deck, at: now, calendar: calendar)
        #expect(!added6)
        #expect(run.stream.session.currentCardID == before)

        let deck = try Deck(learningOptions: options(), cards: [review("a"), given])
        var practice = StudyStream(practicingNewestWordsIn: deck, at: now, random: SeededRandom(seed: 3))
        let added7 = practice.addCards([given.id], in: deck, at: now, calendar: calendar)
        #expect(!added7)
    }

    @Test func theRoundsStillRestWhileTheAddedCardsAreStudied() throws {
        // The rests belong to the day's rounds, not to the segment: adding cards neither skips nor repeats one.
        let given = (1...3).map { fresh("g\($0)") }
        // A due card stays in the plan, so the ring's rest, which only comes while the plan has cards, comes.
        var run = try run([review("r")] + given, newCardAllowance: 0)
        let added8 = run.stream.addCards(given.map(\.id), in: run.deck, at: now, calendar: calendar)
        #expect(added8)
        let ends = [1, 3]
        _ = try gradeCurrent(&run, .easy)
        settle(&run, ends: ends)
        #expect(run.stream.roundRest == 1)
        run.stream.continueRound()
        _ = try gradeCurrent(&run, .easy)
        _ = try gradeCurrent(&run, .easy)
        settle(&run, ends: ends)
        #expect(run.stream.roundRest == 2)
    }
}
