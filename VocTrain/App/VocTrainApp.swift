import SwiftUI

/// The iPhone app: studies a deck that the Mac app keeps, opened from iCloud Drive or
/// the Files app (#254). It never edits cards; that is left to the Mac app.
///
/// The deck is the same `VocabularyDocument` as on the Mac, from the folder `Shared`.
/// The app opens and saves it itself, without `DocumentGroup`: it starts on Today, which
/// lists the decks and starts studying with one tap, see `StartScreen`.
@main
struct VocTrainApp: App {
    var body: some Scene {
        WindowGroup {
            StartScreen()
        }
    }
}
