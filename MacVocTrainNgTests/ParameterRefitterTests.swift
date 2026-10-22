import Foundation
import Testing

@testable import MacVocTrain
@testable import VocabCore

/// The automatic refit of the parameters (`ParameterRefit`) as a document gets it when it
/// opens: fitted in the background, applied through the editing layer as one undo step.
@MainActor
struct ParameterRefitterTests {
    let calendar = StudyCalendar.testing

    /// 250 cards that were all forgotten three days after their first review and then recalled
    /// the day after, started over ten days so that the newest reviews hold both: 500 usable
    /// reviews, which the default parameters predict badly, so a fit beats them by far.
    func forgetfulDeck(options: LearningOptions = LearningOptions()) throws -> Deck {
        let noon = Date(timeIntervalSince1970: 1_791_201_600)
        let cards = (0..<250).map { index -> Card in
            let steps: [(days: Int, grade: Grade)] = [(0, .good), (3, .again), (4, .good)]
            let log = steps.map { ReviewLogEntry(date: noon.addingTimeInterval(Double(index % 10 + $0.days) * 86400 + Double(index)), grade: $0.grade) }
            let state = LearningState(phase: .review, stability: 3, difficulty: 5, lastReview: log[2].date, due: log[2].date, reviews: 3)
            return Card(question: "q\(index)", answer: "a", learningState: state, log: log)
        }
        return try Deck(learningOptions: options, cards: cards)
    }

    /// An undo manager that groups explicitly: there is no event loop in tests to close the
    /// group of a change. The test opens the group around what it runs, as one event does.
    func attachUndoManager(to document: VocabularyDocument) -> UndoManager {
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        return undoManager
    }

    /// Runs the refit of `document` in one undo group.
    func refit(_ document: VocabularyDocument, with undoManager: UndoManager) async {
        undoManager.beginUndoGrouping()
        await ParameterRefitter.refit(document)
        undoManager.endUndoGrouping()
    }

    @Test func aDueDeckGetsBetterParametersAsOneUndoStep() async throws {
        let document = try VocabularyDocument(deck: forgetfulDeck(), calendar: calendar)
        let undoManager = attachUndoManager(to: document)
        let original = document.deck

        await refit(document, with: undoManager)

        let options = document.deck.learningOptions
        let fit = try #require(options.lastAutoFit)
        #expect(fit.adopted)
        #expect(fit.reviewCount == 500)
        #expect(options.parameters != .default)
        #expect(undoManager.undoActionName == String(localized: "Update Parameters"))

        undoManager.undo()
        #expect(document.deck.learningOptions == original.learningOptions)
        #expect(document.deck.cards == original.cards)
        #expect(!undoManager.canUndo)

        undoManager.redo()
        #expect(document.deck.learningOptions == options)
    }

    @Test func aStudyStreamKeepsTheDeckAsItIs() async throws {
        let document = try VocabularyDocument(deck: forgetfulDeck(), calendar: calendar)
        let undoManager = attachUndoManager(to: document)
        let original = document.deck

        // The stream is up when the fit is due, and again when it is done. No undo group is open,
        // so a change of the deck would raise.
        await ParameterRefitter.refit(document) { false }

        #expect(document.deck == original)
        #expect(!undoManager.canUndo)
    }

    @Test func aDeckThatIsNotDueOrSwitchedOffIsNotChanged() async throws {
        var off = LearningOptions()
        off.updatesParametersAutomatically = false
        let switchedOff = try VocabularyDocument(deck: forgetfulDeck(options: off), calendar: calendar)
        let fewReviews = try VocabularyDocument(deck: Deck(cards: [Card(question: "dom", answer: "Haus")]), calendar: calendar)
        for document in [switchedOff, fewReviews] {
            let undoManager = attachUndoManager(to: document)
            let original = document.deck
            await ParameterRefitter.refit(document)
            #expect(document.deck == original)
            #expect(!undoManager.canUndo)
        }
    }

    /// The learner switches the update off while the fit runs: the result is dropped.
    @Test func aResultForADeckThatMovedOnIsDropped() throws {
        let document = try VocabularyDocument(deck: forgetfulDeck(), calendar: calendar)
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        let date = Date(timeIntervalSince1970: 1_791_216_000)
        let result = ParameterRefit.Result(parameters: Weights.fast, fit: LearningOptions.AutoFit(date: date, reviewCount: 500, adopted: true))

        var options = document.deck.learningOptions
        options.updatesParametersAutomatically = false
        undoManager.beginUndoGrouping()
        document.updateLearningOptions(options)
        document.applyParameterRefit(result)
        undoManager.endUndoGrouping()
        #expect(document.deck.learningOptions.parameters == .default)
        #expect(document.deck.learningOptions.lastAutoFit == nil)

        // Another device fitted later: its note stays.
        options.updatesParametersAutomatically = true
        options.lastAutoFit = LearningOptions.AutoFit(date: date.addingTimeInterval(60), reviewCount: 500, adopted: false)
        undoManager.beginUndoGrouping()
        document.updateLearningOptions(options)
        document.applyParameterRefit(result)
        undoManager.endUndoGrouping()
        #expect(document.deck.learningOptions == options)
    }
}

private enum Weights {
    /// Parameters other than the defaults, for a result to apply.
    static let fast: FSRSParameters = {
        var weights = FSRSParameters.default.weights
        weights[0] = 0.1
        return FSRSParameters(weights)!
    }()
}
