import AppKit
import SwiftUI
import Testing

@testable import MacVocTrain
@testable import VocabCore

/// Draws the Mac's rings at 0, 0.4, 1.0, 1.6 and 2.3 of the goal, light and dark, to PNGs to look
/// at: the 24-pt ring of the toolbar chip with "8/20" and the 28-pt ring of the session header
/// (the lap in its middle). The directory is `STUDY_SHOTS_DIR` (pass it as
/// `TEST_RUNNER_STUDY_SHOTS_DIR`), else, and when the sandbox of the test host refuses it, the
/// temporary directory of the host's container (`~/Library/Containers/<bundle id>/Data/tmp`).
/// The window never shows. The test fails only if a picture can't be made; what it shows is for a person to judge.
@MainActor
struct RingSnapshotMacTests {
    static let fractions: [Double] = [0, 0.4, 1.0, 1.6, 2.3]

    private var directory: URL {
        let path = ProcessInfo.processInfo.environment["STUDY_SHOTS_DIR"]
        let url = path.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory.appendingPathComponent("study-shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func progress(_ fraction: Double) -> DailyProgress {
        DailyProgress(ring: DailyRing(done: Int((fraction * 20).rounded()), goal: 20), streak: Streak(days: 12, repairCards: nil))
    }

    private func write<Content: View>(_ content: Content, name: String, dark: Bool) throws {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let hosting = NSHostingView(rootView: content.padding(16).background(Color(nsColor: .windowBackgroundColor)))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: hosting.fittingSize), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = appearance
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        let bounds = hosting.bounds
        let rep = try #require(hosting.bitmapImageRepForCachingDisplay(in: bounds))
        hosting.cacheDisplay(in: bounds, to: rep)
        let data = try #require(rep.representation(using: .png, properties: [:]))
        let file = "ring-mac-\(name)-\(dark ? "dark" : "light").png"
        do {
            try data.write(to: directory.appendingPathComponent(file))
        } catch {
            // The sandbox of the test host lets it write only in its own container.
            try data.write(to: FileManager.default.temporaryDirectory.appendingPathComponent(file))
        }
        window.close()
    }

    @Test(arguments: [false, true])
    func chip(dark: Bool) throws {
        let view = HStack(spacing: 24) {
            ForEach(Self.fractions, id: \.self) { fraction in
                let progress = progress(fraction)
                ProgressRing(fraction: progress.ring.fraction, diameter: 24)
            }
        }
        try write(view, name: "1-chip", dark: dark)
    }

    @Test(arguments: [false, true])
    func sessionHeader(dark: Bool) throws {
        let view = HStack(spacing: 24) {
            ForEach(Self.fractions, id: \.self) { fraction in
                DailyRingView(progress: progress(fraction))
            }
        }
        try write(view, name: "2-session", dark: dark)
    }
}
