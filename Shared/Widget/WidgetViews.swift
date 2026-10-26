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
                case .accessoryInline: InlineWidget(state: state)
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
    /// "6 cards left", the cards left to close the ring; "Ring closed" once it is; never the whole plan or backlog.
    fileprivate var headline: Text {
        if toRing > 0 { return Text("\(toRing) cards left") }
        if goal > 0 && done >= goal { return Text("Ring closed") }
        if due > 0 { return Text("\(due) cards left") }
        return done > 0 ? Text("All done") : Text("Nothing due")
    }

    /// "≈ 7 min", the time the cards left take; `nil` when there is nothing to price.
    fileprivate var timeLeft: String? {
        minutesLeft.map { Format.timeLeft(minutes: $0) }
    }

    /// "49 cards today" once the ring is closed; while it is open the ring itself shows how far it is.
    fileprivate var progressLine: Text? {
        done > 0 && done >= goal ? Text("\(done) cards today") : nil
    }

    /// What the day asks next (`RoundStatus.title`), "≈ 2 min to keep your streak", while cards are left and the
    /// snapshot knows the rounds; `nil` otherwise, and the headline says the cards left.
    fileprivate var roundTitle: LocalizedStringResource? {
        due > 0 ? roundStatus?.title : nil
    }

    /// The streak's flame as every ring draws it: outlined until the streak step is done, filled after, and the day
    /// after a missed one outlined in the streak's colour.
    var streakState: StreakState { progress.streakState }

    /// The cards left to close the ring, "20 cards left", in a closed ring "Ring closed" while the plan has more, and
    /// "All done" once nothing is left.
    var inlineLeft: String {
        if toRing > 0 { return String(localized: "\(toRing) cards left") }
        if due > 0 { return goal > 0 && done >= goal ? String(localized: "Ring closed") : String(localized: "\(due) cards left") }
        return done > 0 ? String(localized: "All done") : String(localized: "Nothing due")
    }

    /// The line over the lock screen's clock, after the flame: "12 · 20 cards left", and without a streak the cards left alone.
    var inlineLine: String {
        guard streakDays > 0 else { return inlineLeft }
        return streakDays.formatted(.number.grouping(.never)) + " · " + inlineLeft
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

/// The flame and the days of the streak, for the lock screen's rectangle, which has no ring; the flame is filled once
/// today keeps the streak.
private struct StreakLine: View {
    var state: WidgetState

    var body: some View {
        if state.streakDays > 0 {
            HStack(spacing: 4) {
                StreakFlame(state: state.streakState)
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
                state.progressLine?
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

/// The ring with the streak in its middle and the line Today shows under its ring (`TodayHeadline`), then the week's
/// rings, and Study while the ring is open (the whole widget still opens the stream).
private struct MediumWidget: View {
    var state: WidgetState

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                DailyRingView(progress: state.progress, diameter: 60)
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: state.todayLine)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    state.progressLine?
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                if let week = state.week {
                    WeekRings(week: week, today: state.progress.ring.fraction, now: state.date, diameter: 20, spacing: 8)
                        .fixedSize()
                }
                Spacer(minLength: 8)
                if state.due > 0 && !state.isGoalMet {
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
            }
        }
        .monospacedDigit()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// The ring with the streak in its middle, as every ring has it; the headline is for VoiceOver.
private struct CircularWidget: View {
    var state: WidgetState

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            DailyRingView(progress: state.progress, diameter: 58)
                .widgetAccentable()
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
            state.progressLine?
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

/// The line over the lock screen's clock: the flame, the days of the streak and the cards left, "12 · 20 cards left";
/// without a streak the cards left alone.
private struct InlineWidget: View {
    var state: WidgetState

    var body: some View {
        if state.streakDays > 0 {
            Label {
                Text(verbatim: state.inlineLine)
            } icon: {
                StreakFlame(state: state.streakState)
                    .widgetAccentable(state.isStreakKept)
            }
        } else {
            Text(verbatim: state.inlineLine)
        }
    }
}

/// Before the first snapshot: the app has not run since it was installed, or the keychain
/// shares nothing with it.
private struct EmptyWidget: View {
    var family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Open Mnemit to start")
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
