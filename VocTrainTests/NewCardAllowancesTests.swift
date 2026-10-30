import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// The new cards a deck may introduce today: the daily ring works them out, and the plan of each deck takes them.
@MainActor
struct NewCardAllowancesTests {
    /// `count` new cards added `daysAgo` days ago: the day's new cards go to the newest additions first.
    func fresh(_ count: Int, daysAgo: Double = 0) -> [Card] {
        (0..<count).map { Card(text: CardText(question: "n\($0)", answer: "x")!, created: Date().addingTimeInterval(-daysAgo * 86400)) }
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
        let url = try writeDeck(named: "Greek", cards: fresh(20, daysAgo: 2), in: directory)
        // Three words of today and seventeen older ones.
        let document = try VocabularyDocument(deck: Deck(cards: fresh(3) + fresh(17, daysAgo: 3)))
        let ring = DailyRingModel()

        // The 150 s of the first day at the first pace of 30 s a new card hold five of them, taken from one queue of the
        // words of both decks, newest addition first: the document's three of today, then two of the file's.
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

    // MARK: A deck is counted once

    @Test func aDeckPassedAsADocumentAndAsItsOwnFileIsEvaluatedOnce() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = try writeDeck(named: "Greek", cards: fresh(10, daysAgo: 2), in: directory)
        // The same package behind a link and with a slash at its end, as two lists may spell it.
        let link = directory.appending(path: "link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: directory)
        let spelled = URL(fileURLWithPath: link.path + "/Greek.mnemit/", isDirectory: true)
        let document = try VocabularyDocument(deck: Deck(cards: fresh(10, daysAgo: 2)))
        document.packageURL = url

        let alone = DailyRingModel()
        await alone.refresh(documents: [document], reloadFiles: true, delay: .zero).value
        let twice = DailyRingModel()
        await twice.refresh(documents: [document], files: [spelled], reloadFiles: true, delay: .zero).value

        let single = try #require(alone.progress)
        let doubled = try #require(twice.progress)
        #expect(single.newCardAllowances.count == 1)
        #expect(doubled.newCardAllowances == single.newCardAllowances)
        #expect(doubled.ring == single.ring)
    }

    @Test func aFileListedTwiceIsEvaluatedOnce() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = try writeDeck(named: "Greek", cards: fresh(10, daysAgo: 2), in: directory)
        let slash = URL(fileURLWithPath: url.path + "/", isDirectory: true)
        let ring = DailyRingModel()
        await ring.refresh(documents: [], files: [url, slash], reloadFiles: true, delay: .zero).value
        #expect(try #require(ring.progress).newCardAllowances.count == 1)
    }

    // MARK: The study day

    @Test func anAllowanceOfYesterdayIsNoAllowanceToday() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Greek.mnemit", directoryHint: .isDirectory)
        let other = directory.appending(path: "Polish.mnemit", directoryHint: .isDirectory)
        let today = StudyCalendar().dayNumber(for: Date())
        defer { NewCardAllowances.today = NewCardAllowances() }

        var yesterday = NewCardAllowances(day: today - 1)
        yesterday[url] = 12
        yesterday[other] = 3
        NewCardAllowances.today = yesterday
        #expect(NewCardAllowances.today[url] == nil)

        // The first evaluation of the day replaces them all, also the files it leaves out.
        NewCardAllowances.today = yesterday
        var current = NewCardAllowances(day: today)
        current[url] = 5
        NewCardAllowances.today.merge(current)
        #expect(NewCardAllowances.today[url] == 5)
        #expect(NewCardAllowances.today[other] == nil)

        // Within the day, a file the evaluation left out keeps its allowance.
        var again = NewCardAllowances(day: today)
        again[other] = 2
        NewCardAllowances.today.merge(again)
        #expect(NewCardAllowances.today[url] == 5)
        #expect(NewCardAllowances.today[other] == 2)
    }
}
