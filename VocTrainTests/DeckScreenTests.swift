import SwiftUI
import Testing
import UIKit

@testable import VocTrain
@testable import VocabCore

/// The deck screen's one-line header, its menus, a card's memory line and the calendar's streak runs.
@MainActor
struct DeckScreenTests {
    let now = HomeSnapshotTests.now

    // MARK: The header

    @Test func theHeaderSaysTheTimeAndAnkisCountsDonePausedOrNothing() {
        let tomorrow = now.addingTimeInterval(86_400)
        let some = HomeSnapshotTests.counts(new: 4, learning: 3, review: 7)
        let none = HomeSnapshotTests.counts(new: 0, learning: 0, review: 0, nextDue: tomorrow)

        // Anki's counts after the time; a count of 0 is left out. `due` is the studied cards due now.
        var counts = some
        counts.due = 5
        let pace = Pace(newCard: 30, otherCard: 15)
        #expect(DeckHeadline(counts: counts, pace: pace, isPaused: false, hasCards: true, now: now)?.text == "5\u{00A0}min · 5 due · 4 new · 3 learning")
        #expect(DeckHeadline(counts: counts, isPaused: false, hasCards: true, now: now)?.text == "5 due · 4 new · 3 learning", "no pace, no time")
        var quiet = HomeSnapshotTests.counts(new: 6, learning: 0, review: 0)
        quiet.due = 0
        #expect(DeckHeadline(counts: quiet, pace: pace, isPaused: false, hasCards: true, now: now)?.text == "3\u{00A0}min · 6 new")
        let done = DeckHeadline(counts: none, isPaused: false, hasCards: true, now: now)
        #expect(done?.text == "Done · next review \(Format.due(tomorrow, now: now))")
        #expect(done?.text.hasPrefix("Done · next review ") == true)
        #expect(done?.isDone == true)
        #expect(DeckHeadline(counts: HomeSnapshotTests.counts(new: 0, learning: 0, review: 0), isPaused: false, hasCards: true, now: now) == DeckHeadline(text: "Done", isDone: true))
        // A paused deck says so, whatever its plan holds.
        #expect(DeckHeadline(counts: some, isPaused: true, hasCards: true, now: now) == DeckHeadline(text: "Paused", isDone: false))
        // No cards, or the plan not read yet: nothing to say.
        #expect(DeckHeadline(counts: none, isPaused: false, hasCards: false, now: now) == nil)
        #expect(DeckHeadline(counts: nil, isPaused: false, hasCards: true, now: now) == nil)
    }

    // MARK: The menu

    /// The menu's two items start the two streams that the Mac's menu does (`Button { start(practice.entry) }`). A tap
    /// through the bar's menu could not be driven: SwiftUI hands UIKit no menu to walk, nor the buttons of a list to VoiceOver's tree.
    @Test func theTwoPracticesAreTheEntriesOfTheStreams() {
        #expect(DeckPractice.allCases.map(\.entry) == [.practiceNewest, .practiceMistakes])
    }

    // MARK: Card Detail

    @Test func aCardsMemoryIsOneLineWithItsStepAndNextReview() throws {
        let sample = try BrowserSnapshotTests().makeSample()
        let now = BrowserSnapshotTests().now
        let house = CardMemoryLine.text(of: sample.house, now: now)
        #expect(house == "Young · next review \(Format.due(sample.house.learningState!.due, now: now))")
        #expect(house.hasPrefix("Young · next review "))
        // Overdue says so, a suspended card is not "due now" (no session asks it), a card not studied yet is New.
        #expect(CardMemoryLine.text(of: sample.suspended, now: now) == "Young · suspended")
        #expect(CardMemoryLine.text(of: sample.leech, now: now) == "Shaky · due now")
        #expect(CardMemoryLine.text(of: sample.newCard, now: now) == "New")
    }

    @Test func theDirectionsAreWordMeaningAndMeaningWord() {
        #expect(CardKind.recognition.title == "Word → Meaning")
        #expect(CardKind.production.title == "Meaning → Word")
    }

    // MARK: The calendar

    @Test func aBandFollowsTheStreakAsItsCounterCountsItAcrossTheRows() {
        // A Monday: day 0 is a Thursday.
        let monday = 4 + 7 * 2900
        func day(_ offset: Int, kept: Bool, closed: Bool = false, streak: Int, saved: Bool = false) -> DayRecord {
            DayRecord(day: monday + offset, done: kept ? 10 : 1, goal: 8, kept: kept, closed: closed || kept, streak: streak, savedStreak: saved)
        }
        // Wednesday to Sunday kept, Monday kept, Tuesday missed and saved by Wednesday's closed ring, Thursday to Saturday
        // kept, today, Sunday, not kept yet: 11 days, as the counter says.
        let records = [
            day(2, kept: true, streak: 1), day(3, kept: true, streak: 2), day(4, kept: true, streak: 3), day(5, kept: true, streak: 4),
            day(6, kept: true, streak: 5), day(7, kept: true, streak: 6), day(8, kept: false, streak: 6),
            day(9, kept: true, closed: true, streak: 8, saved: true), day(10, kept: true, streak: 9), day(11, kept: true, streak: 10),
            day(12, kept: true, streak: 11), day(13, kept: false, streak: 11),
        ]
        let streak = WeeksGrid.streakDays(records)
        #expect(streak == Set((2...12).map { monday + $0 }))
        let rows = [Array(monday..<monday + 7), Array(monday + 7..<monday + 14)]
        #expect(WeeksGrid.bands(rows[0], streak: streak) == [WeeksGrid.Band(columns: 2...6, continuesAfter: true)])
        #expect(WeeksGrid.bands(rows[1], streak: streak) == [WeeksGrid.Band(columns: 0...5, continuesBefore: true)])

        // A streak of one day is its ring; a run that ends on Sunday is closed there when Monday breaks it.
        #expect(WeeksGrid.bands(rows[0], streak: [monday + 3]).isEmpty)
        #expect(WeeksGrid.bands(rows[0], streak: [monday + 5, monday + 6]) == [WeeksGrid.Band(columns: 5...6)])
        // A Monday alone in its row, after a streak that ran through Sunday, is the open end of that band.
        #expect(WeeksGrid.bands(rows[1], streak: [monday + 6, monday + 7]) == [WeeksGrid.Band(columns: 0...0, continuesBefore: true)])
    }
}
