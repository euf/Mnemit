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

    @Test func theHeaderSaysCardsTodayDonePausedOrNothing() {
        let tomorrow = now.addingTimeInterval(86_400)
        let some = HomeSnapshotTests.counts(new: 4, learning: 3, review: 7)
        let none = HomeSnapshotTests.counts(new: 0, learning: 0, review: 0, nextDue: tomorrow)

        #expect(DeckHeadline(counts: some, isPaused: false, hasCards: true, now: now) == DeckHeadline(text: "14 cards today", isDone: false))
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
        // Overdue says so, a card not studied yet is New.
        #expect(CardMemoryLine.text(of: sample.suspended, now: now) == "Young · due now")
        #expect(CardMemoryLine.text(of: sample.leech, now: now) == "Shaky · due now")
        #expect(CardMemoryLine.text(of: sample.newCard, now: now) == "New")
    }

    @Test func theDirectionsAreWordMeaningAndMeaningWord() {
        #expect(CardKind.recognition.title == "Word → Meaning")
        #expect(CardKind.production.title == "Meaning → Word")
    }

    // MARK: The calendar

    @Test func aRunIsTwoKeptDaysOrMoreInAWeekRow() {
        func runs(_ pattern: String) -> [ClosedRange<Int>] { WeeksGrid.runs(ofKept: pattern.map { $0 == "x" }) }
        #expect(runs("xx.xxx.") == [0...1, 3...5])
        #expect(runs("xxxxxxx") == [0...6])
        #expect(runs("x.x.x.x") == [])
        #expect(runs(".......") == [])
        #expect(runs("..xxxxx") == [2...6])
    }
}
