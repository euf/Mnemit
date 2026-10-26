import SwiftUI
import VocabCore

/// The learning options of a deck, pushed from its screen: what a learner changes now and
/// then, with "Advanced" one push further. Every change is saved at once through
/// `VocabularyDocument.updateLearningOptions(_:)`, one undo step each, so there is no Save;
/// the Mac's `DeckOptionsView` collects the changes in a sheet instead.
struct DeckOptionsScreen: View {
    @ObservedObject var document: VocabularyDocument

    init(document: VocabularyDocument) {
        self.document = document
    }

    var body: some View {
        let options = document.deck.learningOptions
        Form {
            Section {
                LimitRows(title: "New cards per day", value: document.option(\.newCardsPerSession), defaultValue: 20, step: 5, range: LearningOptions.sessionLimitRange)
                Picker("New card order", selection: document.option(\.newCardOrder)) {
                    Text("Deck order").tag(NewCardOrder.deckOrder)
                    Text("Newest first").tag(NewCardOrder.newestFirst)
                }
            } header: {
                Text("New Cards")
            } footer: {
                Text("Counts every new card except the Translation → Greek ones.")
            }

            Section {
                OptionSlider(title: "Target recall", value: document.option(\.targetRecall), range: LearningOptions.targetRecallRange, step: 0.01)
            } header: {
                Text("Scheduling")
            } footer: {
                Text("Higher means better recall but more reviews. 90% is a good balance.")
            }

            Section {
                LimitRows(title: "New per day", value: document.option(\.newProductionPerSession), defaultValue: 7, step: 1, range: LearningOptions.productionLimitRange)
                Stepper(value: document.option(\.productionUnlockDays), in: LearningOptions.productionUnlockDaysRange) {
                    ValueLabel("Unlock after") {
                        if options.productionUnlockDays == 0 {
                            Text("Never locked")
                        } else {
                            Text(Format.days(Double(options.productionUnlockDays)))
                        }
                    }
                }
            } header: {
                Text("Translation → Greek")
            } footer: {
                Text("A Translation → Greek card stays locked until its Greek → translation card has an interval this long. A word is asked in one direction per day.")
            }

            Section {
                Stepper(value: document.option(\.leechThreshold), in: LearningOptions.leechThresholdRange) {
                    ValueLabel("Difficult after") {
                        if options.leechThreshold == 0 {
                            Text("Off")
                        } else {
                            Text("\(options.leechThreshold) lapses")
                        }
                    }
                }
            } footer: {
                Text("A card you forget this many times, and again after every further multiple, is suspended and marked Difficult. Resume it in the Card Browser. Off never suspends.")
            }

            Section {
                NavigationLink("Advanced") {
                    DeckAdvancedOptionsScreen(document: document)
                }
            }
        }
        .monospacedDigit()
        .navigationTitle("Options")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(!document.isReadyToEdit)
    }
}

/// What the learning options keep to themselves: the intervals, the steps, how revealed
/// reviews count, and the FSRS parameters with their optimizer.
struct DeckAdvancedOptionsScreen: View {
    @ObservedObject var document: VocabularyDocument

    init(document: VocabularyDocument) {
        self.document = document
    }

    var body: some View {
        let options = document.deck.learningOptions
        Form {
            Section {
                Stepper(value: document.option(\.maximumInterval), in: LearningOptions.maximumIntervalRange, step: 30) {
                    ValueLabel("Longest interval") {
                        Text(Format.days(Double(options.maximumInterval)))
                    }
                }
                Toggle("Spread out intervals", isOn: document.option(\.fuzzing))
            } footer: {
                Text("Varies intervals slightly so cards learned together don't always come back together.")
            }

            Section {
                Stepper(value: document.option(\.steps), in: LearningOptions.stepsRange) {
                    ValueLabel("Steps per card") {
                        Text(options.steps, format: .number)
                    }
                }
            } footer: {
                Text("New cards and cards after a lapse come back within the session until they have been graded Good this many times. Hard keeps a card on its step, Again resets it, Easy moves it to the review phase at once.")
            }

            ParametersSection(options: document.option(\.self), cards: document.deck.cards, calendar: document.calendar, appliesAtOnce: true)
        }
        .monospacedDigit()
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(!document.isReadyToEdit)
    }
}

extension VocabularyDocument {
    /// A binding to one learning option, or to all of them with `\.self`: it reads the
    /// deck, and what is set goes through `updateLearningOptions(_:)`, which clamps the
    /// value into its range. Nothing happens while the document can't be changed.
    func option<Value>(_ keyPath: WritableKeyPath<LearningOptions, Value>) -> Binding<Value> {
        Binding(
            get: { self.deck.learningOptions[keyPath: keyPath] },
            set: { value in
                var options = self.deck.learningOptions
                options[keyPath: keyPath] = value
                self.updateLearningOptions(options)
            }
        )
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

/// A number the learner may leave unlimited, as two rows: a stepper, and the switch.
struct LimitRows: View {
    var title: LocalizedStringKey
    @Binding var value: Int?
    /// What switching "Unlimited" off sets.
    var defaultValue: Int
    var step: Int
    var range: ClosedRange<Int>

    var body: some View {
        Stepper(value: Binding(get: { value ?? defaultValue }, set: { value = $0 }), in: range, step: step) {
            ValueLabel(title) {
                if let value {
                    Text(value, format: .number)
                } else {
                    Text("Unlimited")
                }
            }
        }
        .disabled(value == nil)
        Toggle("Unlimited", isOn: Binding(get: { value == nil }, set: { value = $0 ? nil : defaultValue }))
    }
}

/// A fraction as a percentage on a slider, with its range at the ends. The value is saved
/// once the slider rests for a moment, not on every step of a drag: each save is an undo
/// step and a write of the deck.
struct OptionSlider: View {
    var title: LocalizedStringKey
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    /// What the slider shows while it moves, until it is saved.
    @State private var live: Double?

    var body: some View {
        let shown = Binding(get: { live ?? value }, set: { live = $0 })
        VStack(alignment: .leading, spacing: Spacing.tight) {
            ValueLabel(title) { Text(Format.percent(live ?? value)) }
                .accessibilityHidden(true)
            Slider(value: shown, in: range, step: step) {
                Text(title)
            } minimumValueLabel: {
                Text(Format.percent(range.lowerBound))
            } maximumValueLabel: {
                Text(Format.percent(range.upperBound))
            }
            .font(.footnote)
            .accessibilityValue(Format.percent(live ?? value))
        }
        .task(id: live) {
            guard let pending = live else { return }
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            value = pending
            live = nil
        }
    }
}
