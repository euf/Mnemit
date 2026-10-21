import SwiftUI
import Testing
import UIKit
import WidgetKit

@testable import VocTrain
@testable import VocabCore

/// Draws the widget in each family, light and dark, at the sizes of an iPhone 13 mini
/// (375 × 812 pt), and writes PNGs to look at: nobody has to put the widget on a screen. The
/// system draws the real one; what the pictures lack is the system's own chrome (the wallpaper
/// behind a translucent background, the tint of the accented and clear styles).
///
/// The directory is `STUDY_SHOTS_DIR` (pass it to `xcodebuild` as an environment variable,
/// `TEST_RUNNER_STUDY_SHOTS_DIR`), else a folder in the temporary directory. The test fails only
/// if a picture can't be made; what the pictures show is for a person to judge.
@MainActor
struct WidgetShotsTests {
    typealias Fixtures = WidgetFixtures

    static let now = Fixtures.date(22, 10, 20)

    /// What a widget shows in the states worth a picture.
    static let states: [(name: String, state: WidgetState?)] = [
        // Under way: 12 of 20, 42 due, a streak not yet kept today, the reminder ahead.
        ("progress", WidgetState(date: now, reviews: 12, goal: 20, streakDays: 7, isGoalMet: false, due: 42, nextReminder: Fixtures.date(23, 9))),
        // Goal reached twice over, nothing left due, the streak kept.
        ("laps", WidgetState(date: now, reviews: 45, goal: 20, streakDays: 31, isGoalMet: true, due: 0, nextReminder: nil)),
        // A fresh day: nothing reviewed, three digits due, no streak yet.
        ("fresh", WidgetState(date: now, reviews: 0, goal: 20, streakDays: 0, isGoalMet: false, due: 120, nextReminder: nil)),
        // No snapshot yet.
        ("empty", nil),
    ]

    static let families: [(name: String, family: WidgetFamily)] = [
        ("small", .systemSmall), ("medium", .systemMedium), ("circular", .accessoryCircular), ("rectangular", .accessoryRectangular),
    ]

    private var directory: URL {
        let path = ProcessInfo.processInfo.environment["STUDY_SHOTS_DIR"]
        let url = path.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory.appendingPathComponent("widget-shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test(arguments: [false, true])
    func everyFamilyInEveryState(dark: Bool) async throws {
        for (stateName, state) in Self.states {
            for (familyName, family) in Self.families {
                let image = try await render(WidgetFrame(state: state, family: family, dark: dark), dark: dark)
                let data = try #require(image.pngData())
                try data.write(to: directory.appendingPathComponent("widget-\(stateName)-\(familyName)-\(dark ? "dark" : "light").png"))
            }
        }
    }

    /// All families of one state side by side, one sheet per state, for a look at the lot.
    @Test(arguments: [false, true])
    func sheets(dark: Bool) async throws {
        for (stateName, state) in Self.states {
            let sheet = HStack(alignment: .top, spacing: 16) {
                ForEach(Self.families, id: \.name) { item in
                    WidgetFrame(state: state, family: item.family, dark: dark)
                }
            }
            let image = try await render(sheet, dark: dark)
            let data = try #require(image.pngData())
            try data.write(to: directory.appendingPathComponent("widget-sheet-\(stateName)-\(dark ? "dark" : "light").png"))
        }
    }

    /// The view in a window of the hosting app, so the accent and the traits are the app's, drawn
    /// at its own size.
    private func render(_ view: some View, dark: Bool) async throws -> UIImage {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let controller = UIHostingController(rootView: view.dynamicTypeSize(.large))
        controller.overrideUserInterfaceStyle = dark ? .dark : .light
        controller.safeAreaRegions = []
        let size = controller.sizeThatFits(in: CGSize(width: 1200, height: 800))
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.windowLevel = .alert + 1
        window.rootViewController = controller
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(150))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let bounds = CGRect(origin: .zero, size: size)
        let image = UIGraphicsImageRenderer(bounds: bounds, format: format).image { _ in
            window.drawHierarchy(in: bounds, afterScreenUpdates: true)
        }
        window.isHidden = true
        return image
    }
}

/// A widget as the system draws it, on a wallpaper: the content inside the margins of its
/// family, on the background, clipped to the shape of the family.
private struct WidgetFrame: View {
    var state: WidgetState?
    var family: WidgetFamily
    var dark: Bool

    /// The sizes of an iPhone 13 mini (375 × 812), from Apple's table of widget sizes.
    static func size(_ family: WidgetFamily) -> CGSize {
        switch family {
        case .systemMedium: CGSize(width: 329, height: 155)
        case .accessoryCircular: CGSize(width: 72, height: 72)
        case .accessoryRectangular: CGSize(width: 160, height: 72)
        default: CGSize(width: 155, height: 155)
        }
    }

    private var isAccessory: Bool {
        family == .accessoryCircular || family == .accessoryRectangular
    }

    var body: some View {
        let size = Self.size(family)
        let content = WidgetContent(state: state, family: family)
        Group {
            if isAccessory {
                // On the lock screen the widgets are vibrant: light on a dark wallpaper, dark on a light one.
                content
                    .frame(width: size.width, height: size.height)
                    .background(family == .accessoryCircular ? AnyShapeStyle(.clear) : AnyShapeStyle(Color.primary.opacity(0.12)), in: shape)
                    .clipShape(shape)
            } else {
                content
                    .padding(16)
                    .frame(width: size.width, height: size.height)
                    .background(WidgetContent.background, in: shape)
            }
        }
        .padding(12)
        .background(wallpaper)
    }

    private var shape: AnyShape {
        switch family {
        case .accessoryCircular: AnyShape(Circle())
        case .accessoryRectangular: AnyShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        default: AnyShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var wallpaper: some View {
        LinearGradient(
            colors: dark ? [Color(white: 0.08), Color(red: 0.12, green: 0.14, blue: 0.3)] : [Color(white: 0.92), Color(red: 0.75, green: 0.82, blue: 0.95)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
