import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// The new cards a deck may introduce today: the daily ring works them out, and the plan of each deck takes them.
@MainActor
struct NewCardAllowancesTests {
    func fresh(_ count: Int) -> [Card] {
        (0..<count).map { Card(text: CardText(question: "n\($0)", answer: "x")!, created: Date()) }
    }

    func writeDeck(named name: String, cards: [Card], in directory: URL) throws -> URL {
        let url = directory.appending(path: "\(name).mnemit", directoryHint: .isDirectory)
        try DeckFile.fileWrapper(for: Deck(cards: cards)).write(to: url, options: .atomic, originalContentsURL: nil)
        return url
    }

    func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func aFileIsFoundHoweverItsURLIsSpelled() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let plain = directory.appending(path: "Greek.mnemit", directoryHint: .isDirectory)
        // The same file with a detour and a trailing slash, as the picker and the list may spell it.
        let detour = URL(fileURLWithPath: directory.path + "/elsewhere/../Greek.mnemit/", isDirectory: true)
        let other = directory.appending(path: "Polish.mnemit", directoryHint: .isDirectory)
        var allowances = NewCardAllowances()
        allowances[plain] = 6
        #expect(allowances[detour] == 6)
        #expect(allowances[other] == nil)
        var later = NewCardAllowances()
        later[plain] = 2
        later[other] = 3
        allowances.merge(later)
        #expect(allowances[detour] == 2)
        #expect(allowances[other] == 3)
    }

    @Test func theRingHandsOutTheAllowanceOfEachDeckToItsFileAndItsDocument() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = try writeDeck(named: "Greek", cards: fresh(20), in: directory)
        let document = try VocabularyDocument(deck: Deck(cards: fresh(20)))
        let ring = DailyRingModel()

        // The 150 s of the first day at the first pace of 30 s a new card hold five of them, shared by the ceilings of the two decks: 2.5 and 2.5, and the odd card goes to the earlier.
        await ring.refresh(documents: [document], files: [url], reloadFiles: true, delay: .zero).value
        let progress = try #require(ring.progress)
        #expect(progress.newCardAllowances.reduce(0, +) == 5)
        #expect(progress.newCardAllowances == [3, 2])
        #expect(document.newCardAllowance == 3)
        #expect(NewCardAllowances.today[url] == 2)
        // The document's counter shows the plan of that allowance, not the 20 cards of the deck.
        #expect(document.dueCards.counts.new == 3)
    }

    @Test func theRowOfTodayTakesTheNewCardsOfTheDecksAllowance() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = try writeDeck(named: "Polish", cards: fresh(10), in: directory)
        #expect(try #require(KnownDeckCounts.counts(at: url)).new == 10)
        #expect(try #require(KnownDeckCounts.counts(at: url, allowance: 3)).new == 3)
        // The forecast of the reminders and the widget takes the same allowance at every date.
        let dates = [Date(), Date().addingTimeInterval(86400 * 2)]
        #expect(try #require(KnownDeckCounts.counts(at: url, on: dates, allowance: 3)).map(\.new) == [3, 3])
        #expect(WidgetSnapshot.dueCounts(of: [try Deck(cards: fresh(10))], at: dates, calendar: StudyCalendar(), newCardAllowance: 3) == [3, 3])
    }

    @Test func aDeckOpenedFromItsFileStartsWithTheAllowanceTheRingFoundForIt() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = try writeDeck(named: "Czech", cards: fresh(12), in: directory)
        let ring = DailyRingModel()
        await ring.refresh(documents: [], files: [url], reloadFiles: true, delay: .zero).value
        let expected = try #require(NewCardAllowances.today[url])
        #expect(expected == 5)
        let deck = OpenDeck(url: url)
        let document = try #require(await deck.editableDocument())
        #expect(document.newCardAllowance == expected)
        await deck.close()
    }
}
