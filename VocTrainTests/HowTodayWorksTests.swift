import SwiftUI
import Testing

@testable import VocTrain
@testable import VocabCore

/// "How It Works": the rows the figures of the objects make, and the sheet drawn to a PNG with
/// the other home screens (`HomeSnapshotTests.directory`).
@MainActor
struct HowTodayWorksTests {
    static let day = Date(timeIntervalSince1970: 1_791_216_000)

    /// A deck with its own limits and a fit that was kept.
    static var options: LearningOptions {
        var options = LearningOptions()
        options.newCardsPerSession = 20
        options.lastAutoFit = LearningOptions.AutoFit(date: day, reviewCount: 2314, adopted: true)
        return options
    }

    /// Eight minutes of a plan of 28 cards that are not new and six that are, at the default pace: the streak
    /// step ends at card 12 and the day at 34.
    static var progress: DailyProgress {
        DailyProgress(
            ring: DailyRing(done: 18, goal: 34), streak: Streak(days: 12, repairCards: nil), cardsLeft: 22, newCardsLeft: 5,
            pace: Pace(newCard: 31.4, otherCard: 9.2), time: 480,
            roundPlan: DayRounds(otherCards: 28, newCards: 12, pace: Pace(), seconds: 480), streakKeptToday: true, newCardAllowances: [6])
    }

    static var breakdown: DayBreakdown {
        let days = [
            DayBreakdown.Day(start: day.addingTimeInterval(-2 * 86400), time: 240, isClosed: true, worked: 360, reason: .start),
            DayBreakdown.Day(start: day.addingTimeInterval(-86400), time: 258, isClosed: false, worked: 300, reason: .ringClosed),
            DayBreakdown.Day(start: day, time: 199.95, isClosed: false, worked: 150, reason: .ringOpen),
        ]
        return DayBreakdown(
            plan: DayBreakdown.Plan(reviewsDue: 28, learning: 2, newAdmitted: 6),
            decks: [DayBreakdown.DeckNewCards(allowance: 6, ceiling: 27, admitted: 6)], days: days,
            newCards: DayBreakdown.PaceBasis(durations: 214, gaps: 120, reviews: 500, doneCards: 200),
            otherCards: DayBreakdown.PaceBasis(durations: 5, gaps: 12, reviews: 40, doneCards: 40))
    }

    static var memory: MemoryEstimate { MemoryEstimate(words: 412.37, wordsAtDayStart: 411.53) }

    static var swipes: SwipeTally.Counts { SwipeTally.Counts(graded: 38, gapMisses: 3) }

    static func content(decks: [HowTodayWorks.DeckInfo] = [HowTodayWorks.DeckInfo(name: "Greek B1", options: options)]) -> HowTodayWorks {
        HowTodayWorks(progress: progress, breakdown: breakdown, memory: memory, swipes: swipes, decks: decks)
    }

    /// The figures of a section by their labels.
    func values(_ section: HowTodayWorks.Section) -> [String: String] {
        var values: [String: String] = [:]
        for case let .value(label, value, _) in section.rows { values[label] = value }
        return values
    }

    @Test func theRowsAreTheFiguresOfTheObjectsInTheOrderOfTheScreen() throws {
        let content = Self.content()
        #expect(content.sections.map(\.title) == ["Today", "Today's Plan", "Today's time", "Pace", "Streak", "Words in Memory", "Swipes", "Options", "FSRS"])
        // The first section is three plain sentences, with no rule under them: the ring, Catch Up, Learn 10 New Words.
        let today = content.sections[0]
        #expect(today.footer.isEmpty)
        #expect(today.rows.count == 3)
        #expect(today.rows.allSatisfy { if case .text = $0 { true } else { false } })
        // Like "Today", the options are only sentences, with no rule under them.
        #expect(content.sections.dropFirst().allSatisfy { $0.title == "Options" || !$0.footer.isEmpty })

        let plan = values(content.sections[1])
        #expect(plan["Due today, overdue included"] == "28")
        #expect(plan["Overdue cards taken"] == nil)
        #expect(plan["Cards in learning"] == "2")
        #expect(plan["New cards admitted"] == "6")
        // The plan has no row for a bound on the new cards: the day's time is the only one, told in its own section.
        #expect(plan.keys.filter { $0.hasPrefix("New cards: limited") }.isEmpty)
        #expect(plan["Greek B1"] == "6")
        #expect(content.sections[1].rows.contains(.value(label: "Greek B1", value: "6", note: "Ceiling 27 (limits 20 new / 7 production)")))
        #expect(plan["Cards done"] == "18")
        #expect(plan["Cards left"] == "22")
        #expect(plan["Catch-up beyond the plan"] == nil)

        let time = content.sections[2]
        #expect(values(time)["Time of the day"] == "\((8.0).formatted(.number.precision(.fractionLength(1)))) min")
        #expect(values(time)["Streak step (cards)"] == "12")
        #expect(values(time)["Daily goal (cards)"] == "34")
        let table = try #require(time.rows.compactMap { row -> ([String], [[String]])? in if case let .table(header, rows) = row { (header, rows) } else { nil } }.first)
        #expect(table.0 == ["Day", "Asked (min)", "Worked (min)", "Ring", "Why"])
        // The newest day first: the minutes the ring asked and the minutes worked, the ring, and why the time.
        let earlier = Self.day.addingTimeInterval(-86400).formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        #expect(table.1.map { $0[0] }.first == "Today" && table.1.map { $0[0] }[1] == earlier)
        func one(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(1))) }
        #expect(
            table.1.map { Array($0.dropFirst()) } == [
                [one(199.95 / 60), one(2.5), "Open", "Ring open"], [one(258.0 / 60), one(5), "Open", "Ring closed"], [one(4), one(6), "Closed", "Start"],
            ])
        // The footer names the direction of the time, never the rule's factors.
        #expect(time.footer.hasPrefix("The time follows your days"))
        #expect(time.footer.contains("a ring closed on a plan smaller than the time or a day without study leaves it as it was"))
        #expect(!time.footer.contains("%"))
        #expect(time.footer.contains("two and a half minutes before any study"))

        let pace = content.sections[3].rows
        #expect(pace[0] == .value(label: "New card", value: "31 s", note: "Durations (214)"))
        #expect(pace[1] == .value(label: "Reviews per new card", value: (2.5).formatted(.number.precision(.fractionLength(2)))))
        // Five timed answers and twelve gaps are under twenty: the price is the default.
        #expect(pace[2] == .value(label: "Other card", value: "9 s", note: "Default"))
        #expect(pace[3] == .value(label: "Reviews per other card", value: (1.0).formatted(.number.precision(.fractionLength(2)))))

        #expect(values(content.sections[4]) == ["Days": "12", "Today": "Kept"])

        let words = values(content.sections[5])
        #expect(words["In memory now"] == (412.37).formatted(.number.precision(.fractionLength(2))))
        #expect(words["At the start of the day"] == (411.53).formatted(.number.precision(.fractionLength(2))))
        #expect(words["Gain today"]?.hasPrefix("+") == true)
        #expect(words["Next milestone"] == "500")

        // The swipes: the gap misses of all that tried, and the sectors in compass degrees in the rule.
        let swipes = content.sections[6]
        #expect(swipes.rows == [.value(label: "Swipes that sprang back from a gap", value: "3 of 41 today")])
        // They are the constants of `GradeSwipe`, in compass degrees (90 - the code's angle, modulo 360).
        func bearing(_ math: Double) -> Int { Int((90 - math).truncatingRemainder(dividingBy: 360) + 360) % 360 }
        let sectors = [
            "Easy \(bearing(GradeSwipe.easyEnd))° to \(bearing(GradeSwipe.goodReach))°",
            "Good \(bearing(GradeSwipe.goodReach))° to \(bearing(-GradeSwipe.goodReach))°",
            "Hard \(bearing(-GradeSwipe.goodReach))° to \(bearing(GradeSwipe.hardStart))°",
            "Forgot \(bearing(GradeSwipe.forgotEnd))° to \(bearing(GradeSwipe.forgotStart))°",
            "\(bearing(GradeSwipe.hardStart))° to \(bearing(GradeSwipe.forgotEnd))° or "
                + "\(bearing(GradeSwipe.forgotStart))° to \(bearing(GradeSwipe.easyEnd))°",
        ]
        for sector in sectors {
            #expect(swipes.footer.contains(sector), "\(sector)")
        }

        let fsrs = content.sections[8]
        #expect(values(fsrs)["Target recall"] == Format.percent(0.9))
        #expect(values(fsrs)["Parameters"] == "Default")
        #expect(values(fsrs)["Steps per card"] == "2")
        #expect(values(fsrs)["Last automatic fit"]?.hasPrefix("Updated") == true)
        // The 21 weights, four decimals, as the default parameters have them.
        let numbers = try #require(fsrs.rows.compactMap { row -> String? in if case let .numbers(text) = row { text } else { nil } }.first)
        #expect(numbers.split(separator: " ").count == FSRSParameters.count)
        #expect(numbers.hasPrefix("0.2120 1.2931 2.3065 8.2956"))
    }

    @Test func aStreakToRepairAndDecksWithoutNamesAreTold() {
        var progress = Self.progress
        progress.streak = Streak(days: 5, repairCards: 7)
        progress.streakKeptToday = false
        var fitted = LearningOptions()
        fitted.parameters = FSRSParameters([Double](repeating: 0.5, count: FSRSParameters.count))!
        let content = HowTodayWorks(
            progress: progress, breakdown: Self.breakdown, memory: Self.memory, swipes: nil,
            decks: [HowTodayWorks.DeckInfo(name: nil, options: LearningOptions()), HowTodayWorks.DeckInfo(name: "Greek", options: fitted)])
        #expect(values(content.sections[4]) == ["Days": "5", "Today": "Not yet", "Cards to repair yesterday": "7"])
        // Where nothing is swiped (the Mac) there is no section of swipes.
        #expect(content.sections.map(\.title) == ["Today", "Today's Plan", "Today's time", "Pace", "Streak", "Words in Memory", "Options", "FSRS · Deck 1", "FSRS · Greek"])
        #expect(values(content.sections[7])["Parameters"] == "Default")
        #expect(values(content.sections[8])["Parameters"] == "Fitted")
        #expect(values(content.sections[8])["Last automatic fit"] == "None yet")
    }

    /// The options section says in sentences what the one-line footers of the Options screen leave out: the rules
    /// for any learner, not for one language, and with the fit schedule read from `ParameterRefit`.
    @Test func theOptionsAreSevenSentencesInPlainWords() throws {
        let options = try #require(Self.content().sections.first { $0.title == "Options" })
        let sentences = options.rows.compactMap { row -> String? in if case let .text(text) = row { text } else { nil } }
        #expect(sentences.count == 7)
        #expect(options.rows.count == 7)
        #expect(options.footer.isEmpty)
        for word in ["Greek", "production", "recognition"] {
            #expect(sentences.allSatisfy { !$0.localizedCaseInsensitiveContains(word) }, "\(word)")
        }
        #expect(sentences.allSatisfy { !$0.contains("%@") })
        #expect(sentences[1].contains(Format.percent(0.9)))
        let first = ParameterRefit.minimumReviewCount.formatted()
        let second = ParameterRefit.secondFitReviewCount.formatted()
        let step = ParameterRefit.reviewStep.formatted()
        #expect(sentences[6].contains("\(first) reviews, again at \(second), then every 30 days or after \(step) more reviews"))
    }

    /// A ring closed on a plan smaller than its time is told as "Plan under the time" in the days' table.
    @Test func aRingClosedOnASmallPlanIsToldWhy() throws {
        var breakdown = Self.breakdown
        breakdown.days[1] = DayBreakdown.Day(start: Self.day.addingTimeInterval(-86400), time: 240, isClosed: true, worked: 200, reason: .smallPlan)
        let content = HowTodayWorks(progress: Self.progress, breakdown: breakdown, memory: Self.memory, swipes: nil, decks: [])
        let table = try #require(content.sections[2].rows.compactMap { row -> [[String]]? in if case let .table(_, rows) = row { rows } else { nil } }.first)
        #expect(table.map { $0.last } == ["Ring open", "Plan under the time", "Start"])
    }

    /// A paused deck is named in the plan as "Paused: <name>", with no share of the new cards, and the figures are
    /// those of the decks that take part; its FSRS settings are still shown.
    @Test func aPausedDeckIsNamedInThePlanAndLeftOutOfTheFigures() throws {
        let cards = (0..<10).map { Card(text: CardText(question: "n\($0)", answer: "x")!, created: Self.day.addingTimeInterval(-86_400)) }
        var pausedOptions = LearningOptions()
        pausedOptions.isPaused = true
        let taking = HowTodayWorks.Source(name: "Greek B1", deck: try Deck(cards: cards))
        let paused = HowTodayWorks.Source(name: "Greek B2", deck: try Deck(learningOptions: pausedOptions, cards: cards))
        let content = HowTodayWorks.make([taking, paused], at: Self.day, calendar: StudyCalendar(), swipes: nil)
        let alone = HowTodayWorks.make([taking], at: Self.day, calendar: StudyCalendar(), swipes: nil)

        let pausedRow = HowTodayWorks.Row.value(label: "Paused: Greek B2", value: "–")
        #expect(content.sections[1].rows.contains(pausedRow))
        #expect(values(content.sections[1])["Greek B2"] == nil)
        #expect(content.sections[1].rows.filter { $0 != pausedRow } == alone.sections[1].rows)
        #expect(content.sections[2...5] == alone.sections[2...5])
        #expect(content.sections.suffix(2).map(\.title) == ["FSRS · Greek B1", "FSRS · Greek B2"])
    }

    /// A drawing of the whole sheet in one, 6,400 pixels tall, came out blank: it is drawn in two, the plan, the
    /// capacity and the pace, then the rest.
    @Test func theSheetIsDrawnToAPNG() async throws {
        let content = Self.content()
        try await HomeSnapshotTests().shoot("how-today-works-1", HowTodayWorksSheet(content: content, done: {}), height: 1700)
        var rest = content
        rest.sections.removeFirst(4)
        try await HomeSnapshotTests().shoot("how-today-works-2", HowTodayWorksSheet(content: rest, done: {}), height: 1700)
    }
}
