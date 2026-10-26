import AppKit
import SwiftUI
import Testing

@testable import MacVocTrain
@testable import VocabCore

extension DeckFileTests {
    /// Draws the Mac's one window (`ShellView`) over decks in a temporary folder, light and dark, to PNGs to look at: Today,
    /// a deck and Progress. The directory is `STUDY_SHOTS_DIR` (pass it as `TEST_RUNNER_STUDY_SHOTS_DIR`), else the
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
            #expect(shell.sidebar.today == shell.due)

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
                        #expect(shell.deckActions.canStartSession)
                    }
                    try await Task.sleep(for: .seconds(1.5))
                    hosting.layoutSubtreeIfNeeded()
                    let rep = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
                    hosting.cacheDisplay(in: hosting.bounds, to: rep)
                    let data = try #require(rep.representation(using: .png, properties: [:]))
                    let file = "shell-\(name)-\(dark ? "dark" : "light").png"
                    do {
                        try data.write(to: directory.appendingPathComponent(file))
                    } catch {
                        try data.write(to: FileManager.default.temporaryDirectory.appendingPathComponent(file))
                    }
                }
            }
            await f.finish()
        }
    }
}
