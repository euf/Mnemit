import SwiftUI
import Testing
import UIKit

@testable import VocTrain
@testable import VocabCore

/// Draws the sheets and the options screen of the deck editing in their states, light and
/// dark, at the size of an iPhone 13 mini (375 × 812), and writes PNGs to look at, as
/// `StudyScreenSnapshotTests` does. The sheets are presented as sheets, so their top edge
/// and the bar are in the picture.
///
/// The directory is `STUDY_SHOTS_DIR` (pass it to `xcodebuild` as `TEST_RUNNER_STUDY_SHOTS_DIR`),
/// else a folder in the temporary directory; the files are named `edit-…`. The tests fail only
/// if a picture can't be made; what the pictures show is for a person to judge.
@Suite(.serialized, .timeLimit(.minutes(5)))
@MainActor
struct DeckEditingSnapshotTests {
    static let size = CGSize(width: 375, height: 812)
    let created = Date(timeIntervalSince1970: 1_791_216_000)

    private var directory: URL {
        let path = ProcessInfo.processInfo.environment["STUDY_SHOTS_DIR"]
        let url = path.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory.appendingPathComponent("study-shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// The undo managers of the documents made: a document holds its own weakly, and one that
    /// is gone can't be edited, which the screens show by switching their controls off.
    private static var undoManagers: [UndoManager] = []

    /// A deck with a word of both directions and an older card without a word key.
    private func makeDocument() throws -> (VocabularyDocument, UndoManager) {
        let cards = [
            Card(text: CardText(question: "ο κλέφτης", answer: "thief")!, note: "κλέφτης#ο", kind: .recognition, created: created),
            Card(text: CardText(question: "thief", answer: "ο κλέφτης")!, note: "κλέφτης#ο", kind: .production, created: created),
            Card(text: CardText(question: "η αστυνομία", answer: "the police")!, created: created),
        ]
        let document = try VocabularyDocument(deck: Deck(cards: cards), clock: StudyClock { [created] in created.addingTimeInterval(60) })
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        Self.undoManagers.append(undoManager)
        return (document, undoManager)
    }

    // MARK: Hosting

    /// The view in a window on the app's scene, as a sheet over a plain page, or as the root
    /// of the window, with the run loop given time to lay it out and draw it.
    private func host<Root: View>(_ root: Root, dark: Bool, textSize: DynamicTypeSize? = nil, asSheet: Bool = true) async throws -> UIWindow {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: Self.size)
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        window.windowLevel = .alert + 1
        let controller = UIHostingController(rootView: root.dynamicTypeSize(textSize ?? .large))
        if asSheet {
            let page = UIViewController()
            page.view.backgroundColor = .systemGroupedBackground
            window.rootViewController = page
            window.makeKeyAndVisible()
            page.present(controller, animated: false)
        } else {
            window.rootViewController = controller
            window.makeKeyAndVisible()
        }
        try await Task.sleep(for: .milliseconds(700))
        return window
    }

    private func snapshot(_ window: UIWindow) -> UIImage {
        let bounds = CGRect(origin: .zero, size: Self.size)
        return UIGraphicsImageRenderer(bounds: bounds).image { _ in
            window.drawHierarchy(in: bounds, afterScreenUpdates: true)
        }
    }

    private func write(_ window: UIWindow, name: String, dark: Bool) throws {
        let data = try #require(snapshot(window).pngData())
        try data.write(to: directory.appendingPathComponent("edit-\(name)-\(dark ? "dark" : "light").png"))
    }

    // MARK: Add Cards

    private static let list = """
        κλέβω = to steal
        η κλοπή = theft
        ο κλέφτης = thief
        ο ταχυδρόμος = the postman
        ο ταχυδρόμος = postman
        thief is a word
        το σπίτι - the house
        """

    @Test(arguments: [false, true])
    func addOneCard(dark: Bool) async throws {
        let (document, _) = try makeDocument()
        let empty = try await host(AddCardsSheet(document: document), dark: dark)
        try write(empty, name: "add-1-one-empty", dark: dark)
        empty.isHidden = true

        // The question is in the deck already: the warning under the fields.
        let filled = try await host(AddCardsSheet(document: document, question: "ο κλέφτης", answer: "thief / robber", hint: "noun"), dark: dark)
        try write(filled, name: "add-2-one-filled", dark: dark)
        filled.isHidden = true

        for (name, size) in [("add-7-one-xxxl", DynamicTypeSize.xxxLarge), ("add-8-one-ax3", .accessibility3)] {
            let large = try await host(AddCardsSheet(document: document, question: "ο ταχυδρόμος", answer: "the postman", hint: "noun"), dark: dark, textSize: size)
            try write(large, name: name, dark: dark)
            large.isHidden = true
        }
    }

    /// Just after Add: the fields are empty and the confirmation counts the two cards.
    @Test(arguments: [false, true])
    func theConfirmationAfterACard(dark: Bool) async throws {
        let (document, _) = try makeDocument()
        let window = try await host(AddCardsSheet(document: document, added: 2), dark: dark)
        try write(window, name: "add-3-added", dark: dark)
        window.isHidden = true
    }

    @Test(arguments: [false, true])
    func addFromAList(dark: Bool) async throws {
        let (document, _) = try makeDocument()
        let empty = try await host(AddCardsSheet(document: document, showsList: true), dark: dark)
        try write(empty, name: "add-4-list-empty", dark: dark)
        empty.isHidden = true

        let filled = try await host(AddCardsSheet(document: document, showsList: true, list: Self.list), dark: dark)
        try write(filled, name: "add-5-list-preview", dark: dark)
        filled.isHidden = true

        // Every line is a word: the rows of the preview, a word of the deck and a word twice
        // among them.
        let rows = try await host(
            AddCardsSheet(document: document, showsList: true, list: "κλέβω = to steal\nο κλέφτης = thief\nο ταχυδρόμος = the postman\nο ταχυδρόμος = postman"), dark: dark)
        try write(rows, name: "add-5b-list-rows", dark: dark)
        rows.isHidden = true

        let large = try await host(AddCardsSheet(document: document, showsList: true, list: Self.list), dark: dark, textSize: .accessibility2)
        try write(large, name: "add-6-list-ax2", dark: dark)
        large.isHidden = true
    }

    /// Just after Add N Cards: the list is empty again.
    @Test(arguments: [false, true])
    func theConfirmationAfterAList(dark: Bool) async throws {
        let (document, _) = try makeDocument()
        let window = try await host(AddCardsSheet(document: document, showsList: true, added: 6), dark: dark)
        try write(window, name: "add-9-list-added", dark: dark)
        window.isHidden = true
    }

    // MARK: New and renamed decks

    @Test(arguments: [false, true])
    func nameSheets(dark: Bool) async throws {
        let empty = try await host(NewDeckSheet(onCreate: { _, _ in }), dark: dark)
        try write(empty, name: "deck-1-new-empty", dark: dark)
        empty.isHidden = true

        let filled = try await host(DeckNameSheet(title: "New Deck", actionTitle: "Create", current: nil, prefill: "Greek B1", mark: .constant(false), perform: { _ in }), dark: dark)
        try write(filled, name: "deck-2-new-filled", dark: dark)
        filled.isHidden = true

        let invalid = try await host(DeckNameSheet(title: "New Deck", actionTitle: "Create", current: nil, prefill: "Greek/B1", perform: { _ in }), dark: dark)
        try write(invalid, name: "deck-3-new-invalid", dark: dark)
        invalid.isHidden = true

        let rename = try await host(RenameDeckSheet(currentName: "Greek A2", onRename: { _ in }), dark: dark)
        try write(rename, name: "deck-5-rename", dark: dark)
        rename.isHidden = true

        let large = try await host(DeckNameSheet(title: "New Deck", actionTitle: "Create", current: nil, prefill: "Greek B1", mark: .constant(false), perform: { _ in }), dark: dark, textSize: .accessibility3)
        try write(large, name: "deck-6-new-ax3", dark: dark)
        large.isHidden = true
    }

    /// What the creating threw, under the field.
    @Test(arguments: [false, true])
    func aFailureStaysUnderTheField(dark: Bool) async throws {
        let message = try #require(DeckFiles.Failure.nameTaken("Greek B1").errorDescription)
        let window = try await host(
            DeckNameSheet(title: "New Deck", actionTitle: "Create", current: nil, prefill: "Greek B1", failure: message, perform: { _ in }), dark: dark)
        try write(window, name: "deck-4-new-taken", dark: dark)
        window.isHidden = true
    }

    // MARK: Options

    private func options(_ change: (inout LearningOptions) -> Void) throws -> VocabularyDocument {
        let (document, undoManager) = try makeDocument()
        var options = LearningOptions()
        change(&options)
        undoManager.beginUndoGrouping()
        document.updateLearningOptions(options)
        undoManager.endUndoGrouping()
        return document
    }

    @Test(arguments: [false, true])
    func optionsScreen(dark: Bool) async throws {
        let (document, _) = try makeDocument()
        let main = try await host(NavigationStack { DeckOptionsScreen(document: document) }, dark: dark, asSheet: false)
        try write(main, name: "options-1-main", dark: dark)
        main.isHidden = true

        let custom = try options {
            $0.introducesNewCards = true
            $0.newCardsPerSession = nil
            $0.newCardOrder = .newestFirst
            $0.targetRecall = 0.95
            $0.newProductionPerSession = 3
            $0.productionUnlockDays = 0
            $0.leechThreshold = 0
        }
        let changed = try await host(NavigationStack { DeckOptionsScreen(document: custom) }, dark: dark, asSheet: false)
        try write(changed, name: "options-2-main-custom", dark: dark)
        changed.isHidden = true

        for (name, size) in [("options-3-main-xxxl", DynamicTypeSize.xxxLarge), ("options-4-main-ax3", .accessibility3)] {
            let large = try await host(NavigationStack { DeckOptionsScreen(document: document) }, dark: dark, textSize: size, asSheet: false)
            try write(large, name: name, dark: dark)
            large.isHidden = true
        }
    }

    @Test(arguments: [false, true])
    func advancedOptionsScreen(dark: Bool) async throws {
        let (document, _) = try makeDocument()
        let advanced = try await host(NavigationStack { DeckAdvancedOptionsScreen(document: document) }, dark: dark, asSheet: false)
        try write(advanced, name: "options-5-advanced", dark: dark)
        advanced.isHidden = true

        let large = try await host(NavigationStack { DeckAdvancedOptionsScreen(document: document) }, dark: dark, textSize: .accessibility3, asSheet: false)
        try write(large, name: "options-6-advanced-ax3", dark: dark)
        large.isHidden = true
    }
}
