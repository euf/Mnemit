import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// The ring says which study day its figures are of, so a screen can hold them back once the day has turned.
@MainActor
struct RingDayTests {
    let calendar = StudyCalendar()

    @Test func figuresOfYesterdayAreStaleAndTodaysAreNot() {
        let now = Date()
        let today = calendar.dayNumber(for: now)
        #expect(DailyRingModel.isStale(day: today - 1, at: now))
        #expect(!DailyRingModel.isStale(day: today, at: now))
        #expect(!DailyRingModel.isStale(day: nil, at: now))
    }

    @Test func aRefreshRecordsTheDayItWasWorkedOutFor() async {
        let ring = DailyRingModel()
        #expect(ring.day == nil)
        await ring.refresh(documents: [], files: [], delay: .zero).value
        #expect(ring.day == calendar.dayNumber(for: Date()))
        #expect(!ring.isStale)
    }
}
