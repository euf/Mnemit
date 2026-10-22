import AppKit
import SwiftUI
import VocabCore

/// The content of a document window: the card list or the statistics, or the study
/// stream that temporarily takes over the whole window.
///
/// Shows one document for its whole life: the window gives each document a view of
/// its own, see `DocumentWindow`.
struct DocumentView: View {
    enum Screen: String {
        case cards
        case statistics
    }

    @ObservedObject var document: VocabularyDocument
    /// Where the document is saved; `nil` until it is saved for the first time.
    var fileURL: URL?
    /// `false` while the deck can only be viewed, e.g. an old version in the version
    /// browser or a file that can't be written. Nothing then changes the deck or starts
    /// a session; the controls say so by being disabled.
    var isEditable: Bool
    /// Merges the versions of the deck from other devices; outlives the view.
    var merger: VersionMerger
    /// Survives quitting when the window is restored; the stream doesn't.
    @SceneStorage("screen") private var screen: Screen = .cards
    @State private var session: SessionViewModel?
    @State private var showingOptions = false
    @State private var importPreview: CardImport.Preview?
    /// Whether an import file is being read: an Anki package takes a while.
    @State private var isReadingImport = false
    @State private var addingLessonWords = false
    @State private var toast: Toast?
    @State private var shortcutsHelp = ShortcutsHelp()
    /// Today's cards done against the daily goal and the streak, over all decks open in the app.
    @State private var ring = DailyRingModel()
    @Environment(\.controlActiveState) private var controlActiveState

    /// Whether the deck can be changed now: the file can be written, and the document
    /// has the undo manager of the window, which this view attaches (#305).
    private var canEdit: Bool {
        isEditable && document.isReadyToEdit
    }

    var body: some View {
        Group {
            if let session {
                SessionView(model: session, ring: ring) { self.session = nil }
            } else {
                switch screen {
                case .cards: CardListView(document: document, isEditable: canEdit)
                case .statistics: StatisticsView(document: document)
                }
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .toolbar {
            if session == nil {
                ToolbarItem(placement: .principal) {
                    Picker("View", selection: $screen) {
                        Label("Cards", systemImage: "rectangle.stack").tag(Screen.cards)
                        Label("Statistics", systemImage: "chart.bar.xaxis").tag(Screen.statistics)
                    }
                    .pickerStyle(.segmented)
                    .labelStyle(.titleOnly)
                }
                ToolbarItem(placement: .primaryAction) {
                    RingChip(progress: ring.progress)
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .primaryAction) {
                    StartStudyButton(dueCards: document.dueCards, hasCards: !document.deck.cards.isEmpty, action: startSession)
                        .disabled(!canEdit)
                }
                // A text button beside symbol buttons reads as one control without a gap.
                ToolbarSpacer(.fixed, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addingLessonWords = true
                    } label: {
                        Label("Add Lesson Words", systemImage: "text.badge.plus")
                    }
                    .help("Add Lesson Words…")
                    .disabled(!canEdit)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingOptions = true
                    } label: {
                        Label("Learning Options", systemImage: "slider.horizontal.3")
                    }
                    .help("Learning Options")
                    .disabled(!canEdit)
                }
            }
        }
        .sheet(isPresented: $showingOptions) {
            DeckOptionsView(document: document)
        }
        .sheet(item: $importPreview) { preview in
            ImportPreviewView(document: document, preview: preview)
        }
        .sheet(isPresented: $addingLessonWords) {
            LessonWordsSheet(document: document, deckName: deckName) { count in
                toast = Toast(String(localized: "Added \(count) cards. The production cards unlock after the recognition cards are learned."))
            }
        }
        .overlay {
            if isReadingImport {
                ProgressView("Reading cards…")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                ToastView(toast: toast) { self.toast = nil }
            }
        }
        .animation(.easeOut(duration: 0.2), value: toast)
        .shortcutsHelp(shortcutsHelp)
        .onChange(of: session?.studyBy == .flashcards, initial: true) { _, isFlashcards in
            shortcutsHelp.opensWithQuestionMark = isFlashcards
        }
        .onChange(of: canEdit, initial: true) { _, canEdit in
            // The welcome window made this document to import cards into: a new deck, which
            // an Anki package names.
            if canEdit, let request = WelcomeRequest.takeImportCards() {
                Task { importCards(from: request.file, namesDeck: true) }
            }
        }
        .attachingUndoManager(to: document)
        // The deck opened: its parameters are fitted again if it is due, in the background and
        // never into a study stream (`ParameterRefit`).
        .task(id: canEdit) {
            guard canEdit, session == nil else { return }
            await ParameterRefitter.refit(document) { session == nil }
        }
        .documentSync(document, fileURL: fileURL, isEditable: isEditable, merger: merger, isInSession: session != nil)
        .onAppear {
            OpenDecks.shared.add(document)
            refreshRing()
        }
        .onDisappear { OpenDecks.shared.remove(document) }
        .onReceive(document.deckDidChange) { refreshRing() }
        .onChange(of: controlActiveState) { _, state in
            if state == .key { refreshRing() }
        }
        // The plan and the study day change as time passes.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                refreshRing()
            }
        }
        .focusedSceneValue(
            \.deckActions,
            DeckActions(
                isInSession: session != nil,
                isEditable: canEdit,
                canStartSession: canEdit && session == nil && !document.deck.cards.isEmpty,
                startSession: startSession,
                canPracticeMistakes: canEdit && session == nil && !document.deck.mistakes(onDayOf: document.clock.now, calendar: document.calendar).isEmpty,
                practiceMistakes: practiceMistakes,
                canPracticeNewest: canEdit && session == nil && !document.deck.newestBatchIDs.isEmpty,
                practiceNewest: practiceNewestWords,
                show: { screen = $0 },
                showOptions: { showingOptions = true },
                isPaused: document.deck.learningOptions.isPaused,
                setPaused: { document.setPaused($0) },
                importCards: { importCards() },
                exportCards: exportCards,
                addLessonWords: { addingLessonWords = canEdit && session == nil },
                showShortcuts: { shortcutsHelp.isShown = true }
            )
        )
        #if DEBUG
        .onAppear(perform: applyDebugLaunchArguments)
        #endif
    }

    #if DEBUG
    /// Development aids for checking the app without clicking through it:
    /// `-debugScreen statistics|study|options` opens a screen,
    /// `-debugSave YES` saves all open documents shortly after opening.
    private func applyDebugLaunchArguments() {
        switch UserDefaults.standard.string(forKey: "debugScreen") {
        case "statistics": screen = .statistics
        // On the next turn, once the view attached the undo manager.
        case "study": Task { startSession() }
        case "options": showingOptions = true
        default: break
        }
        if UserDefaults.standard.bool(forKey: "debugSave") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                for openDocument in NSDocumentController.shared.documents {
                    openDocument.save(nil)
                }
            }
        }
    }
    #endif

    /// Asks for a file, or takes `file`, and shows its cards to choose from. `namesDeck`: the
    /// deck is new, and the Anki deck of a package names it and sets its FSRS settings.
    private func importCards(from file: URL? = nil, namesDeck: Bool = false) {
        guard canEdit, !isReadingImport, let url = file ?? CardImport.chooseFile() else { return }
        isReadingImport = true
        let isNewDeck = namesDeck && fileURL == nil && document.deck.cards.isEmpty
        Task {
            defer { isReadingImport = false }
            guard let preview = await CardImport.preview(ofFileAt: url, for: document, isNewDeck: isNewDeck) else { return }
            if isNewDeck, document.deck.cards.isEmpty, let anki = preview.anki {
                nameWindow(CardImport.deckName(forDecks: anki.deckNames, fileName: url.lastPathComponent))
            }
            importPreview = preview
        }
    }

    /// Names the deck that has no file yet, in the window title and in what Save As offers. A changed
    /// `displayName` reaches the title only when the window controllers are told: until then it says "Untitled".
    private func nameWindow(_ name: String) {
        let named = shortcutsHelp.window.flatMap { NSDocumentController.shared.document(for: $0) } ?? NSDocumentController.shared.currentDocument
        named?.displayName = name
        for controller in named?.windowControllers ?? [] {
            controller.synchronizeWindowTitleWithDocumentName()
        }
    }

    private func exportCards() {
        CardExport.run(
            cards: document.deck.cards,
            calendar: document.calendar,
            suggestedName: fileURL?.deletingPathExtension().lastPathComponent ?? String(localized: "Cards")
        )
    }

    /// The name of the deck as the file has it, for the lesson words sheet.
    private var deckName: String {
        fileURL?.deletingPathExtension().lastPathComponent ?? String(localized: "this deck")
    }

    /// Opens the study stream, which rests at once if today's plan is empty.
    private func startSession() {
        guard canEdit, session == nil, !document.deck.cards.isEmpty else { return }
        let model = SessionViewModel(document: document, studyBy: Preferences.studyBy(), rounds: RoundGuide(progress: ring.progress, document: document))
        session = model
        if model.studyBy == .flashcards {
            shortcutsHelp.showForFirstSession()
        }
    }

    /// Practices the cards that went wrong today, whatever their schedule: the reviews
    /// change no card.
    private func practiceMistakes() {
        guard canEdit, session == nil else { return }
        let model = SessionViewModel(document: document, studyBy: Preferences.studyBy(), entry: .practiceMistakes)
        if !model.isResting {
            session = model
        }
    }

    /// Practices the words the last run of `deck-from-tsv` added, whatever their schedule:
    /// the reviews change no card.
    private func practiceNewestWords() {
        guard canEdit, session == nil else { return }
        let model = SessionViewModel(document: document, studyBy: Preferences.studyBy(), entry: .practiceNewest)
        if !model.isResting {
            session = model
        }
    }

    /// Evaluates the ring for every deck open in the app.
    private func refreshRing() {
        ring.refresh(documents: OpenDecks.shared.documents)
    }
}

/// The prominent "Study" button of the toolbar. The stream it opens has no end, so the button
/// works once the plan is done, too, and offers catch-up, review ahead and practice; the menu command
/// Study ▸ Study is its twin.
private struct StartStudyButton: View {
    var dueCards: DueCardCounter
    var hasCards: Bool
    var action: () -> Void

    var body: some View {
        Button("Study", action: action)
            .buttonStyle(.borderedProminent)
            .disabled(!hasCards)
            .help(dueCards.count > 0 ? "Study today's plan" : "Done for today")
    }
}

/// Today's cards done against the daily goal as a ring with the streak in its middle and "14/20", beside
/// the Study button. An indicator, no button: it takes no background in the toolbar.
private struct RingChip: View {
    var progress: DailyProgress?

    var body: some View {
        HStack(spacing: 6) {
            ProgressRing(fraction: progress?.ring.fraction ?? 0, diameter: 24, center: RingCenter(progress, inStream: false))
            if let ring = progress?.ring {
                Text(verbatim: "\(ring.done)/\(ring.goal)")
                    .monospacedDigit()
            }
        }
        .help(help)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Daily Goal"))
        .accessibilityValue(help)
    }

    /// The day's headline, "≈ 2 min to keep your streak" or "Ring closed", then "14 of 20 cards", "· 12-day streak" when there is one,
    /// and "≈ 28 words in memory · +15 today".
    private var help: String {
        guard let progress else { return "" }
        var parts: [String] = []
        if let round = RoundStatus(progress).line {
            parts.append(round)
        }
        parts.append(String(localized: "\(progress.ring.done) of \(progress.ring.goal) cards"))
        if progress.streak.days > 0 {
            parts.append(String(localized: "\(progress.streak.days)-day streak"))
        }
        if let memory = progress.memory.line {
            parts.append(memory)
        }
        return parts.joined(separator: " · ")
    }
}
