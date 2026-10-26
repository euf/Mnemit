import AppKit
import SwiftUI
import UniformTypeIdentifiers
import VocabCore

/// A deck of the sidebar: its file and what today's plan has left of it.
struct SidebarRow: Identifiable, Hashable {
    var url: URL
    var isPaused = false
    /// The cards of today's plan not done yet; `nil` before the deck is read, and for a paused deck.
    var cardsLeft: Int?

    var id: URL { url }
    var name: String { url.deletingPathExtension().lastPathComponent }
}

/// What the sidebar lists: Today with the cards left of the day, then the decks of the day, the paused ones and the
/// decks opened from outside the folder.
struct SidebarRows: Equatable {
    /// The cards left of the day, once the decks are read.
    var today: Int?
    var decks: [SidebarRow] = []
    var paused: [SidebarRow] = []
    var others: [SidebarRow] = []
}

/// What the sidebar's menus do, for the window to carry out.
struct SidebarActions {
    var study: (URL) -> Void = { _ in }
    var setPaused: (URL, Bool) -> Void = { _, _ in }
    var showInFinder: (URL) -> Void = { _ in }
    var rename: (URL) -> Void = { _ in }
    var delete: (URL) -> Void = { _ in }
    var newDeck: () -> Void = {}
    var openDeck: () -> Void = {}
    var sharedDecks: () -> Void = {}
    var chooseFolder: () -> Void = {}
}

/// The sidebar of the Mac's one window, from what it is given so a test can draw it: Today and Progress, the decks
/// with the cards left as the badge, the paused ones, and the decks opened from elsewhere; under them the (+) menu
/// for a new or an opened deck.
struct SidebarContent: View {
    var rows: SidebarRows
    @Binding var selection: Shell.Item
    var actions = SidebarActions()

    var body: some View {
        List(selection: Binding<Shell.Item?>(get: { selection }, set: { if let item = $0 { selection = item } })) {
            Label("Today", systemImage: "circle.circle")
                .badge(rows.today ?? 0)
                .tag(Shell.Item.today)
            Label("Progress", systemImage: "chart.bar.xaxis")
                .tag(Shell.Item.progress)
            section("Decks", rows.decks)
            section("Paused", rows.paused)
            section("Other Decks", rows.others)
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) { addMenu }
    }

    @ViewBuilder
    private func section(_ title: LocalizedStringKey, _ rows: [SidebarRow]) -> some View {
        if !rows.isEmpty {
            Section(title) {
                ForEach(rows) { row in
                    Label(row.name, systemImage: row.isPaused ? "pause.circle" : "rectangle.stack")
                        .badge(row.cardsLeft ?? 0)
                        .tag(Shell.Item.deck(row.url))
                        .contextMenu { menu(for: row) }
                }
            }
        }
    }

    @ViewBuilder
    private func menu(for row: SidebarRow) -> some View {
        Button("Study This Deck", systemImage: "play.rectangle") { actions.study(row.url) }
            .disabled(row.isPaused)
        Button(row.isPaused ? "Resume Deck" : "Pause Deck", systemImage: row.isPaused ? "play.circle" : "pause.circle") {
            actions.setPaused(row.url, !row.isPaused)
        }
        Divider()
        Button("Show in Finder", systemImage: "folder") { actions.showInFinder(row.url) }
        Button("Rename…", systemImage: "pencil") { actions.rename(row.url) }
        Button("Delete Deck", systemImage: "trash", role: .destructive) { actions.delete(row.url) }
    }

    private var addMenu: some View {
        HStack {
            Menu {
                Button("New Deck…", action: actions.newDeck)
                Button("Open Deck…", action: actions.openDeck)
                Divider()
                Button("Shared Decks on AnkiWeb…", action: actions.sharedDecks)
                Button("Choose Mnemit Folder…", action: actions.chooseFolder)
            } label: {
                Image(systemName: "plus")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("New Deck")
            .accessibilityLabel(Text("New Deck"))
            Spacer()
        }
        .padding(.horizontal, Spacing.tight)
        .padding(.vertical, Spacing.hairline)
    }
}

extension Shell {
    /// The rows of the sidebar over what the shell knows now.
    var sidebar: SidebarRows {
        let paused = Set(known.filter(isPaused))
        let day = TodayDecks(folder.decks.map(KnownDeck.init(url:)), paused: paused)
        func row(_ url: URL) -> SidebarRow {
            SidebarRow(url: url, isPaused: paused.contains(url), cardsLeft: studyCounts(url)?.total)
        }
        return SidebarRows(
            today: counts.isRead ? due : nil, decks: day.active.map { row($0.url) }, paused: day.paused.map { row($0.url) },
            others: others.map(row))
    }
}

/// The sidebar of the window: `SidebarContent` over the shell, with what its menus do.
struct Sidebar: View {
    var shell: Shell
    var newDeck: () -> Void
    var rename: (URL) -> Void
    var delete: (URL) -> Void

    var body: some View {
        SidebarContent(
            rows: shell.sidebar,
            selection: Binding(get: { shell.selection }, set: { shell.select($0) }),
            actions: SidebarActions(
                study: { shell.study(.deck($0)) },
                setPaused: { url, isPaused in Task { await shell.setPaused(url, isPaused) } },
                showInFinder: { NSWorkspace.shared.activateFileViewerSelecting([$0]) },
                rename: rename, delete: delete, newDeck: newDeck, openDeck: openDeck,
                sharedDecks: { DeckWebWindow.show() }, chooseFolder: chooseFolder))
    }

    /// File ▸ Open Deck…: the learner chooses decks, which are selected, outside the folder too.
    private func openDeck() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = DeckFile.fileExtensions.compactMap { UTType(filenameExtension: $0) }
        panel.prompt = String(localized: "Open")
        guard panel.runModal() == .OK else { return }
        shell.open(panel.urls)
    }

    private func chooseFolder() {
        shell.folder.choose()
        shell.refresh()
    }
}
