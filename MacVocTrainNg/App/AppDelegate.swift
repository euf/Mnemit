import AppKit

/// What SwiftUI's `DocumentGroup` leaves to AppKit: the first window at launch, which is
/// the welcome window while no document opens, and what a click on the Dock icon does.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// No empty document and no Open panel at launch: `applicationDidFinishLaunching` shows
    /// the welcome window unless a document opened by itself.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        !WelcomeWindow.isEnabled
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard WelcomeWindow.isEnabled else { return }
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeMainNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { WelcomeWindow.closeIfDocumentIsOpen() }
        }
        Task { await WelcomeWindow.showAtLaunchIfNoDocumentOpens() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard WelcomeWindow.isEnabled, NSDocumentController.shared.documents.isEmpty else { return true }
        WelcomeWindow.show()
        return false
    }
}
