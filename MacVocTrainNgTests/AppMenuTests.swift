import AppKit
import Testing

@testable import MacVocTrain
@testable import VocabCore

extension DeckFileTests {
    /// The menu bar of the app, walked item by item in the test host: the real `Shell.shared` and the menus SwiftUI built from
    /// `AppCommands`, on Today, on a deck, in a stream and when the day has no cards left. The expected rows are typed out
    /// here, not read from `MenuKey`, so a key changed in the table shows up as a red test.
    @MainActor @Suite(.timeLimit(.minutes(5)))
    struct AppMenuTests {
        /// A row of a menu as the learner sees it: its title, its key and whether it can be chosen.
        private struct Item: Equatable, CustomStringConvertible {
            var title: String
            var key = ""
            var modifiers = NSEvent.ModifierFlags()
            var isOn: Bool

            var description: String { "\(isOn ? "on " : "off") \(title) [\(modifiers.rawValue):\(key)]" }
        }

        /// Which rows are on. The defaults are Today's with decks that have cards left.
        private struct On {
            var newDeck = true, openDeck = true, importCards = true, shared = true, export = false, finder = false
            var day = true, studyDeck = false, addCards = false, newest = false, mistakes = false, pause = false, options = false
            var today = true, progress = true, cards = false, statistics = false, inspector = false

            /// Nothing a window does is on, as in a stream.
            static let stream = On(newDeck: false, openDeck: false, importCards: false, shared: false, day: false, today: false, progress: false)

            /// A deck's page is up, and its cards are shown.
            static let deck = On(export: true, finder: true, studyDeck: true, addCards: true, newest: true, pause: true, options: true, cards: true, statistics: true, inspector: true)

            func with(inspector: Bool) -> On {
                var copy = self
                copy.inspector = inspector
                return copy
            }
        }

        private static let command = NSEvent.ModifierFlags.command
        private static let shiftCommand: NSEvent.ModifierFlags = [.command, .shift]
        private static let optionCommand: NSEvent.ModifierFlags = [.command, .option]

        private func menu(_ name: String) -> NSMenu? {
            if name == "Help" { return NSApp.helpMenu }
            return NSApp.mainMenu?.items.first { $0.submenu?.title == String(localized: String.LocalizationValue(name)) }?.submenu
        }

        private func row(_ title: String, _ key: String = "", _ modifiers: NSEvent.ModifierFlags = [], on isOn: Bool) -> Item {
            Item(title: String(localized: String.LocalizationValue(title)), key: key, modifiers: modifiers, isOn: isOn)
        }

        /// The rows of the menu `name` with the titles of `expected`, in the menu's order; the system's own rows are not ours
        /// to check. SwiftUI builds the items of its menus, with their on and off, when AppKit is about to show the menu or to
        /// look for a key in it: `menuNeedsUpdate` is that moment, and the items read before it are the ones of the last.
        private func rows(of name: String, like expected: [Item]) -> [Item] {
            let titles = Set(expected.map(\.title))
            if let menu = menu(name) { menu.delegate?.menuNeedsUpdate?(menu) }
            return (menu(name)?.items ?? []).filter { titles.contains($0.title) }.map {
                Item(title: $0.title, key: $0.keyEquivalent, modifiers: $0.keyEquivalentModifierMask.intersection(.deviceIndependentFlagsMask), isOn: $0.isEnabled)
            }
        }

        /// Waits until the menu reads as `expected`, then reports what differs.
        private func expect(_ name: String, _ expected: [Item], _ comment: Comment, sourceLocation: SourceLocation) async throws {
            let deadline = ContinuousClock.now + .seconds(10)
            while rows(of: name, like: expected) != expected, ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(20))
            }
            #expect(rows(of: name, like: expected) == expected, "\(name) menu, \(comment)", sourceLocation: sourceLocation)
        }

        /// File, Study, View and Help as the learner finds them.
        private func expectMenus(_ on: On, day: String = "Study", pause: String = "Pause Deck", _ comment: Comment, sourceLocation: SourceLocation = #_sourceLocation) async throws {
            try await expect(
                "File",
                [
                    row("New Deck…", "n", Self.command, on: on.newDeck),
                    row("Open Deck…", "o", Self.command, on: on.openDeck),
                    row("Import Cards…", "i", Self.shiftCommand, on: on.importCards),
                    row("Shared Decks on AnkiWeb…", on: on.shared),
                    row("Export Deck…", on: on.export),
                    row("Show in Finder", on: on.finder),
                ], comment, sourceLocation: sourceLocation)
            try await expect(
                "Study",
                [
                    row(day, "l", Self.command, on: on.day),
                    row("Study This Deck", "l", Self.optionCommand, on: on.studyDeck),
                    row("Add Cards…", "l", Self.shiftCommand, on: on.addCards),
                    row("Practice Newest Words", on: on.newest),
                    row("Practice Today's Mistakes", on: on.mistakes),
                    row(pause, on: on.pause),
                    row("Learning Options…", ";", Self.command, on: on.options),
                ], comment, sourceLocation: sourceLocation)
            try await expect(
                "View",
                [
                    row("Today", "1", Self.command, on: on.today),
                    row("Progress", "2", Self.command, on: on.progress),
                    row("Cards", "3", Self.command, on: on.cards),
                    row("Statistics", "4", Self.command, on: on.statistics),
                    row("Show Inspector", "i", Self.optionCommand, on: on.inspector),
                ], comment, sourceLocation: sourceLocation)
            try await expect("Help", [row("Keyboard Shortcuts", on: true)], comment, sourceLocation: sourceLocation)
        }

        /// What the menus offer on Today, on a deck, in a stream and when nothing of the day is left to study.
        @Test func theMenusFollowTheWindow() async throws {
            let shell = Shell.shared
            let folder = DeckFolder.shared
            let previous = folder.url
            let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
            let alpha = directory.appending(path: "Alpha.mnemit", directoryHint: .isDirectory)
            let empty = directory.appending(path: "Empty.mnemit", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try ShellFixture.write(cards: 2, to: alpha)
            try ShellFixture.write(cards: 2, to: directory.appending(path: "Beta.mnemit", directoryHint: .isDirectory))

            do {
                try await waitUntil("the menus are built", timeout: .seconds(60)) { menu("View")?.items.contains { $0.title == String(localized: "Today") } == true }
                folder.use(directory)
                shell.select(.today)
                shell.screen = .cards
                shell.showsInspector = false
                shell.refresh()
                // The shell may have read an earlier folder: wait for the two decks, whose four new cards make the day's action Study.
                try await waitUntil("the two decks are read and the day says Study", timeout: .seconds(60)) { shell.due == 4 && shell.menu.dayAction == .study }

                try await expectMenus(On(), "on Today")

                shell.open([alpha])
                let deck = try #require(shell.selectedDeck)
                try await waitUntil("the deck is read", timeout: .seconds(120)) { deck.document != nil && deck.isEditable && deck.document?.isReadyToEdit == true }
                try await expectMenus(.deck, "on a deck")

                shell.showScreen(.statistics)
                try await expectMenus(.deck.with(inspector: false), "on the deck's statistics")
                shell.showScreen(.cards)

                shell.study(.day)
                #expect(shell.run != nil)
                try await expectMenus(.stream, "in a stream")
                shell.endStudy()
                try await expectMenus(.deck, "after the stream")

                // Nothing of the plan is left: the day's action is Learn 10 New Words, and it stays on.
                shell.select(.today)
                await shell.closeAll()
                try FileManager.default.removeItem(at: directory)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try ShellFixture.write(cards: 0, to: empty)
                shell.refresh()
                try await waitUntil("the empty deck is read", timeout: .seconds(60)) { shell.isDayReady && shell.dayAction == .pushOn }
                try await expectMenus(On(), day: "Learn 10 New Words", "when the day has nothing left")
            } catch {
                await restore(previous, directory)
                throw error
            }
            await restore(previous, directory)
        }

        private func restore(_ previous: URL?, _ directory: URL) async {
            let shell = Shell.shared
            if shell.run != nil { shell.endStudy() }
            shell.select(.today)
            shell.shortcuts.isShown = false
            shell.showsInspector = false
            await shell.closeAll()
            DeckFolder.shared.use(previous)
            shell.refresh()
            try? FileManager.default.removeItem(at: directory)
        }

        /// Study's first item is the day's action by name, as Today's button: Study while the ring is open, Catch Up once it is
        /// closed with cards left, Learn 10 New Words once the plan is done. The live menu has the first and the last of them
        /// in `theMenusFollowTheWindow`; the middle one needs a closed ring, which is made by hand here.
        @Test func theFirstItemOfStudyNamesTheDaysAction() {
            let pace = Pace(newCard: 30, otherCard: 15)
            let rounds = DayRounds(otherCards: 30, newCards: 0, pace: pace, seconds: 480)
            func progress(done: Int) -> DailyProgress {
                DailyProgress(
                    ring: DailyRing(done: done, goal: rounds.goal), streak: Streak(days: 12, repairCards: nil), cardsLeft: max(0, rounds.goal - done),
                    pace: pace, roundPlan: rounds, streakKeptToday: done > 0)
            }
            let open = progress(done: 2)
            let closed = progress(done: rounds.goal)
            #expect(DayAction(due: 12, progress: open) == .study)
            #expect(DayAction(due: 12, progress: nil) == .study)
            #expect(DayAction(due: 12, progress: closed) == .catchUp)
            #expect(DayAction(due: 0, progress: closed) == .pushOn)
            #expect(DayAction(due: 0, progress: open) == .pushOn)

            func title(_ action: DayAction) -> String? {
                Mirror(reflecting: MenuKey.studyDay.title(MenuState(dayAction: action))).children.first { $0.label == "key" }?.value as? String
            }
            #expect(title(.study) == "Study")
            #expect(title(.catchUp) == "Keep Going")
            #expect(title(.pushOn) == "Learn 10 New Words")
        }

        /// The cheat sheet lists the keys of the table, which are the menus' keys: the same twelve, each once, with the
        /// caps the menus print.
        @Test func theCheatSheetListsTheKeysOfTheMenus() {
            let keys = MenuKey.allCases.map { $0.caps.joined() }
            #expect(keys == ["⌘N", "⌘O", "⇧⌘I", "⌘L", "⌥⌘L", "⇧⌘L", "⌘;", "⌘1", "⌘2", "⌘3", "⌘4", "⌥⌘I"])
        }
    }
}
