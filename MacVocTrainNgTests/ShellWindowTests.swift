import AppKit
import Testing

@testable import MacVocTrain
@testable import VocabCore

extension DeckFileTests {
    /// The one window with the shell's view in it: the undo manager Edit ▸ Undo goes to and the window an error of a deck
    /// is shown in. The decks are `NSDocument`s without windows, so the window is the only way to them.
    @MainActor @Suite(.timeLimit(.minutes(3)))
    struct ShellWindowTests {
        /// The window and the router of its undo manager, once the view has put it in the chain.
        private func routed(_ f: ShellFixture) async throws -> (window: NSWindow, router: UndoRouter) {
            let window = f.window()
            try await f.waitFor("the window routes undo") { router(in: window) != nil }
            return (window, try #require(router(in: window)))
        }

        private func router(in window: NSWindow) -> UndoRouter? {
            var responder = window.contentView?.nextResponder
            while let current = responder {
                if let router = current as? UndoRouter { return router }
                responder = current.nextResponder
            }
            return nil
        }

        /// Where Edit ▸ Undo starts: the focus of the window, as a key press or a menu item would.
        private func start(of window: NSWindow) -> NSResponder? {
            let focus = window.firstResponder
            return focus == nil || focus === window ? window.contentView : focus
        }

        /// The responder that takes `action`, as the menu finds it: the first of the chain from the window's focus on that
        /// answers it.
        private func target(of action: String, in window: NSWindow) -> NSResponder? {
            var responder = start(of: window)
            while let current = responder, !current.responds(to: Selector(action)) {
                responder = current.nextResponder
            }
            return responder
        }

        /// What Edit ▸ Undo sends: to the responder that takes it.
        private func perform(_ action: String, in window: NSWindow) -> Bool {
            guard let target = target(of: action, in: window) else { return false }
            _ = target.perform(Selector(action), with: nil)
            return true
        }

        /// The undo manager the chain answers with, as the field editor of a text field in the window asks for it.
        private func undoManager(in window: NSWindow) -> UndoManager? {
            var responder = start(of: window)
            while let current = responder {
                if let manager = current.undoManager { return manager }
                responder = current.nextResponder
            }
            return nil
        }

        private func isLogged(_ document: VocabularyDocument) -> Bool {
            document.deck.cards.contains { !$0.log.isEmpty }
        }

        @Test func undoInOneDeckLeavesTheOtherAlone() async throws {
            let f = try ShellFixture(decks: [("Alpha", 3), ("Beta", 3)])
            let shell = f.shell
            let (window, router) = try await routed(f)
            defer { window.close() }
            let (alpha, a) = try await f.open("Alpha")
            let (beta, b) = try await f.open("Beta")
            try f.review(alpha, a)
            try f.review(beta, b)

            // Today shows no deck: the answer is a manager of the router's own, which has nothing to undo.
            #expect(undoManager(in: window) === router.ownManager)

            shell.select(.deck(f.url("Alpha")))
            #expect(undoManager(in: window) === alpha.undoManager)
            #expect(perform("undo:", in: window))
            #expect(!isLogged(a))
            #expect(isLogged(b))

            shell.select(.deck(f.url("Beta")))
            #expect(undoManager(in: window) === beta.undoManager)
            #expect(perform("undo:", in: window))
            #expect(!isLogged(b))

            // Redo comes back to the deck it was undone in.
            shell.select(.deck(f.url("Alpha")))
            #expect(perform("redo:", in: window))
            #expect(isLogged(a))
            #expect(!isLogged(b))
            await f.finish()
        }

        @Test func undoOnTodayAndProgressDoesNothing() async throws {
            let f = try ShellFixture(decks: [("Alpha", 3)])
            let shell = f.shell
            let (window, router) = try await routed(f)
            defer { window.close() }
            let (alpha, a) = try await f.open("Alpha")
            try f.review(alpha, a)

            for item in [Shell.Item.today, .progress] {
                shell.select(item)
                #expect(undoManager(in: window) === router.ownManager)
                _ = perform("undo:", in: window)
                _ = perform("redo:", in: window)
            }
            #expect(isLogged(a))
            #expect(alpha.undoManager.canUndo)
            await f.finish()
        }

        @Test func duringTheStreamUndoLeavesTheDecksStepsAlone() async throws {
            let f = try ShellFixture(decks: [("Alpha", 3)])
            let shell = f.shell
            let (window, router) = try await routed(f)
            defer { window.close() }
            let (alpha, a) = try await f.open("Alpha")
            try f.review(alpha, a)
            shell.select(.deck(f.url("Alpha")))
            #expect(undoManager(in: window) === alpha.undoManager)

            // The stream's ⌘Z is its own: Edit ▸ Undo has nothing of the deck's to take.
            shell.study(.deck(f.url("Alpha")))
            #expect(undoManager(in: window) === router.ownManager)
            _ = perform("undo:", in: window)
            #expect(isLogged(a))

            shell.endStudy()
            #expect(undoManager(in: window) === alpha.undoManager)
            await f.finish()
        }

        /// What the Edit menu shows: Undo is there for the deck shown when it has a step, and not on Today.
        @Test func theEditMenuFollowsTheDeckShown() async throws {
            let f = try ShellFixture(decks: [("Alpha", 3), ("Beta", 3)])
            let shell = f.shell
            let (window, router) = try await routed(f)
            defer { window.close() }
            let (alpha, a) = try await f.open("Alpha")
            try await f.open("Beta")
            try f.review(alpha, a)
            let undo = NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
            let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")

            // The item finds the router from the window's focus on, before the window that has an undo manager of its own.
            #expect(target(of: "undo:", in: window) === router)
            #expect(target(of: "redo:", in: window) === router)
            #expect(!router.validateMenuItem(undo))

            shell.select(.deck(f.url("Alpha")))
            #expect(router.validateMenuItem(undo))
            #expect(!router.validateMenuItem(redo))
            #expect(perform("undo:", in: window))
            #expect(!router.validateMenuItem(undo))
            #expect(router.validateMenuItem(redo))

            shell.select(.deck(f.url("Beta")))
            #expect(!router.validateMenuItem(undo))
            #expect(!router.validateMenuItem(redo))
            await f.finish()
        }

        @Test func anErrorOfADeckIsASheetOfTheWindow() async throws {
            let f = try ShellFixture(decks: [("Alpha", 3)])
            let (window, _) = try await routed(f)
            defer { window.close() }
            try await f.open("Alpha")
            let file = try #require(NSDocumentController.shared.document(for: f.url("Alpha")) as? DeckFileDocument)

            #expect(file.windowForSheet === window)
            await f.finish()
        }

        @Test func theRouterSitsOnceBetweenTheContentAndTheWindowAndGoesAgain() throws {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let content = NSView()
            window.contentView = content
            let router = UndoRouter()
            #expect(content.nextResponder === window)

            router.install(in: window)
            #expect(content.nextResponder === router)
            #expect(router.nextResponder === window)
            #expect(DeckFileDocument.sheetWindow === window)

            // Again changes nothing; the chain doesn't loop.
            router.install(in: window)
            #expect(content.nextResponder === router)
            #expect(router.nextResponder === window)

            // Edit ▸ Undo from the content reaches the router's manager, which never answers nil.
            #expect(content.undoManager === router.ownManager)
            let deck = UndoManager()
            router.provider = { deck }
            #expect(content.undoManager === deck)
            router.provider = { nil }
            #expect(content.undoManager === router.ownManager)

            router.uninstall()
            #expect(content.nextResponder === window)
            window.close()
        }
    }
}
