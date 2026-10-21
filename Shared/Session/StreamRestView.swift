import SwiftUI
import VocabCore

/// New cards beyond the daily limits, as "+10 new" offers them.
struct ExtraNewCards {
    /// At most `StudyStream.newCardChunk`.
    var cards: Int
    /// What they add to the reviews of each day of the next week, rounded; see `NewCardLoad`.
    var reviewsPerDay: Int
}

/// What the stream shows while it rests, see `StreamRestView`.
struct StreamRest {
    /// A practice from the deck screen, not the stream: it ends here.
    var isPracticeOnly: Bool
    /// What the plan of the stream did; what the practice did, for a practice.
    var recap: StudyStream.Recap
    /// When cards come back that today's plan leaves out; `nil` if no card has been studied.
    var nextDue: Date?
    var now: Date
    /// Review ahead or practice has something to go on with.
    var canKeepGoing: Bool
    /// What the stream could add beyond the daily limits; `nil` if there are no new cards.
    var extraNew: ExtraNewCards?
}

/// The short stop between today's plan and the rest of the stream: "Done for today" with
/// the size of the plan, how many cards were recalled and when the next one is due, the
/// ring, and what the learner can do from here. "Keep Going" reviews ahead and practices,
/// and is the default; the new cards beyond the daily limit need a button of their own, with
/// a line that says what they cost. A finished practice ends with its figures.
struct StreamRestView: View {
    var rest: StreamRest
    var progress: DailyProgress?
    var onKeepGoing: () -> Void
    var onAddNewCards: () -> Void
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            DailyRingView(progress: progress, diameter: 96)

            Text(rest.isPracticeOnly ? "Practice complete" : "Done for today")
                .font(.title.weight(.semibold))

            VStack(spacing: 4) {
                if rest.recap.cards > 0 {
                    if rest.isPracticeOnly {
                        Text("\(rest.recap.cards) cards")
                    } else {
                        Text("\(rest.recap.cards) cards in today's plan")
                    }
                }
                if let accuracy = rest.recap.accuracy {
                    Text("\(Format.percent(accuracy)) recalled")
                }
                if !rest.isPracticeOnly, let nextDue = rest.nextDue {
                    Text("Next review \(Format.due(nextDue, now: rest.now))")
                }
            }
            .foregroundStyle(.secondary)
            .monospacedDigit()

            VStack(spacing: 14) {
                if rest.canKeepGoing {
                    Button(action: onKeepGoing) {
                        Text("Keep Going")
                            .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
                if let extra = rest.extraNew {
                    VStack(spacing: 4) {
                        Button(action: onAddNewCards) {
                            Text("+\(extra.cards) new")
                                .frame(maxWidth: .infinity, minHeight: 28)
                        }
                        .buttonStyle(.bordered)
                        Text("≈ +\(extra.reviewsPerDay) reviews/day next week")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Button(action: onDone) {
                    Text("Done")
                        .frame(maxWidth: .infinity, minHeight: 28)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(rest.canKeepGoing ? nil : .defaultAction)
            }
            .controlSize(.large)
            .frame(maxWidth: 320)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
