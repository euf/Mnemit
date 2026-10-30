import Foundation
import Testing

@testable import VocabCore

/// The words learned: whole words whose Word → Meaning card has left learning, and what the day added.
struct WordsLearnedTests {
    let calendar = StudyCalendar.testing
    let today: Int
    let scheduler: Scheduler

    init() {
        today = StudyCalendar.testing.dayNumber(for: Date(timeIntervalSince1970: 1_791_216_000))
        scheduler = Scheduler(learningOptions: LearningOptions(), calendar: .testing)
    }

    /// Noon of the study day `day`.
    func noon(_ day: Int) -> Date { calendar.start(ofDay: day).addingTimeInterval(8 * 3600) }

    func reviewed(_ card: Card, _ grade: Grade = .good, on day: Int) -> Card {
        var random = SeededRandom(seed: 1)
        return scheduler.review(card, grade: grade, at: noon(day), using: &random)
    }

    /// Two goods, which is what the default steps ask: the card is in the review phase afterwards.
    func learned(_ card: Card, on day: Int) -> Card { reviewed(reviewed(card, on: day), on: day) }

    func recognition(_ question: String = "q", kind: CardKind? = .recognition) -> Card {
        Card(question: question, answer: "a", note: kind == nil ? nil : question, kind: kind)
    }

    func count(_ cards: [Card], on day: Int) throws -> WordsLearned {
        WordsLearned(deck: try Deck(cards: cards), at: noon(day), calendar: calendar)
    }

    @Test func aWordIsLearnedWhenItsCardLeavesLearning() throws {
        #expect(try count([], on: today) == WordsLearned(words: 0, wordsAtDayStart: 0))
        #expect(try count([recognition()], on: today).words == 0)
        // One good is a step: the card is still in learning.
        let step = reviewed(recognition(), on: today)
        #expect(step.learningState?.phase == .learning)
        #expect(try count([step], on: today).words == 0)

        let card = learned(recognition(), on: today)
        #expect(card.learningState?.phase == .review)
        let result = try count([card], on: today)
        #expect(result.words == 1)
        #expect(result.wordsAtDayStart == 0)
        #expect(result.gainToday == 1)
        #expect(result.shownGain == 1)
    }

    @Test func aCardThatFinishedLearningTodayWasInLearningWhenTheDayBegan() throws {
        let result = try count([reviewed(reviewed(recognition(), on: today - 1), on: today)], on: today)
        #expect(result.wordsAtDayStart == 0)
        #expect(result.words == 1)
    }

    @Test func aDayWithoutNewWordsShowsNoGain() throws {
        let result = try count([learned(recognition(), on: today - 5)], on: today)
        #expect(result.words == 1)
        #expect(result.wordsAtDayStart == 1)
        #expect(result.gainToday == 0)
        #expect(result.shownGain == nil)
    }

    @Test func aLapseTakesNoWordOut() throws {
        let known = learned(recognition(), on: today - 5)
        let lapsed = reviewed(known, .again, on: today)
        #expect(lapsed.learningState?.phase == .relearning)
        let after = try count([lapsed], on: today)
        // A word in relearning has left learning, as the ledger and the medals count it.
        #expect(after.words == 1)
        #expect(after.wordsAtDayStart == 1)
        #expect(after.gainToday == 0)
        #expect(after.shownGain == nil)

        // Made up the same day: the day began with it and ends with it.
        let relearned = reviewed(reviewed(lapsed, on: today), on: today)
        #expect(relearned.learningState?.phase == .review)
        let back = try count([relearned], on: today)
        #expect(back.words == 1)
        #expect(back.wordsAtDayStart == 1)
        #expect(back.shownGain == nil)
    }

    @Test func aLapseNextToNewWordsHidesNoneOfTheirGain() throws {
        let lapsed = reviewed(learned(recognition("old"), on: today - 5), .again, on: today)
        let result = try count([lapsed, learned(recognition("new"), on: today), learned(recognition("newer"), on: today)], on: today)
        #expect(result.words == 3)
        #expect(result.wordsAtDayStart == 1)
        #expect(result.shownGain == 2)
    }

    @Test func aCardThatLapsedLastNightAndIsRelearnedThisMorningAddsNothingAndTheHeadlineNeverFalls() throws {
        // At 4:00 the card is in relearning. It graduates again today: the word was learned before, so the headline holds
        // and tomorrow's ledger value for today (the medals' count) is the same number.
        let known = learned(recognition(), on: today - 5)
        let lapsedLastNight = reviewed(known, .again, on: today - 1)
        let relearned = reviewed(reviewed(lapsedLastNight, on: today), on: today)
        let deck = try Deck(cards: [relearned])
        let progress = DailyProgress.evaluate([DeckActivity(deck: deck, calendar: calendar)], at: noon(today), calendar: calendar)
        #expect(progress.learned == WordsLearned(words: 1, wordsAtDayStart: 1))
        #expect(progress.learned.shownGain == nil)
        let tomorrow = DailyProgress.evaluate([DeckActivity(deck: deck, calendar: calendar)], at: noon(today + 1), calendar: calendar)
        #expect(tomorrow.records.first { $0.day == today }?.wordsLearned == progress.learned.words)
    }

    @Test func aSuspendedWordIsInNeitherNumber() throws {
        var card = learned(recognition(), on: today - 3)
        #expect(try count([card], on: today).words == 1)
        card.suspend(at: noon(today))
        let suspended = try count([card], on: today)
        #expect(suspended.words == 0)
        #expect(suspended.wordsAtDayStart == 0)
        #expect(suspended.shownGain == nil)
    }

    @Test func suspendingTodaysNewWordTakesItBackOutOfTheGain() throws {
        var card = learned(recognition(), on: today)
        #expect(try count([card], on: today).shownGain == 1)
        card.suspend(at: noon(today))
        #expect(try count([card], on: today).shownGain == nil)
    }

    @Test func productionCardsCountNothingAndACardWithoutAKindIsAWord() throws {
        let word = learned(recognition("w"), on: today)
        let production = learned(recognition("p", kind: .production), on: today)
        let withoutKind = learned(recognition("k", kind: nil), on: today)
        #expect(try count([word, production], on: today).words == 1)
        #expect(try count([word, production, withoutKind], on: today).words == 2)
    }

    @Test func aWordHeldByTwoDecksCountsOnce() throws {
        let note = "σπίτι#το"
        func card(learnedOn day: Int?) -> Card {
            let card = Card(question: "σπίτι", answer: "house", note: note, kind: .recognition)
            return day.map { learned(card, on: $0) } ?? card
        }
        let a = WordsLearned(deck: try Deck(cards: [card(learnedOn: today - 4)]), at: noon(today), calendar: calendar)
        let b = WordsLearned(deck: try Deck(cards: [card(learnedOn: today)]), at: noon(today), calendar: calendar)
        let notYet = WordsLearned(deck: try Deck(cards: [card(learnedOn: nil)]), at: noon(today), calendar: calendar)
        #expect(a.words == 1 && b.words == 1)
        let both = WordsLearned.total([a, b])
        #expect(both.words == 1)
        // The word was learned when the day began, in the first deck: today's review of the copy gains nothing.
        #expect(both.wordsAtDayStart == 1)
        #expect(both.shownGain == nil)
        // Learned in one deck, new in the other.
        #expect(WordsLearned.total([a, notYet]).words == 1)
        #expect(WordsLearned.total([notYet, notYet]).words == 0)
        // Words of different lemmas add up; cards without a Greek key are words of their own.
        let plain = try count([learned(recognition("x"), on: today), learned(recognition("y"), on: today)], on: today)
        #expect(WordsLearned.total([a, plain, plain]).words == 5)
    }

    @Test func theProgressOfTheDayHoldsBothNumbers() throws {
        let known = try Deck(cards: [learned(recognition("a"), on: today - 8), learned(recognition("b"), on: today), reviewed(recognition("c"), on: today)])
        var pausedOptions = LearningOptions()
        pausedOptions.isPaused = true
        var paused = try Deck(cards: [learned(recognition("d"), on: today - 8)])
        paused.learningOptions = pausedOptions
        let progress = DailyProgress.evaluate(
            [DeckActivity(deck: known, calendar: calendar), DeckActivity(deck: paused, calendar: calendar)], at: noon(today), calendar: calendar)
        // The word of the paused deck stays learned.
        #expect(progress.learned == WordsLearned(words: 3, wordsAtDayStart: 2))
        #expect(progress.learned.shownGain == 1)
        #expect(progress.memory.words > 2)
    }

    // MARK: Milestones

    @Test func theMilestonesAreTenFiftyHundredTwoFiftyFiveHundredThousandThenEveryThousand() {
        #expect(WordsLearned.milestones(upTo: 9) == [])
        #expect(WordsLearned.milestones(upTo: 10) == [10])
        #expect(WordsLearned.milestones(upTo: 99) == [10, 50])
        #expect(WordsLearned.milestones(upTo: 1999) == [10, 50, 100, 250, 500, 1000])
        #expect(WordsLearned.milestones(upTo: 3500) == [10, 50, 100, 250, 500, 1000, 2000, 3000])
        #expect(WordsLearned.nextMilestone(after: 0) == 10)
        #expect(WordsLearned.nextMilestone(after: 10) == 50)
        #expect(WordsLearned.nextMilestone(after: 1000) == 2000)
        #expect(WordsLearned.nextMilestone(after: 2999) == 3000)
        #expect(WordsLearned.nextMilestone(after: 3000) == 4000)
    }

    @Test func theWordsThatLeftLearningAreCountedFromTheDayTheirFirstCardDid() throws {
        // A lapse takes a word out of neither "words learned" nor the count the medals are earned from.
        var cards = (1...5).map { learned(recognition("a\($0)"), on: today - 2) }
        cards += (1...4).map { learned(recognition("b\($0)"), on: today - 1) }
        cards += (1...3).map { learned(recognition("c\($0)"), on: today) }
        cards.append(reviewed(learned(recognition("lapsed"), on: today - 2), .again, on: today))
        cards.append(reviewed(recognition("stillLearning"), on: today))
        var imported = recognition("imported")
        imported.learningState = LearningState(phase: .review, stability: 10, difficulty: 5, lastReview: noon(today - 9), due: noon(today + 3), reviews: 4)
        cards.append(imported)
        let deck = try Deck(cards: cards)
        let progress = DailyProgress.evaluate([DeckActivity(deck: deck, calendar: calendar)], at: noon(today), calendar: calendar)
        // First study day: today - 2. The imported word has no day and counts from it.
        #expect(progress.records.map(\.wordsLearned) == [5 + 1 + 1, 7 + 4, 11 + 3])
        // The lapsed word stays learned: the headline is the medals' count.
        #expect(progress.learned.words == 14)
        #expect(progress.achievements.contains(Achievement(kind: .wordsLearned(count: 10), day: today - 1)))
        #expect(!progress.achievements.contains(Achievement(kind: .wordsLearned(count: 50), day: today)))
    }

    @Test func aWordHeldTwiceCountsOnceFromItsFirstDay() throws {
        let key = try #require(WordKey("σπίτι"))
        let other = try #require(WordKey("δέντρο"))
        let counts = WordsLearned.cumulative([(key, 3), (key, 5), (other, 4), (nil, 5), (nil, nil)], from: 1, through: 6)
        #expect(counts[1] == 1)
        #expect(counts[3] == 2)
        #expect(counts[4] == 3)
        #expect(counts[5] == 4)
        #expect(counts[6] == 4)
        // A day before the first study day, or after today, is held to them.
        #expect(WordsLearned.cumulative([(nil, 0), (nil, 99)], from: 1, through: 6)[1] == 1)
        #expect(WordsLearned.cumulative([(nil, 0), (nil, 99)], from: 1, through: 6)[6] == 2)
        #expect(WordsLearned.cumulative([], from: 4, through: 4) == [4: 0])
    }
}
