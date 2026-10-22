import AppKit
import UniformTypeIdentifiers
import VocabCore

extension CardImport {
    /// Asks for a CSV or TSV file or an Anki package; `nil` if the user cancels.
    static func chooseFile() -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.delimitedText, .plainText, .ankiPackage]
        openPanel.allowsMultipleSelection = false
        openPanel.message = String(localized: "Choose an Anki package, or a CSV or TSV file with a question, an answer and an optional hint per row.")
        openPanel.prompt = String(localized: "Import")
        return openPanel.runModal() == .OK ? openPanel.url : nil
    }

    /// Reads the file at `url` into the preview for the deck of `document`; the cards of an Anki
    /// package are made off the main thread. `isNewDeck`: the document is a new deck for the
    /// package, which takes Anki's FSRS settings. `nil`, after telling the learner, if the file
    /// can't be read or has no cards.
    static func preview(ofFileAt url: URL, for document: VocabularyDocument, isNewDeck: Bool = false) async -> Preview? {
        let name = url.lastPathComponent
        let preview: Preview
        let elsewhere = await OpenDecks.shared.wordIndex(excluding: document)
        do {
            if url.isAnkiPackage {
                let package = try await loadAnki(at: url)
                preview = await ankiPreview(of: package, fileName: name, for: document, isNewDeck: isNewDeck, elsewhere: elsewhere)
            } else {
                let data = try Data(contentsOf: url)
                preview = self.preview(of: data, fileName: name, existing: document.deck.cards, elsewhere: elsewhere, created: document.clock.now)
            }
        } catch {
            showError(failureMessage(error))
            return nil
        }
        guard !preview.candidates.isEmpty else {
            showError(
                preview.anki?.noCardsMessage(fileName: name)
                    ?? String(localized: "“\(name)” contains no rows with a question and an answer."))
            return nil
        }
        return preview
    }

    private static func showError(_ message: String) {
        NSAlert.showWarning(String(localized: "Import failed"), message: message)
    }
}
