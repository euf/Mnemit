import SwiftUI
import UniformTypeIdentifiers
import VocabCore

/// The document behind `DocumentGroup`, which only the Mac app uses; the iPhone app
/// opens and saves its decks itself (#285, #297). Everything here is `nonisolated`:
/// SwiftUI opens documents and writes snapshots to file wrappers off the main actor.
extension VocabularyDocument: ReferenceFileDocument {
    nonisolated static var readableContentTypes: [UTType] { UTType.deckTypes }

    /// A deck of the old extension is saved in place, so its type must be writable too.
    /// The first type is that of new decks: `.mnemit`.
    nonisolated static var writableContentTypes: [UTType] { UTType.deckTypes }

    nonisolated convenience init(configuration: ReadConfiguration) throws {
        let deck: Deck
        do {
            deck = try DeckFile.decode(configuration.file)
        } catch {
            throw Self.openingError(for: error)
        }
        self.init(deck: deck)
    }

    /// Runs on the main thread or, for the first save of a new deck, on a background
    /// thread, see `deckToSave`.
    nonisolated func snapshot(contentType: UTType) throws -> Deck {
        deckToSave
    }

    /// The media of the package that are in it already are cloned from `packageURL`, not written again:
    /// `configuration.existingFile` has no URL to clone from.
    nonisolated func fileWrapper(snapshot: Deck, configuration: WriteConfiguration) throws -> FileWrapper {
        try fileWrapper(for: snapshot)
    }
}
