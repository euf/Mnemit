import SwiftUI

/// "Rename Deck": the name of the deck in the field, then `onRename` renames it, see
/// `DeckFiles.rename(_:to:)`. As in `NewDeckSheet`, what it throws stays under the field.
struct RenameDeckSheet: View {
    var currentName: String
    var onRename: (String) async throws -> Void

    init(currentName: String, onRename: @escaping (String) async throws -> Void) {
        self.currentName = currentName
        self.onRename = onRename
    }

    var body: some View {
        DeckNameSheet(title: "Rename Deck", actionTitle: "Rename", current: currentName, perform: onRename)
    }
}
