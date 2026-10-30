import SwiftUI
import VocabCore

/// What the day asks next and what it costs, in one sentence that says the next moment of the day and its minutes, with no
/// days in it: the streak has a line of its own (`StreakLine`, the flame and "12-day streak", in the same place and form all
/// day). Pure: the figures go in, the words come out, so every screen that says it says the same: Today, the rests, the
/// stream's header and the widgets.
///
/// The sentence by moment: the streak step not done, "≈ 2 min to keep your streak" (without a price "Keep your streak"); the
/// step done, "≈ 5 min to close the ring" ("Close the ring"); the day after a missed one "≈ 6 min to close the ring and save
/// your streak" ("Close the ring to save your streak"); the ring closed with cards left, "Ring closed · ≈ 12 min of reviews
/// left"; nothing left, "All done for today"; without a streak "≈ 2 min to start your streak" ("Start your streak").
///
/// The sentence has two parts only where the ring is closed with cards left (`lines`): a screen that has to wrap it breaks
/// between them, never inside one and never at the " · ".
struct NextStep: Equatable, Sendable {
    /// The sentence as the lines it breaks into: the moment and, once the ring is closed, the price of the reviews left.
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

    /// The minutes of the next moment: to the streak mark while the step is open, to the ring after it and at risk, of the
    /// cards that stay after the ring once it is closed; `nil` when nothing is left, and without a price.
    var minutes: Int? {
        if isClosed { return reviewsLeft ? minutesOfReviews : nil }
        return state == .open ? minutesToKeep : minutesToClose
    }

    /// The sentence in its parts: one, or the two of "Ring closed · ≈ 12 min of reviews left".
    var lines: Lines {
        let time = { (minutes: Int) in Format.timeLeft(minutes: minutes) }
        if isClosed {
            guard reviewsLeft else { return Lines(lead: String(localized: "All done for today")) }
            return Lines(lead: String(localized: "Ring closed"), tail: minutesOfReviews.map { String(localized: "\(time($0)) of reviews left") })
        }
        guard days > 0 else {
            guard let minutes = minutesToKeep else { return Lines(lead: String(localized: "Start your streak")) }
            return Lines(lead: String(localized: "\(time(minutes)) to start your streak"))
        }
        switch state {
        case .atRisk:
            guard let minutes = minutesToClose else { return Lines(lead: String(localized: "Close the ring to save your streak")) }
            return Lines(lead: String(localized: "\(time(minutes)) to close the ring and save your streak"))
        case .open:
            guard let minutes = minutesToKeep else { return Lines(lead: String(localized: "Keep your streak")) }
            return Lines(lead: String(localized: "\(time(minutes)) to keep your streak"))
        case .kept:
            guard let minutes = minutesToClose else { return Lines(lead: String(localized: "Close the ring")) }
            return Lines(lead: String(localized: "\(time(minutes)) to close the ring"))
        }
    }

    /// The next moment as a figure (`Figure`): the label names the moment, the value is its minutes, "To keep your streak" over
    /// "≈ 2 min". Without a price the label is "Next" and the value the moment in words, "Keep your streak"; once nothing is left
    /// the label is "Today" and the value "All done".
    struct Moment: Equatable, Sendable {
        var label: String
        var value: String
    }

    /// The next moment as a figure: "To keep your streak", "To close the ring", "To save your streak" (the day after a miss), "Reviews
    /// left" (the ring closed, cards left), "To start your streak" (no days), each over its `minutes`; without them "Next" over
    /// "Keep your streak", "Close the ring", "Save your streak", "Keep Going", "Start your streak".
    var moment: Moment {
        let price = minutes.map { Format.timeLeft(minutes: $0) }
        func figure(_ label: String, or words: String) -> Moment {
            price.map { Moment(label: label, value: $0) } ?? Moment(label: String(localized: "Next"), value: words)
        }
        if isClosed {
            guard reviewsLeft else { return Moment(label: String(localized: "Today"), value: String(localized: "All done")) }
            return figure(String(localized: "Reviews left"), or: String(localized: "Keep Going"))
        }
        guard days > 0 else { return figure(String(localized: "To start your streak"), or: String(localized: "Start your streak")) }
        switch state {
        case .atRisk: return figure(String(localized: "To save your streak"), or: String(localized: "Save your streak"))
        case .open: return figure(String(localized: "To keep your streak"), or: String(localized: "Keep your streak"))
        case .kept: return figure(String(localized: "To close the ring"), or: String(localized: "Close the ring"))
        }
    }

    /// The sentence, "≈ 2 min to keep your streak", on one line.
    var sentence: String { lines.joined }

    /// The price line of a rest, which has the streak and the moment in its title: "≈ 4 min to close the ring" while the ring
    /// is open, "≈ 12 min of reviews left" once it is closed; `nil` without a price.
    var priceLine: String? { isClosed ? lines.tail : minutes == nil ? nil : sentence }

    /// "12-day streak": the words of the streak line.
    var streakText: String { String(localized: "\(days)-day streak") }

    /// What VoiceOver reads for the streak line: the days and the state, which the flame's shape shows.
    var streakSpoken: String {
        switch state {
        case .open: String(localized: "\(days)-day streak, not kept yet")
        case .kept: String(localized: "\(days)-day streak, kept today")
        case .atRisk: String(localized: "\(days)-day streak, at risk")
        }
    }

    /// What VoiceOver reads for the streak and the sentence together, as a widget does.
    var spoken: String { days > 0 ? [streakSpoken, sentence].joined(separator: " · ") : sentence }

    /// The short form for a line with room for little, after the flame: "7 · ≈ 2 min", "7 · Done" once nothing is left,
    /// without a price the moment in words, "7 · Keep your streak". Without a streak the sentence.
    var short: String {
        guard days > 0 else { return sentence }
        let tail = minutes.map(Format.timeLeft(minutes:)) ?? (isClosed && !reviewsLeft ? String(localized: "Done") : moment.value)
        return [days.formatted(.number.grouping(.never)), tail].compactMap { $0 }.joined(separator: " · ")
    }

    /// `text` where it must not break: the hyphen of "7-day" and the spaces of "≈ 2 min" stay whole; with `endTogether`, the last
    /// two words too, so a sentence never ends on a line of one word.
    nonisolated static func unbroken(_ text: String, endTogether: Bool = false) -> String {
        let text = text.replacingOccurrences(of: "-", with: "\u{2011}")
            .replacingOccurrences(of: "([≈<]) (\\d+) (\\S+)", with: "$1\u{00A0}$2\u{00A0}$3", options: .regularExpression)
            .replacingOccurrences(of: "< 1 min", with: "<\u{00A0}1\u{00A0}min")
        return endTogether ? text.replacingOccurrences(of: "(\\S+) (\\S+)$", with: "$1\u{00A0}$2", options: .regularExpression) : text
    }
}

/// The words of the sentence (`NextStep`): on one line when they fit, else broken between its two parts where it has two, the
/// second under the first, each wrapping by itself if it must. The font, the alignment of the text and the number of lines are
/// the caller's; `alignment` places the two parts against each other.
struct NextStepText: View {
    var step: NextStep
    var alignment: HorizontalAlignment = .center

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Text(verbatim: NextStep.unbroken(step.sentence, endTogether: true))
                .lineLimit(1)
            // Each part wraps by itself in a narrow place (the small widget), so no line ends on the dot between them.
            VStack(alignment: alignment, spacing: 0) {
                Text(verbatim: NextStep.unbroken(step.lines.lead, endTogether: true))
                if let tail = step.lines.tail { Text(verbatim: NextStep.unbroken(tail, endTogether: true)) }
            }
        }
        .accessibilityLabel(Text(verbatim: step.sentence))
    }
}

/// The streak's line: the flame by its state (an outline until today's step is done, filled once it is, an outline with "!"
/// the day after a miss) and "12-day streak", in the same place and form all day. Nothing without a streak. The text is the
/// headline's unless the caller gives a font. The widgets draw the flame themselves, as they mark it accentable.
struct StreakLine: View {
    var step: NextStep
    var font: Font = .headline

    var body: some View {
        if step.days > 0 {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                StreakFlame(state: step.state)
                Text(verbatim: NextStep.unbroken(step.streakText))
            }
            .font(font)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: step.streakSpoken))
        }
    }
}
