import AppKit
import SwiftUI
import VocabCore

/// The keys of the menus: the menus take their shortcut and their title from here, and the cheat sheet lists the same
/// rows, so a key can't be changed in one and forgotten in the other.
enum MenuKey: CaseIterable {
    case newDeck, openDeck, importCards
    case studyDay, studyDeck, addCards, learningOptions
    case showToday, showProgress, showCards, showStatistics, toggleInspector

    var shortcut: KeyboardShortcut {
        switch self {
        case .newDeck: KeyboardShortcut("n")
        case .openDeck: KeyboardShortcut("o")
        case .importCards: KeyboardShortcut("i", modifiers: [.command, .shift])
        case .studyDay: KeyboardShortcut("l")
        case .studyDeck: KeyboardShortcut("l", modifiers: [.command, .option])
        case .addCards: KeyboardShortcut("l", modifiers: [.command, .shift])
        case .learningOptions: KeyboardShortcut(";")
        case .showToday: KeyboardShortcut("1")
        case .showProgress: KeyboardShortcut("2")
        case .showCards: KeyboardShortcut("3")
        case .showStatistics: KeyboardShortcut("4")
        case .toggleInspector: KeyboardShortcut("i", modifiers: [.command, .option])
        }
    }

    /// The keys to press, one cap each, in the order the menus print them.
    var caps: [String] {
        let modifiers = shortcut.modifiers
        let marks = [(EventModifiers.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
        return marks.filter { modifiers.contains($0.0) }.map(\.1) + [String(shortcut.key.character).uppercased()]
    }

    /// The menu item's title; the day's action and the inspector's switch say what they do now.
    func title(_ state: MenuState) -> LocalizedStringKey {
        switch self {
        case .newDeck: "New Deck…"
        case .openDeck: "Open Deck…"
        case .importCards: "Import Cards…"
        case .studyDay: state.dayAction.title
        case .studyDeck: "Study This Deck"
        case .addCards: "Add Cards…"
        case .learningOptions: "Learning Options…"
        case .showToday: "Today"
        case .showProgress: "Progress"
        case .showCards: "Cards"
        case .showStatistics: "Statistics"
        case .toggleInspector: state.showsInspector ? "Hide Inspector" : "Show Inspector"
        }
    }
}

/// What the menu bar can do for what the window shows. It reads the shell, so a menu that reads it follows the page, the
/// open deck and the stream.
struct MenuState {
    var dayAction = DayAction.study
    /// Study has a deck of the day to run over.
    var canStudyDay = false
    var hasDeck = false
    /// The selected deck is read, which Export and Show in Finder need.
    var hasDocument = false
    /// The selected deck can be changed, and no stream runs.
    var canChange = false
    var canStudyDeck = false
    var canPracticeMistakes = false
    var canPracticeNewest = false
    var isPaused = false
    var canImport = false
    var inRun = false
    /// The deck's cards are on the page, which the inspector is part of.
    var showsCards = false
    var showsInspector = false
    /// The stream asks a card on its first showing, which the cheat sheet names by its two buttons.
    var onNewCard = false
}

extension Shell {
    var menu: MenuState {
        _ = revision
        let deck = selectedDeck
        let document = deck?.document
        let inRun = run != nil
        let canChange = deck?.isEditable == true && document?.isReadyToEdit == true && !inRun
        let now = document?.clock.now ?? Date()
        return MenuState(
            dayAction: dayAction,
            canStudyDay: canStudyDay,
            hasDeck: selectedURL != nil,
            hasDocument: document != nil,
            canChange: canChange,
            canStudyDeck: canChange && document?.deck.cards.isEmpty == false,
            canPracticeMistakes: canChange && document.map { !$0.deck.mistakes(onDayOf: now, calendar: $0.calendar).isEmpty } == true,
            canPracticeNewest: canChange && document.map { !$0.deck.newestBatchIDs.isEmpty } == true,
            isPaused: document?.deck.learningOptions.isPaused ?? false,
            canImport: !inRun && (selectedURL == nil || canChange),
            inRun: inRun,
            showsCards: selectedURL != nil && screen == .cards && !inRun && document != nil,
            showsInspector: showsInspector,
            onNewCard: session.map { !$0.isResting && $0.currentCard?.isNew == true } ?? false)
    }

    /// File ▸ Import Cards…: into the selected deck, else into a new deck made for the file.
    func importCards() {
        if selectedURL != nil {
            request = .importCards
        } else if let file = CardImport.chooseFile() {
            Task { await importIntoNewDeck(from: file) }
        }
    }

    /// File ▸ Export Deck…: the selected deck's cards, to a file the learner names.
    func exportSelected() {
        guard let url = selectedURL, let document = selectedDeck?.document else { return }
        CardExport.run(cards: document.deck.cards, calendar: document.calendar, suggestedName: url.deletingPathExtension().lastPathComponent)
    }

    /// File ▸ Show in Finder.
    func showInFinder() {
        if let url = selectedURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }

    /// Study ▸ Study This Deck and the two practices.
    func studySelected(_ entry: SessionViewModel.Entry? = nil) {
        if let url = selectedURL { study(.deck(url), entry: entry) }
    }

    /// Study ▸ Pause Deck and Resume Deck.
    func setSelectedPaused(_ isPaused: Bool) {
        if let url = selectedURL { Task { await setPaused(url, isPaused) } }
    }

    func toggleInspector() {
        showsInspector.toggle()
    }
}
