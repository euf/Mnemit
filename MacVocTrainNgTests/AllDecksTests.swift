import Foundation
import Testing

@testable import MacVocTrain
@testable import VocabCore

extension DeckFileTests {
    /// The decks the Mac's day counts: the open documents and the folder's decks that none of them holds.
    @MainActor @Suite(.timeLimit(.minutes(3)))
    struct AllDecksTests {
        @Test func aDeckOpenUnderAnotherSpellingOfItsPathIsNotListedAsAFileToo() async throws {
            let f = try ShellFixture(decks: [("Alpha", 3), ("Beta", 2)])
            let (_, document) = try await f.open("Alpha")
            // The package of the open deck behind a link to the folder, as an alias or a bookmark may spell it.
            let link = f.directory.appending(path: "link")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: f.folderURL)
            document.packageURL = link.appending(path: "Alpha.mnemit", directoryHint: .isDirectory)

            let all = AllDecks.current(decks: f.shell.decks, folder: f.shell.folder)
            #expect(all.documents.count == 1)
            #expect(all.files.map(\.lastPathComponent) == ["Beta.mnemit"])
            await f.finish()
        }
    }
}
