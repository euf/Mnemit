import SwiftUI
import Testing
import UIKit

@testable import VocTrain
@testable import VocabCore

/// Draws the import preview sheet, light and dark, at the size of an iPhone 13 mini, and writes
/// PNGs to look at, as `DeckEditingSnapshotTests` does (`TEST_RUNNER_STUDY_SHOTS_DIR`; the files
/// are named `import-…`). The tests fail only if a picture can't be made; what it shows is for a
/// person to judge.
@Suite(.serialized, .timeLimit(.minutes(5)))
@MainActor
struct ImportPreviewSnapshotTests {
    static let size = CGSize(width: 375, height: 812)
    let created = Date(timeIntervalSince1970: 1_791_216_000)

    private var directory: URL {
        let path = ProcessInfo.processInfo.environment["STUDY_SHOTS_DIR"]
        let url = path.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory.appendingPathComponent("study-shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// The undo managers of the documents made, which a document holds weakly.
    private static var undoManagers: [UndoManager] = []

    @Test(arguments: [false, true])
    func previewSheet(dark: Bool) async throws {
        let existing = Card(text: CardText(question: "ο κλέφτης", answer: "thief")!, created: created)
        let document = try VocabularyDocument(deck: Deck(cards: [existing]), clock: StudyClock { [created] in created.addingTimeInterval(60) })
        let undoManager = UndoManager()
        document.attachUndoManager(undoManager)
        Self.undoManagers.append(undoManager)

        let text = """
            #separator:tab
            #html:false
            #columns:Front\tBack\tHint\tWord Key\tKind
            ο κλέφτης\tthief\tnoun\tκλέφτης#ο\trecognition
            η κλοπή\ttheft\t\tκλοπή#η\trecognition
            theft\tη κλοπή\t\tκλοπή#η\tproduction
            ο ταχυδρόμος\tthe postman\t\t\t
            ο ταχυδρόμος\tpostman\tmale\t\t
            το σπίτι\t\t\t\t
            """
        let preview = CardImport.preview(of: Data(text.utf8), fileName: "greek-a2.tsv", existing: document.deck.cards, created: created)
        #expect(preview.candidates.count == 5)
        #expect(preview.skippedRows == 1)

        let window = try await host(ImportPreviewSheet(document: document, file: ImportedFile(name: "greek-a2.tsv", data: Data()), preview: preview), dark: dark)
        let image = UIGraphicsImageRenderer(bounds: CGRect(origin: .zero, size: Self.size)).image { _ in
            window.drawHierarchy(in: CGRect(origin: .zero, size: Self.size), afterScreenUpdates: true)
        }
        let data = try #require(image.pngData())
        try data.write(to: directory.appendingPathComponent("import-preview-\(dark ? "dark" : "light").png"))
        window.isHidden = true
    }

    /// The sheet as a sheet over a plain page, with the run loop given time to lay it out.
    private func host<Root: View>(_ root: Root, dark: Bool) async throws -> UIWindow {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: Self.size)
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        window.windowLevel = .alert + 1
        let page = UIViewController()
        page.view.backgroundColor = .systemGroupedBackground
        window.rootViewController = page
        window.makeKeyAndVisible()
        page.present(UIHostingController(rootView: root), animated: false)
        try await Task.sleep(for: .milliseconds(700))
        return window
    }
}
