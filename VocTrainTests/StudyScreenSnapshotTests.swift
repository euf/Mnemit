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
    /// The card that goes before the one a picture is about, so a grade has been given before it.
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

    private func host(_ model: StudyModel, ring: DailyRingModel, flight: CardFlight, motion: StudyMotion? = nil, dark: Bool, textSize: DynamicTypeSize? = nil) async throws -> UIWindow {
        try await host(StudyView(model: model, ring: ring, flight: flight, motion: motion, onClose: {}), dark: dark, textSize: textSize)
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

    /// The rest, at the end of the plan.
    @Test(arguments: [false, true])
    func rest(dark: Bool) async throws {
        let (model, ring) = try await prepare(reviews: 6)
        #expect(model.isResting)
        let window = try await host(model, ring: ring, flight: CardFlight(), dark: dark)
        try write(window, name: "7-rest", dark: dark)
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
    /// example sentence.
    @Test(arguments: [false, true])
    func wrappingWords(dark: Bool) async throws {
        let (model, ring) = try await prepare(target: Self.wrappingQuestion)
        let window = try await host(model, ring: ring, flight: CardFlight(), dark: dark)
        try write(window, name: "8-wrap-question", dark: dark)
        model.reveal()
        try await Task.sleep(for: .milliseconds(400))
        try write(window, name: "9-wrap-revealed", dark: dark)
        window.isHidden = true

        let (answerModel, answerRing) = try await prepare(target: Self.wrappingAnswer)
        answerModel.reveal()
        let answerWindow = try await host(answerModel, ring: answerRing, flight: CardFlight(), dark: dark)
        try write(answerWindow, name: "11-wrap-answer-head", dark: dark)
        answerWindow.isHidden = true
    }

    /// While the deck is read: the grey of the study page, not white.
    @Test(arguments: [false, true])
    func loading(dark: Bool) async throws {
        try beSilent()
        let window = try await host(StudyPlaceholder(failure: nil, onClose: {}), dark: dark)
        try write(window, name: "16-loading", dark: dark)
        window.isHidden = true
    }

    /// Larger text: the bar keeps its line and the card keeps its place.
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

    // MARK: What moves

    /// A model with six new cards cut into rounds of four and two, `done` of them graded Easy, so the
    /// stack under the card holds the rest of the round, and the ring evaluated for them.
    private func prepareRound(done: Int) async throws -> (StudyModel, DailyRingModel, VocabularyDocument, UndoManager) {
        try beSilent()
        let (document, undoManager) = try makeDocument()
        let ring = DailyRingModel()
        ring.refresh(documents: [document], delay: .zero)
        try await Task.sleep(for: .milliseconds(300))
        let guide = try #require(RoundGuide(progress: ring.progress, document: document))
        #expect(guide.ends == [4, 6])
        let model = StudyModel(document: document, rounds: guide)
        for _ in 0..<done {
            grade(model, .easy, undoManager: undoManager)
        }
        ring.refresh(documents: [document], delay: .zero)
        try await Task.sleep(for: .milliseconds(300))
        return (model, ring, document, undoManager)
    }

    /// The bar with Undo next to the menu: dimmed before there is a grade to take back, lit after one.
    @Test(arguments: [false, true])
    func undoButton(dark: Bool) async throws {
        let (fresh, freshRing) = try await prepare(reviews: 0)
        #expect(!fresh.canUndo)
        let before = try await host(fresh, ring: freshRing, flight: CardFlight(), dark: dark)
        try write(before, name: "20-undo-disabled", dark: dark)
        before.isHidden = true

        // The undo manager is the caller's: the document holds it weakly.
        let (graded, gradedRing, _, undoManager) = try await prepareRound(done: 2)
        #expect(graded.canUndo)
        let after = try await host(graded, ring: gradedRing, flight: CardFlight(), dark: dark)
        try write(after, name: "21-undo-enabled", dark: dark)
        withExtendedLifetime(undoManager) {}
        after.isHidden = true
    }

    /// The card in the air with its label on it, `progress` of the way along: into the ring in the bar
    /// (the ring's place and the card's are the ones the views report), under the stack, off to the side
    /// for a leech, and with Reduce Motion where it was, half faded. The next card is on top already.
    @Test(arguments: [false, true])
    func theCardInTheAir(dark: Bool) async throws {
        let cases: [(name: String, receipt: GradeReceipt, progress: Double, reduceMotion: Bool, drag: CGSize)] = [
            ("22-flight-ring", GradeReceipt(grade: .good, interval: .days(8)), 0.5, false, CGSize(width: 130, height: -20)),
            ("23-flight-ring-late", GradeReceipt(grade: .easy, interval: .days(95)), 0.8, false, CGSize(width: 25, height: -120)),
            ("24-flight-stack", GradeReceipt(grade: .again, interval: .learning), 0.55, false, CGSize(width: -110, height: 15)),
            ("25-flight-leech", GradeReceipt(grade: .again, interval: .days(3), isLeech: true), 0.35, false, CGSize(width: -110, height: 15)),
            ("26-flight-reduced", GradeReceipt(grade: .good, interval: .days(1)), 0.5, true, .zero),
        ]
        for item in cases {
            let (model, ring, _, _) = try await prepareRound(done: 1)
            model.reveal()
            let flight = CardFlight()
            let motion = StudyMotion(ring: ring)
            motion.frozen = StudyMotion.Frozen(departure: item.progress)
            let window = try await host(model, ring: ring, flight: flight, motion: motion, dark: dark)
            #expect(motion.ringHome.width > 0, "the ring in the bar reports its place")
            #expect(motion.cardSlot.width > 0, "the card reports its place")
            if item.drag != .zero {
                let start = CGPoint(x: 0.5 * flight.size.width, y: 0.3 * flight.size.height)
                flight.drag(item.drag, from: start, isRevealed: true)
            }
            let card = try #require(model.currentCard)
            motion.depart(card, receipt: item.receipt, release: flight.release, velocity: .zero, behind: model.cardsBehind, peek: 6, reduceMotion: item.reduceMotion)
            flight.didRelease(item.receipt.grade)
            try await Task.sleep(for: .milliseconds(800))
            try write(window, name: item.name, dark: dark)
            window.isHidden = true
        }
    }

    /// The stack: three cards left in the round show as three blank edges under the card, one as one.
    @Test(arguments: [false, true])
    func theStackOfTheRound(dark: Bool) async throws {
        for (name, done) in [("27-stack-3", 0), ("28-stack-1", 2)] {
            let (model, ring, _, _) = try await prepareRound(done: done)
            #expect(model.cardsBehind == 3 - done)
            let window = try await host(model, ring: ring, flight: CardFlight(), dark: dark)
            try await Task.sleep(for: .milliseconds(700))
            try write(window, name: name, dark: dark)
            window.isHidden = true
        }
    }

    /// The next card on its way up from the stack, the cards under it blank: a few points low and a little
    /// small, its words half in.
    @Test(arguments: [false, true])
    func theNextCardRises(dark: Bool) async throws {
        let (model, ring, _, _) = try await prepareRound(done: 1)
        let motion = StudyMotion(ring: ring)
        motion.arrival = .rises
        motion.frozen = StudyMotion.Frozen(rise: 0.4)
        let window = try await host(model, ring: ring, flight: CardFlight(), motion: motion, dark: dark)
        try await Task.sleep(for: .milliseconds(700))
        try write(window, name: "29-next-card-rises", dark: dark)
        window.isHidden = true
    }

    /// The end of a round with the ring on its way down: the empty place of the card as a faint outline, the ring
    /// half way, scaled up from the bar's size toward the rest's, and none of the lines in yet.
    @Test(arguments: [false, true])
    func theRingComesDown(dark: Bool) async throws {
        let (model, ring, document, undoManager) = try await prepareRound(done: 3)
        let motion = StudyMotion(ring: ring)
        // The card's place is known from the card that left.
        let cards = try await host(model, ring: ring, flight: CardFlight(), motion: motion, dark: dark)
        try await Task.sleep(for: .milliseconds(200))
        cards.isHidden = true
        model.reveal()
        grade(model, .easy, undoManager: undoManager)
        #expect(model.isRoundRest)
        ring.refresh(documents: [document], delay: .zero)
        try await Task.sleep(for: .milliseconds(300))

        for (name, travel, lines) in [("30-rest-travel-half", 0.5, 0), ("31-rest-travel-end", 1.0, 0)] {
            motion.freezeRest(travel: travel, lines: lines)
            let window = try await host(model, ring: ring, flight: CardFlight(), motion: motion, dark: dark)
            #expect(motion.ringRest.width > 0, "the rest reports where its ring goes")
            try await Task.sleep(for: .milliseconds(300))
            try write(window, name: name, dark: dark)
            window.isHidden = true
        }
    }

    /// The lines of the rest coming in one after the other: the title, then each line, then the buttons.
    @Test(arguments: [false, true])
    func theLinesComeInOneByOne(dark: Bool) async throws {
        let (model, ring, document, undoManager) = try await prepareRound(done: 3)
        model.reveal()
        grade(model, .easy, undoManager: undoManager)
        #expect(model.isRoundRest)
        ring.refresh(documents: [document], delay: .zero)
        try await Task.sleep(for: .milliseconds(300))
        for (name, lines) in [("32-lines-1", 1), ("33-lines-3", 3), ("34-lines-all", 9)] {
            let motion = StudyMotion(ring: ring)
            motion.freezeRest(travel: 1, lines: lines)
            let window = try await host(model, ring: ring, flight: CardFlight(), motion: motion, dark: dark)
            try await Task.sleep(for: .milliseconds(300))
            try write(window, name: name, dark: dark)
            window.isHidden = true
        }
    }

    /// The burst at its peak, as a still from a fixed time: the ring swollen to 1.12 and the specks half way out.
    @Test(arguments: [false, true])
    func theBurstAtItsPeak(dark: Bool) async throws {
        let (_, ring) = try await prepare(reviews: 2)
        let still = VStack(spacing: Spacing.margin) {
            RingBurstFrame(elapsed: RingBurstTiming.swell / 2, diameter: 96) {
                DailyRingView(progress: ring.progress, diameter: 96)
            }
            Text("Round 1 done")
                .font(.title.weight(.semibold))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        let window = try await host(still, dark: dark)
        try write(window, name: "35-burst-peak", dark: dark)
        window.isHidden = true
    }
}
