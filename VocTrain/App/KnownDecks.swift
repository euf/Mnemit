import Foundation
import Observation
import VocabCore

/// A deck the app has opened, as the start screen lists it (#288).
struct KnownDeck: Identifiable, Hashable {
    let url: URL

    var id: URL { url }

    /// The name of the deck, without the extension.
    var name: String {
        url.deletingPathExtension().lastPathComponent
    }
}

/// The decks the app has opened, which the start screen lists (#288); the one studied
/// last comes first in the queue of Study.
///
/// Kept as bookmarks in the user defaults: a deck on iCloud Drive lies outside the
/// app's sandbox, and only a bookmark keeps the access the file picker granted to it.
/// Forgetting a deck leaves its file alone.
///
/// The learner may also choose the folder that holds the decks, Mnemit in iCloud Drive:
/// every deck in it is listed, and `refreshFolder()` picks up the ones that arrived since.
/// The folder is a bookmark too, and the app keeps its access while it runs, so the decks
/// in it open without a bookmark of their own.
///
/// Without iCloud Drive the folder is the app's own Documents directory, which Files shows as
/// On My iPhone, Mnemit. It lies inside the sandbox, so it needs no bookmark and no security
/// scope; only a flag says it was chosen, and its path is looked up at every launch, because
/// the path of the container may change.
@MainActor @Observable
final class KnownDecks {
    static let key = "KnownDecks"
    static let folderKey = "KnownFolder"
    static let localFolderKey = "KnownFolderIsLocal"
    /// The name of the folder the learner is asked to pick or create in iCloud Drive.
    static let folderName = "Mnemit"

    /// The opened last first.
    private var entries: [Entry]
    /// The folder the learner chose, `nil` before.
    private(set) var folder: URL?
    /// Whether the folder is the app's own Documents directory, not one in iCloud Drive.
    private(set) var isLocalFolder = false
    /// The decks in the folder, as `refreshFolder()` read them last.
    private var folderDecks: [KnownDeck] = []
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let localFolder: URL
    @ObservationIgnored private var isAccessingFolder = false

    private struct Entry {
        var deck: KnownDeck
        var bookmark: Data
    }

    /// Reads the decks from `defaults`. Forgets those that are gone, e.g. deleted. `localFolder`
    /// is the directory `useLocalFolder()` takes, the app's Documents directory.
    init(defaults: UserDefaults = .standard, localFolder: URL = .documentsDirectory) {
        self.defaults = defaults
        self.localFolder = localFolder
        entries = (defaults.array(forKey: Self.key) as? [Data] ?? []).compactMap { bookmark in
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) else { return nil }
            return Entry(deck: KnownDeck(url: url), bookmark: isStale ? Self.bookmark(for: url) ?? bookmark : bookmark)
        }
        save()
        if defaults.bool(forKey: Self.localFolderKey) {
            takeLocalFolder()
        } else if let bookmark = defaults.data(forKey: Self.folderKey) {
            resolveFolder(bookmark)
        }
    }

    /// The decks by name, as the start screen lists them: those opened before and those in
    /// the folder.
    var byName: [KnownDeck] {
        let opened = entries.map(\.deck)
        let openedPaths = Set(opened.map { Self.resolvedPath($0.url) })
        let others = folderDecks.filter { !openedPaths.contains(Self.resolvedPath($0.url)) }
        return (opened + others).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Whether `url` lies in the folder, so the learner can't take it off the list: the
    /// next refresh would bring it back.
    func isInFolder(_ url: URL) -> Bool {
        folder.map { Self.isSameFile(url.deletingLastPathComponent(), $0) } ?? false
    }

    /// The deck used last: studied or added to. Cards are added to it from Today.
    var last: URL? {
        entries.first?.deck.url
    }

    /// Adds the deck that is used now, or moves it to the front.
    func remember(_ url: URL) {
        guard let bookmark = Self.bookmark(for: url) else { return }
        removeEntry(for: url)
        entries.insert(Entry(deck: KnownDeck(url: url), bookmark: bookmark), at: 0)
        save()
    }

    func forget(_ url: URL) {
        removeEntry(for: url)
        save()
    }

    /// The deck at `old` was renamed, or moved: the list knows it at `new`, in the same
    /// place of the order. A deck that is in the list only by its folder needs no entry:
    /// `refreshFolder()` finds it by its new name.
    func replace(_ old: URL, with new: URL) {
        guard let index = entries.firstIndex(where: { Self.isSameFile($0.deck.url, old) }), let bookmark = Self.bookmark(for: new) else { return }
        entries[index] = Entry(deck: KnownDeck(url: new), bookmark: bookmark)
        save()
    }

    /// Takes `url`, a folder the file picker returned, as the folder of decks, and returns
    /// how many decks it holds. A folder without decks is most likely the wrong one: it is
    /// not taken, and the result is 0, unless it is named Mnemit, which the learner may have
    /// just created, with the decks still on their way. Whether it was taken: `folder`.
    @discardableResult
    func chooseFolder(_ url: URL) -> Int {
        let isAccessing = url.startAccessingSecurityScopedResource()
        let decks = Self.decks(in: url)
        guard !decks.isEmpty || url.lastPathComponent == Self.folderName, let bookmark = Self.bookmark(for: url) else {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
            return 0
        }
        stopAccessingFolder()
        defaults.set(bookmark, forKey: Self.folderKey)
        defaults.removeObject(forKey: Self.localFolderKey)
        folder = url
        isLocalFolder = false
        isAccessingFolder = isAccessing
        folderDecks = decks
        return decks.count
    }

    /// Takes the app's own Documents directory as the folder of decks, for a learner without
    /// iCloud Drive. It is taken even when empty: decks arrive there through Files.
    func useLocalFolder() {
        stopAccessingFolder()
        defaults.removeObject(forKey: Self.folderKey)
        defaults.set(true, forKey: Self.localFolderKey)
        takeLocalFolder()
    }

    private func takeLocalFolder() {
        folder = localFolder
        isLocalFolder = true
        folderDecks = Self.decks(in: localFolder)
    }

    /// Reads the folder again, for decks that arrived since.
    func refreshFolder() {
        guard let folder else { return }
        folderDecks = Self.decks(in: folder)
    }

    private func resolveFolder(_ bookmark: Data) {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            defaults.removeObject(forKey: Self.folderKey)
            return
        }
        isAccessingFolder = url.startAccessingSecurityScopedResource()
        if isStale, let fresh = Self.bookmark(for: url) {
            defaults.set(fresh, forKey: Self.folderKey)
        }
        folder = url
        folderDecks = Self.decks(in: url)
    }

    private func stopAccessingFolder() {
        if isAccessingFolder, let folder {
            folder.stopAccessingSecurityScopedResource()
        }
        isAccessingFolder = false
    }

    /// The decks in `folder`: packages with the extension of a deck. A deck that iCloud
    /// Drive has not downloaded yet is only a hidden placeholder, ".Greek B1.mnemit.icloud",
    /// whose download starts here; the deck itself opens as soon as it has arrived. A deck that is
    /// here is asked for too: iCloud Drive then brings the version another device saved, which it
    /// otherwise brings only when it gets to it.
    nonisolated static func decks(in folder: URL) -> [KnownDeck] {
        let contents = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return contents.compactMap { url in
            let name = url.lastPathComponent
            if name.hasPrefix("."), name.hasSuffix(".icloud") {
                let deckName = String(name.dropFirst().dropLast(".icloud".count))
                guard DeckFile.isDeckName(deckName) else { return nil }
                let deck = folder.appending(path: deckName, directoryHint: .isDirectory)
                try? FileManager.default.startDownloadingUbiquitousItem(at: deck)
                return KnownDeck(url: deck)
            }
            guard DeckFile.isDeckName(name) else { return nil }
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            return KnownDeck(url: url)
        }
    }

    private func removeEntry(for url: URL) {
        entries.removeAll { Self.isSameFile($0.deck.url, url) }
    }

    /// Whether two URLs name the same file, however they spell it: the path of a
    /// package may end with a slash, and `/var` is a link to `/private/var`.
    nonisolated static func isSameFile(_ first: URL, _ second: URL) -> Bool {
        resolvedPath(first) == resolvedPath(second)
    }

    private nonisolated static func resolvedPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func save() {
        defaults.set(entries.map(\.bookmark), forKey: Self.key)
    }

    private static func bookmark(for url: URL) -> Data? {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
    }
}
