import SwiftUI
import VocabCore

/// A deck, pushed on Today by the tap on its row: what today's plan takes from it, its cards,
/// the practices, the statistics and the options, with Study This Deck at the bottom. Rename and
/// Delete are in the menu of the bar.
///
/// The deck is held open by `PushedDecks` for as long as the screen is on the stack, so the
/// screens it pushes show the same document. A study stream started from here takes the deck
/// over from the stack, see `StudyRun`.
struct DeckScreen: View {
    var deck: OpenDeck
    /// What the list read from the file, for the first frame.
    var knownCounts: StudyCounts?
    var start: (StudyModel.Entry) -> Void
    var rename: (String) async throws -> Void
    var delete: () async throws -> Void
    /// Opens the browser of the shared decks.
    var showAnkiWeb: () -> Void = {}
    /// The deck was paused or resumed from its menu.
    var didChangePause: () -> Void = {}

    var body: some View {
        DeckContent(
            name: deck.name, knownCounts: knownCounts, document: deck.document, failure: deck.failure, merger: deck.merger,
            canEdit: deck.isEditable, start: start, rename: rename, delete: delete, showAnkiWeb: showAnkiWeb, didChangePause: didChangePause
        )
        .background {
            if let document = deck.document {
                DocumentAttachment(document: document, deck: deck)
            }
        }
    }
}

/// Keeps the document attached to the merger of its deck, see `documentSync`.
struct DocumentAttachment: View {
    @ObservedObject var document: VocabularyDocument
    var deck: OpenDeck

    var body: some View {
        Color.clear
            .documentSync(document, fileURL: deck.url, isEditable: deck.isEditable, merger: deck.merger, isInSession: false)
    }
}

/// The content of the screen. Shows what it is given, so the snapshot test can render it.
struct DeckContent: View {
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
    var rename: (String) async throws -> Void
    var delete: () async throws -> Void
    var showAnkiWeb: () -> Void = {}
    var didChangePause: () -> Void = {}

    @State private var showsRename = false
    @State private var confirmsDelete = false
    @State private var showsAddCards = false
    @State private var isChoosingImport = false
    /// The file of "Import Cards…", for its preview sheet.
    @State private var importedFile: ImportedFile?
    @State private var deleteFailure: String?

    var body: some View {
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
                LoadedSections(
                    document: document, merger: merger, canEdit: canEdit, start: start, addCards: { showsAddCards = true },
                    importCards: { isChoosingImport = true }, showAnkiWeb: showAnkiWeb)
            } else if failure == nil, let knownCounts {
                Section {
                    CountsRow(counts: knownCounts)
                } header: {
                    Text("Today")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("More", systemImage: "ellipsis") {
                    Button("Rename…", systemImage: "pencil") { showsRename = true }
                    if let document {
                        PauseDeckButton(document: document, canEdit: canEdit, didChange: didChangePause)
                        ExportLink(document: document, name: name)
                    }
                    Button("Delete Deck", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                }
            }
        }
        .safeAreaBar(edge: .bottom) {
            StudyButton(isDue: studyIsDue, due: due, title: "Study This Deck") { start(.study) }
                .disabled(!canEdit || (document?.deck.cards.isEmpty ?? true))
        }
        .sheet(isPresented: $showsRename) {
            RenameDeckSheet(currentName: name) { newName in
                try await rename(newName)
                showsRename = false
            }
        }
        .sheet(isPresented: $showsAddCards) {
            if let document {
                AddCardsSheet(document: document)
            }
        }
        .cardFileImporter(isPresented: $isChoosingImport) { importedFile = $0 }
        .sheet(item: $importedFile) { file in
            if let document {
                ImportPreviewSheet(document: document, file: file)
            }
        }
        .confirmationDialog("Delete “\(name)”?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete Deck", role: .destructive) {
                Task {
                    do {
                        try await delete()
                    } catch {
                        deleteFailure = error.localizedDescription
                    }
                }
            }
        } message: {
            Text("The deck moves to the Trash, from where you can put it back.")
        }
        .alert("The Deck Could Not Be Deleted", isPresented: Binding(get: { deleteFailure != nil }, set: { if !$0 { deleteFailure = nil } })) {
            Button("OK") {}
        } message: {
            Text(deleteFailure ?? "")
        }
    }

    /// Today's counts of the deck, from the document once it is read.
    private var counts: StudyCounts? {
        document?.dueCards.counts ?? knownCounts
    }

    private var due: Int { counts?.total ?? 0 }

    /// Study, or Keep Going when nothing is due: the stream then opens at its rest.
    private var studyIsDue: Bool { counts.map { $0.total > 0 } ?? true }
}

/// "Pause Deck" or, for a paused deck, "Resume Deck", in the menu of the deck screen. Watches the document,
/// so the item turns over as soon as the deck is paused.
private struct PauseDeckButton: View {
    @ObservedObject var document: VocabularyDocument
    var canEdit: Bool
    var didChange: () -> Void

    var body: some View {
        let isPaused = document.deck.learningOptions.isPaused
        Group {
            if isPaused {
                Button("Resume Deck", systemImage: "play.circle", action: toggle)
            } else {
                Button("Pause Deck", systemImage: "pause.circle", action: toggle)
            }
        }
        .disabled(!canEdit || !document.isReadyToEdit)
    }

    private func toggle() {
        document.setPaused(!document.deck.learningOptions.isPaused)
        didChange()
    }
}

/// The sections that need the deck itself.
private struct LoadedSections: View {
    @ObservedObject var document: VocabularyDocument
    var merger: VersionMerger
    var canEdit: Bool
    var start: (StudyModel.Entry) -> Void
    var addCards: () -> Void
    var importCards: () -> Void
    var showAnkiWeb: () -> Void

    var body: some View {
        let counts = document.dueCards.counts
        let now = document.clock.now
        let mistakes = document.deck.mistakes(onDayOf: now, calendar: document.calendar).count
        let newest = document.deck.newestBatchIDs.count
        let isEditable = canEdit && document.isReadyToEdit

        if let failure = merger.failure {
            Notice(title: "Another version of this deck could not be merged", message: Text(failure)) {
                merger.failure = nil
            }
        }

        Section {
            CountsRow(counts: counts)
        } header: {
            Text("Today")
        } footer: {
            if document.deck.learningOptions.isPaused {
                Text("Paused. Today's plan leaves this deck out.")
            } else if counts.total == 0, let nextDue = counts.nextDue {
                Text("Nothing due. Next review \(Format.due(nextDue, now: now))")
            } else {
                Text("What today's plan takes from this deck.")
            }
        }

        Section {
            NavigationLink {
                CardBrowserScreen(document: document, canEdit: canEdit, addCards: addCards)
            } label: {
                LabeledContent {
                    Text(document.deck.cards.count, format: .number)
                        .monospacedDigit()
                } label: {
                    RowLabel(title: "Cards", symbol: "rectangle.stack")
                }
            }
            Button(action: addCards) {
                RowLabel(title: "Add Cards", symbol: "plus")
            }
            .tint(.primary)
            .disabled(!isEditable)
            Button(action: importCards) {
                RowLabel(title: "Import Cards…", symbol: "square.and.arrow.down")
            }
            .tint(.primary)
            .disabled(!isEditable)
            Button(action: showAnkiWeb) {
                RowLabel(title: "Shared Decks on AnkiWeb", symbol: "safari")
            }
            .tint(.primary)
        }

        if canEdit, mistakes > 0 || newest > 0 {
            Section {
                if newest > 0 {
                    Button {
                        start(.practiceNewest)
                    } label: {
                        RowLabel(title: "Practice Newest Words", symbol: "rectangle.stack.badge.play")
                    }
                    .tint(.primary)
                }
                if mistakes > 0 {
                    Button {
                        start(.practiceMistakes)
                    } label: {
                        RowLabel(title: "Practice Today's Mistakes", symbol: "arrow.counterclockwise")
                    }
                    .tint(.primary)
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
                RowLabel(title: "Statistics", symbol: "chart.bar")
            }
            NavigationLink {
                DeckOptionsScreen(document: document)
            } label: {
                RowLabel(title: "Options", symbol: "slider.horizontal.3")
            }
        }
    }
}

/// The title of a row in the text colour, its symbol in the accent: the accent is a glyph here,
/// not text. In a sheet, whose dark rows are raised, it is the lighter accent of raised surfaces.
struct RowLabel: View {
    var title: LocalizedStringKey
    var symbol: String

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(Color.appAccentOnRaised)
        }
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

/// What the `VersionMerger` reports, at the top of the screen until dismissed.
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
