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
                    LimitStepper(title: "Cards per session", value: $options.cardsPerSession, step: 10, ceiling: 300, range: LearningOptions.sessionLimitRange)
                    LimitStepper(title: "New cards per day", value: $options.newCardsPerSession, step: 5, ceiling: 100, range: LearningOptions.sessionLimitRange)
                    Picker("New card order", selection: $options.newCardOrder) {
                        Text("Deck order").tag(NewCardOrder.deckOrder)
                        Text("Newest first").tag(NewCardOrder.newestFirst)
                    }
                    Stepper(value: $options.steps, in: LearningOptions.stepsRange) {
                        LabeledContent("Steps per card", value: options.steps.formatted())
                    }
                } header: {
                    Text("Sessions")
                } footer: {
                    Text("New and lapsed cards come back in the session until you have graded them Good this many times.")
                }

                Section {
                    LimitStepper(title: "New per day", value: $options.newProductionPerSession, step: 1, ceiling: 30, range: LearningOptions.productionLimitRange)
                    Stepper(value: $options.productionUnlockDays, in: LearningOptions.productionUnlockDaysRange) {
                        LabeledContent(
                            "Unlock after",
                            value: options.productionUnlockDays == 0 ? String(localized: "Never locked") : Format.days(Double(options.productionUnlockDays)))
                    }
                } header: {
                    Text("Meaning → Word cards")
                } footer: {
                    Text("A Meaning → Word card waits until the Word → Meaning card of its word has an interval this long.")
                }

                Section {
                    DisclosureGroup("Advanced", isExpanded: $showsAdvanced) {
                        Toggle("Spread out intervals", isOn: $options.fuzzing)
                            .help("Varies intervals slightly so cards learned together don't always come back together.")
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
