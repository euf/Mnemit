import AppKit
import SwiftUI
import Testing

@testable import MacVocTrain
@testable import VocabCore

/// Draws the Mac's Options sheet, New Deck and Add Cards, light and dark, to PNGs to look at, as
/// `TodayWindowSnapshotTests` does: into `STUDY_SHOTS_DIR` (pass it as `TEST_RUNNER_STUDY_SHOTS_DIR`), else the
/// temporary directory. The windows never show. The test fails only if a picture can't be made.
@MainActor
struct DeckSheetsSnapshotMacTests {
    private var directory: URL {
        let path = ProcessInfo.processInfo.environment["STUDY_SHOTS_DIR"]
        let url = path.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory.appendingPathComponent("study-shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ view: some View, name: String, size: CGSize? = nil) throws {
        for dark in [false, true] {
            let hosting = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size ?? hosting.fittingSize), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            window.contentView = hosting
            hosting.layoutSubtreeIfNeeded()
            let rep = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            let data = try #require(rep.representation(using: .png, properties: [:]))
            let file = "sheet-mac-\(name)-\(dark ? "dark" : "light").png"
            do {
                try data.write(to: directory.appendingPathComponent(file))
            } catch {
                try data.write(to: FileManager.default.temporaryDirectory.appendingPathComponent(file))
            }
            window.close()
        }
    }

    @Test func options() throws {
        try write(DeckOptionsView(document: VocabularyDocument(deck: Deck())), name: "options")
    }

    @Test func newDeck() throws {
        try write(NewDeckView(onCreate: { _ in }), name: "new-deck")
        try write(NewDeckView(name: "Greek B1", onCreate: { _ in }), name: "new-deck-filled")
    }

    @Test func addCards() throws {
        let document = VocabularyDocument()
        try write(AddCardsView(document: document, mode: .oneCard, question: "κλέβω", answer: "to steal"), name: "add-one")
        try write(
            AddCardsView(document: document, mode: .fromList, list: "κλέβω = to steal\nη κλοπή = theft\nο κλέφτης = thief\nbad line", added: 2),
            name: "add-list")
        // Cards added: Study These Now sits beside Add.
        let added = [Card(question: "κλέβω", answer: "to steal").id]
        try write(AddCardsView(document: document, mode: .oneCard, added: 2, studyable: added), name: "add-study-now")
    }
}
