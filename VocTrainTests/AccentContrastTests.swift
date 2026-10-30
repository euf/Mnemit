import SwiftUI
import Testing
import UIKit
import VocabCore

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
        let pixels = try PixelBitmap(image)
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

    /// `color` in `traits` as SwiftUI's resolved colour, for `OKLCH`.
    static func resolved(_ color: UIColor, in traits: UITraitCollection) -> Color.Resolved {
        var (red, green, blue, alpha): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        color.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return Color.Resolved(colorSpace: .sRGB, red: Float(red), green: Float(green), blue: Float(blue), opacity: Float(alpha))
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
        let pixels = try PixelBitmap(image)
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

    /// The ring's gradient runs from the accent (`Color.dailyRing`) to `Color.dailyRingTail(of:scheme:)`: lighter and
    /// 20° of hue towards violet, as Apple's Activity rings move. The head is the asset's accent; the tail holds 3:1 on
    /// every surface, so no part of the stroke fades into it, and differs from the head by 1.5:1 of luminance and 15–25°
    /// of hue. Both ends are read from the pixels of a view in the appearance.
    @MainActor @Test func ringGradientHoldsItsContrastInEveryAppearance() async throws {
        var lines: [String] = []
        for appearance in Self.appearances {
            let traits = UITraitCollection(traitsFrom: [
                UITraitCollection(userInterfaceStyle: appearance.style), UITraitCollection(accessibilityContrast: appearance.contrast),
            ])
            let accent = try #require(UIColor(named: "AccentColor", in: .main, compatibleWith: traits))
            let accentLuminance = Self.luminance(accent, in: traits)
            let scheme: ColorScheme = appearance.style == .dark ? .dark : .light
            let (head, tail) = try await Self.shown(.dailyRing, .dailyRingTail(of: Self.resolved(accent, in: traits), scheme: scheme), in: appearance)
            let headLuminance = Self.luminance(head, in: traits)
            let tailLuminance = Self.luminance(tail, in: traits)
            #expect(abs(headLuminance - accentLuminance) < 0.01, "the head is the asset's accent, \(appearance.name)")
            let spread = Self.contrast(tailLuminance, headLuminance)
            let turn = OKLCH.value(of: Self.resolved(tail, in: traits)).hue - OKLCH.value(of: Self.resolved(head, in: traits)).hue
            lines.append("\(appearance.name): tail against head \(String(format: "%.2f", spread)), hue \(String(format: "%.1f", turn))°")
            #expect(tailLuminance > headLuminance, "the tail is the lighter end, \(appearance.name)")
            #expect(spread >= 1.5, "the ends differ in luminance, \(appearance.name)")
            #expect((15...25).contains(turn), "the tail turns towards violet, \(appearance.name)")
            for surface in Self.surfaces {
                let ratio = Self.contrast(tailLuminance, Self.luminance(surface.color, in: traits))
                lines.append("    tail on \(surface.name) \(String(format: "%.2f", ratio))")
                #expect(ratio >= 3, "tail on \(surface.name), \(appearance.name)")
            }
        }
        print(lines.joined(separator: "\n"))
    }
}

// MARK: The accent as text, the marks of what is not there, the ramp, the track

extension AccentContrastTests {
    /// The accent as text (`Color.appAccentText`): 4.5:1 or more on every surface of a screen and of a sheet in all four
    /// appearances; in light the accent itself, in dark a lighter indigo of the same hue. The accent alone holds 3.0:1 on
    /// the card and 2.5:1 on a sheet's rows, which is why a label in it was hard to read.
    @Test func theTextAccentHoldsFourAndAHalfToOneOnEverySurface() throws {
        var lines: [String] = []
        for appearance in Self.appearances {
            let screen = Self.traits(appearance)
            let sheet = Self.traits(appearance, level: .elevated)
            let accent = try #require(UIColor(named: "AccentColor", in: .main, compatibleWith: screen))
            let accentLuminance = Self.luminance(accent, in: screen)
            for (traits, surfaces) in [(screen, Self.surfaces), (sheet, Self.raisedSurfaces)] {
                let text = Color.textAccent(in: traits)
                let textLuminance = Self.luminance(text, in: traits)
                lines.append("\(appearance.name), level \(traits.userInterfaceLevel.rawValue): text accent \(Self.hex(text, in: traits))")
                for surface in surfaces {
                    let ratio = Self.contrast(textLuminance, Self.luminance(surface.color, in: traits))
                    lines.append("    on \(surface.name) \(Self.hex(surface.color, in: traits)): \(String(format: "%.2f", ratio))")
                    #expect(ratio >= 4.5, "text accent on \(surface.name), \(appearance.name), level \(traits.userInterfaceLevel.rawValue)")
                }
            }
            let text = Color.textAccent(in: screen)
            if appearance.style == .light {
                #expect(abs(Self.luminance(text, in: screen) - accentLuminance) < 0.001, "in light it is the accent, \(appearance.name)")
            } else {
                var (hue, otherHue) = (CGFloat(0), CGFloat(0))
                accent.resolvedColor(with: screen).getHue(&hue, saturation: nil, brightness: nil, alpha: nil)
                text.getHue(&otherHue, saturation: nil, brightness: nil, alpha: nil)
                #expect(abs(hue - otherHue) < 0.02, "the hue stays, \(appearance.name)")
                #expect(Self.luminance(text, in: screen) > accentLuminance, "the lighter one, \(appearance.name)")
            }
        }
        print(lines.joined(separator: "\n"))
    }

    /// The ring of a missed day and the outline of a medal not yet earned (`Color.inactiveMark`): 3:1 or more on the surfaces
    /// of a screen, in grey, so they stay a quiet mark and not progress.
    @Test func theInactiveMarkHoldsThreeToOneOnEveryScreenSurface() {
        var lines: [String] = []
        for appearance in Self.appearances {
            let traits = Self.traits(appearance)
            let mark = UIColor(Color.inactiveMark)
            let luminance = Self.luminance(mark, in: traits)
            lines.append("\(appearance.name): mark \(Self.hex(mark, in: traits))")
            for surface in Self.surfaces {
                let ratio = Self.contrast(luminance, Self.luminance(surface.color, in: traits))
                lines.append("    on \(surface.name) \(Self.hex(surface.color, in: traits)): \(String(format: "%.2f", ratio))")
                #expect(ratio >= 3, "inactive mark on \(surface.name), \(appearance.name)")
            }
            var (hue, saturation) = (CGFloat(0), CGFloat(0))
            mark.resolvedColor(with: traits).getHue(&hue, saturation: &saturation, brightness: nil, alpha: nil)
            #expect(saturation < 0.08, "grey, not a colour, \(appearance.name)")
        }
        print(lines.joined(separator: "\n"))
    }

    /// The words of a medal not yet earned (`Color.lockedText`) hold 4.5:1 on the surfaces of a screen, in grey.
    @Test func theLockedMedalTextHoldsFourAndAHalfToOneOnEveryScreenSurface() {
        for appearance in Self.appearances {
            let traits = Self.traits(appearance)
            let text = UIColor(Color.lockedText)
            let luminance = Self.luminance(text, in: traits)
            for surface in Self.surfaces {
                let ratio = Self.contrast(luminance, Self.luminance(surface.color, in: traits))
                #expect(ratio >= 4.5, "locked medal text on \(surface.name), \(appearance.name): \(String(format: "%.2f", ratio))")
            }
            var saturation = CGFloat(0)
            text.resolvedColor(with: traits).getHue(nil, saturation: &saturation, brightness: nil, alpha: nil)
            #expect(saturation < 0.08, "grey, \(appearance.name)")
        }
    }

    /// The maturity ramp is one ordinal hue (278°, lightness steps of 0.085 or more in one direction), and in dark its
    /// lowest step stays off the card (2.4:1 on `#1C1C1E`; the former step was 1.9:1) and New, the grey outside it, holds 3:1.
    @Test func theMaturityRampStaysOneOrdinalHueAndItsLowestStepStaysOffTheCard() throws {
        let steps = MaturityCategory.allCases.filter { $0 != .new }
        for appearance in Self.appearances where appearance.contrast == .normal {
            let traits = Self.traits(appearance)
            let colors = steps.map { UIColor($0.color) }
            let values = colors.map { OKLCH.value(of: Self.resolved($0, in: traits)) }
            for (lower, higher) in zip(values, values.dropFirst()) {
                let rise = appearance.style == .dark ? higher.lightness - lower.lightness : lower.lightness - higher.lightness
                #expect(rise >= 0.085, "the ramp is ordered by lightness, \(appearance.name)")
            }
            for value in values { #expect((274...282).contains(value.hue), "one hue, \(appearance.name)") }
            guard appearance.style == .dark else { continue }
            let card = Self.luminance(.secondarySystemGroupedBackground, in: traits)
            let lowest = Self.contrast(Self.luminance(colors[0], in: traits), card)
            let new = Self.contrast(Self.luminance(UIColor(MaturityCategory.new.color), in: traits), card)
            #expect(lowest >= 2.4, "the lowest step on the card, \(lowest)")
            #expect(new >= 3, "New on the card, \(new)")
        }
    }

    /// The unfilled part of a ring in dark is a visible circle: 1.4:1 or more of the accent over black and over the card
    /// (0.15 was 1.1:1), and a stronger track than in light.
    @Test func theTrackOfARingShowsInDark() throws {
        let dark = Self.traits(Self.appearances[1])
        let accent = try #require(UIColor(named: "AccentColor", in: .main, compatibleWith: dark))
        let alpha = RingDrawing.trackAlpha(isFlat: false, isDark: true)
        #expect(alpha > RingDrawing.trackAlpha(isFlat: false, isDark: false))
        var (red, green, blue, opacity) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        accent.resolvedColor(with: dark).getRed(&red, green: &green, blue: &blue, alpha: &opacity)
        for surface in [UIColor.systemBackground, .secondarySystemGroupedBackground] {
            var (r, g, b, a) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
            surface.resolvedColor(with: dark).getRed(&r, green: &g, blue: &b, alpha: &a)
            let track = UIColor(red: red * alpha + r * (1 - alpha), green: green * alpha + g * (1 - alpha), blue: blue * alpha + b * (1 - alpha), alpha: 1)
            let ratio = Self.contrast(Self.luminance(track, in: dark), Self.luminance(surface, in: dark))
            #expect(ratio >= 1.4, "the track on \(Self.hex(surface, in: dark)): \(ratio)")
        }
    }

    /// A past day after the first study day with nothing done is a missed day, drawn as a `MissedDayMark`; today, a partial
    /// day, a closed one and the days before the first study day are not.
    @Test func aPastDayWithNothingDoneIsMissed() {
        let week: [Bool?] = [nil, false, true, false, false, true, false]
        let rings: [Double?] = [nil, 0, 1, 0.4, 0, 1, 0]
        let missed = week.indices.map { WeekRings.isMissed($0, week: week, rings: rings) }
        #expect(missed == [false, true, false, false, true, false, false])
        // Without the shares, as in the widget: a day that did not close is missed.
        let flat = week.indices.map { WeekRings.isMissed($0, week: week, rings: nil) }
        #expect(flat == [false, true, false, true, true, false, false])
    }
}
