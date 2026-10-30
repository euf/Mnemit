import SwiftUI

/// "New Deck": a name, then `onCreate` makes the deck, see `DeckFiles.create(named:in:)`.
/// A failure it throws, a name that is taken, stays in the sheet under the field; the sheet
/// closes once the deck exists.
struct NewDeckSheet: View {
    var onCreate: (_ name: String) async throws -> Void

    var body: some View {
        DeckNameSheet(title: "New Deck", actionTitle: "Create", current: nil, perform: onCreate)
    }
}

/// The sheet of a deck's name, for a new deck and for a renamed one. The name must make a
/// file name, `DeckFiles.fileName(for:)`: until it does, the action stays off and the
/// field says why.
struct DeckNameSheet: View {
    var title: LocalizedStringKey
    var actionTitle: LocalizedStringKey
    /// The name of the deck being renamed, `nil` for a new deck: the field starts with it,
    /// and the action stays off while the name is still this one, as there is nothing to do.
    var current: String?
    var perform: (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    /// What `perform` threw, until the name changes.
    @State private var failure: String?
    @State private var isWorking = false
    @FocusState private var isFocused: Bool

    /// - Parameters:
    ///   - prefill: What the field starts with instead of `current`: a test starts a new
    ///     deck with a name.
    ///   - failure: What the sheet starts with under the field, for a snapshot.
    init(
        title: LocalizedStringKey, actionTitle: LocalizedStringKey, current: String?, prefill: String? = nil, failure: String? = nil,
        perform: @escaping (String) async throws -> Void
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.current = current
        self.perform = perform
        _name = State(initialValue: prefill ?? current ?? "")
        _failure = State(initialValue: failure)
    }

    /// The name as the file system gets it, `nil` if it can't name a file.
    private var fileName: String? { DeckFiles.fileName(for: name) }

    /// Off while the field shows an error, as for a name that can't make a file: the name has to change first.
    var canSubmit: Bool { fileName != nil && fileName != current && !isWorking && failure == nil }

    /// Why the name won't do: what the last try threw, or that it can't name a file once
    /// there is something to judge.
    var message: String? {
        if let failure { return failure }
        guard fileName == nil, !name.allSatisfy(\.isWhitespace) else { return nil }
        return DeckFiles.Failure.invalidName.errorDescription
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name, prompt: .prompt("Name"))
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit(submit)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .disabled(isWorking)
                } footer: {
                    if let message {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                        .disabled(isWorking)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(actionTitle, action: submit)
                        .disabled(!canSubmit)
                }
            }
            .defaultFocus($isFocused, true)
            .onChange(of: name) { failure = nil }
        }
        .interactiveDismissDisabled(isWorking)
        // A name needs little room, and the keyboard takes the rest.
        .presentationDetents([.medium, .large])
    }

    private func submit() {
        guard canSubmit else { return }
        isWorking = true
        failure = nil
        Task {
            if let message = await Self.attempt(name, using: perform) {
                failure = message
                isWorking = false
                AccessibilityNotification.Announcement(message).post()
            } else {
                dismiss()
            }
        }
    }

    /// Runs `perform` with `name`. Returns what it throws as the message for the field,
    /// `nil` if it succeeds.
    static func attempt(_ name: String, using perform: (String) async throws -> Void) async -> String? {
        do {
            try await perform(name)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
