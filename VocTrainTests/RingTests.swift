import Observation
import SwiftUI
import Testing
import UIKit

@testable import VocTrain
@testable import VocabCore

private func progress(done: Int, goal: Int = 20, streak: Int = 0) -> DailyProgress {
    DailyProgress(ring: DailyRing(done: done, goal: goal), streak: Streak(days: streak, repairCards: nil))
}

/// What stands in the middle of the ring: the streak outside the study stream, the lap inside it.
struct RingCenterTests {
    @Test func streakOutsideTheStream() {
        #expect(RingCenter(nil, inStream: false) == .none)
        #expect(RingCenter(progress(done: 5, streak: 0), inStream: false) == .none, "a streak of 0 shows nothing")
        #expect(RingCenter(progress(done: 5, streak: 1), inStream: false) == .streak(days: 1))
        #expect(RingCenter(progress(done: 5, streak: 12), inStream: false) == .streak(days: 12))
        // The laps do not show outside the stream, however far the ring has gone.
        #expect(RingCenter(progress(done: 70, streak: 12), inStream: false) == .streak(days: 12))
    }

    @Test func lapInTheStream() {
        #expect(RingCenter(nil, inStream: true) == .none)
        #expect(RingCenter(progress(done: 0, streak: 9), inStream: true) == .none)
        #expect(RingCenter(progress(done: 19, streak: 9), inStream: true) == .none, "the first lap is empty")
        #expect(RingCenter(progress(done: 20, streak: 9), inStream: true) == .lap(2), "×2 once the goal is reached")
        #expect(RingCenter(progress(done: 39, streak: 9), inStream: true) == .lap(2))
        #expect(RingCenter(progress(done: 40, streak: 9), inStream: true) == .lap(3), "×3 after the second lap")
        // A small plan: the goal is the plan.
        #expect(RingCenter(progress(done: 6, goal: 6), inStream: true) == .lap(2))
    }

    @Test func texts() {
        #expect(RingCenter.none.text == nil)
        #expect(RingCenter.streak(days: 5).text == "5")
        #expect(RingCenter.streak(days: 1234).text == "1234", "no grouping separator in a ring")
        #expect(RingCenter.lap(2).text == "×2")
        #expect(RingCenter.lap(10).text == "×10")
        #expect(RingCenter.lap(2).caption == nil, "only a streak has a word under it")
        #expect(RingCenter.none.caption == nil)
        #expect(RingCenter.streak(days: 5).caption == "days")
        #expect(RingCenter.streak(days: 1).caption == "day")
    }

    @Test func spokenLabels() {
        #expect(RingCenter.none.spokenLabel == nil)
        #expect(RingCenter.streak(days: 5).spokenLabel == "Day streak: 5 days")
        #expect(RingCenter.streak(days: 1).spokenLabel == "Day streak: 1 day")
        #expect(RingCenter.lap(2).spokenLabel == "Lap 2")
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
        DailyProgress(ring: DailyRing(done: Int((fraction * Double(goal)).rounded()), goal: goal), streak: Streak(days: 12, repairCards: nil))
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
            ProgressRing(fraction: progress.ring.fraction, diameter: 72, center: RingCenter(progress, inStream: false))
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
                ProgressRing(fraction: progress.ring.fraction, diameter: 24, center: RingCenter(progress, inStream: false))
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

    /// The places where the drawing changes kind: a sliver, almost closed, closed, a sliver of the
    /// second lap, whole laps (the head at the top again).
    @Test(arguments: [false, true])
    func edges(dark: Bool) async throws {
        let fractions: [Double] = [0.05, 0.95, 1.0, 1.05, 1.5, 2.0, 3.0]
        let view = row(fractions, spacing: 20) { progress in
            ProgressRing(fraction: progress.ring.fraction, diameter: 72, center: RingCenter(progress, inStream: true))
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
