import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

@MainActor
struct StudyModelTests {
    let created = Date(timeIntervalSince1970: 1_791_216_000)

    func makeDocument(questions: [String] = ["dom", "kot"]) throws -> (VocabularyDocument, UndoManager) {
        let cards = questions.map { Card(text: CardText(question: $0, answer: "x")!, created: created) }
        let document = try VocabularyDocument(deck: Deck(cards: cards), clock: StudyClock { [created] in created.addingTimeInterval(60) })
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        return (document, undoManager)
    }

    /// Grades in an undo group of its own, like one tap in the app.
    func grade(_ model: StudyModel, _ grade: Grade, undoManager: UndoManager) {
        undoManager.beginUndoGrouping()
        model.grade(grade)
        undoManager.endUndoGrouping()
    }

    @Test func theStreamTakesTheNewCardsOfTheDocumentsAllowance() throws {
        let (document, _) = try makeDocument(questions: ["a", "b", "c", "d", "e"])
        document.newCardAllowance = 2
        let model = StudyModel(document: document)
        #expect(model.session.totalCount == 2)
        #expect(document.dueCards.counts.new == 2)
    }

    @Test func gradingNeedsTheAnswerShown() throws {
        let (document, undoManager) = try makeDocument()
        let model = StudyModel(document: document)
        #expect(model.stage == .asking)

        grade(model, .good, undoManager: undoManager)
        #expect(model.session.reviewCount == 0)
        #expect(document.deck.cards.allSatisfy { $0.isNew })

        model.reveal()
        #expect(model.stage == .revealed)
    }

    @Test func reviewsAreRecordedAsRevealed() throws {
        let (document, undoManager) = try makeDocument()
        let model = StudyModel(document: document)
        let id = try #require(model.currentCard?.id)

        model.reveal()
        grade(model, .good, undoManager: undoManager)
        #expect(document.card(withID: id)?.log.map(\.mode) == [.revealed])
        #expect(document.card(withID: id)?.log.map(\.grade) == [.good])
        #expect(model.session.reviewCount == 1)
        #expect(model.stage == .asking)
    }

    @Test func undoTakesBackTheCardAndTheStreamsPlace() throws {
        let (document, undoManager) = try makeDocument()
        let model = StudyModel(document: document)
        let card = try #require(model.currentCard)

        model.reveal()
        grade(model, .again, undoManager: undoManager)
        undoManager.undo()
        #expect(document.card(withID: card.id) == card)
        #expect(model.currentCard == card)
        #expect(model.session.reviewCount == 0)
        // The card returns with its answer showing, ready to be graded again.
        #expect(model.stage == .revealed)

        undoManager.redo()
        #expect(document.card(withID: card.id)?.log.map(\.grade) == [.again])
        #expect(model.session.reviewCount == 1)
    }

    /// On the iPhone too, a card can be suspended in the stream, revealed or not (#290).
    @Test func suspendingMovesOnAndCanBeUndone() throws {
        let (document, undoManager) = try makeDocument()
        let model = StudyModel(document: document)
        let card = try #require(model.currentCard)
        #expect(!model.hasUndoableSteps)

        model.reveal()
        undoManager.beginUndoGrouping()
        model.suspendCurrentCard()
        undoManager.endUndoGrouping()
        #expect(document.card(withID: card.id)?.isSuspended == true)
        #expect(document.card(withID: card.id)?.learningState == nil)
        #expect(model.currentCard?.id != card.id)
        #expect(model.stage == .asking)
        #expect(model.hasUndoableSteps)

        undoManager.undo()
        #expect(document.card(withID: card.id) == card)
        #expect(model.currentCard == card)
        #expect(!model.hasUndoableSteps)
    }

    /// Once the plan is done, the stream goes on with the practice of the mistakes of today,
    /// which changes no card, as on the Mac; a practice entry of its own ends at rest.
    @Test func practicingMistakesLeavesScheduleAlone() throws {
        let (document, undoManager) = try makeDocument(questions: ["dom"])
        let model = StudyModel(document: document)
        let id = try #require(model.currentCard?.id)
        #expect(!model.rest.canKeepGoing)

        model.reveal()
        grade(model, .again, undoManager: undoManager)
        model.reveal()
        grade(model, .easy, undoManager: undoManager)
        #expect(model.isResting)
        #expect(!model.isPracticing)
        #expect(model.rest.canKeepGoing)

        let before = document.deck
        model.keepGoing()
        #expect(model.isPracticing)
        #expect(!model.isResting)
        #expect(model.streamStage == .practiceMistakes)
        #expect(model.currentCard?.id == id)
        model.reveal()
        grade(model, .easy, undoManager: undoManager)
        // Then the newest words, again and again.
        #expect(model.streamStage == .practiceNewest)
        #expect(document.deck == before)

        let practice = StudyModel(document: document, entry: .practiceMistakes)
        #expect(practice.isPracticing)
        practice.reveal()
        grade(practice, .easy, undoManager: undoManager)
        #expect(practice.isResting)
        #expect(practice.rest.isPracticeOnly)
        #expect(document.deck == before)
    }

    /// The plan is done: the stream rests, then reviews ahead, with ordinary reviews that undo
    /// takes back across the segments.
    @Test func afterThePlanTheStreamRestsAndReviewsAhead() throws {
        let lastReview = created.addingTimeInterval(-5 * 86400)
        let state = LearningState(phase: .review, stability: 10, difficulty: 5, lastReview: lastReview, due: created.addingTimeInterval(5 * 86400), reviews: 1)
        let ahead = Card(question: "ahead", answer: "x", created: created, learningState: state, log: [ReviewLogEntry(date: lastReview, grade: .good, mode: .revealed)])
        let new = Card(text: CardText(question: "new", answer: "x")!, created: created)
        let document = try VocabularyDocument(deck: Deck(cards: [new, ahead]), clock: StudyClock { [created] in created.addingTimeInterval(60) })
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        let model = StudyModel(document: document)
        #expect(model.streamStage == .plan)
        #expect(model.rest.nextDue != nil)

        model.reveal()
        grade(model, .good, undoManager: undoManager)
        model.reveal()
        grade(model, .good, undoManager: undoManager)
        #expect(model.isResting)
        #expect(model.rest.recap.cards == 1)
        #expect(model.rest.canKeepGoing)

        model.keepGoing()
        #expect(model.streamStage == .reviewAhead)
        #expect(model.currentCard?.id == ahead.id)
        model.reveal()
        grade(model, .good, undoManager: undoManager)
        #expect(document.card(withID: ahead.id)?.log.count == 2)
        #expect(model.hasUndoableSteps)

        undoManager.undo()
        #expect(model.streamStage == .reviewAhead)
        #expect(document.card(withID: ahead.id) == ahead)
    }

    /// "+10 new" offers the cards beyond the daily limit, with what they cost, and asks them.
    @Test func newCardsBeyondTheLimitComeOnRequest() throws {
        var learningOptions = LearningOptions()
        learningOptions.newCardsPerSession = 1
        let cards = (0..<15).map { Card(text: CardText(question: "q\($0)", answer: "x")!, created: created) }
        let document = try VocabularyDocument(deck: Deck(learningOptions: learningOptions, cards: cards), clock: StudyClock { [created] in created.addingTimeInterval(60) })
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        let model = StudyModel(document: document)
        #expect(model.session.totalCount == 1)
        #expect(model.extraNew?.cards == StudyStream.newCardChunk)
        #expect((model.extraNew?.reviewsPerDay ?? 0) > 0)

        for _ in 0..<learningOptions.steps {
            model.reveal()
            grade(model, .good, undoManager: undoManager)
        }
        #expect(model.isResting)
        model.addNewCards()
        #expect(!model.isResting)
        #expect(model.session.totalCount == StudyStream.newCardChunk)
        #expect(model.currentCard?.isNew == true)
    }

    /// The view speaks a Greek question when this changes: once per move to a card, also
    /// when undo brings a card back, and not for a reveal.
    @Test func questionNumberCountsEveryMoveOnce() throws {
        let (document, undoManager) = try makeDocument()
        let model = StudyModel(document: document)
        #expect(model.questionNumber == 0)

        model.reveal()
        #expect(model.questionNumber == 0)
        grade(model, .good, undoManager: undoManager)
        #expect(model.questionNumber == 1)
        undoManager.undo()
        #expect(model.questionNumber == 2)
    }

    /// A document with one due review card: Good sends it to another day, Forgot makes it a lapse.
    /// `lapses` is how many it has had, so a threshold can be one lapse away.
    func reviewDocument(lapses: Int = 0, leechThreshold: Int = 8) throws -> (VocabularyDocument, UndoManager) {
        let lastReview = created.addingTimeInterval(-10 * 86400)
        let state = LearningState(
            phase: .review, stability: 10, difficulty: 5, lastReview: lastReview, due: created.addingTimeInterval(-86400), reviews: 1 + lapses, lapses: lapses)
        let card = Card(question: "due", answer: "x", created: created, learningState: state, log: [ReviewLogEntry(date: lastReview, grade: .good, mode: .revealed)])
        var options = LearningOptions()
        options.leechThreshold = leechThreshold
        let document = try VocabularyDocument(deck: Deck(learningOptions: options, cards: [card]), clock: StudyClock { [created] in created.addingTimeInterval(60) })
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        return (document, undoManager)
    }

    /// The receipt says where the card goes, and the view lets it leave that way: into the ring when FSRS
    /// lets it go to another day, under the stack when it comes back today, off the screen for a leech and
    /// in a practice.
    @Test func theReceiptDecidesWhereTheCardGoes() throws {
        // A due review card: Good lets it go to another day.
        let (reviewDoc, reviewUndo) = try reviewDocument()
        let review = StudyModel(document: reviewDoc)
        review.reveal()
        reviewUndo.beginUndoGrouping()
        let done = try #require(review.grade(.good))
        reviewUndo.endUndoGrouping()
        #expect(done.destination == .ring)
        reviewUndo.undo()

        // Forgot keeps it today, in relearning.
        review.reveal()
        reviewUndo.beginUndoGrouping()
        let lapsed = try #require(review.grade(.again))
        reviewUndo.endUndoGrouping()
        #expect(lapsed.destination == .stack)

        // A new card: a learning step keeps it today, Easy sends it to another day.
        let (document, undoManager) = try makeDocument(questions: ["dom"])
        let model = StudyModel(document: document)
        model.reveal()
        grade(model, .again, undoManager: undoManager)
        model.reveal()
        undoManager.beginUndoGrouping()
        let easy = try #require(model.grade(.easy))
        undoManager.endUndoGrouping()
        #expect(easy.destination == .ring)

        // Practice schedules nothing: no interval, and the card flies off.
        let practice = StudyModel(document: document, entry: .practiceMistakes)
        practice.reveal()
        undoManager.beginUndoGrouping()
        let practiced = try #require(practice.grade(.good))
        undoManager.endUndoGrouping()
        #expect(practiced.interval == nil)
        #expect(practiced.destination == .away)
    }

    @Test func aLeechFliesOffEvenThoughItsGradeIsAnInterval() throws {
        // One lapse short of the threshold: Forgot makes it a leech, and suspends it.
        let (document, undoManager) = try reviewDocument(lapses: 7, leechThreshold: 8)
        let model = StudyModel(document: document)
        model.reveal()
        undoManager.beginUndoGrouping()
        let receipt = try #require(model.grade(.again))
        undoManager.endUndoGrouping()
        #expect(receipt.isLeech)
        #expect(receipt.destination == .away)
        #expect(receipt.flightLabel == "suspended · leech")
    }

    @Test func theLabelOnTheCardNamesWhereItGoes() {
        func label(_ interval: ReviewInterval?, isLeech: Bool = false) -> String? {
            GradeReceipt(grade: .good, interval: interval, isLeech: isLeech).flightLabel
        }
        #expect(label(.days(1)) == "tomorrow")
        #expect(label(.days(8)) == "in 8 days")
        #expect(label(.days(91)) == "in 3 months")
        #expect(label(.days(800)) == "in 2 years")
        #expect(label(.learning) == "again today")
        #expect(label(.learning, isLeech: true) == "suspended · leech")
        #expect(label(nil) == nil)
        #expect(GradeReceipt(grade: .good, interval: .days(8)).announcement == "Good, in 8 days")
        #expect(GradeReceipt(grade: .again, interval: .learning).announcement == "Forgot, again today")
    }

    /// The Undo button and the one in the menu are enabled by the same thing.
    @Test func undoIsEnabledWhenThereIsAStepToTakeBack() throws {
        let (document, undoManager) = try makeDocument()
        let model = StudyModel(document: document)
        #expect(!model.canUndo)

        model.reveal()
        #expect(!model.canUndo)
        grade(model, .good, undoManager: undoManager)
        #expect(model.canUndo)

        undoManager.undo()
        #expect(!model.canUndo)
        undoManager.redo()
        #expect(model.canUndo)

        // Suspending is a step too.
        undoManager.beginUndoGrouping()
        model.suspendCurrentCard()
        undoManager.endUndoGrouping()
        #expect(model.canUndo)
    }

    /// Undo plays the grade backwards: the card comes out of the ring or from under the stack, and across the
    /// end of a round the ring goes up to the bar first.
    @Test func undoPlaysTheGradeBackwards() throws {
        #expect(try StudyModel(document: makeDocument().0).undoReturn == nil)

        // Into the ring, and out of it.
        let (reviewDoc, reviewUndo) = try reviewDocument()
        let review = StudyModel(document: reviewDoc)
        review.reveal()
        reviewUndo.beginUndoGrouping()
        review.grade(.good)
        reviewUndo.endUndoGrouping()
        #expect(review.undoReturn == UndoReturn(from: .ring, fromRest: review.isResting))
        review.undoLast()
        #expect(review.returnedByUndo)
        #expect(review.stage == .revealed)
        #expect(review.undoReturn == nil)

        // Under the stack, and up from it.
        review.reveal()
        reviewUndo.beginUndoGrouping()
        review.grade(.again)
        reviewUndo.endUndoGrouping()
        #expect(review.undoReturn == UndoReturn(from: .stack, fromRest: false))
        review.undoLast()
        #expect(review.stage == .revealed)

        // Each grade has its own way back, the last first.
        let (document, undoManager) = try makeDocument(questions: ["a", "b", "c", "d"])
        let model = StudyModel(document: document)
        model.reveal()
        grade(model, .again, undoManager: undoManager)
        model.reveal()
        grade(model, .easy, undoManager: undoManager)
        #expect(model.undoReturn?.from == .ring)
        model.undoLast()
        #expect(model.undoReturn?.from == .stack)
        model.undoLast()
        #expect(model.undoReturn == nil)

        // The grade that ends a round leaves the stream at rest, with the ring down in it.
        let (roundDoc, roundUndo) = try makeDocument(questions: ["a", "b", "c"])
        let rounded = StudyModel(document: roundDoc, rounds: RoundGuide(ends: [1, 3]))
        rounded.reveal()
        grade(rounded, .easy, undoManager: roundUndo)
        #expect(rounded.isRoundRest)
        #expect(rounded.undoReturn == UndoReturn(from: .ring, fromRest: true))
        rounded.undoLast()
        #expect(!rounded.isResting)
        #expect(rounded.stage == .revealed)
    }

    /// The cards of the round that wait behind the one asked: the stack under the card.
    @Test func theStackIsTheCardsLeftInTheRound() throws {
        let (document, undoManager) = try makeDocument(questions: ["a", "b", "c", "d", "e"])
        let model = StudyModel(document: document, rounds: RoundGuide(ends: [3, 5]))
        // Three cards end the first round: this one and two behind it.
        #expect(model.cardsBehind == 2)

        // Forgot keeps the card in the round: it goes under the stack, and the stack is as it was.
        model.reveal()
        grade(model, .again, undoManager: undoManager)
        #expect(model.cardsBehind == 2)

        // A card done leaves the stack one card shorter.
        model.reveal()
        grade(model, .easy, undoManager: undoManager)
        #expect(model.cardsBehind == 1)
        model.reveal()
        grade(model, .easy, undoManager: undoManager)
        #expect(model.cardsBehind == 0)

        // Without rounds, and in a practice, there is no stack.
        #expect(StudyModel(document: document, entry: .practiceMistakes).cardsBehind == 0)
        let (plain, _) = try makeDocument(questions: ["a", "b", "c"])
        #expect(StudyModel(document: plain).cardsBehind == 0)
    }

    /// The ring is evaluated after the stream is opened, say: the rounds count from the next card on.
    @Test func roundsThatArriveWhileTheStreamIsOpenAreRestedFor() throws {
        let (document, undoManager) = try makeDocument(questions: ["a", "b", "c", "d", "e", "f"])
        let model = StudyModel(document: document)
        for _ in 0..<2 {
            model.reveal()
            grade(model, .easy, undoManager: undoManager)
        }
        #expect(!model.isResting)

        // The progress arrives after two cards, with the rounds ending at 3 and 6.
        model.adoptRounds(RoundGuide(ends: [3, 6]))
        model.reveal()
        grade(model, .easy, undoManager: undoManager)
        #expect(model.isRoundRest)
        #expect(model.rest.roundEnd == RoundEnd(round: 1, rounds: 2))
    }

    /// A boundary already passed stays passed: no rest for it, and no turning back.
    @Test func aRoundAlreadyEndedIsNotRestedForWhenTheRoundsArrive() throws {
        let (document, undoManager) = try makeDocument(questions: ["a", "b", "c", "d", "e", "f"])
        let model = StudyModel(document: document)
        for _ in 0..<3 {
            model.reveal()
            grade(model, .easy, undoManager: undoManager)
        }
        model.adoptRounds(RoundGuide(ends: [3, 6]))
        #expect(!model.isResting)
        #expect(model.currentCard != nil)
        // The same rounds again change nothing.
        model.adoptRounds(RoundGuide(ends: [3, 6]))
        #expect(!model.isResting)
    }

    /// The model follows the ring by itself: the stream opens before the ring is evaluated, and rests at the
    /// round's end the progress then names (six new cards cut into rounds of four and two).
    @Test func theStreamFollowsTheRingForItsRounds() async throws {
        let (document, undoManager) = try makeDocument(questions: ["a", "b", "c", "d", "e", "f"])
        let ring = DailyRingModel()
        #expect(ring.progress == nil)
        let model = StudyModel(document: document, ring: ring)
        for _ in 0..<2 {
            model.reveal()
            grade(model, .easy, undoManager: undoManager)
        }
        await ring.refresh(documents: [document], delay: .zero).value
        // The change reaches the model on the next turn of the main actor.
        try await Task.sleep(for: .milliseconds(100))
        for _ in 0..<2 {
            model.reveal()
            grade(model, .easy, undoManager: undoManager)
        }
        #expect(model.isRoundRest)
    }

    @Test func streamWithoutCardsRests() throws {
        let (document, _) = try makeDocument(questions: [])
        let model = StudyModel(document: document)
        #expect(model.isResting)
        #expect(model.currentCard == nil)
        #expect(!model.rest.canKeepGoing)
        #expect(model.extraNew == nil)
    }

    // MARK: Rounds

    /// `count` review cards that are due today, so the plan takes all of them (a backlog from before the day
    /// would send a share of it) and a Good sends each to another day: a card done.
    func makeDueDocument(count: Int) throws -> (VocabularyDocument, UndoManager) {
        let calendar = StudyCalendar()
        let dueToday = calendar.start(ofDay: calendar.dayNumber(for: created.addingTimeInterval(60)))
        let lastReview = dueToday.addingTimeInterval(-10 * 86400)
        let cards = (0..<count).map { index in
            let state = LearningState(phase: .review, stability: 10, difficulty: 5, lastReview: lastReview, due: dueToday, reviews: 1)
            return Card(
                question: "q\(index)", answer: "x", created: created, learningState: state, log: [ReviewLogEntry(date: lastReview, grade: .good, mode: .revealed)])
        }
        let document = try VocabularyDocument(deck: Deck(cards: cards), clock: StudyClock { [created] in created.addingTimeInterval(60) })
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        return (document, undoManager)
    }

    /// Grades the card being asked Good, `times` times, one undo group for each.
    func done(_ times: Int, _ model: StudyModel, undoManager: UndoManager) {
        for _ in 0..<times {
            model.reveal()
            grade(model, .good, undoManager: undoManager)
        }
    }

    @Test func theStreamRestsAtTheEndOfARoundAndNextRoundGoesOn() throws {
        let (document, undoManager) = try makeDueDocument(count: 5)
        let model = StudyModel(document: document, rounds: RoundGuide(ends: [2, 4, 5]))
        done(1, model, undoManager: undoManager)
        #expect(!model.isResting)

        done(1, model, undoManager: undoManager)
        #expect(model.isResting && model.isRoundRest)
        #expect(model.stage == .resting)
        #expect(model.rest.roundEnd == RoundEnd(round: 1, rounds: 3))
        #expect(model.currentCard == nil)
        #expect(!model.rest.canKeepGoing)
        // Nothing is graded while it rests.
        model.reveal()
        grade(model, .good, undoManager: undoManager)
        #expect(model.session.reviewCount == 2)

        model.continueRound()
        #expect(!model.isResting)
        #expect(model.stage == .asking)
        #expect(model.currentCard != nil)
        done(2, model, undoManager: undoManager)
        #expect(model.rest.roundEnd == RoundEnd(round: 2, rounds: 3))
        model.continueRound()
        done(1, model, undoManager: undoManager)
        // The last round ends in the rest of the plan.
        #expect(model.isResting && !model.isRoundRest)
        #expect(model.rest.roundEnd == nil)
        #expect(model.rest.recap.cards == 5)
    }

    @Test func undoAcrossARoundBoundaryBringsTheCardBackAndTakesTheRestAway() throws {
        let (document, undoManager) = try makeDueDocument(count: 5)
        let model = StudyModel(document: document, rounds: RoundGuide(ends: [2, 4, 5]))
        done(1, model, undoManager: undoManager)
        // The card that ends the round: the second one asked.
        let second = try #require(model.currentCard)
        done(1, model, undoManager: undoManager)
        #expect(model.isRoundRest)

        // Undo at the rest takes back the review that ended the round.
        undoManager.undo()
        #expect(!model.isResting)
        #expect(model.currentCard?.id == second.id)
        #expect(document.card(withID: second.id)?.log.count == 1)
        undoManager.redo()
        #expect(model.isRoundRest)

        // After Next Round, undo takes back the card of the new round, and again the one before the boundary.
        model.continueRound()
        done(1, model, undoManager: undoManager)
        undoManager.undo()
        #expect(!model.isResting)
        undoManager.undo()
        #expect(!model.isResting)
        #expect(model.currentCard?.id == second.id)
        // Done again, it ends the round again.
        done(1, model, undoManager: undoManager)
        #expect(model.isRoundRest)
        #expect(model.rest.roundEnd?.round == 1)
    }

    @Test func roundsDoneBeforeTheStreamBeganAreNotRestedFor() throws {
        let (document, undoManager) = try makeDueDocument(count: 5)
        // Two cards were done in another deck: round 1 is over, and the next ends at 4 and the last at 6.
        let model = StudyModel(document: document, rounds: RoundGuide(ends: [2, 4, 6], doneElsewhere: 2))
        done(1, model, undoManager: undoManager)
        #expect(!model.isResting)
        done(1, model, undoManager: undoManager)
        #expect(model.rest.roundEnd == RoundEnd(round: 2, rounds: 3))
    }

    @Test func leavingAtARoundRestLosesNothingAndTheNextStreamGoesOn() throws {
        let (document, undoManager) = try makeDueDocument(count: 5)
        let model = StudyModel(document: document, rounds: RoundGuide(ends: [2, 4, 5]))
        done(2, model, undoManager: undoManager)
        #expect(model.isRoundRest)
        // Done for Now closes the stream; the reviews are in the deck, and the next stream starts with the
        // rounds as they are then: round 1 is done, so it asks the third card at once.
        let next = StudyModel(document: document, rounds: RoundGuide(ends: [2, 4, 5], doneElsewhere: 0))
        #expect(document.deck.doneCards(onDayOf: document.clock.now, calendar: document.calendar) == 2)
        #expect(!next.isResting)
        #expect(next.currentCard != nil)
        #expect(next.session.totalCount == 3)
    }

    @Test func aStreamWithoutRoundsOrAPracticeNeverRestsForThem() throws {
        let (document, undoManager) = try makeDueDocument(count: 3)
        let plain = StudyModel(document: document)
        done(2, plain, undoManager: undoManager)
        #expect(!plain.isResting)
        #expect(plain.rest.roundEnd == nil)

        let (other, otherUndo) = try makeDueDocument(count: 3)
        // The cards go wrong first, so there is something to practice.
        let first = StudyModel(document: other)
        first.reveal()
        grade(first, .again, undoManager: otherUndo)
        let practice = StudyModel(document: other, entry: .practiceMistakes, rounds: RoundGuide(ends: [1, 2]))
        #expect(!practice.isResting)
        practice.reveal()
        grade(practice, .good, undoManager: otherUndo)
        #expect(!practice.isRoundRest)
    }
}
