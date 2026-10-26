import AppKit
import Foundation
import Testing

@testable import MacVocTrain
@testable import VocabCore

extension DeckFileTests {
    /// The model of the Mac's one window (`Shell`): what is selected, what the sidebar says, how the stream takes the window
    /// and gives it back, and what renaming, deleting and pausing a deck do to all of it. Over decks in a temporary folder.
    @MainActor @Suite(.timeLimit(.minutes(3)))
    struct ShellModelTests {
        // MARK: Selecting

        @Test func selectingADeckOpensItAndKeepsItOpen() async throws {
            let f = try ShellFixture(decks: [("Alpha", 3), ("Beta", 2)])
            let shell = f.shell
            #expect(shell.selection == .today)
            #expect(shell.selectedDeck == nil)

            shell.select(.progress)
            #expect(shell.selection == .progress)
            #expect(shell.selectedURL == nil)

            shell.select(.deck(f.url("Alpha")))
            let alpha = try #require(shell.selectedDeck)
            #expect(shell.selectedURL == f.url("Alpha"))

            // Another page and back: the same open deck, with the undo steps it has.
            shell.select(.deck(f.url("Beta")))
            shell.select(.today)
            shell.select(.deck(f.url("Alpha")))
            #expect(shell.selectedDeck === alpha)
            #expect(shell.decks.deck(for: f.url("Beta")) != nil)
            await f.finish()
        }

        @Test func theCardsAndStatisticsOfTheSelectedDeckAreForDecksOnly() throws {
            let f = try ShellFixture(decks: [("Alpha", 1)])
            f.shell.showScreen(.statistics)
            #expect(f.shell.screen == .cards)
            f.shell.select(.deck(f.url("Alpha")))
            f.shell.showScreen(.statistics)
            #expect(f.shell.screen == .statistics)
        }

        // MARK: The badges

        @Test func badgesAreTheCardsLeftOfTheDay() async throws {
            let f = try ShellFixture(decks: [("Alpha", 5), ("Beta", 3), ("Gamma", 4)])
            let shell = f.shell
            try await f.waitUntilRead(decks: 3)

            // What the files say, read on their own, over the new cards each deck may take today.
            let left = try ["Alpha", "Beta", "Gamma"].map {
                try #require(KnownDeckCounts.counts(at: f.url($0), allowance: NewCardAllowances.today[f.url($0)])).total
            }
            #expect(left.allSatisfy { $0 > 0 })
            let rows = shell.sidebar
            #expect(rows.decks.map(\.cardsLeft) == left)
            #expect(rows.today == left.reduce(0, +))
            // The number Today's page shows is the one on its badge.
            #expect(rows.today == shell.due)
            #expect(rows.paused.isEmpty && rows.others.isEmpty)

            // An open deck counts with the reviews not saved yet: the badge follows at once.
            let (deck, document) = try await f.open("Alpha")
            try f.review(deck, document, grade: .easy)
            let after = shell.sidebar
            #expect(after.decks.map(\.cardsLeft) == [left[0] - 1, left[1], left[2]])
            #expect(after.today == left.reduce(0, +) - 1)
            #expect(after.today == shell.due)
            await f.finish()
        }

        @Test func aPausedDeckHasNoBadgeAndAsksNothingOfTheDay() async throws {
            let f = try ShellFixture(decks: [("Alpha", 5), ("Beta", 3)])
            let shell = f.shell
            try await f.waitUntilRead(decks: 2)
            let beta = try #require(shell.sidebar.decks.last?.cardsLeft)

            await shell.setPaused(f.url("Alpha"), true)
            #expect(shell.isPaused(f.url("Alpha")))
            var rows = shell.sidebar
            #expect(rows.decks.map(\.url) == [f.url("Beta")])
            #expect(rows.paused.map(\.url) == [f.url("Alpha")])
            #expect(rows.paused.first?.cardsLeft == nil)
            #expect(rows.today == beta)

            await shell.setPaused(f.url("Alpha"), false)
            rows = shell.sidebar
            #expect(rows.paused.isEmpty)
            #expect(rows.decks.count == 2)
            #expect(rows.today == shell.due)

            // The pause is in the file once the decks are closed.
            await shell.setPaused(f.url("Beta"), true)
            await shell.closeAll()
            #expect(DeckFileReader.deck(at: f.url("Beta"))?.learningOptions.isPaused == true)
            #expect(DeckFileReader.deck(at: f.url("Alpha"))?.learningOptions.isPaused == false)
            await f.finish()
        }

        // MARK: Opening from outside

        @Test func aDeckFromOutsideTheFolderLandsUnderOtherDecks() async throws {
            let f = try ShellFixture(decks: [("Alpha", 2)])
            let shell = f.shell
            let outside = f.directory.appending(path: "Elsewhere.mnemit", directoryHint: .isDirectory)
            try ShellFixture.write(cards: 2, to: outside)

            shell.open([outside])
            #expect(shell.others == [outside.standardizedFileURL])
            #expect(shell.selectedURL == outside.standardizedFileURL)
            #expect(shell.sidebar.others.map(\.url) == [outside.standardizedFileURL])
            #expect(shell.sidebar.decks.map(\.url) == [f.url("Alpha")])
            #expect(shell.known == [f.url("Alpha"), outside.standardizedFileURL])

            // Once only, however many times it is opened, and the folder's decks never join it.
            shell.open([outside])
            shell.open([f.url("Alpha")])
            #expect(shell.others == [outside.standardizedFileURL])
            #expect(shell.selectedURL == f.url("Alpha"))
            await f.finish()
        }

        // MARK: Study

        @Test func studyTakesTheWindowAndDoneGivesTheSidebarBack() async throws {
            let f = try ShellFixture(decks: [("Alpha", 5), ("Beta", 3)])
            let shell = f.shell
            try await f.waitUntilRead(decks: 2)
            shell.select(.deck(f.url("Beta")))
            shell.setVisibility(.all)
            #expect(shell.canStudyDay)

            shell.study(.day)
            let run = try #require(shell.run)
            #expect(shell.columnVisibility == .detailOnly)
            #expect(run.decks.map(\.url) == [f.url("Alpha"), f.url("Beta")])
            // The stream has the window whole: no page, no toggle.
            shell.select(.today)
            #expect(shell.selectedURL == f.url("Beta"))
            shell.setVisibility(.all)
            #expect(shell.columnVisibility == .detailOnly)
            shell.study(.deck(f.url("Alpha")))
            #expect(shell.run === run)

            try await f.waitFor("the stream opens") { shell.session != nil }
            #expect(f.defaults.string(forKey: Shell.lastStudiedKey) == OpenDecks.key(run.decks[0].url))

            shell.endStudy()
            #expect(shell.run == nil)
            #expect(shell.session == nil)
            #expect(shell.columnVisibility == .all)
            shell.select(.today)
            #expect(shell.selection == .today)
            await f.finish()
        }

        @Test func studyOfADeckRunsOverThatDeckAlone() async throws {
            let f = try ShellFixture(decks: [("Alpha", 5), ("Beta", 3)])
            let shell = f.shell
            try await f.waitUntilRead(decks: 2)

            shell.study(.deck(f.url("Beta")))
            let run = try #require(shell.run)
            #expect(run.decks.map(\.url) == [f.url("Beta")])
            #expect(shell.columnVisibility == .detailOnly)
            try await f.waitFor("the stream opens") { shell.session != nil }

            shell.endStudy()
            #expect(shell.columnVisibility == .automatic)
            // The run doesn't own the decks: they stay open, as the sidebar has them.
            #expect(shell.decks.deck(for: f.url("Beta")) != nil)
            await f.finish()
        }

        @Test func theDayStudiesTheDeckStudiedLastFirst() async throws {
            let f = try ShellFixture(decks: [("Alpha", 5), ("Beta", 3), ("Gamma", 4)])
            let shell = f.shell
            try await f.waitUntilRead(decks: 3)
            #expect(shell.queue(for: .study).map(\.lastPathComponent) == ["Alpha.mnemit", "Beta.mnemit", "Gamma.mnemit"])

            f.defaults.set(OpenDecks.key(f.url("Gamma")), forKey: Shell.lastStudiedKey)
            #expect(shell.queue(for: .study).map(\.lastPathComponent) == ["Gamma.mnemit", "Alpha.mnemit", "Beta.mnemit"])
            await f.finish()
        }

        // MARK: Renaming, deleting

        @Test func renamingTheSelectedDeckSelectsItUnderItsNewName() async throws {
            let f = try ShellFixture(decks: [("Alpha", 3), ("Beta", 2)])
            let shell = f.shell
            shell.select(.deck(f.url("Alpha")))
            try await f.open("Alpha")

            try await shell.rename(f.url("Alpha"), to: "Polish")
            #expect(!FileManager.default.fileExists(atPath: f.url("Alpha").path))
            #expect(FileManager.default.fileExists(atPath: f.url("Polish").path))
            #expect(shell.folder.decks.map(\.lastPathComponent) == ["Beta.mnemit", "Polish.mnemit"])
            #expect(shell.selectedURL == f.url("Polish"))
            #expect(shell.decks.deck(for: f.url("Alpha")) == nil)
            await f.finish()
        }

        @Test func renamingToATakenNameLeavesTheDeckWhereItWas() async throws {
            let f = try ShellFixture(decks: [("Alpha", 3), ("Beta", 2)])
            let shell = f.shell
            shell.select(.deck(f.url("Alpha")))
            try await f.open("Alpha")

            await #expect(throws: (any Error).self) { try await shell.rename(f.url("Alpha"), to: "Beta") }
            #expect(FileManager.default.fileExists(atPath: f.url("Alpha").path))
            #expect(shell.selectedURL == f.url("Alpha"))
            await f.finish()
        }

        @Test func deletingTheSelectedDeckMovesItToTheTrashAndShowsToday() async throws {
            let f = try ShellFixture(decks: [("Alpha", 3), ("Beta", 2)])
            let shell = f.shell
            shell.select(.deck(f.url("Alpha")))
            try await f.open("Alpha")

            try await shell.delete(f.url("Alpha"))
            #expect(!FileManager.default.fileExists(atPath: f.url("Alpha").path))
            #expect(shell.folder.decks.map(\.lastPathComponent) == ["Beta.mnemit"])
            #expect(shell.selection == .today)
            #expect(shell.decks.deck(for: f.url("Alpha")) == nil)

            // Another deck stays selected when this one goes.
            shell.select(.deck(f.url("Beta")))
            #expect(shell.selectedURL == f.url("Beta"))
            await f.finish()
        }
    }
}
