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
                LimitStepper(title: "New cards/day", value: document.option(\.newCardsPerSession), step: 5, ceiling: 100, range: LearningOptions.sessionLimitRange)
            } header: {
                Text("Daily Limits")
            } footer: {
                Text("— lets the day's ring decide. A number takes that many new cards a day, as Anki does.")
            }

            Section {
                OptionSlider(title: "Target recall", value: document.option(\.targetRecall), range: LearningOptions.targetRecallRange, step: 0.01)
            } header: {
                Text("Scheduling")
            } footer: {
                Text("Higher means better recall and more reviews.")
            }

            Section {
                Stepper(value: document.option(\.leechThreshold), in: LearningOptions.leechThresholdRange) {
                    ValueLabel("Leech after") {
                        if options.leechThreshold == 0 {
                            Text("Off")
                        } else {
                            Text("\(options.leechThreshold) lapses")
                        }
                    }
                }
                Picker("When a card becomes a leech", selection: document.option(\.leechAction)) {
                    Text("Keep").tag(LeechAction.keep)
                    Text("Suspend").tag(LeechAction.suspend)
                }
            } footer: {
                Text("A card you forget this many times becomes a leech, and again after every half of that.")
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
                Text("Spreads cards learned together over nearby days.")
            }

            Section {
                Stepper(value: document.option(\.steps), in: LearningOptions.stepsRange) {
                    ValueLabel("Steps per card") {
                        Text(options.steps, format: .number)
                    }
                }
            } footer: {
                Text("New and forgotten cards come back until you grade them Good this many times.")
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
