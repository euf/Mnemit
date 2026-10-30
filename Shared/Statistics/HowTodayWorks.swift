import Foundation
import VocabCore

/// The content of "How It Works", the screen that tells a learner the three moments of the day (the streak kept, the ring
/// closed, all done) in three plain sentences, and shows one who knows Anki and FSRS what is under the ring and the rounds: the
/// numbers and the rules, read from the same objects the Today screen shows (`DailyProgress`, `DayBreakdown`, `MemoryEstimate`, the decks' learning options) and nothing
/// else. Read-only, no knobs.
///
/// Built into sections of rows that are already text, so a test can compare them and the view only lays
/// them out. The sections come in the order of the screen: the three sentences, the plan, the day's time, the pace, the
/// streak, the words in memory, the swipes (where the screen has them: the iPhone), the options (the rules
/// the Options screen only names), then the FSRS settings of each deck. A section's footer is its rule.
struct HowTodayWorks: Equatable, Sendable {
    enum Row: Equatable, Sendable {
        /// A sentence to read.
        case text(String)
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
        /// The rule, in a line or three; empty for a section that is only sentences.
        var footer: String
    }

    /// A deck of the screen: its name, which the Mac does not know, and its learning options.
    struct DeckInfo: Equatable, Sendable {
        var name: String?
        var options: LearningOptions
    }

    var sections: [Section]

    /// `swipes` is what `SwipeTally` counted today; `nil` where nothing is swiped (the Mac), so there is no section.
    /// `showsFourButtons` is the setting "Hard and Easy Buttons": the rule of the swipes states the sectors of that mode.
    init(
        progress: DailyProgress, breakdown: DayBreakdown, memory: MemoryEstimate, swipes: SwipeTally.Counts?,
        showsFourButtons: Bool = false, decks: [DeckInfo]
    ) {
        sections =
            [
                Self.today(),
                Self.plan(progress, breakdown, decks),
                Self.time(progress, breakdown),
                Self.pace(progress, breakdown),
                Self.streak(progress),
                Self.wordsInMemory(memory),
            ] + (swipes.map { [Self.swipes($0, showsFourButtons: showsFourButtons)] } ?? [])
            + [Self.options()]
            + decks.indices.map { Self.fsrs(decks[$0], position: $0, of: decks.count) }
    }

    // MARK: Sections

    /// The three moments of the day in plain words: the streak kept, the ring closed, all done.
    private static func today() -> Section {
        let rows: [Row] = [
            .text(String(localized: "The first two minutes keep your streak. Stop there or go on.")),
            .text(String(localized: "The ring is today's goal: the cards you usually have time for. Close it and the day is done; Keep Going takes the reviews still waiting.")),
            .text(String(localized: "Nothing due: the day is done. Learn 10 New Words if you want more.")),
        ]
        return Section(title: String(localized: "Today"), rows: rows, footer: "")
    }

    private static func plan(_ progress: DailyProgress, _ breakdown: DayBreakdown, _ decks: [DeckInfo]) -> Section {
        let plan = breakdown.plan
        var rows: [Row] = [
            .value(label: String(localized: "Due today, overdue included"), value: plan.reviewsDue.formatted()),
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
            let new = deck.options.newCardsPerSession.map { $0.formatted() } ?? String(localized: "Auto")
            // Fewer admitted than ready: the day's time is what stops the new cards, and the row says so.
            let note =
                share.admitted < share.ceiling
                ? String(localized: "Ready \(share.ceiling) (New cards/day: \(new)), the day's time fits \(share.admitted)")
                : String(localized: "Ready \(share.ceiling) (New cards/day: \(new))")
            rows.append(.value(label: name(of: deck, at: index, of: decks.count), value: share.admitted.formatted(), note: note))
        }
        rows += [
            .value(label: String(localized: "Cards done"), value: progress.ring.done.formatted()),
            .value(label: String(localized: "Cards left"), value: progress.cardsLeft.formatted()),
        ]
        let footer = String(
            localized:
                "Each day FSRS sets the reviews due, overdue ones included, and the cards in learning. New cards fill the time left, up to each deck's limit."
        )
        return Section(title: String(localized: "Today's Plan"), rows: rows, footer: footer)
    }

    /// Seconds as minutes with a decimal.
    private static func minutes(_ seconds: Double) -> String { (seconds / 60).formatted(.number.precision(.fractionLength(1))) }

    private static func time(_ progress: DailyProgress, _ breakdown: DayBreakdown) -> Section {
        let header = [String(localized: "Day"), String(localized: "Asked (min)"), String(localized: "Worked (min)"), String(localized: "Ring"), String(localized: "Why")]
        let table = breakdown.days.reversed().enumerated().map { offset, day in
            [
                offset == 0 ? String(localized: "Today") : day.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)),
                minutes(day.time),
                minutes(day.worked),
                day.isClosed ? String(localized: "Closed") : String(localized: "Open"),
                Self.text(of: day.reason),
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
                "Your ring grows after closed rings and shrinks after an open one. Go well past it most days, and it grows to what you do. It starts at 2½ minutes and stays between 2 minutes and an hour."
        )
        return Section(title: String(localized: "Today's time"), rows: rows, footer: footer)
    }

    /// Why a day had the size it had.
    private static func text(of reason: DailyGoal.SizeReason) -> String {
        switch reason {
        case .start: String(localized: "Start")
        case .ringClosed, .closedInARow: String(localized: "Ring closed")
        case .ringOpen: String(localized: "Ring open")
        case .smallPlan: String(localized: "Plan under the time")
        case .sustainedOvershoot: String(localized: "Past the ring")
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
                "Your pace: how long a card takes you, over your last \(DailyGoal.paceDays) study days and today. Until you have \(DailyGoal.paceMinimumGaps) timed reviews and \(DailyGoal.paceMinimumCards) done cards, a new card counts as \(Int(DailyGoal.fallbackNewCardSeconds)) s and any other as \(Int(DailyGoal.fallbackOtherCardSeconds)) s."
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
            localized: "The first two minutes of a day keep your streak. After one missed day, closing the next day's ring saves it; two missed days end it.")
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
        let footer = String(localized: "The sum of the recall chances of your learned Word → Meaning cards, now.")
        return Section(title: String(localized: "Words in Memory"), rows: rows, footer: footer)
    }

    private static func swipes(_ counts: SwipeTally.Counts, showsFourButtons: Bool) -> Section {
        let rows: [Row] = [
            .value(
                label: String(localized: "Swipes that sprang back from a gap"),
                value: String(localized: "\(counts.gapMisses) of \(counts.total) today"))
        ]
        // The sectors are those of `GradeSwipe`, in compass degrees (`HowTodayWorksTests` checks them).
        let footer =
            showsFourButtons
            ? String(
                localized:
                    "A swipe of \(Int(GradeSwipe.commitDistance)) points or a flick grades by direction, clockwise from the top: Easy 330°–45°, Good 45°–135°, Hard 135°–210°, Forgot 240°–300°. In the gaps, 210°–240° and 300°–330°, the card springs back. On a card's first showing only Good 30°–150° and Forgot 210°–330° count. Counted per study day since the app started."
            )
            : String(
                localized:
                    "A swipe of \(Int(GradeSwipe.commitDistance)) points or a flick grades by direction, clockwise from the top: Good 30°–150°, Forgot 210°–330°. Up and down, 330°–30° and 150°–210°, spring the card back. Counted per study day since the app started."
            )
        return Section(title: String(localized: "Swipes"), rows: rows, footer: footer)
    }

    /// What the Options screen's help leaves out: one sentence per option that has a rule behind it.
    private static func options() -> Section {
        let rows: [Row] = [
            .text(
                String(
                    localized:
                        "If a word is new to you, answer Don't know: it comes back in this session."
                )),
            .text(
                String(
                    localized:
                        "Desired retention: the chance you still remember a card when it comes back. Higher means more reviews; \(Format.percent(0.9)) is a good balance."
                )),
            .text(
                String(
                    localized:
                        "Meaning → Word opens once Word → Meaning has an interval of 7 days. A word is asked one way a day."
                )),
            .text(
                String(
                    localized:
                        "A leech is a card you have forgotten as often as the deck's threshold says, and again after every half of it. Its answer stays on screen so you can edit the card or set it aside."
                )),
            .text(
                String(
                    localized:
                        "A new or forgotten card comes back in the session until you grade it Good as many times as Learning steps says. Hard keeps its step, Forgot starts it over, Easy finishes it at once."
                )),
            .text(
                String(
                    localized:
                        "FSRS starts with parameters averaged over many learners. Fitted to your reviews, they need fewer reviews for the same recall. Due dates stay; new intervals start at each card's next review."
                )),
            .text(
                String(
                    localized:
                        "Parameters are fitted first at \(ParameterRefit.minimumReviewCount.formatted()) reviews, again at \(ParameterRefit.secondFitReviewCount.formatted()), then every \(Format.days(Double(ParameterRefit.intervalDays))) or after \(ParameterRefit.reviewStep.formatted()) more reviews, counting all your decks together. A new fit is kept only if it predicts your latest reviews clearly better."
                )),
        ]
        return Section(title: String(localized: "Options"), rows: rows, footer: "")
    }

    private static func fsrs(_ deck: DeckInfo, position: Int, of count: Int) -> Section {
        let options = deck.options
        let rows: [Row] = [
            .value(label: String(localized: "Desired retention"), value: Format.percent(options.targetRecall)),
            .value(label: String(localized: "Parameters"), value: options.parameters == .default ? String(localized: "Default") : String(localized: "Fitted")),
            .numbers(options.parameters.weights.map { String(format: "%.4f", $0) }.joined(separator: " ")),
            .value(
                label: String(localized: "Last automatic fit"), value: options.lastAutoFit.map(Self.summary) ?? String(localized: "None yet")),
            .value(label: String(localized: "Learning steps"), value: options.steps.formatted()),
            .value(label: String(localized: "Maximum interval"), value: Format.days(Double(options.maximumInterval))),
        ]
        let footer = String(
            localized:
                "A card comes back when your chance of recalling it falls to the target. FSRS models your memory with 21 parameters, fitted to the reviews of all your decks; a new fit is kept only if it predicts your latest reviews clearly better."
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
            return String(localized: "Updated \(date). Fitted on \(fit.reviewCount.formatted()) reviews from all your decks.")
        }
        return String(localized: "Checked \(date), kept: no clear gain")
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

    /// Works the screen out of `decks` at `now`, the way the daily ring does: from the decks and their logs and the
    /// progress `ledger` the app read (`ProgressLedgerStore`; writes nothing), so it shows what Today shows; a paused
    /// deck is left out of the figures and named in the plan. Replays the logs: call it off the main actor.
    nonisolated static func make(_ decks: [Source], at now: Date, calendar: StudyCalendar, swipes: SwipeTally.Counts?, showsFourButtons: Bool = false, ledger: DayLedger = DayLedger()) -> HowTodayWorks {
        let activities = decks.map { DeckActivity(deck: $0.deck, calendar: calendar) }
        let progress = DailyProgress.evaluate(activities, at: now, calendar: calendar, ledger: ledger)
        return HowTodayWorks(
            progress: progress,
            breakdown: DayBreakdown(activities, progress: progress, at: now, calendar: calendar),
            memory: progress.memory,
            swipes: swipes,
            showsFourButtons: showsFourButtons,
            decks: decks.map { DeckInfo(name: $0.name, options: $0.deck.learningOptions) })
    }

    /// The decks at `files`, which are read here: those that can't be are left out. The ledger is read from `store`.
    nonisolated static func read(_ files: [URL], at now: Date, calendar: StudyCalendar = StudyCalendar(), swipes: SwipeTally.Counts?, showsFourButtons: Bool = false, ledger store: ProgressLedgerStore? = nil) -> HowTodayWorks {
        let sources = files.compactMap { url in
            DeckFileReader.deck(at: url).map { Source(name: url.deletingPathExtension().lastPathComponent, deck: $0) }
        }
        return make(sources, at: now, calendar: calendar, swipes: swipes, showsFourButtons: showsFourButtons, ledger: store?.read() ?? DayLedger())
    }
}
