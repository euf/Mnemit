import AppKit
import SwiftUI
import Testing

@testable import MacVocTrain
@testable import VocabCore

extension DeckFileTests {
    /// Draws the Mac's one window (`ShellView`) over decks in a temporary folder, light and dark, to PNGs to look at: Today,
    /// a deck and Progress, and the shortcuts sheet. The directory is `STUDY_SHOTS_DIR` (pass it as `TEST_RUNNER_STUDY_SHOTS_DIR`), else the
    /// temporary directory of the test host's container. The window is not active, so the selected row of the sidebar and
    /// the prominent buttons draw in the colours of an inactive window. The test fails only if a picture can't be made;
    /// what it shows is for a person to judge. The dark frames are not to be trusted: offscreen, the sidebar and the table
    /// draw dark while the page of the detail keeps the colours of light (measured 26.10.2026, `colorScheme` and the window's
    /// appearance alike), so dark is looked at in the live window.
    @MainActor @Suite(.timeLimit(.minutes(3)))
    struct ShellSnapshotMacTests {
        private var directory: URL {
            let path = ProcessInfo.processInfo.environment["STUDY_SHOTS_DIR"]
            let url = path.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory.appendingPathComponent("study-shots", isDirectory: true)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }

        @Test func todayADeckAndProgress() async throws {
            let f = try ShellFixture(decks: [("Greek A1–A2", 14), ("Greek B1", 6), ("Greek B2", 3)])
            let shell = f.shell
            try await f.waitUntilRead(decks: 3)
            try await f.waitFor("the ring is worked out") { shell.isDayReady }
            // The third deck is paused, as the sidebar's Paused section shows it.
            await shell.setPaused(f.url("Greek B2"), true)
            try await f.waitFor("the deck is paused") { shell.sidebar.paused.count == 1 }
            #expect(shell.canStudyDay)
            #expect(shell.dayAction == .study)
            // Today and the decks say how long the plan takes, not how many cards it has.
            guard case .minutes? = shell.sidebar.today else {
                Issue.record("Today has no minutes: \(String(describing: shell.sidebar.today))")
                return
            }
            #expect(shell.sidebar.decks.allSatisfy { if case .minutes? = $0.badge { true } else { false } })

            for dark in [false, true] {
                // A window of its own for each appearance, never shown: SwiftUI takes the colour scheme from the window it is first put in.
                let window = f.window(dark: dark, shown: false)
                defer { window.close() }
                let hosting = try #require(window.contentView)
                for (name, item) in [("today", Shell.Item.today), ("deck", .deck(f.url("Greek A1–A2"))), ("progress", .progress)] {
                    shell.select(item)
                    if case .deck = item {
                        let deck = try #require(shell.selectedDeck)
                        try await f.waitFor("the deck is open") { deck.document != nil }
                        #expect(shell.menu.canStudyDeck)
                    }
                    try await Task.sleep(for: .seconds(1.5))
                    try write(hosting, to: "shell-\(name)-\(dark ? "dark" : "light").png")
                }
            }
            await f.finish()
        }

        /// A medal's toast on Today stands under the Study button and never over the ring: in a window that is tall, and in
        /// the least one, where the page gives up the room under the button and scrolls.
        @Test func todayWithAMedalToast() async throws {
            let f = try ShellFixture(decks: [("Greek A1–A2", 14), ("Greek B1", 6)])
            try await f.waitUntilRead(decks: 2)
            try await f.waitFor("the ring is worked out") { f.shell.isDayReady }
            let toasts = MedalToasts(store: CelebratedMedals(defaults: nil), frozen: Achievement(kind: .comeback, day: 0))
            for (name, height) in [("tall", CGFloat(760)), ("short", 520)] {
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: height), styleMask: [.titled], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.appearance = NSAppearance(named: .aqua)
                window.contentView = NSHostingView(rootView: TodayPage(shell: f.shell, newDeck: {}, toasts: toasts).brandTint().frame(width: 760, height: height))
                defer { window.close() }
                try await Task.sleep(for: .seconds(1))
                try write(try #require(window.contentView), to: "shell-today-toast-\(name)-light.png")
            }
            await f.finish()
        }

        /// Help ▸ Keyboard Shortcuts outside a stream: the twelve keys of the menus over the window at its least size,
        /// where they have to fit.
        @Test func theKeyboardShortcutsOfTheMenusInTheSmallestWindow() async throws {
            let f = try ShellFixture(decks: [("Greek A1–A2", 14)])
            try await f.waitUntilRead(decks: 1)
            f.shell.shortcuts.isShown = true
            let window = f.window(width: 760, height: 520, shown: false)
            defer { window.close() }
            try await Task.sleep(for: .seconds(1))
            try write(try #require(window.contentView), to: "shell-shortcuts-light.png")
            await f.finish()
        }

        private func write(_ hosting: NSView, to file: String) throws {
            hosting.layoutSubtreeIfNeeded()
            let rep = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            let data = try #require(rep.representation(using: .png, properties: [:]))
            do {
                try data.write(to: directory.appendingPathComponent(file))
            } catch {
                try data.write(to: FileManager.default.temporaryDirectory.appendingPathComponent(file))
            }
        }
    }
}
