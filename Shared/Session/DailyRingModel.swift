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
/// It also hands out the new-card allowance of each deck (`DailyProgress.newCardAllowances`), the
/// deck's share of the new cards the day admits: to an open document as its `newCardAllowance`, and
/// for a deck read from its file in `NewCardAllowances.today`, where whoever builds the plan of a
/// deck from its file finds it.
///
/// A paused deck (`LearningOptions.isPaused`) is in none of it: the evaluation leaves it out, and it gets no
/// allowance, so its own plan is the one of its limits, which "Study This Deck" takes.
///
/// The work runs off the main actor, after a short pause that later calls replace, so a
/// grade doesn't wait for it, and a quick run of grades costs one evaluation. It waits for a card
/// that speaks to be through (`GreekSpeech.whenQuiet()`): the figures change a moment later, and the
/// voice has the main thread and the processor to itself.
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
    /// - Returns: The evaluation, which a later call cancels: its `value` is there when the figures are.
    @discardableResult
    func refresh(documents: [VocabularyDocument], files: [URL] = [], reloadFiles: Bool = false, delay: Duration = .milliseconds(250)) -> Task<Void, Never> {
        let decks = documents.map(\.deck)
        let calendar = documents.first?.calendar ?? StudyCalendar()
        let now = documents.first?.clock.now ?? Date()
        let known = fileActivities
        let mustRead = reloadFiles || Set(files) != Set(known.keys)

        evaluation?.cancel()
        let evaluation = Task { [weak self] in
            try? await Task.sleep(for: delay)
            await GreekSpeech.shared.whenQuiet()
            guard !Task.isCancelled else { return }
            let result = await Task.detached(priority: .utility) { () -> (DailyProgress, [URL: DeckActivity], NewCardAllowances, [URL]) in
                var fileActivities = known
                if mustRead {
                    fileActivities = [:]
                    for url in files {
                        if let deck = DeckFileReader.deck(at: url) {
                            fileActivities[url] = DeckActivity(deck: deck, calendar: calendar)
                        }
                    }
                }
                let read = files.filter { fileActivities[$0] != nil }
                let activities = decks.map { DeckActivity(deck: $0, calendar: calendar) } + read.compactMap { fileActivities[$0] }
                let progress = DailyProgress.evaluate(activities, at: now, calendar: calendar)
                // In the order of the activities: the documents, then the files that were read. A paused deck has
                // none, and the allowance of its file from before it was paused goes with it.
                var allowances = NewCardAllowances()
                var paused: [URL] = []
                for (url, allowance) in zip(read, progress.newCardAllowances.dropFirst(decks.count)) {
                    if fileActivities[url]?.isPaused == true {
                        paused.append(url)
                    } else {
                        allowances[url] = allowance
                    }
                }
                return (progress, fileActivities, allowances, paused)
            }.value
            guard !Task.isCancelled, let self else { return }
            StallTrace.measure("ringApply") {
                fileActivities = result.1
                progress = result.0
                NewCardAllowances.today.merge(result.2)
                for url in result.3 {
                    NewCardAllowances.today[url] = nil
                }
                for ((document, deck), allowance) in zip(zip(documents, decks), result.0.newCardAllowances) {
                    document.newCardAllowance = deck.learningOptions.isPaused ? nil : allowance
                }
            }
        }
        self.evaluation = evaluation
        return evaluation
    }
}

/// Reads a deck package with its review log, without opening it as a document.
enum DeckFileReader {
    /// The deck at `url`, or `nil` if it can't be read: damaged, or not downloaded yet by
    /// iCloud Drive. It holds none of the media files: the readers count cards, and a deck read
    /// like this is never saved.
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
            deck = try? DeckFile.read(at: url, withMedia: false)
        }
        return deck
    }
}

/// How many new cards each deck may introduce today next to its own limits: the deck's share of the
/// new cards the day admits (`DailyProgress.newCardAllowances`), by the file the deck is kept in.
/// `StudySession` takes it as `newCardAllowance`; a deck with no entry has none, and its plan is
/// the one of its limits.
struct NewCardAllowances: Equatable, Sendable {
    private var byFile: [String: Int] = [:]

    /// What the daily ring worked out last, for every deck file it has seen: the allowance of a deck
    /// holds for the study day, so a file the last evaluation left out keeps the one it had.
    @MainActor static var today = NewCardAllowances()

    subscript(url: URL) -> Int? {
        get { byFile[Self.key(url)] }
        set { byFile[Self.key(url)] = newValue }
    }

    mutating func merge(_ other: NewCardAllowances) {
        byFile.merge(other.byFile) { _, new in new }
    }

    /// The same file however its URL is spelled: the path of a package may end with a slash, and
    /// `/var` is a link to `/private/var`.
    private static func key(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
