import SwiftUI
import VocabCore

/// What the day asks next and what it costs: an action and its minutes, "Keep your streak" and "2 min", with no days in it:
/// the streak has a line of its own (`StreakLine`, the flame and "12-day streak", in the same place and form all day). Pure:
/// the figures go in, the words come out, so every screen that says it says the same: Today, the rests, the stream's header
/// and the widgets.
///
/// The action is a call to the learner, an imperative with "your": the streak step not done, "Keep your streak"; the step
/// done, "Close your ring"; the day after a missed one, "Save your streak", whose minutes are the ring's, as closing it saves
/// the streak; the ring closed with cards left, "Finish your reviews"; nothing left, "All done for today"; without a streak,
/// "Start your streak". The price is the minutes of the next moment, "2 min" (`Format.timeLeft`), none without a price or
/// once nothing is left. Where there is room the action stands over its price (`NextStepText`, the moment's figure); on one
/// line they read "Keep your streak · 2 min" (`sentence`).
struct NextStep: Equatable, Sendable {
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

    /// The next moment as a call to action: "Keep your streak", "Close your ring", "Save your streak" (the day after a miss),
    /// "Finish your reviews" (the ring closed, cards left), "Start your streak" (no days); "All done for today" once nothing
    /// is left.
    var action: String {
        if isClosed { return reviewsLeft ? String(localized: "Finish your reviews") : String(localized: "All done for today") }
        guard days > 0 else { return String(localized: "Start your streak") }
        switch state {
        case .atRisk: return String(localized: "Save your streak")
        case .open: return String(localized: "Keep your streak")
        case .kept: return String(localized: "Close your ring")
        }
    }

    /// What the next moment costs, "2 min", "< 1 min"; `nil` without a price and once nothing is left.
    var price: String? { minutes.map(Format.timeLeft(minutes:)) }

    /// The next moment as a figure (`Figure`): the action over its price, "Keep your streak" over "2 min". Without a price the
    /// label is "Next" and the value the action; once nothing is left the label is "Today" and the value "All done".
    struct Moment: Equatable, Sendable {
        var label: String
        var value: String
    }

    /// The next moment as a figure: the action over its price; without one "Next" over the action.
    var moment: Moment {
        if isClosed && !reviewsLeft { return Moment(label: String(localized: "Today"), value: String(localized: "All done")) }
        return price.map { Moment(label: action, value: $0) } ?? Moment(label: String(localized: "Next"), value: action)
    }

    /// The action and its price on one line, "Keep your streak · 2 min"; the action alone without a price.
    var sentence: String { [action, price].compactMap { $0 }.joined(separator: " · ") }

    /// The price line of a rest, which has the streak and the moment in its title: "Close your ring · 4 min" while the ring is
    /// open, "Finish your reviews · 12 min" once it is closed; `nil` without a price.
    var priceLine: String? { price == nil ? nil : sentence }

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

    /// The short form for a line with room for little, after the flame: "7 · 2 min", "7 · Done" once nothing is left,
    /// without a price the action, "7 · Keep your streak". Without a streak the sentence.
    var short: String {
        guard days > 0 else { return sentence }
        let tail = price ?? (isClosed && !reviewsLeft ? String(localized: "Done") : action)
        return [days.formatted(.number.grouping(.never)), tail].joined(separator: " · ")
    }

    /// `text` where it must not break: the hyphen of "7-day" stays whole (a price never breaks: `Format.timeLeft`); with
    /// `endTogether`, the last two words too, so a line of text never ends on a line of one word.
    nonisolated static func unbroken(_ text: String, endTogether: Bool = false) -> String {
        let text = text.replacingOccurrences(of: "-", with: "\u{2011}")
        return endTogether ? text.replacingOccurrences(of: "(\\S+) (\\S+)$", with: "$1\u{00A0}$2", options: .regularExpression) : text
    }
}

/// The next moment where there is room for two lines: the action, wrapping at words, and under it its price in the ring's
/// indigo, as the moment's figure has it. The font, the alignment of the text and the number of lines are the caller's;
/// `alignment` places the two against each other. VoiceOver reads them as one line.
struct NextStepText: View {
    var step: NextStep
    var alignment: HorizontalAlignment = .center

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(verbatim: NextStep.unbroken(step.action, endTogether: true))
            if let price = step.price {
                Text(verbatim: price)
                    .foregroundStyle(Color.appAccentText)
            }
        }
        .accessibilityElement(children: .ignore)
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
