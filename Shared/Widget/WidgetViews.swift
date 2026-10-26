#if os(iOS)
import SwiftUI
import VocabCore
import WidgetKit

/// The picture of the widget in each family, from the figures of one timeline entry: the day's ring as a picture, nothing
/// in its middle, and one sentence that carries the streak and the price of the next step (`WidgetState.sentence`), led
/// by the flame. The medium widget adds the week's rings; the lock screen's circle, a gauge, has the minutes of the next
/// step. `nil` before the app wrote a snapshot.
///
/// In `Shared` and not in the extension, so the tests of the app can draw it with fixed
/// sizes; the extension only puts a timeline under it. Everything that opens the app is the
/// widget's own URL, `WidgetLink.study`; no widget has a button of its own.
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
    /// Today's ring in laps of the goal, as every ring draws it.
    fileprivate var ringFraction: Double { DailyRingFigure.fraction(progress, shown: nil) }

    /// The flame and the one sentence of the widget.
    var nextStep: NextStep { NextStep(progress, minutesToKeep: roundStatus?.minutesToKeep, minutesToClose: minutesLeft, minutesOfReviews: minutesLeft) }
}

/// The day's ring as a picture, with nothing in its middle: the arc and its laps.
private struct WidgetRing: View {
    var state: WidgetState
    var diameter: CGFloat

    var body: some View {
        DailyRingView(progress: state.progress, diameter: diameter)
            .widgetAccentable()
    }
}

/// The one sentence (`NextStep`), led by the flame: the second line starts under the first, not under the flame. The flame is
/// filled once today keeps the streak and carries an exclamation mark the day after a missed one. The size, the weight, the
/// alignment and the number of lines are the caller's.
private struct WidgetSentence: View {
    var step: NextStep
    var alignment: HorizontalAlignment = .center

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if let flame = step.flame {
                StreakFlame(state: flame)
                    .widgetAccentable(flame != .open)
            }
            NextStepText(step: step, alignment: alignment)
        }
    }
}

/// The ring, large, and the sentence under it: two lines, three for the longest, the day after a missed one.
private struct SmallWidget: View {
    var state: WidgetState

    var body: some View {
        VStack(spacing: 6) {
            WidgetRing(state: state, diameter: 72)
            WidgetSentence(step: state.nextStep)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: state.nextStep.spoken))
    }
}

/// The ring on the left; on the right the sentence as the headline and under it the week's rings, without initials.
/// The widget opens the stream; it has no button.
private struct MediumWidget: View {
    var state: WidgetState

    private static let ring: CGFloat = 104

    var body: some View {
        HStack(spacing: 16) {
            WidgetRing(state: state, diameter: Self.ring)
            // As tall as the ring: the sentence at its top, the week at its bottom.
            VStack(alignment: .leading, spacing: 8) {
                WidgetSentence(step: state.nextStep, alignment: .leading)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                    // Three lines: the day after a missed one is the longest sentence.
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                if let week = state.week {
                    WeekRings(week: week, rings: state.weekRings, today: state.ringFraction, now: state.date, showsLetters: false, diameter: 18, spacing: 6)
                        .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: Self.ring, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: state.nextStep.spoken))
    }
}

/// The system's gauge, which the lock screen draws in each of its styles (full colour, vibrant, tinted), with the minutes
/// of the next step in its middle, "2" over "min", and a check once the ring is closed. A gauge is one lap, so past the
/// goal it is full.
private struct CircularWidget: View {
    var state: WidgetState

    var body: some View {
        Gauge(value: min(1, state.ringFraction)) {
            Text("Daily Goal")
        } currentValueLabel: {
            if state.nextStep.isClosed {
                Image(systemName: "checkmark")
            } else if let minutes = state.nextStep.minutes {
                VStack(spacing: -2) {
                    Text(verbatim: minutes == 0 ? "<1" : String(minutes))
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .minimumScaleFactor(0.5)
                    Text("min")
                        .font(.system(size: 9))
                }
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(Color.dailyRing)
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: state.nextStep.spoken))
    }
}

/// A small ring on the left and the sentence beside it.
private struct RectangularWidget: View {
    var state: WidgetState

    var body: some View {
        HStack(spacing: 8) {
            WidgetRing(state: state, diameter: 56)
            WidgetSentence(step: state.nextStep, alignment: .leading)
                .font(.caption)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: state.nextStep.spoken))
    }
}

/// The line over the lock screen's clock: the flame and "7 · ≈ 2 min"; the flame carries an exclamation mark at risk.
/// Without a streak the sentence alone.
private struct InlineWidget: View {
    var state: WidgetState

    var body: some View {
        let step = state.nextStep
        Group {
            if step.days > 0, let flame = step.flame {
                Label {
                    Text(verbatim: step.short)
                } icon: {
                    StreakFlame(state: flame)
                        .widgetAccentable(flame != .open)
                }
            } else {
                Text(verbatim: step.short)
            }
        }
        .accessibilityLabel(Text(verbatim: step.spoken))
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
