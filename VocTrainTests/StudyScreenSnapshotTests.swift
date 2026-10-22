import SwiftUI
import Testing
import UIKit

@testable import VocTrain
@testable import VocabCore

/// Draws the study screen in its states, light and dark, at the size of an iPhone 13 mini
/// (375 × 812), and writes PNGs to look at: nobody has to open the app. The screen is hosted in
/// a real window, so the bar with the close button, the ring and the menu is in the picture.
///
/// The directory is `STUDY_SHOTS_DIR` (pass it to `xcodebuild` as an environment variable,
/// `TEST_RUNNER_STUDY_SHOTS_DIR`), else a folder in the temporary directory. The test fails only
/// if a picture can't be made; what the pictures show is for a person to judge. The
/// measurements (`StudyScreenMeasureTests`) read the same screens by pixels.
@Suite(.serialized)
@MainActor
struct StudyScreenSnapshotTests {
    static let size = CGSize(width: 375, height: 812)
    let created = Date(timeIntervalSince1970: 1_791_216_000)

    typealias Texts = (question: String, answer: String, hint: String)

    static let defaultTexts: [Texts] = [
        ("αφού", "после того как; раз, поскольку · after; since\nΑφού δεν έχεις δουλειά, έλα μαζί μας.", "conjunction"),
        ("η αστυνομία", "полиция · the police\nΗ αστυνομία ήρθε αμέσως.", ""),
        ("βάζω φωτιά (έβαλα)", "поджигать · to set fire", ""),
        ("ο Άγγλος", "англичанин · Englishman\nΟ Τζον είναι Άγγλος.", ""),
        ("υπεύθυνος, -η, -ο", "ответственный · responsible", "adjective"),
        ("ο ταχυδρόμος", "почтальон · the postman\nΟ ταχυδρόμος έρχεται κάθε πρωί.", ""),
    ]
    /// The card that goes before the one a picture is about, so its grade leaves the chip.
    static let filler: Texts = ("το σπίτι", "дом · the house", "")
    /// A Greek word that wraps to two lines at the default text size, as the question.
    static let wrappingQuestion: Texts = ("απαντάω (απάντησα)", "отвечать · to answer\nΑπάντησα στο γράμμα του Γιάννη.", "verb")
    /// The same word as the head of an answer, under a question in Russian.
    static let wrappingAnswer: Texts = ("отвечать", "απαντάω (απάντησα)\nΑπάντησα στο γράμμα του Γιάννη.", "verb")

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

    private func makeDocument(texts: [Texts] = defaultTexts) throws -> (VocabularyDocument, UndoManager) {
        let cards = texts.map { Card(text: CardText(question: $0.question, answer: $0.answer, hint: $0.hint)!, created: created) }
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
    /// lay it out and draw it. `textSize` overrides the text size the way the Settings app would.
    private func host<Root: View>(_ root: Root, dark: Bool, textSize: DynamicTypeSize? = nil) async throws -> UIWindow {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: Self.size)
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        window.windowLevel = .alert + 1
        let controller = UIHostingController(rootView: root.dynamicTypeSize(textSize ?? .large))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(500))
        return window
    }

    private func host(_ model: StudyModel, ring: DailyRingModel, flight: CardFlight, dark: Bool, textSize: DynamicTypeSize? = nil) async throws -> UIWindow {
        try await host(StudyView(model: model, ring: ring, flight: flight, onClose: {}), dark: dark, textSize: textSize)
    }

    private func snapshot(_ window: UIWindow) -> UIImage {
        let bounds = CGRect(origin: .zero, size: Self.size)
        return UIGraphicsImageRenderer(bounds: bounds).image { _ in
            window.drawHierarchy(in: bounds, afterScreenUpdates: true)
        }
    }

    private func write(_ window: UIWindow, name: String, dark: Bool) throws {
        let data = try #require(snapshot(window).pngData())
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

    /// A model whose first card, `filler`, was graded with `grade`, so the chip shows and the
    /// card asked is `target`. The order of a stream is random: the deck is made again until the
    /// filler comes first.
    private func prepare(target: Texts, after grade: Grade = .good) async throws -> (StudyModel, DailyRingModel) {
        try beSilent()
        for _ in 0..<50 {
            let (document, undoManager) = try makeDocument(texts: [Self.filler, target])
            let model = StudyModel(document: document)
            guard model.currentCard?.question == Self.filler.question else { continue }
            self.grade(model, grade, undoManager: undoManager)
            let ring = DailyRingModel()
            ring.refresh(documents: [document], delay: .zero)
            try await Task.sleep(for: .milliseconds(300))
            return (model, ring)
        }
        throw TestFailure("the filler never came first")
    }

    private struct TestFailure: Error, CustomStringConvertible {
        var description: String
        init(_ description: String) { self.description = description }
    }

    @Test(arguments: [false, true])
    func questionAndAnswer(dark: Bool) async throws {
        let (model, ring) = try await prepare(reviews: 2)
        let window = try await host(model, ring: ring, flight: CardFlight(), dark: dark)
        try write(window, name: "1-question", dark: dark)
        model.reveal()
        try await Task.sleep(for: .milliseconds(400))
        try write(window, name: "2-revealed", dark: dark)
        window.isHidden = true
    }

    /// Mid-swipe in each zone: the card tinted, bent toward the grade's target, turned about where
    /// it was grabbed, and the button of the grade lit; and in a gap between two zones, where
    /// the card is neither tinted nor lit. The finger is at `grab` in the card (a share of its
    /// size).
    @Test(arguments: [false, true])
    func swipes(dark: Bool) async throws {
        let cases: [(name: String, translation: CGSize, grab: CGPoint)] = [
            ("3-swipe-forgot", CGSize(width: -110, height: 15), CGPoint(x: 0.5, y: 0.3)),
            ("4-swipe-hard", CGSize(width: 30, height: 110), CGPoint(x: 0.5, y: 0.7)),
            ("5-swipe-good", CGSize(width: 130, height: -20), CGPoint(x: 0.5, y: 0.3)),
            ("6-swipe-easy", CGSize(width: 25, height: -120), CGPoint(x: 0.5, y: 0.3)),
            // Between Easy and Forgot: no grade, no tint, the card half way.
            ("6b-swipe-gap", CGSize(width: -85, height: -85), CGPoint(x: 0.5, y: 0.3)),
        ]
        for item in cases {
            let (model, ring) = try await prepare(reviews: 2)
            model.reveal()
            let flight = CardFlight()
            let window = try await host(model, ring: ring, flight: flight, dark: dark)
            let start = CGPoint(x: item.grab.x * flight.size.width, y: item.grab.y * flight.size.height)
            flight.drag(item.translation, from: start, isRevealed: true)
            try await Task.sleep(for: .milliseconds(400))
            try write(window, name: item.name, dark: dark)
            window.isHidden = true
        }
    }

    /// The rest, with the chip of the last grade and a moment after it has gone.
    @Test(arguments: [false, true])
    func rest(dark: Bool) async throws {
        let (model, ring) = try await prepare(reviews: 6)
        #expect(model.isResting)
        let window = try await host(model, ring: ring, flight: CardFlight(), dark: dark)
        try write(window, name: "7-rest", dark: dark)
        model.dismissReceipt()
        try await Task.sleep(for: .milliseconds(400))
        try write(window, name: "7b-rest-nochip", dark: dark)
        window.isHidden = true
    }

    /// The stop at the end of a round: six new cards cut into two rounds of four and two, and the stream
    /// rests when the fourth is done. The header before it names the round.
    @Test(arguments: [false, true])
    func roundEnd(dark: Bool) async throws {
        try beSilent()
        let (document, undoManager) = try makeDocument()
        let ring = DailyRingModel()
        ring.refresh(documents: [document], delay: .zero)
        try await Task.sleep(for: .milliseconds(300))
        let guide = try #require(RoundGuide(progress: ring.progress, document: document))
        #expect(guide.ends == [4, 6])
        let model = StudyModel(document: document, rounds: guide)
        for _ in 0..<3 {
            grade(model, .easy, undoManager: undoManager)
        }
        ring.refresh(documents: [document], delay: .zero)
        try await Task.sleep(for: .milliseconds(300))
        let window = try await host(model, ring: ring, flight: CardFlight(), dark: dark)
        try write(window, name: "8-round-header", dark: dark)
        window.isHidden = true

        grade(model, .easy, undoManager: undoManager)
        #expect(model.isRoundRest)
        ring.refresh(documents: [document], delay: .zero)
        try await Task.sleep(for: .milliseconds(300))
        let rest = try await host(model, ring: ring, flight: CardFlight(), dark: dark)
        try write(rest, name: "8-round-end", dark: dark)
        rest.isHidden = true

        model.continueRound()
        #expect(!model.isResting)
        grade(model, .easy, undoManager: undoManager)
        grade(model, .easy, undoManager: undoManager)
        ring.refresh(documents: [document], delay: .zero)
        try await Task.sleep(for: .milliseconds(300))
        #expect(model.isResting && !model.isRoundRest)
        let done = try await host(model, ring: ring, flight: CardFlight(), dark: dark)
        try write(done, name: "8-plan-end", dark: dark)
        done.isHidden = true
    }

    /// A word that wraps to two lines, as the question and as the head of the answer, with an
    /// example sentence: with the chip, and without it.
    @Test(arguments: [false, true])
    func wrappingWords(dark: Bool) async throws {
        let (model, ring) = try await prepare(target: Self.wrappingQuestion)
        let window = try await host(model, ring: ring, flight: CardFlight(), dark: dark)
        try write(window, name: "8-wrap-question-chip", dark: dark)
        model.reveal()
        try await Task.sleep(for: .milliseconds(400))
        try write(window, name: "9-wrap-revealed-chip", dark: dark)
        model.dismissReceipt()
        try await Task.sleep(for: .milliseconds(400))
        try write(window, name: "10-wrap-revealed-nochip", dark: dark)
        window.isHidden = true

        let (answerModel, answerRing) = try await prepare(target: Self.wrappingAnswer)
        answerModel.dismissReceipt()
        answerModel.reveal()
        let answerWindow = try await host(answerModel, ring: answerRing, flight: CardFlight(), dark: dark)
        try write(answerWindow, name: "11-wrap-answer-head", dark: dark)
        answerWindow.isHidden = true
    }

    /// The chip after each kind of grade: it names the grade in its colour with its arrow.
    @Test(arguments: [false, true])
    func chips(dark: Bool) async throws {
        for (name, grade) in [("12-chip-forgot", Grade.again), ("13-chip-hard", .hard), ("14-chip-good", .good), ("15-chip-easy", .easy)] {
            let (model, ring) = try await prepare(target: Self.defaultTexts[3], after: grade)
            let window = try await host(model, ring: ring, flight: CardFlight(), dark: dark)
            try write(window, name: name, dark: dark)
            window.isHidden = true
        }
    }

    /// The chip comes and goes without the card, or anything below it, moving: the picture with the
    /// chip and the one without differ only above the card's top edge, which is found in a column
    /// the chip never reaches.
    @Test(arguments: [false, true])
    func chipLeavesTheCardWhereItIs(dark: Bool) async throws {
        let (model, ring) = try await prepare(target: Self.wrappingQuestion)
        let window = try await host(model, ring: ring, flight: CardFlight(), dark: dark)
        let shownImage = snapshot(window)
        let shown = PixelBitmap(shownImage)
        model.dismissReceipt()
        try await Task.sleep(for: .milliseconds(500))
        let hiddenImage = snapshot(window)
        let hidden = PixelBitmap(hiddenImage)
        window.isHidden = true
        try shownImage.pngData()?.write(to: directory.appendingPathComponent("chip-shown-\(dark ? "dark" : "light").png"))
        try hiddenImage.pngData()?.write(to: directory.appendingPathComponent("chip-hidden-\(dark ? "dark" : "light").png"))

        let scale = Int(hidden.scale)
        // From under the chip: higher up, the shadow of the bar's glass buttons is in the column.
        let cardTop = try #require(hidden.firstChange(inColumn: 40 * scale, from: 150 * scale))
        var above = 0
        var below = 0
        for y in 0..<hidden.height {
            for x in 0..<hidden.width where shown.differs(x, y, from: hidden) {
                if y < cardTop { above += 1 } else { below += 1 }
            }
        }
        #expect(above > 0, "the chip shows nothing above the card")
        #expect(below == 0, "\(below) pixels at or below the top of the card (row \(cardTop)) changed with the chip")
    }

    /// While the deck is read: the grey of the study page, not white.
    @Test(arguments: [false, true])
    func loading(dark: Bool) async throws {
        try beSilent()
        let window = try await host(StudyPlaceholder(failure: nil, onClose: {}), dark: dark)
        try write(window, name: "16-loading", dark: dark)
        window.isHidden = true
    }

    /// Larger text: the chip stays one line and the card keeps its place.
    @Test(arguments: [false, true])
    func largerText(dark: Bool) async throws {
        for (name, size) in [("17-text-xxxl", DynamicTypeSize.xxxLarge), ("18-text-ax1", .accessibility1), ("19-text-ax5", .accessibility5)] {
            let (model, ring) = try await prepare(target: Self.wrappingQuestion)
            let window = try await host(model, ring: ring, flight: CardFlight(), dark: dark, textSize: size)
            try write(window, name: name, dark: dark)
            model.reveal()
            try await Task.sleep(for: .milliseconds(400))
            try write(window, name: name + "-revealed", dark: dark)
            window.isHidden = true
        }
    }
}
