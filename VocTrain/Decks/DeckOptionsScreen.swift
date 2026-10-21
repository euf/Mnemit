import SwiftUI

/// Placeholder: the real options screen comes from the other branch of wave 2.
struct DeckOptionsScreen: View {
    var document: VocabularyDocument

    init(document: VocabularyDocument) {
        self.document = document
    }

    var body: some View {
        Text(verbatim: "Options")
            .navigationTitle(Text(verbatim: "Options"))
    }
}
