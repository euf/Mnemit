import Foundation
import os

/// The documents File ▸ New just made, until the window of each has asked its learner "New Deck" once: a
/// name and the mark. Opening a file and the welcome window's import into a new deck make no such question.
enum NewDecks {
    private static let made = OSAllocatedUnfairLock(initialState: Set<ObjectIdentifier>())

    /// What `DocumentGroup` makes for File ▸ New: an empty deck that starts with New words, the default of a new
    /// deck, so a learner who closes the question keeps it. It is marked to be asked about.
    nonisolated static func newDocument() -> VocabularyDocument {
        let document = VocabularyDocument(deck: .new(introducesNewCards: true))
        made.withLock { _ = $0.insert(ObjectIdentifier(document)) }
        return document
    }

    /// Whether `document` is a new deck that has not been asked about: true once, for its window.
    @MainActor static func take(_ document: VocabularyDocument) -> Bool {
        made.withLock { $0.remove(ObjectIdentifier(document)) != nil }
    }
}
