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
                LimitStepper(title: "New cards per day", value: document.option(\.newCardsPerSession), step: 5, ceiling: 100, range: LearningOptions.sessionLimitRange)
                Picker("New card order", selection: document.option(\.newCardOrder)) {
                    Text("Deck order").tag(NewCardOrder.deckOrder)
                    Text("Newest first").tag(NewCardOrder.newestFirst)
                }
            } header: {
                Text("New Cards")
            } footer: {
                Text("Meaning → Word cards have a limit of their own.")
            }

            Section {
                OptionSlider(title: "Target recall", value: document.option(\.targetRecall), range: LearningOptions.targetRecallRange, step: 0.01)
            } header: {
                Text("Scheduling")
            } footer: {
                Text("Higher means better recall and more reviews.")
            }

            Section {
                LimitStepper(title: "New per day", value: document.option(\.newProductionPerSession), step: 1, ceiling: 30, range: LearningOptions.productionLimitRange)
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
                Text("Meaning → Word cards")
            } footer: {
                Text("A Meaning → Word card waits until the Word → Meaning card of its word has an interval this long.")
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
                Text("A card you forget this many times is suspended and marked Difficult.")
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

/// What the learning options keep to themselves: the intervals, the steps, and the FSRS
/// parameters with their optimizer.
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
                Text("New and lapsed cards come back in the session until you have graded them Good this many times.")
            }

            ParametersSection(options: document.option(\.self), cards: document.deck.trainingCards, calendar: document.calendar, appliesAtOnce: true)
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
