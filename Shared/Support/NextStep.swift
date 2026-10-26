import Foundation
import VocabCore

/// What the day asks next and what it costs, in one sentence that carries the streak and the price of the next step, led by
/// the flame (`flame`, the state by shape). Pure: the figures go in, the flame and the words come out, so every screen that
/// says it says the same. The widgets use it first.
///
/// The sentence by state: the streak step not done, "≈ 2 min to keep your 7-day streak" (without a streak "Start your
/// streak · ≈ 2 min"); the step done, the ring open, "7-day streak · ≈ 5 min left"; the ring closed, "7-day streak · Done
/// for today"; the day after a missed one "Close the ring to save your 7-day streak". Without a price (`nil` minutes) the
/// time is left out and the streak stays.
struct NextStep: Equatable, Sendable {
    /// The streak in days.
    var days: Int
    /// The streak's state (`StreakState`): `open` while today's streak step is not done, `kept` once it is, `atRisk` the day
    /// after a missed one until the ring closes.
    var state: StreakState
    /// The ring is closed: no cards left that close it.
    var isClosed: Bool
    /// The minutes to the end of the first round, the streak step (`RoundStatus.minutesToKeep`); `nil` without a price or once
    /// the step is done.
    var minutesToKeep: Int?
    /// The minutes the cards that close the ring take (`DailyGoal.minutesLeft`); `nil` without a price. Not read once the ring
    /// is closed.
    var minutesToClose: Int?

    /// The same from the day's figures: the streak and its state, and whether the ring is closed.
    init(_ progress: DailyProgress, minutesToKeep: Int?, minutesToClose: Int?) {
        self.init(
            days: progress.streak.days, state: progress.streakState, isClosed: progress.cardsToClose == 0, minutesToKeep: minutesToKeep,
            minutesToClose: minutesToClose)
    }

    init(days: Int, state: StreakState, isClosed: Bool, minutesToKeep: Int?, minutesToClose: Int?) {
        self.days = days
        self.state = state
        self.isClosed = isClosed
        self.minutesToKeep = minutesToKeep
        self.minutesToClose = minutesToClose
    }

    /// The flame to draw before the sentence; `nil` where there is no streak and nothing left to do.
    var flame: StreakState? { days == 0 && isClosed ? nil : state }

    /// The minutes of the next step: the first round's while the streak step is open, the ring's after it and at risk;
    /// `nil` once the ring is closed, and without a price.
    var minutes: Int? {
        guard !isClosed else { return nil }
        return state == .open ? minutesToKeep : minutesToClose
    }

    /// The sentence, "≈ 2 min to keep your 7-day streak".
    var sentence: String {
        if days == 0 && isClosed { return String(localized: "Done for today") }
        switch state {
        case .atRisk:
            return StreakChip.text(days: days, state: .atRisk, minutesToKeep: nil)
        case .open:
            return StreakChip.text(days: days, state: .open, minutesToKeep: minutes)
        case .kept:
            let tail = isClosed ? String(localized: "Done for today") : minutes.map { String(localized: "\(Format.timeLeft(minutes: $0)) left") }
            return [StreakChip.text(days: days, state: .kept, minutesToKeep: nil), tail].compactMap { $0 }.joined(separator: " · ")
        }
    }

    /// The short form for a line with room for little, after the flame: "7 · ≈ 2 min", "7 · Done" once the ring is closed,
    /// the days alone without a price. Without a streak the sentence.
    var short: String {
        guard days > 0 else { return sentence }
        let tail = isClosed ? String(localized: "Done") : minutes.map(Format.timeLeft(minutes:))
        return [days.formatted(.number.grouping(.never)), tail].compactMap { $0 }.joined(separator: " · ")
    }
}
