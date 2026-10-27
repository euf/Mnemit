import AppKit
import SwiftUI

/// Answers Edit ▸ Undo and Redo of the shell window with the undo manager of the deck the window shows. The decks are
/// `NSDocument`s without windows of their own, so their managers reach the menu only through this responder.
///
/// A responder in the chain, not the window's delegate: an `NSWindow` keeps the undo manager of its own it made at the
/// first question no delegate answered, and never asks again (measured in the tests). SwiftUI's hosting view asks as
/// soon as it is in the window, before any code of the app runs, so a delegate (`windowWillReturnUndoManager`) is too
/// late. This responder sits between the window's content and the window, which implements `undo:` itself: Undo and
/// Redo find it first, wherever the focus is in the window. A text field's own undo goes through `undoManager` of the
/// chain, which answers the same.
///
/// Where no deck applies (Today, Progress, the stream) the answer is `ownManager`, which has nothing to undo.
@MainActor
final class UndoRouter: NSResponder, NSMenuItemValidation {
    let ownManager = UndoManager()
    /// The undo manager of the deck shown, `nil` where there is none.
    var provider: @MainActor () -> UndoManager? = { nil }
    private weak var window: NSWindow?
    private weak var before: NSResponder?
    private var observation: (any NSObjectProtocol)?

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private var manager: UndoManager { provider() ?? ownManager }

    override var undoManager: UndoManager? { manager }

    @objc func undo(_ sender: Any?) {
        manager.undo()
    }

    @objc func redo(_ sender: Any?) {
        manager.redo()
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(undo(_:)):
            item.title = manager.undoMenuItemTitle
            return manager.canUndo
        case #selector(redo(_:)):
            item.title = manager.redoMenuItemTitle
            return manager.canRedo
        default:
            return false
        }
    }

    /// Puts the router in the chain of `window`, and the sheets of its decks' errors on the window. AppKit and SwiftUI
    /// put the window back as the content's next responder while the window is built, so the router looks again after
    /// each update of the window.
    func install(in window: NSWindow?) {
        guard let window, let content = window.contentView else { return }
        DeckFileDocument.sheetWindow = window
        if self.window !== window {
            stopObserving()
            self.window = window
            // AppKit posts the update on the main thread; the block hops by the main queue instead of asserting the
            // executor, which crashed a test host on 27.10 (`swift_task_isMainExecutor` on a dangling executor).
            observation = NotificationCenter.default.addObserver(forName: NSWindow.didUpdateNotification, object: window, queue: nil) { [weak self, weak window] _ in
                DispatchQueue.main.async { self?.install(in: window) }
            }
        }
        var last: NSResponder = content
        while let next = last.nextResponder, next !== window {
            if next === self { return }
            last = next
        }
        before = last
        last.nextResponder = self
        nextResponder = window
    }

    /// Takes the router out of the chain again, when the view goes.
    func uninstall() {
        if let before, before.nextResponder === self {
            before.nextResponder = window
        }
        before = nil
        stopObserving()
        window = nil
    }

    /// Unregisters the block of `install(in:)`: dropping its token alone leaves it registered with the notification centre.
    private func stopObserving() {
        if let observation { NotificationCenter.default.removeObserver(observation) }
        observation = nil
    }
}

/// Puts an `UndoRouter` in the chain of the window its view is in, over the undo manager the shell names.
struct WindowUndoRouting: NSViewRepresentable {
    var shell: Shell

    func makeCoordinator() -> UndoRouter { UndoRouter() }

    func makeNSView(context: Context) -> NSView {
        let view = RoutedView()
        view.router = context.coordinator
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.provider = { [weak shell] in shell?.undoManagerForWindow }
        context.coordinator.install(in: view.window)
    }

    static func dismantleNSView(_ view: NSView, coordinator: UndoRouter) {
        coordinator.uninstall()
    }

    private final class RoutedView: NSView {
        var router: UndoRouter?

        override func viewDidMoveToWindow() {
            router?.install(in: window)
        }
    }
}
