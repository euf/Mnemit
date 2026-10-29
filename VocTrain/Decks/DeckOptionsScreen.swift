import SwiftUI
import VocabCore

/// The learning options of a deck, pushed from its screen: what a learner changes now and
/// then, with "Advanced" one push further. The rows carry Anki's names, each with a "?" that tells
/// a newcomer what the row does, and Restore Defaults is the way back. Every change is saved at once through
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
                    .helpButton(
                        "How many new cards this deck gives a day. — lets Mnemit decide from your day: fewer when reviews pile up, more when you keep up. A number takes exactly that many, as in Anki."
                    )
                LimitStepper(
                    title: "Maximum reviews/day", value: document.option(\.maximumReviewsPerDay), step: 10, ceiling: 500, range: LearningOptions.reviewLimitRange
                )
                .helpButton(
                    "The most review cards this deck asks a day. — asks every card that is due, which keeps your memory on schedule. A number leaves the rest for the next days, as in Anki."
                )
            } header: {
                Text("Daily Limits")
            }

            Section {
                OptionSlider(
                    title: "Desired retention", value: document.option(\.targetRecall), range: LearningOptions.targetRecallRange, step: 0.01,
                    help: "The chance you still remember a card when it comes back. Higher means more reviews; \(Format.percent(0.9)) suits most learners.")
            } header: {
                Text(verbatim: "FSRS")
            }

            Section {
                Stepper(value: document.option(\.leechThreshold), in: LearningOptions.leechThresholdRange) {
                    ValueLabel("Leech threshold") {
                        if options.leechThreshold == 0 {
                            Text("Off")
                        } else {
                            Text("\(options.leechThreshold) lapses")
                        }
                    }
                }
                .helpButton("A card you forget this many times becomes a leech: it costs you more time than it gives. Off never marks one.")
                Picker("Leech action", selection: document.option(\.leechAction)) {
                    Text("Keep Card").tag(LeechAction.keep)
                    Text("Suspend Card").tag(LeechAction.suspend)
                }
                .helpButton("What happens to a leech. Keep Card goes on asking it; Suspend Card stops asking it until you resume it.")
            } header: {
                Text("Lapses")
            }

            Section {
                NavigationLink("Advanced") {
                    DeckAdvancedOptionsScreen(document: document)
                }
            }

            RestoreDefaultsSection(document: document)
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
                    ValueLabel("Maximum interval") {
                        Text(Format.days(Double(options.maximumInterval)))
                    }
                }
                .helpButton("The longest a card waits before it is asked again. The default holds no card back.")
                Stepper(value: document.option(\.steps), in: LearningOptions.stepsRange) {
                    ValueLabel("Learning steps") {
                        Text(options.steps, format: .number)
                    }
                }
                .helpButton("How many times you grade a new or forgotten card Good before it moves on to longer intervals.")
            }

            ParametersSection(options: document.option(\.self), cards: document.deck.trainingCards, calendar: document.calendar, appliesAtOnce: true)

            RestoreDefaultsSection(document: document)
        }
        .monospacedDigit()
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(!document.isReadyToEdit)
    }
}

/// The way back to the defaults, on both screens: every option of the deck at once, one undo step, once the learner
/// has confirmed. The FSRS parameters and the pause stay (`LearningOptions.restoringDefaults()`).
private struct RestoreDefaultsSection: View {
    @ObservedObject var document: VocabularyDocument
    @State private var isAsking = false

    var body: some View {
        Section {
            Button("Restore Defaults", role: .destructive) { isAsking = true }
                .confirmationDialog("Restore the defaults of this deck's options?", isPresented: $isAsking, titleVisibility: .visible) {
                    Button("Restore Defaults", role: .destructive) { document.restoreDefaultLearningOptions() }
                    Button("Cancel", role: .cancel) {}
                }
        }
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
    /// What the "?" next to the title says.
    var help: LocalizedStringKey
    /// What the slider shows while it moves, until it is saved.
    @State private var live: Double?

    var body: some View {
        let shown = Binding(get: { live ?? value }, set: { live = $0 })
        VStack(alignment: .leading, spacing: Spacing.tight) {
            ValueLabel(title) { Text(Format.percent(live ?? value)) }
                .accessibilityHidden(true)
                .helpButton(help)
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
