import AppKit
import SwiftUI

/// The window of the deck browser (`DeckWebBrowserView`), from the welcome window and the File
/// menu: the learner browses the shared decks, and the file they download fills a new deck of the
/// shell, the way of a package that Finder opens. One window; asking again brings it to the front.
@MainActor
enum DeckWebWindow {
    private static var window: NSWindow?

    static func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let browser = DeckWebBrowser()
        browser.onFile = { file in
            close()
            Task { await Shell.shared.importIntoNewDeck(from: file) }
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: DeckWebBrowserView(browser: browser, done: nil).brandTint()))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.title = String(localized: "Shared Decks")
        window.setContentSize(NSSize(width: 1000, height: 760))
        window.isReleasedWhenClosed = false
        window.center()
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            MainActor.assumeIsolated { Self.window = nil }
        }
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    static func close() {
        window?.close()
    }
}
