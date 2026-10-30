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
                    NewCardsPicker(limit: $options.newCardsPerSession)
                        .helpButton("New cards a day. Auto: Mnemit decides, fewer when reviews pile up. A number: exactly that many. None: no new cards.")
                    ReviewLimitPicker(limit: $options.maximumReviewsPerDay)
                        .helpButton("The most reviews asked a day. No limit asks every due card; a number leaves the rest for later.")
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
                    Text("Memory Model (FSRS)")
                }

                Section {
                    LeechThresholdPicker(threshold: $options.leechThreshold)
                        .helpButton("A card you forget this many times is a leech: it takes more time than it gives. Off marks none.")
                    Picker("Leech action", selection: $options.leechAction) {
                        Text("Keep Card").tag(LeechAction.keep)
                        Text("Suspend Card").tag(LeechAction.suspend)
                    }
                    .disabled(options.leechThreshold == 0)
                    .helpButton("Keep Card goes on asking a leech. Suspend Card stops asking it until you resume it.")
                } header: {
                    Text("Lapses")
                }

                Section {
                    DisclosureGroup("Advanced", isExpanded: $showsAdvanced) {
                        MaximumIntervalPicker(days: $options.maximumInterval)
                            .helpButton("The longest a card waits before it is asked again. The default holds no card back.")
                        LearningStepsPicker(steps: $options.steps)
                            .helpButton("How many times you grade a new or forgotten card Good before longer intervals begin. Anki’s list “1m 10m” is 2.")
                    }
                }

                ParametersSection(options: $options, cards: document.deck.trainingCards, pool: AllDecks.pool(besides: document), calendar: document.calendar)
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
