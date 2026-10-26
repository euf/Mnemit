import SwiftUI

/// The menu bar of the one window: File, Study, View and Help's cheat sheet. The items read `Shell.shared` through
/// `MenuState`, so what is switched off follows the page, the open deck and the stream; their keys and titles come from
/// `MenuKey`, the table the cheat sheet lists too. An item that does something to the window brings it forward first, as
/// Settings or a closed window may be what is up.
struct AppCommands: Commands {
    var shell: Shell

    private var menu: MenuState { shell.menu }

    private func item(_ key: MenuKey, in menu: MenuState, _ action: @escaping () -> Void) -> some View {
        Button(key.title(menu)) {
            shell.showWindow()
            action()
        }
        .keyboardShortcut(key.shortcut)
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            let menu = menu
            item(.newDeck, in: menu) { shell.isNamingDeck = true }
                .disabled(menu.inRun)
            item(.openDeck, in: menu) { shell.chooseDecks() }
                .disabled(menu.inRun)

            Divider()

            item(.importCards, in: menu) { shell.importCards() }
                .disabled(!menu.canImport)
            Button("Shared Decks on AnkiWeb…") { DeckWebWindow.show() }
                .disabled(menu.inRun)

            Divider()

            Button("Export Deck…") { shell.exportSelected() }
                .disabled(!menu.hasDocument || menu.inRun)
            Button("Show in Finder") { shell.showInFinder() }
                .disabled(!menu.hasDeck || menu.inRun)
        }

        CommandMenu("Study") {
            let menu = menu
            item(.studyDay, in: menu) { shell.study(.day) }
                .disabled(!menu.canStudyDay)
            item(.studyDeck, in: menu) { shell.studySelected() }
                .disabled(!menu.canStudyDeck)

            Divider()

            item(.addCards, in: menu) { shell.request = .addCards }
                .disabled(!menu.canChange)

            Divider()

            Button("Practice Newest Words") {
                shell.showWindow()
                shell.studySelected(.practiceNewest)
            }
            .disabled(!menu.canPracticeNewest)
            Button("Practice Today's Mistakes") {
                shell.showWindow()
                shell.studySelected(.practiceMistakes)
            }
            .disabled(!menu.canPracticeMistakes)

            Divider()

            Button(menu.isPaused ? "Resume Deck" : "Pause Deck") {
                shell.showWindow()
                shell.setSelectedPaused(!menu.isPaused)
            }
            .disabled(!menu.canChange)
            item(.learningOptions, in: menu) { shell.request = .options }
                .disabled(!menu.canChange)
        }

        CommandGroup(before: .sidebar) {
            let menu = menu
            item(.showToday, in: menu) { shell.select(.today) }
                .disabled(menu.inRun)
            item(.showProgress, in: menu) { shell.select(.progress) }
                .disabled(menu.inRun)
            item(.showCards, in: menu) { shell.showScreen(.cards) }
                .disabled(!menu.hasDeck || menu.inRun)
            item(.showStatistics, in: menu) { shell.showScreen(.statistics) }
                .disabled(!menu.hasDeck || menu.inRun)

            Divider()

            item(.toggleInspector, in: menu) { shell.toggleInspector() }
                .disabled(!menu.showsCards)

            Divider()
        }

        CommandGroup(after: .help) {
            Button("Keyboard Shortcuts") { shell.shortcuts.isShown = true }
        }
    }
}
