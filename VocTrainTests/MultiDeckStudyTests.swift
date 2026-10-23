import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// One stream over several decks: each card comes from the deck whose next card is most urgent, the
/// grade goes to that deck, and Undo goes back across decks.
@MainActor
struct MultiDeckStudyTests {
    let created = Date(timeIntervalSince1970: 1_791_216_000)
    /// The documents hold their undo managers weakly: the test keeps them.
    private let undoManagers = UndoManagers()

    final class UndoManagers {
        var all: [UndoManager] = []
    }

    private func document(_ cards: [Card]) throws -> VocabularyDocument {
        let document = try VocabularyDocument(deck: Deck(cards: cards), clock: StudyClock { [created] in created.addingTimeInterval(60) })
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        undoManagers.all.append(undoManager)
        return document
    }

    private func newCards(_ questions: [String]) -> [Card] {
        questions.map { Card(text: CardText(question: $0, answer: "x")!, created: created) }
    }

    /// Reviews due today, last seen `age` days before it: the older, the less is recalled, and the sooner the
    /// stack asks them.
    private func dueReviews(_ questions: [String], age: Int = 10) -> [Card] {
        let calendar = StudyCalendar()
        let dueToday = calendar.start(ofDay: calendar.dayNumber(for: created.addingTimeInterval(60)))
        let lastReview = dueToday.addingTimeInterval(-Double(age) * 86400)
        return questions.map { question in
            let state = LearningState(phase: .review, stability: 10, difficulty: 5, lastReview: lastReview, due: dueToday, reviews: 1)
            return Card(question: question, answer: "x", created: created, learningState: state, log: [ReviewLogEntry(date: lastReview, grade: .good, mode: .revealed)])
        }
    }

    /// Grades the card being asked in an undo group of its deck, like one tap in the app.
    private func grade(_ model: StudyModel, _ grade: Grade) {
        let undoManager = model.document.undoManager
        model.reveal()
        undoManager?.beginUndoGrouping()
        model.grade(grade)
        undoManager?.endUndoGrouping()
    }

    /// A deck whose plan is `reviews` due today, `allowance` of its new cards among them (none by default), with
    /// the `new` cards beyond it for Push On.
    private func deck(reviews: [String] = [], age: Int = 10, new: [String] = [], allowance: Int = 0) throws -> VocabularyDocument {
        let made = try document(dueReviews(reviews, age: age) + newCards(new))
        made.newCardAllowance = allowance
        return made
    }

    private func questions(_ prefix: String, _ count: Int) -> [String] {
        (0..<count).map { "\(prefix)\($0)" }
    }

    /// Answers the cards the stack asks, each Easy, until it rests; the position in `decks` of the deck of each.
    private func askAll(_ model: StudyModel, among decks: [VocabularyDocument]) -> [Int] {
        var order: [Int] = []
        while !model.isResting && order.count < 100 {
            order.append(decks.firstIndex { $0 === model.document } ?? -1)
            grade(model, .easy)
        }
        return order
    }

    @Test func aReviewDueInOneDeckComesBeforeTheNewCardsOfAnother() throws {
        let words = try document(newCards(["a", "b"]))
        let reviews = try document(dueReviews(["r"]))
        let model = StudyModel(documents: [words, reviews])
        #expect(model.document === reviews)
        #expect(model.currentCard?.question == "r")
        grade(model, .good)
        #expect(model.document === words)
        #expect(model.currentCard?.isNew == true)
        #expect(reviews.deck.cards[0].log.count == 2)
    }

    @Test func newCardsAreTakenFromTheDecksInTurn() throws {
        let first = try document(newCards(["a1", "a2", "a3"]))
        let second = try document(newCards(["b1", "b2", "b3"]))
        let model = StudyModel(documents: [first, second])
        var decks: [ObjectIdentifier] = []
        for _ in 0..<2 {
            guard model.currentCard?.isNew == true else { break }
            decks.append(ObjectIdentifier(model.document))
            grade(model, .easy)
        }
        #expect(Set(decks).count == 2)
    }

    @Test func undoGoesBackToTheDeckOfTheLastStep() throws {
        let words = try document(newCards(["a"]))
        let reviews = try document(dueReviews(["r"]))
        let model = StudyModel(documents: [words, reviews])
        grade(model, .good)  // the review, in `reviews`
        #expect(model.document === words)
        grade(model, .easy)  // the new card, in `words`
        #expect(model.canUndo)

        model.undoLast()
        #expect(model.document === words)
        #expect(model.currentCard?.question == "a")
        #expect(model.stage == .revealed)
        #expect(words.deck.cards[0].isNew)

        model.undoLast()
        #expect(model.document === reviews)
        #expect(model.currentCard?.question == "r")
        #expect(reviews.deck.cards[0].log.count == 1)
    }

    @Test func oneDeckRunsAsBefore() throws {
        let words = try document(newCards(["a", "b"]))
        let model = StudyModel(document: words)
        #expect(model.document === words)
        grade(model, .easy)
        #expect(model.document === words)
    }

    // MARK: Push On

    /// Neither deck asked a new card, and both have more beyond their limits: Push On's ten are five from each,
    /// and the stack asks them by turns.
    @Test func pushOnSharesTheNewCardsBetweenTheDecksAndTheStackAlternatesThem() throws {
        let first = try deck(reviews: ["r1"], new: questions("a", 15))
        let second = try deck(reviews: ["r2"], new: questions("b", 15))
        let model = StudyModel(documents: [first, second])
        #expect(askAll(model, among: [first, second]).count == 2)
        #expect(model.isResting)
        #expect(model.streamStage == .rest)
        #expect(model.rest.extraNew?.cards == StudyStream.newCardChunk)

        model.addNewCards()
        #expect(!model.isResting)
        #expect(askAll(model, among: [first, second]) == [0, 1, 0, 1, 0, 1, 0, 1, 0, 1])
        #expect(first.deck.cards.filter { !$0.isNew }.count == 6)
        #expect(second.deck.cards.filter { !$0.isNew }.count == 6)
        // Ten more are there for the next Push On, five from each again.
        #expect(model.isResting)
        #expect(model.extraNew?.cards == StudyStream.newCardChunk)
        model.addNewCards()
        #expect(askAll(model, among: [first, second]) == [0, 1, 0, 1, 0, 1, 0, 1, 0, 1])
    }

    /// A deck with no new cards left gives none, and one with fewer than its share gives what it has: the other
    /// deck makes up the ten.
    @Test func pushOnTakesTheRestFromTheDeckThatHasNewCardsLeft() throws {
        let none = try deck(reviews: ["r"])
        let words = try deck(reviews: ["w"], new: questions("b", 15))
        let model = StudyModel(documents: [none, words])
        #expect(askAll(model, among: [none, words]).count == 2)
        model.addNewCards()
        #expect(askAll(model, among: [none, words]) == Array(repeating: 1, count: 10))

        let short = try deck(reviews: ["r"], new: questions("a", 3))
        let long = try deck(reviews: ["w"], new: questions("b", 15))
        let both = StudyModel(documents: [short, long])
        #expect(askAll(both, among: [short, long]).count == 2)
        #expect(both.extraNew?.cards == StudyStream.newCardChunk)
        both.addNewCards()
        let order = askAll(both, among: [short, long])
        #expect(order.filter { $0 == 0 }.count == 3)
        #expect(order.filter { $0 == 1 }.count == 7)
        #expect(Array(order.prefix(6)) == [0, 1, 0, 1, 0, 1])
    }

    /// The deck that has given fewer new cards so far gets more of the ten, and its cards come first.
    @Test func pushOnGoesToTheDeckThatHasGivenFewerNewCards() throws {
        let busy = try deck(reviews: ["r1"], new: questions("a", 20), allowance: 3)
        let idle = try deck(reviews: ["r2"], new: questions("b", 20))
        let model = StudyModel(documents: [busy, idle])
        // The two reviews and the three new cards of the plan.
        #expect(askAll(model, among: [busy, idle]).count == 5)
        #expect(model.isResting)

        model.addNewCards()
        #expect(askAll(model, among: [busy, idle]) == [1, 1, 1, 0, 1, 0, 1, 0, 1, 0])
    }

    /// No deck has a new card beyond its limits: nothing to push on with, and Push On changes nothing.
    @Test func pushOnHasNothingToAddWithoutNewCards() throws {
        let first = try deck(reviews: ["a1"])
        let second = try deck(reviews: ["b1"])
        let model = StudyModel(documents: [first, second])
        #expect(askAll(model, among: [first, second]).count == 2)
        #expect(model.isResting)
        #expect(model.extraNew == nil)
        #expect(model.rest.extraNew == nil)

        let before = (first.deck, second.deck)
        model.addNewCards()
        #expect(model.isResting)
        #expect(model.streamStage == .rest)
        #expect(first.deck == before.0)
        #expect(second.deck == before.1)
    }

    // MARK: Rests

    /// A deck that has done its plan rests while another still has cards: the stack goes on, and the rest of the
    /// plan comes with the last card of the last deck.
    @Test func theRestOfThePlanComesOnlyWhenEveryDeckIsDone() throws {
        let short = try deck(reviews: ["a"], age: 100)
        let long = try deck(reviews: ["b1", "b2"], age: 10)
        let model = StudyModel(documents: [short, long])
        #expect(model.document === short)

        grade(model, .good)
        #expect(model.document === long)
        #expect(!model.isResting)
        #expect(model.streamStage == .plan)
        grade(model, .good)
        #expect(!model.isResting)
        #expect(model.stage == .asking)
        grade(model, .good)
        #expect(model.isResting)
        #expect(model.streamStage == .rest)
        #expect(model.rest.roundEnd == nil)
    }

    /// Three decks of reviews that the day's plan cuts into two rounds: 20 cards, of which the goal takes 15, the
    /// first round ending at 12. Each deck's cards are alike, so the stack asks the oldest deck first, then
    /// the next, whatever order the cards of a deck come in: 8 cards, then 10, then 2. The goal ends in the
    /// second deck, and the last five cards, three of the second and two of the third, are cut.
    private func threeDecksOfTwentyReviews() throws -> [VocabularyDocument] {
        [
            try document(dueReviews(questions("a", 8), age: 100)),
            try document(dueReviews(questions("b", 10), age: 30)),
            try document(dueReviews(questions("c", 2), age: 5)),
        ]
    }

    /// The streak step comes once for the whole run, at the card of the day that ends the round whichever deck
    /// it is in; the ring's rest comes at the goal.
    @Test func theStreakStepRestsOnceForTheWholeRun() async throws {
        let decks = try threeDecksOfTwentyReviews()
        let ring = DailyRingModel()
        await ring.refresh(documents: decks, delay: .zero).value
        #expect(ring.progress?.roundEnds == [12, 15])
        let model = StudyModel(documents: decks, ring: ring)

        var rests: [(done: Int, end: RoundEnd, doneInDecks: [Int])] = []
        var done = 0
        while (!model.isResting || model.isRoundRest) && done < 100 {
            if let end = model.rest.roundEnd, model.isRoundRest {
                rests.append((done, end, decks.map { deck in deck.deck.cards.filter { $0.log.count > 1 }.count }))
                model.continueRound()
            } else {
                grade(model, .good)
                done += 1
            }
        }
        // The twelfth card ended the round: eight of the first deck and four of the second.
        #expect(rests.map(\.done) == [12, 15])
        #expect(rests.map(\.end) == [RoundEnd(round: 1, rounds: 2), RoundEnd(round: 2, rounds: 2)])
        #expect(rests.first?.doneInDecks == [8, 4, 0])
        #expect(rests.last?.doneInDecks == [8, 7, 0])
        #expect(done == 20)
        #expect(model.streamStage == .rest)
        #expect(!model.isRoundRest)
    }

    /// The ring is closed with five cards of the plan left, in two decks: Catch Up goes on with all of them, in
    /// the order of the stack, and the plan then rests.
    @Test func catchUpGoesOnWithTheCutCardsOfEveryDeck() async throws {
        let decks = try threeDecksOfTwentyReviews()
        let ring = DailyRingModel()
        await ring.refresh(documents: decks, delay: .zero).value
        let model = StudyModel(documents: decks, ring: ring)

        var done = 0
        while !model.isRoundRest && done < 100 {
            grade(model, .good)
            done += 1
        }
        #expect(done == 12)
        model.continueRound()
        while !model.isRoundRest && done < 100 {
            grade(model, .good)
            done += 1
        }
        #expect(done == 15)
        #expect(model.rest.roundEnd == RoundEnd(round: 2, rounds: 2))
        #expect(model.rest.roundEnd?.closesRing == true)
        #expect(model.currentCard == nil)

        model.continueRound()
        var order: [Int] = []
        while !model.isResting && order.count < 100 {
            order.append(decks.firstIndex { $0 === model.document } ?? -1)
            grade(model, .good)
        }
        #expect(order == [1, 1, 1, 2, 2])
        #expect(model.isResting)
        #expect(!model.isRoundRest)
        #expect(model.streamStage == .rest)
        #expect(decks.allSatisfy { deck in deck.deck.cards.allSatisfy { $0.log.count == 2 } })
    }
}
