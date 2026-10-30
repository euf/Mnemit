import Foundation

/// Saves a few seconds after every change of a deck, for `VersionMerger` (#252, #298),
/// so the other device gets reviews soon and conflicts become rare. The devices take
/// turns rather than being used at the same time, and iCloud Drive takes about a
/// minute to bring a version over, so waiting a few seconds for more changes costs
/// little. A save waits for a card that speaks to be through, see `GreekSpeech.whenQuiet()`.
///
/// A save that fails leaves the change unsaved: `onFailure` runs, and the save is tried again after `retryDelay`,
/// so a disk that is full for a minute loses no review.
@MainActor
final class SaveScheduler {
    /// The save scheduled after the latest change, or the one `flush()` started.
    private(set) var saving: Task<Void, Never>?
    /// Whether a change waits for the save scheduled after it.
    private var hasUnsavedChange = false
    /// Whether the latest save that ran failed and no save has succeeded since. Tests set it to make
    /// `OpenDeck.close()` refuse, which the file document alone does not do on demand.
    var hasFailed = false
    /// How long a save waits for more changes.
    private let delay: Duration
    /// How long after a failed save the next one starts.
    private let retryDelay: Duration
    private let save: @MainActor () -> Task<Bool, Never>?
    /// Runs when a save failed, before the next try.
    var onFailure: (@MainActor () -> Void)?

    /// - Parameter save: Starts to save the deck and returns the task that saves it, which finishes with whether it
    ///   did, or `nil` if there is nowhere to save it now. It decides where at once, when it is called.
    init(delay: Duration, retryDelay: Duration = .seconds(30), save: @escaping @MainActor () -> Task<Bool, Never>?) {
        self.delay = delay
        self.retryDelay = retryDelay
        self.save = save
    }

    /// Saves after `delay`, unless another change comes first; then after that one.
    func changed() {
        hasUnsavedChange = true
        schedule(after: delay)
    }

    private func schedule(after wait: Duration) {
        saving?.cancel()
        saving = Task { [weak self] in
            try? await Task.sleep(for: wait)
            await GreekSpeech.shared.whenQuiet()
            guard !Task.isCancelled, let self else { return }
            await start()?.value
        }
    }

    /// Saves a change that waits for its save at once, e.g. before the iPhone app goes
    /// to the background.
    func flush() {
        guard hasUnsavedChange else { return }
        saving?.cancel()
        saving = start()
    }

    /// Starts a save of what is unsaved. A change that comes meanwhile is unsaved again, and a failure keeps it so.
    private func start() -> Task<Void, Never>? {
        hasUnsavedChange = false
        guard let task = save() else {
            hasUnsavedChange = true
            return nil
        }
        return Task { [weak self] in
            let saved = await task.value
            guard let self else { return }
            hasFailed = !saved
            if !saved {
                hasUnsavedChange = true
                onFailure?()
                schedule(after: retryDelay)
            }
        }
    }
}
