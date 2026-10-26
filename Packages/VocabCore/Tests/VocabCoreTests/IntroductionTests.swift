import Foundation
import Testing

@testable import VocabCore

/// An introduction is an exposure, not a review: in a deck that introduces new cards the first showing of a
/// new card has its answer open and records nothing, and the card is asked as a question a few cards later.
struct IntroductionTests {
    let calendar = StudyCalendar.testing
    /// 2026-10-05 18:00 in Berlin.
    let now = Date(timeIntervalSince1970: 1_791_216_000)

    func options(introducing: Bool = true) -> LearningOptions {
        var options = LearningOptions()
        options.fuzzing = false
        options.cardsPerSession = nil
        options.newCardsPerSession = nil
        options.newProductionPerSession = nil
        options.introducesNewCards = introducing
        return options
    }

    func review(_ question: String) -> Card {
        let last = now.addingTimeInterval(-3 * 86400)
        let state = LearningState(phase: .review, stability: 3, difficulty: 5, lastReview: last, due: now.addingTimeInterval(-3600), reviews: 1)
        return Card(question: question, answer: question, learningState: state)
    }

    func deck(new: Int, reviews: Int = 0, introducing: Bool = true) throws -> Deck {
        let cards = (0..<new).map { Card(question: "n\($0)", answer: "n\($0)") } + (0..<reviews).map { review("r\($0)") }
        return try Deck(learningOptions: options(introducing: introducing), cards: cards)
    }

    /// A stream over a deck, grading the way the app's driver does.
    struct Run {
        var deck: Deck
        var stream: StudyStream
        let now: Date
        let calendar: StudyCalendar

        init(_ deck: Deck, now: Date, calendar: StudyCalendar) {
            self.deck = deck
            self.now = now
            self.calendar = calendar
            stream = StudyStream(deck: deck, at: now, calendar: calendar, random: SeededRandom(seed: 4))
        }

        var current: Card.ID? { stream.session.currentCardID }
        var isIntroduction: Bool { stream.session.isIntroduction }

        mutating func introduce(for duration: Duration = .seconds(2)) {
            stream.introduce(duration: duration)
            while stream.advance(in: deck, at: now, calendar: calendar) {}
        }

        @discardableResult
        mutating func grade(_ grade: Grade = .good, duration: Duration? = nil) -> Bool {
            guard case let .rescheduled(change)? = stream.grade(grade, in: deck, at: now, calendar: calendar, duration: duration) else { return false }
            _ = deck.apply(change, at: now, calendar: calendar)
            while stream.advance(in: deck, at: now, calendar: calendar) {}
            return true
        }
    }

    // MARK: Queue

    @Test func aHeldCardComesBackAfterThreeOtherCardsOrNextIfNoneAreLeft() {
        let ids = (0..<20).map { _ in UUID() }
        var queue = SessionQueue(cardIDs: ids)
        var random = SeededRandom(seed: 3)
        let held = queue.next(using: &random)!
        queue.hold(held)
        let asked = (0..<4).map { _ in queue.next(using: &random)! }
        #expect(!asked.prefix(3).contains(held))
        #expect(asked[3] == held)

        var alone = SessionQueue(cardIDs: [ids[0]])
        #expect(alone.next(using: &random) == ids[0])
        alone.hold(ids[0])
        #expect(alone.count == 1)
        #expect(alone.next(using: &random) == ids[0])
    }

    @Test func aHeldCardIsPartOfTheQueueUntilItLeaves() {
        let ids = (0..<5).map { _ in UUID() }
        var queue = SessionQueue(cardIDs: ids)
        var random = SeededRandom(seed: 3)
        let held = queue.next(using: &random)!
        queue.hold(held)
        #expect(queue.count == 5)
        #expect(queue.contains(held))
        queue.remove(held)
        #expect(queue.count == 4)
        #expect(!queue.contains(held))
    }

    // MARK: Stream

    @Test func anIntroductionRecordsNoGradeAndChangesNoState() throws {
        var run = Run(try deck(new: 6), now: now, calendar: calendar)
        let id = try #require(run.current)
        #expect(run.isIntroduction)
        let before = run.deck
        let graded = run.grade()  // there is no question to grade
        #expect(!graded)
        #expect(run.current == id)
        run.introduce()
        #expect(run.deck == before)
        #expect(run.deck.card(withID: id)?.learningState == nil)
        #expect(run.deck.card(withID: id)?.log.isEmpty == true)
        #expect(run.stream.stepCount == 0)
        #expect(run.stream.session.reviewCount == 0)
        #expect(run.stream.session.recalledCount == 0)
        #expect(run.stream.session.mistakeIDs.isEmpty)
        #expect(run.stream.session.wasIntroduced(id))
        #expect(run.stream.session.totalCount == 6)
        #expect(run.stream.session.completedCount == 0)
    }

    @Test func anIntroducedCardIsAskedAgainWithinTheStreamAndItsFirstGradeSetsTheState() throws {
        var run = Run(try deck(new: 1, reviews: 8), now: now, calendar: calendar)
        let new = try #require(run.deck.cards.first { $0.isNew }?.id)
        var others = 0
        var introducedAt: Int?
        var askedAt: Int?
        for turn in 0..<200 where run.stream.stage == .plan {
            let id = try #require(run.current)
            if run.isIntroduction {
                #expect(id == new)
                introducedAt = turn
                run.introduce()
            } else {
                if id == new, askedAt == nil, introducedAt != nil {
                    askedAt = turn
                    others = turn - introducedAt! - 1
                    #expect(run.deck.card(withID: new)?.learningState == nil)
                    let graded = run.grade()
                    #expect(graded)
                    #expect(run.deck.card(withID: new)?.learningState != nil)
                    #expect(run.deck.card(withID: new)?.log.count == 1)
                } else {
                    run.grade()
                }
            }
        }
        #expect(introducedAt != nil)
        #expect(askedAt != nil)
        // Three other cards come between, fewer only when the stream has no more.
        #expect(others <= SessionQueue.introductionGap)
        #expect(others >= 0)
    }

    @Test func aSoleNewCardIsAskedRightAfterItsIntroduction() throws {
        var run = Run(try deck(new: 1), now: now, calendar: calendar)
        let id = try #require(run.current)
        #expect(run.isIntroduction)
        run.introduce()
        #expect(run.current == id)
        #expect(!run.isIntroduction)
        #expect(run.stream.stage == .plan)
    }

    @Test func theIntroductionsTimeIsAddedToTheFirstReviewsDuration() throws {
        var run = Run(try deck(new: 1), now: now, calendar: calendar)
        let id = try #require(run.current)
        run.introduce(for: .milliseconds(4000))
        run.grade(.good, duration: .milliseconds(1500))
        #expect(run.deck.card(withID: id)?.log.map(\.duration) == [.milliseconds(5500)])
        // The second review is the card's own time alone.
        while run.stream.stage == .plan, run.current == id { run.grade(.good, duration: .milliseconds(900)) }
        #expect(run.deck.card(withID: id)?.log.map(\.duration) == [.milliseconds(5500), .milliseconds(900)])
        #expect(!run.stream.session.wasIntroduced(id))
    }

    @Test func aDeckWithTheOptionOffAsksNewCardsAsBefore() throws {
        var run = Run(try deck(new: 3, reviews: 3, introducing: false), now: now, calendar: calendar)
        var asked = 0
        while run.stream.stage == .plan, asked < 100 {
            #expect(!run.isIntroduction)
            let graded = run.grade()
            #expect(graded)
            asked += 1
        }
        // Three new cards take two steps, the reviews one.
        #expect(asked == 3 * 2 + 3)
    }

    @Test func onlyNewCardsAreIntroducedNotLearningOrReviewCards() throws {
        var run = Run(try deck(new: 2, reviews: 4), now: now, calendar: calendar)
        var introduced: [Card.ID] = []
        // Every question is a lapse or a failed first answer: those cards are in learning and never introduced.
        for _ in 0..<60 where run.stream.stage == .plan {
            if run.isIntroduction {
                introduced.append(try #require(run.current))
                run.introduce()
            } else {
                run.grade(.again)
            }
        }
        #expect(introduced.count == 2)
        #expect(introduced.allSatisfy { run.deck.card(withID: $0)?.question.hasPrefix("n") == true })
    }

    @Test func practicesNeverIntroduce() throws {
        let deck = try deck(new: 4)
        var newest = StudyStream(practicingNewestWordsIn: deck, at: now, random: SeededRandom(seed: 1))
        #expect(!newest.session.isIntroduction)
        newest.introduce(duration: .seconds(1))  // does nothing in a practice
        #expect(!newest.session.isIntroduction)
        #expect(!newest.session.wasIntroduced(try #require(newest.session.currentCardID)))
        let mistakes = StudyStream(practicingMistakesIn: deck, at: now, calendar: calendar, random: SeededRandom(seed: 1))
        #expect(!mistakes.session.isIntroduction)
    }

    @Test func aStreamThatEndsBetweenIntroductionAndQuestionLeavesTheCardNewAndIntroducesItAgain() throws {
        var run = Run(try deck(new: 3), now: now, calendar: calendar)
        let id = try #require(run.current)
        run.introduce()
        #expect(run.deck.card(withID: id)?.isNew == true)
        // The learner leaves; the next stream starts from the deck.
        let next = Run(run.deck, now: now, calendar: calendar)
        #expect(next.isIntroduction)
        #expect(next.stream.session.totalCount == 3)
    }

    @Test func aStreamRestoredFromBeforeAnIntroductionShowsItAgain() throws {
        var run = Run(try deck(new: 3), now: now, calendar: calendar)
        let before = run.stream
        let id = try #require(run.current)
        run.introduce()
        #expect(run.stream.session.wasIntroduced(id))
        run.stream = before  // what undo does, back to the card before
        #expect(run.current == id)
        #expect(run.isIntroduction)
        #expect(!run.stream.session.wasIntroduced(id))
    }

    @Test func theOptionRoundTripsThroughTheDeckFileAndIsLeftOutWhileOff() throws {
        let off = try deck(new: 1, introducing: false)
        #expect(!String(decoding: try DeckFile.encodeDeck(off), as: UTF8.self).contains("introducesNewCards"))
        #expect(!(try DeckFile.decode(DeckFile.fileWrapper(for: off))).learningOptions.introducesNewCards)

        let on = try deck(new: 1, introducing: true)
        #expect(String(decoding: try DeckFile.encodeDeck(on), as: UTF8.self).contains("\"introducesNewCards\""))
        let read = try DeckFile.decode(DeckFile.fileWrapper(for: on))
        #expect(read.learningOptions.introducesNewCards)
        #expect(read == on)

        // A key that is not a Boolean costs the mark, not the deck.
        let odd = Data(
            """
            {"format": "de.fluch-it-consulting.voctrain.deck", "version": 4, "progress": [],
             "learningOptions": {"introducesNewCards": "yes"}, "cards": []}
            """.utf8)
        #expect(!(try DeckFile.decode(odd)).learningOptions.introducesNewCards)
    }
}
