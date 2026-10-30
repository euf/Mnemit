import Foundation
import Testing
import VocabCore

@testable import VocTrain

/// The decks the app has opened (#282, #288).
@MainActor
struct KnownDecksTests {
    let directory: URL
    let defaults: UserDefaults

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defaults = try #require(UserDefaults(suiteName: "KnownDecksTests-\(UUID().uuidString)"))
    }

    @Test func rememberedDecksAreListedByNameAfterTheNextLaunch() throws {
        let spanish = try makeDeck(named: "Spanish")
        let polish = try makeDeck(named: "Polish")
        let known = KnownDecks(defaults: defaults)
        known.remember(spanish)
        known.remember(polish)

        #expect(KnownDecks(defaults: defaults).byName.map(\.name) == ["Polish", "Spanish"])
    }

    @Test func theDeckOpenedLastOpensAtLaunch() throws {
        let polish = try makeDeck(named: "Polish")
        let spanish = try makeDeck(named: "Spanish")
        let known = KnownDecks(defaults: defaults)
        known.remember(polish)
        known.remember(spanish)
        known.remember(polish)

        let last = try #require(KnownDecks(defaults: defaults).last)
        #expect(KnownDecks.isSameFile(last, polish))
        #expect(known.byName.count == 2)
    }

    @Test func aForgottenDeckLeavesTheListButNotTheDisk() throws {
        let url = try makeDeck(named: "Polish")
        let known = KnownDecks(defaults: defaults)
        known.remember(url)
        known.forget(url)

        #expect(KnownDecks(defaults: defaults).byName.isEmpty)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    /// A rename keeps the deck's place in the list of decks used, which Study and Add Cards
    /// read; a deck that is only in the folder has no entry to change.
    @Test func aRenamedDeckKeepsItsPlace() throws {
        let polish = try makeDeck(named: "Polish")
        let spanish = try makeDeck(named: "Spanish")
        let known = KnownDecks(defaults: defaults)
        known.remember(polish)
        known.remember(spanish)
        let renamed = directory.appending(path: "Czech.mnemit", directoryHint: .isDirectory)
        try FileManager.default.moveItem(at: polish, to: renamed)

        known.replace(polish, with: renamed)
        #expect(known.byName.map(\.name) == ["Czech", "Spanish"])
        let last = try #require(known.last)
        #expect(KnownDecks.isSameFile(last, spanish))

        let next = KnownDecks(defaults: defaults)
        #expect(next.byName.map(\.name) == ["Czech", "Spanish"])
        known.replace(directory.appending(path: "Unknown.mnemit"), with: renamed)
        #expect(known.byName.count == 2)
    }

    @Test func aDeletedDeckIsForgotten() throws {
        let url = try makeDeck(named: "Polish")
        KnownDecks(defaults: defaults).remember(url)
        try FileManager.default.removeItem(at: url)

        #expect(KnownDecks(defaults: defaults).last == nil)
        #expect(defaults.array(forKey: KnownDecks.key)?.isEmpty == true)
    }

    /// A bookmark that fails to resolve while access is away (iCloud Drive signed out, say) stays in the defaults and the
    /// deck is back on the list once it resolves; a bookmark of a file that is gone is dropped.
    @Test func aBookmarkThatFailsForAnotherReasonThanAMissingFileIsKeptUntilItResolves() throws {
        let polish = try makeDeck(named: "Polish")
        let gone = try makeDeck(named: "Gone")
        let known = KnownDecks(defaults: defaults)
        known.remember(polish)
        known.remember(gone)
        let stored = try #require(defaults.array(forKey: KnownDecks.key) as? [Data])
        #expect(stored.count == 2)

        // Gone's file is deleted; Polish's bookmark fails while access is away.
        var isAway = true
        let resolve: KnownDecks.Resolve = { bookmark in
            if bookmark == stored[0] { throw CocoaError(.fileNoSuchFile) }
            if isAway { throw CocoaError(.fileReadNoPermission) }
            return (polish, false)
        }
        let away = KnownDecks(defaults: defaults, resolve: resolve)
        #expect(away.byName.isEmpty)
        // Polish is kept for the day access returns, Gone is not.
        #expect((defaults.array(forKey: KnownDecks.key) as? [Data]) == [stored[1]])

        isAway = false
        away.refreshFolder()
        #expect(away.byName.map(\.name) == ["Polish"])
        #expect((defaults.array(forKey: KnownDecks.key) as? [Data]) == [stored[1]])
        #expect(KnownDecks(defaults: defaults).byName.map(\.name) == ["Polish"])
    }

    @Test func aPackageIsTheSameFileWithOrWithoutTheSlashAtTheEnd() {
        let url = URL(fileURLWithPath: "/Users/learner/Library/Mobile Documents/com~apple~CloudDocs/Polish.mnemit")
        #expect(KnownDecks.isSameFile(url, URL(fileURLWithPath: url.path + "/", isDirectory: true)))
        #expect(!KnownDecks.isSameFile(url, url.deletingLastPathComponent().appending(path: "German.mnemit")))
    }

    private func makeDeck(named name: String) throws -> URL {
        let url = directory.appending(path: "\(name).mnemit", directoryHint: .isDirectory)
        try DeckFile.fileWrapper(for: Deck()).write(to: url, options: .atomic, originalContentsURL: nil)
        return url
    }
}
