import SwiftUI
import VocabCore

/// The screen of an open deck: what today's plan takes, new, learning and review cards,
/// the daily ring with the streak over all known decks, and the start of the study stream.
///
/// A study stream goes on when another device changes the file: `OpenDeck` merges
/// the change into the document (#296).
struct DeckView: View {
    @ObservedObject var document: VocabularyDocument
    /// Where the document is saved.
    var fileURL: URL?
    /// `false` while the deck can only be viewed, e.g. a file that can't be written;
    /// studying is then disabled.
    var isEditable: Bool
    /// Merges the versions of the deck from the Mac; outlives the view.
    var merger: VersionMerger
    @State private var study: StudyModel?
    @State private var isShowingStatistics = false
    /// Today's reviews against the goal and the streak, over all known decks.
    @State private var ring = DailyRingModel()
    /// The other known decks, read from their files for the ring; `nil` until asked.
    @State private var otherDecks: [URL]?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let counts = document.dueCards.counts

        List {
            if let failure = merger.failure {
                Notice(title: "Another version of this deck could not be merged", message: Text(failure)) {
                    merger.failure = nil
                }
            }

            if document.deck.cards.isEmpty {
                EmptyDeckNotice()
            }

            Section {
                VStack(spacing: 12) {
                    StudyCountsColumns(counts: counts)
                    totals
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                ringRow
            }

            Section {
                Button(action: { startStudying() }) {
                    studyLabel(counts)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(document.deck.cards.isEmpty || !canEdit)
            } footer: {
                if counts.total == 0, let nextDue = counts.nextDue {
                    Text("Next review \(Format.due(nextDue, now: document.clock.now))")
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            practiceSection
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("More", systemImage: "ellipsis.circle") {
                    Button("Statistics", systemImage: "chart.bar") { isShowingStatistics = true }
                }
            }
        }
        .navigationDestination(isPresented: $isShowingStatistics) {
            StatisticsScreen(document: document)
        }
        .documentSync(document, fileURL: fileURL, isEditable: isEditable, merger: merger, isInSession: study != nil)
        .fullScreenCover(item: $study) { model in
            StudyView(model: model, ring: ring) { study = nil }
        }
        .onAppear { refreshRing(reload: true) }
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

    /// The ring with today's figures and the streak.
    private var ringRow: some View {
        HStack(spacing: 16) {
            DailyRingView(progress: ring.progress, diameter: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily Goal")
                    .font(.headline)
                if let progress = ring.progress {
                    Text("\(progress.ring.reviews) / \(progress.ring.goal)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    if progress.streak.days > 0 {
                        Label("\(progress.streak.days) days", systemImage: "flame")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    /// Practice of the mistakes of today and of the newest words, which changes no card.
    @ViewBuilder
    private var practiceSection: some View {
        let mistakes = document.deck.mistakes(onDayOf: document.clock.now, calendar: document.calendar).count
        let newest = document.deck.newestBatchIDs.count
        if canEdit, mistakes > 0 || newest > 0 {
            Section {
                if mistakes > 0 {
                    Button("Practice Mistakes (\(mistakes))") { startStudying(.practiceMistakes) }
                }
                if newest > 0 {
                    Button("Practice Newest Words (\(newest))") { startStudying(.practiceNewest) }
                }
            } footer: {
                Text("Practice doesn't change when cards come back")
            }
        }
    }

    /// Evaluates the ring over this deck and the other known ones. `reload` reads the other
    /// decks from their files again.
    private func refreshRing(reload: Bool = false) {
        if reload || otherDecks == nil {
            otherDecks = KnownDecks().byName.map(\.url).filter { url in
                fileURL.map { !KnownDecks.isSameFile(url, $0) } ?? true
            }
        }
        ring.refresh(documents: [document], files: otherDecks ?? [], reloadFiles: reload)
    }

    /// Whether a study session may change the deck: the file can be written, and
    /// `OpenDeck` attached the undo manager of the UIDocument (#305).
    private var canEdit: Bool {
        isEditable && document.isReadyToEdit
    }

    /// Opens the study stream, which rests at once if today's plan is empty, or a practice.
    private func startStudying(_ entry: StudyModel.Entry = .study) {
        guard canEdit else { return }
        study = StudyModel(document: document, entry: entry)
    }

    /// All cards of the deck, and the suspended ones.
    private var totals: Text {
        let total = document.deck.cards.count
        let suspended = document.deck.suspendedCount
        return suspended > 0 ? Text("Total cards \(total) · Suspended \(suspended)") : Text("Total cards \(total)")
    }

    /// The size of today's plan; "Done for today" once nothing is left of it, from where the
    /// stream goes on with review ahead and practice.
    @ViewBuilder
    private func studyLabel(_ counts: StudyCounts) -> some View {
        if counts.total > 0 {
            Label("Study \(counts.total)", systemImage: "graduationcap")
        } else if document.deck.cards.isEmpty {
            Label("Study", systemImage: "graduationcap")
        } else {
            Label("Done for today", systemImage: "checkmark.circle")
        }
    }
}

/// Explains a deck without cards (#266): this app never adds cards.
private struct EmptyDeckNotice: View {
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Label("This deck has no cards", systemImage: "rectangle.stack")
                    .font(.headline)
                Text("Decks are created and edited in Mnemit on the Mac. Here you only study them.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// What the `VersionMerger` reports, at the top of the deck until dismissed.
private struct Notice: View {
    var title: LocalizedStringKey
    var message: Text
    var dismiss: () -> Void

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: "exclamationmark.triangle")
                    .font(.headline)
                message
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button("Dismiss", action: dismiss)
        }
    }
}
