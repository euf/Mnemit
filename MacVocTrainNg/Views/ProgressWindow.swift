import AppKit
import SwiftUI
import VocabCore

/// The window "Progress", the iPhone's Progress screen (`ProgressScreen`) over every deck of the Mnemit folder: the
/// streak and the totals, the medals, the calendar, the ladder of memory, and How It Works. From the Today
/// window's day, the ring of a deck window's toolbar and Window ▸ Progress. One window; asking again brings it to
/// the front.
@MainActor
enum ProgressWindow {
    private static var window: NSWindow?

    static func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: Content().brandTint()))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.title = String(localized: "Progress")
        window.setContentSize(NSSize(width: 460, height: 720))
        window.isReleasedWhenClosed = false
        window.center()
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            MainActor.assumeIsolated { Self.window = nil }
        }
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    /// The day's figures, read again whenever the window comes to the front.
    private struct Content: View {
        @State private var ring = DailyRingModel()

        var body: some View {
            NavigationStack {
                if let progress = ring.progress {
                    ProgressScreen(progress: progress) {
                        Button("How It Works", systemImage: "gauge.with.dots.needle.33percent") { HowTodayWorksWindow.show() }
                            .buttonStyle(.link)
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 380, minHeight: 480)
            .onAppear { ring.refreshAllDecks(reloadFiles: true, delay: .zero) }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
                ring.refreshAllDecks(reloadFiles: true, delay: .zero)
            }
        }
    }
}
