import SwiftUI
import Testing
import UIKit

@testable import VocTrain
@testable import VocabCore

/// Renders Today and the deck details with sample data to PNGs, in light and dark mode at the
/// width of an iPhone 13 mini (375 x 812 pt), to look at without a screen of the owner's. The
/// views sit in a window of the hosting app and are drawn with `drawHierarchy`: `ImageRenderer`
/// leaves a `List` blank, as it is a UIKit view. Nothing is compared; the test fails only when
/// a view can't be drawn.
///
/// Where the PNGs go: the environment variable `HOME_SHOTS_DIR`, else `home-shots` in the
/// temporary directory.
@MainActor
struct HomeSnapshotTests {
    nonisolated static let now = Date()
    static let greekB1 = KnownDeck(url: URL(filePath: "/Decks/Greek B1.mnemit"))
    static let greekA1 = KnownDeck(url: URL(filePath: "/Decks/Greek A1–A2.mnemit"))

    // MARK: Samples

    static func counts(new: Int, learning: Int, review: Int, nextDue: Date? = nil) -> StudyCounts {
        StudyCounts(newProduction: 0, newOther: new, learning: learning, review: review, nextDue: nextDue)
    }

    static func progress(done: Int, goal: Int, streak: Int) -> DailyProgress {
        DailyProgress(ring: DailyRing(done: done, goal: goal), streak: Streak(days: streak, repairCards: nil), cardsLeft: max(0, goal - done))
    }

    /// The day cut into four rounds, which end at 8, 16, 24 and 30 cards, with `done` of them done, and the words in memory.
    static func roundsProgress(
        done: Int, streak: Int, repairCards: Int? = nil, memory: MemoryEstimate = MemoryEstimate(words: 28.4, wordsAtDayStart: 13.2)
    ) -> DailyProgress {
        let rounds = DayRounds(otherCards: 30, newCards: 0, pace: Pace(newCard: 30, otherCard: 15), seconds: 480)
        return DailyProgress(
            ring: DailyRing(done: done, goal: rounds.goal), streak: Streak(days: streak, repairCards: repairCards),
            cardsLeft: max(0, rounds.goal - done), pace: Pace(newCard: 30, otherCard: 15),
            roundPlan: rounds, streakKeptToday: rounds.roundsDone(cardsDone: done) > 0, memory: memory,
            week: streak > 0 ? [true, true, false, true, true, true, false] : [nil, nil, nil, nil, nil, nil, false])
    }

    func today(
        decks: [KnownDeck] = [greekA1, greekB1], counts: [URL: StudyCounts], paused: Set<URL> = [], progress: DailyProgress?, query: String = "",
        hits: [AllCardsSearch.Hit] = []
    ) -> some View {
        NavigationStack {
            TodayScreen(
                decks: decks, counts: counts, paused: paused, progress: progress, now: Self.now, query: .constant(query), hits: hits,
                isSearching: false, canForget: { _ in true }, study: { _ in }, showDeck: { _ in }, showCard: { _ in },
                forget: { _ in }, addCards: {}, newDeck: {}, chooseFolder: {}, openDeck: {}, showSettings: {}, refresh: {})
        }
    }

    var dueCounts: [URL: StudyCounts] {
        [
            Self.greekA1.url: Self.counts(new: 30, learning: 0, review: 30),
            Self.greekB1.url: Self.counts(new: 20, learning: 4, review: 3),
        ]
    }

    /// What is left of the plan when `done` of its 30 cards are done, across the two decks.
    func leftCounts(done: Int) -> [URL: StudyCounts] {
        let left = max(0, 30 - done)
        let first = (left * 2 + 2) / 3
        return [
            Self.greekA1.url: Self.counts(new: first / 3, learning: 0, review: first - first / 3, nextDue: Self.now.addingTimeInterval(86_400)),
            Self.greekB1.url: Self.counts(new: 0, learning: 0, review: left - first, nextDue: Self.now.addingTimeInterval(86_400)),
        ]
    }

    var doneCounts: [URL: StudyCounts] {
        let tomorrow = Self.now.addingTimeInterval(86_400)
        return [
            Self.greekA1.url: Self.counts(new: 0, learning: 0, review: 0, nextDue: tomorrow),
            Self.greekB1.url: Self.counts(new: 0, learning: 0, review: 0, nextDue: tomorrow),
        ]
    }

    /// A deck with cards in every state: new, learning, due for review, suspended, one gone wrong today.
    func sampleDocument() throws -> VocabularyDocument {
        let created = Self.now.addingTimeInterval(-90 * 86_400)
        let newest = Self.now.addingTimeInterval(-3600)
        func state(_ phase: LearningPhase, due: Date, reviews: Int = 3) -> LearningState {
            LearningState(phase: phase, stability: 6, difficulty: 5, lastReview: Self.now.addingTimeInterval(-5 * 86_400), due: due, reviews: reviews)
        }
        var cards: [Card] = []
        for index in 0..<24 {
            cards.append(Card(question: "νέο \(index)", answer: "new \(index)", created: newest, learningState: nil))
        }
        for index in 0..<4 {
            cards.append(
                Card(question: "μαθαίνω \(index)", answer: "learn \(index)", created: created, learningState: state(.learning, due: Self.now.addingTimeInterval(-60))))
        }
        for index in 0..<30 {
            cards.append(
                Card(question: "επανάληψη \(index)", answer: "review \(index)", created: created, learningState: state(.review, due: Self.now.addingTimeInterval(-3600))))
        }
        for index in 0..<40 {
            cards.append(
                Card(question: "μακριά \(index)", answer: "later \(index)", created: created, learningState: state(.review, due: Self.now.addingTimeInterval(20 * 86_400))))
        }
        for index in 0..<3 {
            cards.append(Card(question: "παύση \(index)", answer: "paused \(index)", created: created, learningState: nil, isSuspended: true))
        }
        cards.append(
            Card(
                question: "λάθος", answer: "mistake", created: created,
                learningState: state(.relearning, due: Self.now.addingTimeInterval(86_400)),
                log: [ReviewLogEntry(date: Self.now.addingTimeInterval(-1800), grade: .again, mode: .revealed)]))
        let document = try VocabularyDocument(deck: Deck(cards: cards), clock: StudyClock { Self.now })
        // The document holds its undo manager weakly: the test run keeps it.
        let undoManager = UndoManager()
        Self.undoManagers.append(undoManager)
        document.attachUndoManager(undoManager)
        return document
    }

    private static var undoManagers: [UndoManager] = []

    // MARK: Rendering

    static var directory: URL {
        let path = ProcessInfo.processInfo.environment["HOME_SHOTS_DIR"]
        return path.map { URL(filePath: $0, directoryHint: .isDirectory) }
            ?? FileManager.default.temporaryDirectory.appending(path: "home-shots", directoryHint: .isDirectory)
    }

    func shoot(_ name: String, _ view: some View, height: CGFloat = 812, types: [DynamicTypeSize?] = [nil]) async throws {
        for dark in [false, true] {
            for type in types {
                let root = AnyView(view.dynamicTypeSize(type ?? .large))
                let suffix = type.map { "-\($0)" } ?? ""
                try await render(root, to: "\(name)\(suffix)-\(dark ? "dark" : "light").png", dark: dark, height: height)
            }
        }
    }

    func render(_ view: AnyView, to file: String, dark: Bool, height: CGFloat) async throws {
        let size = CGSize(width: 375, height: height)
        let controller = UIHostingController(rootView: view)
        controller.overrideUserInterfaceStyle = dark ? .dark : .light
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()
        // The safe area of an iPhone 13 mini: 50 pt at the top, 34 at the bottom.
        let inset = window.safeAreaInsets
        controller.additionalSafeAreaInsets = UIEdgeInsets(top: 50 - inset.top, left: 0, bottom: 34 - inset.bottom, right: 0)
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()
        // Lets SwiftUI lay out, and the list and the navigation bar draw.
        try await Task.sleep(for: .milliseconds(800))
        controller.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            window.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        window.isHidden = true
        try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        let data = try #require(image.pngData())
        try data.write(to: Self.directory.appending(path: file))
    }

    // MARK: Tests

    /// After the streak step: the cards left with their time, the cards done and left, the streak kept, the words in memory.
    @Test func todayWithCardsDue() async throws {
        try await shoot("today-due", today(counts: leftCounts(done: 10), progress: Self.roundsProgress(done: 10, streak: 12)))
    }

    @Test func todayWithCardsDueAtLargeTypeSizes() async throws {
        try await shoot("today-due", today(counts: leftCounts(done: 10), progress: Self.roundsProgress(done: 10, streak: 12)), types: [.xxxLarge, .accessibility3, .accessibility5])
    }

    /// A deck paused: it moves to a "Paused" section at the bottom, in the secondary colour, with no counts, and the
    /// day is the other decks'.
    @Test func todayWithAPausedDeck() async throws {
        let paused = KnownDeck(url: URL(filePath: "/Decks/Greek B2.mnemit"))
        try await shoot(
            "today-paused",
            today(
                decks: [Self.greekA1, paused, Self.greekB1], counts: leftCounts(done: 10), paused: [paused.url],
                progress: Self.roundsProgress(done: 10, streak: 12)))
    }

    /// Before the first round: the time it takes to keep the streak, which is not kept yet.
    @Test func todayBeforeTheFirstRound() async throws {
        try await shoot("today-first-round", today(counts: leftCounts(done: 3), progress: Self.roundsProgress(done: 3, streak: 12)))
    }

    /// The last round done with cards still left: the ring is closed and the rest waits in Catch Up.
    @Test func todayWithTheRingClosed() async throws {
        try await shoot("today-closed", today(counts: leftCounts(done: 28), progress: Self.roundsProgress(done: 31, streak: 13)))
    }

    /// The day after a missed one: the streak survives only if the ring closes, and its flame says so.
    @Test func todayWithTheStreakAtRisk() async throws {
        try await shoot("today-at-risk", today(counts: leftCounts(done: 3), progress: Self.roundsProgress(done: 3, streak: 12, repairCards: 15)))
    }

    /// A milestone of the words in memory passed today.
    @Test func todayWithAMilestonePassed() async throws {
        let memory = MemoryEstimate(words: 51.3, wordsAtDayStart: 44)
        try await shoot("today-milestone", today(counts: leftCounts(done: 9), progress: Self.roundsProgress(done: 9, streak: 4, memory: memory)))
    }

    /// The very first day: no streak, no words yet.
    @Test func todayOnTheFirstDay() async throws {
        let memory = MemoryEstimate(words: 0, wordsAtDayStart: 0)
        try await shoot("today-first-day", today(counts: leftCounts(done: 0), progress: Self.roundsProgress(done: 0, streak: 0, memory: memory)))
    }

    /// Before the rounds are known the old lines stand: the cards left and the time they take.
    @Test func todayWithoutRounds() async throws {
        try await shoot("today-no-rounds", today(counts: dueCounts, progress: Self.progress(done: 14, goal: 20, streak: 12)))
    }

    @Test func todayWithNothingDueAfterReviews() async throws {
        try await shoot("today-done", today(counts: doneCounts, progress: Self.roundsProgress(done: 31, streak: 13)))
    }

    @Test func todayWithNothingDueAndNoReviews() async throws {
        try await shoot("today-nothing", today(counts: doneCounts, progress: Self.progress(done: 0, goal: 1, streak: 0)))
    }

    @Test func todayBeforeTheDecksAreRead() async throws {
        try await shoot("today-loading", today(counts: [:], progress: nil))
    }

    @Test func todayAtFirstLaunch() async throws {
        try await shoot("today-empty", today(decks: [], counts: [:], progress: nil))
    }

    @Test func todayWithSearchResults() async throws {
        let hits = [
            AllCardsSearch.Hit(deck: Self.greekB1, card: UUID(), question: "το σπίτι", answer: "дом · the house"),
            AllCardsSearch.Hit(deck: Self.greekB1, card: UUID(), question: "house", answer: "το σπίτι"),
            AllCardsSearch.Hit(deck: Self.greekA1, card: UUID(), question: "η πολυκατοικία", answer: "многоквартирный дом · block of flats\nΜένουμε σε μια πολυκατοικία."),
        ]
        try await shoot("today-search", today(counts: dueCounts, progress: nil, query: "house", hits: hits))
    }

    func deckScreen(document: VocabularyDocument?, counts: StudyCounts? = nil, canEdit: Bool = true) -> some View {
        NavigationStack {
            DeckContent(
                name: "Greek B1", knownCounts: counts, document: document, failure: nil, merger: document.map { _ in VersionMerger { _ in } },
                canEdit: canEdit, start: { _ in }, rename: { _ in }, delete: {})
        }
    }

    @Test func deckScreenWhileLoading() async throws {
        try await shoot("deck-loading", deckScreen(document: nil, counts: Self.counts(new: 20, learning: 4, review: 3), canEdit: false))
    }

    @Test func deckScreenAtAccessibilitySize() async throws {
        let document = try sampleDocument()
        try await shoot("deck", deckScreen(document: document), types: [.accessibility3, .accessibility5])
    }
}

/// A simulator plays speech through the speakers of the Mac, so the app that hosts the tests
/// must not speak by itself, see `VocTrainApp.init()`.
@MainActor
struct TestRunsAreSilent {
    @Test func theHostAppDoesNotSpeakByItself() {
        #expect(GreekSpeech.autoSpeak == false)
    }
}
