import SwiftUI

/// "New Deck": what a new deck asks first, its name, as the iPhone's New Deck sheet does. `onCreate` makes
/// the deck; Add Cards opens after it.
struct NewDeckView: View {
    /// Called with the name as a file name; the sheet creates nothing while the field is empty, so it is never `nil` here.
    var onCreate: (_ name: String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @FocusState private var isFocused: Bool

    /// - Parameters: The rest is what the sheet starts with, for a test or a snapshot.
    init(name: String = "", onCreate: @escaping (String?) -> Void) {
        self.onCreate = onCreate
        _name = State(initialValue: name)
    }

    /// The name as a file name, `nil` if the field is empty or can't name a file.
    private var fileName: String? { DeckFiles.fileName(for: name) }

    private var isInvalid: Bool { fileName == nil && !name.allSatisfy(\.isWhitespace) }

    /// Create is off while the name is empty, as on the iPhone, and while it can't name a file.
    var canCreate: Bool { fileName != nil }

    var body: some View {
        VStack(spacing: 0) {
            Text("New Deck")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.horizontal, .top], 20)

            Form {
                Section {
                    TextField("Name", text: $name)
                        .focused($isFocused)
                        .onSubmit(create)
                } footer: {
                    if isInvalid, let message = DeckFiles.Failure.invalidName.errorDescription {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create", action: create)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canCreate)
            }
            .padding(20)
        }
        .frame(width: 440)
        .defaultFocus($isFocused, true)
    }

    private func create() {
        guard canCreate else { return }
        onCreate(fileName)
        dismiss()
    }
}
