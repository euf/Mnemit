import SwiftUI
import VocabCore

/// A deck's Today card, the top of its screen on both apps, in the grammar of the screens: the label "Today" over the plan's
/// time, "≈ 4 min" in the ring's colour, and beside it Due, New and Learning as figures in the primary colour. A count of 0 is
/// left out, as on the deck's row. A deck with nothing left says "Done" with its next review, a paused one "Paused".
/// VoiceOver reads the headline, the same words in one line.
struct DeckTodayCard: View {
    var headline: DeckHeadline
    var counts: StudyCounts?
    /// The day's pace, which prices the plan; `nil` until the ring is evaluated, the time is a placeholder then.
    var pace: Pace?
    var isPaused: Bool
    var now: Date

    var body: some View {
        ViewThatFits(in: .horizontal) {
            // The time keeps its width, the counts share what is left.
            HStack(alignment: .top, spacing: Spacing.gap) {
                today.fixedSize(horizontal: true, vertical: false)
                counters
            }
            VStack(alignment: .leading, spacing: Spacing.tight) {
                today
                HStack(alignment: .top, spacing: Spacing.gap) { counters }
            }
            VStack(alignment: .leading, spacing: Spacing.tight) {
                today
                counters
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: headline.text))
    }

    /// The plan's cards, only while there are some to do.
    private var plan: StudyCounts? { isPaused || headline.isDone ? nil : counts }

    @ViewBuilder
    private var today: some View {
        if isPaused {
            Figure(label: Text("Today"), value: Text("Paused"))
        } else if headline.isDone {
            VStack(alignment: .leading, spacing: 2) {
                Figure(label: Text("Today"), value: Text("Done")) {
                    Image(systemName: "checkmark")
                        .font(.headline)
                        .accessibilityHidden(true)
                }
                if let next = counts?.nextDue {
                    Text("Next review \(Format.due(next, now: now))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } else if let plan, let minutes = DeckMinutes.minutes(plan, pace: pace) {
            Figure(label: Text("Today"), value: Text(verbatim: Format.timeLeft(minutes: minutes)), tint: .appAccentText)
        } else {
            Figure(label: Text("Today"), value: Text(verbatim: Format.timeLeft(minutes: 2)), tint: .appAccentText)
                .redacted(reason: .placeholder)
        }
    }

    @ViewBuilder
    private var counters: some View {
        if let plan {
            if plan.due > 0 { Figure(label: Text("Due"), value: Text(plan.due, format: .number)) }
            if plan.new > 0 { Figure(label: Text("New"), value: Text(plan.new, format: .number)) }
            if plan.learning > 0 { Figure(label: Text("Learning"), value: Text(plan.learning, format: .number)) }
        }
    }
}
