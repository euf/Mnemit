import SwiftUI
import VocabCore

/// One go at studying that covers the screen: a stream on one deck, or on several decks one
/// after the other when the learner starts Study. The stream knows one deck only (`StudyModel`),
/// so the queue lives here: when a deck's stream rests and another deck has cards due, the cover
/// offers "Next", and the deck of the next stream is opened then, the one before it closed.
@MainActor @Observable
final class StudyRun {
    /// What the first stream starts with; the streams after it are always the plan.
    let entry: StudyModel.Entry
    /// The deck the stream runs on now.
    private(set) var deck: OpenDeck
    /// The decks that follow, in order.
    private(set) var upcoming: [URL]
    /// Whether the stream on `deck` starts with `entry`: only the first one does.
    private(set) var isFirst = true
    /// Whether the run closes the deck it starts with. A run started from a Deck screen
    /// studies the deck the screen holds open, which the screen closes.
    let ownsDeck: Bool

    init(deck: OpenDeck, entry: StudyModel.Entry = .study, upcoming: [URL] = [], ownsDeck: Bool = true) {
        self.deck = deck
        self.entry = entry
        self.upcoming = upcoming
        self.ownsDeck = ownsDeck
    }

    /// The deck the next stream would run on.
    var next: URL? { upcoming.first }

    /// Goes on with the next deck; the one before it saves and closes in the background.
    func advance() {
        guard !upcoming.isEmpty else { return }
        let previous = deck
        deck = OpenDeck(url: upcoming.removeFirst())
        isFirst = false
        Task { await previous.close() }
    }

    /// Saves what is unsaved and lets go of the deck, if the run owns it.
    func close() async {
        if ownsDeck {
            await deck.close()
        }
    }
}

extension StudyRun: Identifiable, Hashable {
    nonisolated static func == (lhs: StudyRun, rhs: StudyRun) -> Bool {
        lhs === rhs
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

extension OpenDeck: Identifiable {
    nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }
}

/// What covers the screen while the learner studies: the deck's stream once the deck is
/// read, before it a spinner, or why the deck could not be opened.
struct StudyRunView: View {
    var run: StudyRun
    var ring: DailyRingModel
    var knownDecks: KnownDecks
    /// What today's plan takes from each deck, for what "Next" says.
    var counts: [URL: StudyCounts]
    var onClose: () -> Void

    var body: some View {
        let deck = run.deck
        Group {
            if let document = deck.document {
                DeckStream(
                    deck: deck, document: document, entry: run.isFirst ? run.entry : .study, ring: ring,
                    knownDecks: knownDecks, next: next, onNext: run.advance, onClose: onClose)
            } else {
                StudyPlaceholder(failure: deck.failure, onClose: onClose)
            }
        }
        // A new deck, a new stream: the state of the one before must not carry over.
        .id(deck.id)
    }

    private var next: (name: String, due: Int)? {
        guard let url = run.next else { return nil }
        let name = url.deletingPathExtension().lastPathComponent
        return (name, counts[url]?.total ?? 0)
    }
}

/// The deck is being read, or can't be. On the grey page of the study screen, so the cover
/// doesn't turn from white to grey when the stream appears.
struct StudyPlaceholder: View {
    var failure: String?
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let failure {
                    ContentUnavailableView("The deck could not be opened", systemImage: "exclamationmark.triangle", description: Text(failure))
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close, action: onClose)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// The stream of one open deck, and what it needs around it: the deck's document attached to
/// the merger, the ring that follows the reviews, and "Next" while the stream rests.
private struct DeckStream: View {
    var deck: OpenDeck
    @ObservedObject var document: VocabularyDocument
    var entry: StudyModel.Entry
    var ring: DailyRingModel
    var knownDecks: KnownDecks
    var next: (name: String, due: Int)?
    var onNext: () -> Void
    var onClose: () -> Void
    @State private var model: StudyModel?
    @Environment(\.scenePhase) private var scenePhase

    /// Whether a study stream may change the deck: the file can be written, and `OpenDeck`
    /// attached the undo manager of the UIDocument (#305).
    private var canEdit: Bool {
        deck.isEditable && document.isReadyToEdit
    }

    var body: some View {
        Group {
            if let model {
                StudyView(model: model, ring: ring, onClose: onClose)
                    .safeAreaInset(edge: .bottom) {
                        if model.isResting, let next {
                            NextButton(name: next.name, due: next.due, action: onNext)
                        }
                    }
            } else {
                StudyPlaceholder(failure: nil, onClose: onClose)
            }
        }
        .documentSync(document, fileURL: deck.url, isEditable: deck.isEditable, merger: deck.merger, isInSession: model != nil)
        .onChange(of: canEdit, initial: true) {
            if canEdit, model == nil {
                model = StudyModel(document: document, entry: entry)
            }
        }
        .onAppear {
            knownDecks.remember(deck.url)
            refreshRing(reload: true)
        }
        .onReceive(document.deckDidChange) { refreshRing() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshRing(reload: true) }
        }
        // The plan and the study day change as time passes.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                refreshRing()
            }
        }
    }

    /// Evaluates the ring over this deck, as it is now, and the other known ones, as their files
    /// are. `reload` reads those files again.
    private func refreshRing(reload: Bool = false) {
        let others = knownDecks.byName.map(\.url).filter { !KnownDecks.isSameFile($0, deck.url) }
        ring.refresh(documents: [document], files: others, reloadFiles: reload)
    }
}

/// Goes on with the next deck, at the bottom of the cover while the stream of this deck rests.
private struct NextButton: View {
    var name: String
    var due: Int
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Next: \(name) · \(Text("\(due) due"))")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .padding(.horizontal, Spacing.margin)
        .padding(.bottom, Spacing.gap)
    }
}
