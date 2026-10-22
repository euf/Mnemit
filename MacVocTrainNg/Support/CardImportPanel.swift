import AppKit
import UniformTypeIdentifiers
import VocabCore

extension CardImport {
    /// Asks for a file and reads it; `nil` if the user cancels or the file has no cards.
    static func chooseFile(existing: [Card], created: Date) -> Preview? {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.delimitedText, .plainText]
        openPanel.allowsMultipleSelection = false
        openPanel.message = String(localized: "Choose a CSV or TSV file with a question, an answer and an optional hint per row.")
        openPanel.prompt = String(localized: "Import")
        guard openPanel.runModal() == .OK, let source = openPanel.url else { return nil }

        let data: Data
        do {
            data = try Data(contentsOf: source)
        } catch {
            showError(error.localizedDescription)
            return nil
        }
        let preview = preview(of: data, fileName: source.lastPathComponent, existing: existing, created: created)
        guard !preview.candidates.isEmpty else {
            showError(String(localized: "“\(source.lastPathComponent)” contains no rows with a question and an answer."))
            return nil
        }
        return preview
    }

    private static func showError(_ message: String) {
        NSAlert.showWarning(String(localized: "Import failed"), message: message)
    }
}
