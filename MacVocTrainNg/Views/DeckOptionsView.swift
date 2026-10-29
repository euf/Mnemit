import SwiftUI
import VocabCore

/// Learning options stored in the deck.
struct DeckOptionsView: View {
    @ObservedObject var document: VocabularyDocument
    @Environment(\.dismiss) private var dismiss
    @State private var options: LearningOptions
    @State private var showsAdvanced = false

    init(document: VocabularyDocument) {
        self.document = document
        _options = State(initialValue: document.deck.learningOptions)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    LabeledContent("Target recall") {
                        HStack {
                            Slider(value: $options.targetRecall, in: LearningOptions.targetRecallRange, step: 0.01)
                            Text(Format.percent(options.targetRecall))
                                .monospacedDigit()
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                } header: {
                    Text("Scheduling")
                } footer: {
                    Text("Higher means better recall and more reviews.")
                }

                Section {
                    LimitStepper(title: "New cards/day", value: $options.newCardsPerSession, step: 5, ceiling: 100, range: LearningOptions.sessionLimitRange)
                } header: {
                    Text("Daily Limits")
                } footer: {
                    Text("— lets the day's ring decide. A number takes that many new cards a day, as Anki does.")
                }

                Section {
                    Stepper(value: $options.steps, in: LearningOptions.stepsRange) {
                        LabeledContent("Steps per card", value: options.steps.formatted())
                    }
                } header: {
                    Text("Sessions")
                } footer: {
                    Text("New and forgotten cards come back until you grade them Good this many times.")
                }

                Section {
                    DisclosureGroup("Advanced", isExpanded: $showsAdvanced) {
                        Toggle("Spread out intervals", isOn: $options.fuzzing)
                            .help("Spreads cards learned together over nearby days.")
                        Stepper(value: $options.maximumInterval, in: LearningOptions.maximumIntervalRange, step: 30) {
                            LabeledContent("Longest interval", value: Format.days(Double(options.maximumInterval)))
                        }
                        Stepper(value: $options.leechThreshold, in: LearningOptions.leechThresholdRange) {
                            LabeledContent("Leech threshold", value: options.leechThreshold == 0 ? String(localized: "Off") : options.leechThreshold.formatted())
                        }
                        .help("A card you forget this many times becomes a leech, and again after every half of that.")
                        Picker("When a card becomes a leech", selection: $options.leechAction) {
                            Text("Keep").tag(LeechAction.keep)
                            Text("Suspend").tag(LeechAction.suspend)
                        }
                    }
                }

                ParametersSection(options: $options, cards: document.deck.trainingCards, calendar: document.calendar)
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Restore Defaults") {
                    options = LearningOptions()
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
