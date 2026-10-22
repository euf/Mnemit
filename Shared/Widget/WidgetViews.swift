#if os(iOS)
import SwiftUI
import VocabCore
import WidgetKit

/// The picture of the widget in each family, from the figures of one timeline entry: the
/// daily ring (`DailyRingView`, which shows the streak in its middle), what today's plan
/// still asks, how far today's goal is. `nil` before the app wrote a snapshot.
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
    /// "42 cards left", what the plan still asks, or what stands in for it when it is empty: never the whole backlog.
    fileprivate var headline: Text {
        if due > 0 { return Text("\(due) cards left") }
        return reviews > 0 ? Text("All done") : Text("Nothing due")
    }

    fileprivate var progressLine: Text {
        Text("\(reviews) of \(goal) reviews")
    }

    /// For the circular widget, whose middle holds the due count: no streak number, and one lap
    /// at most, as the badge of the laps would hang out of the circle the system cuts.
    fileprivate var ringWithoutStreak: DailyProgress {
        DailyProgress(ring: DailyRing(reviews: min(reviews, goal), goal: goal), streak: Streak(days: 0, repairCards: nil))
    }
}

/// The flame and the days of the streak; the flame in the accent once today's goal keeps it.
private struct StreakLine: View {
    var state: WidgetState

    var body: some View {
        if state.streakDays > 0 {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(state.isGoalMet ? Color.appAccent : Color.secondary)
                    .widgetAccentable(state.isGoalMet)
                Text("\(state.streakDays)-day streak")
            }
        }
    }
}

private struct SmallWidget: View {
    var state: WidgetState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DailyRingView(progress: state.progress, diameter: 64)
                .widgetAccentable()
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 0) {
                state.headline
                    .font(.title3.weight(.semibold))
                    .minimumScaleFactor(0.7)
                state.progressLine
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
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
                state.headline
                    .font(.title2.weight(.semibold))
                state.progressLine
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                StreakLine(state: state)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
            state.headline
                .font(.headline)
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
