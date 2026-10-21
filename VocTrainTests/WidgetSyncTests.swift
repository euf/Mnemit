import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// When the app writes the snapshot and asks WidgetKit to reload: after a quiet, once for a
/// run of requests, at once on a flush, never in a test run's own app.
@MainActor
struct WidgetSyncTests {
    typealias Fixtures = WidgetFixtures

    /// Counts the reloads; the sync asks on the main actor.
    final class Reloads {
        var count = 0
    }

    private func inputs(reviews: Int) -> WidgetSync.Inputs {
        WidgetSync.Inputs(
            progress: Fixtures.progress(reviews: reviews, goal: 20, streak: 3), decks: [.open(Fixtures.deck(), Fixtures.studyCalendar)], nextReminder: nil)
    }

    private func sync(_ store: FakeSnapshotStore, _ reloads: Reloads, isEnabled: Bool = true) -> WidgetSync {
        WidgetSync(store: store, delay: .milliseconds(60), isEnabled: isEnabled, reload: { reloads.count += 1 })
    }

    /// Waits until `condition` holds, at most two seconds.
    private func wait(until condition: () -> Bool) async throws {
        for _ in 0..<100 where !condition() {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test func aRunOfRequestsIsOneWriteWithTheLastFigures() async throws {
        let store = FakeSnapshotStore()
        let reloads = Reloads()
        let sync = sync(store, reloads)
        for reviews in 1...5 {
            sync.request(inputs(reviews: reviews))
            try await Task.sleep(for: .milliseconds(10))
        }
        try await wait { store.writes > 0 }
        // Time for a second write, if one were to come.
        try await Task.sleep(for: .milliseconds(250))
        #expect(store.writes == 1)
        #expect(reloads.count == 1)
        #expect(store.read()?.reviews == 5)
    }

    @Test func aFlushWritesAtOnceAndTakesTheWaitingRequestWithIt() async throws {
        let store = FakeSnapshotStore()
        let reloads = Reloads()
        let sync = sync(store, reloads)
        sync.request(inputs(reviews: 1))
        await sync.flush(inputs(reviews: 2))
        #expect(store.writes == 1)
        #expect(store.read()?.reviews == 2)
        #expect(reloads.count == 1)
        try await Task.sleep(for: .milliseconds(250))
        #expect(store.writes == 1)
    }

    @Test func noReloadIfTheStoreRefuses() async {
        let store = FakeSnapshotStore()
        store.succeeds = false
        let reloads = Reloads()
        await sync(store, reloads).flush(inputs(reviews: 1))
        #expect(store.writes == 0)
        #expect(reloads.count == 0)
    }

    @Test func aDisabledSyncLeavesTheStoreAlone() async throws {
        let store = FakeSnapshotStore()
        let reloads = Reloads()
        let sync = sync(store, reloads, isEnabled: false)
        sync.request(inputs(reviews: 1))
        await sync.flush(inputs(reviews: 2))
        try await Task.sleep(for: .milliseconds(250))
        #expect(store.writes == 0)
        #expect(reloads.count == 0)
    }

    /// The app that hosts the tests starts its own screen, which must not write to the
    /// keychain of the simulator or reload its widgets.
    @Test func theSyncOfAnAppUnderTestIsDisabledByDefault() async throws {
        let store = FakeSnapshotStore()
        let sync = WidgetSync(store: store, delay: .milliseconds(10), reload: { Issue.record("a test run reloaded the widgets") })
        sync.request(inputs(reviews: 1))
        await sync.flush(inputs(reviews: 2))
        try await Task.sleep(for: .milliseconds(100))
        #expect(store.writes == 0)
    }
}
