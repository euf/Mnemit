import SwiftUI
import VocabCore

/// A deck, pushed on Today by the tap on its row: its Today card (the time and the counts of the plan), then its cards, the
/// statistics and the options as rows, with Study This Deck in the bottom bar. Add Cards and Import Cards… are the
/// plus of the bar; the practices, Rename, Pause, Export and Delete are in its menu.
///
/// The deck is held open by `PushedDecks` for as long as the screen is on the stack, so the
/// screens it pushes show the same document. A study stream started from here takes the deck
/// over from the stack, see `StudyRun`.
struct DeckScreen: View {
    var deck: OpenDeck
    /// What the list read from the file, for the first frame.
    var knownCounts: StudyCounts?
    /// The day's pace, which prices the plan in minutes; `nil` until the ring is evaluated.
    var pace: Pace?
    var start: (StudyModel.Entry) -> Void
    var rename: (String) async throws -> Void
    var delete: () async throws -> Void
    /// The deck was paused or resumed from its menu.
    var didChangePause: () -> Void = {}
    /// Opens the deck again after it could not be opened.
    var retry: () -> Void = {}

    var body: some View {
        DeckContent(
            name: deck.name, knownCounts: knownCounts, pace: pace, document: deck.document, failure: deck.failure, merger: deck.merger,
            canEdit: deck.isEditable, start: start, rename: rename, delete: delete, didChangePause: didChangePause, retry: retry
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
    var pace: Pace?
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
    var didChangePause: () -> Void = {}
    /// Opens the deck again after it could not be opened.
    var retry: () -> Void = {}

    @State private var showsRename = false
    @State private var confirmsDelete = false
    @State private var showsAddCards = false
    @State private var isChoosingImport = false
    /// The file of "Import Cards…", for its preview sheet.
    @State private var importedFile: ImportedFile?
    /// The cards a sheet asked to study first, which the stream takes up once the sheet has gone.
    @State private var studyAfterSheet: [Card.ID]?
    @State private var deleteFailure: String?
    /// Whether Add Cards came up by itself for this screen's empty deck, once.
    @State private var offeredAddCards = false

    var body: some View {
        List {
            if let failure {
                Section {
                    Label("The deck could not be opened", systemImage: "exclamationmark.triangle")
                    Text(failure)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Try Again", action: retry)
                }
            }
            if let document, let merger {
                LoadedSections(document: document, merger: merger, pace: pace, canEdit: canEdit, addCards: { showsAddCards = true })
            } else if failure == nil, let headline = DeckHeadline(counts: knownCounts, pace: pace, isPaused: false, hasCards: true, now: Date()) {
                Section {
                    DeckTodayCard(headline: headline, counts: knownCounts, pace: pace, isPaused: false, now: Date())
                }
            }
        }
        .listStyle(.insetGrouped)
        // An empty deck has one thing to do: a new deck goes straight on to its first cards.
        .onChange(of: canEdit && document?.deck.cards.isEmpty == true, initial: true) { _, isEmpty in
            guard isEmpty, !offeredAddCards else { return }
            offeredAddCards = true
            showsAddCards = true
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let document {
                ToolbarItem(placement: .primaryAction) {
                    AddMenu(document: document, canEdit: canEdit, addCards: { showsAddCards = true }, importCards: { isChoosingImport = true })
                }
            }
            ToolbarItem(placement: .bottomBar) { studyButton }
            ToolbarItem(placement: .primaryAction) {
                Menu("More", systemImage: "ellipsis") {
                    if let document {
                        PracticeButtons(document: document, canEdit: canEdit, start: start)
                        Divider()
                    }
                    Button("Rename…", systemImage: "pencil") { showsRename = true }
                    if let document {
                        PauseDeckButton(document: document, canEdit: canEdit, didChange: didChangePause)
                        ExportLink(document: document, name: name)
                    }
                    Button("Delete Deck", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                }
            }
        }
        .sheet(isPresented: $showsRename) {
            RenameDeckSheet(currentName: name) { newName in
                try await rename(newName)
                showsRename = false
            }
        }
        .sheet(isPresented: $showsAddCards, onDismiss: studyAddedCards) {
            if let document {
                AddCardsSheet(document: document) { studyAfterSheet = $0 }
            }
        }
        .cardFileImporter(isPresented: $isChoosingImport) { importedFile = $0 }
        .sheet(item: $importedFile, onDismiss: studyAddedCards) { file in
            if let document {
                ImportPreviewSheet(document: document, file: file) { studyAfterSheet = $0 }
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
            Text("The deck goes to the Trash.")
        }
        .alert("The Deck Could Not Be Deleted", isPresented: Binding(get: { deleteFailure != nil }, set: { if !$0 { deleteFailure = nil } })) {
            Button("OK") {}
        } message: {
            Text(deleteFailure ?? "")
        }
    }

    /// The deck's one action in the bottom bar: Study This Deck, prominent while cards are due, Learn 10 New Words when
    /// nothing is.
    private var studyButton: some View {
        let stage: DayAction = studyIsDue ? .study : .pushOn
        return Button {
            start(stage == .pushOn ? .pushOn : .study)
        } label: {
            Text(stage == .study ? "Study This Deck" : stage.title)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                // The bar sizes its items to their content: the button takes the bar's width, as on Today.
                .containerRelativeFrame(.horizontal) { width, _ in max(180, width - 64) }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canEdit || (document?.deck.cards.isEmpty ?? true))
        .accessibilityValue(due > 0 ? Text("\(due) cards left") : Text(verbatim: ""))
    }

    /// Study These Now: the sheet has gone, the stream of this deck puts the cards it added first.
    private func studyAddedCards() {
        guard let ids = studyAfterSheet else { return }
        studyAfterSheet = nil
        start(.studyNow(ids))
    }

    /// Today's counts of the deck, from the document once it is read.
    private var counts: StudyCounts? {
        document?.dueCards.counts ?? knownCounts
    }

    private var due: Int { counts?.total ?? 0 }

    /// Study This Deck, or Push On when nothing is due: ten new cards of the deck at once.
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

/// The "+" of the bar: Add Cards and Import Cards…, which need the file to be ready to change.
private struct AddMenu: View {
    @ObservedObject var document: VocabularyDocument
    var canEdit: Bool
    var addCards: () -> Void
    var importCards: () -> Void

    var body: some View {
        Menu("Add", systemImage: "plus") {
            Button("Add Cards", systemImage: "plus", action: addCards)
            Button("Import Cards…", systemImage: "square.and.arrow.down", action: importCards)
        }
        .disabled(!canEdit || !document.isReadyToEdit)
    }
}

/// The two practices of a deck, which change no card, one tap away in the menu of the bar: the newest words and
/// today's mistakes. An item with nothing to practice is grey.
enum DeckPractice: CaseIterable {
    case newest, mistakes

    var entry: StudyModel.Entry {
        switch self {
        case .newest: .practiceNewest
        case .mistakes: .practiceMistakes
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .newest: "Practice Newest Words"
        case .mistakes: "Practice Today's Mistakes"
        }
    }

    var symbol: String {
        switch self {
        case .newest: "rectangle.stack.badge.play"
        case .mistakes: "arrow.counterclockwise"
        }
    }
}

/// The practices as the items of the menu; they watch the document, so the counts are those of the moment the menu opens.
private struct PracticeButtons: View {
    @ObservedObject var document: VocabularyDocument
    var canEdit: Bool
    var start: (StudyModel.Entry) -> Void

    private func cards(of practice: DeckPractice) -> Int {
        switch practice {
        case .newest: document.deck.newestBatchIDs(calendar: document.calendar).count
        case .mistakes: document.deck.mistakes(onDayOf: document.clock.now, calendar: document.calendar).count
        }
    }

    var body: some View {
        ForEach(DeckPractice.allCases, id: \.self) { practice in
            Button(practice.title, systemImage: practice.symbol) { start(practice.entry) }
                .disabled(!canEdit || cards(of: practice) == 0)
        }
    }
}

/// The sections that need the deck itself.
private struct LoadedSections: View {
    @ObservedObject var document: VocabularyDocument
    var merger: VersionMerger
    var pace: Pace?
    var canEdit: Bool
    var addCards: () -> Void

    var body: some View {
        let counts = document.dueCards.counts
        let now = document.clock.now

        if let failure = merger.failure {
            Notice(title: "Another version of this deck could not be merged", message: Text(failure)) {
                merger.failure = nil
            }
        }

        let isPaused = document.deck.learningOptions.isPaused
        if let headline = DeckHeadline(counts: counts, pace: pace, isPaused: isPaused, hasCards: !document.deck.cards.isEmpty, now: now) {
            Section {
                DeckTodayCard(headline: headline, counts: counts, pace: pace, isPaused: isPaused, now: now)
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
