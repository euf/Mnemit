import Foundation
import Testing

@testable import VocabCore

/// The limits on new cards hold for the study day, not for a session: cards first
/// reviewed today count against them, whichever session introduced them.
struct DailyLimitTests {
    let calendar = StudyCalendar.testing
    /// 2026-10-05 18:00 in Berlin.
    let now = Date(timeIntervalSince1970: 1_791_216_000)
    var today: Int { calendar.dayNumber(for: now) }

    func deck(_ cards: [Card], newPerDay: Int? = nil, productionPerDay: Int? = nil) throws -> Deck {
        var options = LearningOptions()
        options.fuzzing = false
        options.cardsPerSession = nil
        options.newCardsPerSession = newPerDay
        options.newProductionPerSession = productionPerDay
        options.productionUnlockDays = 0
        return try Deck(learningOptions: options, cards: cards)
    }

    func fresh(_ count: Int, kind: CardKind? = nil, prefix: String = "n") -> [Card] {
        (0..<count).map { Card(question: "\(prefix)\($0)", answer: "\(prefix)\($0)", note: "\(prefix)\($0)", kind: kind) }
    }

    /// Plays a session started at `time` through with Good, as the app would apply it.
    /// Returns what the counts promised before the session; the session takes the same.
    @discardableResult
    func study(_ deck: inout Deck, at time: Date, stoppingAfter reviews: Int = .max) -> StudyCounts {
        let counts = StudySession.counts(for: deck, at: time, calendar: calendar)
        var study = StudySession(deck: deck, at: time, calendar: calendar, random: SeededRandom(seed: 1))
        #expect(study.session.totalCount == counts.total)
        var done = 0
        while done < reviews, let id = study.session.currentCardID {
            let card = study.review(.good, of: deck.card(withID: id)!, with: deck.learningOptions, at: time, calendar: calendar)!
            deck.cards[deck.index(of: id)!] = card
            done += 1
        }
        return counts
    }

    @Test func twoSessionsOnOneDayIntroduceAtMostTheLimit() throws {
        var deck = try deck(fresh(12), newPerDay: 5)
        #expect(study(&deck, at: now).new == 5)
        #expect(deck.cards.filter { !$0.isNew }.count == 5)

        // The counts the deck screen shows say so, and so does a second session.
        let counts = study(&deck, at: now.addingTimeInterval(3600))
        #expect(counts.new == 0)
        #expect(counts.total == 0)
        #expect(deck.cards.filter { !$0.isNew }.count == 5)
    }

    /// Plays the plan of `time` through with Good under `allowance`, as the stream does, and returns the plan it promised.
    @discardableResult
    func study(_ deck: inout Deck, at time: Date, allowance: Int?) -> StudyCounts {
        let counts = StudySession.counts(for: deck, at: time, calendar: calendar, newCardAllowance: allowance)
        var study = StudySession(deck: deck, at: time, calendar: calendar, random: SeededRandom(seed: 1), newCardAllowance: allowance)
        #expect(study.session.totalCount == counts.total)
        while let id = study.session.currentCardID {
            let card = study.review(.good, of: deck.card(withID: id)!, with: deck.learningOptions, at: time, calendar: calendar)!
            deck.cards[deck.index(of: id)!] = card
        }
        return counts
    }

    @Test func withoutAnAllowanceThePlanIsTheOldOneOfTheLimits() throws {
        let deck = try deck(fresh(12), newPerDay: 5)
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar, newCardAllowance: nil) == StudySession.counts(for: deck, at: now, calendar: calendar))
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).new == 5)
        var random = SeededRandom(seed: 1)
        let ids = StudySession.selectCards(from: deck, at: now, calendar: calendar, using: &random)
        random = SeededRandom(seed: 1)
        #expect(StudySession.selectCards(from: deck, at: now, calendar: calendar, newCardAllowance: nil, using: &random) == ids)
        #expect(ids.count == 5)
    }

    @Test func anAllowanceBelowTheLimitCapsTheNewCardsAndOneAboveItLeavesThem() throws {
        let deck = try deck(fresh(12), newPerDay: 5)
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar, newCardAllowance: 3).new == 3)
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar, newCardAllowance: 9).new == 5)
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar, newCardAllowance: 0).new == 0)
        var random = SeededRandom(seed: 1)
        #expect(StudySession.selectCards(from: deck, at: now, calendar: calendar, newCardAllowance: 3, using: &random).count == 3)
        #expect(StudySession(deck: deck, at: now, calendar: calendar, newCardAllowance: 2).session.totalCount == 2)
    }

    @Test func anAllowanceTakesNoReviewCardsAndAnUnlimitedDeckTakesJustTheAllowance() throws {
        var cards = fresh(40)
        cards.append(contentsOf: (0..<4).map { Card(question: "r\($0)", answer: "r\($0)", learningState: LearningState(phase: .review, stability: 3, difficulty: 5, lastReview: now.addingTimeInterval(-3 * 86400), due: now.addingTimeInterval(-3600))) })
        let deck = try deck(cards)
        let counts = StudySession.counts(for: deck, at: now, calendar: calendar, newCardAllowance: 6)
        #expect(counts.review == 4)
        #expect(counts.new == 6)
    }

    @Test func theCardsIntroducedTodayCountAgainstTheAllowance() throws {
        var deck = try deck(fresh(20))
        #expect(study(&deck, at: now, allowance: 4).new == 4)
        // The same day, the same allowance: nothing is left to take, nor does a later session take more.
        #expect(study(&deck, at: now.addingTimeInterval(3600), allowance: 4).new == 0)
        #expect(deck.cards.filter { !$0.isNew }.count == 4)
        // A larger allowance, as the day's budget grew, lets the difference in.
        #expect(study(&deck, at: now.addingTimeInterval(7200), allowance: 7).new == 3)
        // The next study day starts with the allowance whole again.
        #expect(study(&deck, at: calendar.start(ofDay: today + 1).addingTimeInterval(3600), allowance: 4).new == 4)
    }

    @Test func theAllowanceHoldsForTheProductionCardsToo() throws {
        let deck = try deck(fresh(4) + fresh(4, kind: .production, prefix: "p"), productionPerDay: 3)
        let counts = StudySession.counts(for: deck, at: now, calendar: calendar, newCardAllowance: 5)
        #expect(counts.new == 5)
        #expect(counts.newProduction <= 3)
    }

    @Test func newCardsOnRequestComeBeyondTheAllowance() throws {
        let deck = try deck(fresh(30))
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar, extraNew: 10, newCardAllowance: 6).new == 16)
        #expect(StudyStream.extraNewCards(in: deck, at: now, calendar: calendar, newCardAllowance: 6) == StudyStream.newCardChunk)
        var stream = StudyStream(deck: deck, at: now, calendar: calendar, newCardAllowance: 6)
        #expect(stream.session.totalCount == 6)
        let added = stream.addNewCards(StudyStream.newCardChunk, in: deck, at: now, calendar: calendar)
        #expect(added)
        #expect(stream.session.totalCount == 16)
    }

    @Test func theNextStudyDayRefillsTheLimit() throws {
        var deck = try deck(fresh(12), newPerDay: 5)
        study(&deck, at: now)
        let tomorrow = calendar.start(ofDay: today + 1).addingTimeInterval(3600)
        // The cards of yesterday are scheduled for later, so only new cards are due.
        #expect(study(&deck, at: tomorrow).new == 5)
        #expect(study(&deck, at: tomorrow.addingTimeInterval(3600)).new == 0)
        #expect(study(&deck, at: calendar.start(ofDay: today + 2).addingTimeInterval(3600)).new == 2)
        #expect(deck.cards.allSatisfy { !$0.isNew })
    }

    @Test func theStudyDayEndsAtTheRollover() throws {
        var deck = try deck(fresh(12), newPerDay: 4)
        // 02:00 after midnight still belongs to the study day that began the morning before.
        study(&deck, at: calendar.start(ofDay: today).addingTimeInterval(22 * 3600))
        #expect(study(&deck, at: calendar.start(ofDay: today + 1).addingTimeInterval(-60)).new == 0)
        #expect(study(&deck, at: calendar.start(ofDay: today + 1)).new == 4)
    }

    @Test func cardsLeftInLearningLeaveTheRestOfTheQuota() throws {
        var deck = try deck(fresh(12), newPerDay: 5)
        // The learner stops after three reviews: each introduced a card, none is learned yet.
        study(&deck, at: now, stoppingAfter: 3)
        let introduced = deck.cards.filter { !$0.isNew }.count
        #expect(introduced > 0)

        let counts = StudySession.counts(for: deck, at: now.addingTimeInterval(60), calendar: calendar)
        #expect(counts.learning == introduced)
        #expect(counts.new == 5 - introduced)
    }

    @Test func productionCardsHaveALimitOfTheirOwn() throws {
        let cards = fresh(6) + fresh(6, kind: .production, prefix: "p")
        var deck = try deck(cards, newPerDay: 2, productionPerDay: 1)
        let first = study(&deck, at: now)
        #expect(first.newOther == 2)
        #expect(first.newProduction == 1)

        let second = study(&deck, at: now.addingTimeInterval(3600))
        #expect(second.new == 0)
        #expect(deck.cards.filter { !$0.isNew && $0.kind == .production }.count == 1)

        // Only the other kind refills when a limit is the larger: raise the one for production cards.
        deck.learningOptions.newProductionPerSession = 3
        let third = study(&deck, at: now.addingTimeInterval(7200))
        #expect(third.newProduction == 2)
        #expect(third.newOther == 0)
    }

    @Test func aLimitOfZeroAsksNoNewProductionCards() throws {
        var deck = try deck(fresh(3, kind: .production), productionPerDay: 0)
        #expect(study(&deck, at: now).total == 0)
        #expect(deck.cards.allSatisfy { $0.isNew })
    }

    @Test func noLimitIntroducesEveryCardInOneSession() throws {
        var deck = try deck(fresh(30))
        #expect(study(&deck, at: now).new == 30)
        #expect(study(&deck, at: now.addingTimeInterval(3600)).total == 0)
    }

    @Test func cardsThatTheLogDoesNotReachBackForAreNotIntroducedToday() throws {
        // Imported from MacVocTrain 1: five reviews counted, but only today's is in the log.
        var imported = Card(
            question: "old", answer: "old",
            learningState: LearningState(phase: .review, stability: 30, difficulty: 5, lastReview: now, due: now.addingTimeInterval(30 * 86400), reviews: 5),
            log: [ReviewLogEntry(date: now, grade: .good)]
        )
        #expect(!imported.hasCompleteLog)
        var deck = try deck([imported] + fresh(3), newPerDay: 1)
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).new == 1)

        // With the whole log, the card was introduced today and takes the quota.
        imported.learningState?.reviews = 1
        deck = try self.deck([imported] + fresh(3), newPerDay: 1)
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).new == 0)
    }

    @Test func resettingACardGivesItsPlaceBack() throws {
        var deck = try deck(fresh(3), newPerDay: 1)
        study(&deck, at: now)
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).new == 0)
        let introduced = Set(deck.cards.filter { !$0.isNew }.map(\.id))
        let change = try #require(DeckChange.resettingLearningState(of: introduced, in: deck, at: now))
        _ = deck.apply(change, at: now, calendar: calendar)
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar).new == 1)
    }
}
