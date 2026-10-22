import SwiftUI
import VocabCore

/// New cards beyond the daily limits, as "+10 new" offers them.
struct ExtraNewCards {
    /// At most `StudyStream.newCardChunk`.
    var cards: Int
    /// What they add to the cards of each day of the next week, rounded; see `NewCardLoad`.
    var reviewsPerDay: Int
}

/// The end of a round of the day, where the plan stops for a moment: "Round 1 done".
struct RoundEnd: Equatable {
    /// How many rounds are done.
    var round: Int
    /// How many the day holds.
    var rounds: Int
}

/// What the stream shows while it rests, see `StreamRestView`.
struct StreamRest {
    /// A practice from the deck screen, not the stream: it ends here.
    var isPracticeOnly: Bool
    /// What the plan of the stream did; what the practice did, for a practice.
    var recap: StudyStream.Recap
    /// When cards come back that today's plan leaves out; `nil` if no card has been studied.
    var nextDue: Date?
    var now: Date
    /// The catch-up, the overdue review cards the plan left for the days after: Keep Going works
    /// through them first.
    var catchUp = 0
    /// The catch-up, review ahead or practice has something to go on with.
    var canKeepGoing: Bool
    /// What the stream could add beyond the daily limits; `nil` if there are no new cards.
    var extraNew: ExtraNewCards?
    /// The rest is the end of a round, not the end of the plan: the plan goes on with Next Round.
    var roundEnd: RoundEnd?
}

/// The short stop in the stream: at the end of a round of the day, "Round 1 done" with what the next one
/// asks and the words the day has added to memory, and the learner goes on with Next Round or leaves with
/// Done for Now; and at the end of the plan, "Done for today" with the size of the plan, how many cards were
/// recalled and when the next one is due, the ring, and what the learner can do from here. "Keep Going" works
/// through the catch-up, then reviews ahead and practices, and is the default; the new cards beyond the daily
/// limit need a button of their own, with a line that says what they cost in cards a day. A finished
/// practice ends with its figures.
struct StreamRestView: View {
    var rest: StreamRest
    var progress: DailyProgress?
    var onKeepGoing: () -> Void
    var onAddNewCards: () -> Void
    var onNextRound: () -> Void = {}
    var onDone: () -> Void
    /// The iPhone's ring is the one that comes down from the bar (`RingTraveler`): this view only
    /// leaves its place and says where that is. The Mac draws the ring itself.
    var ringPlace: ((CGRect) -> Void)?
    /// The iPhone brings the lines in one by one, 0.1 s apart, once the ring has come (`arrived`); the
    /// Mac shows them all at once.
    var staggers = false
    var arrived = true
    /// A picture's instant: how many steps of the stagger have run.
    var frozenStep: Int?

    @State private var step = 0

    /// The title is the first step, each line one more, and the buttons the last.
    private var steps: Int { lines.count + 2 }

    private var visibleStep: Int { staggers ? (frozenStep ?? step) : .max }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ring

            title
                .padding(.top, Spacing.margin)
                .reveal(visibleStep >= 1)

            VStack(spacing: Spacing.hairline) {
                ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                    line.view
                        .reveal(visibleStep >= index + 2)
                }
            }
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .padding(.top, Spacing.tight)

            buttons
                .controlSize(.large)
                .frame(maxWidth: Metrics.buttonsWidth)
                .padding(.top, Spacing.section)
                .reveal(visibleStep >= steps)
                .allowsHitTesting(visibleStep >= steps)

            Spacer()
        }
        .padding(Spacing.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: Stagger(arrived: arrived, staggers: staggers)) {
            guard staggers, frozenStep == nil else { return }
            step = 0
            guard arrived else { return }
            for next in 1...steps {
                withAnimation(.easeOut(duration: 0.25)) { step = next }
                try? await Task.sleep(for: .seconds(0.1))
            }
        }
    }

    private struct Stagger: Hashable {
        var arrived: Bool
        var staggers: Bool
    }

    @ViewBuilder
    private var ring: some View {
        if let ringPlace {
            Color.clear
                .frame(width: 96, height: 96)
                .onGeometryChange(for: CGRect.self) {
                    $0.frame(in: .global)
                } action: {
                    ringPlace($0)
                }
                .accessibilityHidden(true)
        } else {
            DailyRingView(progress: progress, diameter: 96)
        }
    }

    private var title: some View {
        Group {
            if let end = rest.roundEnd {
                Text("Round \(end.round) done")
            } else {
                Text(rest.isPracticeOnly ? "Practice complete" : "Done for today")
            }
        }
        .font(.title.weight(.semibold))
    }

    @ViewBuilder
    private var buttons: some View {
        if let end = rest.roundEnd {
            roundEndButtons(end)
        } else {
            planEndButtons
        }
    }

    // MARK: The lines under the title

    private struct Line: Identifiable {
        let id: String
        let view: AnyView

        init(_ id: String, @ViewBuilder _ view: () -> some View) {
            self.id = id
            self.view = AnyView(view())
        }
    }

    private var lines: [Line] {
        if let end = rest.roundEnd { return roundEndLines(end) }
        return planEndLines
    }

    /// The cards the round asked: the difference of the card counts at which it and the one before end.
    private func cards(inRound round: Int) -> Int? {
        guard let ends = progress?.roundEnds, round >= 1, round <= ends.count else { return nil }
        return ends[round - 1] - (round > 1 ? ends[round - 2] : 0)
    }

    /// The iPhone: the cards of the round, the words it added, the streak, and what the next round asks.
    /// The Mac keeps its three lines in their old order.
    private func roundEndLines(_ end: RoundEnd) -> [Line] {
        let cards = staggers ? cards(inRound: end.round).map { count in Line("cards") { Text("\(count) cards this round") } } : nil
        let gain = progress?.memory.gainSentence.map { gain in Line("gain") { Text(gain) } }
        let streak =
            end.round == 1
            ? Line("streak") {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Color.appAccent)
                        .accessibilityHidden(true)
                    Text("Streak kept")
                }
            } : nil
        let next = progress?.minutes(ofRound: end.round + 1).map { minutes in Line("next") { Text("Next round \(Format.timeLeft(minutes: minutes))") } }
        return (staggers ? [cards, gain, streak, next] : [streak, next, gain]).compactMap { $0 }
    }

    private var planEndLines: [Line] {
        var lines: [Line] = []
        if rest.recap.cards > 0 {
            if rest.isPracticeOnly {
                lines.append(Line("cards") { Text("\(rest.recap.cards) cards") })
            } else {
                lines.append(Line("cards") { Text("\(rest.recap.cards) cards in today's plan") })
            }
        }
        if let accuracy = rest.recap.accuracy {
            lines.append(Line("accuracy") { Text("\(Format.percent(accuracy)) recalled") })
        }
        if !rest.isPracticeOnly, progress?.ring.isGoalMet == true {
            lines.append(Line("closed") { Text("Ring closed") })
        }
        if !rest.isPracticeOnly, let gain = progress?.memory.gainSentence {
            lines.append(Line("gain") { Text(gain) })
        }
        if !rest.isPracticeOnly, rest.catchUp > 0 {
            lines.append(Line("catchup") { Text("+\(rest.catchUp) to catch up this week") })
        } else if !rest.isPracticeOnly, let nextDue = rest.nextDue {
            lines.append(Line("next") { Text("Next review \(Format.due(nextDue, now: rest.now))") })
        }
        return lines
    }

    // MARK: The buttons

    private func roundEndButtons(_ end: RoundEnd) -> some View {
        VStack(spacing: Spacing.gap) {
            Button(action: onNextRound) {
                Text("Next Round")
                    .frame(maxWidth: .infinity, minHeight: Metrics.labelHeight)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            Button(action: onDone) {
                Text("Done for Now")
                    .frame(maxWidth: .infinity, minHeight: Metrics.labelHeight)
            }
            .buttonStyle(.bordered)
        }
    }

    private var planEndButtons: some View {
        VStack(spacing: Spacing.gap) {
            if rest.canKeepGoing {
                Button(action: onKeepGoing) {
                    Text("Keep Going")
                        .frame(maxWidth: .infinity, minHeight: Metrics.labelHeight)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            if let extra = rest.extraNew {
                VStack(spacing: Spacing.hairline) {
                    Button(action: onAddNewCards) {
                        Text("+\(extra.cards) new")
                            .frame(maxWidth: .infinity, minHeight: Metrics.labelHeight)
                    }
                    .buttonStyle(.bordered)
                    Text("≈ +\(extra.reviewsPerDay) cards/day next week")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Button(action: onDone) {
                Text("Done")
                    .frame(maxWidth: .infinity, minHeight: Metrics.labelHeight)
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(rest.canKeepGoing ? nil : .defaultAction)
        }
    }

    /// The gaps are from `Spacing`: 16 from the ring to the title, 8 to the figures, 24 to the
    /// buttons, 12 between buttons, 16 round all of it. On the iPhone the buttons are as wide
    /// as the card was and as high as the grade buttons were, 48 pt.
    private enum Metrics {
        #if os(macOS)
        static let labelHeight: CGFloat = 28
        static let buttonsWidth: CGFloat = 320
        #else
        static let labelHeight: CGFloat = 0
        static let buttonsWidth: CGFloat = 400
        #endif
    }
}

extension View {
    /// Comes in with a fade and a small lift, when `isShown`.
    fileprivate func reveal(_ isShown: Bool) -> some View {
        opacity(isShown ? 1 : 0)
            .offset(y: isShown ? 0 : 6)
    }
}
