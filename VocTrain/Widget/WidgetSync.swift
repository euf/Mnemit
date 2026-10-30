import Foundation
import UIKit
import VocabCore
import WidgetKit

/// Keeps the snapshot of the widget up to date (`WidgetSnapshot`): writes it to the shared
/// store and tells WidgetKit to reload the timelines.
///
/// The screen asks for a write whenever the figures may have changed: after each grade, at
/// launch, when the decks change, when the reminder moves. Writes wait for a short quiet (a
/// run of grades is one write, and a card that speaks is let finish, `GreekSpeech.whenQuiet()`) and
/// happen off the main actor, as the forecast reads the decks again: the open deck as it is, the
/// others from their files, and the keychain answers slowly. The moment the app goes to the
/// background the write is made at once.
@MainActor
final class WidgetSync {
    /// What the snapshot is made from, as the screen has it when it asks.
    struct Inputs: Sendable {
        var progress: DailyProgress
        var decks: [Source]
        var nextReminder: Date?
    }

    /// A deck that counts towards the forecast: the open one is taken as it is in memory,
    /// as its file may not hold the last grades yet.
    enum Source: Sendable {
        /// The file of a deck and the new-card allowance of the deck for the day.
        case file(URL, allowance: Int? = nil)
        case open(Deck, StudyCalendar, allowance: Int? = nil)
    }

    private let store: SnapshotStore
    private let delay: Duration
    private let isEnabled: Bool
    private let reload: @MainActor () -> Void
    private var pending: Task<Void, Never>?
    private var lastWrite: Task<Void, Never>?

    /// - Parameters:
    ///   - isEnabled: A test run leaves the keychain and the widgets of the simulator alone.
    ///   - reload: Asks WidgetKit for new timelines.
    init(
        store: SnapshotStore = KeychainSnapshotStore(), delay: Duration = .seconds(2), isEnabled: Bool = !GreekSpeech.isUnderTest,
        reload: @escaping @MainActor () -> Void = { WidgetCenter.shared.reloadAllTimelines() }
    ) {
        self.store = store
        self.delay = delay
        self.isEnabled = isEnabled
        self.reload = reload
    }

    /// Writes after `delay`, unless another request comes first and replaces this one.
    func request(_ inputs: Inputs) {
        guard isEnabled else { return }
        pending?.cancel()
        pending = Task { [weak self, delay] in
            try? await Task.sleep(for: delay)
            await GreekSpeech.shared.whenQuiet()
            guard !Task.isCancelled else { return }
            await self?.write(inputs)
        }
    }

    /// Writes now, and drops the request that waits.
    func flush(_ inputs: Inputs) async {
        guard isEnabled else { return }
        pending?.cancel()
        pending = nil
        await write(inputs)
    }

    /// Like `flush(_:)`, for the moment the app goes to the background: iOS gets asked for the
    /// time to finish, as it suspends the app soon after.
    func flushBeforeSuspending(_ inputs: Inputs) {
        guard isEnabled else { return }
        let time = BackgroundTime()
        time.identifier = UIApplication.shared.beginBackgroundTask(withName: "Widget") { [time] in
            MainActor.assumeIsolated { time.end() }
        }
        Task {
            await flush(inputs)
            time.end()
        }
    }

    /// The write itself; waits for the one before it, so an older snapshot never lands on a
    /// newer one.
    private func write(_ inputs: Inputs) async {
        // No deck yet (or none read yet): the ring is empty and met, and the widget would say "All done for
        // today". It keeps what it has, a snapshot of earlier decks or its own placeholder.
        guard !inputs.decks.isEmpty else { return }
        let previous = lastWrite
        let run = Task { @MainActor in
            await previous?.value
            let now = Date()
            let isStored = await Task.detached(priority: .utility) { [store = self.store] in
                let snapshot = StallTrace.measure("widgetSnapshot") { Self.snapshot(from: inputs, at: now) }
                return StallTrace.measure("widgetStoreWrite") { store.write(snapshot) }
            }.value
            if isStored {
                reload()
            }
        }
        lastWrite = run
        await run.value
    }

    /// The snapshot of `inputs` at `now`: the due count across the decks at each hour of the
    /// next two days. A deck whose file can't be read, e.g. one iCloud Drive has not downloaded,
    /// adds nothing.
    nonisolated static func snapshot(from inputs: Inputs, at now: Date, calendar: Calendar = .current) -> WidgetSnapshot {
        let dates = WidgetSnapshot.forecastDates(from: now, calendar: calendar)
        let dueByDeck = inputs.decks.compactMap { source -> [Int]? in
            switch source {
            case let .open(deck, studyCalendar, allowance):
                // A paused deck asks nothing of the day.
                guard !deck.learningOptions.isPaused else { return nil }
                return WidgetSnapshot.dueCounts(of: [deck], at: dates, calendar: studyCalendar, newCardAllowance: allowance)
            case let .file(url, allowance):
                return KnownDeckCounts.counts(at: url, on: dates, allowance: allowance)?.map(\.total)
            }
        }
        return WidgetSnapshot(now: now, progress: inputs.progress, dates: dates, dueByDeck: dueByDeck, nextReminder: inputs.nextReminder)
    }
}
