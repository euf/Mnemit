#if os(iOS)
import SwiftUI
import VocabCore
import WidgetKit

/// The picture of the widget in each family, from the figures of one timeline entry: the day's ring as a picture, nothing
/// in its middle. The medium widget is Today's card without its week: the ring on the left, its three figures on the right
/// (`TodayFigures`: Day streak, the next moment, Words learned); the small one has the ring, the flame over the days and the
/// next step under them (`NextStepText`: the action over its price); the lock screen's circle, a gauge, has the minutes of the next step. In a tinted or clear
/// rendering (`widgetRenderingMode`) the ring's track and arc differ by opacity, ring and values are `widgetAccentable`, and a
/// ring past its goal says its lap as a number. `nil` before the app wrote a snapshot.
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

    /// The streak and the one sentence of the widget.
    var nextStep: NextStep { NextStep(progress, minutesToKeep: roundStatus?.minutesToKeep, minutesToClose: minutesLeft, minutesOfReviews: minutesLeft) }
}

/// The day's ring as a picture, with nothing in its middle: the arc and its laps. In a tinted, clear or vibrant rendering the
/// system keeps one tone and the opacity, so the ring is flat there with a stronger track, and a lap past the goal is a number,
/// "2×", in its middle.
private struct WidgetRing: View {
    var state: WidgetState
    var diameter: CGFloat
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        let tinted = mode != .fullColor
        DailyRingView(progress: state.progress, diameter: diameter, isFlat: tinted)
            .overlay {
                if tinted, let laps = DailyRingFigure.laps(state.ringFraction) {
                    Text(verbatim: "\(laps)×")
                        .font(diameter >= 56 ? .caption.bold() : .caption2.bold())
                        .monospacedDigit()
                        .accessibilityHidden(true)
                }
            }
            .widgetAccentable()
    }
}

/// The streak's line (`StreakLine`): the flame, filled once today keeps the streak and with a solid alert disc the day after a
/// missed one, marked accentable so a tinted widget keeps the state by the flame's shape, and "12-day streak". Nothing without
/// a streak. The size and the weight are the caller's.
private struct WidgetStreakLine: View {
    var step: NextStep

    var body: some View {
        if step.days > 0 {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                StreakFlame(state: step.state)
                    .widgetAccentable(step.state != .open)
                Text(verbatim: NextStep.unbroken(step.streakText))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

/// The ring at the top left, the days at the top right with the flame over them (large, no label: the flame says it), the
/// next step at the bottom left: three blocks pinned to the corners fill the square, as the system's own small widgets do.
/// The edges are the drawn ones. The flame hangs from the ring's top and the days stand on its bottom, so the pair spans the
/// ring and the row is the ring's height (the days' descent hangs into the gap); the last line's baseline sits on the bottom
/// margin as the ring's edge sits on the side ones; the flame and the days move out by their glyphs' side bearing, so their
/// ink meets the right margin.
private struct SmallWidget: View {
    var state: WidgetState
    /// The days, as large as the ring's height allows under the flame; with the text size.
    @ScaledMetric(relativeTo: .largeTitle) private var daysSize: CGFloat = 44

    private let ring: CGFloat = 62
    /// The side bearing of the flame and the figures at their size, and the space above the flame's tip in its image.
    private let bearing: CGFloat = 1.5
    private let flameTop: CGFloat = 1.3

    var body: some View {
        let step = state.nextStep
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: 8) {
                WidgetRing(state: state, diameter: ring)
                Spacer(minLength: 0)
                // Proportional figures: tabular ones open a gap inside "11", and nothing here ticks in place.
                Text(verbatim: step.days.formatted(.number.grouping(.never)))
                    .font(.system(size: daysSize, weight: .bold, design: .rounded))
                    .foregroundStyle(step.state.tint)
                    .widgetAccentable()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .alignmentGuide(.bottom) { $0[.lastTextBaseline] }
                    .offset(x: bearing)
            }
            .frame(height: ring, alignment: .top)
            .overlay(alignment: .topTrailing) {
                StreakFlame(state: step.state)
                    .font(.title3)
                    .widgetAccentable(step.state != .open)
                    .offset(x: bearing, y: -flameTop)
            }
            NextStepText(step: step, alignment: .leading)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .alignmentGuide(.bottom) { $0[.lastTextBaseline] }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: step.spoken))
    }
}

/// Today's card without its week, for room: the ring on the left, on the right Day streak, the next moment and Words learned.
/// The widget opens the stream; it has no button.
private struct MediumWidget: View {
    var state: WidgetState

    var body: some View {
        let step = state.nextStep
        HStack(spacing: 16) {
            WidgetRing(state: state, diameter: 96)
            TodayFigures(step: step, words: state.wordsLearned, gain: state.wordsLearnedToday, size: .compact, accentable: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: step.spoken))
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
            let step = state.nextStep
            if step.isClosed {
                Image(systemName: "checkmark")
            } else if let minutes = step.minutes {
                VStack(spacing: -2) {
                    Text(verbatim: minutes == 0 ? "<1" : String(minutes))
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .minimumScaleFactor(0.5)
                    Text("min")
                        .font(.system(size: 9))
                }
            } else if step.days > 0 {
                // Without a price (a snapshot of an older app): the flame over the days, so the circle is never blank.
                VStack(spacing: -2) {
                    StreakFlame(state: step.state)
                        .font(.caption2)
                    Text(step.days, format: .number.grouping(.never))
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .minimumScaleFactor(0.5)
                }
            } else {
                Image(systemName: "flame")
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(Color.dailyRing)
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: state.nextStep.spoken))
    }
}

/// A small ring on the left; beside it the streak line and the sentence.
private struct RectangularWidget: View {
    var state: WidgetState

    var body: some View {
        let step = state.nextStep
        HStack(spacing: 8) {
            WidgetRing(state: state, diameter: 44)
            VStack(alignment: .leading, spacing: 0) {
                WidgetStreakLine(step: step)
                    .font(.caption.weight(.semibold))
                NextStepText(step: step, alignment: .leading)
                    .font(.caption2)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: step.spoken))
    }
}

/// The line over the lock screen's clock: the flame and "7 · 2 min"; the flame carries an alert disc at risk.
/// Without a streak the sentence alone.
private struct InlineWidget: View {
    var state: WidgetState

    var body: some View {
        let step = state.nextStep
        Group {
            if step.days > 0 {
                Label {
                    Text(verbatim: step.short)
                } icon: {
                    StreakFlame(state: step.state)
                        .widgetAccentable(step.state != .open)
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
        case .accessoryCircular:
            Image(systemName: "rectangle.stack.fill")
                .font(.title2)
                .widgetAccentable()
                .accessibilityLabel(Text("Open Mnemit to start"))
        case .accessoryRectangular:
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
