import Foundation
import SwiftUI
import Testing
import UIKit
import VocabCore

@testable import VocTrain

/// The introduction: the order of its steps, the four cards of the swipe practice, and the two
/// places the cards can be kept.
@MainActor
struct OnboardingTests {
    let directory: URL
    let defaults: UserDefaults

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defaults = try #require(UserDefaults(suiteName: "OnboardingTests-\(UUID().uuidString)"))
    }

    // MARK: Steps

    @Test func theStepsGoFromWelcomeThroughSwipesAndSyncToTheReminder() {
        #expect(OnboardingStep.allCases == [.welcome, .swipe, .sync, .reminder])
        #expect(OnboardingStep.welcome.next == .swipe)
        #expect(OnboardingStep.swipe.next == .sync)
        #expect(OnboardingStep.sync.next == .reminder)
        // The end: the introduction is over.
        #expect(OnboardingStep.reminder.next == nil)
    }

    // MARK: Practice

    @Test func theCardsAskForLeftThenUpThenDownThenRight() {
        #expect(SwipePractice.order == [.again, .easy, .hard, .good])
        #expect(SwipePractice.order.map(\.arrow) == ["←", "↑", "↓", "→"])
        // The meanings are the rules of the app: four different ones.
        #expect(Set(SwipePractice.order.map(\.meaning)).count == 4)
    }

    @Test func onlyTheSwipeAskedForMovesOn() {
        var practice = SwipePractice()
        for expected in SwipePractice.order {
            #expect(practice.current == expected)
            for other in Grade.allCases where other != expected {
                #expect(!practice.accepts(other))
            }
            #expect(practice.accepts(expected))
            practice.advance()
        }
        #expect(practice.isDone)
        #expect(practice.current == nil)
        for grade in Grade.allCases {
            #expect(!practice.accepts(grade))
        }
        // More of it changes nothing.
        practice.advance()
        #expect(practice.index == SwipePractice.order.count)
    }

    @Test func aSwipeIsJudgedByItsDirection() {
        let right = CGSize(width: 160, height: 0)
        let left = CGSize(width: -160, height: 0)
        let up = CGSize(width: 0, height: -160)
        let down = CGSize(width: 0, height: 160)
        // Up and a little to the left (compass 330°), a gap: no grade.
        let upLeft = CGSize(width: -80, height: -140)
        func released(_ translation: CGSize) -> Grade? {
            GradeSwipe.released(translation: translation, predictedEnd: translation)
        }

        var practice = SwipePractice()
        #expect(released(left).map(practice.accepts) == true)
        #expect(released(right).map(practice.accepts) == false)
        #expect(released(up).map(practice.accepts) == false)
        practice.advance()
        #expect(released(up).map(practice.accepts) == true)
        #expect(released(down).map(practice.accepts) == false)
        #expect(released(left).map(practice.accepts) == false)
        practice.advance()
        #expect(released(down).map(practice.accepts) == true)
        #expect(released(up).map(practice.accepts) == false)
        practice.advance()
        #expect(released(right).map(practice.accepts) == true)
        #expect(released(left).map(practice.accepts) == false)
        // Too short to count, or in a gap: no grade at all, so no mistake either.
        #expect(released(CGSize(width: 40, height: 0)) == nil)
        #expect(released(upLeft) == nil)
    }

    @Test func theFourSampleCardsAreDifferentAndNotAllGreek() {
        let samples = SwipePractice.order.map(SwipePractice.sample(for:))
        #expect(Set(samples.map(\.question)).count == 4)
        #expect(samples.allSatisfy { !$0.question.isEmpty && !$0.answer.isEmpty })
        // Four languages: French, Italian, Greek, Spanish.
        #expect(samples.map(\.question) == ["la bibliothèque", "il treno", "η αστυνομία", "la mariposa"])
    }

    @Test func theHintPlaysTheFingerOfItsGradeAndTheCardTakesTheWayOfARealSwipe() {
        let ways: [Grade: Double] = [.again: 180, .easy: 75, .hard: 285, .good: 0]
        for grade in SwipePractice.order {
            let step = SwipePractice.nudge(for: grade)
            // The finger's axis is read as the grade, so the card takes the grade's own tint.
            #expect(GradeSwipe.zone(step) == grade)
            #expect(abs(hypot(step.width, step.height) - SwipePractice.nudgeTravel) < 0.001)
            // The card goes as under a finger on the reference direction: along it.
            let flight = CardFlight()
            flight.drag(step, isRevealed: true)
            #expect(flight.zone == grade)
            #expect(flight.highlighted == grade)
            let way = GradeSwipe.angle(of: flight.offset)
            let expected = ways[grade] ?? 0
            #expect(abs(way - expected) < 0.001 || abs(way - expected - 360) < 0.001, "\(grade)")
            #expect(abs(hypot(flight.offset.width, flight.offset.height) - SwipePractice.nudgeTravel) < 0.001)
        }
    }

    @Test func aPracticeStartsWhereItIsAskedToAndStaysInRange() {
        #expect(SwipePractice(index: 2).current == .hard)
        #expect(SwipePractice(index: 9).isDone)
        #expect(SwipePractice(index: -3).index == 0)
    }

    // MARK: Storage

    @Test func onlyOnThisPhoneTakesTheOwnFolderEvenWithoutDecks() {
        let local = directory.appending(path: "Documents", directoryHint: .isDirectory)
        let known = KnownDecks(defaults: defaults, localFolder: local)
        #expect(known.folder == nil)

        known.useLocalFolder()
        #expect(known.folder == local)
        #expect(known.isLocalFolder)
        #expect(known.byName.isEmpty)
        // No bookmark: the folder lies in the sandbox. Only the flag is kept.
        #expect(defaults.data(forKey: KnownDecks.folderKey) == nil)

        let relaunched = KnownDecks(defaults: defaults, localFolder: local)
        #expect(relaunched.folder == local)
        #expect(relaunched.isLocalFolder)
    }

    @Test func theDecksOfTheOwnFolderAreListedAndFoundAgainOnRefresh() throws {
        let local = try makeFolder(named: "Documents", decks: ["Greek A1–A2"])
        let known = KnownDecks(defaults: defaults, localFolder: local)
        known.useLocalFolder()
        #expect(known.byName.map(\.name) == ["Greek A1–A2"])

        try makeDeck(named: "Spanish", in: local)
        known.refreshFolder()
        #expect(known.byName.map(\.name) == ["Greek A1–A2", "Spanish"])
        // In the folder: the list would take a removed deck up again.
        #expect(known.isInFolder(local.appending(path: "Spanish.\(DeckFile.fileExtension)", directoryHint: .isDirectory)))
    }

    @Test func iCloudDriveAndTheOwnFolderReplaceEachOther() throws {
        let local = try makeFolder(named: "Documents", decks: ["Local"])
        let cloud = try makeFolder(named: "Mnemit", decks: ["Greek B1"])
        let known = KnownDecks(defaults: defaults, localFolder: local)

        known.useLocalFolder()
        #expect(known.chooseFolder(cloud) == 1)
        #expect(!known.isLocalFolder)
        #expect(known.byName.map(\.name) == ["Greek B1"])
        let afterCloud = KnownDecks(defaults: defaults, localFolder: local)
        #expect(!afterCloud.isLocalFolder)
        #expect(afterCloud.folder.map { KnownDecks.isSameFile($0, cloud) } == true)

        known.useLocalFolder()
        #expect(known.isLocalFolder)
        #expect(known.byName.map(\.name) == ["Local"])
        #expect(defaults.data(forKey: KnownDecks.folderKey) == nil)
        let afterLocal = KnownDecks(defaults: defaults, localFolder: local)
        #expect(afterLocal.isLocalFolder)
        #expect(afterLocal.byName.map(\.name) == ["Local"])
    }

    @Test func anEmptyFolderNamedMnemitIsTakenAnyOtherEmptyFolderIsNot() throws {
        let created = try makeFolder(named: "Mnemit", decks: [])
        let other = try makeFolder(named: "Documents", decks: [])
        let known = KnownDecks(defaults: defaults, localFolder: directory)

        // The learner was told to create it; its decks are still on their way.
        #expect(known.chooseFolder(other) == 0)
        #expect(known.folder == nil)
        #expect(known.chooseFolder(created) == 0)
        #expect(known.folder.map { KnownDecks.isSameFile($0, created) } == true)
        #expect(known.byName.isEmpty)

        try makeDeck(named: "Greek B1", in: created)
        known.refreshFolder()
        #expect(known.byName.map(\.name) == ["Greek B1"])
    }

    private func makeFolder(named name: String, decks: [String]) throws -> URL {
        let folder = directory.appending(path: "\(UUID().uuidString)/\(name)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for deck in decks {
            try makeDeck(named: deck, in: folder)
        }
        return folder
    }

    @discardableResult
    private func makeDeck(named name: String, in folder: URL) throws -> URL {
        let url = folder.appending(path: "\(name).\(DeckFile.fileExtension)", directoryHint: .isDirectory)
        try DeckFile.fileWrapper(for: Deck()).write(to: url, options: .atomic, originalContentsURL: nil)
        return url
    }
}

/// Draws the steps of the introduction, light and dark, at the size of an iPhone 13 mini, to
/// look at without opening the app: `HomeSnapshotTests` has the window and the PNGs, in
/// `HOME_SHOTS_DIR` (pass it as `TEST_RUNNER_HOME_SHOTS_DIR`). The test fails only when a view
/// can't be drawn.
@MainActor
struct OnboardingSnapshotTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)

    private func knownDecks(decks: [String] = [], local: Bool = false) throws -> KnownDecks {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let defaults = try #require(UserDefaults(suiteName: "OnboardingSnapshotTests-\(UUID().uuidString)"))
        let folder = directory.appending(path: "Mnemit", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for name in decks {
            let url = folder.appending(path: "\(name).\(DeckFile.fileExtension)", directoryHint: .isDirectory)
            try DeckFile.fileWrapper(for: Deck()).write(to: url, options: .atomic, originalContentsURL: nil)
        }
        let known = KnownDecks(defaults: defaults, localFolder: folder)
        if local {
            known.useLocalFolder()
        } else if !decks.isEmpty {
            known.chooseFolder(folder)
        }
        return known
    }

    private func step(_ step: OnboardingStep, decks: KnownDecks? = nil) throws -> some View {
        OnboardingView(knownDecks: try decks ?? knownDecks(), reminders: Reminders(), step: step, onFinish: {})
    }

    private func practice(_ index: Int, isRevealed: Bool = false, flight: CardFlight? = nil) -> some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            GesturePracticeView(practice: SwipePractice(index: index), isRevealed: isRevealed, flight: flight, done: {})
        }
    }

    @Test func welcome() async throws {
        try await HomeSnapshotTests().shoot("onboarding-1-welcome", step(.welcome))
    }

    @Test func practiceCards() async throws {
        let shots = HomeSnapshotTests()
        for index in 0..<4 {
            try await shots.shoot("onboarding-2-swipe-\(index + 1)", practice(index))
        }
        try await shots.shoot("onboarding-2-swipe-done", practice(4))
    }

    /// The finger has landed: the answer shows, as on the study card.
    @Test func practiceCardWithItsAnswer() async throws {
        try await HomeSnapshotTests().shoot("onboarding-2-swipe-1-answer", practice(0, isRevealed: true))
    }

    /// The hint: the card a step the way a real swipe moves it, in the tint of its grade; Easy
    /// goes up and right, Hard down and right.
    @Test func practiceCardWhileTheHintShowsTheWay() async throws {
        let shots = HomeSnapshotTests()
        for index in 0..<4 {
            let grade = SwipePractice.order[index]
            let flight = CardFlight()
            flight.drag(SwipePractice.nudge(for: grade), isRevealed: true)
            try await shots.shoot("onboarding-2-swipe-\(index + 1)-hint", practice(index, flight: flight))
        }
    }

    /// A taller screen: the card grows to its limit and stays in the middle of the room.
    @Test func practiceCardOnATallScreen() async throws {
        try await HomeSnapshotTests().shoot("onboarding-2-swipe-1-tall", practice(0), height: 844)
        try await HomeSnapshotTests().shoot("onboarding-2-swipe-done-tall", practice(4), height: 844)
    }

    @Test func syncBeforeAChoice() async throws {
        try await HomeSnapshotTests().shoot("onboarding-3-sync", step(.sync))
    }

    @Test func syncAfterTheDecksWereFound() async throws {
        let decks = try knownDecks(decks: ["Greek A1–A2", "Greek B1"])
        try await HomeSnapshotTests().shoot("onboarding-3-sync-found", step(.sync, decks: decks))
    }

    @Test func syncOnlyOnThisPhone() async throws {
        let decks = try knownDecks(local: true)
        try await HomeSnapshotTests().shoot("onboarding-3-sync-local", step(.sync, decks: decks))
    }

    @Test func reminder() async throws {
        try await HomeSnapshotTests().shoot("onboarding-4-reminder", step(.reminder))
    }
}
