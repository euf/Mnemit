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

    /// The step of one card, for its corner and the moment it climbs: "Maturing", in Russian «Созревающая».
    var cardTitle: String {
        switch self {
        case .new: String(localized: "card.step.new", defaultValue: "New")
        case .shaky: String(localized: "card.step.shaky", defaultValue: "Shaky")
        case .young: String(localized: "card.step.young", defaultValue: "Young")
        case .maturing: String(localized: "card.step.maturing", defaultValue: "Maturing")
        case .mature: String(localized: "card.step.mature", defaultValue: "Mature")
        case .mastered: String(localized: "card.step.mastered", defaultValue: "Mastered")
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

    /// An ordinal one-hue ramp in the accent's indigo (OKLCH hue 278, lightness 0.86 to 0.40 in light mode and
    /// 0.42 to 0.85 in dark, adjacent steps 10 to 13.5 ΔE2000 apart): the higher the maturity, the more prominent
    /// the indigo, so memory reads in the colour of the ring, apart from the grades' red and greens.
    /// New cards are neutral grey, outside the ramp.
    var color: Color {
        switch self {
        case .new: Color(light: 0xB4B2AC, dark: 0x5E5D59)
        case .shaky: Color(light: 0xC6CDFF, dark: 0x3F3F97)
        case .young: Color(light: 0x9AA3F6, dark: 0x5758C7)
        case .maturing: Color(light: 0x7277EA, dark: 0x7277EA)
        case .mature: Color(light: 0x5350CF, dark: 0x959EF8)
        case .mastered: Color(light: 0x3932A0, dark: 0xC2CAFF)
        }
    }
}

extension StudyCounts {
    /// "4 new · 10 review": what today's plan takes from a deck, the kinds it has none of left out.
    var parts: String {
        [
            new > 0 ? String(localized: "\(new) new") : nil,
            learning > 0 ? String(localized: "\(learning) learning") : nil,
            review > 0 ? String(localized: "\(review) review") : nil,
        ]
        .compactMap { $0 }.joined(separator: " · ")
    }
}

extension AchievementKind {
    /// "A week in a row", "First ring", "50 cards in a day": a streak is named in words, never in days.
    var title: String {
        switch self {
        case let .streak(days):
            switch days {
            case 7: String(localized: "A week in a row")
            case 14: String(localized: "2 weeks in a row")
            case 30: String(localized: "A month in a row")
            case 61: String(localized: "2 months in a row")
            case 91: String(localized: "3 months in a row")
            case 183: String(localized: "Half a year in a row")
            case 365: String(localized: "A year in a row")
            case 548: String(localized: "A year and a half in a row")
            case 730: String(localized: "2 years in a row")
            default: String(localized: "\(days) days in a row")
            }
        case .firstRing: String(localized: "First ring")
        case .perfectWeek: String(localized: "Perfect week")
        case let .bigDay(cards): String(localized: "\(cards) cards in a day")
        case .comeback: String(localized: "Comeback")
        }
    }

    /// What it took, for the line under a medal; `nil` where the title says it.
    var detail: String? {
        switch self {
        case .streak, .bigDay: nil
        case .firstRing: String(localized: "Closed the ring for the first time")
        case .perfectWeek: String(localized: "Seven rings in a row")
        case .comeback: String(localized: "Saved your streak after a missed day")
        }
    }

    /// The emoji of an earned medal (`references/learning-flow.md`, "Emoji or SF Symbols"): the only emoji of the app.
    var face: String {
        switch self {
        case let .streak(days):
            switch days {
            case 7: "\u{2B50}\u{FE0F}"
            case 14: "\u{1F31F}"
            case 30: "\u{1F319}"
            case 61: "\u{1F33F}"
            case 91: "\u{1F333}"
            case 183: "\u{26F0}\u{FE0F}"
            case 365: "\u{1F3C6}"
            case 548: "\u{1F48E}"
            case 730: "\u{1F451}"
            default: "\u{1F525}"
            }
        case .firstRing: "\u{1F3AF}"
        case .perfectWeek: "\u{1F308}"
        case let .bigDay(cards):
            switch cards {
            case 50: "\u{1F4DA}"
            case 100: "\u{1F9E0}"
            case 200: "\u{1F989}"
            default: "\u{1F418}"
            }
        case .comeback: "\u{1F426}\u{200D}\u{1F525}"
        }
    }

    /// What the device remembers a medal by, `CelebratedMedals`: stable, one per kind.
    var key: String {
        switch self {
        case let .streak(days): "streak-\(days)"
        case .firstRing: "firstRing"
        case .perfectWeek: "perfectWeek"
        case let .bigDay(cards): "bigDay-\(cards)"
        case .comeback: "comeback"
        }
    }

    /// How notable a medal is where there is room for one: a streak above the comeback, the big day, the
    /// perfect week and the first ring; within a line the higher tier.
    var notability: Int {
        switch self {
        case let .streak(days): 6000 + days
        case .comeback: 5000
        case let .bigDay(cards): 3000 + cards
        case .perfectWeek: 2000
        case .firstRing: 1000
        }
    }

    /// The SF Symbol of the line, which the grey medal of the next tier shows while its emoji stays a surprise.
    var symbol: String { line.symbol }

    var line: AchievementLine {
        switch self {
        case .streak: .streak
        case .firstRing: .firstRing
        case .perfectWeek: .perfectWeek
        case .bigDay: .bigDay
        case .comeback: .comeback
        }
    }
}

/// The lines of achievements.
enum AchievementLine: CaseIterable, Hashable {
    case streak, firstRing, perfectWeek, bigDay, comeback

    /// The lines of one medal each, which the Progress screen gathers in one row.
    static let single: [AchievementLine] = [.firstRing, .perfectWeek, .comeback]
    /// The lines of tiers, a row each.
    static let tiered: [AchievementLine] = [.streak, .bigDay]

    var symbol: String {
        switch self {
        case .streak: "flame"
        case .firstRing: "circle.circle"
        case .perfectWeek: "calendar"
        case .bigDay: "rectangle.stack"
        case .comeback: "arrow.uturn.up"
        }
    }

    /// Earned again and again: one medal with its count as a badge, not a tier after tier.
    var repeats: Bool { self == .perfectWeek || self == .comeback }
}

/// A medal earned, once or more: of a line that repeats, the count and the day of the last time.
struct EarnedMedal: Hashable {
    var kind: AchievementKind
    var day: Int
    var count: Int
}

extension Array where Element == Achievement {
    /// One medal per kind, in the order each was first earned.
    var medals: [EarnedMedal] {
        var medals: [EarnedMedal] = []
        for achievement in self {
            if let index = medals.firstIndex(where: { $0.kind == achievement.kind }) {
                medals[index].count += 1
                medals[index].day = achievement.day
            } else {
                medals.append(EarnedMedal(kind: achievement.kind, day: achievement.day, count: 1))
            }
        }
        return medals
    }
}

extension Array where Element == Achievement {
    /// The medals earned last, up to five, the newest first: one per kind, with the day of the last time and how
    /// often it was earned.
    var recentMedals: [EarnedMedal] {
        let counts = Dictionary(grouping: self, by: \.kind).mapValues(\.count)
        var seen = Set<AchievementKind>()
        return reversed().filter { seen.insert($0.kind).inserted }.prefix(5).map { EarnedMedal(kind: $0.kind, day: $0.day, count: counts[$0.kind] ?? 1) }
    }

    /// The most notable medal, for a screen with room for one, and how many others there are.
    var featured: (medal: AchievementKind, others: Int)? {
        let kinds = Set(map(\.kind))
        guard let best = kinds.max(by: { $0.notability < $1.notability }) else { return nil }
        return (best, kinds.count - 1)
    }
}

/// The tier a line offers next and how far the learner is from it: the grey medal of the Progress screen.
struct NextTier: Hashable {
    var kind: AchievementKind
    /// Where the learner stands: the streak's days, the rings of the run or the cards of the best day.
    var value = 0
    /// What the tier asks; `nil` for a tier with no count to work toward.
    var goal: Int?

    /// "12 of 14 days", "3 of 7 rings", "76 of 100 cards"; `nil` without a goal.
    var hint: String? {
        guard let goal else { return nil }
        switch kind {
        case .streak: return String(localized: "\(value) of \(goal) days")
        case .perfectWeek: return String(localized: "\(value) of \(goal) rings")
        case .bigDay: return String(localized: "\(value) of \(goal) cards")
        case .firstRing, .comeback: return nil
        }
    }

    /// The next unearned tier of `line`, `nil` once all are earned. A line that repeats always has one: the
    /// comeback, which can't be worked toward, and the perfect week, whose run of rings counts. The big
    /// day counts the best day on record, as a tier is reached in one day, never added up over days.
    static func of(_ line: AchievementLine, earned: [Achievement], records: [DayRecord], streak: Int) -> NextTier? {
        let kinds = Set(earned.map(\.kind))
        switch line {
        case .streak:
            return Achievements.streakMilestones.first { !kinds.contains(.streak(days: $0)) }
                .map { NextTier(kind: .streak(days: $0), value: streak, goal: $0) }
        case .firstRing:
            return kinds.contains(.firstRing) ? nil : NextTier(kind: .firstRing)
        case .perfectWeek:
            return NextTier(kind: .perfectWeek, value: ringRun(records) % 7, goal: 7)
        case .bigDay:
            let best = records.map(\.done).max() ?? 0
            return Achievements.bigDayTiers.first { !kinds.contains(.bigDay(cards: $0)) }.map { NextTier(kind: .bigDay(cards: $0), value: best, goal: $0) }
        case .comeback:
            return NextTier(kind: .comeback)
        }
    }

    /// The days in a row up to now whose ring closed with work in it; today, while its ring is open, doesn't end the
    /// run, as it can still close.
    private static func ringRun(_ records: [DayRecord]) -> Int {
        var run = 0
        for (index, record) in records.reversed().enumerated() {
            if record.closed && record.done > 0 {
                run += 1
            } else if index > 0 {
                break
            }
        }
        return run
    }
}

/// A colour in light and in dark mode, as sRGB hex.
struct AppearanceColor: Equatable {
    var light: UInt32
    var dark: UInt32

    var color: Color { Color(light: light, dark: dark) }
}

/// The colours of one grade, see `Grade.color`; `label`, `tint` and `ring` follow the fill unless given.
struct GradeSwatch: Equatable {
    var fill: AppearanceColor
    var label: AppearanceColor
    var tint: AppearanceColor
    var ring: AppearanceColor

    init(fill: AppearanceColor, label: AppearanceColor = .init(light: 0xFFFFFF, dark: 0xFFFFFF), tint: AppearanceColor? = nil, ring: AppearanceColor? = nil) {
        self.fill = fill
        self.label = label
        self.tint = tint ?? fill
        self.ring = ring ?? fill
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
    /// the grade's colour, and on the Mac the grade's button carries it as its key.
    var arrow: String {
        switch self {
        case .again: "←"
        case .hard: "↓"
        case .good: "→"
        case .easy: "↑"
        }
    }

    /// The arrow key that gives the grade on the Mac: the swipe's direction, `arrow`.
    var arrowKey: KeyEquivalent {
        switch self {
        case .again: .leftArrow
        case .hard: .downArrow
        case .good: .rightArrow
        case .easy: .upArrow
        }
    }

    /// The grade's colour: red for Again, the only "no", and three greens for Hard, Good and
    /// Easy, the three kinds of "yes". It fills the grade buttons and the review history and, as `tint`,
    /// the card while it is swiped. Always shown together with the grade's title; `onColor` is the
    /// text on it: white on Again, Good and Easy, a dark green on Hard.
    ///
    /// One hue (OKLCH 170°, a jade green, apart from the maturity ramp's blue at about 255°). Hard is
    /// the light end of the ramp, a pale green with a dark green label, so it reads as the lightest
    /// "yes" and not as a disabled button; Good is a medium green and Easy the most vivid green the sRGB
    /// gamut has at that lightness, both with white text. Good and Easy are told apart by chroma.
    ///
    /// Values (OKLCH L, C; WCAG contrast of the label on the fill; computed with a script, hue 170 for
    /// the greens and 27 for the red), light mode / dark mode, as `GradeSwatch` holds them:
    /// - Again 0xCE0E1A / 0xC4111A: L .54 / .52, C .215 / .205; white 5.7 / 6.1
    /// - Hard  0xB1E5D1 / 0x91C4B1: L .88 / .78, C .060 / .060; 0x0F3B2C / 0x0B2A20 8.9 / 7.9
    /// - Good  0x467B69 / 0x437464: L .54 / .52, C .064 / .060; white 4.9 / 5.4
    /// - Easy  0x0D8265 / 0x0C7B60: L .54 / .52, C .105 / .100; white 4.8 / 5.2
    ///
    /// Distance between neighbours (ΔE as 100 × the distance in OKLab; about 2 is a just
    /// noticeable difference): Hard to Good 34.0 / 26.0, Good to Easy 4.1 / 4.1. Lightness tells Hard from
    /// the two others, chroma tells Good from Easy; hence the title on every button, because a red-green
    /// deficiency removes chroma.
    ///
    /// The card takes `tint` while it is swiped (`CardFlight`, at most 70 % over the card face, with the
    /// text in its normal colour, which never changes with the swipe): `GradeContrastTests` holds the
    /// numbers, 5.5:1 or more for the primary text on all four tints in light mode and 7.1:1 or more in dark
    /// mode, 4.3:1 or more for the secondary text (75 % of the primary, `Color.cardSecondary`) in light
    /// mode and 4.7:1 in dark mode.
    /// In dark mode Hard's tint is a mid green (0x527165), not its pale fill, which would leave white
    /// text 3.2:1 on the Mac's raised card.
    ///
    /// Why 170°: a ramp at 150° with the same steps was Microsoft Excel's (0x21A366, 0x107C41, 0x185C37 at
    /// 152° to 157°), and the owner saw Office in it. The hues from 135° to 143° are Office's too (chart
    /// green 0x70AD47 and 0x4EA72E, Fluent 0x107C10), so they are no way out. 170° is the family the owner
    /// accepted. Easy, the most vivid of the three, lies 4.9 ΔE from Excel's 0x107C41 (4.5 in dark mode;
    /// 4.0 at 165°); if it reads as Office again, move all three greens up in hue.
    var color: Color { swatch.fill.color }

    /// Text and symbols on `color`.
    var onColor: Color { swatch.label.color }

    /// The colour the swiped card takes (`FlightCard`): `color`, except Hard in dark mode.
    var tint: Color { swatch.tint.color }

    /// A ring round the grade's button while a swipe is about to give it, clear of the fill, on the
    /// screen's background: `color`, except Hard in light mode, whose pale fill would not show.
    var ring: Color { swatch.ring.color }

    /// The colours of the grade as hex values, `color`, `onColor`, `tint` and `ring` made of them.
    var swatch: GradeSwatch {
        switch self {
        case .again: GradeSwatch(fill: .init(light: 0xCE0E1A, dark: 0xC4111A))
        case .hard:
            GradeSwatch(
                fill: .init(light: 0xB1E5D1, dark: 0x91C4B1), label: .init(light: 0x0F3B2C, dark: 0x0B2A20),
                tint: .init(light: 0xB1E5D1, dark: 0x527165), ring: .init(light: 0x438A73, dark: 0x91C4B1))
        case .good: GradeSwatch(fill: .init(light: 0x467B69, dark: 0x437464))
        case .easy: GradeSwatch(fill: .init(light: 0x0D8265, dark: 0x0C7B60))
        }
    }

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
    /// Which way the card asks, in every view: Word → Meaning, Meaning → Word.
    var title: String {
        switch self {
        case .recognition: String(localized: "Word → Meaning")
        case .production: String(localized: "Meaning → Word")
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

/// Where a card stands, as one line in the colour of its step on the ladder of memory: "Young · next review in
/// 3 days", "Shaky · due now", "New". The colour is a dot, as in the ladder's legend on Progress: the step's
/// words stay in the text colour, since the palest steps are no colour for text. Card Detail and the Mac inspector
/// show it; stability, difficulty and the other figures go under their Details.
struct CardMemoryLine: View {
    var card: Card
    var now: Date

    /// The line as words.
    static func text(of card: Card, now: Date) -> String {
        let step = MaturityCategory(card: card).cardTitle
        guard let due = card.learningState?.due else { return step }
        if due <= now { return String(localized: "\(step) · due now") }
        return String(localized: "\(step) · next review \(Format.due(due, now: now))")
    }

    var body: some View {
        let step = MaturityCategory(card: card)
        HStack(spacing: Spacing.tight) {
            Circle()
                .fill(step.color)
                .overlay { Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 0.5) }
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            Text(verbatim: Self.text(of: card, now: now))
        }
        .help(step.explanation)
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
    /// The app's accent, indigo on both apps: named, as in a widget `Color.accentColor` is the system tint (blue),
    /// since WidgetKit uses the extension's `AccentColor` only for the configuration screen, and on the Mac
    /// `accentColor` is the system accent (graphite, say), which turned the ring and Study grey. The Mac's windows
    /// take it as their tint (`brandTint()`).
    static var appAccent: Color {
        Color("AccentColor")
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
        Color("AccentColor")
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

    /// The streak's flame, filled once today keeps it and outlined in this colour when the streak is at risk: orange,
    /// the one hue of the app that means the habit (red is Forgot, the greens are recalled, indigo is the ring and
    /// the accent). `#E05A00` holds 3.7:1 on white and 3.3:1 on the light grouped grey, `#FF9F0A` (system orange)
    /// 8:1 on the dark raised grey, above the 3:1 a glyph needs. A streak not kept yet has a grey outline.
    static let streak = Color(light: 0xE05A00, dark: 0xFF9F0A)

    /// The face of a flash card: a little off the background, so the card stands out
    /// from the screen it is swiped across. On iOS the grouped pair, as on the Today screen:
    /// a white card on a grey screen in light, a raised grey on black in dark.
    static var cardSurface: Color {
        #if os(macOS)
        Color(light: 0xFFFFFF, dark: 0x2C2C2E)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }

    /// What a card lies on in the study stream: the grouped background, a grey in light and near black in dark, so
    /// the white or raised card stands out as it does on the iPhone.
    static var studyBackdrop: Color {
        #if os(macOS)
        Color(light: 0xF2F2F7, dark: 0x1C1C1E)
        #else
        Color(uiColor: .systemGroupedBackground)
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

extension View {
    /// The app's indigo as the tint of a Mac window's controls, whatever the system accent: the ring, Study and the
    /// links look as they do on the iPhone.
    func brandTint() -> some View {
        tint(Color.appAccent)
    }
}
