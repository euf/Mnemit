import SwiftUI

/// The settings of the app: the daily reminder, on or off and at what time, and the way
/// back to the introduction.
struct SettingsView: View {
    var reminders: Reminders
    var showIntroduction: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

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
                    Button("Show Introduction") {
                        dismiss()
                        showIntroduction()
                    }
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
        } else {
            Text("The reminder tells you how many cards are due in each deck. The number on the app icon is the total due today.")
        }
    }
}
