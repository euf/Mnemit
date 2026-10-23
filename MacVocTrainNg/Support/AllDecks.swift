import Foundation
import VocabCore

/// The decks the Mac's day counts, as the iPhone's does: every deck of the Mnemit folder, the open ones as their
/// documents have them (with the reviews not saved yet), the others read from their files.
@MainActor
enum AllDecks {
    /// The open documents, and the decks of the folder that none of them holds.
    static func current() -> (documents: [VocabularyDocument], files: [URL]) {
        let documents = OpenDecks.shared.documents
        let open = Set(documents.compactMap { $0.packageURL?.standardizedFileURL })
        return (documents, DeckFolder.shared.decks.filter { !open.contains($0.standardizedFileURL) })
    }
}

extension DailyRingModel {
    /// Evaluates the ring over `AllDecks`.
    @discardableResult
    func refreshAllDecks(reloadFiles: Bool = false, delay: Duration = .milliseconds(250)) -> Task<Void, Never> {
        let decks = AllDecks.current()
        return refresh(documents: decks.documents, files: decks.files, reloadFiles: reloadFiles, delay: delay)
    }
}
