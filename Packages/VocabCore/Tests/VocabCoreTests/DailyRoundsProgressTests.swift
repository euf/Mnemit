import Foundation
import Testing

@testable import VocabCore

/// The rounds, the capacity and the admission of new cards, as `DailyProgress.evaluate` works them out from
/// the decks and their logs.
extension DailyProgressTests {
    /// A review card whose state says it is due on the study day `day`, without a log: it adds nothing to the
    /// history, so the learner has no pace yet and every price is the fallback (30 s new, 10 s other).
    func waiting(_ question: String, onDay day: Int? = nil) -> Card {
        let due = calendar.start(ofDay: day ?? today)
        let state = LearningState(phase: .review, stability: 5, difficulty: 5, lastReview: due.addingTimeInterval(-5 * 86400), due: due, reviews: 1)
        return Card(question: question, answer: question, learningState: state)
    }

    /// A new card created well before any day of these tests.
    func fresh(_ question: String, kind: CardKind? = nil, note: String? = nil) -> Card {
        Card(
            id: UUID(), text: CardText(question: question, answer: question, hint: "")!, note: note, kind: kind,
            created: calendar.start(ofDay: today - 60))
    }

    func at(day: Int, hour: Double = 10) -> Date {
        calendar.start(ofDay: day).addingTimeInterval(hour * 3600)
    }

    /// Studies the plan of `day` as the app does: the new cards the progress at the day's start admits, in the
    /// stream's order, each grade Good, until `stopping` says so. Returns the progress before the first card.
    @discardableResult
    func study(_ deck: inout Deck, onDay day: Int, until stopping: (Int, DailyProgress) -> Bool = { _, progress in progress.ring.isGoalMet }) -> DailyProgress {
        let start = at(day: day)
        let before = evaluate([deck], at: start)
        var session = StudySession(
            deck: deck, at: start, calendar: calendar, random: SeededRandom(seed: UInt64(day)), reviewMode: .revealed, newCardAllowance: before.newCardAllowances.first)
        var done = 0
        var clock = start
        while let id = session.session.currentCardID {
            let progress = evaluate([deck], at: clock)
            if stopping(progress.ring.done, progress) { break }
            clock = clock.addingTimeInterval(8)
            let card = session.review(.good, of: deck.card(withID: id)!, with: deck.learningOptions, at: clock, calendar: calendar)!
            deck.cards[deck.index(of: id)!] = card
            done += 1
        }
        return before
    }

    // MARK: Capacity

    @Test func theCapacityIsTwoOnTheFirstStudyDay() throws {
        var deck = try Deck(learningOptions: options(), cards: (0..<30).map { fresh("n\($0)") })
        #expect(evaluate([deck], at: at(day: today)).capacity == 2)
        study(&deck, onDay: today, until: { done, _ in done >= 3 })
        #expect(evaluate([deck], at: at(day: today, hour: 12)).capacity == 2)
    }

    @Test func twoClosedDaysInARowAddARoundAndAnOpenDayTakesOneAway() throws {
        var deck = try Deck(learningOptions: options(), cards: (0..<400).map { fresh("n\($0)") })
        var capacities: [Int] = []
        // Six days with the ring closed each time, then a day nobody studied, then two days closed again.
        for offset in 0..<9 {
            let day = today - 9 + offset
            capacities.append(evaluate([deck], at: at(day: day, hour: 5)).capacity)
            if offset != 6 { study(&deck, onDay: day) }
        }
        // Day 1: 2. Day 2: one closed day is not two: 2. Then one more for each closed day: 3, 4, 5, 6, 7.
        // The day without study (day 7) is open: day 8 loses a round, and day 9 follows a closed day after an
        // open one: the same. Today follows two closed days again: one more.
        #expect(capacities == [2, 2, 3, 4, 5, 6, 7, 6, 6])
        #expect(evaluate([deck], at: at(day: today, hour: 5)).capacity == 7)
    }

    @Test func aDayStoppedBeforeItsGoalIsOpenAndTakesARoundAway() throws {
        var deck = try Deck(learningOptions: options(), cards: (0..<400).map { fresh("n\($0)") })
        for offset in 0..<4 { study(&deck, onDay: today - 5 + offset) }
        let capacity = evaluate([deck], at: at(day: today - 1, hour: 5)).capacity
        #expect(capacity == 5)
        // The next day is left after a couple of cards: its ring stays open, and the day after has a round less.
        study(&deck, onDay: today - 1, until: { done, _ in done >= 2 })
        #expect(evaluate([deck], at: at(day: today, hour: 5)).capacity == capacity - 1)
    }

    @Test func theCapacityComesFromTheLogsAloneWhateverTheOrderOfTheDecks() throws {
        var first = try Deck(learningOptions: options(), cards: (0..<200).map { fresh("a\($0)") })
        var second = try Deck(learningOptions: options(), cards: (0..<200).map { fresh("b\($0)") })
        for offset in 0..<5 {
            study(&first, onDay: today - 5 + offset)
            if offset.isMultiple(of: 2) { study(&second, onDay: today - 5 + offset) }
        }
        let forwards = evaluate([first, second], at: at(day: today, hour: 12))
        let again = evaluate([first, second], at: at(day: today, hour: 12))
        let backwards = evaluate([second, first], at: at(day: today, hour: 12))
        #expect(forwards == again)
        #expect(forwards.capacity == backwards.capacity)
        #expect(forwards.roundPlan == backwards.roundPlan)
        #expect(forwards.ring == backwards.ring)
        #expect(forwards.streak == backwards.streak)
        #expect(forwards.newCardAllowances == backwards.newCardAllowances.reversed())
    }

    // MARK: Admission

    @Test func newCardsFillTheTimeOfTheDayAfterItsReviews() throws {
        // First day, two rounds, 240 s: 15 reviews of 10 s leave 90 s, which are three new cards of 30 s.
        let deck = try Deck(learningOptions: options(), cards: (0..<15).map { waiting("r\($0)") } + (0..<20).map { fresh("n\($0)") })
        let progress = evaluate([deck])
        #expect(progress.capacity == 2)
        #expect(progress.newCardAllowances == [3])
        #expect(progress.cardsLeft == 18)
        #expect(progress.ring == DailyRing(done: 0, goal: 18))
        #expect(StudySession.counts(for: deck, at: now, calendar: calendar, newCardAllowance: progress.newCardAllowances[0]).new == 3)
    }

    @Test func aDayWithMoreReviewsThanItsTimeAdmitsNoNewCards() throws {
        let deck = try Deck(learningOptions: options(), cards: (0..<40).map { waiting("r\($0)") } + (0..<20).map { fresh("n\($0)") })
        let progress = evaluate([deck])
        #expect(progress.newCardAllowances == [0])
        // The reviews beyond the day's time stay in the plan; the goal is the 24 that fit two rounds.
        #expect(progress.cardsLeft == 40)
        #expect(progress.ring == DailyRing(done: 0, goal: 24))
        #expect(progress.roundEnds == [12, 24])
    }

    @Test func theLimitsOfTheDeckAreCeilingsOfTheAllowance() throws {
        var options = options()
        options.newCardsPerSession = 5
        let deck = try Deck(learningOptions: options, cards: (0..<20).map { fresh("n\($0)") })
        // Eight would fit two rounds; the deck's own limit is five.
        let progress = evaluate([deck])
        #expect(progress.newCardAllowances == [5])
        #expect(progress.ring == DailyRing(done: 0, goal: 5))
    }

    @Test func theAllowanceIsSharedByTheCeilingsOfTheDecks() throws {
        var small = options()
        small.newCardsPerSession = 10
        let first = try Deck(learningOptions: small, cards: (0..<30).map { fresh("a\($0)") })
        let second = try Deck(learningOptions: options(), cards: (0..<30).map { fresh("b\($0)") })
        // Eight new cards over ceilings of 10 and 30: 2 and 6.
        let progress = evaluate([first, second])
        #expect(progress.newCardAllowances == [2, 6])
        #expect(progress.cardsLeft == 8)
        #expect(progress.ring == DailyRing(done: 0, goal: 8))
        // The reviews of either deck take their time from all.
        let busy = try Deck(learningOptions: options(), cards: (0..<15).map { waiting("r\($0)") } + (0..<30).map { fresh("c\($0)") })
        #expect(evaluate([first, busy]).newCardAllowances.reduce(0, +) == 3)
    }

    @Test func theCardsIntroducedTodayCountAgainstTheAllowanceAndTheGoalStaysForTheDay() throws {
        var deck = try Deck(learningOptions: options(), cards: (0..<30).map { fresh("n\($0)") })
        let before = evaluate([deck], at: at(day: today, hour: 6))
        #expect(before.ring.goal == 8)
        study(&deck, onDay: today, until: { done, _ in done >= 3 })
        let during = evaluate([deck], at: at(day: today, hour: 12))
        #expect(during.ring.goal == 8)
        #expect(during.newCardAllowances == before.newCardAllowances)
        // What the stream takes now is what is left of the allowance, not the allowance again.
        let counts = StudySession.counts(for: deck, at: at(day: today, hour: 12), calendar: calendar, newCardAllowance: during.newCardAllowances[0])
        #expect(counts.newAtDayStart == during.newCardsLeft)
        #expect(deck.cards.filter { !$0.isNew }.count + counts.new == 8)
    }

    @Test func aDeckThatBeganTheDayWithoutNewCardsGetsItsShareOfThemOnceTheyAreAdded() throws {
        // Ten new cards were created this afternoon: the day began without them, and they are admitted, up to the
        // time of the day, without being part of the goal.
        let late = (0..<10).map { Card(id: UUID(), question: "n\($0)", answer: "x", created: now.addingTimeInterval(-3600)) }
        let deck = try Deck(learningOptions: options(), cards: (0..<5).map { waiting("r\($0)" ) } + late)
        let progress = evaluate([deck])
        // Five reviews take 50 s of 240: 190 s are six new cards.
        #expect(progress.newCardAllowances == [6])
        #expect(progress.cardsLeft == 11)
        #expect(progress.ring == DailyRing(done: 0, goal: 5))
    }

    @Test func aFirstDayWithoutAnyPlanTakesTheCardsItAdmitsAsItsGoal() throws {
        let late = (0..<20).map { Card(id: UUID(), question: "n\($0)", answer: "x", created: now.addingTimeInterval(-3600)) }
        let progress = evaluate([try Deck(learningOptions: options(), cards: late)])
        #expect(progress.newCardAllowances == [8])
        #expect(progress.ring == DailyRing(done: 0, goal: 8))
        // Its rounds are those of the cards as they stand: four new cards of 30 s a round.
        #expect(progress.roundEnds == [4, 8])
        #expect(progress.streakKeptToday)
    }

    // MARK: Rounds

    @Test func theRoundsAreCutAtTheCostOfEachKindOfCard() throws {
        // 12 reviews fill the first round, four new cards the second.
        let deck = try Deck(learningOptions: options(), cards: (0..<12).map { waiting("r\($0)") } + (0..<20).map { fresh("n\($0)") })
        let progress = evaluate([deck])
        #expect(progress.newCardAllowances == [4])
        #expect(progress.roundEnds == [12, 16])
        #expect(progress.rounds == 2)
        #expect(progress.roundsDone == 0)
        #expect(progress.cardsToNextRound == 12)
        #expect(progress.minutesToNextRound == 2)
    }

    @Test func theRoundsDoneAndTheWayToTheNextOneFollowTheCardsDone() throws {
        var deck = try Deck(learningOptions: options(), cards: (0..<40).map { due("r\($0)", onDay: today) })
        let noon = at(day: today, hour: 12)
        // Three rounds of two minutes hold 36 reviews of 10 s; the plan is 40.
        var progress = evaluate([deck], at: noon)
        #expect(progress.capacity == 3)
        #expect(progress.roundEnds == [12, 24, 36])
        review(5, of: &deck, at: noon)
        progress = evaluate([deck], at: noon)
        #expect(progress.ring == DailyRing(done: 5, goal: 36))
        #expect(progress.roundsDone == 0)
        #expect(progress.cardsToNextRound == 7)
        #expect(progress.minutesToNextRound == 2)
        review(7, of: &deck, at: noon)
        progress = evaluate([deck], at: noon)
        #expect(progress.roundsDone == 1)
        #expect(progress.cardsToNextRound == 12)
        review(24, of: &deck, at: noon)
        progress = evaluate([deck], at: noon)
        #expect(progress.roundsDone == 3)
        #expect(progress.cardsToNextRound == nil)
        #expect(progress.minutesToNextRound == nil)
        #expect(progress.ring.isGoalMet)
        // The rest of the plan is laps.
        review(4, of: &deck, at: noon)
        #expect(evaluate([deck], at: noon).ring == DailyRing(done: 40, goal: 36))
    }

    @Test func theRoundsKeepTheirPlaceThroughTheDay() throws {
        var deck = try Deck(learningOptions: options(), cards: (0..<40).map { due("r\($0)", onDay: today) })
        let morning = evaluate([deck], at: at(day: today, hour: 6))
        review(15, of: &deck, at: at(day: today, hour: 12))
        let noon = evaluate([deck], at: at(day: today, hour: 13))
        #expect(noon.roundEnds == morning.roundEnds)
        #expect(noon.capacity == morning.capacity)
        #expect(noon.newCardAllowances == morning.newCardAllowances)
        #expect(noon.ring.goal == morning.ring.goal)
    }

    // MARK: Streak

    @Test func theFirstRoundKeepsTheStreakWithTheRingStillOpen() throws {
        var deck = try Deck(learningOptions: options(), cards: (0..<40).map { due("r\($0)", onDay: today) })
        // The days since the cards were learned asked nothing and count; today needs its first round, 12 cards.
        review(11, of: &deck, at: now)
        var progress = evaluate([deck])
        #expect(!progress.streakKeptToday)
        #expect(progress.streak == Streak(days: interval, repairCards: nil))
        #expect(progress.cardsToNextRound == 1)
        #expect(progress.minutesToNextRound == 0)
        review(1, of: &deck, at: now)
        progress = evaluate([deck])
        #expect(progress.streakKeptToday)
        #expect(progress.roundsDone == 1)
        #expect(!progress.ring.isGoalMet)
        #expect(progress.streak == Streak(days: interval + 1, repairCards: nil))
    }

    @Test func theProgressHoldsTheWordsInMemoryOfTheDecks() throws {
        var deck = try Deck(learningOptions: options(), cards: (0..<30).map { due("r\($0)", onDay: today) })
        let before = evaluate([deck])
        #expect(before.memory.shownWords > 0)
        #expect(before.memory.shownGain == 0)
        review(12, of: &deck, at: now)
        let after = evaluate([deck])
        // The twelve reviewed today are back at full memory, which the day's start did not have.
        #expect(after.memory.words > before.memory.words)
        #expect(after.memory.shownGain > 0)
        #expect(after.memory.wordsAtDayStart == before.memory.wordsAtDayStart)
    }

    @Test func aRoundHasItsMinutesWhateverTheRingHasCaughtUpWith() throws {
        let deck = try Deck(learningOptions: options(), cards: (0..<40).map { due("r\($0)", onDay: today) })
        let progress = evaluate([deck])
        #expect(progress.minutes(ofRound: 1) == 2)
        #expect(progress.minutes(ofRound: progress.rounds + 1) == nil)
    }

    @Test func aDayWithAnEmptyPlanKeepsTheStreakAndTheRoundsAreNone() throws {
        let deck = try Deck(learningOptions: options(), cards: (0..<5).map { waiting("r\($0)", onDay: today + 3) })
        let progress = evaluate([deck])
        #expect(progress.rounds == 0)
        #expect(progress.roundEnds.isEmpty)
        #expect(progress.streakKeptToday)
        #expect(progress.cardsToNextRound == nil)
    }

    /// Studies the given days as far as `first` rounds, or all of the ring, and skips the others, and returns the deck.
    func learner(days: ClosedRange<Int>, skipping skipped: Set<Int> = [], firstRoundOnly: Set<Int> = []) throws -> Deck {
        var deck = try Deck(learningOptions: options(), cards: (0..<400).map { fresh("n\($0)") })
        for day in days where !skipped.contains(day) {
            if firstRoundOnly.contains(day) {
                study(&deck, onDay: today + day, until: { done, progress in done >= (progress.roundEnds.first ?? 0) })
            } else {
                study(&deck, onDay: today + day)
            }
        }
        return deck
    }

    @Test func aMissedDayIsRepairedWhenTheNextDayClosesItsRing() throws {
        // Four closed days, a day nobody studied, two closed days: the missed day counts, and so do the others.
        let deck = try learner(days: -8 ... -2, skipping: [-4])
        #expect(evaluate([deck], at: at(day: today - 1, hour: 5)).streak == Streak(days: 7, repairCards: nil))
    }

    @Test func aMissedDayIsNotRepairedByTheFirstRoundOfTheNextDayAlone() throws {
        let deck = try learner(days: -8 ... -2, skipping: [-4], firstRoundOnly: [-3])
        // -3 did its first round and not its ring, so -4 stays missed, and the streak starts again with -3, -2.
        #expect(evaluate([deck], at: at(day: today - 1, hour: 5)).streak == Streak(days: 2, repairCards: nil))
    }

    @Test func aDayThatDidItsFirstRoundCountsWithTheRingOpen() throws {
        let deck = try learner(days: -8 ... -2, firstRoundOnly: [-5, -3])
        #expect(evaluate([deck], at: at(day: today - 1, hour: 5)).streak == Streak(days: 7, repairCards: nil))
    }

    @Test func twoMissedDaysInARowEndTheStreak() throws {
        let deck = try learner(days: -8 ... -3, skipping: [-6, -5])
        // The two days between are missed whatever follows: -4 and -3 make a streak of two.
        #expect(evaluate([deck], at: at(day: today - 2, hour: 5)).streak == Streak(days: 2, repairCards: nil))
    }

    @Test func todayStillRepairsYesterdayAndSaysHowManyCardsItTakes() throws {
        var deck = try learner(days: -8 ... -1, skipping: [-1])
        // Yesterday is missed. Today's first round is done; its ring is not.
        study(&deck, onDay: today, until: { done, progress in done >= (progress.roundEnds.first ?? 0) })
        let progress = evaluate([deck], at: at(day: today, hour: 20))
        #expect(progress.streakKeptToday)
        #expect(!progress.ring.isGoalMet)
        #expect(progress.streak == Streak(days: 7, repairCards: progress.ring.goal - progress.ring.done))
        // Closing the ring repairs it: both days count.
        study(&deck, onDay: today)
        #expect(evaluate([deck], at: at(day: today, hour: 21)).streak == Streak(days: 9, repairCards: nil))
    }

    // MARK: History

    @Test func theDayStartOfTodayIsThePlanOfTheDayWhenItBegan() throws {
        var options = options()
        options.newCardsPerSession = 6
        options.productionUnlockDays = 3
        let recognition = (0..<8).map { fresh("r\($0)", kind: .recognition, note: "n\($0)") }
        let production = (0..<8).map { fresh("p\($0)", kind: .production, note: "n\($0)") }
        var deck = try Deck(learningOptions: options, cards: recognition + production + (0..<4).map { waiting("w\($0)") })
        for offset in 0..<5 { study(&deck, onDay: today - 5 + offset) }
        // Some of the plan of today is done before the evaluation.
        study(&deck, onDay: today, until: { done, _ in done >= 4 })
        let when = at(day: today, hour: 15)
        let activity = DeckActivity(deck: deck, calendar: calendar)
        let history = activity.history(from: today - 5, at: when, calendar: calendar)
        let plan = activity.plan(onDayOf: when, calendar: calendar)
        #expect(history.starts[today] == .init(other: plan.learning + plan.review, new: plan.new))
    }

    @Test func anActivityKeepsItsHistoryForTheDayAndWorksItOutAnewForAnother() throws {
        var deck = try Deck(learningOptions: options(), cards: (0..<30).map { fresh("n\($0)") })
        for offset in 0..<3 { study(&deck, onDay: today - 3 + offset) }
        let activity = DeckActivity(deck: deck, calendar: calendar)
        let first = today - 3
        let morning = activity.history(from: first, at: at(day: today, hour: 6), calendar: calendar)
        let evening = activity.history(from: first, at: at(day: today, hour: 22), calendar: calendar)
        #expect(morning.starts == evening.starts)
        #expect(morning.paced.days.mapValues(\.count) == evening.paced.days.mapValues(\.count))
        let tomorrow = activity.history(from: first, at: at(day: today + 1, hour: 6), calendar: calendar)
        #expect(tomorrow.starts[today + 1] != nil)
        #expect(morning.starts[today + 1] == nil)
        // The same evaluation twice is the same figures.
        let figures = DailyProgress.evaluate([activity], at: at(day: today, hour: 12), calendar: calendar)
        #expect(DailyProgress.evaluate([activity], at: at(day: today, hour: 12), calendar: calendar) == figures)
    }

    @Test func theLocksOfTheProductionCardsFollowTheStateOfTheRecognitionCardsLikeTheSession() throws {
        var options = options()
        options.productionUnlockDays = 4
        let notes = (0..<6).map { "n\($0)" }
        let cards = notes.map { fresh("r\($0)", kind: .recognition, note: $0) } + notes.map { fresh("p\($0)", kind: .production, note: $0) }
        var deck = try Deck(learningOptions: options, cards: cards)
        var locks = ProductionLocks(of: deck, calendar: calendar)
        #expect(locks.notes == StudySession.notesAwaitingRecognition(in: deck, calendar: calendar))
        #expect(locks.notes == Set(notes))
        // Learn the recognition cards with growing intervals: the long ones unlock.
        let last = at(day: today - 10)
        for (index, interval) in [1, 3, 4, 9].enumerated() {
            let state = LearningState(
                phase: .review, stability: Double(interval), difficulty: 5, lastReview: last, due: calendar.start(ofDay: calendar.dayNumber(for: last) + interval), reviews: 1)
            deck.cards[index].learningState = state
            locks.update(deck.cards[index], at: index)
            #expect(locks.notes == StudySession.notesAwaitingRecognition(in: deck, calendar: calendar), "after \(index)")
        }
        #expect(locks.notes == Set(["n0", "n1", "n4", "n5"]))
        // The interval of a learned card shortens, as after a lapse: the note locks again.
        deck.cards[3].learningState?.phase = .relearning
        locks.update(deck.cards[3], at: 3)
        #expect(locks.notes == StudySession.notesAwaitingRecognition(in: deck, calendar: calendar))
        #expect(locks.notes.contains("n3"))
    }
}
