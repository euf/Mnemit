import Foundation
import Observation
import VocabCore

/// The daily ring and the streak of the learner across decks, for `DailyRingView`: in the
/// stream's header, on the deck screen, in the toolbar of the Mac, and wherever else the
/// app shows them (the iPhone's start screen asks `refresh(documents:files:)` for all its
/// known decks).
///
/// Derived from the review logs alone (`DailyProgress`), so there is nothing to store or
/// sync: every device reads the same logs from the same deck files. The decks that are
/// open come as documents, with their reviews not yet saved; the others are read from
/// their files, once per `reloadFiles`, and kept.
///
/// The work runs off the main actor, after a short pause that later calls replace, so a
/// grade doesn't wait for it, and a quick run of grades costs one evaluation.
@MainActor @Observable
final class DailyRingModel {
    /// `nil` until the first evaluation is done.
    private(set) var progress: DailyProgress?
    @ObservationIgnored private var fileActivities: [URL: DeckActivity] = [:]
    @ObservationIgnored private var evaluation: Task<Void, Never>?

    /// Evaluates the ring and the streak for `documents` and the decks at `files`; the
    /// caller leaves the files of the documents out.
    ///
    /// - Parameters:
    ///   - reloadFiles: Reads the files again, instead of using what was read before for
    ///     the same files: after the app came back to the front, say. Without it the
    ///     files are read only if they are not the ones of the last call.
    ///   - delay: How long to wait for another call before evaluating.
    func refresh(documents: [VocabularyDocument], files: [URL] = [], reloadFiles: Bool = false, delay: Duration = .milliseconds(250)) {
        let decks = documents.map(\.deck)
        let calendar = documents.first?.calendar ?? StudyCalendar()
        let now = documents.first?.clock.now ?? Date()
        let known = fileActivities
        let mustRead = reloadFiles || Set(files) != Set(known.keys)

        evaluation?.cancel()
        evaluation = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            let result = await Task.detached(priority: .utility) { () -> (DailyProgress, [URL: DeckActivity]) in
                var fileActivities = known
                if mustRead {
                    fileActivities = [:]
                    for url in files {
                        if let deck = DeckFileReader.deck(at: url) {
                            fileActivities[url] = DeckActivity(deck: deck, calendar: calendar)
                        }
                    }
                }
                let activities = decks.map { DeckActivity(deck: $0, calendar: calendar) } + files.compactMap { fileActivities[$0] }
                return (DailyProgress.evaluate(activities, at: now, calendar: calendar), fileActivities)
            }.value
            guard !Task.isCancelled, let self else { return }
            fileActivities = result.1
            progress = result.0
        }
    }
}

/// Reads a deck package with its review log, without opening it as a document.
enum DeckFileReader {
    /// The deck at `url`, or `nil` if it can't be read: damaged, or not downloaded yet by
    /// iCloud Drive.
    nonisolated static func deck(at url: URL) -> Deck? {
        // A deck outside the app's sandbox can be read only while the app accesses it.
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        var deck: Deck?
        var error: NSError?
        // Coordinated, as the open deck's document and the merger write the package.
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { url in
            guard let wrapper = try? FileWrapper(url: url, options: .immediate) else { return }
            deck = try? DeckFile.decode(wrapper)
        }
        return deck
    }
}
