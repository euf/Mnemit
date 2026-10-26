import SwiftUI
import VocabCore

/// What the day asks next and what it costs, in one sentence that says the next moment of the day and its minutes, led by
/// the flame (`flame`, the state by shape). Pure: the figures go in, the flame and the words come out, so every screen that
/// says it says the same: Today, the rests, the stream's header, the widgets and the reminders.
///
/// The sentence by moment: the streak step not done, "≈ 2 min to keep your 12-day streak" (without a streak "Start your
/// streak · ≈ 2 min"); the step done, the ring open, "12-day streak · ≈ 5 min to close the ring"; the ring closed with
/// cards left, "Ring closed · ≈ 12 min of reviews left"; nothing left, "All done for today"; the day after a missed one
/// "≈ 6 min to close the ring and save your 12-day streak". Without a price (`nil` minutes) the time is left out and the
/// streak stays.
///
/// The sentence has two parts where it has a streak line and a price line (`lines`): a screen that has to wrap it breaks
/// between them, never inside one and never at the " · ".
struct NextStep: Equatable, Sendable {
    /// The sentence as the lines it breaks into: the streak line and the price line.
    struct Lines: Equatable, Sendable {
        var lead: String
        var tail: String?

        /// One line, " · " between the parts.
        var joined: String { [lead, tail].compactMap { $0 }.joined(separator: " · ") }
    }

    /// The streak in days.
    var days: Int
    /// The streak's state (`StreakState`): `open` while today's streak step is not done, `kept` once it is, `atRisk` the day
    /// after a missed one until the ring closes.
    var state: StreakState
    /// The ring is closed: no cards left that close it.
    var isClosed: Bool
    /// The minutes to the end of the first round, the streak step (`DailyProgress.minutesToStreak`); `nil` without a price or
    /// once the step is done.
    var minutesToKeep: Int?
    /// The minutes the cards that close the ring take (`DailyProgress.minutesToRing`); `nil` without a price. Not read once the
    /// ring is closed.
    var minutesToClose: Int?
    /// The ring is closed and cards of the plan are left: what Catch Up studies.
    var reviewsLeft: Bool
    /// The minutes of those cards (`DailyProgress.minutesOfDueAfterRing`); `nil` without a price. Not read before the ring is closed.
    var minutesOfReviews: Int?

    /// The same from the day's figures.
    init(_ progress: DailyProgress) {
        self.init(
            progress, minutesToKeep: progress.minutesToStreak, minutesToClose: progress.minutesToRing,
            minutesOfReviews: progress.minutesOfDueAfterRing ?? progress.minutesLeft)
    }

    /// The same with other prices: the widget, which has the cards of the plan and one price for them.
    init(_ progress: DailyProgress, minutesToKeep: Int?, minutesToClose: Int?, minutesOfReviews: Int?) {
        self.init(
            days: progress.streak.days, state: progress.streakState, isClosed: progress.cardsToClose == 0, minutesToKeep: minutesToKeep,
            minutesToClose: minutesToClose, reviewsLeft: progress.cardsLeft > 0, minutesOfReviews: minutesOfReviews)
    }

    init(
        days: Int, state: StreakState, isClosed: Bool, minutesToKeep: Int? = nil, minutesToClose: Int? = nil, reviewsLeft: Bool = false,
        minutesOfReviews: Int? = nil
    ) {
        self.days = days
        self.state = state
        self.isClosed = isClosed
        self.minutesToKeep = minutesToKeep
        self.minutesToClose = minutesToClose
        self.reviewsLeft = reviewsLeft
        self.minutesOfReviews = minutesOfReviews
    }

    /// The flame to draw before the sentence; `nil` where there is no streak and nothing left to do.
    var flame: StreakState? { days == 0 && isClosed && !reviewsLeft ? nil : state }

    /// The minutes of the next moment: to the streak mark while the step is open, to the ring after it and at risk, of the
    /// cards that stay after the ring once it is closed; `nil` when nothing is left, and without a price.
    var minutes: Int? {
        if isClosed { return reviewsLeft ? minutesOfReviews : nil }
        return state == .open ? minutesToKeep : minutesToClose
    }

    /// The sentence in its two parts.
    var lines: Lines { lines(spoken: false) }

    /// The sentence, "≈ 2 min to keep your 7-day streak", on one line.
    var sentence: String { lines.joined }

    /// What VoiceOver reads: the sentence, with the state added to the streak where the sentence does not say it.
    var spoken: String { lines(spoken: true).joined }

    private func lines(spoken: Bool) -> Lines {
        let time = { (minutes: Int) in Format.timeLeft(minutes: minutes) }
        if isClosed {
            guard reviewsLeft else { return Lines(lead: String(localized: "All done for today")) }
            return Lines(lead: String(localized: "Ring closed"), tail: minutesOfReviews.map { String(localized: "\(time($0)) of reviews left") })
        }
        guard days > 0 else { return Lines(lead: String(localized: "Start your streak"), tail: minutesToKeep.map(time)) }
        switch state {
        case .atRisk:
            guard let minutes = minutesToClose else { return Lines(lead: String(localized: "Close the ring to save your \(days)-day streak")) }
            return Lines(lead: String(localized: "\(time(minutes)) to close the ring and save your \(days)-day streak"))
        case .open:
            guard let minutes = minutesToKeep else {
                return Lines(lead: spoken ? String(localized: "\(days)-day streak, not kept yet") : String(localized: "\(days)-day streak"))
            }
            return Lines(lead: String(localized: "\(time(minutes)) to keep your \(days)-day streak"))
        case .kept:
            return Lines(
                lead: spoken ? String(localized: "\(days)-day streak, kept today") : String(localized: "\(days)-day streak"),
                tail: minutesToClose.map { String(localized: "\(time($0)) to close the ring") })
        }
    }

    /// The short form for a line with room for little, after the flame: "7 · ≈ 2 min", "7 · Done" once nothing is left,
    /// the days alone without a price. Without a streak the sentence.
    var short: String {
        guard days > 0 else { return sentence }
        let tail = minutes.map(Format.timeLeft(minutes:)) ?? (isClosed && !reviewsLeft ? String(localized: "Done") : nil)
        return [days.formatted(.number.grouping(.never)), tail].compactMap { $0 }.joined(separator: " · ")
    }

    /// `text` where it must not break: the hyphen of "7-day" and the spaces of "≈ 2 min" stay whole.
    nonisolated static func unbroken(_ text: String) -> String {
        text.replacingOccurrences(of: "-", with: "\u{2011}")
            .replacingOccurrences(of: "([≈<]) (\\d+) (\\S+)", with: "$1\u{00A0}$2\u{00A0}$3", options: .regularExpression)
            .replacingOccurrences(of: "< 1 min", with: "<\u{00A0}1\u{00A0}min")
    }
}

/// The words of the sentence (`NextStep`): on one line when they fit, else broken between the streak line and the price line,
/// the second under the first. The font, the alignment of the text and the number of lines are the caller's; `alignment` places
/// the two lines against each other.
struct NextStepText: View {
    var step: NextStep
    var alignment: HorizontalAlignment = .center

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Text(verbatim: NextStep.unbroken(step.sentence))
                .lineLimit(1)
            if let tail = step.lines.tail {
                VStack(alignment: alignment, spacing: 0) {
                    Text(verbatim: NextStep.unbroken(step.lines.lead))
                    Text(verbatim: NextStep.unbroken(tail))
                }
            }
            Text(verbatim: NextStep.unbroken(step.sentence))
        }
        .accessibilityLabel(Text(verbatim: step.spoken))
    }
}

/// The sentence led by the flame, which is filled once today keeps the streak and carries an exclamation mark the day after a
/// missed one: Today and the rests. The widgets draw the flame themselves, as they mark it accentable.
struct StreakSentence: View {
    var step: NextStep
    var alignment: HorizontalAlignment = .center

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if let flame = step.flame {
                StreakFlame(state: flame)
            }
            NextStepText(step: step, alignment: alignment)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: step.spoken))
    }
}
