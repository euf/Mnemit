import SwiftUI
import VocabCore

/// What the app knows about the card being asked, in a sheet: the card list's inspector, with Done under it
/// and Edit and Delete as there. The stream follows a card deleted here, see `SessionDriver`.
struct CardInfoSheet: View {
    @ObservedObject var document: VocabularyDocument
    var card: Card
    /// Opens the sheet that edits the card.
    var onEdit: (Card.ID) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            CardInspector(
                document: document, selection: [card.id], isEditable: document.isReadyToEdit, onEdit: onEdit,
                onDelete: { ids in
                    document.delete(ids)
                    dismiss()
                }, onSelect: { _ in })
            Divider()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 420, height: 520)
    }
}
