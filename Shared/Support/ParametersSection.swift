import SwiftUI
import VocabCore

/// The FSRS parameters in the learning options: computes them from the deck's review
/// log and compares them with the current ones. Saving the options applies them; the
/// iPhone's options screen saves every change at once (`appliesAtOnce`). Shared by both
/// apps' options screens.
struct ParametersSection: View {
    @Binding var options: LearningOptions
    /// The cards of this deck.
    let cards: [Card]
    /// The other decks of the learner: the memory model is fitted on the reviews of all of them.
    var pool = ReviewPool()
    let calendar: StudyCalendar
    /// Whether a change of `options` is saved as it is made, so new parameters need no
    /// Save button to take effect.
    var appliesAtOnce = false

    /// The usable reviews, counted once per opening of the sheet, not in `init`: the parent
    /// rebuilds this view on every change to the options, and counting goes through the
    /// whole log. `nil` while counting.
    @State private var reviewCount: Int?
    /// The cards of all decks, once counted.
    @State private var allCards: [Card] = []
    @State private var state = ComputationState.idle
    @State private var task: Task<Void, Never>?

    private enum ComputationState {
        case idle
        case running(Double)
        case finished(FSRSOptimizer.Comparison)
        case failed
    }

    var body: some View {
        Section {
            LabeledContent("Current parameters", value: options.parameters == .default ? String(localized: "Default") : String(localized: "Custom"))
                // On a row that is always there, whatever the count.
                .task { await countReviews() }
            Toggle("Update parameters automatically", isOn: $options.updatesParametersAutomatically)
            if ParameterRefit.hasOwnParameters(options) {
                Text("Set by hand or by an Anki preset: kept as they are.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let fit = options.lastAutoFit {
                Text(Self.summary(of: fit))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            switch reviewCount {
            case nil:
                // Counted in a moment: a row with no value would look broken.
                EmptyView()
            case let count? where count < FSRSOptimizer.minimumReviewCount:
                LabeledContent("Usable reviews", value: "\(count) / \(FSRSOptimizer.minimumReviewCount)")
            case let count?:
                LabeledContent("Usable reviews", value: count.formatted())
                computation
            }
            if options.parameters != .default {
                Button("Reset FSRS Parameters") {
                    options.parameters = .default
                }
            }
        } header: {
            HStack {
                Text("FSRS Parameters")
                HelpButton(text: "The memory model behind the schedule, fitted by itself to the reviews of all your decks. Optimize does it now.")
            }
        } footer: {
            if let reviewCount, reviewCount < FSRSOptimizer.minimumReviewCount {
                Text("Needs \(FSRSOptimizer.minimumReviewCount) reviews from all your decks together, each on a later day than the card's previous one.")
            }
        }
        .onDisappear { task?.cancel() }
    }

    @ViewBuilder
    private var computation: some View {
        switch state {
        case .idle:
            Button("Optimize", action: start)
        case .running(let fraction):
            HStack {
                ProgressView(value: fraction)
                Button("Cancel") { task?.cancel() }
            }
        case .finished(let comparison):
            Grid(alignment: .trailing, horizontalSpacing: 16, verticalSpacing: 4) {
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    Text("Current").foregroundStyle(.secondary)
                    Text("New").foregroundStyle(.secondary)
                }
                GridRow {
                    Text("Prediction error").gridColumnAlignment(.leading)
                    Text(Self.error(comparison.current.rmse))
                    Text(Self.error(comparison.computed.rmse))
                }
                GridRow {
                    Text("Log loss")
                    Text(Self.loss(comparison.current.logLoss))
                    Text(Self.loss(comparison.computed.logLoss))
                }
            }
            .monospacedDigit()
            if !comparison.isBetter {
                Text("The current parameters already predict your reviews best.")
            } else if options.parameters == comparison.parameters {
                if appliesAtOnce {
                    Label("Used for this deck.", systemImage: "checkmark.circle")
                } else {
                    Label("Takes effect when you save.", systemImage: "checkmark.circle")
                }
            } else {
                Button("Use New Parameters") {
                    options.parameters = comparison.parameters
                    // Set by hand: the automatic update leaves them as they are.
                    options.lastAutoFit = nil
                }
            }
        case .failed:
            Text("The parameters could not be computed.")
            Button("Optimize", action: start)
        }
    }

    /// What the last automatic fit did, in a line: "Updated 22 Oct. Fitted on 2,314 reviews from all your decks.", or
    /// that it checked and kept the parameters.
    static func summary(of fit: LearningOptions.AutoFit) -> String {
        let date = fit.date.formatted(.dateTime.day().month(.abbreviated))
        if fit.adopted {
            return String(localized: "Updated \(date). Fitted on \(fit.reviewCount.formatted()) reviews from all your decks.")
        }
        return String(localized: "Checked \(date), kept: no clear gain")
    }

    private static func error(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(1)))
    }

    private static func loss(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(4)))
    }

    private func countReviews() async {
        // The form may create the row again after scrolling it out of view.
        guard reviewCount == nil else { return }
        let cards = cards
        let pool = pool
        let calendar = calendar
        let options = options
        let (all, count) = await Task.detached(priority: .userInitiated) { () -> ([Card], Int) in
            let all = cards + pool.trainingCards()
            return (all, FSRSOptimizer(cards: all, learningOptions: options, calendar: calendar).reviewCount)
        }.value
        allCards = all
        reviewCount = count
    }

    private func start() {
        let optimizer = FSRSOptimizer(cards: allCards, learningOptions: options, calendar: calendar)
        let current = options.parameters
        state = .running(0)
        task = Task {
            let (progress, continuation) = AsyncStream.makeStream(of: Double.self, bufferingPolicy: .bufferingNewest(1))
            let work = Task.detached(priority: .userInitiated) {
                defer { continuation.finish() }
                return try optimizer.compare(with: current) { continuation.yield($0) }
            }
            await withTaskCancellationHandler {
                for await fraction in progress {
                    state = .running(fraction)
                }
            } onCancel: {
                work.cancel()
            }
            switch await work.result {
            case .success(let comparison): state = .finished(comparison)
            case .failure(is CancellationError): state = .idle
            case .failure: state = .failed
            }
        }
    }
}
