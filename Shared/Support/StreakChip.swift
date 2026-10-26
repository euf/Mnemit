import SwiftUI
import VocabCore

/// The streak as one unit outside every ring: the flame by its state and one sentence, read together. Today, the rests
/// and the widgets show it under or beside the ring, which holds the day's cards and never the streak.
///
/// The sentence by state: kept "12-day streak"; open, with the time to the end of the first round, "≈ 2 min to keep
/// your 12-day streak"; the day after a missed one "Close the ring to save your 12-day streak"; with no streak
/// "Start your streak · ≈ 2 min". The state is also a shape (`StreakFlame`), so the chip reads in one colour.
struct StreakChip: View {
    /// The streak in days; `nil` while the day is not read: a placeholder.
    var days: Int?
    var state: StreakState
    /// The minutes the first round takes while it is not done, `RoundStatus.minutesToKeep`.
    var minutesToKeep: Int?

    var body: some View {
        let shown = days ?? 12
        HStack(spacing: 6) {
            StreakFlame(state: state)
                .imageScale(.large)
            Text(verbatim: Self.text(days: shown, state: state, minutesToKeep: minutesToKeep))
        }
        .font(.subheadline.weight(.semibold))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(state == .open ? Color.secondary.opacity(0.12) : Color.streak.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .redacted(reason: days == nil ? .placeholder : [])
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: Self.spoken(days: shown, state: state, minutesToKeep: minutesToKeep)))
    }

    /// The chip's sentence for `days` in `state`. `nonisolated`: a view is main-actor, and the closures in here trap when
    /// a test or a widget builds the text off the main queue.
    nonisolated static func text(days: Int, state: StreakState, minutesToKeep: Int?) -> String {
        let time = minutesToKeep.map(Format.timeLeft(minutes:))
        guard days > 0 else {
            return [String(localized: "Start your streak"), time].compactMap { $0 }.joined(separator: " · ")
        }
        switch state {
        case .atRisk: return String(localized: "Close the ring to save your \(days)-day streak")
        case .open: return time.map { String(localized: "\($0) to keep your \(days)-day streak") } ?? String(localized: "\(days)-day streak")
        case .kept: return String(localized: "\(days)-day streak")
        }
    }

    /// What VoiceOver reads: the sentence, with the state added where the sentence does not say it.
    nonisolated static func spoken(days: Int, state: StreakState, minutesToKeep: Int?) -> String {
        guard days > 0 else { return text(days: days, state: state, minutesToKeep: minutesToKeep) }
        switch state {
        case .kept: return String(localized: "\(days)-day streak, kept today")
        case .open where minutesToKeep == nil: return String(localized: "\(days)-day streak, not kept yet")
        default: return text(days: days, state: state, minutesToKeep: minutesToKeep)
        }
    }
}
