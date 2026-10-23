import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// A store in memory, for the tests of what the app writes and of the timeline.
final class FakeSnapshotStore: SnapshotStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: WidgetSnapshot?
    private var writeCount = 0
    var succeeds = true

    var writes: Int { lock.withLock { writeCount } }

    func read() -> WidgetSnapshot? { lock.withLock { stored } }

    func write(_ snapshot: WidgetSnapshot) -> Bool {
        lock.withLock {
            guard succeeds else { return false }
            stored = snapshot
            writeCount += 1
            return true
        }
    }
}

/// The days are in UTC, so the tests read the same in every time zone: the study day starts
/// at 04:00.
enum WidgetFixtures {
    static let zone = TimeZone(identifier: "UTC")!
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }()
    static let studyCalendar = StudyCalendar(timeZone: zone, rolloverHour: 4)

    static func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    /// Cards in every state: three reviews due, a learning card due at 11:30 on the 22nd, two
    /// reviews due at 15:30, four new cards, and cards that are never due: one far off and one
    /// suspended.
    static func deck(now: Date = date(22, 10, 20)) -> Deck {
        func state(_ phase: LearningPhase, due: Date) -> LearningState {
            LearningState(phase: phase, stability: 6, difficulty: 5, lastReview: now.addingTimeInterval(-5 * 86_400), due: due, reviews: 3)
        }
        let created = now.addingTimeInterval(-90 * 86_400)
        var cards: [Card] = []
        for index in 0..<3 {
            cards.append(Card(question: "r\(index)", answer: "r", created: created, learningState: state(.review, due: now.addingTimeInterval(-3600))))
        }
        cards.append(Card(question: "l", answer: "l", created: created, learningState: state(.learning, due: now.addingTimeInterval(70 * 60))))
        for index in 0..<2 {
            cards.append(Card(question: "later\(index)", answer: "l", created: created, learningState: state(.review, due: now.addingTimeInterval(310 * 60))))
        }
        for index in 0..<4 {
            cards.append(Card(question: "n\(index)", answer: "n", created: now, learningState: nil))
        }
        cards.append(Card(question: "far", answer: "f", created: created, learningState: state(.review, due: now.addingTimeInterval(20 * 86_400))))
        cards.append(Card(question: "paused", answer: "p", created: created, learningState: nil, isSuspended: true))
        return try! Deck(cards: cards)
    }

    static func progress(done: Int, goal: Int, streak: Int, cardsLeft: Int = 0, newCardsLeft: Int = 0, pace: Pace = Pace()) -> DailyProgress {
        DailyProgress(ring: DailyRing(done: done, goal: goal), streak: Streak(days: streak, repairCards: nil), cardsLeft: cardsLeft, newCardsLeft: newCardsLeft, pace: pace)
    }

    /// A snapshot made at `now` whose due count is `count(date)`, hourly for two days.
    static func snapshot(
        now: Date, done: Int, goal: Int = 20, streak: Int, isGoalMet: Bool, reminder: Date? = nil, secondsPerCard: Double? = nil,
        count: (Date) -> Int
    ) -> WidgetSnapshot {
        let dates = WidgetSnapshot.forecastDates(from: now, calendar: calendar)
        return WidgetSnapshot(
            date: now, done: done, goal: goal, streakDays: streak, isGoalMet: isGoalMet,
            due: dates.map { .init(date: $0, count: count($0)) }, nextReminder: reminder, secondsPerCard: secondsPerCard)
    }
}

struct WidgetSnapshotTests {
    typealias Fixtures = WidgetFixtures

    // MARK: Format

    @Test func snapshotSurvivesJSON() throws {
        let snapshot = Fixtures.snapshot(
            now: Fixtures.date(22, 10, 20), done: 12, streak: 7, isGoalMet: false, reminder: Fixtures.date(23, 9)
        ) { _ in 42 }
        let data = try snapshot.encoded()
        #expect(WidgetSnapshot.decoded(from: data) == snapshot)
        // Small: 49 forecast points, a few kilobytes at most.
        #expect(data.count < 4096)
    }

    @Test func snapshotKeysAreTheFormat() throws {
        let snapshot = Fixtures.snapshot(now: Fixtures.date(22, 10), done: 3, streak: 2, isGoalMet: false) { _ in 1 }
        let json = try #require(JSONSerialization.jsonObject(with: snapshot.encoded()) as? [String: Any])
        // No reminder: no key.
        #expect(Set(json.keys) == ["date", "reviews", "goal", "streakDays", "isGoalMet", "due"])
        let first = try #require((json["due"] as? [[String: Any]])?.first)
        #expect(Set(first.keys) == ["date", "count"])
        #expect(json["date"] as? Double == Fixtures.date(22, 10).timeIntervalSince1970)
    }

    /// The cards done are stored under the key "reviews", the one a stored snapshot has.
    @Test func aStoredSnapshotWithTheReviewsKeyDecodesIntoDone() throws {
        let json = #"{"date":1792663200,"reviews":12,"goal":20,"streakDays":7,"isGoalMet":false,"due":[{"date":1792663200,"count":42}]}"#
        let snapshot = try #require(WidgetSnapshot.decoded(from: Data(json.utf8)))
        #expect(snapshot.done == 12 && snapshot.goal == 20 && snapshot.streakDays == 7 && !snapshot.isGoalMet)
        #expect(snapshot.due.map(\.count) == [42])
    }

    @Test func thePriceOfACardIsInTheFormatOnlyWhenThereIsOne() throws {
        let priced = Fixtures.snapshot(now: Fixtures.date(22, 10), done: 3, streak: 2, isGoalMet: false, secondsPerCard: 9.5) { _ in 1 }
        let json = try #require(JSONSerialization.jsonObject(with: priced.encoded()) as? [String: Any])
        #expect(json["secondsPerCard"] as? Double == 9.5)
        #expect(WidgetSnapshot.decoded(from: try priced.encoded()) == priced)
        // What an older app wrote has no price: it still reads, and there is no time to show.
        let unpriced = Fixtures.snapshot(now: Fixtures.date(22, 10), done: 3, streak: 2, isGoalMet: false) { _ in 1 }
        let old = try #require(WidgetSnapshot.decoded(from: try unpriced.encoded()))
        #expect(old.secondsPerCard == nil)
        #expect(old.state(at: Fixtures.date(22, 10)).minutesLeft == nil)
    }

    /// What an older app wrote has no rounds and no words: it still reads, and the widget shows the cards left.
    @Test func aSnapshotOfAnOlderAppHasNoRoundsAndNoWords() throws {
        let json = #"{"date":1792663200,"reviews":12,"goal":20,"streakDays":7,"isGoalMet":true,"secondsPerCard":9.5,"due":[{"date":1792663200,"count":42}]}"#
        let snapshot = try #require(WidgetSnapshot.decoded(from: Data(json.utf8)))
        #expect(snapshot.rounds == nil && snapshot.roundsDone == nil && snapshot.minutesToNextRound == nil)
        #expect(snapshot.wordsInMemory == nil && snapshot.wordsToday == nil)
        let state = snapshot.state(at: Date(timeIntervalSince1970: 1_792_663_200))
        #expect(state.roundStatus == nil)
        #expect(state.isStreakKept)
        #expect(state.due == 42)
        // And it writes none of them back.
        let written = try #require(JSONSerialization.jsonObject(with: snapshot.encoded()) as? [String: Any])
        #expect(Set(written.keys) == ["date", "reviews", "goal", "streakDays", "isGoalMet", "due", "secondsPerCard"])
    }

    @Test func theSnapshotKeepsTheRoundsAndTheWordsOfTheProgress() throws {
        let rounds = DayRounds(otherCards: 20, newCards: 0, pace: Pace(newCard: 30, otherCard: 15), seconds: 360)
        #expect(rounds.ends == [8, 20])
        let progress = DailyProgress(
            ring: DailyRing(done: 12, goal: 20), streak: Streak(days: 7, repairCards: nil), roundPlan: rounds, streakKeptToday: true,
            memory: MemoryEstimate(words: 28.4, wordsAtDayStart: 13.2))
        let now = Fixtures.date(22, 10, 20)
        let snapshot = WidgetSnapshot(now: now, progress: progress, dates: [now], dueByDeck: [[8]], nextReminder: nil)
        #expect(snapshot.rounds == 2 && snapshot.roundsDone == 1)
        // From 12 done to the goal at 20: eight cards at 15 s, two minutes.
        #expect(snapshot.minutesToNextRound == 2)
        #expect(snapshot.wordsInMemory == 28 && snapshot.wordsToday == 15)
        #expect(WidgetSnapshot.decoded(from: try snapshot.encoded()) == snapshot)

        let state = snapshot.state(at: now, calendar: Fixtures.studyCalendar)
        #expect(state.roundStatus == RoundStatus(rounds: 2, roundsDone: 1, minutesToNext: 2))
        #expect(state.wordsInMemory == 28 && state.wordsToday == 15)
        // The next study day only has a forecast: no rounds, and the words are not the same after a night.
        let tomorrow = snapshot.state(at: Fixtures.date(23, 10), calendar: Fixtures.studyCalendar)
        #expect(tomorrow.roundStatus == nil && tomorrow.wordsInMemory == nil && tomorrow.wordsToday == nil)
    }

    @Test func theStreakIsKeptOnceTheFirstRoundIsDone() {
        func state(roundsDone: Int, rounds: Int = 3) -> WidgetState {
            WidgetState(
                date: Fixtures.date(22, 10), done: 5, goal: 20, streakDays: 3, isGoalMet: false, due: 15, nextReminder: nil, rounds: rounds, roundsDone: roundsDone)
        }
        #expect(!state(roundsDone: 0).isStreakKept)
        #expect(state(roundsDone: 1).isStreakKept)
        // A day without a plan keeps it from the start.
        #expect(state(roundsDone: 0, rounds: 0).isStreakKept)
    }

    @Test func unreadableDataIsNoSnapshot() {
        #expect(WidgetSnapshot.decoded(from: Data("{}".utf8)) == nil)
        #expect(WidgetSnapshot.decoded(from: Data()) == nil)
    }

    @Test func lapsCountTheGoalReachedAgain() {
        let snapshot = { (done: Int) in
            Fixtures.snapshot(now: Fixtures.date(22, 10), done: done, goal: 20, streak: 1, isGoalMet: done >= 20) { _ in 0 }
        }
        #expect(snapshot(19).laps == 0)
        #expect(snapshot(20).laps == 1)
        #expect(snapshot(45).laps == 2)
    }

    // MARK: Forecast

    @Test func forecastLooksAtTheNextFullHours() {
        let now = Fixtures.date(22, 10, 20)
        let dates = WidgetSnapshot.forecastDates(from: now, calendar: Fixtures.calendar)
        #expect(dates.count == 1 + WidgetSnapshot.forecastHours)
        #expect(dates[0] == now)
        #expect(dates[1] == Fixtures.date(22, 11))
        #expect(dates[2] == Fixtures.date(22, 12))
        #expect(dates.last == Fixtures.date(24, 10))
        // On the hour itself the next one is an hour on.
        #expect(WidgetSnapshot.forecastDates(from: Fixtures.date(22, 11), calendar: Fixtures.calendar)[1] == Fixtures.date(22, 12))
    }

    @Test func forecastCountsWhatComesDueHourByHour() {
        let now = Fixtures.date(22, 10, 20)
        let dates = WidgetSnapshot.forecastDates(from: now, calendar: Fixtures.calendar)
        let counts = WidgetSnapshot.dueCounts(of: [Fixtures.deck(now: now)], at: dates, calendar: Fixtures.studyCalendar)
        // 3 reviews and 4 new cards now; the learning card from 11:30, so at 12:00; the two
        // reviews from 15:30, so at 16:00. The far and the suspended card never.
        #expect(Array(counts.prefix(7)) == [7, 7, 8, 8, 8, 8, 10])
        // The plan of the 22nd that is still open when the study day turns at 04:00 is backlog on
        // the 23rd: the five reviews ask a seventh of themselves, one, beside the learning card
        // and the four new cards.
        for (date, count) in zip(dates, counts).dropFirst(6) {
            #expect(count == (date < Fixtures.date(23, 4) ? 10 : 6), "\(date)")
        }
        #expect(counts.count == dates.count)
    }

    @Test func snapshotAddsUpTheDecks() {
        let now = Fixtures.date(22, 10, 20)
        let dates = Array(WidgetSnapshot.forecastDates(from: now, calendar: Fixtures.calendar).prefix(3))
        let snapshot = WidgetSnapshot(
            now: now, progress: Fixtures.progress(done: 12, goal: 20, streak: 7), dates: dates, dueByDeck: [[7, 7, 8], [1, 2, 3]], nextReminder: nil)
        #expect(snapshot.due.map(\.count) == [8, 9, 11])
        #expect(snapshot.due.map(\.date) == dates)
        #expect(snapshot.done == 12 && snapshot.goal == 20 && snapshot.streakDays == 7 && !snapshot.isGoalMet)
    }

    /// The forecast counts cards and not their kinds: the snapshot keeps the one price of the cards left now.
    @Test func theSnapshotKeepsTheOnePriceOfTheCardsLeftWhenItWasMade() {
        let now = Fixtures.date(22, 10, 20)
        let dates = Array(WidgetSnapshot.forecastDates(from: now, calendar: Fixtures.calendar).prefix(3))
        func snapshot(cardsLeft: Int, newCardsLeft: Int, pace: Pace = Pace(newCard: 30, otherCard: 12.5)) -> WidgetSnapshot {
            WidgetSnapshot(
                now: now, progress: Fixtures.progress(done: 12, goal: 20, streak: 7, cardsLeft: cardsLeft, newCardsLeft: newCardsLeft, pace: pace),
                dates: dates, dueByDeck: [[cardsLeft, cardsLeft, cardsLeft / 2]], nextReminder: nil)
        }
        // 3 new cards at 30 s and 5 others at 12.5 s: 152.5 s over 8 cards.
        #expect(snapshot(cardsLeft: 8, newCardsLeft: 3).secondsPerCard == 152.5 / 8)
        #expect(snapshot(cardsLeft: 8, newCardsLeft: 0).secondsPerCard == 12.5)
        #expect(snapshot(cardsLeft: 8, newCardsLeft: 8).secondsPerCard == 30)
        // Nothing left: the price of the others.
        #expect(snapshot(cardsLeft: 0, newCardsLeft: 0).secondsPerCard == 12.5)
        // The widget's minutes for the cards due now are the app's for the cards left: 152.5 s, 3 minutes.
        let state = snapshot(cardsLeft: 8, newCardsLeft: 3).state(at: now, calendar: Fixtures.studyCalendar)
        #expect(state.minutesLeft == DailyGoal.minutesLeft(newCards: 3, otherCards: 5, pace: Pace(newCard: 30, otherCard: 12.5)))
        #expect(state.minutesLeft == 3)
        // 26 new and 12 other cards at 30 s and 10 s take 900 s, 15 minutes exactly, in the widget as in the app.
        let exact = snapshot(cardsLeft: 38, newCardsLeft: 26, pace: Pace()).state(at: now, calendar: Fixtures.studyCalendar)
        #expect(exact.minutesLeft == 15)
    }

    /// The minutes follow the cards due at each hour of the forecast, priced by the one price of the snapshot.
    @Test func theMinutesLeftFollowTheDueCountOfTheMoment() {
        let snapshot = Fixtures.snapshot(now: Fixtures.date(22, 10, 20), done: 12, streak: 7, isGoalMet: false, secondsPerCard: 10) {
            $0 < Fixtures.date(22, 12) ? 42 : $0 < Fixtures.date(22, 16) ? 100 : 0
        }
        let state = { snapshot.state(at: $0, calendar: Fixtures.studyCalendar) }
        #expect(state(Fixtures.date(22, 10, 20)).minutesLeft == 7)
        #expect(state(Fixtures.date(22, 12)).minutesLeft == 17)
        // Nothing due: nothing to say.
        #expect(state(Fixtures.date(22, 16)).minutesLeft == nil)
        // Five cards at ten seconds: under a minute.
        let few = Fixtures.snapshot(now: Fixtures.date(22, 10, 20), done: 12, streak: 7, isGoalMet: false, secondsPerCard: 10) { _ in 5 }
        #expect(few.state(at: Fixtures.date(22, 11), calendar: Fixtures.studyCalendar).minutesLeft == 0)
        // The timeline carries the price into the next study day.
        #expect(snapshot.timeline(from: Fixtures.date(22, 10, 20), calendar: Fixtures.studyCalendar).allSatisfy { $0.secondsPerCard == 10 })
    }

    @Test func theTimeLeftReadsAsMinutesOrUnderOne() {
        #expect(Format.timeLeft(minutes: 7) == "≈ 7 min")
        #expect(Format.timeLeft(minutes: 120) == "≈ 120 min")
        #expect(Format.timeLeft(minutes: 0) == "< 1 min")
    }

    @Test func syncMakesTheSnapshotFromOpenAndSavedDecks() throws {
        let now = Fixtures.date(22, 10, 20)
        let deck = Fixtures.deck(now: now)
        let inputs = WidgetSync.Inputs(
            progress: Fixtures.progress(done: 20, goal: 20, streak: 3), decks: [.open(deck, Fixtures.studyCalendar)],
            nextReminder: Fixtures.date(23, 9))
        let snapshot = WidgetSync.snapshot(from: inputs, at: now, calendar: Fixtures.calendar)
        #expect(snapshot.date == now)
        #expect(snapshot.isGoalMet && snapshot.laps == 1)
        #expect(snapshot.nextReminder == Fixtures.date(23, 9))
        #expect(Array(snapshot.due.map(\.count).prefix(7)) == [7, 7, 8, 8, 8, 8, 10])
        // A deck whose file is missing adds nothing.
        let withMissing = WidgetSync.Inputs(
            progress: inputs.progress, decks: [.open(deck, Fixtures.studyCalendar), .file(URL(filePath: "/nonexistent/Gone.mnemit"))], nextReminder: nil)
        #expect(WidgetSync.snapshot(from: withMissing, at: now, calendar: Fixtures.calendar).due == WidgetSync.snapshot(from: inputs, at: now, calendar: Fixtures.calendar).due)
    }

    // MARK: The widget's figures over time

    /// 22:30 on the 22nd: the goal is met, 20 of 20, a streak of 5, nothing due until the new
    /// study day brings 33 cards at 04:00.
    private var evening: WidgetSnapshot {
        Fixtures.snapshot(now: Fixtures.date(22, 22, 30), done: 20, streak: 5, isGoalMet: true, reminder: Fixtures.date(23, 9)) {
            $0 >= Fixtures.date(23, 4) ? 33 : 0
        }
    }

    @Test func theFiguresStayUntilTheStudyDayChanges() {
        let late = evening.state(at: Fixtures.date(22, 23, 59), calendar: Fixtures.studyCalendar)
        #expect(late.done == 20 && late.goal == 20 && late.isGoalMet && late.streakDays == 5 && late.due == 0)
        // Midnight is not the turn of the study day: until 04:00 the cards done still count for the 22nd.
        let night = evening.state(at: Fixtures.date(23, 3, 59), calendar: Fixtures.studyCalendar)
        #expect(night.done == 20 && night.isGoalMet && night.streakDays == 5)
        #expect(night.nextReminder == Fixtures.date(23, 9))
    }

    @Test func theNewStudyDayStartsAtZeroWithThePlanAsGoal() {
        let morning = evening.state(at: Fixtures.date(23, 4), calendar: Fixtures.studyCalendar)
        #expect(morning.done == 0)
        #expect(morning.goal == 33)
        #expect(!morning.isGoalMet)
        #expect(morning.due == 33)
        // The streak holds, today's goal still to meet.
        #expect(morning.streakDays == 5)
        #expect(morning.progress.ring.fraction == 0)
    }

    @Test func theGoalOfANewDayIsThePlanWhateverItsSize() {
        let small = Fixtures.snapshot(now: Fixtures.date(22, 22), done: 20, streak: 1, isGoalMet: true) { $0 >= Fixtures.date(23, 4) ? 5 : 0 }
        #expect(small.state(at: Fixtures.date(23, 5), calendar: Fixtures.studyCalendar).goal == 5)
        let big = Fixtures.snapshot(now: Fixtures.date(22, 22), done: 20, streak: 1, isGoalMet: true) { $0 >= Fixtures.date(23, 4) ? 180 : 0 }
        #expect(big.state(at: Fixtures.date(23, 5), calendar: Fixtures.studyCalendar).goal == 180)
    }

    @Test func aNewDayWithAnEmptyPlanIsMetAndCountsForTheStreak() {
        let none = Fixtures.snapshot(now: Fixtures.date(22, 22), done: 20, streak: 1, isGoalMet: true) { _ in 0 }
        let morning = none.state(at: Fixtures.date(23, 5), calendar: Fixtures.studyCalendar)
        #expect(morning.goal == 0)
        #expect(morning.isGoalMet)
        #expect(morning.streakDays == 2)
        // A day the snapshot didn't see could have asked something: the streak is not counted on.
        #expect(none.state(at: Fixtures.date(24, 5), calendar: Fixtures.studyCalendar).streakDays == 1)
        // A plan that is not empty is not met, and the streak waits for it.
        let some = Fixtures.snapshot(now: Fixtures.date(22, 22), done: 20, streak: 1, isGoalMet: true) { $0 >= Fixtures.date(23, 4) ? 3 : 0 }
        #expect(some.state(at: Fixtures.date(23, 5), calendar: Fixtures.studyCalendar).streakDays == 1)
        #expect(!some.state(at: Fixtures.date(23, 5), calendar: Fixtures.studyCalendar).isGoalMet)
    }

    @Test func aMissedDayKeepsTheStreakForOneDayAndThenEndsIt() {
        // The 22nd's goal was not met: the 23rd can still make it up, the 24th cannot.
        let unmet = Fixtures.snapshot(now: Fixtures.date(22, 20), done: 6, streak: 4, isGoalMet: false) { _ in 10 }
        #expect(unmet.state(at: Fixtures.date(22, 23), calendar: Fixtures.studyCalendar).streakDays == 4)
        #expect(unmet.state(at: Fixtures.date(23, 5), calendar: Fixtures.studyCalendar).streakDays == 4)
        #expect(unmet.state(at: Fixtures.date(24, 5), calendar: Fixtures.studyCalendar).streakDays == 0)
        // Met on the 22nd, nothing on the 23rd: the 24th still holds it, the 25th does not.
        let met = Fixtures.snapshot(now: Fixtures.date(22, 20), done: 20, streak: 4, isGoalMet: true) { _ in 10 }
        #expect(met.state(at: Fixtures.date(23, 5), calendar: Fixtures.studyCalendar).streakDays == 4)
        #expect(met.state(at: Fixtures.date(24, 5), calendar: Fixtures.studyCalendar).streakDays == 4)
        #expect(met.state(at: Fixtures.date(25, 5), calendar: Fixtures.studyCalendar).streakDays == 0)
    }

    @Test func theTimelineHasAnEntryWhereThePictureChanges() {
        let now = Fixtures.date(22, 22, 30)
        let entries = evening.timeline(from: now, calendar: Fixtures.studyCalendar)
        #expect(entries.first?.date == now)
        #expect(entries.map(\.date) == entries.map(\.date).sorted())
        // Now; the start of the study day, where the cards done turn 0 and 33 cards come due; the
        // reminder, after which the line is gone. The hours between change nothing, and the
        // start of the day after, 04:00 on the 24th, looks like the 23rd.
        #expect(entries.map(\.date) == [now, Fixtures.date(23, 4), Fixtures.date(23, 9)])
        #expect(entries.map(\.due) == [0, 33, 33])
        #expect(entries.map(\.done) == [20, 0, 0])
        #expect(entries.map(\.nextReminder) == [Fixtures.date(23, 9), Fixtures.date(23, 9), nil])
        #expect(entries.allSatisfy { $0.date >= now })
    }

    @Test func theTimelineFollowsTheForecastHours() {
        let now = Fixtures.date(22, 10, 20)
        let deck = Fixtures.deck(now: now)
        let dates = WidgetSnapshot.forecastDates(from: now, calendar: Fixtures.calendar)
        let counts = WidgetSnapshot.dueCounts(of: [deck], at: dates, calendar: Fixtures.studyCalendar)
        let snapshot = WidgetSnapshot(
            now: now, progress: Fixtures.progress(done: 12, goal: 20, streak: 7), dates: dates, dueByDeck: [counts], nextReminder: nil)
        let entries = snapshot.timeline(from: now, calendar: Fixtures.studyCalendar)
        // Now (7 in the plan), 12:00 (8), 16:00 (10), and the next study day, which resets the
        // cards done and makes the five review cards of the 22nd backlog: a seventh of it, one card.
        #expect(entries.map(\.due).prefix(3) == [7, 8, 10])
        #expect(entries.prefix(3).map(\.date) == [now, Fixtures.date(22, 12), Fixtures.date(22, 16)])
        #expect(entries.prefix(3).allSatisfy { $0.done == 12 })
        let next = entries.first { $0.date == Fixtures.date(23, 4) }
        #expect(next?.done == 0)
        #expect(next?.due == 6)
        #expect(next?.goal == 6)
        #expect(entries.count <= 5)
    }

    @Test func anOldSnapshotStillGivesAnEntryAtTheNextStudyDay() {
        let snapshot = Fixtures.snapshot(now: Fixtures.date(22, 22), done: 20, streak: 5, isGoalMet: true) { _ in 12 }
        // Three days later: the forecast is used up, its last count stands, the streak is over.
        let now = Fixtures.date(25, 9)
        let entries = snapshot.timeline(from: now, calendar: Fixtures.studyCalendar)
        #expect(entries.first?.streakDays == 0)
        #expect(entries.first?.due == 12)
        #expect(entries.first?.done == 0)
    }

    // MARK: Deep link

    @Test func theWidgetLinkIsStudy() {
        #expect(WidgetLink.isStudy(WidgetLink.study))
        #expect(WidgetLink.study.absoluteString == "mnemit://study")
        #expect(WidgetLink.isStudy(URL(string: "mnemit://study")!))
        #expect(!WidgetLink.isStudy(URL(string: "mnemit://other")!))
        #expect(!WidgetLink.isStudy(URL(string: "https://study")!))
        #expect(!WidgetLink.isStudy(URL(filePath: "/Decks/study.mnemit")))
    }

    // MARK: Keychain

    @Test func theKeychainGroupTakesTheTeamOfTheBuild() {
        #expect(KeychainSnapshotStore.group(prefixedLike: "ABCDE12345.com.euf.mnemit.ios") == "ABCDE12345.com.euf.mnemit.shared")
        #expect(KeychainSnapshotStore.group(prefixedLike: "ABCDE12345.com.euf.mnemit.shared") == "ABCDE12345.com.euf.mnemit.shared")
        #expect(KeychainSnapshotStore.group(prefixedLike: "com.euf.mnemit.shared") == "com.euf.mnemit.shared")
        #expect(KeychainSnapshotStore.group(prefixedLike: "nogroup") == nil)
    }

    @Test func theKeychainKeepsTheSnapshot() throws {
        let store = KeychainSnapshotStore(service: "com.euf.mnemit.tests.\(UUID().uuidString)")
        defer { store.remove() }
        #expect(store.read() == nil)
        let first = Fixtures.snapshot(now: Fixtures.date(22, 10, 20), done: 12, streak: 7, isGoalMet: false) { _ in 42 }
        try #require(store.write(first), "the keychain of this test host refuses the shared access group")
        #expect(store.read() == first)
        // Written over, not added.
        let second = Fixtures.snapshot(now: Fixtures.date(22, 11), done: 13, streak: 7, isGoalMet: false) { _ in 41 }
        #expect(store.write(second))
        #expect(store.read() == second)
        store.remove()
        #expect(store.read() == nil)
    }
}
