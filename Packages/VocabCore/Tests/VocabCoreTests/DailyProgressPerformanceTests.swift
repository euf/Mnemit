import Foundation
import Testing

@testable import VocabCore

/// What evaluating the daily progress costs on a deck of a size that is worth a year of study:
/// 3,000 cards, 1,500 notes with a recognition and a production card, 400 study days.
struct DailyProgressPerformanceTests {
    let calendar = StudyCalendar.testing
    let days = 400
    let cards = 3000

    /// A learner who studies the plan of 85 % of the days, grading Good, Hard or Again as a person does.
    func year() throws -> (deck: Deck, now: Date) {
        var options = LearningOptions()
        options.cardsPerSession = nil
        options.newCardsPerSession = 12
        options.newProductionPerSession = 6
        let end = calendar.start(ofDay: CivilDate(year: 2026, month: 10, day: 5).dayNumber)
        let firstDay = calendar.dayNumber(for: end) - days
        var deck = try Deck(
            learningOptions: options,
            cards: (0..<cards).map { index in
                Card(
                    text: CardText(question: "q\(index)", answer: "a\(index)", hint: "")!, note: "n\(index / 2)", kind: index.isMultiple(of: 2) ? .recognition : .production,
                    created: calendar.start(ofDay: firstDay - 1))
            })
        var random = SeededRandom(seed: 5)
        let scheduler = Scheduler(learningOptions: options, calendar: calendar)
        for day in firstDay..<(firstDay + days) {
            guard random.next() % 100 < 85 else { continue }
            let at = calendar.start(ofDay: day).addingTimeInterval(10 * 3600)
            var study = StudySession(deck: deck, at: at, calendar: calendar, random: SeededRandom(seed: UInt64(day)), reviewMode: .revealed)
            var clock = at
            var count = 0
            while let id = study.session.currentCardID, count < 400 {
                let roll = random.next() % 100
                let grade: Grade = roll < 82 ? .good : roll < 92 ? .hard : .again
                clock = clock.addingTimeInterval(8)
                let card = study.review(grade, of: deck.card(withID: id)!, with: options, at: clock, calendar: calendar, duration: .seconds(6))!
                deck.cards[deck.index(of: id)!] = card
                count += 1
            }
            _ = scheduler
        }
        return (deck, end.addingTimeInterval(14 * 3600))
    }

    /// Slow to build, so off unless `MNEMIT_PERF` is set: `MNEMIT_PERF=1 swift test --filter DailyProgressPerformanceTests`.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["MNEMIT_PERF"] != nil))
    func aYearOfStudyOnAThousandNotesIsEvaluatedInAReasonableTime() throws {
        let clock = ContinuousClock()
        var built: (deck: Deck, now: Date)?
        let buildTime = try clock.measure { built = try year() }
        let (deck, now) = try #require(built)
        let reviews = deck.cards.reduce(0) { $0 + $1.log.count }
        var progress: DailyProgress?
        let evaluateTime = clock.measure {
            progress = DailyProgress.evaluate([DeckActivity(deck: deck, calendar: calendar)], at: now, calendar: calendar)
        }
        let activityTime = clock.measure { _ = DeckActivity(deck: deck, calendar: calendar) }
        let activity = DeckActivity(deck: deck, calendar: calendar)
        let today = calendar.dayNumber(for: now)
        let first = activity.reviewsByDay.keys.min()!
        let replayTime = clock.measure { _ = activity.replayLog(from: first, through: today, calendar: calendar, keepsStates: true) }
        let historyTime = clock.measure { _ = activity.history(from: first, at: now, calendar: calendar) }
        print("PERF replay=\(replayTime) history(replay+days)=\(historyTime) days=\(today - first)")
        print(
            "PERF cards=\(deck.cards.count) reviews=\(reviews) build=\(buildTime) evaluate=\(evaluateTime) activity=\(activityTime) streak=\(String(describing: progress?.streak.days)) "
                + "capacity=\(String(describing: progress?.capacity)) goal=\(String(describing: progress?.ring.goal)) allowances=\(String(describing: progress?.newCardAllowances)) pace=\(String(describing: progress?.pace))")
        // A second evaluation finds the same: the capacity comes from the logs alone.
        let again = DailyProgress.evaluate([DeckActivity(deck: deck, calendar: calendar)], at: now, calendar: calendar)
        #expect(again == progress)
    }
}
