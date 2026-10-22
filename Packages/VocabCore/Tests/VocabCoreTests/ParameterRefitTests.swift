import Foundation
import Testing

@testable import VocabCore

struct ParameterRefitTests {
    let calendar = StudyCalendar(timeZone: TimeZone(identifier: "UTC")!)
    let now = Date(timeIntervalSince1970: 1_791_216_000)

    func fit(daysAgo: Double = 0, count: Int, adopted: Bool = true) -> LearningOptions.AutoFit {
        LearningOptions.AutoFit(date: now.addingTimeInterval(-daysAgo * 86400), reviewCount: count, adopted: adopted)
    }

    /// A learner who forgets fast and along a steep curve. Next to the defaults the fit gains
    /// about 4 % of log loss on its reviews; `SyntheticLearner.unusual` gains less than 1 %, which
    /// the 1 % rule keeps out.
    static let forgetful: FSRSParameters = {
        var w = SyntheticLearner.unusual.weights
        w[0] = 0.1
        w[1] = 0.3
        w[2] = 1
        w[3] = 4
        w[20] = 0.75
        return FSRSParameters(w)!
    }()

    /// The cards of that learner: about 3,600 usable reviews.
    func cards(count: Int = 300, seed: UInt64 = 6) -> [Card] {
        var learner = SyntheticLearner(parameters: Self.forgetful, seed: seed)
        return learner.histories(cards: count, days: 365).enumerated().map { $1.card(index: $0, calendar: calendar) }
    }

    // MARK: - When a deck is due

    @Test func aDeckNeedsTheOptimizersMinimumOfReviews() {
        #expect(ParameterRefit.minimumReviewCount == FSRSOptimizer.minimumReviewCount)
        let minimum = ParameterRefit.minimumReviewCount
        #expect(!ParameterRefit.isDue(reviewCount: minimum - 1, lastFit: nil, at: now))
        #expect(ParameterRefit.isDue(reviewCount: minimum, lastFit: nil, at: now))
        // Time and new reviews don't make up for the missing ones.
        #expect(!ParameterRefit.isDue(reviewCount: minimum - 1, lastFit: fit(daysAgo: 400, count: 0), at: now))
    }

    @Test func aFittedDeckWaitsThirtyDaysOrAThousandReviews() {
        let last = fit(daysAgo: 29.9, count: 500)
        #expect(!ParameterRefit.isDue(reviewCount: 1499, lastFit: last, at: now))
        #expect(ParameterRefit.isDue(reviewCount: 1500, lastFit: last, at: now))

        #expect(ParameterRefit.isDue(reviewCount: 500, lastFit: fit(daysAgo: 30, count: 500), at: now))
        #expect(!ParameterRefit.isDue(reviewCount: 500, lastFit: fit(daysAgo: 29.99, count: 500), at: now))
    }

    /// Whichever comes first, and an attempt that kept the parameters counts like a fit.
    @Test func eitherConditionAloneDuesTheDeckAndAKeptAttemptStartsTheWaitAnew() {
        let kept = fit(daysAgo: 1, count: 800, adopted: false)
        #expect(!ParameterRefit.isDue(reviewCount: 1000, lastFit: kept, at: now))
        #expect(ParameterRefit.isDue(reviewCount: 1800, lastFit: kept, at: now))
        #expect(ParameterRefit.isDue(reviewCount: 800, lastFit: fit(daysAgo: 31, count: 800, adopted: false), at: now))
    }

    @Test func aClockThatWentBackwardsAndFewerReviewsThanBeforeWaitForTheOtherCondition() {
        let future = LearningOptions.AutoFit(date: now.addingTimeInterval(86400), reviewCount: 900, adopted: true)
        #expect(!ParameterRefit.isDue(reviewCount: 900, lastFit: future, at: now))
        // The learner switched off "Learn from revealed reviews": fewer usable reviews than at the last fit.
        #expect(!ParameterRefit.isDue(reviewCount: 450, lastFit: fit(daysAgo: 2, count: 900), at: now))
    }

    // MARK: - Keeping the fit

    func comparison(current: Double, computed: Double) -> FSRSOptimizer.Comparison {
        FSRSOptimizer.Comparison(
            parameters: .default,
            current: .init(logLoss: current, rmse: 0.05),
            computed: .init(logLoss: computed, rmse: 0.05))
    }

    @Test func aFitIsKeptOnlyWhenOnePercentLower() {
        #expect(ParameterRefit.requiredImprovement == 0.01)
        #expect(ParameterRefit.keeps(comparison(current: 0.5, computed: 0.4949)))
        #expect(ParameterRefit.keeps(comparison(current: 0.5, computed: 0.3)))
        #expect(!ParameterRefit.keeps(comparison(current: 0.5, computed: 0.4951)))
        #expect(!ParameterRefit.keeps(comparison(current: 0.5, computed: 0.5)))
        #expect(!ParameterRefit.keeps(comparison(current: 0.5, computed: 0.52)))
        #expect(!ParameterRefit.keeps(comparison(current: 0.5, computed: .nan)))
    }

    // MARK: - Fitting

    @Test func aDeckThatIsNotDueIsNotFitted() throws {
        let cards = cards()
        var options = LearningOptions()
        let result = try #require(try ParameterRefit.fit(cards: cards, options: options, calendar: calendar, now: now))

        options.updatesParametersAutomatically = false
        #expect(try ParameterRefit.fit(cards: cards, options: options, calendar: calendar, now: now) == nil)

        options.updatesParametersAutomatically = true
        options.lastAutoFit = fit(daysAgo: 1, count: result.fit.reviewCount - 10)
        #expect(try ParameterRefit.fit(cards: cards, options: options, calendar: calendar, now: now) == nil)
        #expect(try ParameterRefit.fit(cards: Array(cards.prefix(3)), options: LearningOptions(), calendar: calendar, now: now) == nil)
    }

    @Test func aBetterFitIsKeptAndANoBetterOneIsOnlyRecorded() throws {
        let cards = cards()
        var options = LearningOptions()
        let first = try #require(try ParameterRefit.fit(cards: cards, options: options, calendar: calendar, now: now))
        let fitted = try #require(first.parameters)
        #expect(fitted != .default)
        #expect(first.fit == LearningOptions.AutoFit(date: now, reviewCount: first.fit.reviewCount, adopted: true))
        #expect(first.fit.reviewCount == FSRSOptimizer(cards: cards, learningOptions: options, calendar: calendar).reviewCount)

        // The deck has the fitted parameters now; a fit a month later finds the same ones, which
        // are no better than themselves.
        options = first.applied(to: options)
        #expect(options.parameters == fitted)
        let later = now.addingTimeInterval(31 * 86400)
        let second = try #require(try ParameterRefit.fit(cards: cards, options: options, calendar: calendar, now: later))
        #expect(second.parameters == nil)
        #expect(second.fit == LearningOptions.AutoFit(date: later, reviewCount: first.fit.reviewCount, adopted: false))
        let kept = second.applied(to: options)
        #expect(kept.parameters == fitted)
        #expect(kept.lastAutoFit == second.fit)
    }

    @Test func theDateOfAFitIsInWholeSeconds() throws {
        let result = try #require(try ParameterRefit.fit(cards: cards(), options: LearningOptions(), calendar: calendar, now: now.addingTimeInterval(0.75)))
        #expect(result.fit.date == now)
    }

    @Test func aFitCanBeCancelled() async throws {
        let cards = cards()
        let calendar = calendar
        let now = now
        let task = Task { try ParameterRefit.fit(cards: cards, options: LearningOptions(), calendar: calendar, now: now) }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    /// A deck the optimizer finds nothing in is an attempt too, or it would be tried at every launch:
    /// here every first interval is shared by five cards, too few for the outlier filter, which
    /// leaves nothing to train on, and the result is the default parameters.
    @Test func aDeckWithNothingToFitIsRecordedAsKept() throws {
        let start = calendar.start(ofDay: 20_000)
        let cards = (0..<250).map { index -> Card in
            let days = [0, 1 + index % 50, 3 + index % 50]
            let log = days.map { ReviewLogEntry(date: start.addingTimeInterval(Double($0) * 86400 + Double(index)), grade: .good) }
            let state = LearningState(phase: .review, stability: 3, difficulty: 5, lastReview: log[2].date, due: log[2].date, reviews: 3)
            return Card(question: "q\(index)", answer: "a", learningState: state, log: log)
        }
        let result = try #require(try ParameterRefit.fit(cards: cards, options: LearningOptions(), calendar: calendar, now: now))
        #expect(result.parameters == nil)
        #expect(result.fit == LearningOptions.AutoFit(date: now, reviewCount: 500, adopted: false))
    }

    @Test func aResultChangesOnlyTheParametersAndTheRecord() {
        var options = LearningOptions()
        options.targetRecall = 0.85
        let fitted = SyntheticLearner.unusual
        let record = fit(count: 700)

        let adopted = ParameterRefit.Result(parameters: fitted, fit: record).applied(to: options)
        var expected = options
        expected.parameters = fitted
        expected.lastAutoFit = record
        #expect(adopted == expected)

        let kept = ParameterRefit.Result(parameters: nil, fit: fit(count: 700, adopted: false)).applied(to: options)
        #expect(kept.parameters == options.parameters)
        #expect(kept.lastAutoFit?.adopted == false)
        #expect(kept.targetRecall == 0.85)
    }

    // MARK: - Applied to a deck

    /// The whole way for a learner who never opens the options: a history, the fit, the change
    /// the document applies, and the change that undoes it.
    @Test func aFitOfASyntheticLearnerIsAppliedToTheDeckAndUndone() throws {
        var deck = try Deck(cards: cards())
        let original = deck

        let result = try #require(try ParameterRefit.fit(cards: deck.cards, options: deck.learningOptions, calendar: calendar, now: now))
        let change = try #require(DeckChange.changingLearningOptions(result.applied(to: deck.learningOptions), in: deck, calendar: calendar))
        let inverse = deck.apply(change, at: now, calendar: calendar)

        #expect(deck.learningOptions.parameters == result.parameters)
        #expect(deck.learningOptions.parameters != .default)
        #expect(deck.learningOptions.lastAutoFit == result.fit)
        #expect(deck.learningOptions.lastAutoFit?.adopted == true)
        #expect(deck.learningOptionsChanged == now)
        // Stability and difficulty of the cards follow the new parameters, their due dates stay.
        #expect(deck.cards.map(\.learningState?.stability) != original.cards.map(\.learningState?.stability))
        #expect(deck.cards.map(\.learningState?.due) == original.cards.map(\.learningState?.due))
        // The deck now has the better fit, and is not due again.
        let optimizer = FSRSOptimizer(cards: deck.cards, learningOptions: deck.learningOptions, calendar: calendar)
        let after = try #require(optimizer.evaluate(deck.learningOptions.parameters))
        let before = try #require(optimizer.evaluate(.default))
        #expect(after.logLoss < before.logLoss * 0.99)
        #expect(try ParameterRefit.fit(cards: deck.cards, options: deck.learningOptions, calendar: calendar, now: now) == nil)

        _ = deck.apply(inverse, at: now, calendar: calendar)
        #expect(deck.learningOptions == original.learningOptions)
        #expect(deck.cards == original.cards)
    }
}
