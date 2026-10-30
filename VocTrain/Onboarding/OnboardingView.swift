import SwiftUI
import VocabCore

/// The introduction: shown once at the first launch, and again from Settings. It starts with
/// the app, shows a new word's first showing, lets the learner try the four swipes on sample cards,
/// says in four lines how a day works, asks where the cards are kept, and offers the daily reminder.
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
                    WelcomeStep(next: advance, skip: onFinish)
                case .firstShowing:
                    FirstShowingView(done: advance)
                case .swipe:
                    // Skipping the practice goes where finishing it goes.
                    GesturePracticeView(done: advance)
                case .day:
                    DayStep(next: advance)
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

/// The first step: the app, and the way in; whoever knows what the app does can skip the whole introduction.
private struct WelcomeStep: View {
    var next: () -> Void
    /// Ends the introduction here: Today then offers New Deck, Shared Decks and the iCloud Drive folder, and Settings
    /// shows the introduction again.
    var skip: () -> Void

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
            .tint(Color.appAccent)
            .controlSize(.large)
            Button("Skip Introduction", action: skip)
                .padding(.top, 8)
        }
        .padding(20)
    }
}

/// The fourth step: how a day works, in the words of the screens: the stack, the ring, the streak, the ladder
/// (`references/learning-flow.md`). The ring fills as it shows.
private struct DayStep: View {
    var next: () -> Void
    @State private var fill = 0.0

    var body: some View {
        VStack(spacing: 0) {
            // Scrolls at the largest text sizes, so Continue stays in reach; short, it sits in the middle.
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 20) {
                        ZStack {
                            ForEach((1...3).reversed(), id: \.self) { level in
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.cardSurface)
                                    .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.035 * Double(level))) }
                                    .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color(.opaqueSeparator)) }
                                    .frame(width: 56 - 6 * CGFloat(level), height: 72)
                                    .offset(y: 5 * CGFloat(level))
                            }
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.cardSurface)
                                .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color(.opaqueSeparator)) }
                                .frame(width: 56, height: 72)
                        }
                        ProgressRing(fraction: fill, diameter: 72, filling: .smooth(duration: 1.6))
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                    .padding(.bottom, 32)
                    Text("One stack a day")
                        .font(.title.bold())
                        .padding(.bottom, 16)
                    VStack(alignment: .leading, spacing: 14) {
                        row("rectangle.stack", Text("Mnemit lays out a few minutes' worth of cards every day."))
                        row("circle.circle", Text("Recall a card and the ring moves."))
                        row("flame.fill", Text("Two minutes keep your streak. Close the ring and the day is done."))
                        row("chart.bar.fill", Text("Words climb from New to Mastered as they stick."))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.center, for: .alignment)
            Button(action: next) {
                Text("Continue")
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appAccent)
            .controlSize(.large)
            .padding(.top, 16)
        }
        .padding(20)
        .task {
            try? await Task.sleep(for: .seconds(0.4))
            fill = 0.7
        }
    }

    private func row(_ symbol: String, _ text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Color.appAccentText)
                .frame(width: 24)
                .accessibilityHidden(true)
            text
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The fifth step: where the cards are kept. iCloud Drive, in a folder named Mnemit that the
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
                    .tint(Color.appAccent)
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
                        .tint(Color.appAccent)
                        Text("Pick or create a folder named Mnemit.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        knownDecks.useLocalFolder()
                        problem = nil
                    } label: {
                        Text("Only on This iPhone")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.bordered)
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
                    .foregroundStyle(Color.appAccentText)
            }
            if decks.isEmpty {
                Divider()
                Group {
                    if knownDecks.isLocalFolder {
                        Text("Next, create your first deck.")
                    } else {
                        Text("Decks in this folder appear here.")
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
                .tint(Color.appAccent)
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
