import SwiftUI
import VocabCore

/// The screen of an open deck: what today's study session takes, new, learning and
/// review cards, and the start of the session.
///
/// A study session goes on when another device changes the file: `OpenDeck` merges
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
                Button(action: startStudying) {
                    studyLabel(counts)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(counts.total == 0 || !canEdit)
            } footer: {
                if counts.total == 0, let nextDue = counts.nextDue {
                    Text("Next review \(Format.due(nextDue, now: document.clock.now))")
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
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
            StudyView(model: model) { study = nil }
        }
    }

    /// Whether a study session may change the deck: the file can be written, and
    /// `OpenDeck` attached the undo manager of the UIDocument (#305).
    private var canEdit: Bool {
        isEditable && document.isReadyToEdit
    }

    private func startStudying() {
        guard canEdit else { return }
        study = StudyModel(document: document)
    }

    /// All cards of the deck, and the suspended ones.
    private var totals: Text {
        let total = document.deck.cards.count
        let suspended = document.deck.suspendedCount
        return suspended > 0 ? Text("Total cards \(total) · Suspended \(suspended)") : Text("Total cards \(total)")
    }

    /// The size of the session; "Done for today" once nothing is left to study.
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
