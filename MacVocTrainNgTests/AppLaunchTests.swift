import AppKit
import Testing

@testable import MacVocTrain
@testable import VocabCore

extension DeckFileTests {
    /// The app as AppKit drives it: the window at launch, Finder, the Dock and Quit. Under `DeckFileTests` for the decks.
    @MainActor @Suite(.timeLimit(.minutes(3)))
    struct AppLaunchTests {
        /// The window of the app's own `Window` scene, which the test host opens at launch like the app does.
        private func appWindow() -> NSWindow? {
            NSApp.windows.first { $0.identifier?.rawValue == MacVocTrainApp.shellID }
        }

        private func waitForAppWindow(visible: Bool = true) async throws -> NSWindow {
            try await waitUntil("the app's window is \(visible ? "shown" : "closed")", timeout: .seconds(60)) { appWindow()?.isVisible == visible }
            return try #require(appWindow())
        }

        /// What launch opens: the shell's window on Today, and no deck window and no welcome window beside it.
        @Test func theLaunchSceneIsTheShellOnToday() async throws {
            let window = try await waitForAppWindow()
            #expect(Shell.shared.selection == .today)
            #expect(window.title == String(localized: "Today"))
            let others = NSApp.windows.filter { $0 !== window && $0.isVisible && $0.windowController != nil }
            #expect(others.isEmpty, "Other windows at launch: \(others.map(\.title))")
            #expect(NSApp.windows.allSatisfy { $0.windowController?.document == nil })
            #expect(AppDelegate().applicationShouldOpenUntitledFile(NSApp) == false)
        }

        /// The File menu of the app: New Deck and Open Deck for the shell, from the document types' New and Open that
        /// went with the DocumentGroup, and nothing of the debug item that opened the shell beside the windows.
        @Test func theFileMenuNewDeckOpensTheNameSheetOfTheShell() async throws {
            _ = try await waitForAppWindow()
            let file = try #require(NSApp.mainMenu?.items.first { $0.submenu?.title == String(localized: "File") }?.submenu)
            let new = try #require(file.items.first { $0.title == String(localized: "New Deck…") })
            let open = try #require(file.items.first { $0.title == String(localized: "Open Deck…") })
            #expect(new.keyEquivalent == "n" && new.keyEquivalentModifierMask == .command)
            #expect(open.keyEquivalent == "o" && open.keyEquivalentModifierMask == .command)
            #expect(NSApp.mainMenu?.items.flatMap { $0.submenu?.items ?? [] }.contains { $0.title.contains("Open Shell") } == false)

            Shell.shared.isNamingDeck = false
            file.performActionForItem(at: file.index(of: new))
            try await waitUntil("File > New Deck asks for a name", timeout: .seconds(30)) { Shell.shared.isNamingDeck }
            Shell.shared.isNamingDeck = false
        }

        /// ⌘W leaves the app running (SwiftUI quits a single-window app with its window otherwise), and the Dock icon and a
        /// Finder open bring the window back, with another window of the app open too, as Settings is.
        @Test func theWindowComesBackAfterCommandWFromTheDockAndFromFinder() async throws {
            let delegate = AppDelegate()
            #expect(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApp) == false)

            let window = try await waitForAppWindow()
            let settings = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            settings.isReleasedWhenClosed = false
            settings.orderFront(nil)
            defer { settings.close() }
            window.close()
            #expect(!window.isVisible && settings.isVisible)
            let me = NSAppleEventDescriptor(processIdentifier: ProcessInfo.processInfo.processIdentifier)
            let reopen = NSAppleEventDescriptor(
                eventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEReopenApplication), targetDescriptor: me,
                returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
            _ = try reopen.sendEvent(options: [.noReply], timeout: 5)
            _ = try await waitForAppWindow()

            appWindow()?.close()
            delegate.application(NSApp, open: [])
            _ = try await waitForAppWindow()
        }

        /// Finder opens a deck: one of the folder is selected, one from elsewhere sits under Other Decks, `.voctrain` too.
        @Test func aFinderOpenSelectsItsDeck() async throws {
            let f = try ShellFixture(decks: [("Alpha", 2), ("Beta", 2)])
            let delegate = AppDelegate()
            delegate.shell = f.shell
            let old = f.directory.appending(path: "Old.voctrain", directoryHint: .isDirectory)
            try ShellFixture.write(cards: 1, to: old)

            delegate.application(NSApp, open: [f.url("Beta")])
            #expect(f.shell.selectedURL == f.url("Beta"))
            #expect(f.shell.others.isEmpty)

            delegate.application(NSApp, open: [old])
            #expect(f.shell.selectedURL == old.standardizedFileURL)
            #expect(f.shell.sidebar.others.map(\.url) == [old.standardizedFileURL])
            try await f.waitFor("the deck from outside is read") { f.shell.selectedDeck?.document != nil }
            await f.finish()
        }

        /// A table of the browser's download makes a deck named after the file, a second one of that name is numbered; the
        /// deck's page then shows the file's cards to choose from.
        @Test func aDownloadedTableFillsANewDeckNamedAfterTheFile() async throws {
            let f = try ShellFixture()
            let table = f.directory.appending(path: "greek core.csv")
            try "σπίτι;house\nνερό;water\n".write(to: table, atomically: true, encoding: .utf8)

            await f.shell.importIntoNewDeck(from: table)
            #expect(f.shell.selectedURL == f.url("greek core"))
            guard case let .importFile(file) = f.shell.request else {
                Issue.record("The new deck asks for the preview of the file: \(String(describing: f.shell.request))")
                return await f.finish()
            }
            #expect(file.url == table && file.package == nil)

            await f.shell.importIntoNewDeck(from: table)
            #expect(f.shell.selectedURL == f.url("greek core 2"))
            await f.finish()
        }

        /// A grade made a moment before ⌘Q is in the deck's file when the app has quit: the quit answers AppKit after the
        /// decks are saved, not before.
        @Test func quitSavesAGradeMadeJustBefore() async throws {
            let f = try ShellFixture(decks: [("Alpha", 3)])
            let (deck, document) = try await f.open("Alpha")
            var replies: [Bool] = []
            let delegate = AppDelegate()
            delegate.shell = f.shell
            delegate.replyToTerminate = { replies.append($0) }

            try f.review(deck, document, closesGroup: false)
            #expect(deck.undoManager.groupingLevel == 1)
            #expect(delegate.applicationShouldTerminate(NSApp) == .terminateLater)
            #expect(replies.isEmpty)
            try await f.waitFor("the quit has answered") { !replies.isEmpty }

            #expect(replies == [true])
            let saved = try DeckFile.read(at: f.url("Alpha"))
            #expect(saved.cards.map(\.log.count).sorted() == [0, 0, 1])
            #expect(f.shell.decks.documents.isEmpty)
            await f.finish()
        }
    }
}
