import Foundation

/// When the app fits a deck's FSRS parameters to its review log again by itself, and when
/// it keeps the fit. The learner gets the parameters of the optimizer without opening the
/// options, and never worse ones: a fit that doesn't predict the reviews clearly better
/// than the parameters the deck has is thrown away, and only the attempt is noted
/// (`LearningOptions.lastAutoFit`).
///
/// Pure: the apps decide where and when to call `fit(cards:options:calendar:now:)`, which
/// is the heavy part, and apply its `Result` through the document.
public enum ParameterRefit {
    /// Usable reviews a deck needs before the first fit: the optimizer's own minimum, which
    /// the options screens show.
    public static let minimumReviewCount = FSRSOptimizer.minimumReviewCount
    /// Days after which a deck is fitted again, whatever its reviews.
    public static let intervalDays = 30
    /// New usable reviews after which a deck is fitted again, whatever the date.
    public static let reviewStep = 1000
    /// By how much, relative to the log loss of the current parameters, the fitted ones
    /// must be lower to be kept.
    public static let requiredImprovement = 0.01

    /// Whether a deck with `reviewCount` usable reviews is due for a fit at `now`: it has
    /// the minimum, and since the last automatic fit `intervalDays` days or `reviewStep`
    /// reviews have passed, whichever comes first. A deck never fitted is due at once.
    public static func isDue(reviewCount: Int, lastFit: LearningOptions.AutoFit?, at now: Date) -> Bool {
        guard reviewCount >= minimumReviewCount else { return false }
        guard let lastFit else { return true }
        let days = now.timeIntervalSince(lastFit.date) / 86400
        return days >= Double(intervalDays) || reviewCount - lastFit.reviewCount >= reviewStep
    }

    /// Whether to keep fitted parameters: their log loss is lower than the current one by
    /// at least `requiredImprovement`, relative to it.
    public static func keeps(_ comparison: FSRSOptimizer.Comparison) -> Bool {
        comparison.computed.logLoss <= comparison.current.logLoss * (1 - requiredImprovement)
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
            let comparison = try optimizer.compare(with: options.parameters)
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
