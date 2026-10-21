import SwiftUI
import Testing
import UIKit

@testable import VocTrain
@testable import VocabCore

/// Draws the deck screen, the card browser and a card in their states, light and dark, at the
/// size of an iPhone 13 mini (375 × 812), and writes PNGs to look at, as
/// `StudyScreenSnapshotTests` does for the study stream. The screens are hosted in a real
/// window, so the bar, the search field and the bottom bar of the selection are in the picture.
///
/// The directory is `STUDY_SHOTS_DIR` (pass it to `xcodebuild` as an environment variable,
/// `TEST_RUNNER_STUDY_SHOTS_DIR`), else a folder in the temporary directory. The test fails only
/// if a picture can't be made; what the pictures show is for a person to judge.
@Suite(.serialized)
@MainActor
struct BrowserSnapshotTests {
    static let size = CGSize(width: 375, height: 812)
    /// The relative dates ("in 3 days") are worked out against the real clock, so the sample is too.
    let now = Date()
    let created = Date(timeIntervalSince1970: 1_791_216_000)

    private var directory: URL {
        let path = ProcessInfo.processInfo.environment["STUDY_SHOTS_DIR"]
        let url = path.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory.appendingPathComponent("study-shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: Sample deck

    /// A document holds its undo manager weakly; the test run keeps the ones it made.
    private static var undoManagers: [UndoManager] = []

    static func keep(_ undoManager: UndoManager) -> UndoManager {
        undoManagers.append(undoManager)
        return undoManager
    }

    func state(_ phase: LearningPhase, due: TimeInterval, stability: Double = 12, difficulty: Double = 5.3, reviews: Int = 6, lapses: Int = 0) -> LearningState {
        LearningState(
            phase: phase, stability: stability, difficulty: difficulty, lastReview: now.addingTimeInterval(-2 * 86_400),
            due: now.addingTimeInterval(due), reviews: reviews, lapses: lapses)
    }

    func log(_ grades: [Grade]) -> [ReviewLogEntry] {
        grades.enumerated().map { index, grade in
            ReviewLogEntry(date: now.addingTimeInterval(-Double(grades.count - index) * 3 * 86_400), grade: grade, mode: .revealed)
        }
    }

    struct Sample {
        var document: VocabularyDocument
        var house: Card
        var houseBack: Card
        var newCard: Card
        var leech: Card
        var suspended: Card
        var wrapping: Card
    }

    func makeSample() throws -> Sample {
        let house = Card(
            question: "το σπίτι", answer: "дом · the house\nΤο σπίτι μου είναι μικρό.", hint: "noun, neuter", note: "σπίτι|house",
            kind: .recognition, created: created, learningState: state(.review, due: 3 * 86_400, lapses: 1),
            log: log([.again, .good, .good, .hard, .good, .easy]))
        let houseBack = Card(
            question: "дом · the house", answer: "το σπίτι", note: "σπίτι|house", kind: .production, created: created, learningState: nil)
        let leech = Card(
            question: "βάζω φωτιά (έβαλα)", answer: "поджигать · to set fire", created: created,
            learningState: state(.relearning, due: -600, stability: 1.4, difficulty: 8.7, reviews: 14, lapses: 8),
            log: log([.again, .hard, .again, .good, .again, .again]))
        let suspended = Card(
            question: "η στάση", answer: "остановка · the stop", created: created, learningState: state(.review, due: -86_400),
            isSuspended: true)
        let wrapping = Card(
            question: "απαντάω (απάντησα)", answer: "отвечать · to answer\nΑπάντησα στο γράμμα του Γιάννη, αλλά δεν πήρα απάντηση.",
            hint: "verb", created: created, learningState: state(.learning, due: -60, stability: 0.8, reviews: 2))
        let newCard = Card(question: "ο ταχυδρόμος", answer: "почтальон · the postman", created: created, learningState: nil)
        var cards = [house, houseBack, leech, suspended, wrapping, newCard]
        let words: [(String, String)] = [
            ("η αστυνομία", "полиция · the police"), ("ο Άγγλος", "англичанин · Englishman"),
            ("υπεύθυνος, -η, -ο", "ответственный · responsible"), ("αφού", "после того как; раз · after; since"),
            ("το ψωμί", "хлеб · bread"), ("η θάλασσα", "море · the sea"), ("ο δρόμος", "дорога · the road"),
        ]
        for (index, word) in words.enumerated() {
            let due = index % 3 == 0 ? -3600 : TimeInterval(index) * 86_400
            cards.append(
                Card(
                    question: word.0, answer: word.1, created: created,
                    learningState: index % 4 == 3 ? nil : state(.review, due: due, difficulty: 3 + Double(index))))
        }
        let document = try VocabularyDocument(deck: Deck(cards: cards), clock: StudyClock { [now] in now })
        document.attachUndoManager(Self.keep(UndoManager()))
        return Sample(document: document, house: house, houseBack: houseBack, newCard: newCard, leech: leech, suspended: suspended, wrapping: wrapping)
    }

    // MARK: Rendering

    private func host<Root: View>(_ root: Root, dark: Bool, textSize: DynamicTypeSize? = nil) async throws -> UIWindow {
        try #require(GreekSpeech.isUnderTest, "a test run must not speak")
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: Self.size)
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        window.windowLevel = .alert + 1
        window.rootViewController = UIHostingController(rootView: root.dynamicTypeSize(textSize ?? .large))
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(700))
        return window
    }

    private func write(_ window: UIWindow, name: String, dark: Bool) throws {
        let bounds = CGRect(origin: .zero, size: Self.size)
        let image = UIGraphicsImageRenderer(bounds: bounds).image { _ in
            window.drawHierarchy(in: bounds, afterScreenUpdates: true)
        }
        let data = try #require(image.pngData())
        try data.write(to: directory.appendingPathComponent("\(name)-\(dark ? "dark" : "light").png"))
    }

    /// Draws `view` in a navigation stack, light and dark, as `name`.
    private func shoot(_ name: String, dark: Bool, textSize: DynamicTypeSize? = nil, _ view: some View) async throws {
        let window = try await host(NavigationStack { view }, dark: dark, textSize: textSize)
        try write(window, name: name, dark: dark)
        window.isHidden = true
    }

    // MARK: Deck screen

    func deckContent(_ sample: Sample, canEdit: Bool = true) -> some View {
        DeckContent(
            name: "Greek B1", knownCounts: nil, document: sample.document, failure: nil, merger: VersionMerger { _ in }, canEdit: canEdit,
            start: { _ in }, rename: { _ in }, delete: {})
    }

    @Test(arguments: [false, true])
    func deckScreen(dark: Bool) async throws {
        try await shoot("deck", dark: dark, deckContent(try makeSample()))
    }

    // MARK: Card browser

    @Test(arguments: [false, true])
    func browserFilters(dark: Bool) async throws {
        for filter in BrowserFilter.allCases {
            let sample = try makeSample()
            try await shoot(
                "browser-\(filter.rawValue)", dark: dark, CardBrowserScreen(document: sample.document, canEdit: true, filter: filter))
        }
    }

    @Test(arguments: [false, true])
    func browserSorts(dark: Bool) async throws {
        for sort in [BrowserSort.added, .alphabetical, .difficulty] {
            let sample = try makeSample()
            try await shoot("browser-sort-\(sort.rawValue)", dark: dark, CardBrowserScreen(document: sample.document, canEdit: true, sort: sort))
        }
    }

    @Test(arguments: [false, true])
    func browserSearch(dark: Bool) async throws {
        let sample = try makeSample()
        try await shoot("browser-search", dark: dark, CardBrowserScreen(document: sample.document, canEdit: true, query: "σπιτι"))
        try await shoot("browser-search-none", dark: dark, CardBrowserScreen(document: sample.document, canEdit: true, query: "qqq"))
    }

    @Test(arguments: [false, true])
    func browserSelecting(dark: Bool) async throws {
        let sample = try makeSample()
        let selected: Set<Card.ID> = [sample.house.id, sample.leech.id]
        try await shoot("browser-selecting", dark: dark, CardBrowserScreen(document: sample.document, canEdit: true, selecting: selected))
        try await shoot("browser-selecting-none", dark: dark, CardBrowserScreen(document: sample.document, canEdit: true, selecting: []))
    }

    @Test(arguments: [false, true])
    func browserEmptyDeck(dark: Bool) async throws {
        let document = VocabularyDocument(deck: Deck(), clock: StudyClock { [now] in now })
        document.attachUndoManager(Self.keep(UndoManager()))
        try await shoot("browser-empty", dark: dark, CardBrowserScreen(document: document, canEdit: true))
    }

    @Test func browserAtAccessibilitySize() async throws {
        let sample = try makeSample()
        try await shoot("browser-accessibility", dark: false, textSize: .accessibility3, CardBrowserScreen(document: sample.document, canEdit: true))
    }

    // MARK: Card

    @Test(arguments: [false, true])
    func cardDetail(dark: Bool) async throws {
        let sample = try makeSample()
        let cases: [(name: String, card: Card)] = [
            ("detail-studied", sample.house), ("detail-new-sibling", sample.houseBack), ("detail-leech", sample.leech),
            ("detail-suspended", sample.suspended), ("detail-wrapping", sample.wrapping), ("detail-new", sample.newCard),
        ]
        for item in cases {
            try await shoot(item.name, dark: dark, CardDetailScreen(document: sample.document, cardID: item.card.id, canEdit: true))
        }
    }

    @Test func cardDetailAtAccessibilitySize() async throws {
        let sample = try makeSample()
        try await shoot("detail-accessibility", dark: false, textSize: .accessibility3, CardDetailScreen(document: sample.document, cardID: sample.house.id, canEdit: true))
    }

    @Test(arguments: [false, true])
    func cardDeleted(dark: Bool) async throws {
        let sample = try makeSample()
        let undoManager = try #require(sample.document.undoManager)
        undoManager.groupsByEvent = false
        let window = try await host(NavigationStack { CardDetailScreen(document: sample.document, cardID: sample.newCard.id, canEdit: true) }, dark: dark)
        undoManager.beginUndoGrouping()
        sample.document.delete([sample.newCard.id])
        undoManager.endUndoGrouping()
        try await Task.sleep(for: .milliseconds(500))
        try write(window, name: "detail-deleted", dark: dark)
        window.isHidden = true
    }

    @Test(arguments: [false, true])
    func editCard(dark: Bool) async throws {
        let sample = try makeSample()
        try await shoot("edit", dark: dark, EditCardSheet(document: sample.document, card: sample.house, showsAdvanced: true))
    }
}
