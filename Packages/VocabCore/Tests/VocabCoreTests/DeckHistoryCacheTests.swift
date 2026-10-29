import Foundation
import Testing

@testable import VocabCore

/// The days before today are replayed once while the open deck changes (`DeckHistoryCache`), and what the
/// progress says is what a replay of all days says.
struct DeckHistoryCacheTests {
    let calendar = StudyCalendar.testing

    /// Everything a history says, in a form that compares: `DeckActivity.History` holds tuples.
    struct Summary: Equatable {
        struct Review: Equatable {
            var date: Date
            var isNew: Bool
            var duration: Duration?
            var isDone: Bool
        }

        struct Kept: Equatable {
            var card: Int
            var state: LearningState?
        }

        var days: [Int: [Review]]
        var newDone: Int
        var otherDone: Int
        var newDoneByDay: [Int: Int]
        var otherDoneByDay: [Int: Int]
        var statesAfter: [Int: [Kept]]
        var starts: [Int: DeckActivity.DayStart]
        var newQueueToday: DailyGoal.NewQueue

        init(_ history: DeckActivity.History) {
            days = history.paced.days.mapValues { $0.map { Review(date: $0.date, isNew: $0.isNew, duration: $0.duration, isDone: $0.isDone) } }
            newDone = history.paced.newDone
            otherDone = history.paced.otherDone
            newDoneByDay = history.paced.newDoneByDay
            otherDoneByDay = history.paced.otherDoneByDay
            statesAfter = history.paced.statesAfter.mapValues { $0.map { Kept(card: $0.card, state: $0.state) } }
            starts = history.starts
            newQueueToday = history.newQueueToday
        }
    }

    /// What the cached way and the way that replays every day say of `decks` at `now`, which must be one.
    func expectTheSame(_ decks: [Deck], caches: [DeckHistoryCache], progress: DailyProgressCache, at now: Date, _ comment: String) {
        let cached = decks.indices.map { DeckActivity(deck: decks[$0], calendar: calendar, historyCache: caches[$0]) }
        let replayed = decks.map { DeckActivity(deck: $0, calendar: calendar) }
        #expect(
            DailyProgress.evaluate(cached, at: now, calendar: calendar, cache: progress) == DailyProgress.evaluate(replayed, at: now, calendar: calendar),
            "progress \(comment)")
        // The first study day of all the decks, paused ones included, as `evaluate` asks for it.
        let first = min(cached.compactMap { $0.reviewsByDay.keys.min() }.min() ?? .max, calendar.dayNumber(for: now))
        for (cached, replayed) in zip(cached, replayed) {
            #expect(
                Summary(cached.history(from: first, at: now, calendar: calendar)) == Summary(replayed.history(from: first, at: now, calendar: calendar)),
                "history \(comment)")
        }
    }

    @Test func aGradeAndAnEditOfATextReplayOnlyToday() throws {
        var (deck, now) = try StudiedDeck.make(cards: 60, days: 30)
        let cache = DeckHistoryCache()
        let progressCache = DailyProgressCache()
        func evaluate() -> DailyProgress {
            DailyProgress.evaluate([DeckActivity(deck: deck, calendar: calendar, historyCache: cache)], at: now, calendar: calendar, cache: progressCache)
        }
        _ = evaluate()
        #expect(cache.replays == 1)

        let scheduler = Scheduler(learningOptions: deck.learningOptions, calendar: calendar)
        var random = SeededRandom(seed: 3)
        for step in 0..<4 {
            now = now.addingTimeInterval(10)
            let index = step * 7
            deck.cards[index] = scheduler.review(deck.cards[index], grade: .good, at: now, mode: .revealed, using: &random)
            _ = evaluate()
        }
        let id = deck.cards[5].id
        _ = deck.apply(try #require(DeckChange.editingText(of: id, to: CardText(question: "other", answer: "text", hint: "")!, in: deck)), at: now, calendar: calendar)
        _ = evaluate()
        #expect(cache.replays == 1)
    }

    @Test func whatTheDaysBeforeTodayReadChangesReplaysThem() throws {
        var (deck, now) = try StudiedDeck.make(cards: 60, days: 30)
        let cache = DeckHistoryCache()
        let progressCache = DailyProgressCache()
        func evaluate() {
            expectTheSame([deck], caches: [cache], progress: progressCache, at: now, "after \(cache.replays) replays")
        }
        evaluate()
        #expect(cache.replays == 1)

        let id = deck.cards[8].id
        _ = deck.apply(try #require(DeckChange.settingSuspended(true, of: [id], in: deck, at: now)), at: now, calendar: calendar)
        evaluate()
        #expect(cache.replays == 2)

        var options = deck.learningOptions
        options.newCardsPerSession = 4
        _ = deck.apply(try #require(DeckChange.changingLearningOptions(options, in: deck, calendar: calendar)), at: now, calendar: calendar)
        evaluate()
        #expect(cache.replays == 3)

        let added = Card(text: CardText(question: "new", answer: "card", hint: "")!, created: now)
        _ = deck.apply(try #require(DeckChange.adding([added], to: deck)), at: now, calendar: calendar)
        evaluate()
        #expect(cache.replays == 4)

        // The next study day is another today.
        now = now.addingTimeInterval(24 * 3600)
        evaluate()
        #expect(cache.replays == 5)
    }

    /// A card that can't be replayed from its log stays in the state it has on every day: a grade changes the
    /// days before today, too.
    @Test func aCardWhoseLogIsIncompleteReplaysAllDaysWhenItIsGraded() throws {
        var (deck, now) = try StudiedDeck.make(cards: 20, days: 20)
        let state = LearningState(phase: .review, stability: 30, difficulty: 5, lastReview: now.addingTimeInterval(-40 * 86400), due: now.addingTimeInterval(-3600), reviews: 4)
        deck.cards.append(Card(id: UUID(), question: "old", answer: "card", created: now.addingTimeInterval(-90 * 86400), learningState: state))
        let cache = DeckHistoryCache()
        let progressCache = DailyProgressCache()
        expectTheSame([deck], caches: [cache], progress: progressCache, at: now, "before")
        #expect(cache.replays == 1)

        let scheduler = Scheduler(learningOptions: deck.learningOptions, calendar: calendar)
        var random = SeededRandom(seed: 3)
        let index = deck.cards.count - 1
        now = now.addingTimeInterval(10)
        deck.cards[index] = scheduler.review(deck.cards[index], grade: .good, at: now, mode: .revealed, using: &random)
        expectTheSame([deck], caches: [cache], progress: progressCache, at: now, "after the grade")
        #expect(cache.replays == 2)
    }

    /// Grades and edits of every kind, a day passing now and then, over two decks that share a day: the progress
    /// of the cached way is that of a replay of every day after each step.
    @Test func whateverHappensToTheDecksTheCachedProgressIsTheReplayedOne() throws {
        var first = try StudiedDeck.make(cards: 50, days: 30)
        let second = try StudiedDeck.make(cards: 30, days: 12)
        var now = first.now
        // Cards without a complete log, as an import from an old app leaves them.
        let state = LearningState(phase: .review, stability: 20, difficulty: 5, lastReview: now.addingTimeInterval(-30 * 86400), due: now.addingTimeInterval(-3600), reviews: 3)
        for index in 0..<3 {
            first.deck.cards.append(Card(id: UUID(), question: "old\(index)", answer: "card", created: now.addingTimeInterval(-60 * 86400), learningState: state))
        }
        var decks = [first.deck, second.deck]
        let caches = [DeckHistoryCache(), DeckHistoryCache()]
        let progressCache = DailyProgressCache()
        var random = SeededRandom(seed: 17)
        var kinds: [String: Int] = [:]

        func pick(_ count: Int) -> Int { Int(random.next() % UInt64(count)) }

        expectTheSame(decks, caches: caches, progress: progressCache, at: now, "at the start")
        for step in 0..<150 {
            let dayBefore = calendar.dayNumber(for: now)
            let replaysBefore = caches.map(\.replays)
            var leavesThePast = false
            let which = pick(2)
            var deck = decks[which]
            let card = deck.cards[pick(deck.cards.count)]
            let roll = pick(100)
            let kind: String
            switch roll {
            case ..<45:
                kind = "grade"
                let due = deck.cards.indices.filter { deck.cards[$0].isDue(at: now) }
                if let index = due.isEmpty ? nil : due[pick(due.count)] {
                    leavesThePast = deck.cards[index].hasCompleteLog || deck.cards[index].isNew
                    let scheduler = Scheduler(learningOptions: deck.learningOptions, calendar: calendar)
                    var fuzz = SeededRandom(seed: UInt64(step))
                    let grades: [Grade] = [.good, .good, .good, .hard, .again, .easy]
                    now = now.addingTimeInterval(7)
                    deck.cards[index] = scheduler.review(deck.cards[index], grade: grades[pick(grades.count)], at: now, mode: .revealed, duration: .seconds(5), using: &fuzz)
                }
            case ..<55:
                kind = "text"
                leavesThePast = true
                if let change = DeckChange.editingText(of: card.id, to: CardText(question: "q\(step)", answer: "a\(step)", hint: "")!, in: deck) {
                    _ = deck.apply(change, at: now, calendar: calendar)
                }
            case ..<63:
                kind = "suspend"
                if let change = DeckChange.settingSuspended(!card.isSuspended, of: [card.id], in: deck, at: now) {
                    _ = deck.apply(change, at: now, calendar: calendar)
                }
            case ..<70:
                kind = "add"
                let note = pick(2) == 0 ? nil : "n\(pick(30))"
                let added = Card(text: CardText(question: "added\(step)", answer: "x", hint: "")!, note: note, kind: note == nil ? nil : (pick(2) == 0 ? .recognition : .production), created: now)
                if let change = DeckChange.adding([added], to: deck) { _ = deck.apply(change, at: now, calendar: calendar) }
            case ..<75:
                kind = "delete"
                if deck.cards.count > 20, let change = DeckChange.removing([card.id], from: deck) { _ = deck.apply(change, at: now, calendar: calendar) }
            case ..<80:
                kind = "options"
                var options = deck.learningOptions
                options.newCardsPerSession = [nil, 3, 12][pick(3)]
                options.isPaused = pick(4) == 0
                if let change = DeckChange.changingLearningOptions(options, in: deck, calendar: calendar) { _ = deck.apply(change, at: now, calendar: calendar) }
            case ..<85:
                kind = "note"
                if let change = DeckChange.settingNote("n\(pick(30))", kind: pick(2) == 0 ? .recognition : .production, of: card.id, in: deck) {
                    _ = deck.apply(change, at: now, calendar: calendar)
                }
            case ..<88:
                kind = "reset"
                if let change = DeckChange.resettingLearningState(of: [card.id], in: deck, at: now) { _ = deck.apply(change, at: now, calendar: calendar) }
            case ..<96:
                kind = "time"
                leavesThePast = true
                now = now.addingTimeInterval(Double(600 + pick(5400)))
            default:
                kind = "day"
                now = now.addingTimeInterval(Double(86400 + pick(40000)))
            }
            decks[which] = deck
            kinds[kind, default: 0] += 1
            expectTheSame(decks, caches: caches, progress: progressCache, at: now, "at step \(step), after \(kind)")
            // A grade of a card that can be replayed, an edit of a text and the time passing within the day
            // leave the days before today alone.
            if leavesThePast, calendar.dayNumber(for: now) == dayBefore {
                #expect(caches.map(\.replays) == replaysBefore, "replays at step \(step), after \(kind)")
            }
        }
        #expect(kinds["grade", default: 0] > 40)
    }
}
