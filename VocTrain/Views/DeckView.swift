import SwiftUI
import VocabCore

/// The details of a deck, in a sheet from the info button of its row on Today: what today's
/// plan takes from it, how many cards it has, the two practices and the statistics. Study
/// starts the deck's stream; the figures that need the whole deck come as soon as it is read.
///
/// The sheet holds the deck open. A study stream started from it takes the deck over (see
/// `StartScreen`), so the file is opened once.
struct DeckDetailsSheet: View {
    var deck: OpenDeck
    /// What the list read from the file, for the first frame.
    var knownCounts: StudyCounts?
    var start: (StudyModel.Entry) -> Void

    var body: some View {
        DeckDetails(
            name: deck.name, knownCounts: knownCounts, document: deck.document, failure: deck.failure,
            merger: deck.merger, canEdit: deck.isEditable, start: start
        )
        .background {
            if let document = deck.document {
                DocumentAttachment(document: document, deck: deck)
            }
        }
    }
}

/// Keeps the document attached to the merger of its deck, see `documentSync`.
private struct DocumentAttachment: View {
    @ObservedObject var document: VocabularyDocument
    var deck: OpenDeck

    var body: some View {
        Color.clear
            .documentSync(document, fileURL: deck.url, isEditable: deck.isEditable, merger: deck.merger, isInSession: false)
    }
}

/// The content of the sheet. Shows what it is given, so the snapshot test can render it.
struct DeckDetails: View {
    var name: String
    /// Today's counts as the list has them, until the document is read.
    var knownCounts: StudyCounts?
    var document: VocabularyDocument?
    /// Why the deck could not be opened.
    var failure: String?
    var merger: VersionMerger?
    /// Whether the file can be changed, which a study stream needs; `OpenDeck` attaches the
    /// undo manager before it shows the document (#305).
    var canEdit: Bool
    var start: (StudyModel.Entry) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let failure {
                    Section {
                        Label("The deck could not be opened", systemImage: "exclamationmark.triangle")
                        Text(failure)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if let document, let merger {
                    LoadedSections(document: document, merger: merger, canStart: canEdit, start: start)
                } else if failure == nil {
                    Section {
                        if let knownCounts {
                            CountsRow(counts: knownCounts)
                        }
                    } header: {
                        Text("Today")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    // The toolbar picks a dark label for the dark accent; white has 4.6:1 on it.
                    Button {
                        start(.study)
                    } label: {
                        Text("Study").foregroundStyle(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canEdit || (document?.deck.cards.isEmpty ?? true))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// The sections that need the deck itself.
private struct LoadedSections: View {
    @ObservedObject var document: VocabularyDocument
    var merger: VersionMerger
    var canStart: Bool
    var start: (StudyModel.Entry) -> Void

    var body: some View {
        let counts = document.dueCards.counts
        let now = document.clock.now
        let mistakes = document.deck.mistakes(onDayOf: now, calendar: document.calendar).count
        let newest = document.deck.newestBatchIDs.count
        let suspended = document.deck.suspendedCount

        if let failure = merger.failure {
            Notice(title: "Another version of this deck could not be merged", message: Text(failure)) {
                merger.failure = nil
            }
        }

        if document.deck.cards.isEmpty {
            EmptyDeckNotice()
        }

        Section {
            CountsRow(counts: counts)
        } header: {
            Text("Today")
        } footer: {
            Text("What today's plan takes from this deck.")
        }

        Section {
            LabeledContent("Cards", value: document.deck.cards.count, format: .number)
            if suspended > 0 {
                LabeledContent("Suspended", value: suspended, format: .number)
            }
            if counts.total == 0, let nextDue = counts.nextDue {
                LabeledContent("Next review", value: Format.due(nextDue, now: now))
            }
        }
        .monospacedDigit()

        if canStart, mistakes > 0 || newest > 0 {
            // The accent is a glyph here, not text: it has 3.7:1 on the dark rows.
            Section {
                if newest > 0 {
                    PracticeButton(title: "Practice Newest Words", symbol: "rectangle.stack.badge.play") { start(.practiceNewest) }
                }
                if mistakes > 0 {
                    PracticeButton(title: "Practice Today's Mistakes", symbol: "arrow.counterclockwise") { start(.practiceMistakes) }
                }
            } header: {
                Text("Practice")
            } footer: {
                Text("Practice doesn't change when cards come back")
            }
        }

        Section {
            NavigationLink {
                StatisticsScreen(document: document)
            } label: {
                Label("Statistics", systemImage: "chart.bar")
            }
        }
    }
}

/// A row that starts a practice: the title in the text colour, the symbol in the accent.
private struct PracticeButton: View {
    var title: LocalizedStringKey
    var symbol: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: symbol)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .tint(.primary)
    }
}

/// The three counts of today's plan side by side, a figure above its title. Neutral: the
/// words tell them apart, and the colours belong to the grades. A count of 0 steps back.
struct CountsRow: View {
    var counts: StudyCounts
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout =
            typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 0))
        layout {
            cell("New", counts.new)
            cell("Learning", counts.learning)
            cell("Review", counts.review)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func cell(_ title: LocalizedStringKey, _ value: Int) -> some View {
        VStack(alignment: typeSize.isAccessibilitySize ? .leading : .center, spacing: 2) {
            Text(value, format: .number)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(value > 0 ? .primary : .secondary)
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: typeSize.isAccessibilitySize ? .leading : .center)
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

/// What the `VersionMerger` reports, at the top of the details until dismissed.
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
