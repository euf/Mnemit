import SwiftUI
import VocabCore

/// New cards beyond the daily limits, as "+10 new" offers them.
struct ExtraNewCards {
    /// At most `StudyStream.newCardChunk`.
    var cards: Int
    /// What they add to the cards of each day of the next week, rounded; see `NewCardLoad`.
    var reviewsPerDay: Int
}

/// Where the plan stops for a moment: at the end of the first round, which keeps the streak, or at the end
/// of the last, which closes the ring while the plan has cards beyond it.
struct RoundEnd: Equatable {
    /// How many rounds are done.
    var round: Int
    /// How many the day holds.
    var rounds: Int

    /// The rest closes the ring; otherwise it keeps the streak.
    var closesRing: Bool { round >= rounds }
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

/// The short stop in the stream, twice a day at most (`references/learning-flow.md`). "Streak kept" after
/// the first round: the streak, the words the day has added, the cards left to the ring; Keep Going or Done
/// for Now. "Ring closed" when today's cards are done: the cards and the answers they took, the share
/// recalled, the words, the streak and the week's rings, then one way on, the most useful first: Catch Up
/// when due cards are left, else the new cards beyond the daily limit with what they cost in cards a day,
/// else practice. A finished practice ends with its figures.
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
            if rest.isPracticeOnly {
                Text("Practice complete")
            } else if let end = rest.roundEnd, !end.closesRing {
                Text("Streak kept")
            } else if progress?.ring.isGoalMet == true {
                Text("Ring closed")
            } else {
                Text("Done for today")
            }
        }
        .font(.title.weight(.semibold))
    }

    @ViewBuilder
    private var buttons: some View {
        if let end = rest.roundEnd {
            if end.closesRing { ringButtons } else { streakButtons }
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
        if rest.isPracticeOnly { return practiceLines }
        if let end = rest.roundEnd, !end.closesRing { return [streakLine, gainLine, leftLine].compactMap { $0 } }
        return dayLines
    }

    private var practiceLines: [Line] {
        var lines: [Line] = []
        if rest.recap.cards > 0 {
            lines.append(Line("cards") { Text("\(rest.recap.cards) cards") })
        }
        if let accuracy = rest.recap.accuracy {
            lines.append(Line("accuracy") { Text("\(Format.percent(accuracy)) recalled") })
        }
        return lines
    }

    /// The day: "10 cards · 22 answers", the share recalled, the words or their milestone, the streak, the
    /// week's rings, and the catch-up or when cards come back.
    private var dayLines: [Line] {
        var lines: [Line] = []
        if rest.recap.cards > 0 {
            let cards = [String(localized: "\(rest.recap.cards) cards"), String(localized: "\(rest.recap.reviews) answers")]
            lines.append(Line("cards") { Text(verbatim: cards.joined(separator: " · ")) })
        }
        if let accuracy = rest.recap.accuracy {
            lines.append(Line("accuracy") { Text("\(Format.percent(accuracy)) recalled") })
        }
        if let milestone = progress?.memory.milestoneLine {
            lines.append(Line("milestone") { Text(milestone).foregroundStyle(Color.appAccent) })
        } else if let gainLine {
            lines.append(gainLine)
        }
        if let streakLine { lines.append(streakLine) }
        if let progress, progress.week.count == 7 {
            lines.append(Line("week") { WeekRings(week: progress.week, today: progress.ring.fraction, now: rest.now).padding(.vertical, Spacing.tight) })
        }
        if let progress, progress.ladder.reduce(0, +) > 0 {
            lines.append(
                Line("ladder") {
                    VStack(spacing: Spacing.hairline) {
                        LadderBar(ladder: progress.ladder)
                            .frame(maxWidth: 240)
                        if progress.climbedToday > 0 {
                            Text("+\(progress.climbedToday) climbed today")
                        }
                    }
                })
        }
        if rest.catchUp > 0 {
            lines.append(Line("catchup") { Text("+\(rest.catchUp) to catch up this week") })
        } else if let nextDue = rest.nextDue {
            lines.append(Line("next") { Text("Next review \(Format.due(nextDue, now: rest.now))") })
        }
        return lines
    }

    private var streakLine: Line? {
        guard let days = progress?.streak.days, days > 0 else { return nil }
        return Line("streak") {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Color.appAccent)
                    .accessibilityHidden(true)
                Text("\(days)-day streak")
            }
        }
    }

    private var gainLine: Line? {
        progress?.memory.gainSentence.map { gain in Line("gain") { Text(gain) } }
    }

    /// "12 cards left · ≈ 4 min": what is left to the ring.
    private var leftLine: Line? {
        guard let progress, progress.cardsLeft > 0 else { return nil }
        let left = String(localized: "\(progress.cardsLeft) cards left")
        let text = progress.minutesLeft.map { "\(left) · \(Format.timeLeft(minutes: $0))" } ?? left
        return Line("left") { Text(verbatim: text) }
    }

    // MARK: The buttons

    @ViewBuilder
    private func button(_ title: LocalizedStringKey, prominent: Bool, action: @escaping () -> Void) -> some View {
        let button = Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, minHeight: Metrics.labelHeight)
        }
        if prominent {
            button.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    private var streakButtons: some View {
        VStack(spacing: Spacing.gap) {
            button("Keep Going", prominent: true, action: onNextRound)
            button("Done for Now", prominent: false, action: onDone)
        }
    }

    /// The ring is closed and the plan has cards beyond it, as after a break: they are the catch-up.
    private var ringButtons: some View {
        VStack(spacing: Spacing.gap) {
            button("Catch Up", prominent: true, action: onNextRound)
            button("Done", prominent: false, action: onDone)
        }
    }

    private var planEndButtons: some View {
        let catchesUp = rest.canKeepGoing && rest.catchUp > 0
        return VStack(spacing: Spacing.gap) {
            if catchesUp {
                button("Catch Up", prominent: true, action: onKeepGoing)
            }
            if let extra = rest.extraNew {
                VStack(spacing: Spacing.hairline) {
                    button("+\(extra.cards) new", prominent: !catchesUp, action: onAddNewCards)
                    Text("≈ +\(extra.reviewsPerDay) cards/day next week")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            if rest.canKeepGoing, !catchesUp {
                button("Practice", prominent: false, action: onKeepGoing)
            }
            button("Done", prominent: !catchesUp && rest.extraNew == nil, action: onDone)
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

/// The rings of the last seven study days, today last, each with the initial of its weekday: closed,
/// open, or faint before the first study day. Today's as it stands.
struct WeekRings: View {
    var week: [Bool?]
    /// Today's ring, 1 when closed.
    var today: Double
    var now: Date

    var body: some View {
        HStack(spacing: 10) {
            ForEach(week.indices, id: \.self) { index in
                VStack(spacing: 4) {
                    ProgressRing(fraction: fraction(index), diameter: 20)
                        .opacity(week[index] == nil ? 0.35 : 1)
                    Text(verbatim: letter(index))
                        .font(.caption2.weight(index == week.count - 1 ? .bold : .regular))
                        .foregroundStyle(index == week.count - 1 ? .primary : .secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(week.filter { $0 == true }.count) of 7 rings closed this week"))
    }

    private func fraction(_ index: Int) -> Double {
        index == week.count - 1 ? min(1, today) : (week[index] == true ? 1 : 0)
    }

    /// The weekday's initial, "M"; the study day starts at 04:00.
    // ponytail: the rollover hour is fixed at 4 here; pass the deck's calendar if it ever moves.
    private func letter(_ index: Int) -> String {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: index - (week.count - 1), to: now.addingTimeInterval(-4 * 3600)) ?? now
        return calendar.veryShortWeekdaySymbols[calendar.component(.weekday, from: day) - 1]
    }
}

/// The ladder of memory: the cards by step of `MaturityCategory`, new on the left to mastered on the right, as
/// one bar of segments in the ramp's colours (`references/learning-flow.md`, "Progression").
struct LadderBar: View {
    var ladder: [Int]
    var height: CGFloat = 8

    private var steps: [(step: MaturityCategory, count: Int)] {
        MaturityCategory.allCases.map { ($0, $0.rawValue < ladder.count ? ladder[$0.rawValue] : 0) }.filter { $0.count > 0 }
    }

    var body: some View {
        let total = CGFloat(max(1, ladder.reduce(0, +)))
        GeometryReader { proxy in
            HStack(spacing: 1) {
                ForEach(steps, id: \.step) { part in
                    Rectangle()
                        .fill(part.step.color)
                        .frame(width: max(2, (proxy.size.width - CGFloat(steps.count - 1)) * CGFloat(part.count) / total))
                }
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: steps.map { "\($0.step.title) \($0.count)" }.joined(separator: ", ")))
    }
}
