#if os(iOS)
import SwiftUI
import VocabCore
import WidgetKit

/// The picture of the widget in each family, from the figures of one timeline entry: the
/// daily ring (`DailyRingView`, which shows the streak in its middle), the cards left of
/// today's plan, how far the daily goal is. `nil` before the app wrote a snapshot.
///
/// In `Shared` and not in the extension, so the tests of the app can draw it with fixed
/// sizes; the extension only puts a timeline under it. Everything that opens the app is the
/// widget's own URL, `WidgetLink.study`; "Study" in the medium widget is the same link.
struct WidgetContent: View {
    var state: WidgetState?
    var family: WidgetFamily

    /// The face of the home-screen widgets, the one of the cards on Today: white in light, a
    /// raised grey in dark. The extension puts it under the entries (`containerBackground`).
    static let background = Color(.secondarySystemGroupedBackground)

    var body: some View {
        Group {
            if let state {
                switch family {
                case .systemMedium: MediumWidget(state: state)
                case .accessoryCircular: CircularWidget(state: state)
                case .accessoryRectangular: RectangularWidget(state: state)
                default: SmallWidget(state: state)
                }
            } else {
                EmptyWidget(family: family)
            }
        }
        .widgetURL(WidgetLink.study)
    }
}

extension WidgetState {
    /// "42 cards left", the cards of the plan not done yet, or what stands in for it when none is left: never the whole backlog.
    fileprivate var headline: Text {
        if due > 0 { return Text("\(due) cards left") }
        return done > 0 ? Text("All done") : Text("Nothing due")
    }

    /// "≈ 7 min", the time the cards left take; `nil` when there is nothing to price.
    fileprivate var timeLeft: String? {
        minutesLeft.map { Format.timeLeft(minutes: $0) }
    }

    fileprivate var progressLine: Text {
        Text("\(done) of \(goal) cards")
    }

    /// What the day asks next (`RoundStatus.title`), "≈ 2 min to keep your streak", while cards are left and the
    /// snapshot knows the rounds; `nil` otherwise, and the headline says the cards left.
    fileprivate var roundTitle: LocalizedStringResource? {
        due > 0 ? roundStatus?.title : nil
    }

    /// "≈ 28 words in memory".
    fileprivate var wordsLine: LocalizedStringResource? {
        wordsInMemory.flatMap { MemoryEstimate.wordsLine($0) }
    }

    /// For the circular widget, whose middle holds the cards left: no streak number, and one lap
    /// at most, as the badge of the laps would hang out of the circle the system cuts.
    fileprivate var ringWithoutStreak: DailyProgress {
        DailyProgress(ring: DailyRing(done: min(done, goal), goal: goal), streak: Streak(days: 0, repairCards: nil))
    }
}

/// The headline, "42 cards left", with the time they take after it: on the same line where the
/// two fit side by side at the headline's size, else on the line under it. The small widget
/// (155 pt wide at the least) has no width for three digits and the time, so it always stacks.
private struct HeadlineLine: View {
    var state: WidgetState
    var font: Font

    var body: some View {
        if let title = state.roundTitle {
            // Long enough to take a second line.
            Text(title)
                .font(font)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        } else if let timeLeft = state.timeLeft {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    state.headline
                        .font(font)
                    Text(verbatim: "· " + timeLeft)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 0) {
                    state.headline
                        .font(font)
                        .minimumScaleFactor(0.7)
                    Text(verbatim: timeLeft)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
        } else {
            state.headline
                .font(font)
                .minimumScaleFactor(0.7)
        }
    }
}

/// The flame and the days of the streak; the flame in the accent once today's goal keeps it.
private struct StreakLine: View {
    var state: WidgetState

    var body: some View {
        if state.streakDays > 0 {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(state.isStreakKept ? Color.appAccent : Color.secondary)
                    .widgetAccentable(state.isStreakKept)
                Text("\(state.streakDays)-day streak")
            }
        }
    }
}

private struct SmallWidget: View {
    var state: WidgetState

    var body: some View {
        // With the time under the headline, or a title of two lines, there are three lines of text, and the ring gives up 8 pt.
        let hasTime = state.timeLeft != nil || state.roundTitle != nil
        VStack(alignment: .leading, spacing: hasTime ? 6 : 8) {
            DailyRingView(progress: state.progress, diameter: hasTime ? 56 : 64)
                .widgetAccentable()
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 0) {
                HeadlineLine(state: state, font: .title3.weight(.semibold))
                state.progressLine
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .monospacedDigit()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }
}

private struct MediumWidget: View {
    var state: WidgetState

    var body: some View {
        HStack(spacing: 12) {
            DailyRingView(progress: state.progress, diameter: 76)
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 2) {
                HeadlineLine(state: state, font: .title2.weight(.semibold))
                state.progressLine
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                StreakLine(state: state)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let words = state.wordsLine {
                    // The column beside the ring and the Study button is about 127 pt wide.
                    Text(words)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .minimumScaleFactor(0.7)
                }
                if let reminder = state.nextReminder {
                    Text("Reminder at \(Text(reminder, style: .time))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Link(destination: WidgetLink.study) {
                Text("Study")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.appAccent, in: Capsule())
                    .widgetAccentable()
            }
        }
        .monospacedDigit()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct CircularWidget: View {
    var state: WidgetState

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            DailyRingView(progress: state.ringWithoutStreak, diameter: 58)
                .widgetAccentable()
            Text(state.due, format: .number)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(width: 38)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.headline)
    }
}

private struct RectangularWidget: View {
    var state: WidgetState

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Group {
                if let title = state.roundTitle {
                    Text(title)
                } else {
                    state.headline
                }
            }
            .font(.headline)
            .minimumScaleFactor(0.6)
            .widgetAccentable()
            state.progressLine
                .font(.caption)
            StreakLine(state: state)
                .font(.caption)
        }
        .monospacedDigit()
        .lineLimit(1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Before the first snapshot: the app has not run since it was installed, or the keychain
/// shares nothing with it.
private struct EmptyWidget: View {
    var family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryCircular, .accessoryRectangular:
            Text("Open Mnemit to start")
                .font(.caption)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            VStack(spacing: 8) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.title)
                    .foregroundStyle(Color.appAccent)
                    .widgetAccentable()
                Text("Open Mnemit to start")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
#endif
