import SwiftUI

@main
struct MacVocTrainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    static let shellID = "shell"

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
