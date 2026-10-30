import SwiftUI
import VocabCore

/// A number of the deck's options as a menu of round values. On the iPhone a stepper takes a press per step, and each press
/// is a write of the deck and an undo step; a menu sets the value in one. A value off the menu, as another app or a file may
/// have set, stays on it in its place.
struct LimitMenu: View {
    var title: LocalizedStringKey
    @Binding var value: Int?
    /// The values from top to bottom; `nil` is the option without a number, Auto or No limit.
    var presets: [Int?]
    /// Where `nil` sits among the numbers, for a value off the menu to find its place.
    var unsetLast = false
    var label: (Int?) -> Text

    var body: some View {
        Picker(title, selection: $value) {
            ForEach(Self.menu(presets, keeping: value, unsetLast: unsetLast), id: \.self) { label($0).tag($0) }
        }
    }

    /// `presets`, with `value` among them in numeric order if it is not.
    static func menu(_ presets: [Int?], keeping value: Int?, unsetLast: Bool) -> [Int?] {
        guard let value, !presets.contains(value) else { return presets }
        var menu = presets
        menu.insert(value, at: presets.firstIndex { ($0 ?? (unsetLast ? .max : .min)) > value } ?? presets.endIndex)
        return menu
    }
}

/// New cards/day, as Anki names it: Auto, which leaves it to the day's ring, then None (a review-only stretch) and round numbers.
struct NewCardsPicker: View {
    @Binding var limit: Int?

    var body: some View {
        LimitMenu(title: "New cards/day", value: $limit, presets: [nil, 0, 5, 10, 15, 20, 30, 40, 50, 75, 100]) {
            switch $0 {
            case nil: Text("Auto")
            case 0: Text("None")
            case let number?: Text(number, format: .number)
            }
        }
    }
}

/// Maximum reviews/day, as Anki names it: round numbers around Anki's default of 200, and No limit, which asks every review that is due.
struct ReviewLimitPicker: View {
    @Binding var limit: Int?

    var body: some View {
        LimitMenu(title: "Maximum reviews/day", value: $limit, presets: [50, 100, 150, 200, 300, 500, nil], unsetLast: true) {
            if let number = $0 { Text(number, format: .number) } else { Text("No limit") }
        }
    }
}

/// The leech threshold: the lapses at which a card becomes a leech, or Off.
struct LeechThresholdPicker: View {
    @Binding var threshold: Int

    var body: some View {
        LimitMenu(title: "Leech threshold", value: Binding(get: { threshold }, set: { threshold = $0 ?? 0 }), presets: [0, 4, 5, 6, 8, 10, 12, 16, 20]) {
            if let number = $0, number > 0 { Text("\(number) lapses") } else { Text("Off") }
        }
    }
}

/// Learning steps, 1 to 5, as a menu: five values hardly need a stepper, whose every press is a write of the deck.
struct LearningStepsPicker: View {
    @Binding var steps: Int

    var body: some View {
        Picker("Learning steps", selection: $steps) {
            ForEach(LearningOptions.stepsRange, id: \.self) { Text("\($0) steps").tag($0) }
        }
    }
}

/// The title of a slider with its value: side by side, the title wrapping to a second line before the value leaves its
/// row, and one above the other at the accessibility sizes, where beside each other they squeeze each other to a few
/// letters a line.
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
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                Spacer(minLength: Spacing.tight)
                value.foregroundStyle(.secondary).layoutPriority(1)
            }
            .accessibilityElement(children: .combine)
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
