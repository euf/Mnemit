import Foundation
import Testing

@testable import MacVocTrain
@testable import VocabCore

@MainActor
struct SessionViewModelTests {
    private func makeDocument(cards: Int, steps: Int = 1) throws -> VocabularyDocument {
        var learningOptions = LearningOptions()
        learningOptions.steps = steps
        learningOptions.fuzzing = false
        return try VocabularyDocument(deck: Deck(learningOptions: learningOptions, cards: (0..<cards).map { Card(question: "q\($0)", answer: "a\($0)") }), calendar: .testing)
    }

    @Test func theStreamTakesTheNewCardsOfTheDocumentsAllowance() throws {
        let document = try makeDocument(cards: 6)
        document.newCardAllowance = 2
        let model = SessionViewModel(document: document, autoAdvance: true)
        #expect(model.session.totalCount == 2)
        // Without an allowance the plan is the deck's limits.
        document.newCardAllowance = nil
        #expect(SessionViewModel(document: document, autoAdvance: true).session.totalCount == 6)
    }

    @Test func correctResponseMovesOnAndCanBeUndone() throws {
        let document = try makeDocument(cards: 2)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, autoAdvance: true)
        let first = try #require(model.currentCard)

        model.input = first.answer
        step(undoManager) { model.submit() }
        #expect(document.card(withID: first.id)?.learningState?.phase == .review)
        #expect(model.previous?.grade == .good)
        #expect(model.currentCard?.id != first.id)
        #expect(model.session.completedCount == 1)

        #expect(undoManager.undoActionName == String(localized: "Review"))

        undoManager.undo()
        #expect(document.card(withID: first.id)?.isNew == true)
        #expect(model.currentCard == first)
        #expect(model.session.completedCount == 0)
        #expect(model.stage == .asking)
        #expect(!undoManager.canUndo)  // card and session in one step
        #expect(undoManager.redoActionName == String(localized: "Review"))

        undoManager.redo()
        #expect(document.card(withID: first.id)?.learningState?.phase == .review)
        #expect(model.currentCard?.id != first.id)
        #expect(model.session.completedCount == 1)
        #expect(undoManager.undoActionName == String(localized: "Review"))
    }

    @Test func undoingAReviewOfAnEarlierStreamOnlyTakesBackTheCard() throws {
        let document = try makeDocument(cards: 2, steps: 2)
        let undoManager = makeUndoManager(for: document)
        let earlier = SessionViewModel(document: document, autoAdvance: true)
        let first = try #require(earlier.currentCard)
        earlier.input = first.answer
        step(undoManager) { earlier.submit() }

        let model = SessionViewModel(document: document, autoAdvance: true)
        let session = model.session.id
        let current = try #require(model.currentCard)

        undoManager.undo()
        #expect(document.card(withID: first.id)?.isNew == true)
        #expect(model.session.id == session)
        #expect(model.currentCard?.id == current.id)

        undoManager.redo()
        #expect(document.card(withID: first.id)?.log.count == 1)
        #expect(model.session.id == session)
    }

    /// What undo and redo of a review must bring back. The cards rather than the deck:
    /// undo records today's snapshot again instead of restoring the old one.
    private struct Place: Equatable {
        var cards: [Card]
        var currentCardID: Card.ID?
        var completedCount: Int
        var totalCount: Int
        var reviewCount: Int
        var stage: SessionViewModel.Stage

        @MainActor init(_ model: SessionViewModel) {
            cards = model.document.deck.cards
            currentCardID = model.currentCard?.id
            completedCount = model.session.completedCount
            totalCount = model.session.totalCount
            reviewCount = model.session.reviewCount
            stage = model.stage
        }
    }

    /// Each undo and redo registers the opposite step anew; the stack must stay in order.
    @Test func severalReviewsAreUndoneAndRedoneOneByOne() throws {
        let document = try makeDocument(cards: 3)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, autoAdvance: true)
        var places = [Place(model)]
        for _ in 0..<3 {
            model.input = try #require(model.currentCard).answer
            step(undoManager) { model.submit() }
            places.append(Place(model))
        }
        #expect(model.isResting)

        for place in places.dropLast().reversed() {
            undoManager.undo()
            #expect(Place(model) == place)
        }
        #expect(!undoManager.canUndo)

        for place in places.dropFirst() {
            undoManager.redo()
            #expect(Place(model) == place)
        }
        #expect(!undoManager.canRedo)
    }

    @Test func undoingTheReviewThatEmptiedThePlanAsksAgain() throws {
        let document = try makeDocument(cards: 1)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, autoAdvance: true)
        let card = try #require(model.currentCard)
        model.input = card.answer
        step(undoManager) { model.submit() }
        #expect(model.isResting)

        undoManager.undo()
        #expect(model.stage == .asking)
        #expect(model.currentCard == card)

        undoManager.redo()
        #expect(model.isResting)
    }

    /// The fuzz of intervals belongs to the session's value: after undo, the same grade
    /// gives the same due date.
    @Test func undoingAReviewInLearningRestoresStepAndFuzz() throws {
        let now = Date(timeIntervalSince1970: 1_791_216_000)
        var learningOptions = LearningOptions()
        learningOptions.steps = 2
        learningOptions.fuzzing = true
        // A long stability, so the fuzz has many days to choose from.
        let learningState = LearningState(phase: .learning, stability: 100, difficulty: 5, lastReview: now.addingTimeInterval(-100 * 86400), due: now)
        let card = Card(question: "dom", answer: "Haus", learningState: learningState)
        let document = try VocabularyDocument(deck: Deck(learningOptions: learningOptions, cards: [card]), clock: ManualClock(now).studyClock, calendar: .testing)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, autoAdvance: true)

        model.input = "Haus"
        step(undoManager) { model.submit() }
        #expect(document.card(withID: card.id)?.learningState?.step == 1)
        #expect(model.currentCard?.id == card.id)  // stays in the session

        model.input = "Haus"
        step(undoManager) { model.submit() }
        let reviewed = try #require(document.card(withID: card.id)?.learningState)
        #expect(reviewed.phase == .review)
        #expect(model.isResting)

        undoManager.undo()
        undoManager.undo()
        #expect(document.card(withID: card.id) == card)
        undoManager.redo()
        #expect(document.card(withID: card.id)?.learningState?.step == 1)
        #expect(model.currentCard?.learningState?.step == 1)

        model.input = "Haus"
        step(undoManager) { model.submit() }
        #expect(document.card(withID: card.id)?.learningState == reviewed)
    }

    /// Today's plan, review ahead, practice: undo takes back the reviews of all of them, one by
    /// one, and the place of the stream with each. The review ahead is an ordinary review.
    @Test func undoReachesAcrossTheSegmentsOfTheStream() throws {
        let now = Date()
        let lastReview = now.addingTimeInterval(-5 * 86400)
        let state = LearningState(phase: .review, stability: 10, difficulty: 5, lastReview: lastReview, due: now.addingTimeInterval(5 * 86400), reviews: 1)
        let ahead = Card(question: "ahead", answer: "voraus", learningState: state, log: [ReviewLogEntry(date: lastReview, grade: .good, mode: .revealed)])
        let due = Card(question: "due", answer: "fällig", learningState: LearningState(phase: .review, stability: 3, difficulty: 5, lastReview: now.addingTimeInterval(-3 * 86400), due: now.addingTimeInterval(-3600), reviews: 1))
        var learningOptions = LearningOptions()
        learningOptions.fuzzing = false
        let document = try VocabularyDocument(deck: Deck(learningOptions: learningOptions, cards: [due, ahead]), calendar: .testing)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, studyBy: .flashcards)
        #expect(model.streamStage == .plan)

        model.reveal()
        step(undoManager) { model.grade(.good) }
        #expect(model.isResting)
        model.keepGoing()
        #expect(model.streamStage == .reviewAhead)
        #expect(model.currentCard?.id == ahead.id)
        // Ahead of time, the review asks the way the plan did.
        guard case let .study(study) = model.mode else {
            Issue.record("Review ahead is a study segment.")
            return
        }
        #expect(study.reviewMode == .revealed)

        model.reveal()
        step(undoManager) { model.grade(.good) }
        #expect(model.isPracticing)
        #expect(document.card(withID: ahead.id)?.log.count == 2)
        #expect(model.canUndoLast)

        undoManager.undo()
        #expect(model.streamStage == .reviewAhead)
        #expect(model.currentCard?.id == ahead.id)
        #expect(document.card(withID: ahead.id) == ahead)
        undoManager.undo()
        #expect(model.streamStage == .plan)
        #expect(model.currentCard?.id == due.id)
        #expect(document.card(withID: due.id) == due)
        #expect(!undoManager.canUndo)
    }

    @Test func aNewReviewAfterUndoDropsTheRedo() throws {
        let document = try makeDocument(cards: 2)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, autoAdvance: true)
        let first = try #require(model.currentCard)
        model.input = first.answer
        step(undoManager) { model.submit() }

        undoManager.undo()
        #expect(model.currentCard == first)
        model.input = "wrong"
        model.submit()
        step(undoManager) { model.grade(.again) }
        #expect(!undoManager.canRedo)
        #expect(document.card(withID: first.id)?.log.map(\.grade) == [.again])
        #expect(model.session.mistakeIDs == [first.id])

        undoManager.undo()
        #expect(document.card(withID: first.id)?.isNew == true)
        #expect(model.currentCard == first)
        #expect(model.session.mistakeIDs.isEmpty)
        #expect(!undoManager.canUndo)
    }

    @Test func wrongResponseAsksForGrade() throws {
        let document = try makeDocument(cards: 2, steps: 2)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, autoAdvance: true)
        let card = try #require(model.currentCard)

        model.input = "nonsense"
        model.submit()
        #expect(model.stage == .feedback(.wrong, response: "nonsense"))
        #expect(model.suggestedGrade == .again)
        #expect(document.card(withID: card.id)?.isNew == true)  // nothing applied yet

        step(undoManager) { model.grade(.again) }
        #expect(document.card(withID: card.id)?.learningState?.phase == .learning)
        #expect(model.session.mistakeIDs == [card.id])
        #expect(model.stage == .asking)
    }

    @Test func typoCanBeAcceptedAsCorrect() throws {
        let document = try VocabularyDocument(deck: Deck(cards: [Card(question: "Tag", answer: "dzień")]))
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, autoAdvance: true)

        model.input = "dzien"
        model.submit()
        #expect(model.stage == .feedback(.almostCorrect, response: "dzien"))
        step(undoManager) { model.grade(.good) }
        #expect(document.deck.cards[0].log.map(\.grade) == [.good])
    }

    @Test(arguments: [false, true])
    func highlightingFollowsTheCaseSensitivityOfTheDeck(caseSensitive: Bool) throws {
        var learningOptions = LearningOptions()
        learningOptions.caseSensitive = caseSensitive
        let document = try VocabularyDocument(deck: Deck(learningOptions: learningOptions, cards: [Card(question: "Ding", answer: "Wumbel")]))
        let model = SessionViewModel(document: document, autoAdvance: true)
        #expect(model.highlightedAnswer == nil)

        model.input = "wumbl"
        model.submit()
        #expect(model.stage == .feedback(.almostCorrect, response: "wumbl"))
        let marked = model.highlightedAnswer?.filter(\.isMismatch).map(\.text)
        #expect(marked == (caseSensitive ? ["W", "e"] : ["e"]))
    }

    @Test func withoutAutoAdvanceCorrectResponsesAreConfirmed() throws {
        let document = try makeDocument(cards: 1)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, autoAdvance: false)
        model.input = "a0"
        model.submit()
        #expect(model.suggestedGrade == .good)
        step(undoManager) { model.grade(.easy) }
        #expect(document.deck.cards[0].log.map(\.grade) == [.easy])
        #expect(model.isResting)
    }

    @Test func flashCardsGradeOnlyAfterRevealingAndCanBeUndone() throws {
        let document = try makeDocument(cards: 2)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, studyBy: .flashcards)
        let first = try #require(model.currentCard)

        step(undoManager) { model.grade(.good) }
        #expect(model.stage == .asking)
        #expect(document.card(withID: first.id)?.log.isEmpty == true)
        model.input = first.answer
        model.submit()
        #expect(model.stage == .asking)

        model.reveal()
        #expect(model.stage == .revealed)
        #expect(model.suggestedGrade == nil)
        step(undoManager) { model.grade(.good) }
        #expect(document.card(withID: first.id)?.log.map(\.mode) == [.revealed])
        #expect(model.previous?.grade == .good)
        #expect(model.currentCard?.id != first.id)
        #expect(model.stage == .asking)

        undoManager.undo()
        #expect(document.card(withID: first.id)?.isNew == true)
        #expect(model.currentCard == first)
        #expect(model.stage == .asking)
    }

    @Test func typingIgnoresReveal() throws {
        let document = try makeDocument(cards: 1)
        let model = SessionViewModel(document: document)
        model.reveal()
        #expect(model.stage == .asking)
    }

    /// "Practice Newest Words" practises the newest batch, from a fresh window, and changes
    /// none of the cards; the practice ends at rest.
    @Test func practisingTheNewestWordsAsksOnlyThemAndChangesNothing() throws {
        let older = Card(text: CardText(question: "older", answer: "älter")!, created: Date(timeIntervalSince1970: 1_791_000_000))
        let newest = (0..<2).map { Card(text: CardText(question: "n\($0)", answer: "a\($0)")!, created: Date(timeIntervalSince1970: 1_791_216_000)) }
        let document = try VocabularyDocument(deck: Deck(cards: [older] + newest), calendar: .testing)
        let undoManager = makeUndoManager(for: document)
        let ids = Set(newest.map(\.id))
        let before = document.deck

        let model = SessionViewModel(document: document, autoAdvance: true, entry: .practiceNewest)
        #expect(model.isPracticing)
        #expect(model.session.totalCount == 2)
        while !model.isResting {
            let card = try #require(model.currentCard)
            #expect(ids.contains(card.id))
            model.input = card.answer
            step(undoManager) { model.submit() }
        }
        #expect(model.rest.recap.cards == 2)
        #expect(model.rest.isPracticeOnly)
        #expect(!model.rest.canKeepGoing)
        #expect(model.extraNew == nil)
        #expect(document.deck == before)

        #expect(SessionViewModel(document: VocabularyDocument(), entry: .practiceNewest).isResting)
        #expect(SessionViewModel(document: document, entry: .practiceMistakes).isResting)
    }

    /// The lapse that reaches the leech threshold suspends the card; one undo takes the
    /// grade and the suspension back.
    @Test func aLeechIsSuspendedByItsGradeAndUndoBringsItBack() throws {
        var learningOptions = LearningOptions()
        learningOptions.fuzzing = false
        learningOptions.leechThreshold = 8
        let state = LearningState(
            phase: .review, stability: 10, difficulty: 5,
            lastReview: Date(timeIntervalSinceNow: -10 * 86400), due: Date(timeIntervalSinceNow: -3600), reviews: 12, lapses: 7)
        let leech = Card(question: "q", answer: "a", learningState: state)
        let document = try VocabularyDocument(deck: Deck(learningOptions: learningOptions, cards: [leech]), calendar: .testing)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, autoAdvance: true)

        model.input = "wrong"
        model.submit()
        step(undoManager) { model.grade(.again) }
        let stored = try #require(document.card(withID: leech.id))
        #expect(stored.isSuspended)
        #expect(stored.learningState?.lapses == 8)
        #expect(document.deck.isLeech(stored))
        #expect(model.isResting)
        #expect(model.receipt?.isLeech == true)

        undoManager.undo()
        #expect(document.card(withID: leech.id) == leech)
        #expect(!model.isResting)
        #expect(model.session.leechIDs.isEmpty)
    }

    /// Practice goes on from the plan the way it asked, and changes no card.
    @Test func flashCardsCarryOverToPractice() throws {
        let document = try makeDocument(cards: 1)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, studyBy: .flashcards)
        model.reveal()
        step(undoManager) { model.grade(.again) }
        model.reveal()
        step(undoManager) { model.grade(.good) }
        #expect(model.isResting)

        let before = document.deck
        model.keepGoing()
        #expect(model.streamStage == .practiceMistakes)
        // The answer has to be revealed before it is graded, in practice too.
        step(undoManager) { model.grade(.good) }
        #expect(model.session.reviewCount == 0)
        model.reveal()
        step(undoManager) { model.grade(.good) }
        #expect(model.streamStage == .practiceNewest)
        #expect(document.deck == before)
    }

    @Test func practicingMistakesLeavesScheduleAlone() throws {
        let document = try makeDocument(cards: 1)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, autoAdvance: true)
        model.input = "wrong"
        model.submit()
        step(undoManager) { model.grade(.again) }
        model.input = "a0"
        step(undoManager) { model.submit() }
        #expect(model.isResting)
        #expect(model.rest.canKeepGoing)

        // From the stream: the mistakes of today, then the newest words.
        let before = document.deck
        model.keepGoing()
        #expect(model.streamStage == .practiceMistakes)
        #expect(model.isPracticing)
        #expect(!model.isResting)
        model.input = "a0"
        step(undoManager) { model.submit() }
        #expect(model.streamStage == .practiceNewest)
        #expect(document.deck == before)

        // As an entry of its own: the practice of the mistakes alone, which ends at rest.
        let practice = SessionViewModel(document: document, autoAdvance: true, entry: .practiceMistakes)
        #expect(practice.isPracticing)
        practice.input = "a0"
        step(undoManager) { practice.submit() }
        #expect(practice.isResting)
        #expect(document.deck == before)
    }

    /// A mistake suspended later isn't practised (#290).
    @Test func suspendedMistakesAreNotPractised() throws {
        let document = try makeDocument(cards: 1, steps: 2)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, autoAdvance: true)
        let card = try #require(model.currentCard)
        model.input = "wrong"
        model.submit()
        step(undoManager) { model.grade(.again) }
        #expect(model.currentCard == document.card(withID: card.id))

        step(undoManager) { model.suspendCurrentCard() }
        #expect(model.isResting)
        #expect(model.previous?.question == card.question)
        #expect(model.previous?.grade == nil)
        #expect(document.deck.mistakes(onDayOf: document.clock.now, calendar: document.calendar).isEmpty)
        #expect(!model.rest.canKeepGoing)
        #expect(SessionViewModel(document: document, entry: .practiceMistakes).isResting)

        undoManager.undo()
        #expect(!model.isResting)
        #expect(model.currentCard?.id == card.id)
        #expect(model.previous == nil)
    }

    @Test func undoingPracticeReviewKeepsTheEarlierPlanIntact() throws {
        let document = try makeDocument(cards: 1)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, autoAdvance: true)
        model.input = "wrong"
        step(undoManager) { model.submit() }
        step(undoManager) { model.grade(.again) }
        model.input = "a0"
        step(undoManager) { model.submit() }
        model.keepGoing()
        let scheduled = document.deck

        model.input = "a0"
        step(undoManager) { model.submit() }
        #expect(model.streamStage == .practiceNewest)
        undoManager.undo()
        #expect(model.streamStage == .practiceMistakes)
        #expect(model.isPracticing)
        #expect(document.deck == scheduled)
        undoManager.redo()
        #expect(model.streamStage == .practiceNewest)
    }

    /// A plan with a mistake, then a practice review of it. Nothing else holds the model,
    /// as in the app once the view closes the stream.
    private func practicedMistake(in document: VocabularyDocument, undoManager: UndoManager) -> SessionViewModel {
        let model = SessionViewModel(document: document, autoAdvance: true)
        model.input = "wrong"
        step(undoManager) { model.submit() }
        step(undoManager) { model.grade(.again) }
        model.input = "a0"
        step(undoManager) { model.submit() }
        model.keepGoing()
        model.input = "a0"
        step(undoManager) { model.submit() }
        return model
    }

    /// The undo manager doesn't hold the target of an undo action (#174).
    @Test func undoingPracticeReviewOfAClosedSessionChangesNothing() throws {
        let document = try makeDocument(cards: 1)
        let undoManager = makeUndoManager(for: document)
        var model: SessionViewModel? = practicedMistake(in: document, undoManager: undoManager)
        weak let closed = model
        model = nil
        #expect(closed == nil)
        let scheduled = document.deck

        undoManager.undo()
        #expect(document.deck == scheduled)
        undoManager.redo()
        #expect(document.deck == scheduled)
    }

    @Test func redoingPracticeReviewOfAClosedSessionChangesNothing() throws {
        let document = try makeDocument(cards: 1)
        let undoManager = makeUndoManager(for: document)
        var model: SessionViewModel? = practicedMistake(in: document, undoManager: undoManager)
        let scheduled = document.deck
        undoManager.undo()
        #expect(model?.isPracticing == true)
        weak let closed = model
        model = nil
        #expect(closed == nil)

        undoManager.redo()
        #expect(document.deck == scheduled)
    }

    /// The undo actions don't hold their undo manager (#181).
    @Test func practiceReviewLetsItsUndoManagerGo() throws {
        let document = try makeDocument(cards: 1)
        weak var released: UndoManager?
        autoreleasepool {
            let undoManager = makeUndoManager(for: document)
            let model = practicedMistake(in: document, undoManager: undoManager)
            #expect(model.isPracticing)
            released = undoManager
        }
        #expect(released == nil)
    }

    @Test func reviewOfAClosedSessionIsUndoneAndRedone() throws {
        let document = try makeDocument(cards: 1)
        let undoManager = makeUndoManager(for: document)
        var model: SessionViewModel? = SessionViewModel(document: document, autoAdvance: true)
        let card = try #require(model?.currentCard)
        model?.input = card.answer
        step(undoManager) { model?.submit() }
        let reviewed = try #require(document.card(withID: card.id))
        weak let closed = model
        model = nil
        #expect(closed == nil)

        undoManager.undo()
        #expect(document.card(withID: card.id) == card)
        undoManager.redo()
        #expect(document.card(withID: card.id) == reviewed)
    }

    @Test(arguments: [false, true])
    func removingTheCurrentCardMovesOn(whileShowingFeedback: Bool) throws {
        let document = try makeDocument(cards: 2)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, autoAdvance: true)
        let current = try #require(model.currentCard)
        if whileShowingFeedback {
            model.input = "wrong"
            model.submit()
            #expect(model.stage == .feedback(.wrong, response: "wrong"))
        }
        step(undoManager) { document.delete([current.id]) }
        #expect(model.currentCard != nil)
        #expect(model.currentCard?.id != current.id)
        #expect(model.session.totalCount == 1)
        #expect(model.stage == .asking)
        #expect(model.input.isEmpty)
        #expect(model.suggestedGrade == nil)
    }

    /// The session used to notice removals only by a changed number of cards (#57).
    @Test func removingTheCurrentCardMovesOnEvenIfTheCountStays() throws {
        let document = try makeDocument(cards: 2)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, autoAdvance: true)
        let current = try #require(model.currentCard)
        step(undoManager) {
            document.delete([current.id])
            document.add(CardText(question: "kot", answer: "Katze")!)
        }
        #expect(document.deck.cards.count == 2)
        #expect(model.currentCard != nil)
        #expect(model.currentCard?.id != current.id)
        #expect(model.stage == .asking)
        #expect(model.session.totalCount == 1)
    }

    @Test func undoingAnEditChangesTheCurrentCard() throws {
        let document = try makeDocument(cards: 1)
        let undoManager = makeUndoManager(for: document)
        let card = document.deck.cards[0]
        step(undoManager) { document.editText(of: card.id, to: CardText(question: "dom", answer: card.answer)!) }
        let model = SessionViewModel(document: document, autoAdvance: true)
        #expect(model.currentCard?.question == "dom")

        undoManager.undo()
        #expect(model.currentCard?.question == "q0")
    }

    @Test func undoingAndRedoingAnAnswerEditRechecksFeedback() throws {
        let card = Card(question: "dom", answer: "Haus")
        let document = try VocabularyDocument(deck: Deck(cards: [card]))
        let undoManager = makeUndoManager(for: document)
        step(undoManager) { document.editText(of: card.id, to: CardText(question: card.question, answer: "Heim")!) }
        let model = SessionViewModel(document: document, autoAdvance: false)
        model.input = "Heim"
        model.submit()
        #expect(model.stage == .feedback(.correct, response: "Heim"))
        let questionNumber = model.questionNumber
        model.input = "not submitted"

        undoManager.undo()
        #expect(model.currentCard?.unstamped == card)
        #expect(model.stage == .feedback(.wrong, response: "Heim"))
        #expect(model.suggestedGrade == .again)
        #expect(model.session.reviewCount == 0)
        #expect(model.questionNumber == questionNumber)

        undoManager.redo()
        #expect(model.currentCard?.unstamped == card.withAnswer("Heim"))
        #expect(model.stage == .feedback(.correct, response: "Heim"))
        #expect(model.suggestedGrade == .good)
        #expect(model.session.reviewCount == 0)
        #expect(model.questionNumber == questionNumber)
    }

    /// Editing the card being asked, as the session's edit sheet does, keeps the
    /// response typed so far and asks on (#289).
    @Test func editingTheCardBeingAskedKeepsTheResponse() throws {
        let card = Card(question: "dom", answer: "Haus")
        let document = try VocabularyDocument(deck: Deck(cards: [card]))
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, autoAdvance: false)
        let questionNumber = model.questionNumber
        model.input = "Haus"

        step(undoManager) { document.editText(of: card.id, to: CardText(question: "dom", answer: "Haus", hint: "der")!) }
        #expect(model.currentCard?.hint == "der")
        #expect(model.stage == .asking)
        #expect(model.input == "Haus")
        #expect(model.questionNumber == questionNumber)

        model.submit()
        #expect(model.stage == .feedback(.correct, response: "Haus"))
    }

    /// Fixing the answer once it is shown checks the response against the fixed card;
    /// the grade is still the learner's to give. Undo takes back the review first, then
    /// the edit (#289).
    @Test func fixingTheShownAnswerChecksTheResponseAgain() throws {
        let card = Card(question: "dom", answer: "Heim")
        let document = try VocabularyDocument(deck: Deck(cards: [card]))
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, autoAdvance: true)
        model.input = "Haus"
        model.submit()
        #expect(model.stage == .feedback(.wrong, response: "Haus"))

        step(undoManager) { document.editText(of: card.id, to: CardText(question: "dom", answer: "Haus")!) }
        #expect(model.stage == .feedback(.correct, response: "Haus"))
        #expect(model.suggestedGrade == .good)
        #expect(model.session.reviewCount == 0)

        step(undoManager) { model.grade(.good) }
        let reviewed = try #require(document.card(withID: card.id))
        #expect(reviewed.answer == "Haus")
        #expect(reviewed.log.count == 1)

        undoManager.undo()
        #expect(document.card(withID: card.id)?.log.isEmpty == true)
        #expect(document.card(withID: card.id)?.answer == "Haus")
        undoManager.undo()
        #expect(document.card(withID: card.id)?.answer == "Heim")
    }

    @Test func undoingAndRedoingCaseSensitivityRechecksWithoutAutoAdvance() throws {
        var options = LearningOptions()
        options.caseSensitive = false
        let card = Card(question: "dom", answer: "Haus")
        let document = try VocabularyDocument(deck: Deck(learningOptions: options, cards: [card]))
        let undoManager = makeUndoManager(for: document)
        options.caseSensitive = true
        step(undoManager) { document.updateLearningOptions(options) }
        let model = SessionViewModel(document: document, autoAdvance: true)
        model.input = "haus"
        model.submit()
        #expect(model.stage == .feedback(.almostCorrect, response: "haus"))
        let questionNumber = model.questionNumber

        undoManager.undo()
        #expect(model.stage == .feedback(.correct, response: "haus"))
        #expect(model.suggestedGrade == .good)
        #expect(model.highlightedAnswer == nil)
        #expect(document.deck.cards == [card])
        #expect(model.currentCard == card)
        #expect(model.session.reviewCount == 0)
        #expect(model.questionNumber == questionNumber)

        undoManager.redo()
        #expect(model.stage == .feedback(.almostCorrect, response: "haus"))
        #expect(model.suggestedGrade == .again)
        #expect(model.highlightedAnswer?.filter(\.isMismatch).map(\.text) == ["H"])
        #expect(document.deck.cards == [card])
        #expect(model.currentCard == card)
        #expect(model.session.reviewCount == 0)
        #expect(model.questionNumber == questionNumber)
    }

    @Test func emptyResponseRevealsTheAnswer() throws {
        let document = try makeDocument(cards: 1)
        let model = SessionViewModel(document: document, autoAdvance: true)
        model.submit()
        #expect(model.stage == .feedback(.wrong, response: ""))
    }

    @Test func nothingDueMeansTheStreamRestsAtOnce() throws {
        let learningState = LearningState(phase: .review, stability: 10, difficulty: 5, lastReview: Date(), due: Date().addingTimeInterval(86400))
        let card = Card(question: "q", answer: "a", learningState: learningState)
        let model = try SessionViewModel(document: VocabularyDocument(deck: Deck(cards: [card])))
        #expect(model.isResting)
    }

    @Test func streamsAcrossTheStartOfAStudyDay() throws {
        let calendar = StudyCalendar.testing
        let day = CivilDate(year: 2026, month: 10, day: 6).dayNumber
        // 03:30, still the study day before.
        let clock = ManualClock(calendar.start(ofDay: day).addingTimeInterval(-30 * 60))
        var learningOptions = LearningOptions()
        learningOptions.steps = 1
        learningOptions.fuzzing = false
        let card = Card(question: "dom", answer: "Haus")
        let document = try VocabularyDocument(deck: Deck(learningOptions: learningOptions, cards: [card]), clock: clock.studyClock, calendar: calendar)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, autoAdvance: true)

        model.input = "Haus"
        step(undoManager) { model.submit() }
        let state = try #require(document.card(withID: card.id)?.learningState)
        #expect(state.phase == .review)
        #expect(state.lastReview == clock.now)
        #expect(document.deck.progress.map(\.day) == [day - 1])
        // The interval counts from the study day before, so the card is due earlier
        // than it would be after a review at 04:30.
        var random = SeededRandom(seed: 0)  // unused without fuzzing
        let interval = Scheduler(learningOptions: learningOptions, calendar: calendar).intervalDays(stability: state.stability, using: &random)
        #expect(state.due == calendar.start(ofDay: day - 1 + interval))

        clock.now = state.due.addingTimeInterval(-60)
        #expect(document.deck.dueCount(at: clock.now) == 0)
        #expect(SessionViewModel(document: document, autoAdvance: true).isResting)

        clock.now = state.due.addingTimeInterval(60)
        #expect(document.deck.dueCount(at: clock.now) == 1)
        let next = SessionViewModel(document: document, autoAdvance: true)
        #expect(next.currentCard?.id == card.id)
        next.input = "Haus"
        step(undoManager) { next.submit() }
        #expect(document.card(withID: card.id)?.learningState?.lastReview == clock.now)
        #expect(document.deck.progress.map(\.day) == [day - 1, day - 1 + interval])
    }

    /// A review after the machine's time zone changed counts elapsed study days and the
    /// due date in the new zone, also in a session that started before (#186).
    @Test(arguments: [false, true])
    func reviewsAfterATimeZoneSwitchCountStudyDaysInTheNewZone(sessionStartedBefore: Bool) throws {
        let day = CivilDate(year: 2026, month: 10, day: 6).dayNumber
        // 23:00 in New York, already 05:00 of the next day in Berlin.
        let clock = ManualClock(StudyCalendar.newYork.start(ofDay: day).addingTimeInterval(19 * 3600))
        // Last reviewed at 21:00 in New York, 03:00 in Berlin: the same study day in
        // New York, the one before in Berlin.
        let lastReview = clock.now.addingTimeInterval(-2 * 3600)
        let learningState = LearningState(phase: .review, stability: 5, difficulty: 5, lastReview: lastReview, due: lastReview)
        let card = Card(question: "dom", answer: "Haus", learningState: learningState)
        var learningOptions = LearningOptions()
        learningOptions.fuzzing = false
        let document = try VocabularyDocument(deck: Deck(learningOptions: learningOptions, cards: [card]), clock: clock.studyClock, calendar: .testing)
        let undoManager = makeUndoManager(for: document)

        let earlier = sessionStartedBefore ? SessionViewModel(document: document, autoAdvance: true) : nil
        document.switchTimeZone(to: StudyCalendar.newYork.timeZone)
        let model = earlier ?? SessionViewModel(document: document, autoAdvance: true)
        model.input = "Haus"
        step(undoManager) { model.submit() }

        func review(in calendar: StudyCalendar) -> Card {
            var random = SeededRandom(seed: 0)  // unused without fuzzing
            return Scheduler(learningOptions: learningOptions, calendar: calendar).review(card, grade: .good, at: clock.now, using: &random)
        }
        let expected = review(in: .newYork)
        #expect(expected.learningState?.stability != review(in: .testing).learningState?.stability)
        #expect(expected.learningState?.due != review(in: .testing).learningState?.due)
        #expect(document.card(withID: card.id) == expected)
        #expect(document.deck.progress.map(\.day) == [day])
    }
}
