import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// How long a card was on screen, as the shared `SessionDriver` logs it (`ReviewLogEntry.duration`).
@MainActor
struct SessionDriverDurationTests {
    /// A clock the test moves by hand.
    @MainActor
    final class TestClock {
        private var instant = SuspendingClock.now

        func advance(_ duration: Duration) {
            instant = instant.advanced(by: duration)
        }

        var now: () -> SuspendingClock.Instant { { self.instant } }
    }

    func makeDocument(cards count: Int = 3) throws -> (VocabularyDocument, UndoManager) {
        var learningOptions = LearningOptions()
        learningOptions.steps = 1
        learningOptions.fuzzing = false
        let created = Date(timeIntervalSince1970: 1_791_216_000)
        let cards = (0..<count).map { Card(text: CardText(question: "q\($0)", answer: "a\($0)")!, created: created) }
        let document = try VocabularyDocument(deck: Deck(learningOptions: learningOptions, cards: cards), clock: StudyClock { created.addingTimeInterval(60) })
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        return (document, undoManager)
    }

    func makeDriver(_ document: VocabularyDocument, clock: TestClock) -> SessionDriver {
        let stream = StudyStream(deck: document.deck, at: document.clock.now, calendar: document.calendar, reviewMode: .revealed)
        return SessionDriver(document: document, stream: stream, now: clock.now)
    }

    /// Grades in an undo group of its own, like one tap in the app.
    @discardableResult
    func grade(_ driver: SessionDriver, _ grade: Grade = .good, undoManager: UndoManager) -> Bool {
        undoManager.beginUndoGrouping()
        defer { undoManager.endUndoGrouping() }
        return driver.grade(grade)
    }

    func duration(of id: Card.ID?, in document: VocabularyDocument) -> [Duration?]? {
        id.flatMap(document.card(withID:))?.log.map(\.duration)
    }

    @Test func aGradeLogsHowLongTheCardWasOnScreen() throws {
        let (document, undoManager) = try makeDocument()
        let clock = TestClock()
        let driver = makeDriver(document, clock: clock)
        let first = driver.currentCard?.id
        clock.advance(.milliseconds(4210))
        grade(driver, undoManager: undoManager)
        #expect(duration(of: first, in: document) == [.milliseconds(4210)])

        // The next card counts from the moment it appeared, not from the start of the stream.
        let second = driver.currentCard?.id
        #expect(second != first)
        clock.advance(.seconds(1) + .milliseconds(500))
        grade(driver, undoManager: undoManager)
        #expect(duration(of: second, in: document) == [.milliseconds(1500)])
    }

    @Test func theTimeWhileTheAppIsNotActiveIsLeftOut() throws {
        let (document, undoManager) = try makeDocument()
        let clock = TestClock()
        let driver = makeDriver(document, clock: clock)
        let first = driver.currentCard?.id
        clock.advance(.seconds(2))
        driver.setActive(false)
        clock.advance(.seconds(600))
        driver.setActive(false)  // a repeated report changes nothing
        clock.advance(.seconds(60))
        driver.setActive(true)
        clock.advance(.seconds(1))
        grade(driver, undoManager: undoManager)
        #expect(duration(of: first, in: document) == [.seconds(3)])
    }

    @Test func aCardShownWhileTheAppIsInactiveCountsFromTheMomentItIsActive() throws {
        let (document, undoManager) = try makeDocument()
        let clock = TestClock()
        let driver = makeDriver(document, clock: clock)
        driver.setActive(false)
        grade(driver, undoManager: undoManager)
        let second = driver.currentCard?.id
        clock.advance(.seconds(30))
        driver.setActive(true)
        clock.advance(.seconds(2))
        grade(driver, undoManager: undoManager)
        #expect(duration(of: second, in: document) == [.seconds(2)])
    }

    @Test func undoTakesTheReviewBackAndRedoBringsItBackWithItsDuration() throws {
        let (document, undoManager) = try makeDocument()
        let clock = TestClock()
        let driver = makeDriver(document, clock: clock)
        let first = driver.currentCard?.id
        clock.advance(.milliseconds(3300))
        grade(driver, undoManager: undoManager)

        undoManager.undo()
        #expect(duration(of: first, in: document) == [])
        // The card is asked again, and its time counts from then.
        #expect(driver.currentCard?.id == first)
        clock.advance(.seconds(7))
        undoManager.redo()
        #expect(duration(of: first, in: document) == [.milliseconds(3300)])
        #expect(driver.currentCard?.id != first)
    }

    @Test func practiceLogsNothing() throws {
        let (document, undoManager) = try makeDocument()
        let clock = TestClock()
        let stream = StudyStream(practicingNewestWordsIn: document.deck, at: document.clock.now, calendar: document.calendar)
        let driver = SessionDriver(document: document, stream: stream, now: clock.now)
        clock.advance(.seconds(5))
        grade(driver, undoManager: undoManager)
        #expect(document.deck.cards.allSatisfy { $0.log.isEmpty })
    }

    /// With the real clock, the stream of the iPhone logs at least the wait.
    @Test func aGradeAfterAWaitLogsAtLeastTheWait() async throws {
        let (document, undoManager) = try makeDocument()
        let model = StudyModel(document: document)
        let id = try #require(model.currentCard?.id)
        try await Task.sleep(for: .milliseconds(60))
        model.reveal()
        undoManager.beginUndoGrouping()
        model.grade(.good)
        undoManager.endUndoGrouping()
        let logged = try #require(document.card(withID: id)?.log.first?.duration)
        #expect(logged >= .milliseconds(60))
    }
}
