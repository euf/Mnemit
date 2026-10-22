import Foundation
import Testing
import UniformTypeIdentifiers

@testable import MacVocTrain
@testable import VocabCore

/// The folder that holds the decks, which the welcome window lists.
struct DeckFolderTests {
    @Test func listsTheDecksByName() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        for name in ["Greek B1.mnemit", "Greek A1–A2.voctrain", "Greek B10.mnemit", "notes.txt", ".Hidden.mnemit"] {
            try FileManager.default.createDirectory(at: folder.appending(path: name, directoryHint: .isDirectory), withIntermediateDirectories: true)
        }

        #expect(DeckFolder.decks(in: folder).map(\.lastPathComponent) == ["Greek A1–A2.voctrain", "Greek B1.mnemit", "Greek B10.mnemit"])
    }

    /// A deck of MacVocTrain NG, `.voctrain`, opens like one of Mnemit, is listed next to
    /// it, and the document may save it in place: its type is writable, the one of new decks
    /// comes first.
    @Test func aVoctrainDeckOpensAndIsListedNextToAMnemitOne() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (name, question) in [("Greek B1.mnemit", "dom"), ("Greek A1–A2.voctrain", "kot")] {
            let deck = try Deck(cards: [Card(question: question, answer: "x")])
            try DeckFile.fileWrapper(for: deck).write(to: folder.appending(path: name, directoryHint: .isDirectory), options: .atomic, originalContentsURL: nil)
        }

        let decks = DeckFolder.decks(in: folder)
        #expect(decks.map(\.lastPathComponent) == ["Greek A1–A2.voctrain", "Greek B1.mnemit"])
        let questions = try decks.map { try DeckFile.decode(FileWrapper(url: $0, options: .immediate)).cards.map(\.question) }
        #expect(questions == [["kot"], ["dom"]])

        #expect(VocabularyDocument.readableContentTypes == [.vocabularyDeck, .legacyVocabularyDeck])
        #expect(VocabularyDocument.writableContentTypes == [.vocabularyDeck, .legacyVocabularyDeck])
        // The Info.plist declares the same types as document types, and the Anki package after them.
        let documentTypes = Bundle.main.infoDictionary?["CFBundleDocumentTypes"] as? [[String: Any]] ?? []
        #expect(documentTypes.flatMap { $0["LSItemContentTypes"] as? [String] ?? [] } == (UTType.deckTypes + [.ankiPackage]).map(\.identifier))
    }

    @Test func aMissingFolderHasNoDecks() {
        #expect(DeckFolder.decks(in: URL(filePath: "/nonexistent/\(UUID().uuidString)")).isEmpty)
    }
}
