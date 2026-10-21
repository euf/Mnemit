import Foundation
import Testing
import VocabCore

@testable import VocTrain

/// The folder that holds the decks: its decks are listed without having been opened.
@MainActor
struct KnownFolderTests {
    let directory: URL
    let defaults: UserDefaults

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defaults = try #require(UserDefaults(suiteName: "KnownFolderTests-\(UUID().uuidString)"))
    }

    @Test func aChosenFolderListsItsDecksByNameAfterTheNextLaunch() throws {
        let folder = try makeFolder(decks: ["Greek B1", "Greek A1–A2"], others: ["notes.txt"])
        let known = KnownDecks(defaults: defaults)

        #expect(known.chooseFolder(folder) == 2)
        #expect(known.byName.map(\.name) == ["Greek A1–A2", "Greek B1"])
        // Not opened yet, so none of them opens by itself at launch.
        #expect(known.last == nil)
        #expect(KnownDecks(defaults: defaults).byName.map(\.name) == ["Greek A1–A2", "Greek B1"])
    }

    @Test func aFolderWithoutDecksIsNotTaken() throws {
        let folder = try makeFolder(decks: [], others: ["notes.txt"])
        let known = KnownDecks(defaults: defaults)

        #expect(known.chooseFolder(folder) == 0)
        #expect(known.folder == nil)
        #expect(KnownDecks(defaults: defaults).folder == nil)
    }

    @Test func aDeckThatArrivedLaterIsListedAfterARefresh() throws {
        let folder = try makeFolder(decks: ["Greek A1–A2"], others: [])
        let known = KnownDecks(defaults: defaults)
        known.chooseFolder(folder)

        try makeDeck(named: "Greek B1", in: folder)
        #expect(known.byName.map(\.name) == ["Greek A1–A2"])
        known.refreshFolder()
        #expect(known.byName.map(\.name) == ["Greek A1–A2", "Greek B1"])
    }

    @Test func aDeckOpenedBeforeAndInTheFolderIsListedOnce() throws {
        let folder = try makeFolder(decks: ["Greek A1–A2", "Greek B1"], others: [])
        let known = KnownDecks(defaults: defaults)
        known.remember(folder.appending(path: "Greek B1.mnemit", directoryHint: .isDirectory))
        known.chooseFolder(folder)

        #expect(known.byName.map(\.name) == ["Greek A1–A2", "Greek B1"])
    }

    @Test func onlyDecksInTheFolderStayOnTheListWhenRemoved() throws {
        let folder = try makeFolder(decks: ["Greek B1"], others: [])
        let elsewhere = try makeDeck(named: "Polish", in: directory)
        let known = KnownDecks(defaults: defaults)
        known.chooseFolder(folder)

        #expect(known.isInFolder(folder.appending(path: "Greek B1.mnemit", directoryHint: .isDirectory)))
        #expect(!known.isInFolder(elsewhere))
    }

    @Test func aPlaceholderOfADeckThatIsNotDownloadedStandsForTheDeck() throws {
        let folder = try makeFolder(decks: ["Greek A1–A2"], others: [".Greek B1.mnemit.icloud", ".Greek B2.voctrain.icloud", ".DS_Store", ".notes.txt.icloud"])

        #expect(KnownDecks.decks(in: folder).map(\.name).sorted() == ["Greek A1–A2", "Greek B1", "Greek B2"])
    }

    private func makeFolder(decks: [String], others: [String]) throws -> URL {
        let folder = directory.appending(path: "Mnemit-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for name in decks {
            try makeDeck(named: name, in: folder)
        }
        for name in others {
            try Data().write(to: folder.appending(path: name))
        }
        return folder
    }

    @discardableResult
    private func makeDeck(named name: String, in folder: URL) throws -> URL {
        let url = folder.appending(path: "\(name).mnemit", directoryHint: .isDirectory)
        try DeckFile.fileWrapper(for: Deck()).write(to: url, options: .atomic, originalContentsURL: nil)
        return url
    }
}
