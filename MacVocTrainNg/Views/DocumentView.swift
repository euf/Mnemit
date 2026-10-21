import SwiftUI
import VocabCore

/// The content of a document window: the card list or the statistics, or a
/// session that temporarily takes over the whole window.
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
    /// Survives quitting when the window is restored; the session doesn't.
    @SceneStorage("screen") private var screen: Screen = .cards
    @State private var session: SessionViewModel?
    @State private var showingOptions = false
    @State private var importPreview: CardImport.Preview?
    @State private var addingLessonWords = false
    @State private var toast: Toast?

    /// Whether the deck can be changed now: the file can be written, and the document
    /// has the undo manager of the window, which this view attaches (#305).
    private var canEdit: Bool {
        isEditable && document.isReadyToEdit
    }

    var body: some View {
        Group {
            if let session {
                SessionView(model: session) { self.session = nil }
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
                    StartStudyButton(dueCards: document.dueCards, action: startSession)
                        .disabled(!canEdit)
                }
                ToolbarItem {
                    Button {
                        addingLessonWords = true
                    } label: {
                        Label("Add Lesson Words", systemImage: "text.badge.plus")
                    }
                    .help("Add Lesson Words…")
                    .disabled(!canEdit)
                }
                ToolbarItem {
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
        .overlay(alignment: .bottom) {
            if let toast {
                ToastView(toast: toast) { self.toast = nil }
            }
        }
        .animation(.easeOut(duration: 0.2), value: toast)
        .attachingUndoManager(to: document)
        .documentSync(document, fileURL: fileURL, isEditable: isEditable, merger: merger, isInSession: session != nil)
        .focusedSceneValue(
            \.deckActions,
            DeckActions(
                isInSession: session != nil,
                isEditable: canEdit,
                canStartSession: canEdit && session == nil && document.dueCards.count > 0,
                startSession: startSession,
                show: { screen = $0 },
                showOptions: { showingOptions = true },
                importCards: importCards,
                exportCards: exportCards,
                addLessonWords: { addingLessonWords = canEdit && session == nil }
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

    private func importCards() {
        guard canEdit else { return }
        importPreview = CardImport.chooseFile(existing: document.deck.cards, created: document.clock.now)
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

    private func startSession() {
        guard canEdit, session == nil else { return }
        let model = SessionViewModel(document: document, studyBy: Preferences.studyBy())
        if !model.isFinished {
            session = model
        }
    }
}

/// "Study" button showing how many cards the session takes, not how many are due:
/// the session introduces only as many new cards as its limits allow.
private struct StartStudyButton: View {
    var dueCards: DueCardCounter
    var action: () -> Void

    var body: some View {
        let count = dueCards.count
        Button(action: action) {
            Label(count > 0 ? "Study (\(count))" : "Study", systemImage: "graduationcap")
                .labelStyle(.titleAndIcon)
        }
        .disabled(count == 0)
        .help(count > 0 ? "Start a study session" : "Done for today")
    }
}
