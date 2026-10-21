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
@MainActor @Observable
final class KnownDecks {
    static let key = "KnownDecks"
    static let folderKey = "KnownFolder"

    /// The opened last first.
    private var entries: [Entry]
    /// The folder the learner chose, `nil` before.
    private(set) var folder: URL?
    /// The decks in the folder, as `refreshFolder()` read them last.
    private var folderDecks: [KnownDeck] = []
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isAccessingFolder = false

    private struct Entry {
        var deck: KnownDeck
        var bookmark: Data
    }

    /// Reads the decks from `defaults`. Forgets those that are gone, e.g. deleted.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        entries = (defaults.array(forKey: Self.key) as? [Data] ?? []).compactMap { bookmark in
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) else { return nil }
            return Entry(deck: KnownDeck(url: url), bookmark: isStale ? Self.bookmark(for: url) ?? bookmark : bookmark)
        }
        save()
        if let bookmark = defaults.data(forKey: Self.folderKey) {
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

    /// The deck studied last.
    var last: URL? {
        entries.first?.deck.url
    }

    /// Adds the deck that is open now, or moves it to the front.
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

    /// Takes `url`, a folder the file picker returned, as the folder of decks, and returns
    /// how many decks it holds. A folder without decks is most likely the wrong one: it is
    /// not taken, and the result is 0.
    @discardableResult
    func chooseFolder(_ url: URL) -> Int {
        let isAccessing = url.startAccessingSecurityScopedResource()
        let decks = Self.decks(in: url)
        guard !decks.isEmpty, let bookmark = Self.bookmark(for: url) else {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
            return 0
        }
        stopAccessingFolder()
        defaults.set(bookmark, forKey: Self.folderKey)
        folder = url
        isAccessingFolder = isAccessing
        folderDecks = decks
        return decks.count
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
    /// whose download starts here; the deck itself opens as soon as it has arrived.
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
            return DeckFile.isDeckName(name) ? KnownDeck(url: url) : nil
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
