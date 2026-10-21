import SwiftUI

/// Placeholder: the real New Deck sheet comes from the other branch of wave 2.
struct NewDeckSheet: View {
    var onCreate: (String) async throws -> Void
    @State private var name = ""
    @Environment(\.dismiss) private var dismiss

    init(onCreate: @escaping (String) async throws -> Void) {
        self.onCreate = onCreate
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
                    Button(String("Create")) {
                        Task {
                            try? await onCreate(name)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
