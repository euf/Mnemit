import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// Creating, renaming and deleting deck packages in a folder, as the iPhone's screens do.
@Suite(.timeLimit(.minutes(1)))
struct DeckFilesTests {
    let folder: URL

    init() throws {
        folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func names() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
    }

    func read(_ url: URL) throws -> Deck {
        try DeckFile.decode(FileWrapper(url: url, options: .immediate))
    }

    /// A deck with one card, so a deck that moved can be told from a new one.
    @discardableResult
    func makeDeck(_ name: String) throws -> URL {
        let url = folder.appending(path: name, directoryHint: .isDirectory)
        let deck = try Deck(cards: [Card(text: CardText(question: "dom", answer: "Haus")!, created: .now)])
        try DeckFile.fileWrapper(for: deck).write(to: url, options: .atomic, originalContentsURL: nil)
        return url
    }

    // MARK: Names

    @Test func aNameBecomesAFileName() {
        #expect(DeckFiles.fileName(for: "  Greek B1 \n") == "Greek B1")
        #expect(DeckFiles.fileName(for: "Greek B1.mnemit") == "Greek B1")
        #expect(DeckFiles.fileName(for: "Greek B1.VOCTRAIN") == "Greek B1")
        #expect(DeckFiles.fileName(for: "Ελληνικά A2 – Wörter") == "Ελληνικά A2 – Wörter")
        for invalid in ["", "   ", ".mnemit", ".hidden", "a/b", "a:b", "tab\there", String(repeating: "x", count: 250)] {
            #expect(DeckFiles.fileName(for: invalid) == nil, "\(invalid)")
        }
    }

    // MARK: Creating

    @Test func createsAnEmptyDeckInTheFolder() async throws {
        let url = try await DeckFiles.create(named: " Greek B1 ", in: folder)
        #expect(url.lastPathComponent == "Greek B1.mnemit")
        #expect(try names() == ["Greek B1.mnemit"])
        let deck = try read(url)
        #expect(deck.cards.isEmpty)
        #expect(deck.learningOptions == LearningOptions())
        #expect(KnownDecks.decks(in: folder).map(\.name) == ["Greek B1"])
        #expect(url.isDeck)
    }

    @Test func aDeckNameTypedWithItsExtensionIsNotDoubled() async throws {
        let url = try await DeckFiles.create(named: "Greek.mnemit", in: folder)
        #expect(url.lastPathComponent == "Greek.mnemit")
    }

    @Test func refusesAnInvalidName() async throws {
        for name in ["", "  ", ".hidden", "a/b", "a:b"] {
            await #expect(throws: DeckFiles.Failure.invalidName) { try await DeckFiles.create(named: name, in: folder) }
        }
        #expect(try names().isEmpty)
    }

    @Test func refusesADuplicateNameAndLeavesTheDeckAlone() async throws {
        let url = try makeDeck("Greek B1.mnemit")
        await #expect(throws: DeckFiles.Failure.nameTaken("Greek B1")) { try await DeckFiles.create(named: "Greek B1", in: folder) }
        #expect(try read(url).cards.count == 1)
        #expect(try names() == ["Greek B1.mnemit"])
    }

    /// The names of the learner's decks compare as the file system compares them, and a deck of
    /// the old extension has the name as well: the list shows names without extensions.
    @Test func aDuplicateNameIsFoundWhateverTheCaseAndTheExtension() async throws {
        try makeDeck("Greek B1.mnemit")
        try makeDeck("Polish.voctrain")
        await #expect(throws: DeckFiles.Failure.nameTaken("greek b1")) { try await DeckFiles.create(named: "greek b1", in: folder) }
        await #expect(throws: DeckFiles.Failure.nameTaken("Polish")) { try await DeckFiles.create(named: "Polish", in: folder) }
        #expect(try names() == ["Greek B1.mnemit", "Polish.voctrain"])
    }

    /// A deck iCloud Drive hasn't downloaded yet is a hidden placeholder, and is a deck.
    @Test func aDeckNotDownloadedYetHoldsItsName() async throws {
        try Data().write(to: folder.appending(path: ".Greek B2.mnemit.icloud"))
        await #expect(throws: DeckFiles.Failure.nameTaken("Greek B2")) { try await DeckFiles.create(named: "Greek B2", in: folder) }
    }

    // MARK: Renaming

    @Test func renamesTheDeckAndKeepsItsCards() async throws {
        let url = try makeDeck("Greek B1.mnemit")
        let renamed = try await DeckFiles.rename(url, to: " Greek B1 Wörter ")
        #expect(renamed.lastPathComponent == "Greek B1 Wörter.mnemit")
        #expect(try names() == ["Greek B1 Wörter.mnemit"])
        #expect(try read(renamed).cards.map(\.question) == ["dom"])
    }

    /// A deck of the old extension is renamed under its extension, never converted.
    @Test func aVoctrainDeckKeepsItsExtension() async throws {
        let url = try makeDeck("Polish.voctrain")
        let renamed = try await DeckFiles.rename(url, to: "Polski")
        #expect(renamed.lastPathComponent == "Polski.voctrain")
        #expect(try names() == ["Polski.voctrain"])
    }

    @Test func aNewNameOfTheSameNameChangesNothing() async throws {
        let url = try makeDeck("Polish.mnemit")
        #expect(try await DeckFiles.rename(url, to: "Polish") == url)
        #expect(try await DeckFiles.rename(url, to: "Polish.mnemit") == url)
        #expect(try names() == ["Polish.mnemit"])
    }

    @Test func theCaseOfANameCanChangeOnItsOwn() async throws {
        let url = try makeDeck("greek.mnemit")
        let renamed = try await DeckFiles.rename(url, to: "Greek")
        #expect(renamed.lastPathComponent == "Greek.mnemit")
        #expect(try names() == ["Greek.mnemit"])
        #expect(try read(renamed).cards.count == 1)
    }

    @Test func refusesANameAnotherDeckHasAndLeavesBothAlone() async throws {
        let url = try makeDeck("Polish.mnemit")
        try makeDeck("Greek.voctrain")
        await #expect(throws: DeckFiles.Failure.nameTaken("Greek")) { try await DeckFiles.rename(url, to: "Greek") }
        await #expect(throws: DeckFiles.Failure.invalidName) { try await DeckFiles.rename(url, to: "a/b") }
        #expect(try names() == ["Greek.voctrain", "Polish.mnemit"])
        #expect(try read(url).cards.count == 1)
    }

    // MARK: Deleting

    /// Where the location has a Trash the deck goes there, where it hasn't it is set aside:
    /// either way it is out of the list and not deleted for good.
    @Test func aDeletedDeckIsNotInTheFolderButNotGone() async throws {
        let url = try makeDeck("Polish.mnemit")
        let outcome = try await DeckFiles.trash(url)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(KnownDecks.decks(in: folder).isEmpty)
        switch outcome {
        case .trash:
            break
        case let .setAside(moved):
            #expect(try read(moved).cards.count == 1)
        }
    }

    /// The fallback for a location without a Trash, which is `FileManager`'s way of saying
    /// so: the same name twice gets a number.
    @Test func withoutATrashTheDeckIsSetAsideInAFolderNextToIt() async throws {
        let unsupported: @Sendable (URL) throws -> Void = { _ in throw CocoaError(.featureUnsupported) }
        let first = try makeDeck("Polish.mnemit")
        let moved = try await DeckFiles.trash(first, using: unsupported)
        #expect(moved == .setAside(folder.appending(path: "Deleted Decks/Polish.mnemit", directoryHint: .isDirectory)))
        #expect(try names() == ["Deleted Decks"])

        let second = try makeDeck("Polish.mnemit")
        let again = try await DeckFiles.trash(second, using: unsupported)
        #expect(again == .setAside(folder.appending(path: "Deleted Decks/Polish 2.mnemit", directoryHint: .isDirectory)))
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.appending(path: "Deleted Decks").path).sorted() == ["Polish 2.mnemit", "Polish.mnemit"])
        #expect(KnownDecks.decks(in: folder).isEmpty)
    }

    /// Any other failure leaves the deck where it is: nothing is deleted on a guess.
    @Test func anotherFailureLeavesTheDeckAlone() async throws {
        let url = try makeDeck("Polish.mnemit")
        let failing: @Sendable (URL) throws -> Void = { _ in throw CocoaError(.fileWriteNoPermission) }
        await #expect(throws: CocoaError(.fileWriteNoPermission)) { try await DeckFiles.trash(url, using: failing) }
        #expect(try names() == ["Polish.mnemit"])
    }
}
