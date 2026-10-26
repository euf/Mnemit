import SwiftUI

/// A count the learner may leave unlimited, as one stepper whose last step is "Unlimited":
/// plus past `ceiling` gives Unlimited, minus from Unlimited comes back to `ceiling`. A value
/// above `ceiling`, as another app or a file may have set, shows as it is, and plus from it
/// gives Unlimited.
struct LimitStepper: View {
    var title: LocalizedStringKey
    @Binding var value: Int?
    /// What one press of plus or minus adds or takes.
    var step: Int
    /// The last number; one step further is Unlimited.
    var ceiling: Int
    var range: ClosedRange<Int>

    var body: some View {
        Stepper(
            onIncrement: value == nil ? nil : { value = Self.raised(value, step: step, ceiling: ceiling) },
            onDecrement: value == range.lowerBound ? nil : { value = Self.lowered(value, step: step, ceiling: ceiling, lowerBound: range.lowerBound) }
        ) {
            ValueLabel(title) {
                if let value {
                    Text(value, format: .number)
                } else {
                    Text("Unlimited")
                }
            }
        }
    }

    /// The value after plus: `nil`, Unlimited, once it passes `ceiling`.
    static func raised(_ value: Int?, step: Int, ceiling: Int) -> Int? {
        guard let value else { return nil }
        return value + step > ceiling ? nil : value + step
    }

    /// The value after minus: `ceiling` from Unlimited, never below `lowerBound`.
    static func lowered(_ value: Int?, step: Int, ceiling: Int, lowerBound: Int) -> Int? {
        guard let value else { return ceiling }
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

/// "Words in this deck": New words are shown once with their answer before the learner is asked, Words
/// I know are asked at once (`LearningOptions.introducesNewCards`). The same choice is made in Options,
/// when a deck is made, and when an Anki package makes one. A section of a form.
struct WordsInDeckSection: View {
    @Binding var introducesNewCards: Bool

    var body: some View {
        Section {
            Picker("Words in this deck", selection: $introducesNewCards) {
                Text("New words").tag(true)
                Text("Words I know").tag(false)
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Words in this deck")
        } footer: {
            Text("New words are shown with their answer before you are asked; words you know are asked at once.")
        }
    }
}
