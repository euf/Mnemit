import SwiftUI
import Testing
import UIKit

@testable import VocTrain
@testable import VocabCore

/// The iPhone screens that the home, browser and study snapshots don't draw, as PNGs for a designer: Progress, all
/// medals, the month's screen, How It Works, Settings, a deck's statistics and options, the sheets of a deck's
/// name, where an Anki package goes, and a card's information. The frames are `gallery-<screen>[-state]-<light|dark>.png`
/// at 375 x 812 pt (an iPhone 13 mini), made by `HomeSnapshotTests.shoot`, so they go to the same directory
/// (`HOME_SHOTS_DIR`, passed as `TEST_RUNNER_HOME_SHOTS_DIR`). A tall list has a second frame, `-full`, in a window tall
/// enough for all of it. Nothing is compared; a test fails only when a view can't be drawn.
///
/// The hosting app does not speak (`GreekSpeech.autoSpeak` is off, see `VocTrainApp.init()`), and nothing here plays a
/// card.
@Suite(.serialized, .timeLimit(.minutes(10)))
@MainActor
struct ScreenGallerySnapshotTests {
    private let shots = HomeSnapshotTests()

    /// A frame of `view`, and when `tall` is given, a second one of that height.
    private func shoot(_ name: String, _ view: some View, tall: CGFloat? = nil) async throws {
        try await shots.shoot("gallery-\(name)", view)
        if let tall {
            try await shots.shoot("gallery-\(name)-full", view, height: tall)
        }
    }

    // MARK: Fixtures

    /// A learner of two years: a miss, a saved streak, and one day each of 2, 3, 5 and 10 times the goal and of 50
    /// to 500 cards, so every line of medals has several earned and a grey next one. Today's ring is half done.
    static func longProgress() -> DailyProgress {
        let count = 760
        var streak = 0
        var records: [DayRecord] = []
        let big = [40: 50, 80: 75, 150: 130, 300: 250, 450: 520]
        for index in 0..<count {
            let isToday = index == count - 1
            let missed = index == 100
            let done = isToday ? 14 : missed ? 0 : big[index] ?? 24 + index % 3
            streak = missed ? 0 : streak + 1
            records.append(
                DayRecord(
                    day: StudyCalendar().dayNumber(for: Date()) - (count - 1) + index, done: done, goal: 24, kept: done > 0, closed: done >= 24, streak: streak,
                    savedStreak: index == 220))
        }
        return DailyProgress(
            ring: DailyRing(done: 14, goal: 24), streak: Streak(days: streak, repairCards: nil), streakKeptToday: true,
            learned: WordsLearned(words: 1480, wordsAtDayStart: 1470), ladder: [1240, 210, 340, 515, 402, 188], records: records, achievements: Achievements.earned(over: records))
    }

    /// Two days of history: the first medals, and a grey next one in every line.
    static func newcomerProgress() -> DailyProgress {
        let today = StudyCalendar().dayNumber(for: Date())
        let records = [
            AchievementPresentationTests.day(today - 1, done: 24, goal: 24, streak: 1),
            AchievementPresentationTests.day(today, done: 14, goal: 24, streak: 2),
        ]
        return DailyProgress(
            ring: DailyRing(done: 14, goal: 24), streak: Streak(days: 2, repairCards: nil), streakKeptToday: true, ladder: [5439, 40, 15, 0, 0, 0],
            records: records, achievements: Achievements.earned(over: records))
    }

    /// October 2026: 20 days of study with a day of 75 cards and a saved streak, today the second of November.
    static func octoberRecap() throws -> MonthRecap {
        let october = CivilDate(year: 2026, month: 10, day: 1).dayNumber
        let november = CivilDate(year: 2026, month: 11, day: 2).dayNumber
        let records = (october...november).map { day -> DayRecord in
            let index = day - october
            guard index < 20 else { return AchievementPresentationTests.day(day, done: 0) }
            return DayRecord(
                day: day, done: index == 11 ? 75 : 24, goal: 24, kept: true, closed: true, streak: index + 1, savedStreak: index == 6)
        }
        return try #require(MonthRecapPlan.pending(records: records, calendar: StudyCalendar(), shown: nil))
    }

    func sampleDeck() throws -> BrowserSnapshotTests.Sample {
        try BrowserSnapshotTests().makeSample()
    }

    // MARK: Progress and medals

    /// The streak and totals, the latest medals, the 13 weeks with closed, open and missed days, the ladder of memory.
    @Test func progress() async throws {
        let progress = AchievementPresentationTests.sampleProgress()
        try await shoot("progress", NavigationStack { ProgressScreen(progress: progress) }, tall: 1700)
    }

    @Test func progressOfALongRun() async throws {
        let progress = Self.longProgress()
        try await shoot("progress-long-run", NavigationStack { ProgressScreen(progress: progress) }, tall: 1700)
    }

    @Test func medals() async throws {
        let progress = Self.longProgress()
        try await shoot("medals", NavigationStack { MedalsScreen(progress: progress) }, tall: 2600)
    }

    @Test func medalsOfANewcomer() async throws {
        let progress = Self.newcomerProgress()
        try await shoot("medals-first-days", NavigationStack { MedalsScreen(progress: progress) }, tall: 2600)
    }

    @Test func monthRecap() async throws {
        let recap = try Self.octoberRecap()
        try await shoot("month-recap", MonthRecapSheet(recap: recap, seeAll: {}, done: {}), tall: 1400)
    }

    // MARK: How It Works

    @Test func howTodayWorks() async throws {
        let content = HowTodayWorksTests.content()
        try await shoot("how-today-works", HowTodayWorksSheet(content: content, done: {}), tall: 3400)
    }

    @Test func howTodayWorksLoading() async throws {
        try await shoot("how-today-works-loading", HowTodayWorksSheet(content: nil, done: {}))
    }

    // MARK: Settings

    private func reminders(enabled: Bool) throws -> Reminders {
        let defaults = try #require(UserDefaults(suiteName: "gallery-\(UUID().uuidString)"))
        let reminders = Reminders(defaults: defaults)
        reminders.isEnabled = enabled
        return reminders
    }

    @Test func settingsWithTheReminderOff() async throws {
        try await shoot("settings-reminder-off", SettingsView(reminders: try reminders(enabled: false), showIntroduction: {}))
    }

    @Test func settingsWithTheReminderOn() async throws {
        try await shoot("settings-reminder-on", SettingsView(reminders: try reminders(enabled: true), showIntroduction: {}))
    }

    // MARK: A deck

    @Test func statistics() async throws {
        let document = try sampleDeck().document
        try await shoot("statistics", NavigationStack { StatisticsScreen(document: document) }, tall: 1600)
    }

    /// A deck's Today card in its states: a plan with the three counts, a plan with only new cards, done with its next
    /// review, and paused; in a list, as the deck's screen has it.
    @Test func deckTodayCard() async throws {
        let now = Date()
        let tomorrow = now.addingTimeInterval(86_400)
        let states: [(StudyCounts, Bool)] = [
            (HomeSnapshotTests.counts(new: 6, learning: 2, review: 14), false),
            (HomeSnapshotTests.counts(new: 10, learning: 0, review: 0), false),
            (HomeSnapshotTests.counts(new: 0, learning: 0, review: 0, nextDue: tomorrow), false),
            (HomeSnapshotTests.counts(new: 6, learning: 2, review: 14), true),
        ]
        let list = List {
            ForEach(states.indices, id: \.self) { index in
                let (counts, isPaused) = states[index]
                if let headline = DeckHeadline(counts: counts, pace: Pace(), isPaused: isPaused, hasCards: true, now: now) {
                    Section {
                        DeckTodayCard(headline: headline, counts: counts, pace: Pace(), isPaused: isPaused, now: now)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        try await shoot("deck-today-card", NavigationStack { list.navigationTitle("Greek B1") })
    }

    @Test func deckOptions() async throws {
        let document = try sampleDeck().document
        try await shoot("deck-options", NavigationStack { DeckOptionsScreen(document: document) }, tall: 1900)
    }

    @Test func deckAdvancedOptions() async throws {
        let document = try sampleDeck().document
        try await shoot("deck-options-advanced", NavigationStack { DeckAdvancedOptionsScreen(document: document) }, tall: 1900)
    }

    @Test func cardInformation() async throws {
        let sample = try sampleDeck()
        try await shoot("card-info-leech", CardInfoSheet(document: sample.document, card: sample.leech), tall: 1500)
        try await shoot("card-info-new", CardInfoSheet(document: sample.document, card: sample.newCard))
    }

    // MARK: Sheets of the decks

    @Test func newDeck() async throws {
        try await shoot("new-deck", NewDeckSheet { _ in })
        try await shoot("new-deck-filled", DeckNameSheet(title: "New Deck", actionTitle: "Create", current: nil, prefill: "Greek B2") { _ in })
        try await shoot(
            "new-deck-name-taken",
            DeckNameSheet(
                title: "New Deck", actionTitle: "Create", current: nil, prefill: "Greek B1", failure: DeckFiles.Failure.nameTaken("Greek B1").errorDescription
            ) { _ in })
    }

    @Test func renameDeck() async throws {
        try await shoot("rename-deck", RenameDeckSheet(currentName: "Greek B1") { _ in })
    }

    /// The package is the fixture of the core, made by Anki's own library, so the sheet reads a real one.
    @Test func ankiDestination() async throws {
        let url = AnkiImportScreenTests.fixture("greek-latest")
        let decks = [HomeSnapshotTests.greekA1, HomeSnapshotTests.greekB1]
        try await shoot("anki-destination", AnkiDestinationSheet(url: url, decks: decks) { _, _ in })
        try await shoot("anki-destination-no-decks", AnkiDestinationSheet(url: url, decks: []) { _, _ in })
        let missing = URL(filePath: "/Imports/Greek A2.apkg")
        try await shoot("anki-destination-failed", AnkiDestinationSheet(url: missing, decks: decks) { _, _ in })
    }
}
