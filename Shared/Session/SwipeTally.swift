import Foundation
import VocabCore

/// How many swipes of a study day sprang back from a gap, of all that tried to grade: the count
/// "How Today Works" shows, so a sector that is too narrow for a thumb shows up as a number.
///
/// A swipe is counted when it is let go and went `GradeSwipe.commitDistance` or was a flick: it
/// either gave a grade (`graded`) or sprang back from a gap (`gapMisses`), `GradeSwipe.endedInGap`.
/// A drag that ends short of the commit distance and without a flick tried nothing and isn't counted.
/// Kept in memory and for one study day (`StudyCalendar`, 04:00 rollover): a new day, or a new
/// launch, starts at zero. The study screen calls `released(translation:predictedEnd:)` where it
/// would call `GradeSwipe.released`.
@MainActor
final class SwipeTally {
    static let shared = SwipeTally()

    /// The swipes of one study day.
    struct Counts: Equatable, Sendable {
        /// Swipes that gave a grade.
        var graded = 0
        /// Swipes that sprang back from a gap.
        var gapMisses = 0
        /// All swipes that reached the commit distance or flicked.
        var total: Int { graded + gapMisses }
    }

    private var day: Int?
    private var counted = Counts()

    /// What `GradeSwipe.released` says for this release, counted at `now`.
    func released(
        translation: CGSize, predictedEnd: CGSize, at now: Date = .now, calendar: StudyCalendar = StudyCalendar()
    ) -> Grade? {
        let grade = GradeSwipe.released(translation: translation, predictedEnd: predictedEnd)
        let today = calendar.dayNumber(for: now)
        if day != today {
            day = today
            counted = Counts()
        }
        if grade != nil {
            counted.graded += 1
        } else if GradeSwipe.endedInGap(translation: translation, predictedEnd: predictedEnd) {
            counted.gapMisses += 1
        }
        return grade
    }

    /// The swipes of the study day that holds `now`.
    func counts(at now: Date = .now, calendar: StudyCalendar = StudyCalendar()) -> Counts {
        day == calendar.dayNumber(for: now) ? counted : Counts()
    }
}
