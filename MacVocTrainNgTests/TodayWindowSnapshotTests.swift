import AppKit
import SwiftUI
import Testing

@testable import MacVocTrain
@testable import VocabCore

/// Draws the Mac's Today window (`TodayWindowContent`) in its states, light and dark, to PNGs to look at, as
/// `RingSnapshotMacTests` draws the rings: into `STUDY_SHOTS_DIR` (pass it as `TEST_RUNNER_STUDY_SHOTS_DIR`), else
/// the temporary directory of the test host's container. The window never shows. The test fails only if a picture
/// can't be made; what it shows is for a person to judge.
@MainActor
struct TodayWindowSnapshotTests {
    static let now = Date()
    static let folder = URL(filePath: "/Decks/Mnemit", directoryHint: .isDirectory)
    static let greekA1 = folder.appending(path: "Greek A1–A2.mnemit")
    static let greekB1 = folder.appending(path: "Greek B1.mnemit")

    private var directory: URL {
        let path = ProcessInfo.processInfo.environment["STUDY_SHOTS_DIR"]
        let url = path.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory.appendingPathComponent("study-shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func counts(new: Int, learning: Int, review: Int, nextDue: Date? = nil) -> StudyCounts {
        StudyCounts(newProduction: 0, newOther: new, learning: learning, review: review, nextDue: nextDue)
    }

    /// The day of four rounds ending at 8, 16, 24 and 30 cards, `done` of them done.
    private static func progress(done: Int, streak: Int) -> DailyProgress {
        let rounds = DayRounds(otherCards: 30, newCards: 0, pace: Pace(newCard: 30, otherCard: 15), seconds: 480)
        return DailyProgress(
            ring: DailyRing(done: done, goal: rounds.goal), streak: Streak(days: streak, repairCards: nil), pace: Pace(newCard: 30, otherCard: 15),
            roundPlan: rounds, streakKeptToday: rounds.roundsDone(cardsDone: done) > 0, memory: MemoryEstimate(words: 412.4, wordsAtDayStart: 397))
    }

    private func content(folder: URL? = Self.folder, counts: [URL: StudyCounts], paused: Set<URL> = [], progress: DailyProgress?) -> some View {
        TodayWindowContent(
            folder: folder, decks: folder == nil ? [] : [Self.greekA1, Self.greekB1], recent: [], progress: progress, counts: counts,
            paused: paused, isRead: !counts.isEmpty || !paused.isEmpty, now: Self.now, chooseFolder: {}, study: { _ in })
    }

    private func write(_ view: some View, name: String) throws {
        for dark in [false, true] {
            let hosting = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: hosting.fittingSize), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            window.contentView = hosting
            hosting.layoutSubtreeIfNeeded()
            let rep = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            let data = try #require(rep.representation(using: .png, properties: [:]))
            let file = "today-mac-\(name)-\(dark ? "dark" : "light").png"
            do {
                try data.write(to: directory.appendingPathComponent(file))
            } catch {
                try data.write(to: FileManager.default.temporaryDirectory.appendingPathComponent(file))
            }
            window.close()
        }
    }

    @Test func states() throws {
        let tomorrow = Self.now.addingTimeInterval(86_400)
        try write(
            content(counts: [Self.greekA1: Self.counts(new: 4, learning: 0, review: 10), Self.greekB1: Self.counts(new: 0, learning: 0, review: 6)], progress: Self.progress(done: 10, streak: 12)),
            name: "due")
        try write(
            content(counts: [Self.greekA1: Self.counts(new: 6, learning: 0, review: 12), Self.greekB1: Self.counts(new: 0, learning: 0, review: 12)], progress: Self.progress(done: 3, streak: 12)),
            name: "first-round")
        try write(
            content(
                counts: [Self.greekA1: Self.counts(new: 0, learning: 0, review: 0, nextDue: tomorrow), Self.greekB1: Self.counts(new: 0, learning: 0, review: 0, nextDue: tomorrow)],
                progress: Self.progress(done: 31, streak: 13)),
            name: "done")
        try write(
            content(counts: [Self.greekA1: Self.counts(new: 4, learning: 0, review: 10)], paused: [Self.greekB1], progress: Self.progress(done: 10, streak: 12)),
            name: "paused")
        try write(content(folder: nil, counts: [:], progress: nil), name: "welcome")
    }
}
