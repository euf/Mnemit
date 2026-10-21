import SwiftUI
import VocabCore

// User-facing names and colours for values of the core model, in both apps.

extension MaturityCategory {
    var title: String {
        switch self {
        case .new: String(localized: "New")
        case .shaky: String(localized: "Shaky")
        case .young: String(localized: "Young")
        case .maturing: String(localized: "Maturing")
        case .mature: String(localized: "Mature")
        case .mastered: String(localized: "Mastered")
        }
    }

    var explanation: String {
        switch self {
        case .new: String(localized: "Never studied")
        case .shaky: String(localized: "Remembered for less than 4 days")
        case .young: String(localized: "Remembered for 4 to 16 days")
        case .maturing: String(localized: "Remembered for 16 to 64 days")
        case .mature: String(localized: "Remembered for 64 to 256 days")
        case .mastered: String(localized: "Remembered for 256 days or more")
        }
    }

    /// An ordinal one-hue ramp (validated for colour-vision deficiencies in light
    /// and dark mode): the higher the maturity, the more prominent the blue.
    /// New cards are neutral grey, outside the ramp.
    var color: Color {
        switch self {
        case .new: Color(light: 0xB4B2AC, dark: 0x5E5D59)
        case .shaky: Color(light: 0x86B6EF, dark: 0x1C5CAB)
        case .young: Color(light: 0x5598E7, dark: 0x2A78D6)
        case .maturing: Color(light: 0x2A78D6, dark: 0x5598E7)
        case .mature: Color(light: 0x1C5CAB, dark: 0x86B6EF)
        case .mastered: Color(light: 0x104281, dark: 0xB7D3F6)
        }
    }
}

extension Grade {
    var title: String {
        switch self {
        case .again: String(localized: "Again")
        case .hard: String(localized: "Hard")
        case .good: String(localized: "Good")
        case .easy: String(localized: "Easy")
        }
    }

    var shortcutKey: KeyEquivalent {
        KeyEquivalent(Character(String(rawValue)))
    }

    /// The grade's colour: red for Again, the only "no", and three shades of one green
    /// for Hard, Good and Easy, the three kinds of "yes". It fills the grade buttons, the
    /// card while it is swiped and the review history. Always shown together with the
    /// grade's title; `onColor` is the text on it, white on all four.
    ///
    /// How the greens were chosen: one hue (OKLCH 150°, a plain green clearly apart from
    /// the maturity ramp's blue), told apart by lightness alone, which falls from Hard to
    /// Good to Easy in steps of 0.14 OKLCH L, so colour-vision deficiencies don't matter and
    /// the three read as one answer in three strengths. The ramp is the same in light and
    /// dark mode. Contrast of white on the fill (WCAG, computed with a script):
    /// - Hard 0x2E9E52, L 0.62: 3.4:1, the 3:1 of large text, as the labels are 17 pt semibold
    /// - Good 0x007132, L 0.48: 6.2:1
    /// - Easy 0x00451B, L 0.34: 11.3:1
    /// - Again, the system red darkened to carry white text: 5.4:1 on light (0xD70015),
    ///   4.6:1 on dark (0xD93A30)
    var color: Color {
        switch self {
        case .again: Color(light: 0xD70015, dark: 0xD93A30)
        case .hard: Color(light: 0x2E9E52, dark: 0x2E9E52)
        case .good: Color(light: 0x007132, dark: 0x007132)
        case .easy: Color(light: 0x00451B, dark: 0x00451B)
        }
    }

    /// Text and symbols on `color`.
    var onColor: Color { .white }
}

/// A grade's colour as a dot beside its title, with a hairline so the darkest green shows on
/// a dark background too.
struct GradeDot: View {
    var grade: Grade

    var body: some View {
        Circle()
            .fill(grade.color)
            .overlay { Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 0.5) }
            .frame(width: 10, height: 10)
            .accessibilityHidden(true)
    }
}

extension LearningPhase {
    var title: String {
        switch self {
        case .learning: String(localized: "Learning")
        case .review: String(localized: "Review phase")
        case .relearning: String(localized: "Relearning")
        }
    }
}

enum Format {
    /// A duration in days, e.g. "12 days" or "less than a day".
    static func days(_ days: Double) -> String {
        guard days >= 1 else { return String(localized: "less than a day") }
        let rounded = Int(days.rounded())
        return String(localized: "\(rounded) days")
    }

    /// When a card is asked again after a grade, as the end of a sentence: "in 4 days",
    /// "in 2 months", "in 1 year", rounded to one unit; "again today" while the card is
    /// in (re)learning.
    static func interval(_ interval: ReviewInterval) -> String {
        guard case let .days(days) = interval else { return String(localized: "again today") }
        if days < 30 { return String(localized: "in \(days) days") }
        let months = Int((Double(days) / 30.4375).rounded())
        if months < 12 { return String(localized: "in \(months) months") }
        let years = Int((Double(days) / 365.25).rounded())
        return String(localized: "in \(years) years")
    }

    static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    /// When a card is due, relative to now; `nil` for a card without a learning state.
    static func due(_ due: Date?, now: Date) -> String {
        guard let due else { return String(localized: "New") }
        if due <= now { return String(localized: "Now") }
        return due.formatted(.relative(presentation: .named))
    }
}

extension Color {
    /// The face of a flash card: a little off the background, so the card stands out
    /// from the screen it is swiped across.
    static var cardSurface: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }

    /// A colour that adapts to light and dark appearance.
    init(light: UInt32, dark: UInt32) {
        #if os(macOS)
        self.init(
            nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                let hex = isDark ? dark : light
                return NSColor(
                    srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255,
                    alpha: 1
                )
            })
        #else
        self.init(
            uiColor: UIColor { traits in
                let hex = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(
                    red: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255,
                    alpha: 1
                )
            })
        #endif
    }
}
