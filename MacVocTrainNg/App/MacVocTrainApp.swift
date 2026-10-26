import SwiftUI

@main
struct MacVocTrainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    static let shellID = "shell"

    init() {
        Preferences.setUpDefaults()
    }

    var body: some Scene {
        // The one window: Today, Progress and the decks.
        Window(String("Mnemit"), id: Self.shellID) {
            ShellView(shell: .shared)
                .brandTint()
        }
        .commands {
            AppCommands()
        }

        Settings {
            PreferencesView()
                .brandTint()
        }
    }
}

/// App-wide preferences, stored in the user defaults.
enum Preferences {
    /// AppKit's own key for reopening the decks that were open at quit, which also handles ⌥⌘Q; in the
    /// app's domain it overrides the system setting "Close windows when quitting an application".
    static let reopenDecksKey = "NSQuitAlwaysKeepsWindows"

    /// Launch opens no decks of the last run: the key is off in the app's persistent domain, which the
    /// global domain's setting can't override, and also for a learner whose version once let them turn it on.
    static func setUpDefaults(_ defaults: UserDefaults = .standard) {
        defaults.set(false, forKey: reopenDecksKey)
    }
}
