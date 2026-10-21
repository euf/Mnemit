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
}
