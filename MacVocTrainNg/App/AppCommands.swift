import SwiftUI

/// Actions of the focused document window, for the menu bar.
struct DeckActions {
    var isInSession: Bool
    /// `false` while the deck can only be viewed, see `DocumentView.isEditable`, or
    /// while the document has no undo manager yet (#305).
    var isEditable: Bool
    var canStartSession: Bool
    var startSession: () -> Void
    /// Whether any card went wrong today, see `Deck.mistakes(onDayOf:calendar:)`.
    var canPracticeMistakes: Bool
    var practiceMistakes: () -> Void
    /// Whether the deck has a newest batch to practice, see `Deck.newestBatchIDs`.
    var canPracticeNewest: Bool
    var practiceNewest: () -> Void
    var show: (DocumentView.Screen) -> Void
    var showOptions: () -> Void
    /// Whether the deck is paused (`LearningOptions.isPaused`): the menu then offers to resume it.
    var isPaused: Bool
    /// Pauses the deck, or resumes it.
    var setPaused: (Bool) -> Void
    var importCards: () -> Void
    var exportCards: () -> Void
    var addLessonWords: () -> Void
    var showShortcuts: () -> Void
}

private struct DeckActionsKey: FocusedValueKey {
    typealias Value = DeckActions
}

extension FocusedValues {
    var deckActions: DeckActions? {
        get { self[DeckActionsKey.self] }
        set { self[DeckActionsKey.self] = newValue }
    }
}

struct AppCommands: Commands {
    @FocusedValue(\.deckActions) private var actions

    var body: some Commands {
        CommandGroup(after: .importExport) {
            Button("Import MacVocTrain 1 Document…") {
                LegacyImport.run()
            }
            Button("Import Cards…") { actions?.importCards() }
                .disabled(actions?.isEditable != true || actions?.isInSession == true)
            Button("Shared Decks on AnkiWeb…") { DeckWebWindow.show() }
            Button("Export Cards…") { actions?.exportCards() }
                .disabled(actions == nil)
            Button("Add Lesson Words…") { actions?.addLessonWords() }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(actions?.isEditable != true || actions?.isInSession == true)
        }

        CommandGroup(after: .windowList) {
            Button("Welcome to Mnemit") { WelcomeWindow.show() }
        }

        CommandGroup(after: .help) {
            Button("Keyboard Shortcuts") { actions?.showShortcuts() }
                .disabled(actions == nil)
        }

        CommandMenu("Study") {
            Button("Study") { actions?.startSession() }
                .keyboardShortcut("l", modifiers: .command)
                .disabled(actions?.canStartSession != true)
            Button("Practice Today's Mistakes") { actions?.practiceMistakes() }
                .disabled(actions?.canPracticeMistakes != true)
            Button("Practice Newest Words") { actions?.practiceNewest() }
                .disabled(actions?.canPracticeNewest != true)

            Divider()

            Button("Cards") { actions?.show(.cards) }
                .keyboardShortcut("1", modifiers: .command)
                .disabled(actions == nil || actions?.isInSession == true)
            Button("Statistics") { actions?.show(.statistics) }
                .keyboardShortcut("2", modifiers: .command)
                .disabled(actions == nil || actions?.isInSession == true)

            Divider()

            Button("Learning Options…") { actions?.showOptions() }
                .disabled(actions?.isEditable != true || actions?.isInSession == true)
            if actions?.isPaused == true {
                Button("Resume Deck") { actions?.setPaused(false) }
                    .disabled(actions?.isEditable != true || actions?.isInSession == true)
            } else {
                Button("Pause Deck") { actions?.setPaused(true) }
                    .disabled(actions?.isEditable != true || actions?.isInSession == true)
            }

            Divider()

            Button("How Today Works") { HowTodayWorksWindow.show() }
                .disabled(actions == nil)
        }
    }
}
