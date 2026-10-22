import SwiftUI

/// "Shared Decks on AnkiWeb": opens the shared decks of AnkiWeb in Safari. Just a link: AnkiWeb
/// has no API and its terms allow browser access only. The package the learner downloads comes
/// back through "Open in Mnemit".
struct AnkiWebLink: View {
    static let url = URL(string: "https://ankiweb.net/shared/decks")!

    var body: some View {
        Link(destination: Self.url) {
            Label("Shared Decks on AnkiWeb", systemImage: "safari")
        }
    }
}
