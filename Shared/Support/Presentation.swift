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

    /// The direction of the swipe that gives the grade; the review history shows it beside
    /// the grade's colour.
    var arrow: String {
        switch self {
        case .again: "←"
        case .hard: "↓"
        case .good: "→"
        case .easy: "↑"
        }
    }

    /// The grade's colour: red for Again, the only "no", and three greens for Hard, Good and
    /// Easy, the three kinds of "yes". It fills the grade buttons, the card while it is swiped
    /// and the review history. Always shown together with the grade's title; `onColor` is the
    /// text on it, white on all four.
    ///
    /// Confidence is CHROMA, not lightness. One hue (OKLCH 170°, a jade green, apart from the
    /// maturity ramp's blue at about 255°) and one lightness for all three greens: Hard is a
    /// muted grey-green, Good a medium green, Easy the most vivid green the sRGB gamut has at
    /// that lightness. The first ramp told them apart by lightness (Hard light, Easy dark), and
    /// in dark mode that read backwards, with Hard the brightest button and Easy the darkest.
    /// Equal lightness keeps the buttons equal in weight, and white text (17 pt semibold,
    /// WCAG 4.5:1) works on all of them. The ramp has the same order in light and dark mode;
    /// dark mode lowers the lightness from 0.54 to 0.52 so the fills glare less.
    ///
    /// Values (OKLCH L, C; WCAG contrast of white on the fill; computed with a script, hue 170
    /// for the greens and 27 for the red), light mode / dark mode:
    /// - Again 0xCE0E1A / 0xC4111A: L .54 / .52, C .215 / .205; white 5.7 / 6.1
    /// - Hard  0x63736D / 0x5E6D67: L .54 / .52, C .021 / .020; white 5.0 / 5.4
    /// - Good  0x467B69 / 0x437464: L .54 / .52, C .064 / .060; white 4.9 / 5.4
    /// - Easy  0x0D8265 / 0x0C7B60: L .54 / .52, C .105 / .100; white 4.8 / 5.2
    ///
    /// Distance between neighbours (ΔE as 100 × the distance in OKLab; about 2 is a just
    /// noticeable difference): Hard to Good 4.3 / 3.9, Good to Easy 4.1 / 4.1, Hard to Easy
    /// 8.3 / 8.0. Chroma steps are smaller than the lightness steps of the first ramp (14), so
    /// the buttons also keep their order and their titles. Limit: under deuteranopia (Machado
    /// 2009 simulation) the steps shrink to 0.3 to 0.5 and Hard to Easy to 1.0, so the three
    /// greens read as one green there, and Forgot stays 10 apart from all of them.
    /// Not chroma alone, because a red-green deficiency removes it; hence the title on every
    /// button.
    ///
    /// The card takes the colour while it is swiped (`CardFlight`, at most 70 % over the card
    /// face, with the text in its normal colour): primary text has 5.3 to 7.2:1 on all four at
    /// that tint in light mode and 7.6 to 9.0:1 in dark mode; the secondary text (75 % of the
    /// primary, `Color.cardSecondary`) 4.2 to 5.2:1 in light mode and 5.1 to 5.6:1 in dark mode.
    ///
    /// Why 170°: the first ramp, at 150° with the same lightness steps, was Microsoft Excel's
    /// (0x21A366, 0x107C41, 0x185C37 at 152° to 157°), and the owner saw Office in it. The hues
    /// from 135° to 143° are Office's too (chart green 0x70AD47 and 0x4EA72E, Fluent 0x107C10),
    /// so they are no way out. 170° is the family the owner accepted. Easy, the most vivid of
    /// the three, lies 4.9 ΔE from Excel's 0x107C41 (4.5 in dark mode; 4.0 at 165°; the old Good
    /// the owner accepted, 6.2); if it reads as Office again, move all three greens up in hue.
    var color: Color {
        switch self {
        case .again: Color(light: 0xCE0E1A, dark: 0xC4111A)
        case .hard: Color(light: 0x63736D, dark: 0x5E6D67)
        case .good: Color(light: 0x467B69, dark: 0x437464)
        case .easy: Color(light: 0x0D8265, dark: 0x0C7B60)
        }
    }

    /// Text and symbols on `color`.
    var onColor: Color { .white }

    /// The SF Symbol of the way a swipe gives the grade: ← Forgot, → Good, ↑ Easy, ↓ Hard.
    /// Beside the colour, it says which grade it was to a reader who tells the greens apart
    /// badly.
    var arrowSymbol: String {
        switch self {
        case .again: "arrow.left"
        case .hard: "arrow.down"
        case .good: "arrow.right"
        case .easy: "arrow.up"
        }
    }
}

/// The spacing scale of the study screens, in points: every gap, margin and padding in them is
/// one of these, so the rhythm is the same in every state. `margin` is the iPhone's standard
/// side margin, `gap` what lies between two blocks (the card and its buttons, two bezeled
/// controls), `section` the room a card gives its parts.
enum Spacing {
    static let hairline: CGFloat = 4
    static let tight: CGFloat = 8
    static let gap: CGFloat = 12
    static let margin: CGFloat = 16
    static let section: CGFloat = 24
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

extension CardKind {
    /// Which way the card asks, as the browsers show it.
    var title: String {
        switch self {
        case .recognition: String(localized: "Greek → translation")
        case .production: String(localized: "translation → Greek")
        }
    }
}

extension CardFilter {
    /// The filter's name, the same in every browser: All, Due, New, Learning, Suspended,
    /// Difficult.
    var title: String {
        switch self {
        case .all: String(localized: "All")
        case .due: String(localized: "Due")
        case .new: String(localized: "New")
        case .learning: String(localized: "Learning")
        case .suspended: String(localized: "Suspended")
        case .difficult: String(localized: "Difficult")
        }
    }

    /// What an empty list under the filter says; `nil` for All, whose list is empty only
    /// while the deck has no cards.
    var emptyDescription: String? {
        switch self {
        case .all: nil
        case .due: String(localized: "No card is due right now.")
        case .new: String(localized: "Every card has been studied.")
        case .learning: String(localized: "No card is being learned or relearned.")
        case .suspended: String(localized: "No card is suspended.")
        case .difficult: String(localized: "Cards you keep forgetting show up here.")
        }
    }
}

extension ReviewMode {
    var title: String {
        switch self {
        case .typed: String(localized: "Typed")
        case .revealed: String(localized: "Revealed")
        }
    }
}

/// A maturity as a dot in its colour beside its title.
struct MaturityLabel: View {
    var category: MaturityCategory

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(category.color)
                .frame(width: 8, height: 8)
            Text(category.title)
        }
        .help(category.explanation)
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

    /// What the cards left take, "≈ 7 min", or "< 1 min" for no whole minute (`DailyGoal.minutesLeft`).
    static func timeLeft(minutes: Int) -> String {
        minutes == 0 ? String(localized: "< 1 min") : String(localized: "≈ \(minutes) min")
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
    /// The app's accent. On the iPhone it is named: in a widget `Color.accentColor` is the
    /// system tint (blue), since WidgetKit uses the extension's `AccentColor` only for the
    /// configuration screen. On the Mac `accentColor`, so the system accent setting applies.
    static var appAccent: Color {
        #if os(iOS)
        Color("AccentColor")
        #else
        Color.accentColor
        #endif
    }

    /// The accent for a graphic that may sit on a raised surface: a glyph or a mark in a sheet. In dark a sheet
    /// raises the grouped rows to `#2C2C2E` (`#363638` with Increase Contrast), where the accent holds 2.47:1
    /// (2.97:1), under the 3:1 a graphic needs (WCAG 1.4.11, `references/design-spec.md` §5.1). Drawn there this is
    /// a lighter indigo of the same hue, `#706FDC` (3.32:1) and, with Increase Contrast, `#7B79EA` (3.31:1); drawn
    /// anywhere else it is the accent itself, so one value serves a screen and a sheet: it reads the level the view
    /// is drawn at (`userInterfaceLevel`). Not for the fill of a button with a white label, which asks the darker
    /// accent (4.5:1); the lighter one is 4.20 and 3.64. On the Mac a sheet is not raised: the accent.
    static var appAccentOnRaised: Color {
        #if os(iOS)
        Color(uiColor: UIColor { raisedAccent(in: $0) })
        #else
        Color.accentColor
        #endif
    }

    #if os(iOS)
    /// `appAccentOnRaised` as the traits of a view ask for it.
    static func raisedAccent(in traits: UITraitCollection) -> UIColor {
        guard traits.userInterfaceStyle == .dark, traits.userInterfaceLevel == .elevated else {
            return UIColor(named: "AccentColor", in: .main, compatibleWith: traits) ?? .tintColor
        }
        let hex: UInt32 = traits.accessibilityContrast == .high ? 0x7B79EA : 0x706FDC
        return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
    #endif

    /// The daily ring: the app's accent, indigo `#5856D6` (`AccentColor` holds it as sRGB, with
    /// high-contrast variants `#3634A3` light and `#6563E6` dark).
    /// Indigo because red means Forgot and the greens/teal mean recalled; green read as
    /// Excel and terracotta as Claude (owner, 21.10.2026). On the Mac the user's system
    /// accent shows instead unless it is Multicolor.
    static var dailyRing: Color { .appAccent }

    /// The tail of the ring's gradient (`ProgressRing`): the accent mixed with a quarter of white
    /// in device RGB. It follows the accent in all four appearances. A quarter is the most that
    /// keeps 3:1 on the light grouped grey (a third does not); `AccentContrastTests` holds the
    /// tail to 3:1 on the surfaces and to 1.3:1 against the accent.
    static var dailyRingTail: Color { Color.appAccent.mix(with: .white, by: 0.25, in: .device) }

    /// The face of a flash card: a little off the background, so the card stands out
    /// from the screen it is swiped across. On iOS the grouped pair, as on the Today screen:
    /// a white card on a grey screen in light, a raised grey on black in dark.
    static var cardSurface: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
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
