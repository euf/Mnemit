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
        Task { await WelcomeWindow.showAtLaunchIfNoDocumentOpens() }
    }

    /// Finder, the Dock or another app hands over files. An Anki package takes the welcome
    /// window's route: a new deck whose window starts the import, named after the Anki deck,
    /// not a document window of the package. Implementing this takes the opening of decks away
    /// from AppKit, so they go to the document controller here.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.isAnkiPackage {
                WelcomeRequest.importIntoNewDeck(from: url)
            } else {
                NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
                    if let error {
                        NSApp.presentError(error)
                    }
                }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard WelcomeWindow.isEnabled, NSDocumentController.shared.documents.isEmpty else { return true }
        WelcomeWindow.show()
        return false
    }
}
