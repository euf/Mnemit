import SwiftUI
import VocabCore

/// The introduction: shown once at the first launch, and again from Settings. It starts with
/// the app, lets the learner try the four swipes on sample cards, asks where the cards are
/// kept, and offers the daily reminder.
struct OnboardingView: View {
    /// Where the decks are chosen; the start screen lists what it finds.
    var knownDecks: KnownDecks
    var reminders: Reminders
    /// Called when the introduction is over, whichever way it ended.
    var onFinish: () -> Void

    @State private var step: OnboardingStep

    /// `step` lets the snapshot tests start at a later step.
    init(knownDecks: KnownDecks, reminders: Reminders, step: OnboardingStep = .welcome, onFinish: @escaping () -> Void) {
        self.knownDecks = knownDecks
        self.reminders = reminders
        self.onFinish = onFinish
        _step = State(initialValue: step)
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            Group {
                switch step {
                case .welcome:
                    WelcomeStep(next: advance)
                case .swipe:
                    // Skipping the practice goes where finishing it goes.
                    GesturePracticeView(done: advance)
                case .sync:
                    SyncStep(knownDecks: knownDecks, next: advance)
                case .reminder:
                    ReminderStep(reminders: reminders, finish: onFinish)
                }
            }
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    private func advance() {
        if let next = step.next {
            step = next
        } else {
            onFinish()
        }
    }
}

/// The first step: the app, and one button.
private struct WelcomeStep: View {
    var next: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            // The app icon itself (BrandMark is a copy of the AppIcon PNGs, light and dark).
            Image("BrandMark")
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                .accessibilityHidden(true)
            Text(verbatim: "Mnemit")
                .font(.largeTitle.bold())
                .padding(.top, 16)
            Text("Remember a little every day")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()

            Button(action: next) {
                Text("Get Started")
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(20)
    }
}

/// The third step: where the cards are kept. iCloud Drive, in a folder named Mnemit that the
/// Mac fills with decks, or the app's own storage on the iPhone.
private struct SyncStep: View {
    var knownDecks: KnownDecks
    var next: () -> Void

    @State private var isChoosing = false
    @State private var problem: String?

    /// How many deck names the list shows; the rest is counted.
    private static let listed = 5

    var body: some View {
        let decks = knownDecks.byName
        let hasChosen = knownDecks.folder != nil || !decks.isEmpty
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "icloud")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Sync Your Cards")
                .font(.largeTitle.bold())
                .padding(.top, 16)
            Text("Mnemit keeps your cards and progress in iCloud Drive, so your iPhone and Mac stay in step.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            if hasChosen {
                summary(decks)
                    .padding(.top, 24)
            }
            Spacer()

            VStack(spacing: 8) {
                if hasChosen {
                    Button(action: next) {
                        Text("Continue")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Choose Another Folder…") { isChoosing = true }
                } else {
                    VStack(spacing: 6) {
                        Button {
                            isChoosing = true
                        } label: {
                            Text("Use iCloud Drive")
                                .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.borderedProminent)
                        Text("Pick or create a folder named Mnemit.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Button("Only on This iPhone") {
                        knownDecks.useLocalFolder()
                        problem = nil
                    }
                }
                // Keeps its height, so the buttons stay where they are.
                Text(problem ?? " ")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 36, alignment: .top)
            }
            .controlSize(.large)
        }
        .padding(20)
        .deckPicker(isPresented: $isChoosing, choosesFolder: true, onPick: picked)
    }

    /// What the chosen folder holds: the decks it has, or when there are none yet, where they
    /// will come from.
    private func summary(_ decks: [KnownDeck]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Group {
                    if decks.isEmpty {
                        Text("No decks yet")
                    } else {
                        Text("Found \(decks.count) decks")
                    }
                }
                .fontWeight(.semibold)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            if decks.isEmpty {
                Divider()
                Group {
                    if knownDecks.isLocalFolder {
                        Text("Add decks in Files, under On My iPhone → Mnemit.")
                    } else {
                        Text("Decks you create in Mnemit on the Mac appear here once they sync.")
                    }
                }
                .foregroundStyle(.secondary)
            }
            ForEach(decks.prefix(Self.listed)) { deck in
                Divider()
                Text(deck.name)
            }
            if decks.count > Self.listed {
                Divider()
                Text("and \(decks.count - Self.listed) more")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func picked(_ url: URL) {
        knownDecks.chooseFolder(url)
        // A folder without decks that isn't the Mnemit folder is not taken, and the old one stays.
        if let folder = knownDecks.folder, KnownDecks.isSameFile(folder, url) {
            problem = nil
        } else {
            problem = String(localized: "“\(url.lastPathComponent)” holds no Mnemit decks. Choose the Mnemit folder.")
        }
    }
}

/// The last step: the time of the daily reminder. Asking for the permission to notify
/// waits for "Remind Me", so the system dialog comes when the learner asked for it.
private struct ReminderStep: View {
    var reminders: Reminders
    var finish: () -> Void

    @State private var isAsking = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var reminders = reminders
        VStack(spacing: 0) {
            Spacer()
            Text("Daily Reminder")
                .font(.largeTitle.bold())
            Text("What time suits you for studying? A few minutes a day is enough.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            DatePicker("Time", selection: $reminders.time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.top, 32)
            if reminders.status == .denied {
                VStack(spacing: 4) {
                    Text("Notifications for Mnemit are off in iOS Settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .font(.footnote)
                }
                .padding(.top, 12)
            }
            Spacer()

            VStack(spacing: 8) {
                Button(action: remind) {
                    Text("Remind Me")
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAsking)
                // Leaves the reminder as it is: off at the first launch, and when the
                // introduction comes back from the menu, as the learner set it.
                Button("Not Now", action: finish)
                    .disabled(isAsking)
            }
            .controlSize(.large)
        }
        .padding(20)
        .task { await reminders.refreshStatus() }
    }

    private func remind() {
        isAsking = true
        Task {
            reminders.isEnabled = await reminders.requestAuthorization()
            isAsking = false
            finish()
        }
    }
}
