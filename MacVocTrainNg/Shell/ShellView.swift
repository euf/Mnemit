import AppKit
import SwiftUI
import VocabCore

/// A deck of the sidebar a sheet or a dialog is about.
struct DeckTarget: Identifiable {
    var url: URL
    var id: URL { url }
    var name: String { url.deletingPathExtension().lastPathComponent }
}

/// The Mac's one window: the sidebar of Today, Progress and the decks, and the page of the selection. The stream takes the
/// window whole, the sidebar away, until Done.
struct ShellView: View {
    @Bindable var shell: Shell
    @Environment(\.openWindow) private var openWindow
    @State private var renaming: DeckTarget?
    @State private var deleting: DeckTarget?
    @State private var deleteFailure: String?

    var body: some View {
        NavigationSplitView(columnVisibility: Binding(get: { shell.columnVisibility }, set: { shell.setVisibility($0) })) {
            Sidebar(shell: shell, newDeck: { shell.isNamingDeck = true }, rename: { renaming = DeckTarget(url: $0) }, delete: { deleting = DeckTarget(url: $0) })
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            detail
        }
        .toolbar(removing: shell.run != nil ? .sidebarToggle : nil)
        .frame(minWidth: 760, minHeight: 520)
        .shortcutsHelp(shell.shortcuts) { shell.menu }
        .onChange(of: shell.session != nil, initial: true) { _, inSession in
            shell.shortcuts.opensWithQuestionMark = inSession
        }
        .background(WindowUndoRouting(shell: shell))
        .onAppear {
            shell.refresh()
            shell.showWindow = {
                NSApp.activate()
                openWindow(id: MacVocTrainApp.shellID)
            }
        }
        // The decks may have changed while the window was behind others.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in shell.refresh() }
        // The plan and the study day change as time passes.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                shell.refresh()
            }
        }
        .sheet(isPresented: $shell.isNamingDeck) {
            NewDeckView { name in
                Task {
                    do {
                        try await shell.newDeck(named: name ?? String(localized: "Untitled"))
                    } catch {
                        if (error as? CocoaError)?.code != .userCancelled { shell.notice = error.localizedDescription }
                    }
                }
            }
        }
        .sheet(item: $renaming) { target in
            RenameDeckView(currentName: target.name) { try await shell.rename(target.url, to: $0) }
        }
        .confirmationDialog(
            Text("Delete “\(deleting?.name ?? "")”?"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible, presenting: deleting
        ) { target in
            Button("Delete Deck", role: .destructive) {
                Task {
                    do {
                        try await shell.delete(target.url)
                    } catch {
                        deleteFailure = error.localizedDescription
                    }
                }
            }
        } message: { _ in
            Text("The deck goes to the Trash.")
        }
        .alert("The Deck Could Not Be Deleted", isPresented: Binding(get: { deleteFailure != nil }, set: { if !$0 { deleteFailure = nil } })) {
            Button("OK") {}
        } message: {
            Text(deleteFailure ?? "")
        }
        .alert(shell.notice ?? "", isPresented: Binding(get: { shell.notice != nil }, set: { if !$0 { shell.notice = nil } })) {
            Button("OK") {}
        }
    }

    // MARK: - The detail

    /// Whether the window's search field is there: a deck's cards have their own.
    private var hasSearchField: Bool {
        !(shell.selectedURL != nil && shell.screen == .cards)
    }

    @ViewBuilder
    private var detail: some View {
        if shell.run != nil {
            stream
        } else {
            Group {
                if shell.isSearching, hasSearchField {
                    SearchResults(query: shell.query, hits: shell.hits, isSearching: !shell.search.isLoaded, showCard: shell.showCard)
                        .navigationTitle("Search All Cards")
                } else {
                    page
                }
            }
            .modifier(AllCardsSearchField(query: $shell.query, isOn: hasSearchField))
            .onChange(of: shell.isSearching) { shell.loadSearch() }
        }
    }

    @ViewBuilder
    private var page: some View {
        switch shell.selection {
        case .today:
            TodayPage(shell: shell, newDeck: { shell.isNamingDeck = true })
                .navigationTitle("Today")
                .todaySubtitle(Date())
        case .progress:
            ProgressPage(shell: shell)
                .navigationTitle("Progress")
        case let .deck(url):
            if let deck = shell.decks.deck(for: url) {
                DeckPage(deck: deck, shell: shell)
                    .id(url)
                    .navigationTitle(deck.name)
            } else {
                ProgressView()
            }
        }
    }

    @ViewBuilder
    private var stream: some View {
        if let session = shell.session {
            SessionView(model: session, ring: shell.ring, nextDeck: shell.nextDeck) { shell.endStudy() }
                .onChange(of: session.isResting, initial: true) { shell.updateNextDeck() }
        } else if let failure = shell.runFailure {
            ContentUnavailableView {
                Label("The deck could not be opened", systemImage: "exclamationmark.triangle")
            } description: {
                Text(failure)
            } actions: {
                Button("Done") { shell.endStudy() }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Search All Cards in the toolbar, over every deck, where the page has no search field of its own.
private struct AllCardsSearchField: ViewModifier {
    @Binding var query: String
    var isOn: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isOn {
            content.searchable(text: $query, placement: .toolbar, prompt: Text("Search All Cards"))
        } else {
            content
        }
    }
}

/// "Rename Deck": the name in the field, then `onRename` renames the file, see `DeckFiles.rename(_:to:)`. What it throws,
/// a name that is taken, stays under the field; the sheet closes once the deck has its name.
struct RenameDeckView: View {
    var currentName: String
    var onRename: (String) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var failure: String?
    @State private var isWorking = false
    @FocusState private var isFocused: Bool

    init(currentName: String, failure: String? = nil, onRename: @escaping (String) async throws -> Void) {
        self.currentName = currentName
        self.onRename = onRename
        _name = State(initialValue: currentName)
        _failure = State(initialValue: failure)
    }

    private var fileName: String? { DeckFiles.fileName(for: name) }

    private var canSubmit: Bool { fileName != nil && fileName != currentName && !isWorking }

    /// Why the name won't do: what the last try threw, or that it can't name a file.
    private var message: String? {
        if let failure { return failure }
        guard fileName == nil, !name.allSatisfy(\.isWhitespace) else { return nil }
        return DeckFiles.Failure.invalidName.errorDescription
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Rename Deck")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.horizontal, .top], 20)
            Form {
                Section {
                    TextField("Name", text: $name)
                        .focused($isFocused)
                        .onSubmit(submit)
                        .disabled(isWorking)
                } footer: {
                    if let message {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isWorking)
                Button("Rename", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSubmit)
            }
            .padding(20)
        }
        .frame(width: 440)
        .defaultFocus($isFocused, true)
        .onChange(of: name) { failure = nil }
    }

    private func submit() {
        guard canSubmit else { return }
        isWorking = true
        failure = nil
        Task {
            do {
                try await onRename(name)
                dismiss()
            } catch {
                failure = error.localizedDescription
                isWorking = false
            }
        }
    }
}
