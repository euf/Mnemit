import AppKit
import SwiftUI
import Testing

@testable import MacVocTrain
@testable import VocabCore

/// Draws the Mac's study stream (`SessionView`) with flash cards, asking, with the answer shown, and at its end, light
/// and dark, to PNGs to look at, as `TodayWindowSnapshotTests` does: into `STUDY_SHOTS_DIR`, else the temporary
/// directory of the test host's container. The test fails only if a picture can't be made.
@MainActor
struct SessionSnapshotMacTests {
    private var directory: URL {
        let path = ProcessInfo.processInfo.environment["STUDY_SHOTS_DIR"]
        let url = path.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory.appendingPathComponent("study-shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ model: SessionViewModel, name: String) async throws {
        for dark in [false, true] {
            let hosting = NSHostingView(rootView: SessionView(model: model, ring: DailyRingModel(), onClose: {}).frame(width: 800, height: 600))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            window.contentView = hosting
            hosting.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(300))
            hosting.layoutSubtreeIfNeeded()
            let rep = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            let data = try #require(rep.representation(using: .png, properties: [:]))
            try data.write(to: directory.appendingPathComponent("session-mac-\(name)-\(dark ? "dark" : "light").png"))
            window.close()
        }
    }

    @Test func flashcards() async throws {
        let document = try VocabularyDocument(
            deck: Deck(cards: [Card(question: "το σπίτι", answer: "дом · the house"), Card(question: "ο δρόμος", answer: "дорога · the road")]))
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, autoAdvance: false, studyBy: .flashcards)
        try await write(model, name: "1-asking")
        model.reveal()
        try await write(model, name: "2-revealed")
        withExtendedLifetime(undoManager) {}
    }

    /// A deck whose limit takes no new card today: the stream rests at the end of the plan at once, with Push On.
    @Test func planEnd() async throws {
        var options = LearningOptions()
        options.newCardsPerSession = 0
        let document = try VocabularyDocument(
            deck: Deck(learningOptions: options, cards: [Card(question: "το σπίτι", answer: "дом · the house"), Card(question: "ο δρόμος", answer: "дорога · the road")]))
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, autoAdvance: false, studyBy: .flashcards)
        try await write(model, name: "3-plan-end")
        withExtendedLifetime(undoManager) {}
    }
}
