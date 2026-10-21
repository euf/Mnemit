import SwiftUI

/// The root of the app: lists the decks it has opened (#288) with what today's session
/// takes from each, and opens the one it showed last at launch (#285). Decks it doesn't know yet open through the file
/// picker, or from the Files app. The open deck lies on top, see `DeckScreen`; going
/// back closes it.
///
/// The learner can also choose the folder that holds the decks: every deck in it is
/// listed, and pulling the list down looks for new ones. At the first launch the
/// introduction covers the screen, `OnboardingView`; the menu brings it back. The daily
/// reminder and the number on the app icon follow the counts, see `Reminders`.
struct StartScreen: View {
    @State private var knownDecks = KnownDecks()
    @State private var deckCounts = KnownDeckCounts()
    @State private var reminders = Reminders()
    @State private var deck: OpenDeck?
    @State private var isChoosing = false
    @State private var choosesFolder = false
    @State private var hasReopened = false
    @State private var showsSettings = false
    @State private var showsIntroduction = false
    @State private var wantsIntroduction = false
    @AppStorage("IntroductionSeen") private var hasSeenIntroduction = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                if knownDecks.byName.isEmpty {
                    ContentUnavailableView {
                        Label("No Deck Open", systemImage: "rectangle.stack")
                    } description: {
                        Text("Decks are created in Mnemit on the Mac. Choose the Mnemit folder in iCloud Drive, or open a single deck.")
                    } actions: {
                        Button("Choose Mnemit Folder…") { choose(folder: true) }
                            .buttonStyle(.borderedProminent)
                        Button("Open Deck…") { choose(folder: false) }
                    }
                } else {
                    deckList
                }
            }
            .navigationTitle(Text(verbatim: "Mnemit"))
            .toolbar {
                Menu("More", systemImage: "ellipsis.circle") {
                    Button("Choose Mnemit Folder…", systemImage: "folder") { choose(folder: true) }
                    Button("Open Deck…", systemImage: "plus") { choose(folder: false) }
                    Divider()
                    Button("Settings", systemImage: "gearshape") { showsSettings = true }
                    Button("Show Introduction", systemImage: "questionmark.circle") { showsIntroduction = true }
                }
            }
            // The introduction covers the screen once the sheet has gone.
            .sheet(isPresented: $showsSettings, onDismiss: showIntroductionAfterSettings) {
                SettingsView(reminders: reminders) { wantsIntroduction = true }
            }
            .navigationDestination(item: $deck) { deck in
                DeckScreen(deck: deck, knownDecks: knownDecks)
            }
        }
        .deckPicker(isPresented: $isChoosing, choosesFolder: choosesFolder) { url in
            if url.isDeck {
                openDeck(at: url)
            } else if knownDecks.chooseFolder(url) > 0 {
                Task { await refreshCounts() }
            }
        }
        .fullScreenCover(isPresented: $showsIntroduction) {
            OnboardingView(knownDecks: knownDecks, reminders: reminders, onFinish: finishIntroduction)
        }
        .onOpenURL(perform: openDeck(at:))
        .onAppear {
            reopen()
            if !hasSeenIntroduction {
                showsIntroduction = true
            }
        }
        .onChange(of: deck) { previous, _ in
            if let previous {
                Task {
                    // The deck saves what it changed before the list reads the file.
                    await previous.close()
                    await refreshCounts()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                deck?.suspend()
                reminders.rescheduleBeforeSuspending(decks: knownDecks.byName, open: deck)
            case .active: deck?.resume()
            default: break
            }
        }
        .onChange(of: reminders.isEnabled) { Task { await rescheduleReminders() } }
        .onChange(of: reminders.minutes) { Task { await rescheduleReminders() } }
        // At launch and whenever the app comes back to the front. An open deck shows its
        // own counts, and the list reads again once the deck is closed.
        .task(id: scenePhase) {
            if scenePhase == .active, deck == nil {
                knownDecks.refreshFolder()
                await refreshCounts()
            }
        }
    }

    /// The known decks; removing one from the list leaves its file alone, unless it lies in
    /// the folder: the list would take it up again.
    private var deckList: some View {
        List(knownDecks.byName) { known in
            Button {
                openDeck(at: known.url)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Label(known.name, systemImage: "rectangle.stack")
                    if let counts = deckCounts.counts[known.url] {
                        StudyCountsLine(counts: counts)
                    }
                }
            }
            .tint(.primary)
            .swipeActions {
                if !knownDecks.isInFolder(known.url) {
                    Button("Remove from List", systemImage: "minus.circle", role: .destructive) {
                        knownDecks.forget(known.url)
                    }
                }
            }
        }
        .refreshable {
            knownDecks.refreshFolder()
            await refreshCounts()
        }
    }

    private func choose(folder: Bool) {
        choosesFolder = folder
        isChoosing = true
    }

    /// Reads the counts of every deck and then sets the reminders by them.
    private func refreshCounts() async {
        await deckCounts.refresh(knownDecks.byName)
        await rescheduleReminders()
    }

    private func rescheduleReminders() async {
        await reminders.reschedule(decks: knownDecks.byName, open: deck)
    }

    private func showIntroductionAfterSettings() {
        if wantsIntroduction {
            wantsIntroduction = false
            showsIntroduction = true
        }
    }

    private func finishIntroduction() {
        hasSeenIntroduction = true
        showsIntroduction = false
        Task {
            knownDecks.refreshFolder()
            await refreshCounts()
        }
    }

    /// Opens the deck opened last, once, at launch.
    private func reopen() {
        guard !hasReopened else { return }
        hasReopened = true
        if deck == nil, let url = knownDecks.last {
            deck = OpenDeck(url: url)
        }
    }

    private func openDeck(at url: URL) {
        guard deck?.url != url else { return }
        deck = OpenDeck(url: url)
    }
}

/// An open deck: its overview once the file is read, else why it couldn't be.
///
/// The deck view shows what the `VersionMerger` reports: an alert from here would come
/// while a study session covers the screen, and get lost.
private struct DeckScreen: View {
    var deck: OpenDeck
    var knownDecks: KnownDecks

    var body: some View {
        Group {
            if let document = deck.document {
                DeckView(document: document, fileURL: deck.url, isEditable: deck.isEditable, merger: deck.merger)
                    .onAppear { knownDecks.remember(deck.url) }
            } else if let failure = deck.failure {
                ContentUnavailableView("The deck could not be opened", systemImage: "exclamationmark.triangle", description: Text(failure))
            } else {
                ProgressView()
            }
        }
        .navigationTitle(Text(verbatim: deck.name))
        .navigationBarTitleDisplayMode(.inline)
    }
}
