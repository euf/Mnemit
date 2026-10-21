import SwiftUI

/// App-wide preferences (⌘,).
struct PreferencesView: View {
    @AppStorage(Preferences.studyByKey) private var studyBy = Preferences.StudyBy.flashcards
    @AppStorage(Preferences.autoAdvanceKey) private var autoAdvance = true
    @AppStorage(Preferences.reopenDecksKey) private var reopenDecks = true

    var body: some View {
        Form {
            Section {
                Picker("Study by", selection: $studyBy) {
                    Text("Flashcards").tag(Preferences.StudyBy.flashcards)
                    Text("Typing").tag(Preferences.StudyBy.typing)
                }
            } footer: {
                Text("Flashcards: reveal the answer, then grade yourself. Typing: the app checks your response.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Continue automatically when the response is correct", isOn: $autoAdvance)
                    .disabled(studyBy == .flashcards)
            } footer: {
                Text("When off, you grade every review yourself, e.g. as Easy.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Reopen the decks that were open when you quit", isOn: $reopenDecks)
            } footer: {
                Text("Press ⌥⌘Q to do the opposite once.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize()
    }
}
