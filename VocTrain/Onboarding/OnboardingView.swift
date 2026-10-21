import SwiftUI
import VocabCore

/// The introduction: shown once at the first launch, and again from the menu of the start
/// screen. It finds the learner's decks, lets them try the four swipes on a sample card,
/// tells which grade to press when, and offers the daily reminder.
struct OnboardingView: View {
    /// Where the decks are chosen; the start screen lists what it finds.
    var knownDecks: KnownDecks
    var reminders: Reminders
    /// Called when the introduction is over, whichever way it ended.
    var onFinish: () -> Void

    private enum Step {
        case welcome, gestures, rules, reminder
    }

    @State private var step = Step.welcome

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            Group {
                switch step {
                case .welcome:
                    WelcomeStep(knownDecks: knownDecks) { step = .gestures }
                case .gestures:
                    GesturePracticeView(next: { step = .rules }, skip: { step = .reminder })
                case .rules:
                    RulesStep(done: { step = .reminder })
                case .reminder:
                    ReminderStep(reminders: reminders, finish: onFinish)
                }
            }
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }
}

/// The first step: the app, and the folder with the decks.
private struct WelcomeStep: View {
    var knownDecks: KnownDecks
    var next: () -> Void

    @State private var isChoosing = false
    @State private var choosesFolder = true
    @State private var problem: String?

    /// How many deck names the list shows; the rest is counted.
    private static let listed = 5

    var body: some View {
        let decks = knownDecks.byName
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

            if !decks.isEmpty {
                found(decks)
                    .padding(.top, 32)
            }
            Spacer()

            VStack(spacing: 8) {
                if decks.isEmpty {
                    Button {
                        choose(folder: true)
                    } label: {
                        Text("Choose Mnemit Folder")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Open a Single Deck…") { choose(folder: false) }
                } else {
                    Button(action: next) {
                        Text("Continue")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Choose Another Folder…") { choose(folder: true) }
                }
                Text("Your decks live in iCloud Drive, in the Mnemit folder.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
        .deckPicker(isPresented: $isChoosing, choosesFolder: choosesFolder, onPick: picked)
    }

    private func found(_ decks: [KnownDeck]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text("Found \(decks.count) decks")
                    .fontWeight(.semibold)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
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

    private func choose(folder: Bool) {
        choosesFolder = folder
        isChoosing = true
    }

    private func picked(_ url: URL) {
        if url.isDeck {
            knownDecks.remember(url)
            problem = nil
        } else if knownDecks.chooseFolder(url) > 0 {
            problem = nil
        } else {
            problem = String(localized: "“\(url.lastPathComponent)” holds no Mnemit decks. Choose the Mnemit folder.")
        }
    }
}

/// The third step: which grade to press when.
private struct RulesStep: View {
    var done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("When to Press What")
                        .font(.title.bold())
                    Text("Four swipes, four grades")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Skip", action: done)
            }

            VStack(spacing: 12) {
                ForEach([Grade.again, .hard, .good, .easy], id: \.self) { grade in
                    HStack(spacing: 14) {
                        Text(grade.arrow)
                            .font(.title2.bold())
                            .foregroundStyle(grade.onColor)
                            .frame(width: 44, height: 44)
                            .background(grade.color, in: Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(grade.buttonTitle)
                                .font(.headline)
                            Text(Self.rule(of: grade))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityElement(children: .combine)
                }
            }

            Spacer(minLength: 0)

            Button(action: done) {
                Text("Got It")
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(20)
    }

    private static func rule(of grade: Grade) -> String {
        switch grade {
        case .again: String(localized: "You didn't recall it, or got it wrong")
        case .hard: String(localized: "You recalled it, with effort")
        case .good: String(localized: "The normal case")
        case .easy: String(localized: "You knew it instantly")
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
