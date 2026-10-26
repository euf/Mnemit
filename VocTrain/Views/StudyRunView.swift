import SwiftUI
import VocabCore

/// What covers the screen while the learner studies: the stream once the decks are read, before
/// it a spinner, or why no deck could be opened.
struct StudyRunView: View {
    var run: StudyRun
    var ring: DailyRingModel
    var knownDecks: KnownDecks
    /// What today's plan takes from each deck.
    var counts: [URL: StudyCounts]
    var onClose: () -> Void

    var body: some View {
        RunStream(run: run, ring: ring, knownDecks: knownDecks, onClose: onClose)
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

/// The stream over the decks of the run, and what it needs around it: each deck's document attached
/// to its merger, and the ring that follows the reviews of all of them.
private struct RunStream: View {
    var run: StudyRun
    var ring: DailyRingModel
    var knownDecks: KnownDecks
    var onClose: () -> Void
    @State private var model: StudyModel?
    @Environment(\.scenePhase) private var scenePhase

    /// The decks a stream may change: read, writable, with the undo manager of the UIDocument
    /// attached (#305).
    private var ready: [VocabularyDocument] {
        run.decks.compactMap { deck in
            deck.document.flatMap { deck.isEditable && $0.isReadyToEdit ? $0 : nil }
        }
    }

    /// Every deck is ready or could not be opened.
    private var settled: Bool {
        run.decks.allSatisfy { deck in
            deck.failure != nil || (deck.document.map { deck.isEditable && $0.isReadyToEdit } ?? false)
        }
    }

    var body: some View {
        Group {
            if let model {
                StudyView(model: model, ring: ring, onClose: onClose)
            } else {
                StudyPlaceholder(failure: settled && ready.isEmpty ? run.decks.compactMap(\.failure).first : nil, onClose: onClose)
            }
        }
        .background {
            ForEach(run.decks) { deck in
                if let document = deck.document {
                    DeckSync(deck: deck, document: document, isInSession: model != nil, onReady: start, onChange: { refreshRing() })
                }
            }
        }
        .onChange(of: run.decks.compactMap(\.failure).count, initial: true) { start() }
        .onAppear {
            knownDecks.remember(run.deck.url)
            refreshRing(reload: true)
        }
        .onChange(of: scenePhase) { _, phase in
            model?.setActive(phase == .active)
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

    /// Opens the stream once every deck is ready or failed.
    private func start() {
        guard model == nil, settled, !ready.isEmpty else { return }
        model = StudyModel(documents: ready, entry: run.entry, ring: ring)
        model?.setActive(scenePhase == .active)
    }

    /// Evaluates the ring over the decks of the run, as they are now, and the other known ones, as their
    /// files are. `reload` reads those files again.
    private func refreshRing(reload: Bool = false) {
        let others = knownDecks.byName.map(\.url).filter { url in !run.decks.contains { KnownDecks.isSameFile($0.url, url) } }
        ring.refresh(documents: run.decks.compactMap(\.document), files: others, reloadFiles: reload)
    }
}

/// Keeps one deck of the run in step with its file, says when it is ready, and when it changes.
private struct DeckSync: View {
    var deck: OpenDeck
    @ObservedObject var document: VocabularyDocument
    var isInSession: Bool
    var onReady: () -> Void
    var onChange: () -> Void

    var body: some View {
        Color.clear
            .documentSync(document, fileURL: deck.url, isEditable: deck.isEditable, merger: deck.merger, isInSession: isInSession)
            .onChange(of: deck.isEditable && document.isReadyToEdit, initial: true) { onReady() }
            .onReceive(document.deckDidChange) { onChange() }
    }
}
