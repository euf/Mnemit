import SwiftUI

/// The iPhone app: studies and edits decks it keeps in iCloud Drive or on the iPhone,
/// or opens from the Files app (#254). It edits cards the way the Mac app does, through
/// `VocabularyDocument+Editing`, and merges what the other device wrote, see
/// `VersionMerger`.
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
