import Foundation
import Testing

@testable import MacVocTrain

/// The folder that holds the decks, which the welcome window lists.
struct DeckFolderTests {
    @Test func listsTheDecksByName() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        for name in ["Greek B1.voctrain", "Greek A1–A2.voctrain", "Greek B10.voctrain", "notes.txt", ".Hidden.voctrain"] {
            try FileManager.default.createDirectory(at: folder.appending(path: name, directoryHint: .isDirectory), withIntermediateDirectories: true)
        }

        #expect(DeckFolder.decks(in: folder).map(\.lastPathComponent) == ["Greek A1–A2.voctrain", "Greek B1.voctrain", "Greek B10.voctrain"])
    }

    @Test func aMissingFolderHasNoDecks() {
        #expect(DeckFolder.decks(in: URL(filePath: "/nonexistent/\(UUID().uuidString)")).isEmpty)
    }
}
