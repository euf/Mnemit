import SwiftUI

/// Placeholder: the real Rename Deck sheet comes from the other branch of wave 2.
struct RenameDeckSheet: View {
    var currentName: String
    var onRename: (String) async throws -> Void
    @State private var name: String
    @Environment(\.dismiss) private var dismiss

    init(currentName: String, onRename: @escaping (String) async throws -> Void) {
        self.currentName = currentName
        self.onRename = onRename
        _name = State(initialValue: currentName)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(String("Name"), text: $name)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String("Rename")) {
                        Task {
                            try? await onRename(name)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
