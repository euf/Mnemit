import Foundation
import Testing

@testable import VocabCore

/// The study stream: today's plan, then review ahead and practice, new cards on request.
struct StudyStreamTests {
    let calendar = StudyCalendar.testing
    /// 2026-10-05 18:00 in Berlin.
    let now = Date(timeIntervalSince1970: 1_791_216_000)

    func options() -> LearningOptions {
        var options = LearningOptions()
        options.fuzzing = false
        options.cardsPerSession = nil
        options.newCardsPerSession = nil
        options.newProductionPerSession = nil
        return options
    }

    /// A card in the review phase, due `dueInDays` study days from now, last reviewed on
    /// an earlier day.
    func review(_ question: String, note: String? = nil, kind: CardKind? = nil, interval: Int = 3, dueInDays: Int = 0) -> Card {
        let last = now.addingTimeInterval(-Double(interval - dueInDays) * 86400)
        let due = calendar.start(ofDay: calendar.dayNumber(for: last) + interval)
        let state = LearningState(phase: .review, stability: Double(interval), difficulty: 5, lastReview: last, due: due, reviews: 1)
        return Card(question: question, answer: question, note: note, kind: kind, learningState: state)
    }

    func fresh(_ question: String, note: String? = nil, kind: CardKind? = nil) -> Card {
        Card(question: question, answer: question, note: note, kind: kind)
    }

    /// A stream over a deck that applies the grades the way the app's driver does: the
    /// change goes into the deck, and then the stream moves on.
    struct Run {
        var deck: Deck
        var stream: StudyStream
        let now: Date
        let calendar: StudyCalendar

        init(_ deck: Deck, now: Date, calendar: StudyCalendar, seed: UInt64 = 1, newCardAllowance: Int? = nil) {
            self.deck = deck
            self.now = now
            self.calendar = calendar
            stream = StudyStream(deck: deck, at: now, calendar: calendar, random: SeededRandom(seed: seed), reviewMode: .revealed, newCardAllowance: newCardAllowance)
        }

        var currentID: Card.ID? { stream.session.currentCardID }

        mutating func grade(_ grade: Grade) {
            guard case let .rescheduled(change)? = stream.grade(grade, in: deck, at: now, calendar: calendar) else {
                // Practice: nothing to store.
                stream.advance(in: deck, at: now, calendar: calendar)
                return
            }
            _ = deck.apply(change, at: now, calendar: calendar)
            while stream.advance(in: deck, at: now, calendar: calendar) {}
        }

        /// Grades `grade` until the stream rests or `stage` changes, at most `limit` times.
        mutating func play(_ grade: Grade = .good, whileIn stage: StudyStream.Stage, limit: Int = 2000) -> Int {
            var count = 0
            while stream.stage == stage, count < limit {
                self.grade(grade)
                count += 1
            }
            return count
        }
    }

    func run(_ cards: [Card], options: LearningOptions? = nil, newCardAllowance: Int? = nil) throws -> Run {
        Run(try Deck(learningOptions: options ?? self.options(), cards: cards), now: now, calendar: calendar, newCardAllowance: newCardAllowance)
    }

    @Test func aGradeWithADurationLogsItAndPracticeLogsNothing() throws {
        var run = try run([review("r1"), review("r2")])
        let id = try #require(run.currentID)
        let outcome = run.stream.grade(.good, in: run.deck, at: now, calendar: calendar, duration: .milliseconds(3300))
        guard case let .rescheduled(change)? = outcome else {
            Issue.record("not rescheduled")
            return
        }
        _ = run.deck.apply(change, at: now, calendar: calendar)
        #expect(run.deck.card(withID: id)?.log.map(\.duration) == [.milliseconds(3300)])

        var practice = StudyStream(practicingNewestWordsIn: run.deck, at: now)
        let practiced = practice.grade(.good, in: run.deck, at: now, calendar: calendar, duration: .milliseconds(3300))
        guard case .practiced? = practiced else {
            Issue.record("not practiced")
            return
        }
    }

    // MARK: Plan

    @Test func theStreamStartsWithTheCountedPlanAndRestsWhenItIsDone() throws {
        var run = try run([review("r1"), review("r2"), fresh("n1"), review("later", interval: 20, dueInDays: 10)])
        let counts = StudySession.counts(for: run.deck, at: now, calendar: calendar)
        #expect(run.stream.stage == .plan)
        #expect(run.stream.session.totalCount == counts.total)
        _ = run.play(whileIn: .plan)
        #expect(run.stream.stage == .rest)
        #expect(run.stream.session.isFinished)
        // Two reviews of the review cards, and the steps of the new card.
        #expect(run.stream.recap.cards == 3)
        #expect(run.stream.recap.reviews == 2 + run.deck.learningOptions.steps)
        #expect(run.stream.recap.accuracy == 1)
    }

    @Test func aStreamKeepsItsNewCardAllowanceForEverySegmentOfThePlan() throws {
        var run = try run((0..<20).map { fresh("n\($0)") }, newCardAllowance: 5)
        #expect(run.stream.newCardAllowance == 5)
        #expect(run.stream.session.totalCount == 5)
        _ = run.play(whileIn: .plan)
        // The plan is done at the allowance, not at the 20 cards the deck has: the stream rests.
        #expect(run.stream.stage == .rest)
        #expect(run.deck.cards.filter { !$0.isNew }.count == 5)
        #expect(StudySession.counts(for: run.deck, at: now, calendar: calendar, newCardAllowance: 5).total == 0)
    }

    @Test func aStreamWithoutAPlanRestsAtOnce() throws {
        let run = try run([review("later", interval: 20, dueInDays: 10)])
        #expect(run.stream.stage == .rest)
        #expect(run.stream.recap.cards == 0)
        #expect(run.stream.recap.accuracy == nil)
    }

    @Test func aPlanCappedBySizeGoesOnWithoutResting() throws {
        var options = options()
        options.cardsPerSession = 2
        var run = try run((0..<5).map { review("r\($0)") }, options: options)
        #expect(run.stream.session.totalCount == 2)
        var segments = Set<UUID>()
        while run.stream.stage == .plan {
            segments.insert(run.stream.session.id)
            run.grade(.good)
        }
        #expect(segments.count == 3)
        #expect(run.deck.cards.allSatisfy { $0.log.count == 1 })
        #expect(run.stream.recap.reviews == 5)
    }

    @Test func aMistakeComesBackWithinThePlanAndTheRecapCountsIt() throws {
        var run = try run([review("r1"), review("r2")])
        run.grade(.again)
        #expect(run.stream.stage == .plan)
        _ = run.play(whileIn: .plan)
        #expect(run.stream.stage == .rest)
        // Again, the steps to relearn, and the other card.
        #expect(run.stream.recap.reviews == 1 + run.deck.learningOptions.steps + 1)
        #expect(run.stream.recap.recalled == run.stream.recap.reviews - 1)
        #expect(run.stream.recap.cards == 2)
    }

    // MARK: Backlog

    /// A review card that fell due yesterday, learned with two Goods as the scheduler replays them, so
    /// the card is what its log says.
    func overdue(_ question: String) -> Card {
        let scheduler = Scheduler(learningOptions: options(), calendar: calendar)
        func learned(onDay day: Int) -> Card {
            let first = calendar.start(ofDay: day).addingTimeInterval(10 * 3600)
            let log = [ReviewLogEntry(date: first, grade: .good, mode: .revealed), ReviewLogEntry(date: first.addingTimeInterval(60), grade: .good, mode: .revealed)]
            return scheduler.replaying(log, of: Card(question: question, answer: question))
        }
        let today = calendar.dayNumber(for: now)
        let interval = calendar.dayNumber(for: learned(onDay: today).learningState!.due) - today
        return learned(onDay: today - 1 - interval)
    }

    @Test func aBacklogIsPartOfThePlanAndBeyondItTheStreamGoesToPractice() throws {
        // Fourteen cards fell due yesterday: all of them are today's plan.
        var run = try run((0..<14).map { overdue("b\($0)") })
        var counts = StudySession.counts(for: run.deck, at: now, calendar: calendar)
        #expect(counts.total == 14)
        #expect(run.stream.stage == .plan)
        #expect(run.stream.session.totalCount == 14)

        // The plan shrinks as it is worked off.
        run.grade(.good)
        counts = StudySession.counts(for: run.deck, at: now, calendar: calendar)
        #expect(counts.total == 13)
        var stages = [run.stream.stage]
        _ = run.play(whileIn: .plan)
        stages.append(run.stream.stage)
        #expect(run.stream.stage == .rest)
        #expect(run.stream.recap.cards == 14)
        #expect(run.deck.cards.allSatisfy { $0.log.count == 3 })
        #expect(StudySession.counts(for: run.deck, at: now, calendar: calendar).total == 0)

        // Beyond the plan there is no catch-up stage: nothing is due, so the stream goes to practice.
        let keptGoing = run.stream.keepGoing(in: run.deck, at: now, calendar: calendar)
        #expect(keptGoing)
        stages.append(run.stream.stage)
        #expect(stages == [.plan, .rest, .practiceNewest])
        #expect(stages.allSatisfy { String(describing: $0) != "catchUp" })
    }

    @Test func withoutABacklogKeepGoingGoesStraightToPractice() throws {
        var run = try run([review("r1"), review("ahead", interval: 20, dueInDays: 10)])
        _ = run.play(whileIn: .plan)
        #expect(run.stream.stage == .rest)
        let keptGoing = run.stream.keepGoing(in: run.deck, at: now, calendar: calendar)
        #expect(keptGoing)
        #expect(run.stream.stage == .practiceNewest)
    }

    @Test func keepGoingNeverReviewsACardBeforeItIsDue() throws {
        var run = try run([review("ahead", interval: 10, dueInDays: 5)])
        #expect(run.stream.stage == .rest)
        let keptGoing = run.stream.keepGoing(in: run.deck, at: now, calendar: calendar)
        #expect(keptGoing)
        #expect(run.stream.stage == .practiceNewest)
        let before = run.deck.cards[0]
        run.grade(.good)
        #expect(run.deck.cards[0] == before)
    }

    // MARK: Practice

    @Test func afterThePlanComePracticeOfTodaysMistakesAndThenTheNewestWordsAgainAndAgain() throws {
        var run = try run([review("due"), review("ahead", interval: 10, dueInDays: 5)])
        let mistake = run.deck.cards[0].id
        run.grade(.again)
        _ = run.play(whileIn: .plan)
        #expect(run.stream.stage == .rest)
        #expect(run.deck.mistakes(onDayOf: now, calendar: calendar) == [mistake])

        let keptGoing = run.stream.keepGoing(in: run.deck, at: now, calendar: calendar)
        #expect(keptGoing)
        #expect(run.stream.stage == .practiceMistakes)
        #expect(run.stream.session.currentCardID == mistake)

        let cardsBeforePractice = run.deck.cards
        _ = run.play(whileIn: .practiceMistakes)
        #expect(run.stream.stage == .practiceNewest)
        // All cards were created at the same second: the newest batch is the whole deck.
        var passes = [run.stream.session.id]
        for _ in 0..<2 {
            let pass = run.stream.session.id
            while run.stream.session.id == pass {
                run.grade(.good)
            }
            #expect(run.stream.stage == .practiceNewest)
            passes.append(run.stream.session.id)
        }
        #expect(Set(passes).count == 3)
        // Practice changed no card.
        #expect(run.deck.cards == cardsBeforePractice)
    }

    @Test func keepGoingWithNothingLeftStaysAtRest() throws {
        var run = try run([])
        #expect(!run.stream.canKeepGoing(in: run.deck, at: now, calendar: calendar))
        let keptGoing = run.stream.keepGoing(in: run.deck, at: now, calendar: calendar)
        #expect(!keptGoing)
        #expect(run.stream.stage == .rest)
    }

    @Test func practiceOnlyStreamRestsWhenDoneAndKeepsItsRecap() throws {
        let deck = try Deck(learningOptions: options(), cards: [review("a"), review("b"), review("c")])
        var stream = StudyStream(practicingNewestWordsIn: deck, at: now, random: SeededRandom(seed: 3))
        #expect(stream.isPracticeOnly)
        #expect(stream.stage == .practiceNewest)
        #expect(stream.session.totalCount == 3)
        var graded = 0
        while !stream.session.isFinished {
            _ = stream.grade(graded == 0 ? .again : .good, in: deck, at: now, calendar: calendar)
            stream.advance(in: deck, at: now, calendar: calendar)
            graded += 1
        }
        #expect(stream.stage == .rest)
        #expect(stream.recap.cards == 3)
        #expect(stream.recap.reviews == graded)
        #expect(stream.recap.recalled == graded - 1)
        let keptGoing = stream.keepGoing(in: deck, at: now, calendar: calendar)
        #expect(!keptGoing)
        // Practice changed no card.
        #expect(deck.cards.allSatisfy { $0.log.isEmpty })
    }

    @Test func practiceOfMistakesWithoutAnyRestsAtOnce() throws {
        let deck = try Deck(learningOptions: options(), cards: [review("a")])
        let stream = StudyStream(practicingMistakesIn: deck, at: now, calendar: calendar)
        #expect(stream.stage == .rest)
    }

    // MARK: New cards on request

    @Test func newCardsBeyondTheLimitComeOnlyOnRequestAndAreSelectedLikeThePlan() throws {
        var options = options()
        options.newCardsPerSession = 2
        options.productionUnlockDays = 0
        var cards = (0..<30).map { fresh("n\($0)", note: "w\($0)", kind: .recognition) }
        // The note of a card asked in the plan is buried for the extra cards, too: one card per note.
        cards.insert(fresh("sibling", note: "w0", kind: .production), at: 1)
        var run = try run(cards, options: options)
        #expect(run.stream.session.totalCount == 2)
        _ = run.play(whileIn: .plan)
        #expect(run.stream.stage == .rest)
        #expect(run.deck.cards.filter { !$0.isNew }.count == 2)

        // The limit is spent: the plan stays empty, the extra cards need the button.
        #expect(StudySession.counts(for: run.deck, at: now, calendar: calendar).new == 0)
        #expect(StudyStream.extraNewCards(in: run.deck, at: now, calendar: calendar) == StudyStream.newCardChunk)
        let added = run.stream.addNewCards(StudyStream.newCardChunk, in: run.deck, at: now, calendar: calendar)
        #expect(added)
        #expect(run.stream.stage == .plan)
        #expect(run.stream.session.totalCount == StudyStream.newCardChunk)
        _ = run.play(whileIn: .plan)
        #expect(run.stream.stage == .rest)
        #expect(run.deck.cards.filter { !$0.isNew }.count == 2 + StudyStream.newCardChunk)
        #expect(run.deck.card(withID: cards[1].id)?.isNew == true)
        // The recap counts the plan segments of the stream, the extra cards included.
        #expect(run.stream.recap.cards == 2 + StudyStream.newCardChunk)
    }

    @Test func extraNewCardsKeepTheProductionLockAndTheBurying() throws {
        var options = options()
        options.newCardsPerSession = 1
        options.newProductionPerSession = 0
        // The limit for the day is spent by a card first reviewed today.
        var introduced = review("introduced", interval: 5, dueInDays: 5)
        introduced.learningState?.lastReview = now.addingTimeInterval(-3600)
        introduced.log = [ReviewLogEntry(date: now.addingTimeInterval(-3600), grade: .good, mode: .revealed)]
        let learned = review("learned", note: "a", kind: .recognition, interval: 40, dueInDays: 30)
        let productionOfLearned = fresh("pa", note: "a", kind: .production)
        let recognitionB = fresh("rb", note: "b", kind: .recognition)
        let lockedProductionB = fresh("pb", note: "b", kind: .production)
        let firstOfC = fresh("c1", note: "c", kind: .recognition)
        let secondOfC = fresh("c2", note: "c", kind: .recognition)
        let deck = try Deck(
            learningOptions: options,
            cards: [introduced, learned, productionOfLearned, recognitionB, lockedProductionB, firstOfC, secondOfC])
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).total == 0)

        // The production limit is 0, the recognition limit used up: the extra cards ignore both, but a locked
        // production card stays out, and so does the second card of a note.
        var random = SeededRandom(seed: 5)
        let ids = StudySession.selectCards(from: deck, at: now, calendar: calendar, extraNew: 10, using: &random)
        #expect(ids.count == 3)
        #expect(ids.contains(productionOfLearned.id))
        #expect(ids.contains(recognitionB.id))
        #expect(!ids.contains(lockedProductionB.id))
        #expect(ids.contains(firstOfC.id) != ids.contains(secondOfC.id))
        #expect(StudyStream.extraNewCards(in: deck, at: now, calendar: calendar) == 3)

        var stream = StudyStream(deck: deck, at: now, calendar: calendar, random: SeededRandom(seed: 5))
        #expect(stream.stage == .rest)
        let added = stream.addNewCards(10, in: deck, at: now, calendar: calendar)
        #expect(added)
        #expect(stream.session.totalCount == 3)
    }

    @Test func addNewCardsDoesNothingWithoutNewCards() throws {
        var run = try run([review("later", interval: 20, dueInDays: 10)])
        #expect(StudyStream.extraNewCards(in: run.deck, at: now, calendar: calendar) == 0)
        let added = run.stream.addNewCards(10, in: run.deck, at: now, calendar: calendar)
        #expect(!added)
        #expect(run.stream.stage == .rest)
    }

    // MARK: Undo

    @Test func aStreamRestoredFromBeforeTheLastReviewAsksThatCardAgain() throws {
        var run = try run([review("only")])
        let before = run.stream
        let deckBefore = run.deck
        let id = run.currentID
        run.grade(.good)
        #expect(run.stream.stage == .rest)
        #expect(run.stream.stepCount == 1)
        // What undo does: the card, then the stream.
        run.deck = deckBefore
        run.stream = before
        #expect(run.stream.stage == .plan)
        #expect(run.stream.stepCount == 0)
        #expect(run.currentID == id)
        #expect(run.stream.id == before.id)
        run.grade(.good)
        #expect(run.stream.stage == .rest)
        #expect(run.deck.cards[0].log.count == 1)
    }

    @Test func aStreamRestoredFromAnEarlierSegmentLeavesTheLaterOneBehind() throws {
        var run = try run([review("due"), review("ahead", interval: 10, dueInDays: 5)])
        let beforeLastPlanReview = run.stream
        let deckBefore = run.deck
        run.grade(.good)
        let keptGoing = run.stream.keepGoing(in: run.deck, at: now, calendar: calendar)
        #expect(keptGoing)
        run.grade(.good)
        #expect(run.stream.stage != .plan)
        run.deck = deckBefore
        run.stream = beforeLastPlanReview
        #expect(run.stream.stage == .plan)
        #expect(run.deck.cards.allSatisfy { $0.log.isEmpty })
    }

    // MARK: Rounds

    /// Moves a run on as the driver does after a review: the deck says how many cards are done, and
    /// the rounds that ended at `ends` say how many rounds that is.
    func settle(_ run: inout Run, ends: [Int]) {
        let done = run.deck.doneCards(onDayOf: now, calendar: calendar)
        run.stream.restAtRoundEnd(roundsDone: ends.filter { $0 <= done }.count, rounds: ends.count)
    }

    @Test func theStreamRestsAtTheFirstRoundOnlyAndGoesOnToTheEndOfThePlan() throws {
        var run = try run((1...5).map { review("r\($0)") })
        let ends = [2, 4, 5]
        run.grade(.good)
        settle(&run, ends: ends)
        #expect(!run.stream.isResting)
        run.grade(.good)
        settle(&run, ends: ends)
        #expect(run.stream.isResting)
        #expect(run.stream.roundRest == 1)
        #expect(run.stream.stage == .plan)
        // The card to ask next is kept, and nothing is graded while the stream rests.
        let next = try #require(run.currentID)
        #expect(run.stream.grade(.good, in: run.deck, at: now, calendar: calendar) == nil)
        #expect(run.currentID == next)
        #expect(!run.stream.canKeepGoing(in: run.deck, at: now, calendar: calendar))

        run.stream.continueRound()
        settle(&run, ends: ends)
        #expect(!run.stream.isResting)
        #expect(run.stream.roundsPassed == 1)
        #expect(run.currentID == next)
        run.grade(.good)
        run.grade(.good)
        settle(&run, ends: ends)
        // The rounds between the first and the last go by without a rest.
        #expect(!run.stream.isResting)
        run.grade(.good)
        settle(&run, ends: ends)
        // The last round ends in the rest of the plan, not in one of its own.
        #expect(run.stream.stage == .rest)
        #expect(run.stream.roundRest == nil)
        #expect(run.stream.roundsPassed == 1)
    }

    @Test func theStreamRestsAtTheRingWhileThePlanHasCardsBeyondIt() throws {
        var run = try run((1...5).map { review("r\($0)") })
        // A goal of 3 cards in a plan of 5, as after a break.
        let ends = [2, 3]
        run.grade(.good)
        run.grade(.good)
        settle(&run, ends: ends)
        #expect(run.stream.roundRest == 1)
        run.stream.continueRound()
        run.grade(.good)
        settle(&run, ends: ends)
        #expect(run.stream.roundRest == 2)
        run.stream.continueRound()
        run.grade(.good)
        settle(&run, ends: ends)
        #expect(!run.stream.isResting)
        run.grade(.good)
        settle(&run, ends: ends)
        #expect(run.stream.stage == .rest)
    }

    @Test func aRoundThatWasDoneBeforeTheStreamBeganIsNoRest() throws {
        var run = try run((1...4).map { review("r\($0)") })
        run.stream.startRounds(at: 1)
        run.grade(.good)
        run.grade(.good)
        settle(&run, ends: [2, 4, 5])
        #expect(!run.stream.isResting)
        // Nor is a round between the first and the last; the plan ends in its rest.
        run.grade(.good)
        run.grade(.good)
        settle(&run, ends: [3, 4, 6])
        #expect(run.stream.stage == .rest)
    }

    @Test func undoBringsTheRoundRestBackAndTakesItAway() throws {
        var run = try run((1...4).map { review("r\($0)") })
        let ends = [2, 4]
        run.grade(.good)
        let beforeLast = run.stream
        let deckBefore = run.deck
        run.grade(.good)
        settle(&run, ends: ends)
        let atRest = run.stream
        #expect(atRest.roundRest == 1)

        // Undo takes back the review, and the stream before it was not at a rest.
        run.deck = deckBefore
        run.stream = beforeLast
        settle(&run, ends: ends)
        #expect(!run.stream.isResting)
        #expect(run.stream.roundRest == nil)

        // Redo gives the stream after the review: the rest comes with it.
        run.stream = atRest
        #expect(run.stream.roundRest == 1)
        #expect(run.stream.isResting)
    }

    @Test func goingOnFromARestIsKeptByUndoOfTheNextReview() throws {
        var run = try run((1...4).map { review("r\($0)") })
        let ends = [2, 4]
        run.grade(.good)
        run.grade(.good)
        settle(&run, ends: ends)
        run.stream.continueRound()
        let beforeThird = run.stream
        let deckBefore = run.deck
        run.grade(.good)
        // What undo does: the deck, then the stream, which moves on without resting again.
        run.deck = deckBefore
        run.stream = beforeThird
        settle(&run, ends: ends)
        #expect(!run.stream.isResting)
        #expect(run.stream.roundsPassed == 1)
    }

    @Test func newCardsAddedAtARestGoOnWithTheRound() throws {
        var run = try run([review("r1"), review("r2"), fresh("n1"), fresh("n2")])
        // A new card graded Good is still in its steps, so the cards are graded until two are done.
        while run.deck.doneCards(onDayOf: now, calendar: calendar) < 2 { run.grade(.good) }
        settle(&run, ends: [2, 4])
        #expect(run.stream.roundRest == 1)
        let added = run.stream.addNewCards(2, in: run.deck, at: now, calendar: calendar)
        #expect(added)
        #expect(!run.stream.isResting)
        #expect(run.stream.roundsPassed == 1)
    }

    @Test func aPracticeOnlyStreamNeverRestsInsideItself() throws {
        var stream = StudyStream(practicingNewestWordsIn: try Deck(cards: [fresh("a"), fresh("b")]), at: now)
        let rests = stream.restAtRoundEnd(roundsDone: 1, rounds: 3)
        #expect(!rests)
        #expect(!stream.isResting)
    }
}
