import Foundation
import VocabCore

/// The content of "How Today Works", the screen that shows a learner who knows Anki and FSRS what is under
/// the ring and the rounds: the numbers and the rules, read from the same objects the Today screen
/// shows (`DailyProgress`, `DayBreakdown`, `MemoryEstimate`, the decks' learning options) and nothing
/// else. Read-only, no knobs.
///
/// Built into sections of rows that are already text, so a test can compare them and the view only lays
/// them out. The sections come in the order of the screen: the plan, the day's time, the pace, the
/// streak, the words in memory, the swipes (where the screen has them: the iPhone), then the FSRS
/// settings of each deck. A section's footer is its rule.
struct HowTodayWorks: Equatable, Sendable {
    enum Row: Equatable, Sendable {
        /// A figure, with a line under it when it needs one.
        case value(label: String, value: String, note: String? = nil)
        /// Numbers to read as they are, in a monospaced font and wrapped.
        case numbers(String)
        /// The last days, one row each, the first of `rows` the newest.
        case table(header: [String], rows: [[String]])
    }

    struct Section: Equatable, Sendable {
        var title: String
        var rows: [Row]
        /// The rule, in a line or three.
        var footer: String
    }

    /// A deck of the screen: its name, which the Mac does not know, and its learning options.
    struct DeckInfo: Equatable, Sendable {
        var name: String?
        var options: LearningOptions
    }

    var sections: [Section]

    /// `swipes` is what `SwipeTally` counted today; `nil` where nothing is swiped (the Mac), so there is no section.
    init(progress: DailyProgress, breakdown: DayBreakdown, memory: MemoryEstimate, swipes: SwipeTally.Counts?, decks: [DeckInfo]) {
        sections =
            [
                Self.plan(progress, breakdown, decks),
                Self.time(progress, breakdown),
                Self.pace(progress, breakdown),
                Self.streak(progress),
                Self.wordsInMemory(memory),
            ] + (swipes.map { [Self.swipes($0)] } ?? [])
            + decks.indices.map { Self.fsrs(decks[$0], position: $0, of: decks.count) }
    }

    // MARK: Sections

    private static func plan(_ progress: DailyProgress, _ breakdown: DayBreakdown, _ decks: [DeckInfo]) -> Section {
        let plan = breakdown.plan
        var rows: [Row] = [
            .value(label: String(localized: "Reviews due today"), value: plan.reviewsDue.formatted()),
            .value(label: String(localized: "Overdue cards taken"), value: String(localized: "\(plan.backlogTaken) of \(plan.backlog)")),
            .value(label: String(localized: "Cards in learning"), value: plan.learning.formatted()),
            .value(label: String(localized: "New cards admitted"), value: plan.newAdmitted.formatted()),
        ]
        for (index, deck) in decks.enumerated() where breakdown.decks.indices.contains(index) {
            // A paused deck is no part of the plan: it is named, with no share.
            if deck.options.isPaused {
                rows.append(.value(label: String(localized: "Paused: \(name(of: deck, at: index, of: decks.count))"), value: "–"))
                continue
            }
            let share = breakdown.decks[index]
            let new = deck.options.newCardsPerSession.map { $0.formatted() } ?? "∞"
            let production = deck.options.newProductionPerSession.map { $0.formatted() } ?? "∞"
            rows.append(
                .value(
                    label: name(of: deck, at: index, of: decks.count), value: share.admitted.formatted(),
                    note: String(localized: "Ceiling \(share.ceiling) (limits \(new) new / \(production) production)")))
        }
        rows += [
            .value(label: String(localized: "Cards done"), value: progress.ring.done.formatted()),
            .value(label: String(localized: "Cards left"), value: progress.cardsLeft.formatted()),
            .value(label: String(localized: "Catch-up beyond the plan"), value: breakdown.catchUp.formatted()),
        ]
        let footer = String(
            localized:
                "The plan is what FSRS sets for the day: the reviews due and the cards in learning. Of the overdue cards it takes a share, at least a seventh and at least what a normal day asks. New cards fill what the day's time leaves after reviews, up to each deck's ceiling. The rest of the overdue cards is catch-up."
        )
        return Section(title: String(localized: "Today's Plan"), rows: rows, footer: footer)
    }

    private static func time(_ progress: DailyProgress, _ breakdown: DayBreakdown) -> Section {
        func minutes(_ seconds: Double) -> String { (seconds / 60).formatted(.number.precision(.fractionLength(1))) }
        let header = [String(localized: "Day"), String(localized: "Asked (min)"), String(localized: "Worked (min)"), String(localized: "Ring"), String(localized: "Why")]
        let table = breakdown.days.reversed().enumerated().map { offset, day in
            [
                offset == 0 ? String(localized: "Today") : day.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)),
                minutes(day.time),
                minutes(day.worked),
                day.isClosed ? String(localized: "Closed") : String(localized: "Open"),
                day.reason.map(Self.text(of:)) ?? "–",
            ]
        }
        let rows: [Row] = [
            .value(label: String(localized: "Time of the day"), value: String(localized: "\(minutes(progress.time)) min")),
            .value(label: String(localized: "Streak step (cards)"), value: progress.roundPlan.ends.first.map { $0.formatted() } ?? "–"),
            .value(label: String(localized: "Daily goal (cards)"), value: progress.ring.goal.formatted()),
            .table(header: header, rows: table),
        ]
        let footer = String(
            localized:
                "A day asks the median of the work of the last seven study days, a tenth more after three closed rings in a row unless a try in the last two weeks left its ring open, and 30 % less the day after a missed one. The streak step is the cards that fit the first two minutes of the plan."
        )
        return Section(title: String(localized: "Today's time"), rows: rows, footer: footer)
    }

    /// Why a day had the size it had.
    private static func text(of reason: DailyGoal.SizeReason) -> String {
        switch reason {
        case .start: String(localized: "Start")
        case .median: String(localized: "Median")
        case .probe: String(localized: "Probe +10 %")
        case .afterMiss: String(localized: "After a miss −30 %")
        }
    }

    private static func pace(_ progress: DailyProgress, _ breakdown: DayBreakdown) -> Section {
        func kindRows(_ title: String, seconds: Double, _ basis: DayBreakdown.PaceBasis, reviewsLabel: String) -> [Row] {
            let source =
                switch basis.source {
                case .durations: String(localized: "Durations (\(basis.durations))")
                case .gaps: String(localized: "Gaps (\(basis.gaps))")
                case .fallback: String(localized: "Default")
                }
            return [
                .value(label: title, value: String(localized: "\(Int(seconds.rounded())) s"), note: source),
                .value(label: reviewsLabel, value: basis.reviewsPerCard.map { $0.formatted(.number.precision(.fractionLength(2))) } ?? "–"),
            ]
        }
        let rows =
            kindRows(String(localized: "New card"), seconds: progress.pace.newCard, breakdown.newCards, reviewsLabel: String(localized: "Reviews per new card"))
            + kindRows(String(localized: "Other card"), seconds: progress.pace.otherCard, breakdown.otherCards, reviewsLabel: String(localized: "Reviews per other card"))
        let footer = String(
            localized:
                "Seconds a done card takes: the typical seconds of a review, from its logged durations or else the gaps between reviews, times the reviews each done card took, over the last \(DailyGoal.paceDays) study days and today. With fewer than \(DailyGoal.paceMinimumGaps) timed reviews or \(DailyGoal.paceMinimumCards) done cards a kind keeps the default, \(Int(DailyGoal.fallbackNewCardSeconds)) s for new and \(Int(DailyGoal.fallbackOtherCardSeconds)) s for other."
        )
        return Section(title: String(localized: "Pace"), rows: rows, footer: footer)
    }

    private static func streak(_ progress: DailyProgress) -> Section {
        var rows: [Row] = [
            .value(label: String(localized: "Days"), value: progress.streak.days.formatted()),
            .value(label: String(localized: "Today"), value: progress.streakKeptToday ? String(localized: "Kept") : String(localized: "Not yet")),
        ]
        if let repair = progress.streak.repairCards {
            rows.append(.value(label: String(localized: "Cards to repair yesterday"), value: repair.formatted()))
        }
        let footer = String(
            localized: "The streak step of a day, the cards that fit the first two minutes of its plan, keeps the streak. One missed day is repaired when the next day closes its ring; two missed days in a row end it.")
        return Section(title: String(localized: "Streak"), rows: rows, footer: footer)
    }

    private static func wordsInMemory(_ memory: MemoryEstimate) -> Section {
        func decimals(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(2))) }
        let gain = memory.gainToday
        let rows: [Row] = [
            .value(label: String(localized: "In memory now"), value: decimals(memory.words)),
            .value(label: String(localized: "At the start of the day"), value: decimals(memory.wordsAtDayStart)),
            .value(label: String(localized: "Gain today"), value: gain.formatted(.number.precision(.fractionLength(2)).sign(strategy: .always(includingZero: false)))),
            .value(label: String(localized: "Next milestone"), value: memory.nextMilestone.map { $0.formatted() } ?? "–"),
        ]
        let footer = String(localized: "The sum of the FSRS recall probabilities of the learned recognition cards, as of now.")
        return Section(title: String(localized: "Words in Memory"), rows: rows, footer: footer)
    }

    private static func swipes(_ counts: SwipeTally.Counts) -> Section {
        let rows: [Row] = [
            .value(
                label: String(localized: "Swipes that sprang back from a gap"),
                value: String(localized: "\(counts.gapMisses) of \(counts.total) today"))
        ]
        let footer = String(
            localized:
                "A swipe that goes \(Int(GradeSwipe.commitDistance)) points or flicks gives the grade of its direction, unless it points into a gap: 210° to 240° or 300° to 330°, where the card springs back. Clockwise from the top: Easy 330° to 45°, Good 45° to 135°, Hard 135° to 210°, Forgot 240° to 300°. Counted from when the app started, per study day."
        )
        return Section(title: String(localized: "Swipes"), rows: rows, footer: footer)
    }

    private static func fsrs(_ deck: DeckInfo, position: Int, of count: Int) -> Section {
        let options = deck.options
        let rows: [Row] = [
            .value(label: String(localized: "Target recall"), value: Format.percent(options.targetRecall)),
            .value(label: String(localized: "Parameters"), value: options.parameters == .default ? String(localized: "Default") : String(localized: "Fitted")),
            .numbers(options.parameters.weights.map { String(format: "%.4f", $0) }.joined(separator: " ")),
            .value(
                label: String(localized: "Last automatic fit"), value: options.lastAutoFit.map(Self.summary) ?? String(localized: "None yet")),
            .value(label: String(localized: "Steps per card"), value: options.steps.formatted()),
            .value(label: String(localized: "Longest interval"), value: Format.days(Double(options.maximumInterval))),
        ]
        let footer = String(
            localized:
                "A card is due again when its chance of recall falls to the target. The 21 FSRS-6 parameters model your memory; the app fits them to the deck's review log and keeps a fit only if it predicts your newest reviews better."
        )
        // FSRS is a name, not a word to translate.
        let title = count > 1 ? "FSRS · " + name(of: deck, at: position, of: count) : "FSRS"
        return Section(title: title, rows: rows, footer: footer)
    }

    /// What the last automatic fit did, in the words of `ParametersSection.summary(of:)` (a view's method, which
    /// a nonisolated builder can't call).
    private static func summary(of fit: LearningOptions.AutoFit) -> String {
        let date = fit.date.formatted(.dateTime.day().month(.abbreviated))
        if fit.adopted {
            return String(localized: "Updated \(date) from \(fit.reviewCount.formatted()) answers")
        }
        return String(localized: "Checked \(date), kept: no better fit")
    }

    /// A deck's name, or its place among the decks where the screen doesn't know it.
    private static func name(of deck: DeckInfo, at index: Int, of count: Int) -> String {
        deck.name ?? String(localized: "Deck \(index + 1)")
    }
}

// MARK: Reading the decks

extension HowTodayWorks {
    /// A deck to explain the day of, as it is read from its file or held by a document.
    struct Source: Sendable {
        var name: String?
        var deck: Deck
    }

    /// Works the screen out of `decks` at `now`, the way the daily ring does: from the decks and their logs alone,
    /// so it shows what Today shows; a paused deck is left out of the figures and named in the plan. Replays the
    /// logs: call it off the main actor.
    nonisolated static func make(_ decks: [Source], at now: Date, calendar: StudyCalendar, swipes: SwipeTally.Counts?) -> HowTodayWorks {
        let activities = decks.map { DeckActivity(deck: $0.deck, calendar: calendar) }
        let progress = DailyProgress.evaluate(activities, at: now, calendar: calendar)
        return HowTodayWorks(
            progress: progress,
            breakdown: DayBreakdown(activities, progress: progress, at: now, calendar: calendar),
            memory: progress.memory,
            swipes: swipes,
            decks: decks.map { DeckInfo(name: $0.name, options: $0.deck.learningOptions) })
    }

    /// The decks at `files`, which are read here: those that can't be are left out.
    nonisolated static func read(_ files: [URL], at now: Date, calendar: StudyCalendar = StudyCalendar(), swipes: SwipeTally.Counts?) -> HowTodayWorks {
        let sources = files.compactMap { url in
            DeckFileReader.deck(at: url).map { Source(name: url.deletingPathExtension().lastPathComponent, deck: $0) }
        }
        return make(sources, at: now, calendar: calendar, swipes: swipes)
    }
}
