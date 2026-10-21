import SwiftUI

/// The iPhone app: studies a deck that the Mac app keeps, opened from iCloud Drive or
/// the Files app (#254). It never edits cards; that is left to the Mac app.
///
/// The deck is the same `VocabularyDocument` as on the Mac, from the folder `Shared`.
/// The app opens and saves it itself, without `DocumentGroup`: it starts on Today, which
/// lists the decks and starts studying with one tap, see `StartScreen`.
@main
struct VocTrainApp: App {
    init() {
        // The app that hosts a test run never speaks by itself: a simulator plays the voice
        // through the speakers of the Mac.
        let environment = ProcessInfo.processInfo.environment
        if ["XCTestConfigurationFilePath", "XCTestBundlePath", "XCTestSessionIdentifier"].contains(where: { environment[$0] != nil }) {
            UserDefaults.standard.set(false, forKey: GreekSpeech.autoSpeakKey)
        }
    }

    var body: some Scene {
        WindowGroup {
            StartScreen()
        }
    }
}
