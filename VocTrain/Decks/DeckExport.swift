import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers
import VocabCore

/// The cards of a deck as a TSV file for the share sheet, see `CardExport`: Anki imports it as
/// it is, and so does Mnemit. The file is written when the share sheet asks for it, so it holds
/// the cards of that moment, named after the deck.
struct DeckExport: Transferable, Sendable {
    var name: String
    var cards: [Card]
    var calendar: StudyCalendar

    var fileName: String { "\(name).tsv" }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .tabSeparatedText) { export in
            SentTransferredFile(try export.write())
        }
    }

    /// Writes the file to a folder of its own in the temporary directory, which keeps the
    /// deck's name for it, and returns its URL.
    func write() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: fileName, directoryHint: .notDirectory)
        try CardExport.data(of: cards, format: .tsv, includingLearningState: false, calendar: calendar).write(to: url, options: .atomic)
        return url
    }
}

/// "Export…" in the menu of the deck screen: the share sheet with the TSV file of the cards the
/// deck has now.
struct ExportLink: View {
    @ObservedObject var document: VocabularyDocument
    var name: String

    var body: some View {
        let export = DeckExport(name: name, cards: document.deck.cards, calendar: document.calendar)
        ShareLink(item: export, preview: SharePreview(export.fileName)) {
            Label("Export…", systemImage: "square.and.arrow.up")
        }
    }
}
