import SwiftUI
import VocabCore

/// The daily ring with the streak in its centre, what the day asks next in a headline and one detail line, and
/// the words in memory. The streak's record, the ladder of memory and the rest are on the Progress screen.
/// On Today of the iPhone, in its first row, and on the Mac's Today window, at its top: one picture of the day on
/// both.
struct SummaryRow: View {
    /// The cards of the plan not done yet, "N cards left": not the cards that are due in all.
    var due: Int
    /// Of `due`, the cards that were new when the day began.
    var newDue = 0
    var progress: DailyProgress?
    /// When something comes back that today's plans leave out.
    var nextDue: Date?
    var now: Date
    /// `false` until the decks are read: the figures are placeholders then.
    var isLoaded: Bool
    @Environment(\.dynamicTypeSize) var typeSize
    @ScaledMetric(relativeTo: .title2) var diameter = 72
    /// The ring's size before Dynamic Type: the Mac's Today window gives it more room.
    var ringSize: CGFloat = 72

    var body: some View {
        let layout =
            typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 16))
        // The words in memory take the width of the row under the ring: beside it, on a 375 pt screen, "+15 today"
        // would not fit on the line of the words.
        VStack(alignment: .leading, spacing: 8) {
            layout {
                ProgressRing(
                    fraction: progress?.ring.fraction ?? 0, diameter: min(diameter * ringSize / 72, ringSize * 4 / 3), center: RingCenter(progress),
                    filling: .smooth(duration: 1.4))
                VStack(alignment: .leading, spacing: 2) {
                    if !isLoaded {
                        placeholderLines
                    } else {
                        headline
                            .font(.title2.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        detail
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .monospacedDigit()
            }
            if let memory = progress?.memory {
                MemoryLine(memory: memory)
                    .font(.subheadline)
                    .monospacedDigit()
            } else if !isLoaded {
                Text("≈ \(0) words in memory")
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 8)
        .redacted(reason: isLoaded ? [] : .placeholder)
    }

    /// Until the decks are read, the lines the day will have, as placeholders: the headline and the cards take
    /// their room, so nothing below moves when the figures come.
    @ViewBuilder
    private var placeholderLines: some View {
        Text("Ring closed")
            .font(.title2.weight(.semibold))
        Text(verbatim: [String(localized: "\(12) of \(24) cards"), String(localized: "\(12) left")].joined(separator: " · "))
            .font(.subheadline)
    }

    /// The cards left to close the ring, which "N cards left" counts while it is open: the plan may hold more after a
    /// break, and those come after the ring.
    private var toRing: Int {
        guard let ring = progress?.ring, ring.goal > 0, ring.done < ring.goal else { return 0 }
        return min(due, ring.goal - ring.done)
    }

    /// "≈ 7 min": the cards left to the ring at the learner's pace, once the decks are read.
    private var timeLeft: String? {
        guard let progress, let minutes = DailyGoal.minutesLeft(cards: toRing > 0 ? toRing : due, secondsPerCard: progress.secondsPerCardLeft)
        else { return nil }
        return Format.timeLeft(minutes: minutes)
    }

    private var isAtRisk: Bool { progress?.isStreakAtRisk ?? false }

    /// What the day asks next: "≈ 2 min to keep your streak" before the first round, then the cards left with
    /// their time, "Ring closed" once the ring is, "Close the ring to save your streak" while a missed day waits for it; nothing at all once no card is left.
    @ViewBuilder
    private var headline: some View {
        if isAtRisk {
            Text("Close the ring to save your streak")
        } else if due > 0, let title = progress.flatMap({ RoundStatus($0).title }) {
            Text(title)
        } else if due > 0 {
            let cardsLeft = Text("\(toRing > 0 ? toRing : due) cards left")
            if let timeLeft {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        cardsLeft
                        Text(verbatim: "· " + timeLeft)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        cardsLeft
                        Text(verbatim: timeLeft)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                cardsLeft
            }
        } else if let ring = progress?.ring, ring.done > 0 {
            Text("All done")
        } else {
            Text("Nothing due")
        }
    }

    /// "12 of 24 cards": the done cards against the goal; once the ring is closed, "49 cards today · 3 left", what is
    /// left of the plan. Before the first card of the day, yesterday's ring: the day turns at 04:00, and work done just
    /// before it belongs to the day before, which Today shows until today's first card.
    @ViewBuilder
    private var detail: some View {
        if let ring = progress?.ring, ring.done == 0, let yesterday = progress?.yesterday {
            if yesterday.closed {
                Text("Yesterday's ring closed · \(yesterday.done) cards")
            } else {
                Text("Yesterday: \(yesterday.done) of \(yesterday.goal) cards")
            }
        } else if let ring = progress?.ring, due > 0, !ring.isGoalMet {
            Text("\(ring.done) of \(ring.goal) cards")
        } else if let ring = progress?.ring, due > 0 {
            Text(verbatim: [String(localized: "\(ring.done) cards today"), String(localized: "\(due) left")].joined(separator: " · "))
        } else if let ring = progress?.ring, ring.done > 0 {
            Text("\(ring.done) cards today")
        } else if due == 0, let nextDue {
            Text("Next review \(Format.due(nextDue, now: now))")
        }
    }
}

/// "≈ 28 words in memory · +15 today" on one line, or on the day a milestone was passed "50 words in memory!"
/// with a glyph in the accent: the accent is never small text. Where the line is too long, at a large type size,
/// it is one text that wraps, not the gain stacked under the words.
struct MemoryLine: View {
    var memory: MemoryEstimate

    var body: some View {
        if let milestone = memory.milestoneLine {
            HStack(spacing: 4) {
                // The glyph bursts the first time the line shows for a milestone.
                MilestoneSparkles(milestone: memory.milestoneReachedToday)
                Text(milestone)
                    .fontWeight(.semibold)
            }
        } else if let line = memory.line {
            Text(verbatim: line)
                .foregroundStyle(.secondary)
        }
    }
}

/// What Today's one button does next, named with the words of the rests: **Study** while the ring is open; **Catch
/// Up** once the ring is closed and the plan has cards left; **Push On** once the day's stack is done, ten new
/// cards at once. The iPhone's Today and the Mac's Today window say the same.
enum DayAction: Equatable {
    case study, catchUp, pushOn

    /// What the button does for a day with `due` cards of the plan left.
    init(due: Int, progress: DailyProgress?) {
        if due == 0 {
            self = .pushOn
        } else if progress?.ring.isGoalMet == true {
            self = .catchUp
        } else {
            self = .study
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .study: "Study"
        case .catchUp: "Catch Up"
        case .pushOn: "Push On"
        }
    }
}
