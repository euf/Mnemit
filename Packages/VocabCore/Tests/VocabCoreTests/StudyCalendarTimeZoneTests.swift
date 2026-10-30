import Foundation
import Testing

@testable import VocabCore

/// The study day follows the machine's time zone while the app stays open.
struct StudyCalendarTimeZoneTests {
    @Test func aCalendarMadeAfterTheZoneChangedFollowsIt() {
        let before = getenv("TZ").map { String(cString: $0) }
        defer {
            if let before { setenv("TZ", before, 1) } else { unsetenv("TZ") }
            tzset()
            NSTimeZone.resetSystemTimeZone()
        }
        setenv("TZ", "Pacific/Auckland", 1)
        tzset()
        #expect(StudyCalendar().timeZone.identifier == "Pacific/Auckland")
        setenv("TZ", "America/New_York", 1)
        tzset()
        let calendar = StudyCalendar()
        #expect(calendar.timeZone.identifier == "America/New_York")
        // 1970-01-02 02:00 UTC is the evening of 1 January in New York: day 0.
        #expect(calendar.dayNumber(for: Date(timeIntervalSince1970: 86400 + 2 * 3600)) == 0)
    }
}
