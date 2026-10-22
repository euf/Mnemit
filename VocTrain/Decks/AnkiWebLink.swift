import SwiftUI

/// "Shared Decks on AnkiWeb": opens the deck browser (`DeckWebBrowserView`) at the shared decks
/// of AnkiWeb. `StartScreen` shows the browser; what the learner downloads in it goes the way a
/// package from "Open in Mnemit" does.
struct AnkiWebLink: View {
    static let url = DeckSources.start

    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Shared Decks on AnkiWeb", systemImage: "safari")
        }
    }
}
