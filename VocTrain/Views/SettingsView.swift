import SwiftUI

/// The settings of the app: the daily reminder, on or off and at what time, whether Hard and Easy
/// have buttons, and the way back to the introduction.
struct SettingsView: View {
    var reminders: Reminders
    var showIntroduction: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(GradeChoice.showsFourButtonsKey) private var showsFourButtons = false

    var body: some View {
        @Bindable var reminders = reminders
        NavigationStack {
            Form {
                Section {
                    Toggle("Daily Reminder", isOn: isOn)
                    if reminders.isEnabled {
                        DatePicker("Time", selection: $reminders.time, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Reminder")
                } footer: {
                    footer
                }

                Section {
                    Toggle("Hard and Easy Buttons", isOn: $showsFourButtons)
                } footer: {
                    Text("Adds Hard and Easy buttons, and swipes down and up.")
                }

                Section {
                    Button("Show Introduction") {
                        dismiss()
                        showIntroduction()
                    }
                } footer: {
                    Text("Version \(Self.version) (\(Self.build))")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .task { await reminders.refreshStatus() }
    }

    /// Version 1.2.3 (4c4b8ed): the marketing version from VERSION and the commit the build
    /// was made from, which the install scripts stamp into the bundle.
    private static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    private static let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"

    /// The reminder is on only while the system lets the app notify: asking for the
    /// permission happens the first time it is switched on.
    private var isOn: Binding<Bool> {
        Binding {
            reminders.isEnabled
        } set: { isOn in
            guard isOn else {
                reminders.isEnabled = false
                return
            }
            Task {
                await reminders.refreshStatus()
                if reminders.status == .notDetermined {
                    _ = await reminders.requestAuthorization()
                }
                reminders.isEnabled = reminders.isAllowed
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if reminders.status == .denied {
            VStack(alignment: .leading, spacing: 4) {
                Text("Notifications for Mnemit are off in iOS Settings.")
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            }
        }
    }
}
