#if os(iOS)
import SwiftUI
import VocabCore
import WidgetKit

/// The picture of the widget in each family, from the figures of one timeline entry: the day's ring with the cards
/// left in its middle (a check once it is closed), the streak chip beside or under it, and the time that closes the ring.
/// The ring holds the day's cards and the chip the streak, as on Today. `nil` before the app wrote a snapshot.
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
    /// The streak's flame as the chip draws it: outlined until the streak step is done, filled after, and the day
    /// after a missed one outlined in the streak's colour with an exclamation mark.
    var streakState: StreakState { progress.streakState }

    /// The middle of the ring: the cards left to close it, or a check.
    fileprivate var center: RingCenter { RingCenter(progress) }

    /// Today's ring in laps of the goal, as every ring draws it.
    fileprivate var ringFraction: Double { DailyRingFigure.fraction(progress, shown: nil) }

    /// What the line over the lock screen's clock says after the flame: "8 left", or "8 cards left" where there is no
    /// streak to take the room, and "Ring closed" once it is.
    var inlineLeft: String {
        switch center {
        case .cardsLeft(let count): streakDays > 0 ? String(localized: "\(count) left") : String(localized: "\(count) cards left")
        default: due == 0 && done == 0 ? String(localized: "Nothing due") : String(localized: "Ring closed")
        }
    }

    /// The line over the lock screen's clock, after the flame: "7 · 8 left", and without a streak "8 cards left".
    var inlineLine: String {
        guard streakDays > 0 else { return inlineLeft }
        return streakDays.formatted(.number.grouping(.never)) + " · " + inlineLeft
    }
}

/// The streak chip at the widget's size, once there is a streak; the flame is what the tinted style colours.
private struct WidgetChip: View {
    var state: WidgetState

    var body: some View {
        if state.streakDays > 0 {
            StreakChip(days: state.streakDays, state: state.streakState, minutesToKeep: state.roundStatus?.minutesToKeep, isCompact: true)
                .widgetAccentable(state.streakState != .open)
        }
    }
}

/// The flame and the days of the streak without a capsule, for the lock screen's rectangle: the flame is filled once
/// today keeps the streak, outlined with an exclamation mark the day after a missed one.
private struct StreakLine: View {
    var state: WidgetState

    var body: some View {
        if state.streakDays > 0 {
            HStack(spacing: 4) {
                StreakFlame(state: state.streakState)
                    .widgetAccentable(state.streakState != .open)
                Text("\(state.streakDays)-day streak")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                Text(verbatim: StreakChip.spoken(days: state.streakDays, state: state.streakState, minutesToKeep: state.roundStatus?.minutesToKeep)))
        }
    }
}

/// The line under or beside the chip: the time that closes the ring, "≈ 2 min", or "3 left" of the plan once it is
/// closed (`WidgetState.lead`).
private struct LeadLine: View {
    var state: WidgetState

    var body: some View {
        if let lead = state.lead {
            Text(verbatim: lead)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

/// The ring with the cards left in it; under it the streak chip and the time.
private struct SmallWidget: View {
    var state: WidgetState

    var body: some View {
        VStack(spacing: 6) {
            DailyRingView(progress: state.progress, diameter: 64)
                .widgetAccentable()
            WidgetChip(state: state)
            LeadLine(state: state)
                .font(.footnote)
        }
        .monospacedDigit()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// The ring with the cards left in it on the left; on the right the chip, the time, the week's rings (each day's own
/// share of its goal), and Study while the ring is open (the whole widget still opens the stream).
private struct MediumWidget: View {
    var state: WidgetState

    var body: some View {
        HStack(spacing: 16) {
            // A stroke thinner than the default, so that "cards left" under the figure clears it.
            DailyRingView(progress: state.progress, diameter: 92, lineWidth: 10.5)
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 8) {
                WidgetChip(state: state)
                HStack {
                    LeadLine(state: state)
                        .font(.subheadline)
                    Spacer(minLength: 8)
                    if state.due > 0 && !state.isGoalMet {
                        Link(destination: WidgetLink.study) {
                            Text("Study")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.appAccent, in: Capsule())
                                .widgetAccentable()
                        }
                    }
                }
                if let week = state.week {
                    WeekRings(week: week, rings: state.weekRings, today: state.ringFraction, now: state.date, diameter: 20, spacing: 7)
                        .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .monospacedDigit()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// The system's gauge, which the lock screen draws in each of its styles (full colour, vibrant, tinted), with the cards
/// left in its middle and a check once the ring is closed; no flame. A gauge is one lap, so past the goal it is full.
private struct CircularWidget: View {
    var state: WidgetState

    var body: some View {
        Gauge(value: min(1, state.ringFraction)) {
            Text("Daily Goal")
        } currentValueLabel: {
            if let figure = state.center.text {
                Text(verbatim: figure)
                    .minimumScaleFactor(0.5)
            } else {
                Image(systemName: "checkmark")
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(Color.dailyRing)
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: state.center.spokenLabel ?? ""))
    }
}

/// The ring with the cards left in it on the left; on the right the streak and the time.
private struct RectangularWidget: View {
    var state: WidgetState

    var body: some View {
        HStack(spacing: 8) {
            DailyRingView(progress: state.progress, diameter: 60)
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 2) {
                StreakLine(state: state)
                LeadLine(state: state)
            }
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .monospacedDigit()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The line over the lock screen's clock: the flame, the days of the streak and the cards left, "7 · 8 left"; the flame
/// carries an exclamation mark at risk. Without a streak the cards left alone.
private struct InlineWidget: View {
    var state: WidgetState

    var body: some View {
        if state.streakDays > 0 {
            Label {
                Text(verbatim: state.inlineLine)
            } icon: {
                StreakFlame(state: state.streakState)
                    .widgetAccentable(state.streakState != .open)
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
