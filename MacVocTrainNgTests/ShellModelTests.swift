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

        @Test func badgesAreTheTimeLeftOfTheDay() async throws {
            let f = try ShellFixture(decks: [("Alpha", 5), ("Beta", 3), ("Gamma", 4)], newPerDay: 2)
            let shell = f.shell
            try await f.waitUntilRead(decks: 3)
            try await f.waitFor("the ring is worked out") { shell.isDayReady }
            let pace = try #require(shell.ring.progress?.pace)

            // Each deck says what its plan takes at the day's pace, over the new cards it may take today.
            let counts = try ["Alpha", "Beta", "Gamma"].map {
                try #require(KnownDeckCounts.counts(at: f.url($0), allowance: NewCardAllowances.today[f.url($0)]))
            }
            #expect(counts.allSatisfy { $0.total > 0 })
            let minutes = counts.map { DeckMinutes.minutes($0, pace: pace) }
            let rows = shell.sidebar
            #expect(rows.decks.map(\.badge) == (try minutes.map { SidebarBadge.minutes(try #require($0)) }))
            // Today prices the whole plan as one: the new cards of all decks at their price, the rest at theirs.
            let newCards = counts.reduce(0) { $0 + $1.newAtDayStart }
            let otherCards = counts.reduce(0) { $0 + $1.total - $1.newAtDayStart }
            #expect(rows.today == .minutes(DailyGoal.minutesLeft(newCards: newCards, otherCards: otherCards, pace: pace) ?? 0))
            #expect(rows.paused.isEmpty && rows.others.isEmpty)

            // An open deck counts with the reviews not saved yet: the badge follows at once, down to the check.
            let (deck, document) = try await f.open("Beta")
            for _ in 0..<counts[1].total { try f.review(deck, document, grade: .easy) }
            let after = shell.sidebar
            #expect(try #require(shell.studyCounts(f.url("Beta"))).isDone)
            #expect(after.decks.map(\.badge) == [rows.decks[0].badge, .done, rows.decks[2].badge])
            #expect(after.today != rows.today)
            await f.finish()
        }

        @Test func aPausedDeckHasNoBadgeAndAsksNothingOfTheDay() async throws {
            let f = try ShellFixture(decks: [("Alpha", 5), ("Beta", 3)])
            let shell = f.shell
            try await f.waitUntilRead(decks: 2)
            try await f.waitFor("the ring is worked out") { shell.isDayReady }
            let beta = try #require(shell.sidebar.decks.last?.badge)

            await shell.setPaused(f.url("Alpha"), true)
            #expect(shell.isPaused(f.url("Alpha")))
            var rows = shell.sidebar
            #expect(rows.decks.map(\.url) == [f.url("Beta")])
            #expect(rows.paused.map(\.url) == [f.url("Alpha")])
            #expect(rows.paused.first?.badge == nil)
            #expect(rows.today == beta)

            await shell.setPaused(f.url("Alpha"), false)
            rows = shell.sidebar
            #expect(rows.paused.isEmpty)
            #expect(rows.decks.count == 2)
            #expect(rows.today != nil)

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
            let f = try ShellFixture(decks: [("Alpha", 5), ("Beta", 3)], newPerDay: 2)
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

        /// The cheat sheet names the keys of the card asked: a first showing has Don't know and Know.
        @Test func theCheatSheetKnowsACardOnItsFirstShowing() async throws {
            let f = try ShellFixture(decks: [("Alpha", 3)])
            let shell = f.shell
            try await f.waitUntilRead(decks: 1)
            #expect(!shell.menu.onNewCard)

            shell.study(.deck(f.url("Alpha")))
            try await f.waitFor("the stream opens") { shell.session != nil }
            #expect(shell.session?.currentCard?.isNew == true)
            #expect(shell.menu.onNewCard)

            shell.endStudy()
            #expect(!shell.menu.onNewCard)
            await f.finish()
        }

        /// Study These Now from a deck's page: the stream over that deck asks the cards just added first.
        @Test func studyTheseNowOpensTheStreamWithTheAddedCardsFirst() async throws {
            let f = try ShellFixture(decks: [("Alpha", 6)])
            let shell = f.shell
            try await f.waitUntilRead(decks: 1)
            let (_, document) = try await f.open("Alpha")
            let first = try #require(document.deck.cards.first?.id)
            let added = Array(document.deck.cards.suffix(2).map(\.id))
            #expect(StudyStream.addableCards(added, in: document.deck, at: document.clock.now, calendar: document.calendar) == added)

            shell.study(.deck(f.url("Alpha")), entry: .studyNow(added))
            try await f.waitFor("the stream opens") { shell.session != nil }
            #expect(shell.run?.entry == .studyNow(added))
            let asked = try #require(shell.session?.currentCard?.id)
            #expect(added.contains(asked))
            #expect(asked != first)

            shell.endStudy()
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
            #expect(shell.columnVisibility == .all)
            // The run doesn't own the decks: they stay open, as the sidebar has them.
            #expect(shell.decks.deck(for: f.url("Beta")) != nil)
            await f.finish()
        }

        @Test func theDayStudiesTheDeckStudiedLastFirst() async throws {
            let f = try ShellFixture(decks: [("Alpha", 5), ("Beta", 3), ("Gamma", 4)], newPerDay: 2)
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
