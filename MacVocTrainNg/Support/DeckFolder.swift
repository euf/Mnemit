import AppKit
import Observation
import VocabCore

/// The folder that holds the learner's decks, Mnemit in iCloud Drive: the sidebar
/// lists the decks in it. Kept as a security-scoped bookmark of the folder in the user
/// defaults, because the sandbox lets the app into a folder only after the learner chose
/// it; the app then holds that access until it quits, so decks in the folder open without
/// asking again. Choosing another folder replaces it.
@MainActor @Observable
final class DeckFolder {
    static let shared = DeckFolder()
    static let key = "DeckFolderBookmark"

    /// The folder, `nil` until the learner chose one.
    private(set) var url: URL?
    /// The decks in it by name; read again whenever the window comes to the front.
    private(set) var decks: [URL] = []

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isAccessing = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let bookmark = defaults.data(forKey: Self.key) {
            resolve(bookmark)
        }
    }

    /// The decks in `folder` by name: packages with the extension of a deck.
    nonisolated static func decks(in folder: URL) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return contents.filter { DeckFile.isDeckName($0.lastPathComponent) }
            .sorted { $0.deletingPathExtension().lastPathComponent.localizedStandardCompare($1.deletingPathExtension().lastPathComponent) == .orderedAscending }
    }

    /// Reads the decks in the folder again, to pick up the ones that arrived since.
    func refresh() {
        decks = url.map(Self.decks(in:)) ?? []
    }

    /// Asks for the folder. One without decks is refused, as it is most likely the wrong one, unless
    /// `requiringDecks` is off: a learner who has no deck yet makes the folder for the first one.
    func choose(requiringDecks: Bool = true) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = !requiringDecks
        panel.allowsMultipleSelection = false
        panel.directoryURL = url
        panel.message = String(localized: "Choose the Mnemit folder, the one that holds your decks.")
        panel.prompt = String(localized: "Choose")
        guard panel.runModal() == .OK, let chosen = panel.url else { return }
        guard !requiringDecks || !Self.decks(in: chosen).isEmpty else {
            NSAlert.showWarning(String(localized: "No decks in this folder"), message: String(localized: "“\(chosen.lastPathComponent)” holds no Mnemit decks. Choose the folder with your decks in it."))
            return
        }
        guard let bookmark = Self.bookmark(for: chosen) else { return }
        defaults.set(bookmark, forKey: Self.key)
        use(chosen)
    }

    private func resolve(_ bookmark: Data) {
        var isStale = false
        guard let folder = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            defaults.removeObject(forKey: Self.key)
            return
        }
        use(folder)
        if isStale, let fresh = Self.bookmark(for: folder) {
            defaults.set(fresh, forKey: Self.key)
        }
    }

    /// Takes `folder` as the folder, and keeps its access, in place of the previous one's; `nil` lets go of it.
    func use(_ folder: URL?) {
        if isAccessing, let url {
            url.stopAccessingSecurityScopedResource()
        }
        isAccessing = folder?.startAccessingSecurityScopedResource() ?? false
        url = folder
        refresh()
    }

    private static func bookmark(for folder: URL) -> Data? {
        try? folder.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }
}
