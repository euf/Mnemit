import Foundation
import VocabCore

/// The decks the Mac's day counts, as the iPhone's does: every deck of the Mnemit folder, the open ones as their
/// documents have them (with the reviews not saved yet), the others read from their files.
@MainActor
enum AllDecks {
    /// The open documents, and the decks of the folder that none of them holds.
    static func current(decks: OpenDecks = .shared, folder: DeckFolder = .shared) -> (documents: [VocabularyDocument], files: [URL]) {
        let documents = decks.documents
        let open = Set(documents.compactMap { $0.packageURL.map(OpenDecks.key) })
        return (documents, folder.decks.filter { !open.contains(OpenDecks.key($0)) })
    }
}

extension DailyRingModel {
    /// Evaluates the ring over `AllDecks`.
    @discardableResult
    func refreshAllDecks(decks open: OpenDecks = .shared, folder: DeckFolder = .shared, reloadFiles: Bool = false, delay: Duration = .milliseconds(250)) -> Task<Void, Never> {
        let decks = AllDecks.current(decks: open, folder: folder)
        return refresh(documents: decks.documents, files: decks.files, ledger: ProgressLedgerStore(folder: folder.url), reloadFiles: reloadFiles, delay: delay)
    }
}
