import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// A paused deck (`LearningOptions.isPaused`) is no part of the day's plan: Today lists it apart, Study, the goal, the
/// new cards, the reminders and the widget leave it out.
@MainActor
struct PausedDecksTests {
    static let greek = KnownDeck(url: URL(filePath: "/Decks/Greek.mnemit"))
    static let polish = KnownDeck(url: URL(filePath: "/Decks/Polish.mnemit"))
    static let czech = KnownDeck(url: URL(filePath: "/Decks/Czech.mnemit"))
    static let decks = [greek, polish, czech]

    static func counts(_ total: Int) -> StudyCounts {
        StudyCounts(newProduction: 0, newOther: 0, learning: 0, review: total, nextDue: nil)
    }

    /// `count` new cards added `daysAgo` days ago: the day's new cards go to the newest additions first.
    func fresh(_ count: Int, daysAgo: Double = 0) -> [Card] {
        (0..<count).map { Card(text: CardText(question: "n\($0)", answer: "x")!, created: Date().addingTimeInterval(-daysAgo * 86400)) }
    }

    func deck(_ cards: [Card], isPaused: Bool) throws -> Deck {
        var options = LearningOptions()
        options.isPaused = isPaused
        return try Deck(learningOptions: options, cards: cards)
    }

    func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    func write(_ deck: Deck, named name: String, in directory: URL) throws -> URL {
        let url = directory.appending(path: "\(name).mnemit", directoryHint: .isDirectory)
        try DeckFile.fileWrapper(for: deck).write(to: url, options: .atomic, originalContentsURL: nil)
        return url
    }

    // MARK: Today

    @Test func todayListsTheDecksOfTheDayAndThenThePausedOnesEachInTheOrderOfTheList() {
        let today = TodayDecks(Self.decks, paused: [Self.greek.url, Self.czech.url])
        #expect(today.active == [Self.polish])
        #expect(today.paused == [Self.greek, Self.czech])
        let none = TodayDecks(Self.decks)
        #expect(none.active == Self.decks)
        #expect(none.paused.isEmpty)
    }

    @Test func studyRunsTheDecksOfTheDayWithCardsLeftAndSkipsThePausedOnes() {
        let today = TodayDecks(Self.decks, paused: [Self.greek.url])
        let counts = [Self.polish.url: Self.counts(5), Self.czech.url: Self.counts(2)]
        #expect(today.studyQueue(counts: counts, isRead: true, last: nil) == [Self.polish.url, Self.czech.url])
        // The deck studied last goes first, but not when it is paused.
        #expect(today.studyQueue(counts: counts, isRead: true, last: Self.czech.url) == [Self.czech.url, Self.polish.url])
        #expect(today.studyQueue(counts: counts, isRead: true, last: Self.greek.url) == [Self.polish.url, Self.czech.url])
    }

    @Test func withNothingLeftStudyOpensTheLastDeckOfTheDayAndNeverAPausedOne() {
        let today = TodayDecks(Self.decks, paused: [Self.greek.url])
        let done = [Self.polish.url: Self.counts(0), Self.czech.url: Self.counts(0)]
        #expect(today.studyQueue(counts: done, isRead: true, last: Self.czech.url) == [Self.czech.url])
        #expect(today.studyQueue(counts: done, isRead: true, last: Self.greek.url) == [Self.polish.url])
        #expect(today.studyQueue(counts: done, isRead: true, last: nil) == [Self.polish.url])
        // The paused deck has cards left of its own and still is not asked for.
        let paused = done.merging([Self.greek.url: Self.counts(9)]) { _, new in new }
        #expect(today.studyQueue(counts: paused, isRead: true, last: Self.greek.url) == [Self.polish.url])
    }

    /// Today's ring waits for the counts of the decks of the day: a paused deck has none, so it is not waited for.
    @Test func thePausedDeckIsNotWaitedForToTellTheDay() {
        let today = TodayDecks(Self.decks, paused: [Self.greek.url])
        #expect(today.isRead([Self.polish.url: Self.counts(3), Self.czech.url: Self.counts(0)]))
        #expect(!today.isRead([Self.polish.url: Self.counts(3)]))
        #expect(TodayDecks(Self.decks, paused: Set(Self.decks.map(\.url))).isRead([:]))
    }

    @Test func whenEveryDeckIsPausedStudyHasNothingToRun() {
        let today = TodayDecks(Self.decks, paused: Set(Self.decks.map(\.url)))
        #expect(today.active.isEmpty)
        #expect(today.studyQueue(counts: [:], isRead: true, last: Self.greek.url).isEmpty)
    }

    @Test func beforeTheDecksAreReadEveryDeckOfTheDayCountsAsDue() {
        let today = TodayDecks(Self.decks)
        #expect(today.studyQueue(counts: [:], isRead: false, last: nil) == Self.decks.map(\.url))
    }

    // MARK: Reading the decks

    @Test func aPausedDeckHasNoCountsAndIsListedAsPausedOnceRead() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let active = try write(try deck(fresh(10), isPaused: false), named: "Greek", in: directory)
        let paused = try write(try deck(fresh(10), isPaused: true), named: "Polish", in: directory)

        #expect(KnownDeckCounts.counts(at: active) != nil)
        #expect(KnownDeckCounts.counts(at: paused) == nil)
        #expect(KnownDeckCounts.counts(at: paused, on: [Date()]) == nil)

        let counts = KnownDeckCounts()
        #expect(!counts.isRead)
        await counts.refresh([active, paused], allowances: NewCardAllowances())
        #expect(counts.isRead)
        #expect(counts.counts[active]?.new == 10)
        #expect(counts.counts[paused] == nil)
        #expect(counts.paused == [paused])

        // Only paused decks: the figures are read all the same.
        let onlyPaused = KnownDeckCounts()
        await onlyPaused.refresh([paused], allowances: NewCardAllowances())
        #expect(onlyPaused.isRead)
    }

    @Test func aDeckThatWasPausedAndIsResumedGetsItsCountsBack() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = try write(try deck(fresh(4), isPaused: true), named: "Greek", in: directory)
        let counts = KnownDeckCounts()
        await counts.refresh([url], allowances: NewCardAllowances())
        #expect(counts.paused == [url])
        _ = try write(try deck(fresh(4), isPaused: false), named: "Greek", in: directory)
        await counts.refresh([url], allowances: NewCardAllowances())
        #expect(counts.paused.isEmpty)
        #expect(counts.counts[url]?.new == 4)
    }

    // MARK: Changing it

    @Test func theDocumentPausesAndResumesInOneUndoStepEach() throws {
        let document = try VocabularyDocument(deck: Deck(cards: fresh(3)))
        let undoManager = UndoManager()
        document.attachUndoManager(undoManager)
        #expect(!document.deck.learningOptions.isPaused)
        document.setPaused(true)
        #expect(document.deck.learningOptions.isPaused)
        #expect(document.deck.learningOptionsChanged != nil)
        undoManager.undo()
        #expect(!document.deck.learningOptions.isPaused)
        undoManager.redo()
        #expect(document.deck.learningOptions.isPaused)
        document.setPaused(false)
        #expect(!document.deck.learningOptions.isPaused)
    }

    // MARK: The day

    @Test func theRingGivesAPausedDeckNoAllowanceAndTheOthersAllOfIt() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let pausedFile = try write(try deck(fresh(20), isPaused: true), named: "Greek", in: directory)
        let activeFile = try write(try deck(fresh(20, daysAgo: 2), isPaused: false), named: "Polish", in: directory)
        let pausedDocument = try VocabularyDocument(deck: deck(fresh(20), isPaused: true))
        // Three words of today and seventeen older ones.
        let activeDocument = try VocabularyDocument(deck: deck(fresh(3) + fresh(17, daysAgo: 3), isPaused: false))
        // What the file of the deck had from a time before it was paused.
        NewCardAllowances.today[pausedFile] = 5
        let ring = DailyRingModel()

        await ring.refresh(documents: [pausedDocument, activeDocument], files: [pausedFile, activeFile], reloadFiles: true, delay: .zero).value
        let progress = try #require(ring.progress)
        // The first day's 150 s hold five new cards, taken from one queue of the words of the two decks that take part,
        // newest addition first: the document's three of today, then two of the file's.
        #expect(progress.newCardAllowances == [0, 3, 0, 2])
        #expect(progress.ring.goal == 5)
        #expect(pausedDocument.newCardAllowance == nil)
        #expect(activeDocument.newCardAllowance == 3)
        #expect(NewCardAllowances.today[pausedFile] == nil)
        #expect(NewCardAllowances.today[activeFile] == 2)
        // The paused deck's own screen plans no new card by itself: it asks nothing of the day, and Learn 10 New Words adds them.
        #expect(pausedDocument.dueCards.counts.new == 0)
    }

    @Test func theRoundsOfTheDayAreNoneOfAPausedDecksStream() throws {
        let progress = DailyProgress(
            ring: DailyRing(done: 3, goal: 10), streak: Streak(days: 1, repairCards: nil),
            roundPlan: DayRounds(otherCards: 10, newCards: 0, pace: Pace(newCard: 30, otherCard: 15), seconds: 240))
        let active = try VocabularyDocument(deck: deck(fresh(3), isPaused: false))
        let paused = try VocabularyDocument(deck: deck(fresh(3), isPaused: true))
        #expect(RoundGuide(progress: progress, document: active) != nil)
        #expect(RoundGuide(progress: progress, document: paused) == nil)
    }

    // MARK: Reminders and the widget

    @Test func theWidgetForecastLeavesAPausedDeckOut() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = WidgetFixtures.date(22, 10, 20)
        let cards = WidgetFixtures.deck(now: now).cards
        let active = try deck(cards, isPaused: false)
        let paused = try deck(cards, isPaused: true)
        let file = try write(paused, named: "Greek", in: directory)
        func forecast(_ decks: [WidgetSync.Source]) -> [Int] {
            let progress = WidgetFixtures.progress(done: 0, goal: 5, streak: 1)
            let inputs = WidgetSync.Inputs(progress: progress, decks: decks, nextReminder: nil)
            return WidgetSync.snapshot(from: inputs, at: now, calendar: WidgetFixtures.calendar).due.map(\.count)
        }
        let alone = forecast([.open(active, WidgetFixtures.studyCalendar)])
        #expect(alone.first.map { $0 > 0 } == true)
        #expect(forecast([.open(active, WidgetFixtures.studyCalendar), .open(paused, WidgetFixtures.studyCalendar), .file(file)]) == alone)
        #expect(forecast([.open(paused, WidgetFixtures.studyCalendar)]).allSatisfy { $0 == 0 })
    }
}
