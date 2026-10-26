import AppKit
import SwiftUI
import VocabCore

/// What a row of the sidebar says of the plan left in it, as the iPhone's deck rows do: the time it takes, "≈ 4 min", or a
/// check once nothing is left.
enum SidebarBadge: Hashable {
    case minutes(Int)
    case done

    /// `nil` while the cards are not read, and without a pace, which prices them.
    init?(newCards: Int, otherCards: Int, pace: Pace?) {
        if newCards + otherCards == 0 {
            self = .done
        } else if let pace {
            self = .minutes(DailyGoal.minutesLeft(newCards: newCards, otherCards: otherCards, pace: pace) ?? 0)
        } else {
            return nil
        }
    }

    /// A deck's plan left: `nil` for a deck not read and for a paused one.
    init?(_ counts: StudyCounts?, pace: Pace?) {
        guard let counts else { return nil }
        self.init(newCards: counts.newAtDayStart, otherCards: counts.total - counts.newAtDayStart, pace: pace)
    }

    var text: Text {
        switch self {
        case let .minutes(minutes): Text(verbatim: Format.timeLeft(minutes: minutes))
        case .done: Text(Image(systemName: "checkmark"))
        }
    }

    /// What VoiceOver says for it: the check says "Done".
    var spoken: Text {
        switch self {
        case .minutes: text
        case .done: Text("Done")
        }
    }
}

/// A deck of the sidebar: its file and what today's plan has left of it.
struct SidebarRow: Identifiable, Hashable {
    var url: URL
    var isPaused = false
    /// The plan left in the deck; `nil` before the deck is read, for a paused deck and before the ring is worked out.
    var badge: SidebarBadge?

    var id: URL { url }
    var name: String { url.deletingPathExtension().lastPathComponent }
}

/// What the sidebar lists: Today with the plan left of the day, then the decks of the day, the paused ones and the
/// decks opened from outside the folder.
struct SidebarRows: Equatable {
    /// The plan left of the day over its decks, once they are read.
    var today: SidebarBadge?
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
/// with the minutes left (or a check) as the badge, the paused ones, and the decks opened from elsewhere; under them the (+) menu
/// for a new or an opened deck.
struct SidebarContent: View {
    var rows: SidebarRows
    @Binding var selection: Shell.Item
    var actions = SidebarActions()

    var body: some View {
        List(selection: Binding<Shell.Item?>(get: { selection }, set: { if let item = $0 { selection = item } })) {
            Label("Today", systemImage: "circle.circle")
                .badge(rows.today?.text)
                .accessibilityValue(rows.today.map(\.spoken) ?? Text(verbatim: ""))
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
                        .badge(row.badge?.text)
                        .accessibilityValue(row.badge.map(\.spoken) ?? Text(verbatim: ""))
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
        let pace = ring.progress?.pace
        func row(_ url: URL) -> SidebarRow {
            SidebarRow(url: url, isPaused: paused.contains(url), badge: SidebarBadge(studyCounts(url), pace: pace))
        }
        // The day's plan left, priced as one: the new cards at their price, the rest at theirs.
        let left = day.active.compactMap { studyCounts($0.url) }
        let today =
            counts.isRead && !day.active.isEmpty
            ? SidebarBadge(
                newCards: left.reduce(0) { $0 + $1.newAtDayStart }, otherCards: left.reduce(0) { $0 + $1.total - $1.newAtDayStart }, pace: pace)
            : nil
        return SidebarRows(today: today, decks: day.active.map { row($0.url) }, paused: day.paused.map { row($0.url) }, others: others.map(row))
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
                rename: rename, delete: delete, newDeck: newDeck, openDeck: shell.chooseDecks,
                sharedDecks: { DeckWebWindow.show() }, chooseFolder: chooseFolder))
    }

    private func chooseFolder() {
        shell.folder.choose()
        shell.refresh()
    }
}
