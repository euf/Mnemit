import SwiftUI

/// App-wide preferences (⌘,).
struct PreferencesView: View {
    @AppStorage(GreekSpeech.autoSpeakKey) private var autoSpeak = true
    @AppStorage(GradeChoice.showsFourButtonsKey) private var showsFourButtons = false
    private var folder = DeckFolder.shared

    var body: some View {
        Form {
            Section {
                Toggle("Pronounce Automatically", isOn: $autoSpeak)
            }
            Section {
                Toggle("Hard and Easy Buttons", isOn: $showsFourButtons)
            } footer: {
                Text("Adds Hard and Easy: buttons, and keys 2 and 4.")
            }
            Section {
                LabeledContent {
                    Button("Change…") { folder.choose() }
                } label: {
                    Text(folder.url?.path ?? String(localized: "Not chosen"))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .help(folder.url?.path ?? "")
                }
            } header: {
                Text("Mnemit Folder")
            } footer: {
                Text("Version \(Self.version) (\(Self.build))")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize()
    }

    /// Version 1.2.3 (4c4b8ed): the marketing version from VERSION and the commit the build
    /// was made from, which the install scripts stamp into the bundle.
    private static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    private static let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
}
