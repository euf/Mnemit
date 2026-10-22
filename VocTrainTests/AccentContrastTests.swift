import SwiftUI
import Testing
import UIKit

@testable import VocTrain

/// The indigo accent (systemIndigo, pinned per appearance) keeps its contrast in all four appearances: 4.5:1 for the white label
/// of a prominent button, 3:1 against the surfaces it sits on as a ring, a glyph or a fill. The
/// system surfaces are resolved at run time, not copied. The accent is never small text.
struct AccentContrastTests {
    struct Appearance {
        var name: String
        var style: UIUserInterfaceStyle
        var contrast: UIAccessibilityContrast
    }

    static let appearances = [
        Appearance(name: "light", style: .light, contrast: .normal),
        Appearance(name: "dark", style: .dark, contrast: .normal),
        Appearance(name: "light, increased contrast", style: .light, contrast: .high),
        Appearance(name: "dark, increased contrast", style: .dark, contrast: .high),
    ]

    static let surfaces: [(name: String, color: UIColor)] = [
        ("systemBackground", .systemBackground),
        ("systemGroupedBackground", .systemGroupedBackground),
        ("secondarySystemGroupedBackground", .secondarySystemGroupedBackground),
        ("secondarySystemBackground", .secondarySystemBackground),
    ]

    /// The surfaces of a sheet: in dark it lifts the system backgrounds one step, the grouped rows to `#2C2C2E`
    /// (resolved with `UITraitCollection.userInterfaceLevel` elevated, see `traits(_:level:)`).
    static let raisedSurfaces: [(name: String, color: UIColor)] = [
        ("systemBackground, raised", .systemBackground),
        ("systemGroupedBackground, raised", .systemGroupedBackground),
        ("secondarySystemGroupedBackground, raised", .secondarySystemGroupedBackground),
        ("secondarySystemBackground, raised", .secondarySystemBackground),
    ]

    /// The traits of a view drawn in `appearance`, on a screen (the base level) or in a sheet (elevated).
    static func traits(_ appearance: Appearance, level: UIUserInterfaceLevel = .base) -> UITraitCollection {
        UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: appearance.style), UITraitCollection(accessibilityContrast: appearance.contrast),
            UITraitCollection(userInterfaceLevel: level),
        ])
    }

    /// A colour as `#RRGGBB`.
    static func hex(_ color: UIColor, in traits: UITraitCollection) -> String {
        var (red, green, blue, alpha) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        color.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }

    /// Whether two colours are the same one, to two steps of 8 bits a channel, as pixels are read back.
    static func isClose(_ first: UIColor, _ second: UIColor, in traits: UITraitCollection) -> Bool {
        func channels(_ color: UIColor) -> [CGFloat] {
            var (red, green, blue, alpha) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
            color.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return [red, green, blue].map { $0 * 255 }
        }
        return zip(channels(first), channels(second)).allSatisfy { abs($0 - $1) <= 2 }
    }

    /// WCAG relative luminance of a colour in sRGB.
    static func luminance(_ color: UIColor, in traits: UITraitCollection) -> Double {
        var (red, green, blue, alpha) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        color.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func linear(_ channel: CGFloat) -> Double {
            let value = Double(channel)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    static func contrast(_ first: Double, _ second: Double) -> Double {
        (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    @Test func accentHoldsItsContrastInEveryAppearance() throws {
        let white = 1.0
        var lines: [String] = []
        for appearance in Self.appearances {
            let traits = UITraitCollection(traitsFrom: [
                UITraitCollection(userInterfaceStyle: appearance.style), UITraitCollection(accessibilityContrast: appearance.contrast),
            ])
            let accent = try #require(UIColor(named: "AccentColor", in: .main, compatibleWith: traits))
            let accentLuminance = Self.luminance(accent, in: traits)

            let label = Self.contrast(white, accentLuminance)
            lines.append("\(appearance.name): white label \(String(format: "%.2f", label))")
            #expect(label >= 4.5, "white on the accent, \(appearance.name)")

            for surface in Self.surfaces {
                let ratio = Self.contrast(accentLuminance, Self.luminance(surface.color, in: traits))
                lines.append("    on \(surface.name) \(String(format: "%.2f", ratio))")
                #expect(ratio >= 3, "accent on \(surface.name), \(appearance.name)")
            }
        }
        print(lines.joined(separator: "\n"))
    }

    /// A sheet raises the dark surfaces to `#2C2C2E`, where the accent is under 3:1 (2.47, and 2.97 with Increase
    /// Contrast); there a graphic takes `Color.appAccentOnRaised`, the accent lightened in its hue, which holds
    /// 3:1 on every raised surface. On a screen, and in light, it is the accent itself.
    @Test func theRaisedAccentHoldsItsContrastOnRaisedSurfaces() throws {
        var lines: [String] = []
        for appearance in Self.appearances {
            let screen = Self.traits(appearance)
            let sheet = Self.traits(appearance, level: .elevated)
            let accent = try #require(UIColor(named: "AccentColor", in: .main, compatibleWith: screen))
            let accentLuminance = Self.luminance(accent, in: screen)
            let raised = Color.raisedAccent(in: sheet)
            let raisedLuminance = Self.luminance(raised, in: sheet)
            lines.append("\(appearance.name): accent \(Self.hex(accent, in: screen)), raised accent \(Self.hex(raised, in: sheet))")

            #expect(abs(Self.luminance(Color.raisedAccent(in: screen), in: screen) - accentLuminance) < 0.001, "on a screen it is the accent, \(appearance.name)")
            if appearance.style == .light {
                #expect(abs(raisedLuminance - accentLuminance) < 0.001, "in light it is the accent, \(appearance.name)")
            } else {
                var (hue, otherHue) = (CGFloat(0), CGFloat(0))
                accent.resolvedColor(with: screen).getHue(&hue, saturation: nil, brightness: nil, alpha: nil)
                raised.getHue(&otherHue, saturation: nil, brightness: nil, alpha: nil)
                #expect(abs(hue - otherHue) < 0.01, "the hue stays, \(appearance.name)")
                #expect(raisedLuminance > accentLuminance, "the lighter one, \(appearance.name)")
            }
            for surface in Self.raisedSurfaces {
                let ratio = Self.contrast(raisedLuminance, Self.luminance(surface.color, in: sheet))
                let plain = Self.contrast(accentLuminance, Self.luminance(surface.color, in: sheet))
                lines.append("    on \(surface.name) \(Self.hex(surface.color, in: sheet)): \(String(format: "%.2f", ratio)), the accent \(String(format: "%.2f", plain))")
                #expect(ratio >= 3, "raised accent on \(surface.name), \(appearance.name)")
            }
        }
        print(lines.joined(separator: "\n"))
    }

    /// What a view in a presented controller shows of `Color.appAccentOnRaised`, from its pixels: the colour
    /// resolves with the level of the presentation, so one value serves a screen and a sheet.
    @MainActor
    static func shownPresented(_ style: UIModalPresentationStyle, in appearance: Appearance) async throws -> (level: UIUserInterfaceLevel, color: UIColor) {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.overrideUserInterfaceStyle = appearance.style
        window.traitOverrides.accessibilityContrast = appearance.contrast
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let content = UIHostingController(rootView: Rectangle().fill(Color.appAccentOnRaised).ignoresSafeArea())
        content.modalPresentationStyle = style
        root.present(content, animated: false)
        try await Task.sleep(for: .milliseconds(600))
        let bounds = content.view.bounds
        let image = UIGraphicsImageRenderer(bounds: bounds).image { _ in content.view.drawHierarchy(in: bounds, afterScreenUpdates: true) }
        let pixels = PixelBitmap(image)
        let (red, green, blue) = pixels.rgb(pixels.width / 2, pixels.height / 2)
        return (content.traitCollection.userInterfaceLevel, UIColor(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1))
    }

    /// A sheet is raised and a full-screen cover, which the study stream is, is not: the same `Color` shows
    /// the lighter accent in the first and the accent in the second.
    @MainActor @Test func theRaisedAccentShowsInASheetAndNotInAFullScreenCover() async throws {
        for appearance in Self.appearances where appearance.style == .dark {
            let screen = Self.traits(appearance)
            let accent = try #require(UIColor(named: "AccentColor", in: .main, compatibleWith: screen))
            let sheet = try await Self.shownPresented(.pageSheet, in: appearance)
            #expect(sheet.level == .elevated, "a sheet is raised, \(appearance.name)")
            #expect(Self.isClose(sheet.color, Color.raisedAccent(in: Self.traits(appearance, level: .elevated)), in: screen), "a sheet shows the raised accent, \(appearance.name)")
            let cover = try await Self.shownPresented(.fullScreen, in: appearance)
            #expect(cover.level == .base, "a full-screen cover is not, \(appearance.name)")
            #expect(Self.isClose(cover.color, accent, in: screen), "a cover shows the accent, \(appearance.name)")
        }
    }

    /// The colours two SwiftUI `Color`s show side by side in a window of the given appearance, read from
    /// the pixels: `Color.accentColor` takes the app's accent (the asset, in the appearance's variant)
    /// only inside a view, so the ring's colours cannot be resolved by `UIColor` alone.
    @MainActor
    static func shown(_ first: Color, _ second: Color, in appearance: Appearance) async throws -> (UIColor, UIColor) {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let bounds = CGRect(x: 0, y: 0, width: 140, height: 96)
        window.frame = bounds
        window.windowLevel = .alert + 1
        let swatches = HStack(spacing: 20) {
            Rectangle().fill(first).frame(width: 40, height: 40)
            Rectangle().fill(second).frame(width: 40, height: 40)
        }
        .padding(28)
        // On the controller, not the window: the overrides stay with what is drawn.
        let controller = UIHostingController(rootView: swatches)
        controller.overrideUserInterfaceStyle = appearance.style
        controller.traitOverrides.accessibilityContrast = appearance.contrast
        window.rootViewController = controller
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(400))
        let image = UIGraphicsImageRenderer(bounds: bounds).image { _ in window.drawHierarchy(in: bounds, afterScreenUpdates: true) }
        window.isHidden = true
        // The swatches are where the picture is not the window's background; the safe area of a window
        // this small is not the same on every device, so their place is found, not assumed.
        let pixels = PixelBitmap(image)
        let background = pixels.rgb(1, 1)
        var firstPixel: (x: Int, y: Int)?
        search: for y in 0..<pixels.height {
            for x in 0..<pixels.width where pixels.rgb(x, y) != background {
                firstPixel = (x, y)
                break search
            }
        }
        let start = try #require(firstPixel, "the swatches are not drawn")
        let row = start.y + 12
        var centers: [Int] = []
        var runStart: Int?
        for x in 0..<pixels.width {
            let isSwatch = pixels.rgb(x, row) != background
            if isSwatch, runStart == nil { runStart = x }
            if !isSwatch || x == pixels.width - 1, let begin = runStart {
                centers.append((begin + x) / 2)
                runStart = nil
            }
        }
        try #require(centers.count == 2, "two swatches are drawn")
        func color(_ x: Int) -> UIColor {
            let (red, green, blue) = pixels.rgb(x, row)
            return UIColor(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
        }
        return (color(centers[0]), color(centers[1]))
    }

    /// The ring's gradient runs from `Color.dailyRingTail` (the accent lightened) to the
    /// accent. The head is the accent, held above, and drawn as the asset says; the tail holds the
    /// same 3:1 on every surface, so no part of the stroke fades into it, and it is lighter than the
    /// accent by 1.3:1 at least, so the gradient shows. Both ends are read from the pixels of a
    /// view in the appearance.
    @MainActor @Test func ringGradientHoldsItsContrastInEveryAppearance() async throws {
        var lines: [String] = []
        for appearance in Self.appearances {
            let traits = UITraitCollection(traitsFrom: [
                UITraitCollection(userInterfaceStyle: appearance.style), UITraitCollection(accessibilityContrast: appearance.contrast),
            ])
            let accent = try #require(UIColor(named: "AccentColor", in: .main, compatibleWith: traits))
            let accentLuminance = Self.luminance(accent, in: traits)
            let (head, tail) = try await Self.shown(.dailyRing, .dailyRingTail, in: appearance)
            #expect(abs(Self.luminance(head, in: traits) - accentLuminance) < 0.01, "the head is the asset's accent, \(appearance.name)")
            let tailLuminance = Self.luminance(tail, in: traits)
            let flatness = Self.contrast(tailLuminance, accentLuminance)
            lines.append("\(appearance.name): tail against accent \(String(format: "%.2f", flatness))")
            #expect(tailLuminance > accentLuminance, "the tail is the lighter end, \(appearance.name)")
            #expect(flatness >= 1.3, "the gradient is visible, \(appearance.name)")
            for surface in Self.surfaces {
                let ratio = Self.contrast(tailLuminance, Self.luminance(surface.color, in: traits))
                lines.append("    tail on \(surface.name) \(String(format: "%.2f", ratio))")
                #expect(ratio >= 3, "tail on \(surface.name), \(appearance.name)")
            }
        }
        print(lines.joined(separator: "\n"))
    }
}
