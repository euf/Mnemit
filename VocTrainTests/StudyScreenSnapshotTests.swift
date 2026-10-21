import SwiftUI
import Testing
import UIKit

@testable import VocTrain
@testable import VocabCore

/// Draws the study screen in its states, light and dark, at the size of an iPhone 13 mini
/// (375 × 812), and writes PNGs to look at: nobody has to open the app. The screen is hosted in
/// a real window, so the bar with the close button, the ring and the menu is in the picture.
///
/// The directory is `STUDY_SHOTS_DIR` (pass it to `xcodebuild` as `TEST_RUNNER_STUDY_SHOTS_DIR`),
/// else a folder in the temporary directory. The test fails only if a picture can't be made;
/// what the pictures show is for a person to judge.
@Suite(.serialized)
@MainActor
struct StudyScreenSnapshotTests {
    static let size = CGSize(width: 375, height: 812)
    let created = Date(timeIntervalSince1970: 1_791_216_000)

    private var directory: URL {
        let path = ProcessInfo.processInfo.environment["STUDY_SHOTS_DIR"]
        let url = path.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory.appendingPathComponent("study-shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Before anything is made: the run must be silent, the simulator plays through the Mac's
    /// speakers. `GreekSpeech` speaks nothing and leaves the audio session alone under test; the
    /// test stops here if it could still speak. Nothing is written to the preferences.
    private func beSilent() throws {
        try #require(GreekSpeech.isUnderTest, "a test run must not speak")
    }

    private func makeDocument() throws -> (VocabularyDocument, UndoManager) {
        let texts: [(String, String, String)] = [
            ("αφού", "после того как; раз, поскольку · after; since\nΑφού δεν έχεις δουλειά, έλα μαζί μας.", "conjunction"),
            ("η αστυνομία", "полиция · the police\nΗ αστυνομία ήρθε αμέσως.", ""),
            ("βάζω φωτιά (έβαλα)", "поджигать · to set fire", ""),
            ("ο Άγγλος", "англичанин · Englishman\nΟ Τζον είναι Άγγλος.", ""),
            ("υπεύθυνος, -η, -ο", "ответственный · responsible", "adjective"),
            ("ο ταχυδρόμος", "почтальон · the postman\nΟ ταχυδρόμος έρχεται κάθε πρωί.", ""),
        ]
        let cards = texts.map { Card(text: CardText(question: $0.0, answer: $0.1, hint: $0.2)!, created: created) }
        let document = try VocabularyDocument(deck: Deck(cards: cards), clock: StudyClock { [created] in created.addingTimeInterval(60) })
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        return (document, undoManager)
    }

    private func grade(_ model: StudyModel, _ grade: Grade, undoManager: UndoManager) {
        model.reveal()
        undoManager.beginUndoGrouping()
        model.grade(grade)
        undoManager.endUndoGrouping()
    }

    /// The screen at its place in a window on the app's scene, with the run loop given time to
    /// lay it out and draw it.
    private func host(_ model: StudyModel, ring: DailyRingModel, flight: CardFlight, dark: Bool) async throws -> (UIWindow, UIHostingController<StudyView>) {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: Self.size)
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        window.windowLevel = .alert + 1
        let controller = UIHostingController(rootView: StudyView(model: model, ring: ring, flight: flight, onClose: {}))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(500))
        return (window, controller)
    }

    private func write(_ window: UIWindow, name: String, dark: Bool) throws {
        let bounds = CGRect(origin: .zero, size: Self.size)
        let image = UIGraphicsImageRenderer(bounds: bounds).image { _ in
            window.drawHierarchy(in: bounds, afterScreenUpdates: true)
        }
        let data = try #require(image.pngData())
        try data.write(to: directory.appendingPathComponent("\(name)-\(dark ? "dark" : "light").png"))
    }

    /// A model that has graded `reviews` cards, with the ring evaluated for them.
    private func prepare(reviews: Int) async throws -> (StudyModel, DailyRingModel) {
        try beSilent()
        let (document, undoManager) = try makeDocument()
        let model = StudyModel(document: document)
        for _ in 0..<reviews {
            grade(model, .easy, undoManager: undoManager)
        }
        let ring = DailyRingModel()
        ring.refresh(documents: [document], delay: .zero)
        try await Task.sleep(for: .milliseconds(300))
        return (model, ring)
    }

    @Test(arguments: [false, true])
    func questionAndAnswer(dark: Bool) async throws {
        let (model, ring) = try await prepare(reviews: 2)
        let (window, _) = try await host(model, ring: ring, flight: CardFlight(), dark: dark)
        try write(window, name: "1-question", dark: dark)
        model.reveal()
        try await Task.sleep(for: .milliseconds(400))
        try write(window, name: "2-revealed", dark: dark)
        window.isHidden = true
    }

    /// Mid-swipe in each zone: the card tinted, turned about where it was grabbed, and the
    /// button of the grade lit. The finger is at `grab` in the card (a share of its size).
    @Test(arguments: [false, true])
    func swipes(dark: Bool) async throws {
        let cases: [(name: String, translation: CGSize, grab: CGPoint)] = [
            ("3-swipe-forgot", CGSize(width: -110, height: 15), CGPoint(x: 0.5, y: 0.3)),
            ("4-swipe-hard", CGSize(width: 105, height: 80), CGPoint(x: 0.5, y: 0.7)),
            ("5-swipe-good", CGSize(width: 130, height: -20), CGPoint(x: 0.5, y: 0.3)),
            ("6-swipe-easy", CGSize(width: 90, height: -110), CGPoint(x: 0.5, y: 0.3)),
        ]
        for item in cases {
            let (model, ring) = try await prepare(reviews: 2)
            model.reveal()
            let flight = CardFlight()
            let (window, _) = try await host(model, ring: ring, flight: flight, dark: dark)
            let start = CGPoint(x: item.grab.x * flight.size.width, y: item.grab.y * flight.size.height)
            flight.drag(item.translation, from: start, isRevealed: true)
            try await Task.sleep(for: .milliseconds(400))
            try write(window, name: item.name, dark: dark)
            window.isHidden = true
        }
    }

    @Test(arguments: [false, true])
    func rest(dark: Bool) async throws {
        let (model, ring) = try await prepare(reviews: 6)
        #expect(model.isResting)
        let (window, _) = try await host(model, ring: ring, flight: CardFlight(), dark: dark)
        try write(window, name: "7-rest", dark: dark)
        window.isHidden = true
    }
}
