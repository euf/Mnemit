import Foundation

/// A deck the app has opened, as the start screen lists it (#288).
struct KnownDeck: Identifiable, Hashable {
    let url: URL

    var id: URL { url }

    /// The name of the deck, without the extension.
    var name: String {
        url.deletingPathExtension().lastPathComponent
    }
}
