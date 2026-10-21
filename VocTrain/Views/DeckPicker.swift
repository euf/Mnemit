import SwiftUI

extension View {
    /// The file picker for the folder of decks or for a single deck, whichever
    /// `choosesFolder` says when it is presented. Two `fileImporter`s on one view would
    /// cancel each other, so one serves both; `onPick` tells the result apart with
    /// `URL.isDeck`.
    func deckPicker(isPresented: Binding<Bool>, choosesFolder: Bool, onPick: @escaping (URL) -> Void) -> some View {
        fileImporter(isPresented: isPresented, allowedContentTypes: choosesFolder ? [.folder] : [.vocabularyDeck]) { result in
            if case let .success(url) = result {
                onPick(url)
            }
        }
    }
}

extension URL {
    /// Whether this is a deck, a package with the extension `voctrain`.
    var isDeck: Bool {
        pathExtension == "voctrain"
    }
}
