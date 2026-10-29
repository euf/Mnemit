import SwiftUI
import VocabCore

/// Learning options stored in the deck: Anki's names for the rows, a "?" on each that tells a newcomer what the row
/// does, and Restore Defaults as the way back. The sheet collects the changes; Save applies them as one.
struct DeckOptionsView: View {
    @ObservedObject var document: VocabularyDocument
    @Environment(\.dismiss) private var dismiss
    @State private var options: LearningOptions
    @State private var showsAdvanced = false
    @State private var isAskingToRestore = false

    init(document: VocabularyDocument) {
        self.document = document
        _options = State(initialValue: document.deck.learningOptions)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    LimitStepper(title: "New cards/day", value: $options.newCardsPerSession, step: 5, ceiling: 100, range: LearningOptions.sessionLimitRange)
                        .helpButton(
                            "How many new cards this deck gives a day. — lets Mnemit decide from your day: fewer when reviews pile up, more when you keep up. A number takes exactly that many, as in Anki."
                        )
                    LimitStepper(title: "Maximum reviews/day", value: $options.maximumReviewsPerDay, step: 10, ceiling: 500, range: LearningOptions.reviewLimitRange)
                        .helpButton(
                            "The most review cards this deck asks a day. — asks every card that is due, which keeps your memory on schedule. A number leaves the rest for the next days, as in Anki."
                        )
                } header: {
                    Text("Daily Limits")
                }

                Section {
                    LabeledContent("Desired retention") {
                        HStack {
                            Slider(value: $options.targetRecall, in: LearningOptions.targetRecallRange, step: 0.01)
                            Text(Format.percent(options.targetRecall))
                                .monospacedDigit()
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                    .helpButton("The chance you still remember a card when it comes back. Higher means more reviews; \(Format.percent(0.9)) suits most learners.")
                } header: {
                    Text(verbatim: "FSRS")
                }

                Section {
                    Stepper(value: $options.leechThreshold, in: LearningOptions.leechThresholdRange) {
                        LabeledContent("Leech threshold") {
                            if options.leechThreshold == 0 {
                                Text("Off")
                            } else {
                                Text("\(options.leechThreshold) lapses")
                            }
                        }
                    }
                    .helpButton("A card you forget this many times becomes a leech: it costs you more time than it gives. Off never marks one.")
                    Picker("Leech action", selection: $options.leechAction) {
                        Text("Keep Card").tag(LeechAction.keep)
                        Text("Suspend Card").tag(LeechAction.suspend)
                    }
                    .helpButton("What happens to a leech. Keep Card goes on asking it; Suspend Card stops asking it until you resume it.")
                } header: {
                    Text("Lapses")
                }

                Section {
                    DisclosureGroup("Advanced", isExpanded: $showsAdvanced) {
                        Stepper(value: $options.maximumInterval, in: LearningOptions.maximumIntervalRange, step: 30) {
                            LabeledContent("Maximum interval", value: Format.days(Double(options.maximumInterval)))
                        }
                        .helpButton("The longest a card waits before it is asked again. The default holds no card back.")
                        Stepper(value: $options.steps, in: LearningOptions.stepsRange) {
                            LabeledContent("Learning steps", value: options.steps.formatted())
                        }
                        .helpButton("How many times you grade a new or forgotten card Good before it moves on to longer intervals.")
                    }
                }

                ParametersSection(options: $options, cards: document.deck.trainingCards, calendar: document.calendar)
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Restore Defaults") {
                    isAskingToRestore = true
                }
                .confirmationDialog("Restore the defaults of this deck's options?", isPresented: $isAskingToRestore, titleVisibility: .visible) {
                    Button("Restore Defaults", role: .destructive) { options = options.restoringDefaults() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Your FSRS parameters stay: they come from your reviews.")
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    document.updateLearningOptions(options)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 520, height: 640)
    }
}
