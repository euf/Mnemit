import SwiftUI
import VocabCore

/// A daily limit of the deck, New cards/day or Maximum reviews/day, as Anki names them, as one stepper whose first
/// step is `unset`, no limit of the deck's own: for New cards/day the day's ring decides, for Maximum reviews/day every
/// review that is due is asked. Plus from `unset` gives `step`, minus from the lowest number gives `unset` again, plus stops
/// at `ceiling`.
/// A value above `ceiling`, as another app or a file may have set, shows as it is, and minus takes it down.
struct LimitStepper: View {
    var title: LocalizedStringKey
    /// What the stepper shows without a number: Auto for New cards/day, No limit for Maximum reviews/day.
    var unset: LocalizedStringKey
    @Binding var value: Int?
    /// What one press of plus or minus adds or takes.
    var step: Int
    /// The highest number plus reaches.
    var ceiling: Int
    var range: ClosedRange<Int>

    var body: some View {
        Stepper(
            onIncrement: (value ?? 0) >= ceiling ? nil : { value = Self.raised(value, step: step, ceiling: ceiling) },
            onDecrement: value == nil ? nil : { value = Self.lowered(value, step: step, lowerBound: range.lowerBound) }
        ) {
            ValueLabel(title) {
                if let value {
                    Text(value, format: .number)
                } else {
                    Text(unset)
                }
            }
        }
    }

    /// The value after plus: `step` from `unset`, then a step more, at most `ceiling`.
    static func raised(_ value: Int?, step: Int, ceiling: Int) -> Int? {
        min(ceiling, (value ?? 0) + step)
    }

    /// The value after minus: a step less, never below `lowerBound`; `unset` from `lowerBound`.
    static func lowered(_ value: Int?, step: Int, lowerBound: Int) -> Int? {
        guard let value, value > lowerBound else { return nil }
        return max(lowerBound, value - step)
    }
}

/// The title of a stepper or slider with its value: side by side, and one above the other at the
/// accessibility sizes, where beside each other they squeeze each other to a few letters a line.
struct ValueLabel<Value: View>: View {
    var title: LocalizedStringKey
    var value: Value
    @Environment(\.dynamicTypeSize) private var textSize

    init(_ title: LocalizedStringKey, @ViewBuilder value: () -> Value) {
        self.title = title
        self.value = value()
    }

    var body: some View {
        if textSize.isAccessibilitySize {
            VStack(alignment: .leading) {
                Text(title)
                value.foregroundStyle(.secondary)
            }
        } else {
            LabeledContent(title) { value }
        }
    }
}

/// Maximum interval as Anki names it, as a menu of round values: a stepper over 30...36,500 days takes a thousand presses.
/// The top of the range is Anki's default and holds no card back, so it reads No limit. A value off the menu, as an Anki
/// preset or a file may have set, stays on it as it is.
struct MaximumIntervalPicker: View {
    @Binding var days: Int

    static let choices = [180, 365, 730, 1095, 1825, 3650, LearningOptions.maximumIntervalRange.upperBound]

    var body: some View {
        Picker("Maximum interval", selection: $days) {
            ForEach(Self.choices.contains(days) ? Self.choices : (Self.choices + [days]).sorted(), id: \.self) { days in
                Text(Self.label(days)).tag(days)
            }
        }
    }

    /// "No limit", "5 years", or "180 days" for what isn't whole years.
    static func label(_ days: Int) -> String {
        if days >= LearningOptions.maximumIntervalRange.upperBound { return String(localized: "No limit") }
        if days % 365 == 0 { return String(localized: "\(days / 365) years") }
        return Format.days(Double(days))
    }
}
