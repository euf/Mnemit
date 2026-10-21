import SwiftUI

/// Placeholder: the real Add Cards sheet comes from the other branch of wave 2.
struct AddCardsSheet: View {
    var document: VocabularyDocument
    @Environment(\.dismiss) private var dismiss

    init(document: VocabularyDocument) {
        self.document = document
    }

    var body: some View {
        NavigationStack {
            Text(verbatim: "Add Cards")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) { dismiss() }
                    }
                }
        }
    }
}
