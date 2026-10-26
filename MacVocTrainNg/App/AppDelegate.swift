import AppKit

/// What SwiftUI's `Window` leaves to AppKit: the files Finder hands over, a click on the Dock icon, and quitting.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The window's model; a test gives its own.
    var shell = Shell.shared
    /// Answers AppKit once the decks are saved; a test records the answer instead.
    var replyToTerminate: (Bool) -> Void = { NSApp.reply(toApplicationShouldTerminate: $0) }

    /// ⌘W closes the window and leaves the app running, for the Dock icon to bring the window back. SwiftUI quits
    /// an app of a single `Window` scene with its window unless this says no (measured 26.10.2026).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// No empty document and no Open panel at launch: the window opens on Today.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    /// Finder, the Dock or another app hands over files; implementing this takes the opening of decks away from AppKit.
    func application(_ application: NSApplication, open urls: [URL]) {
        shell.receive(urls)
    }

    /// A click on the Dock icon brings the window forward, back from ⌘W too, whatever other window of the app is open:
    /// SwiftUI reopens its window only for an app that shows none (measured with the test host's windows open).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        shell.showWindow()
        return false
    }

    /// Quitting saves every open deck first, a grade made a moment ago included, and then answers.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task {
            await shell.closeAll()
            replyToTerminate(true)
        }
        return .terminateLater
    }
}
