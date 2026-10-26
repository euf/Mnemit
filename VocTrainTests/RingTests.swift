import Observation
import SwiftUI
import Testing
import UIKit

@testable import VocTrain
@testable import VocabCore

/// `left` cards are left of the plan; by default the ones that close the ring.
private func progress(done: Int, goal: Int = 20, streak: Int = 0, left: Int? = nil) -> DailyProgress {
    DailyProgress(ring: DailyRing(done: done, goal: goal), streak: Streak(days: streak, repairCards: nil), cardsLeft: left ?? max(0, goal - done))
}

/// What stands in the middle of the ring: the cards left or a check, by the size of the ring, and never the streak.
struct RingCenterTests {
    @Test func theMiddleHoldsTheCardsLeft() {
        #expect(RingCenter(nil) == .none, "nothing before the first evaluation")
        #expect(RingCenter(progress(done: 5)) == .cardsLeft(15))
        #expect(RingCenter(progress(done: 5, streak: 12)) == .cardsLeft(15), "the streak is not in the ring")
        #expect(RingCenter(progress(done: 5, goal: 20, left: 40)) == .cardsLeft(15), "the plan may hold more than the ring: the cards to close it")
        #expect(RingCenter(progress(done: 5, goal: 20, left: 3)) == .cardsLeft(3))
    }

    @Test func aClosedRingHoldsACheck() {
        #expect(RingCenter(progress(done: 20)) == .done)
        #expect(RingCenter(progress(done: 70, left: 4)) == .done, "work beyond the goal shows no lap, and the plan's rest is no ring's")
        #expect(RingCenter(progress(done: 5, left: 0)) == .done, "nothing left")
        #expect(RingCenter(progress(done: 0, goal: 0, left: 0)) == .done, "a day without a plan is met")
    }

    @Test func theSizeDecidesHowMuchShows() {
        let cards = RingCenter.cardsLeft(8)
        for small: CGFloat in [22, 28, 30, 55] {
            #expect(cards.shown(at: small) == .none, "no middle in a ring of \(small) pt")
            #expect(RingCenter.done.shown(at: small) == .none)
        }
        #expect(cards.shown(at: 56) == cards, "the figure from 56 pt")
        #expect(!cards.showsCaption(at: 56) && !cards.showsCaption(at: 87), "alone")
        #expect(cards.showsCaption(at: 88) && cards.showsCaption(at: 168) && cards.showsCaption(at: 200), "with its caption")
        #expect(RingCenter.done.shown(at: 96) == .done)
        #expect(!RingCenter.done.showsCaption(at: 168), "the check has no caption")
        #expect(RingCenter.none.shown(at: 168) == .none)
    }

    @Test func theFlameHasThreeStates() {
        var day = progress(done: 5, streak: 12)
        #expect(day.streakState == .open, "outlined, grey, until the streak step is done")
        day.streakKeptToday = true
        #expect(day.streakState == .kept, "filled, in the streak's colour")
        var atRisk = DailyProgress(ring: DailyRing(done: 5, goal: 20), streak: Streak(days: 12, repairCards: 15))
        #expect(atRisk.streakState == .atRisk, "the day after a missed one, the outline takes the streak's colour")
        atRisk.streakKeptToday = true
        #expect(atRisk.isStreakAtRisk && atRisk.streakState == .atRisk, "the streak step alone does not save it")
        atRisk.ring = DailyRing(done: 20, goal: 20)
        #expect(!atRisk.isStreakAtRisk, "the closed ring saves it")
        #expect(atRisk.streakState == .kept)
        atRisk.streakKeptToday = false
        #expect(atRisk.streakState == .open)
    }

    @Test func texts() {
        #expect(RingCenter.none.text == nil && RingCenter.done.text == nil)
        #expect(RingCenter.cardsLeft(5).text == "5")
        #expect(RingCenter.cardsLeft(1234).text == "1234", "no grouping separator in a ring")
        #expect(RingCenter.cardsLeft(5).caption == "cards left")
        #expect(RingCenter.cardsLeft(1).caption == "card left", "the caption takes the plural form of the count")
        #expect(RingCenter.done.caption == nil)
    }

    @Test func spokenLabelsSayTheCards() {
        #expect(RingCenter.none.spokenLabel == nil)
        #expect(RingCenter.cardsLeft(12).spokenLabel == "12 cards left")
        #expect(RingCenter.cardsLeft(1).spokenLabel == "1 card left")
        #expect(RingCenter.done.spokenLabel == "Ring closed")
    }
}

/// The streak chip's sentence by state: kept, open with the time to keep it, at risk, and no streak yet.
struct StreakChipTests {
    @Test func keptSaysTheDays() {
        #expect(StreakChip.text(days: 12, state: .kept, minutesToKeep: nil) == "12-day streak")
        #expect(StreakChip.text(days: 1, state: .kept, minutesToKeep: nil) == "1-day streak")
    }

    @Test func openSaysTheTimeToKeepIt() {
        #expect(StreakChip.text(days: 12, state: .open, minutesToKeep: 2) == "≈ 2 min to keep your 12-day streak")
        #expect(StreakChip.text(days: 12, state: .open, minutesToKeep: 0) == "< 1 min to keep your 12-day streak")
        #expect(StreakChip.text(days: 12, state: .open, minutesToKeep: nil) == "12-day streak", "no time known: the days alone")
    }

    @Test func atRiskAsksForTheRing() {
        #expect(StreakChip.text(days: 12, state: .atRisk, minutesToKeep: nil) == "Close the ring to save your 12-day streak")
        #expect(StreakChip.text(days: 12, state: .atRisk, minutesToKeep: 2) == "Close the ring to save your 12-day streak", "the whole ring, not the step")
    }

    @Test func noStreakStartsOne() {
        #expect(StreakChip.text(days: 0, state: .open, minutesToKeep: 2) == "Start your streak · ≈ 2 min")
        #expect(StreakChip.text(days: 0, state: .open, minutesToKeep: nil) == "Start your streak")
        #expect(StreakChip.text(days: 0, state: .kept, minutesToKeep: nil) == "Start your streak")
    }

    @Test func spokenAddsTheStateWhereTheSentenceLacksIt() {
        #expect(StreakChip.spoken(days: 12, state: .kept, minutesToKeep: nil) == "12-day streak, kept today")
        #expect(StreakChip.spoken(days: 12, state: .open, minutesToKeep: nil) == "12-day streak, not kept yet")
        #expect(StreakChip.spoken(days: 12, state: .open, minutesToKeep: 2) == "≈ 2 min to keep your 12-day streak")
        #expect(StreakChip.spoken(days: 12, state: .atRisk, minutesToKeep: nil) == "Close the ring to save your 12-day streak")
    }
}

/// Draws the rings at 0, 0.4, 1.0, 1.6 and 2.3 of the goal, light and dark, in the three
/// places they sit in (Today, the bar of the study screen, the chip of the Mac's toolbar), to
/// PNGs to look at: nobody has to open the app. The rings sit in a real window, as in
/// `StudyScreenSnapshotTests`. The directory is `STUDY_SHOTS_DIR` (pass it as
/// `TEST_RUNNER_STUDY_SHOTS_DIR`), else a folder in the temporary directory. The test fails only
/// if a picture can't be made; what it shows is for a person to judge.
@Suite(.serialized)
@MainActor
struct RingSnapshotTests {
    static let fractions: [Double] = [0, 0.4, 1.0, 1.6, 2.3]
    static let goal = 20

    private var directory: URL {
        let path = ProcessInfo.processInfo.environment["STUDY_SHOTS_DIR"]
        let url = path.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory.appendingPathComponent("study-shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// The figures at `fraction` of the goal, with a streak of 12 days.
    static func progress(_ fraction: Double) -> DailyProgress {
        let done = Int((fraction * Double(goal)).rounded())
        return DailyProgress(ring: DailyRing(done: done, goal: goal), streak: Streak(days: 12, repairCards: nil), cardsLeft: max(0, goal - done))
    }

    /// `view` in a window of `size`, drawn once the run loop has laid it out.
    private func image<Content: View>(_ view: Content, size: CGSize, dark: Bool, waiting: Duration = .milliseconds(400)) async throws -> UIImage {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        window.windowLevel = .alert + 1
        window.rootViewController = UIHostingController(rootView: view.dynamicTypeSize(.large))
        window.makeKeyAndVisible()
        try await Task.sleep(for: waiting)
        let bounds = CGRect(origin: .zero, size: size)
        let picture = UIGraphicsImageRenderer(bounds: bounds).image { _ in
            window.drawHierarchy(in: bounds, afterScreenUpdates: true)
        }
        window.isHidden = true
        return picture
    }

    private func write(_ picture: UIImage, name: String, dark: Bool) throws {
        let data = try #require(picture.pngData())
        try data.write(to: directory.appendingPathComponent("ring-\(name)-\(dark ? "dark" : "light").png"))
    }

    /// One figure under each ring, so a picture says which fraction it is.
    private func row<Ring: View>(_ fractions: [Double] = RingSnapshotTests.fractions, spacing: CGFloat, @ViewBuilder ring: @escaping (DailyProgress) -> Ring) -> some View {
        HStack(alignment: .center, spacing: spacing) {
            ForEach(fractions, id: \.self) { fraction in
                VStack(spacing: 6) {
                    let progress = Self.progress(fraction)
                    ring(progress)
                    Text(verbatim: "\(Int((progress.ring.fraction * 100).rounded())) %")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Today: 72 pt, the streak and its word in the middle, on the grouped grey.
    @Test(arguments: [false, true])
    func today(dark: Bool) async throws {
        let view = row(spacing: 20) { progress in
            ProgressRing(fraction: progress.ring.fraction, diameter: 72, center: RingCenter(progress))
        }
        .padding(16)
        .background(Color(.systemGroupedBackground))
        try write(try await image(view, size: CGSize(width: 5 * 72 + 4 * 20 + 32, height: 72 + 40 + 32), dark: dark), name: "1-today", dark: dark)
    }

    /// The bar of the study screen: 30 pt with the lap, beside "19 of 20".
    @Test(arguments: [false, true])
    func studyBar(dark: Bool) async throws {
        let view = row(spacing: 16) { progress in
            HStack(spacing: 8) {
                StreamRing(progress: progress)
                Text(verbatim: "\(progress.ring.done) of \(progress.ring.goal)")
                    .font(.subheadline)
                    .monospacedDigit()
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        try write(try await image(view, size: CGSize(width: 5 * 100 + 4 * 16 + 32, height: 30 + 30 + 32), dark: dark), name: "2-study-bar", dark: dark)
    }

    /// The streak as the Mac's toolbar chip shows it: 24 pt and "8/20". Drawn here on the iPhone,
    /// the same view as on the Mac; the Mac's own picture is in `RingSnapshotMacTests`.
    @Test(arguments: [false, true])
    func chip(dark: Bool) async throws {
        let view = row(spacing: 16) { progress in
            HStack(spacing: 6) {
                ProgressRing(fraction: progress.ring.fraction, diameter: 24, center: RingCenter(progress))
                Text(verbatim: "\(progress.ring.done)/\(progress.ring.goal)")
                    .monospacedDigit()
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        try write(try await image(view, size: CGSize(width: 5 * 80 + 4 * 16 + 32, height: 24 + 30 + 32), dark: dark), name: "3-chip", dark: dark)
    }

    /// The rest screen's 96 pt ring and the Mac's session ring at its default 28 pt (lap in
    /// the middle, a button around it).
    @Test(arguments: [false, true])
    func large(dark: Bool) async throws {
        let view = row(spacing: 16) { progress in
            DailyRingView(progress: progress, diameter: 96)
        }
        .padding(16)
        .background(Color(.systemBackground))
        try write(try await image(view, size: CGSize(width: 5 * 96 + 4 * 16 + 32, height: 96 + 30 + 32), dark: dark), name: "4-rest", dark: dark)
    }

    /// The places where the drawing changes kind: a sliver, almost closed, closed, and beyond the goal,
    /// which stays closed.
    @Test(arguments: [false, true])
    func edges(dark: Bool) async throws {
        let fractions: [Double] = [0.05, 0.95, 1.0, 1.05, 1.5, 2.0, 3.0]
        let view = row(fractions, spacing: 20) { progress in
            ProgressRing(fraction: progress.ring.fraction, diameter: 72, center: RingCenter(progress))
        }
        .padding(16)
        .background(Color(.systemBackground))
        try write(try await image(view, size: CGSize(width: 7 * 72 + 6 * 20 + 32, height: 72 + 40 + 32), dark: dark), name: "5-edges", dark: dark)
    }

    /// The ring runs between two fractions instead of jumping. A state in a box the view reads,
    /// flipped while the window shows it; the picture a moment after the flip is not yet the last
    /// (a jump would show it at once).
    @Test func animatesBetweenFractions() async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let bounds = CGRect(x: 0, y: 0, width: 96, height: 96)
        let box = FractionBox()
        window.frame = bounds
        window.overrideUserInterfaceStyle = .light
        window.windowLevel = .alert + 1
        window.rootViewController = UIHostingController(rootView: RingHost(box: box))
        window.makeKeyAndVisible()
        func picture() -> PixelBitmap {
            PixelBitmap(UIGraphicsImageRenderer(bounds: bounds).image { _ in window.drawHierarchy(in: bounds, afterScreenUpdates: true) })
        }
        try await Task.sleep(for: .milliseconds(300))
        let first = picture()
        box.value = 1.6
        try await Task.sleep(for: .milliseconds(150))
        let during = picture()
        try await Task.sleep(for: .milliseconds(1200))
        let last = picture()
        window.isHidden = true
        #expect(differing(first, last) > 100, "the ring moved")
        #expect(differing(during, last) > 20, "a moment after the change the ring is not yet where it ends")
    }

    private func differing(_ a: PixelBitmap, _ b: PixelBitmap) -> Int {
        var count = 0
        for y in 0..<min(a.height, b.height) {
            for x in 0..<min(a.width, b.width) where a.differs(x, y, from: b, tolerance: 8) { count += 1 }
        }
        return count
    }
}

@MainActor @Observable
private final class FractionBox {
    var value = 0.0
}

private struct RingHost: View {
    var box: FractionBox

    var body: some View {
        ProgressRing(fraction: box.value, diameter: 72, center: .none)
            .padding(12)
    }
}
