import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// The store of the medals this device has celebrated: the first read marks the past, today's stays pending,
/// and what is marked stays marked.
@MainActor
struct CelebratedMedalsTests {
    let past = Achievement(kind: .streak(days: 3), day: 9)
    let today = Achievement(kind: .firstRing, day: 10)

    @Test func theFirstReadMarksThePastAndLeavesToday() {
        let store = CelebratedMedals(defaults: nil)
        #expect(store.pending([past, today], today: 10) == [today])
        // Earned on the Mac a day later: pending, and so is today's that was never celebrated; the past is not read again.
        let later = Achievement(kind: .comeback, day: 11)
        #expect(store.pending([past, today, later], today: 12) == [today, later])
    }

    @Test func aMarkedMedalStaysMarked() {
        let store = CelebratedMedals(defaults: nil)
        _ = store.pending([past, today], today: 10)
        store.mark([today])
        #expect(store.pending([past, today], today: 10).isEmpty)
    }

    /// The rest marks today's medals even when it is the first thing to read the store.
    @Test func theRestMarksTodayAfterReadingThePast() {
        let store = CelebratedMedals(defaults: nil)
        store.markToday(in: [past, today], today: 10)
        #expect(store.pending([past, today], today: 10).isEmpty)
    }

    @Test func theKeysAreKeptInTheDefaults() throws {
        let name = "CelebratedMedalsTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = CelebratedMedals(defaults: defaults)
        #expect(store.pending([past, today], today: 10) == [today])
        store.mark([today])
        #expect(defaults.stringArray(forKey: CelebratedMedals.defaultsKey) == ["firstRing@10", "streak-3@9"])
        // A new store reads them, and doesn't read the past again.
        let again = CelebratedMedals(defaults: defaults)
        #expect(again.pending([past, today, Achievement(kind: .laps(2), day: 5)], today: 10) == [Achievement(kind: .laps(2), day: 5)])
    }
}
