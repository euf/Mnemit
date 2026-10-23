import Foundation
import Testing

@testable import VocabCore

/// What evaluating the daily progress costs on a deck of a size that is worth a year of study:
/// 3,000 cards, 1,500 notes with a recognition and a production card, 400 study days.
struct DailyProgressPerformanceTests {
    let calendar = StudyCalendar.testing
    let days = 400
    let cards = 3000

    func year() throws -> (deck: Deck, now: Date) {
        try StudiedDeck.make(cards: cards, days: days, calendar: calendar)
    }

    /// Slow to build, so off unless `MNEMIT_PERF` is set: `MNEMIT_PERF=1 swift test --filter DailyProgressPerformanceTests`.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["MNEMIT_PERF"] != nil))
    func aYearOfStudyOnAThousandNotesIsEvaluatedInAReasonableTime() throws {
        let clock = ContinuousClock()
        var built: (deck: Deck, now: Date)?
        let buildTime = try clock.measure { built = try year() }
        var (deck, now) = try #require(built)
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
                + "time=\(String(describing: progress?.time)) goal=\(String(describing: progress?.ring.goal)) allowances=\(String(describing: progress?.newCardAllowances)) pace=\(String(describing: progress?.pace))")
        // A second evaluation finds the same: the time comes from the logs alone.
        let again = DailyProgress.evaluate([DeckActivity(deck: deck, calendar: calendar)], at: now, calendar: calendar)
        #expect(again == progress)

        // A grade in the open deck: the next evaluation, by an activity that shares the cache of the last, replays
        // today only. A fresh activity replays every day.
        let cache = DeckHistoryCache()
        let progressCache = DailyProgressCache()
        let firstTime = clock.measure {
            _ = DailyProgress.evaluate([DeckActivity(deck: deck, calendar: calendar, historyCache: cache)], at: now, calendar: calendar, cache: progressCache)
        }
        let scheduler = Scheduler(learningOptions: deck.learningOptions, calendar: calendar)
        var random = SeededRandom(seed: 9)
        var cachedTimes: [Duration] = []
        var replayedTimes: [Duration] = []
        for step in 0..<5 {
            now = now.addingTimeInterval(8)
            let index = step * 11
            deck.cards[index] = scheduler.review(deck.cards[index], grade: .good, at: now, mode: .revealed, duration: .seconds(6), using: &random)
            var cached: DailyProgress?
            var replayed: DailyProgress?
            cachedTimes.append(clock.measure { cached = DailyProgress.evaluate([DeckActivity(deck: deck, calendar: calendar, historyCache: cache)], at: now, calendar: calendar, cache: progressCache) })
            replayedTimes.append(clock.measure { replayed = DailyProgress.evaluate([DeckActivity(deck: deck, calendar: calendar)], at: now, calendar: calendar) })
            #expect(cached == replayed, "grade \(step)")
        }
        print("PERF first with cache=\(firstTime) replays=\(cache.replays) after a grade, cached=\(cachedTimes) replayed=\(replayedTimes)")
        #expect(cache.replays == 1)
    }
}
