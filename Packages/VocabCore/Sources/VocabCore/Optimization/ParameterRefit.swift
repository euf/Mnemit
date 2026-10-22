import Foundation

/// When the app fits a deck's FSRS parameters to its review log again by itself, and when
/// it keeps the fit. The learner gets the parameters of the optimizer without opening the
/// options, and never worse ones: the fit is trained on the older 80 % of the log and has to
/// beat the parameters the deck has on the newest 20 %, which it never saw. A fit that doesn't
/// is thrown away, and only the attempt is noted (`LearningOptions.lastAutoFit`).
///
/// Pure: the apps decide where and when to call `fit(cards:options:calendar:now:)`, which
/// is the heavy part, and apply its `Result` through the document.
public enum ParameterRefit {
    /// Usable reviews a deck needs for the first fit: the optimizer's own minimum, which the
    /// options screens show.
    public static let minimumReviewCount = FSRSOptimizer.minimumReviewCount
    /// Usable reviews at which a deck first fitted below it is fitted for the second time.
    /// Measured gains of fitted over default parameters grow with the log: about 0.004 log
    /// loss up to 1,500 reviews, 0.014 up to 10,000.
    public static let secondFitReviewCount = 1500
    /// From then on a deck waits this many days after its last fit, at the most ...
    public static let intervalDays = 30
    /// ... or this many new usable reviews, whichever comes first.
    public static let reviewStep = 1000
    /// The share of the log, the newest reviews by time, that the fit is judged on.
    public static let holdoutShare = 0.2
    /// By how much, relative to the log loss of the current parameters on those reviews, the
    /// fitted ones must be lower to be kept.
    public static let requiredImprovement = 0.0

    /// Whether a deck with `reviewCount` usable reviews is due for a fit at `now`.
    ///
    /// The first fit comes at `minimumReviewCount`, the second at `secondFitReviewCount`.
    /// A deck last fitted at or after that count is due once `intervalDays` days or
    /// `reviewStep` reviews have passed since, whichever comes first. A deck that was never
    /// fitted is due at once, wherever its count stands, so one that arrives with 3,000
    /// reviews gets one fit and then the monthly rhythm.
    public static func isDue(reviewCount: Int, lastFit: LearningOptions.AutoFit?, at now: Date) -> Bool {
        guard reviewCount >= minimumReviewCount else { return false }
        guard let lastFit else { return true }
        if lastFit.reviewCount < secondFitReviewCount {
            return reviewCount >= secondFitReviewCount
        }
        let days = now.timeIntervalSince(lastFit.date) / 86400
        return days >= Double(intervalDays) || reviewCount - lastFit.reviewCount >= reviewStep
    }

    /// Whether to keep fitted parameters: their log loss on the newest reviews is lower than
    /// that of the current ones by at least `requiredImprovement`, relative to it.
    public static func keeps(_ comparison: FSRSOptimizer.Comparison) -> Bool {
        comparison.computed.logLoss < comparison.current.logLoss * (1 - requiredImprovement)
    }

    /// What a fit found, to apply to the learning options of the deck as they are then.
    public struct Result: Hashable, Sendable {
        /// The fitted parameters, `nil` when they are not kept.
        public var parameters: FSRSParameters?
        public var fit: LearningOptions.AutoFit

        /// `options` with the attempt noted, and the parameters replaced if they are kept.
        public func applied(to options: LearningOptions) -> LearningOptions {
            var options = options
            if let parameters { options.parameters = parameters }
            options.lastAutoFit = fit
            return options
        }
    }

    /// Fits the deck again if it is due and the learner has not turned the update off;
    /// `nil` if it is not. Runs the optimizer, so call it off the main actor, at low
    /// priority.
    ///
    /// An optimizer that finds nothing to fit counts as an attempt that kept the parameters,
    /// or a deck like that would be tried again at every launch.
    ///
    /// - Throws: `CancellationError`, checked between the batches of the optimizer.
    public static func fit(cards: [Card], options: LearningOptions, calendar: StudyCalendar, now: Date) throws -> Result? {
        guard options.updatesParametersAutomatically else { return nil }
        let optimizer = FSRSOptimizer(cards: cards, learningOptions: options, calendar: calendar)
        let reviewCount = optimizer.reviewCount
        guard isDue(reviewCount: reviewCount, lastFit: options.lastAutoFit, at: now) else { return nil }

        let date = Date(timeIntervalSince1970: now.timeIntervalSince1970.rounded(.down))
        do {
            let comparison = try optimizer.compareOnNewest(share: holdoutShare, with: options.parameters)
            let adopted = keeps(comparison)
            return Result(
                parameters: adopted ? comparison.parameters : nil,
                fit: LearningOptions.AutoFit(date: date, reviewCount: reviewCount, adopted: adopted))
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return Result(parameters: nil, fit: LearningOptions.AutoFit(date: date, reviewCount: reviewCount, adopted: false))
        }
    }
}
