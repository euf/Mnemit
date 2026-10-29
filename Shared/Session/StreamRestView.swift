import SwiftUI
import VocabCore

/// New cards beyond the daily limits, as Learn 10 New Words adds them to a stack that is done for the day.
struct ExtraNewCards {
    /// At most `StudyStream.newCardChunk`.
    var cards: Int
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
    /// What the stream could add beyond the daily limits; `nil` if there are no new cards.
    var extraNew: ExtraNewCards?
    /// The rest is the end of a round, not the end of the plan: the plan goes on with Next Round.
    var roundEnd: RoundEnd?
    /// The ring's moment is behind the stream: it began past the last round, or went on from its rest (Catch Up, Learn 10 New
    /// Words). The end of its plan is then "All done for today", not another "Ring closed".
    var ringIsBehind = false
}

/// Another deck with cards left in today's plan, which the Mac's stream, one deck to a window, goes on with at the
/// end of this deck's plan: "Study Greek B1 · 14 cards". The iPhone's stream mixes the decks and has none.
struct NextDeck {
    var name: String
    var cards: Int
    var study: () -> Void
}

/// The short stop in the stream, twice a day at most (`references/learning-flow.md`). The ring on top is a picture, with no
/// number in it, and under it the streak, "12-day streak". After the first round the title is the streak, "12-day streak",
/// with the filled flame large (the streak's moment, so nothing under the ring), and the time to the ring ("≈ 5 min to
/// close the ring", the price line of the sentence, `NextStep`); Keep Going or Done for Now. "Ring closed" when the day's
/// goal is done, with the minutes of the reviews left: the medal, the words learned and the week's rings, then one way
/// on, the most useful first: Catch Up when the plan has cards left, else Learn 10 New Words, new cards beyond the daily
/// limit, whose reviews make the next days harder. "All done for today" when the plan is. A finished practice ends with
/// its figures.
struct StreamRestView: View {
    var rest: StreamRest
    var progress: DailyProgress?
    var onAddNewCards: () -> Void
    var onNextRound: () -> Void = {}
    var onDone: () -> Void
    /// The deck to go on with at the end of the plan, on the Mac.
    var nextDeck: NextDeck?
    /// The iPhone's ring is the one that comes down from the bar (`RingTraveler`): this view only
    /// leaves its place and says where that is. The Mac draws the ring itself.
    var ringPlace: ((CGRect) -> Void)?
    /// The iPhone brings the lines in one by one, 0.1 s apart, once the ring has come (`arrived`); the
    /// Mac shows them all at once.
    var staggers = false
    var arrived = true
    /// A picture's instant: how many steps of the stagger have run.
    var frozenStep: Int?

    /// Where the medals shown here are marked as celebrated.
    var medals: CelebratedMedals = .shared

    @State private var step = 0
    /// The burst of the flame in the title of the streak rest, when the title comes in.
    @State private var flameBurstAt: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The title is the first step, each line one more, and the buttons the last.
    private var steps: Int { lines.count + 2 }

    private var visibleStep: Int { staggers ? (frozenStep ?? step) : .max }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ring

            chip
                .padding(.top, Spacing.gap)
                .reveal(visibleStep >= 1)

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
        // The medals of today are shown here, so they are celebrated.
        .onChange(of: earnedToday, initial: true) {
            if let today = progress?.records.last?.day, let all = progress?.achievements { medals.markToday(in: all, today: today) }
        }
        // The streak step is done: the flame in the title bursts as it comes in.
        .onChange(of: visibleStep >= 1, initial: true) { _, isShown in
            if isShown, isStreakRest, frozenStep == nil, !reduceMotion { flameBurstAt = .now }
        }
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

    /// The streak under the ring, the flame and "12-day streak": not in a practice, which leaves it as it was, not without
    /// a streak, and not at the end of the first round, whose title is the streak.
    @ViewBuilder
    private var chip: some View {
        if let progress, !rest.isPracticeOnly, rest.roundEnd?.closesRing ?? true, progress.streak.days > 0 {
            StreakLine(step: NextStep(progress), font: .subheadline.weight(.semibold))
                .imageScale(.large)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.streak.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var title: some View {
        Group {
            if rest.isPracticeOnly {
                Text("Practice complete")
            } else if let end = rest.roundEnd, !end.closesRing {
                streakTitle
            } else if progress?.ring.isGoalMet == true, !rest.ringIsBehind {
                if progress?.records.last?.savedStreak == true {
                    Text("Streak saved")
                } else {
                    Text("Ring closed")
                }
            } else {
                Text("All done for today")
            }
        }
        .font(.title.weight(.semibold))
        .multilineTextAlignment(.center)
    }

    /// The end of the first round: its title is the streak.
    private var isStreakRest: Bool {
        !rest.isPracticeOnly && rest.roundEnd.map { !$0.closesRing } == true
    }

    /// The streak, "12-day streak", with the filled flame large; on the day a streak milestone passed, its name.
    private var streakTitle: some View {
        HStack(spacing: Spacing.tight) {
            RingBurst(startedAt: flameBurstAt, diameter: 36) {
                StreakFlame(state: .kept)
                    .font(.largeTitle)
            }
            if let milestone = milestoneToday {
                Text(verbatim: milestone.title)
            } else if let days = progress?.streak.days, days > 0 {
                Text("\(days)-day streak")
            } else {
                Text("Streak kept")
            }
        }
    }

    /// What was earned today, oldest first: the achievements of the last day of `DailyProgress.records`.
    private var earnedToday: [Achievement] {
        guard let progress, let today = progress.records.last?.day else { return [] }
        return progress.achievements.filter { $0.day == today }
    }

    /// The streak milestone reached today, which gives the Streak kept rest its title.
    private var milestoneToday: AchievementKind? {
        earnedToday.last { $0.kind.line == .streak }?.kind
    }

    /// The most notable medal earned today at 56 pt with its name under it, and "+2 more" when there were others.
    /// The streak kept rest names the milestone in its title, so the medal comes without a name there.
    private var medalLine: Line? {
        guard let (medal, others) = earnedToday.featured else { return nil }
        let isTitle = rest.roundEnd.map { !$0.closesRing } == true && medal.line == .streak
        return Line("medal") {
            VStack(spacing: Spacing.hairline) {
                MedalDisc(kind: medal, size: 56)
                if !isTitle {
                    Text(verbatim: medal.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                if others > 0 {
                    Text("+\(others) more")
                        .font(.caption2)
                }
            }
            .padding(.vertical, Spacing.tight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                Text(verbatim: [medal.title, medal.detail, others > 0 ? String(localized: "+\(others) more") : nil].compactMap { $0 }.joined(separator: ", ")))
        }
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
        if let end = rest.roundEnd, !end.closesRing { return [medalLine, priceLine].compactMap { $0 } }
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

    /// The day: its medal, the price of the reviews left after the ring (Catch Up's), the words learned and the week's rings.
    private var dayLines: [Line] {
        var lines: [Line] = []
        if let medalLine { lines.append(medalLine) }
        if rest.roundEnd != nil, let priceLine { lines.append(priceLine) }
        if let gain = progress?.learned.line {
            lines.append(Line("gain") { Text(verbatim: gain) })
        }
        if let progress, progress.week.count == 7 {
            lines.append(Line("week") { WeekRings(week: progress.week, rings: progress.weekRings, today: DailyRingFigure.fraction(progress, shown: nil), now: rest.now).padding(.vertical, Spacing.tight) })
        }
        return lines
    }

    /// The sentence of the next moment (`NextStep`) under the title, which has the streak and the moment: "≈ 4 min to close
    /// the ring" at the streak's moment, "≈ 12 min of reviews left" at the ring's. `nil` without a price.
    private var priceLine: Line? {
        guard let progress, let price = NextStep(progress).priceLine else { return nil }
        return Line("price") { Text(verbatim: NextStep.unbroken(price, endTogether: true)) }
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

    /// The ring is closed and the plan has cards left: Keep Going goes on with them, the default as at the streak's rest,
    /// since a learner who has just closed the ring mostly finishes the few reviews left.
    private var ringButtons: some View {
        VStack(spacing: Spacing.gap) {
            button("Keep Going", prominent: true, action: onNextRound)
            button("Done for Now", prominent: false, action: onDone)
        }
    }

    /// The stack is done for the day: Done, and under it Learn 10 New Words when the decks have new cards left.
    private var planEndButtons: some View {
        VStack(spacing: Spacing.gap) {
            if let nextDeck {
                button("Study \(nextDeck.name) · \(nextDeck.cards) cards", prominent: true, action: nextDeck.study)
            }
            button("Done", prominent: nextDeck == nil, action: onDone)
            if rest.extraNew != nil {
                button("Learn 10 New Words", prominent: false, action: onAddNewCards)
            }
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

/// The rings of the last seven study days, today last, each with the initial of its weekday: each day's own
/// share of its goal, or faint before the first study day. Today's as it stands.
struct WeekRings: View {
    var week: [Bool?]
    /// The past days' shares of their goals (`DailyProgress.weekRings`). Without it a past day is full when it
    /// closed and empty otherwise, which is all the widget's week keeps.
    var rings: [Double?]? = nil
    /// Today's ring in laps of the goal, 1 when closed (`DailyRingFigure.fraction`).
    var today: Double
    var now: Date
    /// The weekday initials under the rings; the widget leaves them out.
    var showsLetters = true
    /// 22 pt on the screens; the widget's week is smaller.
    var diameter: CGFloat = 22
    var spacing: CGFloat = 10

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(week.indices, id: \.self) { index in
                VStack(spacing: 4) {
                    ProgressRing(fraction: Self.fraction(index, week: week, rings: rings, today: today), diameter: diameter)
                        .opacity(week[index] == nil ? 0.35 : 1)
                    if showsLetters {
                        Text(verbatim: letter(index))
                            .font(.caption2.weight(index == week.count - 1 ? .bold : .regular))
                            .foregroundStyle(index == week.count - 1 ? .primary : .secondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(week.indices.filter { Self.isClosed($0, week: week, rings: rings) }.count) of 7 rings closed this week"))
    }

    /// How full the ring of day `index` is drawn: today's as it stands, a past day's by its own share, else by
    /// whether it closed.
    static func fraction(_ index: Int, week: [Bool?], rings: [Double?]?, today: Double) -> Double {
        if index == week.count - 1 { return min(ProgressRing.maxLaps, today) }
        if let rings, rings.indices.contains(index), let share = rings[index] { return share }
        return week[index] == true ? 1 : 0
    }

    private static func isClosed(_ index: Int, week: [Bool?], rings: [Double?]?) -> Bool {
        index == week.count - 1 ? week[index] == true : fraction(index, week: week, rings: rings, today: 0) >= 1
    }

    /// The weekday's initial, "M"; the study day starts at 04:00.
    // ponytail: the rollover hour is fixed at 4 here; pass the deck's calendar if it ever moves.
    private func letter(_ index: Int) -> String {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: index - (week.count - 1), to: now.addingTimeInterval(-4 * 3600)) ?? now
        return calendar.veryShortWeekdaySymbols[calendar.component(.weekday, from: day) - 1]
    }
}

/// The ladder of memory: the cards started by step of `MaturityCategory`, the youngest on the left to mastered on
/// the right, as one bar of segments in the ramp's colours (`references/learning-flow.md`, "Progression"). The
/// cards not started are not in it, as they would drown the cards studied; with none started the bar is one empty track.
struct LadderBar: View {
    var ladder: [Int]
    var height: CGFloat = 8

    private var steps: [(step: MaturityCategory, count: Int)] {
        MaturityCategory.allCases.filter { $0 != .new }.map { ($0, $0.rawValue < ladder.count ? ladder[$0.rawValue] : 0) }.filter { $0.count > 0 }
    }

    var body: some View {
        let total = CGFloat(max(1, steps.reduce(0) { $0 + $1.count }))
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
        .background(Color.secondary.opacity(0.15))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: steps.map { "\($0.step.title) \($0.count)" }.joined(separator: ", ")))
        .accessibilityHidden(steps.isEmpty)
    }
}
