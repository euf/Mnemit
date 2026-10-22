import AppKit
import SwiftUI

/// The window at launch while no document is open, instead of the bare Open panel: it
/// opens the folder with the learner's decks, imports cards and lists recent decks. A
/// document window that opens closes it. The Window menu brings it back, and so does a
/// click on the Dock icon while no document is open.
///
/// `defaults write <bundle id> showsWelcomeWindow -bool NO` goes back to AppKit's own
/// behaviour at launch.
@MainActor
enum WelcomeWindow {
    static let enabledKey = "showsWelcomeWindow"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    private static var window: NSWindow?

    static func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: WelcomeView()))
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.title = String(localized: "Welcome to Mnemit")
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
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

    /// At launch, once documents that were open at quit, or that Finder asked for, have had
    /// time to open.
    static func showAtLaunchIfNoDocumentOpens() async {
        try? await Task.sleep(for: .milliseconds(600))
        guard NSDocumentController.shared.documents.isEmpty else { return }
        // Should AppKit have shown its Open panel anyway, the welcome window takes its place.
        for case let panel as NSOpenPanel in NSApp.windows {
            panel.cancel(nil)
        }
        show()
    }

    /// Whichever way a document opened, the welcome window has done its work.
    static func closeIfDocumentIsOpen() {
        if !NSDocumentController.shared.documents.isEmpty {
            close()
        }
    }
}

/// What the welcome window, or Finder opening an Anki package, asks of the document window it
/// opens: to start "Import Cards…", from the package if there is one.
@MainActor
enum WelcomeRequest {
    struct Request: Identifiable {
        let id = UUID()
        /// The Anki package to import; `nil` to ask for a file.
        var file: URL?
    }

    private static var pending: [Request] = []

    /// Asks the next document window to start "Import Cards…", from `file` if given.
    static func requestImportCards(from file: URL? = nil) {
        let request = Request(file: file)
        pending.append(request)
        // A request that no window took doesn't wait for an unrelated one.
        Task {
            try? await Task.sleep(for: .seconds(5))
            pending.removeAll { $0.id == request.id }
        }
    }

    /// The request of the import the welcome window made, once; windows take them in order.
    static func takeImportCards() -> Request? {
        pending.isEmpty ? nil : pending.removeFirst()
    }
}
