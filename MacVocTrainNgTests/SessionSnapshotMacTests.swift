import AppKit
import SwiftUI
import Testing

@testable import MacVocTrain
@testable import VocabCore

/// Draws the Mac's study stream (`SessionView`) with flash cards, asking, with the answer shown, and at its end, light
/// and dark, to PNGs to look at, as `TodayWindowSnapshotTests` does: into `STUDY_SHOTS_DIR`, else the temporary
/// directory of the test host's container. The test fails only if a picture can't be made.
@MainActor
struct SessionSnapshotMacTests {
    private var directory: URL {
        let path = ProcessInfo.processInfo.environment["STUDY_SHOTS_DIR"]
        let url = path.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory.appendingPathComponent("study-shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A day of 30 cards in rounds, `done` of them done, with a streak of 12: the header's ring, flame and text by hand,
    /// as no deck of a test has a plan at the start of its day.
    private func progress(done: Int) -> DailyProgress {
        let pace = Pace(newCard: 30, otherCard: 15)
        let rounds = DayRounds(otherCards: 30, newCards: 0, pace: pace, seconds: 480)
        return DailyProgress(
            ring: DailyRing(done: done, goal: rounds.goal), streak: Streak(days: 12, repairCards: nil), cardsLeft: max(0, rounds.goal - done),
            pace: pace, roundPlan: rounds, streakKeptToday: rounds.roundsDone(cardsDone: done) > 0)
    }

    /// `defaults` stand in for the preferences, for a session that reads the setting "Hard and Easy Buttons".
    private func write(
        _ model: SessionViewModel, name: String, done: Int? = nil, toasts: MedalToasts? = nil, height: CGFloat = 600,
        defaults: UserDefaults = .standard
    ) async throws {
        for dark in [false, true] {
            let ring = DailyRingModel(progress: done.map(progress(done:)))
            let hosting = NSHostingView(
                rootView: SessionView(model: model, ring: ring, toasts: toasts, onClose: {}).defaultAppStorage(defaults).frame(width: 800, height: height).brandTint())
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: height), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            window.contentView = hosting
            hosting.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(300))
            hosting.layoutSubtreeIfNeeded()
            let rep = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            let data = try #require(rep.representation(using: .png, properties: [:]))
            try data.write(to: directory.appendingPathComponent("session-mac-\(name)-\(dark ? "dark" : "light").png"))
            window.close()
        }
    }

    @Test func flashcards() async throws {
        let words = [("το σπίτι", "дом · the house"), ("ο δρόμος", "дорога · the road"), ("η αστυνομία", "полиция · the police"), ("αφού", "после того как · after")]
        let document = try VocabularyDocument(deck: Deck(cards: words.map { Card(question: $0.0, answer: $0.1) }))
        let undoManager = makeUndoManager(for: document)
        // A day of rounds, so the stack under the card shows its edges.
        let model = SessionViewModel(document: document, rounds: RoundGuide(ends: [6, 12]))
        try await write(model, name: "1-asking", done: 3)
        model.reveal()
        try await write(model, name: "2-revealed", done: 30)
        withExtendedLifetime(undoManager) {}
    }

    /// A medal's toast in the stream is one line in the middle of the header's row: over neither the ring, nor the card, nor a
    /// button, in a window of 600 pt (the test's) and in a taller one.
    @Test func medalToastInTheHeader() async throws {
        let words = [("το σπίτι", "дом · the house"), ("ο δρόμος", "дорога · the road"), ("η αστυνομία", "полиция · the police"), ("αφού", "после того как · after")]
        let document = try VocabularyDocument(deck: Deck(cards: words.map { Card(question: $0.0, answer: $0.1) }))
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, rounds: RoundGuide(ends: [6, 12]))
        model.reveal()
        let toasts = MedalToasts(store: CelebratedMedals(defaults: nil), frozen: Achievement(kind: .comeback, day: 0))
        try await write(model, name: "6-toast", done: 12, toasts: toasts)
        try await write(model, name: "6-toast-tall", done: 12, toasts: toasts, height: 760)
        withExtendedLifetime(undoManager) {}
    }

    /// A card's first showing with its answer open: its first button reads "Don't know".
    @Test func firstShowing() async throws {
        let words = [("το σπίτι", "дом · the house"), ("ο δρόμος", "дорога · the road"), ("η αστυνομία", "полиция · the police")]
        let document = try VocabularyDocument(deck: Deck(cards: words.map { Card(question: $0.0, answer: $0.1) }))
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, rounds: RoundGuide(ends: [6, 12]))
        #expect(model.currentCard?.isNew == true)
        model.reveal()
        try await write(model, name: "4-first-showing", done: 3)
        withExtendedLifetime(undoManager) {}
    }

    /// A card on a later showing with its answer open: two buttons, Forgot and Good, and with the setting "Hard and Easy
    /// Buttons" four.
    @Test(arguments: [false, true])
    func laterShowing(four: Bool) async throws {
        let suite = "mnemit.tests.answer-buttons-\(four)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(four, forKey: GradeChoice.showsFourButtonsKey)
        let document = try VocabularyDocument(deck: Deck(cards: [Card(question: "το σπίτι", answer: "дом · the house")]))
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, rounds: RoundGuide(ends: [6, 12]))
        model.reveal()
        step(undoManager) { model.grade(.again) }
        #expect(model.currentCard?.isNew == false)
        model.reveal()
        try await write(model, name: "5-later-showing-\(four ? "four" : "two")", done: 3, defaults: defaults)
    }

    /// Catch Up after the ring: the header's ring is full and the stack goes on under the card, the cards left in the plan.
    @Test func catchUpAfterTheRing() async throws {
        let words = (1...6).map { ("λέξη \($0)", "word \($0)") }
        let document = try VocabularyDocument(deck: Deck(cards: words.map { Card(question: $0.0, answer: $0.1) }))
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document, rounds: RoundGuide(ends: [1, 2]))
        for _ in 0..<2 {
            model.reveal()
            step(undoManager) { model.grade(.easy) }
            model.continueRound()
        }
        #expect(model.cardsBehind == 3)
        try await write(model, name: "5-catch-up", done: 30)
        withExtendedLifetime(undoManager) {}
    }

    /// A deck whose limit takes no new card today: the stream rests at the end of the plan at once, with Push On.
    @Test func planEnd() async throws {
        var options = LearningOptions()
        options.newCardsPerSession = 0
        let document = try VocabularyDocument(
            deck: Deck(learningOptions: options, cards: [Card(question: "το σπίτι", answer: "дом · the house"), Card(question: "ο δρόμος", answer: "дорога · the road")]))
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document)
        try await write(model, name: "3-plan-end")
        withExtendedLifetime(undoManager) {}
    }

    /// The stop after a Forgot that made a card a leech, under the deck's action Keep and under Suspend (Keep It).
    @Test(arguments: [LeechAction.keep, .suspend])
    func leechMoment(action: LeechAction) async throws {
        var options = LearningOptions()
        options.leechAction = action
        let state = LearningState(
            phase: .review, stability: 10, difficulty: 5, lastReview: Date(timeIntervalSinceNow: -10 * 86400), due: Date(timeIntervalSinceNow: -3600),
            reviews: 12, lapses: 7)
        let leech = Card(question: "απαντάω (απάντησα)", answer: "отвечать · to answer\nΑπάντησα στο γράμμα του Γιάννη.", learningState: state)
        let document = try VocabularyDocument(deck: Deck(learningOptions: options, cards: [leech]))
        let undoManager = makeUndoManager(for: document)
        let model = SessionViewModel(document: document)
        model.reveal()
        step(undoManager) { model.grade(.again) }
        #expect(model.leechMoment?.card.id == leech.id)
        try await write(model, name: "6-leech-moment-\(action == .keep ? "set-aside" : "keep-it")", done: 3)
        withExtendedLifetime(undoManager) {}
    }
}
