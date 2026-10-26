import AppKit
import UniformTypeIdentifiers
import VocabCore

/// A table or an Anki package for the page of the deck made for it. Equal by identity: two imports of one file are two.
struct ImportFile: Hashable {
    let id = UUID()
    let url: URL
    /// The package, once it was read to name the deck, so the preview doesn't read it again.
    var package: AnkiImport?

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// How files reach the window: Finder, the Dock, File ▸ Open Deck… and the deck browser's downloads.
extension Shell {
    /// Finder or another app hands over files. A deck of the folder is selected, one from elsewhere joins the Other
    /// Decks and is selected, and a package or a table that Anki or the browser saved fills a new deck. The window comes
    /// forward, back from ⌘W too.
    func receive(_ urls: [URL]) {
        let decks = urls.filter { !$0.isAnkiPackage }
        if !decks.isEmpty { open(decks) }
        for package in urls.filter(\.isAnkiPackage) {
            Task { await importIntoNewDeck(from: package) }
        }
        showWindow()
    }

    /// File ▸ Open Deck…: the learner chooses decks, which are selected, outside the folder too.
    func chooseDecks() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = DeckFile.fileExtensions.compactMap { UTType(filenameExtension: $0) }
        panel.prompt = String(localized: "Open")
        guard panel.runModal() == .OK else { return }
        open(panel.urls)
    }

    /// Makes a deck in the folder for the cards of `file`, a package or a table: named after the Anki deck or the file,
    /// numbered if the name is taken, shown with the preview of the cards to choose from.
    func importIntoNewDeck(from file: URL) async {
        do {
            let package = file.isAnkiPackage ? try await CardImport.loadAnki(at: file) : nil
            let name = CardImport.deckName(forDecks: package?.deckNames ?? [], fileName: file.lastPathComponent)
            var number = 1
            while true {
                do {
                    try await newDeck(named: number == 1 ? name : "\(name) \(number)")
                    break
                } catch DeckFiles.Failure.nameTaken where number < 100 {
                    number += 1
                }
            }
            request = .importFile(ImportFile(url: file, package: package))
        } catch {
            if (error as? CocoaError)?.code != .userCancelled { notice = CardImport.failureMessage(error) }
        }
        showWindow()
    }
}
