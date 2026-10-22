import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// What the deck browser decides without a web view: which hosts stay in it and which go to
/// Safari, which responses become downloads, what a download is called, and how a finished one
/// reaches the import. No network, no web view.
@MainActor @Suite(.timeLimit(.minutes(3)))
struct DeckWebBrowserTests {
    // MARK: Hosts

    @Test func theSourcesAreTheStartPageAndTheBookmarks() {
        #expect(DeckSources.all.map(\.title) == ["AnkiWeb Shared Decks", "MintDeck Free Decks"])
        #expect(DeckSources.start.absoluteString == "https://ankiweb.net/shared/decks")
        #expect(AnkiWebLink.url == DeckSources.start)
        #expect(DeckSources.all.map(\.domain) == ["ankiweb.net", "mintdeck.app"])
        #expect(DeckSources.all.allSatisfy { DeckSources.isKnown($0.url) })
    }

    @Test(arguments: [
        "https://ankiweb.net/shared/decks",
        "https://ankiweb.net",
        "https://ANKIWEB.net/shared/info/1942931019",
        "https://www.ankiweb.net/shared/decks",
        "https://www.mintdeck.app/decks",
        "https://mintdeck.app/decks/greek",
        "https://files.mintdeck.app/greek.csv",
        "blob:https://ankiweb.net/6f1c3a52-0000-4000-8000-000000000000",
    ])
    func aSourceStaysInTheBrowser(address: String) throws {
        let url = try #require(URL(string: address))
        #expect(DeckSources.isKnown(url))
        #expect(!DeckSources.opensInSafari(url, isLinkActivation: true))
    }

    @Test(arguments: [
        "https://example.com/ankiweb.net",
        "https://ankiweb.net.example.com/shared/decks",
        "https://notankiweb.net/shared/decks",
        "https://mintdeck.app.evil.example/decks",
        "https://forums.ankiweb.org/t/x",
        "http://ankiweb.net/shared/decks",
        "mailto:support@ankiweb.net",
        "blob:https://example.com/6f1c3a52-0000-4000-8000-000000000000",
    ])
    func anyOtherLinkGoesToSafari(address: String) throws {
        let url = try #require(URL(string: address))
        #expect(!DeckSources.isKnown(url))
        #expect(DeckSources.opensInSafari(url, isLinkActivation: true))
    }

    /// A redirect that the page makes itself is not a click: the file store a source sends the
    /// download to keeps the learner in the browser.
    @Test func onlyAClickLeavesTheBrowser() throws {
        let store = try #require(URL(string: "https://files.example.com/greek.apkg"))
        #expect(!DeckSources.opensInSafari(store, isLinkActivation: false))
        #expect(!DeckSources.isKnown(nil))
        #expect(!DeckSources.opensInSafari(nil, isLinkActivation: false))
    }

    // MARK: Which response is a download

    private func isDownload(
        _ address: String, mime: String? = "text/html", disposition: String? = nil, canShow: Bool = true
    ) -> Bool {
        DeckDownload.shouldDownload(url: URL(string: address), mimeType: mime, contentDisposition: disposition, canShow: canShow)
    }

    @Test func aPackageIsADownloadByItsFileName() {
        #expect(isDownload("https://ankiweb.net/shared/downloadDeck/1", disposition: "attachment; filename=\"Greek Core.apkg\""))
        #expect(isDownload("https://ankiweb.net/shared/downloadDeck/1", disposition: "inline; filename=\"GREEK.APKG\""))
        #expect(isDownload("https://files.example.com/decks/greek.apkg"))
        // The name of the header wins over the path.
        #expect(isDownload("https://ankiweb.net/dl/1", disposition: "attachment; filename*=UTF-8''Gr%C3%A4ka.apkg"))
    }

    @Test func aPackageIsADownloadByItsMimeType() {
        #expect(isDownload("https://ankiweb.net/shared/downloadDeck/1", mime: "application/octet-stream"))
        #expect(isDownload("https://ankiweb.net/shared/downloadDeck/1", mime: "application/octet-stream", canShow: false))
        #expect(isDownload("https://ankiweb.net/shared/downloadDeck/1", mime: "application/zip"))
        #expect(isDownload("https://ankiweb.net/shared/downloadDeck/1", mime: "application/x-zip-compressed"))
        #expect(isDownload("https://ankiweb.net/shared/downloadDeck/1", mime: "Application/Octet-Stream"))
    }

    @Test func aTableIsADownloadByItsNameOrItsType() {
        #expect(isDownload("https://www.mintdeck.app/files/greek.csv", mime: "text/plain"))
        #expect(isDownload("https://www.mintdeck.app/files/greek.TSV", mime: "text/plain"))
        #expect(isDownload("https://www.mintdeck.app/export/42", mime: "text/csv"))
        #expect(isDownload("https://www.mintdeck.app/export/42", mime: "text/tab-separated-values"))
        #expect(isDownload("https://www.mintdeck.app/export/42", mime: "text/plain", disposition: "attachment; filename=\"greek.csv\""))
    }

    @Test func anAttachmentOrWhatTheViewCannotShowIsADownload() {
        #expect(isDownload("https://ankiweb.net/x", disposition: "attachment"))
        #expect(isDownload("https://ankiweb.net/x", disposition: "Attachment; filename=\"notes.pdf\""))
        #expect(isDownload("https://ankiweb.net/x", mime: "application/x-unknown", canShow: false))
    }

    @Test func aPageIsNoDownload() {
        #expect(!isDownload("https://ankiweb.net/shared/decks"))
        #expect(!isDownload("https://ankiweb.net/shared/info/1942931019", disposition: "inline"))
        #expect(!isDownload("https://www.mintdeck.app/decks", mime: "text/html"))
        #expect(!isDownload("https://ankiweb.net/img/logo.png", mime: "image/png"))
        #expect(!isDownload("https://ankiweb.net/x", mime: nil))
    }

    // MARK: Names

    @Test func theHeaderGivesTheTypeAndTheFileName() {
        #expect(DeckDownload.parse("attachment; filename=\"a b.apkg\"").fileName == "a b.apkg")
        #expect(DeckDownload.parse("attachment; filename=a.apkg").fileName == "a.apkg")
        #expect(DeckDownload.parse("attachment; filename=\"x.apkg\"; filename*=UTF-8''%CE%B3%CE%AC%CF%84%CE%B1.apkg").fileName == "γάτα.apkg")
        #expect(DeckDownload.parse("Attachment").type == "attachment")
        #expect(DeckDownload.parse("attachment").fileName == nil)
        #expect(DeckDownload.parse(nil).type == "")
    }

    @Test func aDownloadIsSavedUnderAnImportableName() {
        #expect(DeckDownload.localName(forSuggested: "Greek Core.apkg") == "Greek Core.apkg")
        #expect(DeckDownload.localName(forSuggested: "words.csv") == "words.csv")
        #expect(DeckDownload.localName(forSuggested: "WORDS.TSV") == "WORDS.TSV")
        // A name without an extension the import knows is taken for a package.
        #expect(DeckDownload.localName(forSuggested: "Greek Core") == "Greek Core.apkg")
        #expect(DeckDownload.localName(forSuggested: "notes.pdf") == "notes.pdf.apkg")
        #expect(DeckDownload.localName(forSuggested: "") == "Deck.apkg")
        // No folders, whatever the source says.
        #expect(DeckDownload.localName(forSuggested: "../../Library/x.apkg") == "x.apkg")
    }

    // MARK: Into the import

    @Test func aFinishedDownloadKeepsItsNameInAFolderOfItsOwn() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        let first = try DeckDownload.makeDestination(forSuggested: "Greek Core.apkg", in: folder)
        #expect(first.lastPathComponent == "Greek Core.apkg")
        #expect(first.deletingLastPathComponent().deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL)
        try Data("PK".utf8).write(to: first)

        // The next download clears the earlier one: the import has taken it over by then.
        let second = try DeckDownload.makeDestination(forSuggested: "words.csv", in: folder)
        #expect(second.deletingLastPathComponent() != first.deletingLastPathComponent())
        #expect(!FileManager.default.fileExists(atPath: first.path))
        #expect(FileManager.default.fileExists(atPath: second.deletingLastPathComponent().path))
    }

    /// The package takes the way of "Open in Mnemit": `StartScreen.receiveDownload` hands it to
    /// `receiveAnki`, which copies it and asks where its cards go.
    @Test func aDownloadedPackageGoesTheWayOfAnIncomingPackage() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { IncomingPackages.purge(folder) }
        let file = try DeckDownload.makeDestination(forSuggested: "greek-legacy2", in: folder.appending(path: "Downloads"))
        try FileManager.default.copyItem(at: AnkiImportScreenTests.fixture("greek-legacy2"), to: file)

        #expect(file.isAnkiPackage)
        #expect(IncomingLink(file) == .ankiPackage)
        let copy = try await IncomingPackages.copy(file, into: folder.appending(path: "Incoming"))
        #expect(IncomingLink(copy) == .ankiPackage)
        #expect(try CardImport.readAnki(at: copy).notes.count == 7)
    }

    /// A table is read into the preview of the picker's file, with the name it was saved under.
    @Test func aDownloadedTableGoesTheWayOfAPickedFile() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = try DeckDownload.makeDestination(forSuggested: "greek.csv", in: folder)
        try Data("γάτα,cat\nσκύλος,dog\n".utf8).write(to: file)

        #expect(!file.isAnkiPackage)
        let imported = try ImportedFile(contentsOf: file)
        #expect(imported.name == "greek.csv")
        let data = try #require(imported.data)
        let preview = CardImport.preview(of: data, fileName: imported.name, existing: [], created: Date(timeIntervalSince1970: 1_791_216_000))
        #expect(preview.candidates.map(\.card.question) == ["γάτα", "σκύλος"])
        // With no deck, the new one is named after the file.
        #expect(CardImport.deckName(forDecks: [], fileName: imported.name) == "greek")
    }
}
