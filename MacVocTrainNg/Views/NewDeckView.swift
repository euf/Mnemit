import SwiftUI

/// "New Deck": what a new untitled deck asks first, its name and the mark, New words or Words I know
/// (`LearningOptions.introducesNewCards`), as the iPhone's New Deck sheet does. `onCreate` names the
/// deck, which has no file until it is saved, and sets the mark; Add Cards opens after it. Cancel
/// closes the question: the deck stays untitled with the mark it started with, New words.
struct NewDeckView: View {
    /// Called with the name, `nil` while the field is empty, and the mark.
    var onCreate: (_ name: String?, _ introducesNewCards: Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var introducesNewCards: Bool
    @FocusState private var isFocused: Bool

    /// - Parameters: The rest is what the sheet starts with, for a test or a snapshot.
    init(introducesNewCards: Bool = true, name: String = "", onCreate: @escaping (String?, Bool) -> Void) {
        self.onCreate = onCreate
        _name = State(initialValue: name)
        _introducesNewCards = State(initialValue: introducesNewCards)
    }

    /// The name as a file name, `nil` if the field is empty or can't name a file.
    private var fileName: String? { DeckFiles.fileName(for: name) }

    private var isInvalid: Bool { fileName == nil && !name.allSatisfy(\.isWhitespace) }

    var body: some View {
        VStack(spacing: 0) {
            Text("New Deck")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.horizontal, .top], 20)

            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("Untitled"))
                        .focused($isFocused)
                        .onSubmit(create)
                } footer: {
                    if isInvalid, let message = DeckFiles.Failure.invalidName.errorDescription {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
                WordsInDeckSection(introducesNewCards: $introducesNewCards)
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
                    .disabled(isInvalid)
            }
            .padding(20)
        }
        .frame(width: 440)
        .defaultFocus($isFocused, true)
    }

    private func create() {
        guard !isInvalid else { return }
        onCreate(fileName, introducesNewCards)
        dismiss()
    }
}
