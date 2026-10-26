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

    /// Today's Study over several decks mixes them, as the iPhone's stream does: a new card from the deck that has
    /// given the fewest, the grade to the card's own deck, and Undo back in that deck.
    @Test func aStreamOverTwoDecksMixesThem() throws {
        let first = try makeDocument(cards: 2)
        let second = try makeDocument(cards: 2)
        let firstUndo = makeUndoManager(for: first)
        let secondUndo = makeUndoManager(for: second)
        let model = SessionViewModel(documents: [first, second])
        let asked = model.document
        let askedUndo = try #require(asked.undoManager)
        let card = try #require(model.currentCard)
        model.reveal()
        step(askedUndo) { model.grade(.good) }
        #expect(asked.card(withID: card.id)?.log.count == 1)
        #expect(model.document !== asked, "the next new card comes from the other deck")
        #expect(model.canUndoLast)
        model.undoLast()
        #expect(model.document === asked)
        #expect(asked.card(withID: card.id)?.isNew == true)
        withExtendedLifetime((firstUndo, secondUndo)) {}
    }

    @Test func theStreamTakesTheNewCardsOfTheDocumentsAllowance() throws {
        let document = try makeDocument(cards: 6)
        document.newCardAllowance = 2
        let model = SessionViewModel(document: document)
        #expect(model.session.totalCount == 2)
        // Without an allowance the plan is the deck's limits.
        document.newCardAllowance = nil
        #expect(SessionViewModel(document: document).session.totalCount == 6)
    }

    /// Past the ring the stack goes on: the cards left in the plan, as on the iPhone, so Catch Up keeps its stack.
    @Test func afterTheRingTheStackIsTheCardsLeftInThePlan() throws {
        let document = try makeDocument(cards: 6)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, rounds: RoundGuide(ends: [1, 2]))
        func easy() throws {
            model.reveal()
            step(try #require(document.undoManager)) { model.grade(.easy) }
        }
        try easy()
        model.continueRound()
        try easy()
        #expect(model.isResting && model.cardsBehind == 0, "nothing is asked at a rest")
        model.continueRound()
        // Four cards are left in the plan: the one asked and three behind it.
        #expect(model.cardsBehind == 3)
        try easy()
        #expect(model.cardsBehind == 2)
        withExtendedLifetime(undoManager) {}
    }

    /// Study These Now: the cards just added come first, then the plan.
    @Test func theCardsJustAddedAreAskedFirst() throws {
        let document = try makeDocument(cards: 6)
        let undoManager = makeUndoManager(for: document)
        let added = Array(document.deck.cards.suffix(2).map(\.id))
        let model = SessionViewModel(document: document, entry: .studyNow(added))
        let first = try #require(model.currentCard?.id)
        #expect(added.contains(first), "an added card first")
        model.reveal()
        step(try #require(document.undoManager)) { model.grade(.easy) }
        let second = try #require(model.currentCard?.id)
        #expect(added.contains(second) && second != first, "then the other one")
        model.reveal()
        step(try #require(document.undoManager)) { model.grade(.easy) }
        #expect(model.currentCard.map { !added.contains($0.id) } == true, "then the plan")
        withExtendedLifetime(undoManager) {}
    }

    @Test func aGradeMovesOnAndCanBeUndone() throws {
        let document = try makeDocument(cards: 2)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document)
        let first = try #require(model.currentCard)

        model.reveal()

        step(undoManager) { model.grade(.good) }
        #expect(document.card(withID: first.id)?.learningState?.phase == .review)
        #expect(model.currentCard?.id != first.id)
        #expect(model.session.completedCount == 1)

        #expect(undoManager.undoActionName == String(localized: "Review"))

        undoManager.undo()
        #expect(document.card(withID: first.id)?.isNew == true)
        #expect(model.currentCard == first)
        #expect(model.session.completedCount == 0)
        #expect(model.stage == .revealed)  // the card comes back with its answer shown
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
        let earlier = SessionViewModel(document: document)
        let first = try #require(earlier.currentCard)
        earlier.reveal()
        step(undoManager) { earlier.grade(.good) }

        let model = SessionViewModel(document: document)
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

        @MainActor init(_ model: SessionViewModel) {
            cards = model.document.deck.cards
            currentCardID = model.currentCard?.id
            completedCount = model.session.completedCount
            totalCount = model.session.totalCount
            reviewCount = model.session.reviewCount
        }
    }

    /// Each undo and redo registers the opposite step anew; the stack must stay in order.
    @Test func severalReviewsAreUndoneAndRedoneOneByOne() throws {
        let document = try makeDocument(cards: 3)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document)
        var places = [Place(model)]
        for _ in 0..<3 {
            model.reveal()
            step(undoManager) { model.grade(.good) }
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
        let model = SessionViewModel(document: document)
        let card = try #require(model.currentCard)
        model.reveal()
        step(undoManager) { model.grade(.good) }
        #expect(model.isResting)

        undoManager.undo()
        #expect(model.stage == .revealed)
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
        let model = SessionViewModel(document: document)

        model.reveal()

        step(undoManager) { model.grade(.good) }
        #expect(document.card(withID: card.id)?.learningState?.step == 1)
        #expect(model.currentCard?.id == card.id)  // stays in the session

        model.reveal()

        step(undoManager) { model.grade(.good) }
        let reviewed = try #require(document.card(withID: card.id)?.learningState)
        #expect(reviewed.phase == .review)
        #expect(model.isResting)

        undoManager.undo()
        undoManager.undo()
        #expect(document.card(withID: card.id) == card)
        undoManager.redo()
        #expect(document.card(withID: card.id)?.learningState?.step == 1)
        #expect(model.currentCard?.learningState?.step == 1)

        model.reveal()

        step(undoManager) { model.grade(.good) }
        #expect(document.card(withID: card.id)?.learningState == reviewed)
    }

    /// Today's plan, then the new cards Push On adds beyond the limit: undo takes back the steps of both,
    /// one by one, and the place of the stream with each.
    @Test func undoReachesAcrossTheSegmentsOfTheStream() throws {
        var learningOptions = LearningOptions()
        learningOptions.fuzzing = false
        learningOptions.steps = 1
        learningOptions.newCardsPerSession = 1
        let planned = Card(question: "planned", answer: "geplant")
        let pushed = Card(question: "pushed", answer: "gedrängt")
        let document = try VocabularyDocument(deck: Deck(learningOptions: learningOptions, cards: [planned, pushed]), calendar: .testing)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document)
        #expect(model.streamStage == .plan)
        #expect(model.currentCard?.id == planned.id)

        model.reveal()
        step(undoManager) { model.grade(.good) }
        #expect(model.isResting)
        #expect(model.rest.extraNew?.cards == 1)
        model.addNewCards()
        #expect(!model.isResting)
        #expect(model.streamStage == .plan)
        #expect(model.currentCard?.id == pushed.id)

        model.reveal()
        step(undoManager) { model.grade(.good) }
        #expect(model.isResting)
        #expect(model.canUndoLast)

        undoManager.undo()
        #expect(model.streamStage == .plan)
        #expect(model.currentCard?.id == pushed.id)
        #expect(document.card(withID: pushed.id) == pushed)
        undoManager.undo()
        #expect(model.streamStage == .plan)
        #expect(model.currentCard?.id == planned.id)
        #expect(document.card(withID: planned.id) == planned)
        #expect(!undoManager.canUndo)
    }

    @Test func aNewReviewAfterUndoDropsTheRedo() throws {
        let document = try makeDocument(cards: 2)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document)
        let first = try #require(model.currentCard)
        model.reveal()
        step(undoManager) { model.grade(.good) }

        undoManager.undo()
        #expect(model.currentCard == first)
        model.reveal()
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

    @Test func forgottenCardIsAMistakeAndAsksAgain() throws {
        let document = try makeDocument(cards: 2, steps: 2)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document)
        let card = try #require(model.currentCard)

        model.reveal()
        #expect(model.stage == .revealed)
        #expect(document.card(withID: card.id)?.isNew == true)  // nothing applied yet

        step(undoManager) { model.grade(.again) }
        #expect(document.card(withID: card.id)?.learningState?.phase == .learning)
        #expect(model.session.mistakeIDs == [card.id])
        #expect(model.stage == .asking)
    }

    @Test func gradingNeedsTheAnswerShownAndCanBeUndone() throws {
        let document = try makeDocument(cards: 2)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document)
        let first = try #require(model.currentCard)

        step(undoManager) { model.grade(.good) }
        #expect(model.stage == .asking)
        #expect(document.card(withID: first.id)?.log.isEmpty == true)

        model.reveal()
        #expect(model.stage == .revealed)
        step(undoManager) { model.grade(.good) }
        #expect(document.card(withID: first.id)?.log.map(\.mode) == [.revealed])
        #expect(model.currentCard?.id != first.id)
        #expect(model.stage == .asking)

        // The card comes back with its answer shown, as on the iPhone: it was graded so.
        undoManager.undo()
        #expect(document.card(withID: first.id)?.isNew == true)
        #expect(model.currentCard == first)
        #expect(model.stage == .revealed)
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

        let model = SessionViewModel(document: document, entry: .practiceNewest)
        #expect(model.isPracticing)
        #expect(model.session.totalCount == 2)
        while !model.isResting {
            let card = try #require(model.currentCard)
            #expect(ids.contains(card.id))
            model.reveal()
            step(undoManager) { model.grade(.good) }
        }
        #expect(model.rest.recap.cards == 2)
        #expect(model.rest.isPracticeOnly)
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
        let model = SessionViewModel(document: document)

        model.reveal()
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

    /// A practice asks like the plan: the answer is revealed before it is graded. It changes no card.
    @Test func practiceAsksLikeThePlan() throws {
        let document = try makeDocument(cards: 1)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document)
        model.reveal()
        step(undoManager) { model.grade(.again) }
        model.reveal()
        step(undoManager) { model.grade(.good) }
        #expect(model.isResting)

        let before = document.deck
        let practice = SessionViewModel(document: document, entry: .practiceMistakes)
        #expect(practice.streamStage == .practiceMistakes)
        step(undoManager) { practice.grade(.good) }
        #expect(practice.session.reviewCount == 0)
        practice.reveal()
        step(undoManager) { practice.grade(.good) }
        #expect(practice.isResting)
        #expect(practice.rest.isPracticeOnly)
        #expect(document.deck == before)
    }

    /// The plan ends the stack: it rests, and with no new cards left there is nothing to add. A practice is
    /// an entry of its own, which practises the mistakes of today, changes no card, and ends at rest.
    @Test func practicingMistakesLeavesScheduleAlone() throws {
        let document = try makeDocument(cards: 1)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document)
        model.reveal()
        step(undoManager) { model.grade(.again) }
        model.reveal()
        step(undoManager) { model.grade(.good) }
        #expect(model.isResting)
        #expect(model.streamStage == .rest)
        #expect(!model.isPracticing)
        #expect(model.rest.extraNew == nil)

        let before = document.deck
        model.addNewCards()
        #expect(model.isResting)
        #expect(model.streamStage == .rest)
        #expect(document.deck == before)

        let practice = SessionViewModel(document: document, entry: .practiceMistakes)
        #expect(practice.isPracticing)
        #expect(practice.streamStage == .practiceMistakes)
        practice.reveal()
        step(undoManager) { practice.grade(.good) }
        #expect(practice.isResting)
        #expect(practice.rest.isPracticeOnly)
        #expect(document.deck == before)
    }

    /// A mistake suspended later isn't practised (#290).
    @Test func suspendedMistakesAreNotPractised() throws {
        let document = try makeDocument(cards: 1, steps: 2)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document)
        let card = try #require(model.currentCard)
        model.reveal()
        step(undoManager) { model.grade(.again) }
        #expect(model.currentCard == document.card(withID: card.id))

        step(undoManager) { model.suspendCurrentCard() }
        #expect(model.isResting)
        #expect(document.deck.mistakes(onDayOf: document.clock.now, calendar: document.calendar).isEmpty)
        #expect(SessionViewModel(document: document, entry: .practiceMistakes).isResting)

        undoManager.undo()
        #expect(!model.isResting)
        #expect(model.currentCard?.id == card.id)
    }

    @Test func undoingPracticeReviewKeepsTheEarlierPlanIntact() throws {
        let document = try makeDocument(cards: 1)
        let undoManager = makeUndoManager(for: document)
        plannedMistake(in: document, undoManager: undoManager)
        let scheduled = document.deck

        let model = SessionViewModel(document: document, entry: .practiceMistakes)
        model.reveal()
        step(undoManager) { model.grade(.good) }
        #expect(model.isResting)
        undoManager.undo()
        #expect(model.streamStage == .practiceMistakes)
        #expect(model.isPracticing)
        #expect(!model.isResting)
        #expect(document.deck == scheduled)
        undoManager.redo()
        #expect(model.isResting)
        #expect(document.deck == scheduled)
    }

    /// A plan with a mistake, as the learner went through it; the model is gone at the end.
    private func plannedMistake(in document: VocabularyDocument, undoManager: UndoManager) {
        let model = SessionViewModel(document: document)
        model.reveal()
        step(undoManager) { model.grade(.again) }
        model.reveal()
        step(undoManager) { model.grade(.good) }
    }

    /// A plan with a mistake, then a practice review of it. Nothing else holds the model,
    /// as in the app once the view closes the stream.
    private func practicedMistake(in document: VocabularyDocument, undoManager: UndoManager) -> SessionViewModel {
        plannedMistake(in: document, undoManager: undoManager)
        let model = SessionViewModel(document: document, entry: .practiceMistakes)
        model.reveal()
        step(undoManager) { model.grade(.good) }
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
            #expect(model.rest.isPracticeOnly)
            released = undoManager
        }
        #expect(released == nil)
    }

    @Test func reviewOfAClosedSessionIsUndoneAndRedone() throws {
        let document = try makeDocument(cards: 1)
        let undoManager = makeUndoManager(for: document)
        var model: SessionViewModel? = SessionViewModel(document: document)
        let card = try #require(model?.currentCard)
        model?.reveal()
        step(undoManager) { model?.grade(.good) }
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
    func removingTheCurrentCardMovesOn(whileTheAnswerIsShown: Bool) throws {
        let document = try makeDocument(cards: 2)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document)
        let current = try #require(model.currentCard)
        if whileTheAnswerIsShown {
            model.reveal()
            #expect(model.stage == .revealed)
        }
        step(undoManager) { document.delete([current.id]) }
        #expect(model.currentCard != nil)
        #expect(model.currentCard?.id != current.id)
        #expect(model.session.totalCount == 1)
        #expect(model.stage == .asking)
    }

    /// The session used to notice removals only by a changed number of cards (#57).
    @Test func removingTheCurrentCardMovesOnEvenIfTheCountStays() throws {
        let document = try makeDocument(cards: 2)
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document)
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
        let model = SessionViewModel(document: document)
        #expect(model.currentCard?.question == "dom")

        undoManager.undo()
        #expect(model.currentCard?.question == "q0")
    }

    /// Editing the card being asked, as the session's edit sheet does, shows the edit and asks on (#289).
    @Test func editingTheCardBeingAskedKeepsTheQuestion() throws {
        let card = Card(question: "dom", answer: "Haus")
        let document = try VocabularyDocument(deck: Deck(cards: [card]))
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document)
        let questionNumber = model.questionNumber

        step(undoManager) { document.editText(of: card.id, to: CardText(question: "dom", answer: "Haus", hint: "der")!) }
        #expect(model.currentCard?.hint == "der")
        #expect(model.stage == .asking)
        #expect(model.questionNumber == questionNumber)

        model.reveal()
        #expect(model.stage == .revealed)
    }

    /// Undoing and redoing an edit of the answer while it is shown changes the answer and keeps it shown.
    @Test func undoingAndRedoingAnAnswerEditKeepsTheAnswerShown() throws {
        let card = Card(question: "dom", answer: "Haus")
        let document = try VocabularyDocument(deck: Deck(cards: [card]))
        let undoManager = makeUndoManager(for: document)
        step(undoManager) { document.editText(of: card.id, to: CardText(question: card.question, answer: "Heim")!) }
        let model = SessionViewModel(document: document)
        model.reveal()
        let questionNumber = model.questionNumber

        undoManager.undo()
        #expect(model.currentCard?.unstamped == card)
        #expect(model.stage == .revealed)
        #expect(model.session.reviewCount == 0)
        #expect(model.questionNumber == questionNumber)

        undoManager.redo()
        #expect(model.currentCard?.unstamped == card.withAnswer("Heim"))
        #expect(model.stage == .revealed)
        #expect(model.session.reviewCount == 0)
        #expect(model.questionNumber == questionNumber)
    }

    /// Fixing the answer once it is shown keeps it shown; the grade is still the learner's to give.
    /// Undo takes back the review first, then the edit (#289).
    @Test func fixingTheShownAnswerKeepsItShown() throws {
        let card = Card(question: "dom", answer: "Heim")
        let document = try VocabularyDocument(deck: Deck(cards: [card]))
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document)
        model.reveal()

        step(undoManager) { document.editText(of: card.id, to: CardText(question: "dom", answer: "Haus")!) }
        #expect(model.stage == .revealed)
        #expect(model.currentCard?.answer == "Haus")
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
        let model = SessionViewModel(document: document)

        model.reveal()

        step(undoManager) { model.grade(.good) }
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
        #expect(document.deck.filterCounts(at: clock.now)[.due] == 0)
        #expect(SessionViewModel(document: document).isResting)

        clock.now = state.due.addingTimeInterval(60)
        #expect(document.deck.filterCounts(at: clock.now)[.due] == 1)
        let next = SessionViewModel(document: document)
        #expect(next.currentCard?.id == card.id)
        next.reveal()
        step(undoManager) { next.grade(.good) }
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

        let earlier = sessionStartedBefore ? SessionViewModel(document: document) : nil
        document.switchTimeZone(to: StudyCalendar.newYork.timeZone)
        let model = earlier ?? SessionViewModel(document: document)
        model.reveal()
        step(undoManager) { model.grade(.good) }

        func review(in calendar: StudyCalendar) -> Card {
            var random = SeededRandom(seed: 0)  // unused without fuzzing
            return Scheduler(learningOptions: learningOptions, calendar: calendar).review(card, grade: .good, at: clock.now, using: &random)
        }
        let expected = review(in: .newYork)
        #expect(expected.learningState?.stability != review(in: .testing).learningState?.stability)
        #expect(expected.learningState?.due != review(in: .testing).learningState?.due)
        // The time on screen in the log is the stopwatch's: what the review did to the card is the rest.
        let reviewed = try #require(document.card(withID: card.id))
        #expect(reviewed.learningState == expected.learningState)
        #expect(reviewed.log.map(\.date) == expected.log.map(\.date))
        #expect(reviewed.log.map(\.grade) == expected.log.map(\.grade))
        #expect(document.deck.progress.map(\.day) == [day])
    }
}
