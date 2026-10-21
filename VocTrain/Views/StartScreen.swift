import SwiftUI

/// The root of the app: lists the decks it has opened (#288) with what today's session
/// takes from each, and opens the one it showed last at launch (#285). Decks it doesn't know yet open through the file
/// picker, or from the Files app. The open deck lies on top, see `DeckScreen`; going
/// back closes it.
struct StartScreen: View {
    @State private var knownDecks = KnownDecks()
    @State private var deckCounts = KnownDeckCounts()
    @State private var deck: OpenDeck?
    @State private var isChoosing = false
    @State private var hasReopened = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                if knownDecks.byName.isEmpty {
                    ContentUnavailableView {
                        Label("No Deck Open", systemImage: "rectangle.stack")
                    } description: {
                        Text("Decks are created in Mnemit on the Mac. Open one it saved, e.g. in iCloud Drive.")
                    } actions: {
                        Button("Open Deck…") { isChoosing = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    deckList
                }
            }
            .navigationTitle(Text(verbatim: "Mnemit"))
            .toolbar {
                if !knownDecks.byName.isEmpty {
                    Button("Open Deck…", systemImage: "plus") { isChoosing = true }
                }
            }
            .navigationDestination(item: $deck) { deck in
                DeckScreen(deck: deck, knownDecks: knownDecks)
            }
        }
        .fileImporter(isPresented: $isChoosing, allowedContentTypes: [.vocabularyDeck]) { result in
            if case let .success(url) = result {
                openDeck(at: url)
            }
        }
        .onOpenURL(perform: openDeck(at:))
        .onAppear(perform: reopen)
        .onChange(of: deck) { previous, _ in
            if let previous {
                Task {
                    // The deck saves what it changed before the list reads the file.
                    await previous.close()
                    await deckCounts.refresh(knownDecks.byName)
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: deck?.suspend()
            case .active: deck?.resume()
            default: break
            }
        }
        // At launch and whenever the app comes back to the front. An open deck shows its
        // own counts, and the list reads again once the deck is closed.
        .task(id: scenePhase) {
            if scenePhase == .active, deck == nil {
                await deckCounts.refresh(knownDecks.byName)
            }
        }
    }

    /// The known decks; removing one from the list leaves its file alone.
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
                Button("Remove from List", systemImage: "minus.circle", role: .destructive) {
                    knownDecks.forget(known.url)
                }
            }
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
