import Foundation
import Testing

@testable import VocabCore

/// The progress ledger (`DayLedger`): its records, the merge, the file, and `DailyProgress.evaluate` reading the days
/// before today from it.
struct DayLedgerTests {
    func record(
        _ day: Int, reviews: Int = 12, done: Int = 6, goal: Int = 8, keepAt: Int = 4, time: Double = 150, reason: DailyGoal.SizeReason = .start,
        worked: Double = 61.5, filled: Bool = true, words: Int = 3
    ) -> LedgerDay {
        LedgerDay(
            day: day, reviews: reviews, done: done, goal: goal, keepAt: keepAt, time: time, reason: reason, worked: worked, filled: filled,
            wordsLearned: words)
    }

    func ledger(_ days: LedgerDay...) -> DayLedger {
        DayLedger(days: Dictionary(days.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first }))
    }

    // MARK: A record

    @Test func aRecordIsKeptAndClosedBySeeingItsMarks() {
        let open = record(5, done: 3, goal: 8, keepAt: 4)
        #expect(!open.kept && !open.closed)
        #expect(record(5, done: 4, goal: 8, keepAt: 4).kept)
        #expect(record(5, done: 8, goal: 8, keepAt: 4).closed)
        // An empty plan keeps the streak and closes the ring.
        let empty = record(5, reviews: 0, done: 0, goal: 0, keepAt: 0)
        #expect(empty.kept && empty.closed)
        #expect(open.ringDay == DailyGoal.RingDay(day: 5, time: 150, reason: .start, worked: 61.5, closed: false, studied: true, filled: true))
    }

    @Test func aRecordOnlyRisesAndItsSizeNeverChanges() {
        let open = record(5, reviews: 10, done: 3, goal: 8, keepAt: 4, worked: 40, words: 2)
        // The logs say less: nothing falls.
        #expect(open.raised(reviews: 2, done: 0, worked: 0, wordsLearned: 0) == open)
        // The logs say more: each count takes the larger, and the marks follow.
        let kept = open.raised(reviews: 14, done: 5, worked: 70, wordsLearned: 4)
        #expect(kept.reviews == 14 && kept.done == 5 && kept.worked == 70 && kept.wordsLearned == 4)
        #expect(kept.kept && !kept.closed)
        let closed = kept.raised(reviews: 0, done: 9, worked: 10, wordsLearned: 1)
        #expect(closed.done == 9 && closed.closed && closed.kept && closed.worked == 70 && closed.wordsLearned == 4)
        #expect(closed.goal == 8 && closed.keepAt == 4 && closed.time == 150 && closed.reason == .start && closed.filled)
        // The work moves with the cards done: a price that changed since, with no more cards, leaves it.
        #expect(open.raised(reviews: 0, done: 3, worked: 90, wordsLearned: 0) == open)
        #expect(open.raised(reviews: 0, done: 4, worked: 20, wordsLearned: 0).worked == 40)
    }

    // MARK: The merge

    @Test func ofADayInBothTheLargerDoneWinsThenReviewsWordsAndGoalThenTheSmallerLine() {
        let base = record(5, reviews: 10, done: 5, goal: 8, words: 3)
        let pairs: [(loser: LedgerDay, winner: LedgerDay)] = [
            (record(5, reviews: 99, done: 4, goal: 99, words: 99), base),
            (record(5, reviews: 9, done: 5, goal: 99, words: 99), base),
            (record(5, reviews: 10, done: 5, goal: 99, words: 2), base),
            (record(5, reviews: 10, done: 5, goal: 7, words: 3), base),
        ]
        for (loser, winner) in pairs {
            #expect(ledger(loser).merging(ledger(winner)) == ledger(winner))
            #expect(ledger(winner).merging(ledger(loser)) == ledger(winner))
        }
        // Alike in all of them: the smaller encoded line, whichever side it comes from.
        let slow = record(5, time: 180)
        let quick = record(5, time: 150)
        let smaller = String(decoding: ledger(slow).encoded(), as: UTF8.self) < String(decoding: ledger(quick).encoded(), as: UTF8.self) ? slow : quick
        #expect(ledger(slow).merging(ledger(quick)) == ledger(smaller))
        #expect(ledger(quick).merging(ledger(slow)) == ledger(smaller))
    }

    @Test func theMergeIsCommutativeAndIdempotentAndHoldsTheDaysOfBoth() {
        let a = ledger(record(1), record(2, done: 9), record(3, reviews: 50))
        let b = ledger(record(2, reviews: 99, done: 7), record(3, reviews: 60, time: 170), record(4))
        let merged = a.merging(b)
        #expect(merged == b.merging(a))
        #expect(merged.merging(merged) == merged)
        #expect(merged.merging(a) == merged)
        #expect(merged.merging(b) == merged)
        #expect(a.merging(a) == a)
        #expect(a.merging(DayLedger()) == a && DayLedger().merging(a) == a)
        #expect(merged.days.keys.sorted() == [1, 2, 3, 4])
        #expect(merged.days[2]?.done == 9 && merged.days[3]?.reviews == 60)
    }

    @Test func updatingTakesTheRaisedRecordsAndNeverLowersADay() {
        let old = ledger(record(1, done: 3), record(2, done: 6))
        let raised = old.updating([record(2, done: 6).raised(reviews: 0, done: 8, worked: 0, wordsLearned: 0), record(3)])
        #expect(raised.days.keys.sorted() == [1, 2, 3] && raised.days[2]?.done == 8)
        #expect(raised.updating([record(2, done: 5)]) == raised)
    }

    // MARK: The file

    @Test func theFileIsOneJsonLinePerDayOldestFirstWithTheDocumentedKeys() throws {
        let file = ledger(record(20_000, reason: .sustainedOvershoot), record(19_990, reviews: 0, done: 0, goal: 0, keepAt: 0)).encoded()
        let lines = String(decoding: file, as: UTF8.self).split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 3 && lines[2].isEmpty)
        let objects = try lines.prefix(2).map { try #require(JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any]) }
        #expect(objects[0]["day"] as? String == CivilDate(dayNumber: 19_990).isoString)
        #expect(objects[1]["day"] as? String == CivilDate(dayNumber: 20_000).isoString)
        #expect(Set(objects[1].keys) == ["day", "reviews", "done", "goal", "keep", "kept", "closed", "time", "reason", "worked", "filled", "words"])
        #expect(objects[1]["reason"] as? String == "sustainedOvershoot" && objects[1]["keep"] as? Int == 4 && objects[1]["words"] as? Int == 3)
        #expect(DayLedger().encoded().isEmpty)
    }

    @Test func aLedgerSurvivesTheFile() {
        let reasons: [DailyGoal.SizeReason] = [.start, .ringClosed, .closedInARow, .ringOpen, .smallPlan, .sustainedOvershoot]
        let days = reasons.enumerated().map { record(20_000 + $0.offset, done: $0.offset, time: 172.5 + Double($0.offset), reason: $0.element, filled: $0.offset.isMultiple(of: 2)) }
        let all = DayLedger(days: Dictionary(uniqueKeysWithValues: days.map { ($0.day, $0) }))
        #expect(DayLedger.decode(all.encoded()) == all)
        // Seconds are kept to a tenth.
        let rough = ledger(record(20_000, time: 198.375, worked: 61.54))
        let read = DayLedger.decode(rough.encoded()).days[20_000]
        #expect(read?.time == 198.4 && read?.worked == 61.5)
        #expect(DayLedger.decode(DayLedger.decode(rough.encoded()).encoded()) == DayLedger.decode(rough.encoded()))
    }

    @Test func aDamagedLineCostsItsDayOnly() {
        let good = ledger(record(20_000), record(20_002, done: 9))
        var lines = String(decoding: good.encoded(), as: UTF8.self).split(separator: "\n").map(String.init)
        lines.insert("{\"day\":\"2026-10-01\",\"reviews\":", at: 1)  // cut off
        lines.insert("not json at all", at: 0)
        lines.insert("{\"day\":\"yesterday\",\"reviews\":1,\"done\":1,\"goal\":1,\"keep\":1,\"kept\":true,\"closed\":true,\"time\":150,\"reason\":\"start\",\"worked\":1,\"filled\":true,\"words\":0}", at: 2)
        lines.insert("{\"day\":\"2026-10-01\"}", at: 3)  // a key missing
        lines.append("")
        let read = DayLedger.decode(Data((lines.joined(separator: "\n") + "\n\n").utf8))
        #expect(read == good)
        #expect(DayLedger.decode(Data()) == DayLedger())
        #expect(DayLedger.decode(Data([0xFF, 0xFE, 0x0A, 0x00])) == DayLedger())
    }

    @Test func anUnknownReasonReadsAsRingOpenAndTheSameDayTwiceIsMerged() {
        let line = String(decoding: ledger(record(20_000, reason: .smallPlan)).encoded(), as: UTF8.self).replacingOccurrences(of: "smallPlan", with: "somethingNew")
        #expect(DayLedger.decode(Data(line.utf8)).days[20_000]?.reason == .ringOpen)
        let twice = String(decoding: ledger(record(20_000, done: 3)).encoded(), as: UTF8.self) + String(decoding: ledger(record(20_000, done: 5)).encoded(), as: UTF8.self)
        #expect(DayLedger.decode(Data(twice.utf8)).days[20_000]?.done == 5)
    }
}

/// `DailyProgress.evaluate` over a ledger.
extension DailyProgressTests {
    /// What the past leaves in a progress: the days before today as records (each with the streak it ended at) and as the
    /// size rule reads them, the week before today, the medals and the words learned at the day's start.
    func past(_ progress: DailyProgress) -> [AnyHashable] {
        [
            Array(progress.records.dropLast()), Array(progress.ringDays.dropLast()), Array(progress.week.dropLast()), progress.achievements,
            progress.learned.wordsAtDayStart,
        ]
    }

    func evaluate(_ decks: [Deck], at date: Date? = nil, ledger: DayLedger, cache: DailyProgressCache? = nil, planRuleStart: Int = .min) -> DailyProgress {
        DailyProgress.evaluate(
            decks.map { DeckActivity(deck: $0, calendar: calendar) }, at: date ?? now, calendar: calendar, planRuleStart: planRuleStart, ledger: ledger, cache: cache)
    }

    /// Two decks studied on nine days, the seventh of them missed, and the morning of today: the ledger of the first run.
    func fixture() throws -> (a: Deck, b: Deck, early: Date, first: DailyProgress, ledger: DayLedger) {
        var a = try Deck(learningOptions: options(), cards: (0..<300).map { fresh("a\($0)") })
        var b = try Deck(learningOptions: options(), cards: (0..<300).map { fresh("b\($0)") })
        for offset in 0..<9 where offset != 6 {
            study(&a, onDay: today - 9 + offset)
            study(&b, onDay: today - 9 + offset)
        }
        let early = at(day: today, hour: 5)
        let first = evaluate([a, b], at: early)
        return (a, b, early, first, DayLedger().updating(first.ledgerUpdates))
    }

    @Test func theFirstRunFillsTheLedgerWithEveryDayFromTheFirstStudyDayToYesterday() throws {
        let (a, b, early, first, ledger) = try fixture()
        let days = Array((today - 9)..<today)
        #expect(first.ledgerUpdates.map(\.day) == days)
        // A missed day has its record: its plan had cards and nothing was done.
        let missed = try #require(ledger.days[today - 3])
        #expect(missed.reviews == 0 && missed.done == 0 && missed.goal > 0 && !missed.kept && !missed.closed)
        // The records say what the progress said of those days.
        for (day, record) in zip(days, first.records) {
            let held = try #require(ledger.days[day])
            #expect(record.day == day && record.done == held.done && record.goal == held.goal && record.kept == held.kept && record.closed == held.closed)
            #expect(record.wordsLearned == held.wordsLearned)
        }
        #expect(ledger.days[today] == nil)
        // The ledger of the first run is the ledger of the second: nothing is new, the progress is the same.
        let second = evaluate([a, b], at: early, ledger: ledger)
        #expect(second.ledgerUpdates.isEmpty)
        var same = second
        same.ledgerUpdates = first.ledgerUpdates
        #expect(same == first)
        #expect(second.records == first.records && second.ringDays == first.ringDays && second.time == first.time)
        // The file keeps it, to a tenth of a second.
        let read = DayLedger.decode(ledger.encoded())
        #expect(Set(read.days.keys) == Set(ledger.days.keys))
        let third = evaluate([a, b], at: early, ledger: read)
        #expect(third.records == first.records && third.streak == first.streak && third.achievements == first.achievements)
    }

    @Test func anEmptyLedgerGivesWhatTheLogsAlwaysGave() throws {
        // The figures of this fixture as `evaluate` worked them out from the logs before the ledger existed.
        let (_, _, _, first, _) = try fixture()
        let rows = first.records.map { [$0.done, $0.goal, $0.streak, $0.wordsLearned, $0.kept ? 1 : 0, $0.closed ? 1 : 0] }
        #expect(
            rows == [
                [10, 5, 1, 10, 1, 1], [10, 5, 2, 20, 1, 1], [18, 46, 2, 28, 0, 0], [24, 26, 1, 42, 1, 0], [26, 28, 1, 60, 0, 0],
                [30, 67, 0, 76, 0, 0], [0, 69, 0, 76, 0, 0], [40, 77, 0, 82, 0, 0], [28, 60, 0, 110, 0, 0], [0, 63, 0, 110, 0, 0],
            ])
        #expect(first.time == 120 && first.ring == DailyRing(done: 0, goal: 63) && first.streak == Streak(days: 0, repairCards: nil))
        #expect(first.week == [Bool?](repeating: false, count: 7) && first.learned == WordsLearned(words: 110, wordsAtDayStart: 110))
        #expect(first.achievements.map { $0.day - today } == [-9, -9, -9, -8, -5, -1])
        #expect(first.ringDays.map(\.time) == [150, 150, 172.5, 133.6875, 120, 120, 120, 120, 120, 120])
    }

    @Test func pausingADeckDeletingADeckOrACardTakesNothingFromThePast() throws {
        let (a, b, early, first, ledger) = try fixture()
        let frozen = past(first)
        #expect(first.records.dropLast().contains { $0.done > 0 })
        var paused = b
        paused.learningOptions.isPaused = true
        var pausedBoth = a
        pausedBoth.learningOptions.isPaused = true
        var lessCards = a
        let victim = try #require(lessCards.cards.first { !$0.log.isEmpty })
        lessCards.cards.removeAll { $0.id == victim.id }
        let scenarios: [(String, [Deck])] = [
            ("a paused deck", [a, paused]), ("a deleted deck", [a]), ("every deck paused", [pausedBoth, paused]), ("no deck", []),
            ("a deleted card", [lessCards, b]),
        ]
        for (name, decks) in scenarios {
            let kept = evaluate(decks, at: early, ledger: ledger)
            #expect(past(kept) == frozen, Comment(rawValue: name))
            #expect(kept.ledgerUpdates.isEmpty, Comment(rawValue: name))
            #expect(kept.learned.words == first.learned.words, Comment(rawValue: name))
            // Today is the logs': what is left of its plan keeps it open, as it was, in every scenario that has a plan.
            if !decks.allSatisfy(\.learningOptions.isPaused) && !decks.isEmpty {
                #expect(kept.streak == first.streak && kept.week == first.week, Comment(rawValue: name))
            }
            // Without the ledger the same change does rewrite the days: the ledger is what holds them.
            if name != "a deleted card" {
                #expect(past(evaluate(decks, at: early)) != frozen, Comment(rawValue: name))
            }
        }
        // The missed day stays missed when every deck is paused: an empty plan now is no kept day.
        let none = evaluate([pausedBoth, paused], at: early, ledger: ledger)
        #expect(none.records.first { $0.day == today - 3 }?.kept == false)
    }

    @Test func theWordsLearnedOfPastDaysSurviveADeletedDeck() throws {
        // Cards that left learning on past days: a review card with a complete log is a word learned on its first Good ones.
        var deck = try Deck(learningOptions: options(), cards: (0..<12).map { fresh("w\($0)") })
        for offset in 0..<4 { study(&deck, onDay: today - 4 + offset, until: { done, _ in done >= 5 }) }
        let early = at(day: today, hour: 5)
        let first = evaluate([deck], at: early)
        let ledger = DayLedger().updating(first.ledgerUpdates)
        let held = first.records.map(\.wordsLearned)
        #expect(held == held.sorted(), "the words learned never fall from a day to the next")
        let without = evaluate([], at: early, ledger: ledger)
        #expect(without.records.dropLast().map(\.wordsLearned) == held.dropLast())
        #expect(without.learned.wordsAtDayStart == held[held.count - 2])
        #expect(without.learned.words == without.learned.wordsAtDayStart)
        #expect(without.records.last?.wordsLearned == held[held.count - 2])
    }

    @Test func aDayFrozenOpenRisesToClosedWhenLateReviewsOfItArriveAndNeverFalls() throws {
        let (a, b, early, _, ledger) = try fixture()
        let day = today - 3
        let open = try #require(ledger.days[day])
        #expect(!open.closed && open.done == 0)
        // Other devices' logs of that day arrive: more cards than the day asked.
        let devices = try (0..<20).map { number -> Deck in
            var deck = try Deck(learningOptions: options(), cards: (0..<10).map { fresh("c\(number)-\($0)") })
            study(&deck, onDay: day)
            return deck
        }
        let late = evaluate([a, b] + devices, at: early, ledger: ledger)
        let raised = try #require(late.ledgerUpdates.first { $0.day == day })
        #expect(raised.done >= open.goal && raised.closed && raised.kept && raised.reviews > 0 && raised.worked > 0)
        #expect(raised.goal == open.goal && raised.time == open.time && raised.keepAt == open.keepAt && raised.reason == open.reason)
        #expect(late.records.first { $0.day == day }?.closed == true)
        // The words those logs taught rise the days after it too, and nothing else of them moves.
        for update in late.ledgerUpdates where update.day != day {
            let old = try #require(ledger.days[update.day])
            #expect(update.day > day && update.wordsLearned > old.wordsLearned)
            #expect(update == old.raised(reviews: 0, done: 0, worked: 0, wordsLearned: update.wordsLearned))
        }
        // Written, it stays; the logs saying less again (the devices gone) leave it.
        let written = ledger.updating(late.ledgerUpdates)
        let gone = evaluate([a, b], at: early, ledger: written)
        #expect(gone.ledgerUpdates.isEmpty)
        #expect(past(gone) == past(late))
        #expect(gone.records.first { $0.day == day }?.closed == true)
        #expect(written.days.filter { $0.key < day } == ledger.days.filter { $0.key < day })
    }

    @Test func todayStaysLiveAndNeverReachesTheLedger() throws {
        let made = try fixture()
        var a = made.a
        let b = made.b
        var ledger = made.ledger
        let morning = evaluate([a, b], at: at(day: today, hour: 6), ledger: ledger)
        #expect(morning.ring.done == 0 && !morning.ledgerUpdates.contains { $0.day >= today })
        study(&a, onDay: today, until: { done, _ in done >= 4 })
        let noon = evaluate([a, b], at: at(day: today, hour: 12), ledger: ledger)
        #expect(noon.ring.done >= 4 && noon.ring.fraction > morning.ring.fraction)
        #expect(noon.records.last?.done == noon.ring.done && noon.records.last?.day == today)
        #expect(noon.ledgerUpdates.isEmpty)
        // The ring is today's alone: the same grade moves it as it does without a ledger.
        #expect(noon.ring == evaluate([a, b], at: at(day: today, hour: 12)).ring)
        // Tomorrow, today is the past: it is in the updates, with what it ended at.
        ledger = ledger.updating(noon.ledgerUpdates)
        let tomorrow = evaluate([a, b], at: at(day: today + 1, hour: 6), ledger: ledger)
        #expect(tomorrow.ledgerUpdates.map(\.day) == [today])
        #expect(tomorrow.ledgerUpdates.first?.done == noon.ring.done)
    }

    @Test func aNewLedgerNeverReusesTheStaleDaysOfTheCache() throws {
        let (a, b, early, first, ledger) = try fixture()
        let cache = DailyProgressCache()
        let history = DeckHistoryCache()
        // The same decks, the same day: only the ledger differs, and what it holds is what comes back.
        var lifted = ledger
        let day = today - 3
        lifted.days[day] = lifted.days[day]?.raised(reviews: 40, done: 40, worked: 300, wordsLearned: 0)
        for known in [DayLedger(), ledger, lifted, ledger, DayLedger()] {
            let cached = DailyProgress.evaluate(
                [DeckActivity(deck: a, calendar: calendar, historyCache: history), DeckActivity(deck: b, calendar: calendar)], at: early, calendar: calendar,
                planRuleStart: .min, ledger: known, cache: cache)
            #expect(cached == evaluate([a, b], at: early, ledger: known))
        }
        #expect(evaluate([a, b], at: early, ledger: lifted).records.first { $0.day == day }?.done == 40)
        #expect(evaluate([a, b], at: early, ledger: lifted).records != first.records)
    }

    @Test func theStreakReadsTheLedgersReviewsForPastDaysAndTheLogsForToday() throws {
        // Only the ledger knows the days: no deck is left, and the streak still runs through them.
        let (_, _, early, first, ledger) = try fixture()
        let alone = evaluate([], at: early, ledger: ledger)
        #expect(past(alone) == past(first))
        #expect(alone.records.count == first.records.count && alone.records.first?.day == today - 9)
        #expect(first.records.contains { $0.streak > 0 })
        // Today, with nothing planned, is kept, and the streak goes on through it.
        #expect(alone.streak.days == (first.records.dropLast().last?.streak ?? 0) + 1)
    }
}
