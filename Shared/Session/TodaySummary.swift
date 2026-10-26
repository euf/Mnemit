import SwiftUI
import VocabCore
import WidgetKit

/// Today's ring at hero size, 112 pt in the card: a picture with no number in it, its stroke a tenth of its size,
/// filling slowly. With no figures (`progress` is `nil`) an empty ring. The same ring as everywhere (`ProgressRing`); only
/// the size and the speed of the fill are Today's. VoiceOver reads "Daily Goal" and its percent.
struct HeroRing: View {
    var progress: DailyProgress?
    var diameter: CGFloat = 112

    var body: some View {
        ProgressRing(
            fraction: DailyRingFigure.fraction(progress, shown: nil), diameter: diameter, filling: .smooth(duration: 1.4),
            lineWidth: diameter * 18 / 168
        )
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(progress == nil)
        .accessibilityLabel(Text("Daily Goal"))
        .accessibilityValue(Text(verbatim: Format.percent(min(1, DailyRingFigure.fraction(progress, shown: nil)))))
    }
}

/// Today's ring and figures in the screens' grammar (`references/product-model.md`, "The grammar of the screens"): three
/// figures, each a label over a value in its entity's colour. **Day streak**: the flame by its state and the days in the
/// streak's orange; **the next moment** (`NextStep.moment`): "To keep your streak" over "≈ 2 min" in the ring's indigo, "Today"
/// over "All done" once nothing is left; **Words learned**: the words, "+12 today" after them on a day that added some. The
/// card on the screens puts them beside the ring and the widgets draw their own ring, so the figures are a view of their own.
struct TodayFigures: View {
    var step: NextStep
    /// The words learned and the day's gain; `nil` leaves the figure out, as for a widget snapshot an older app wrote.
    var words: Int?
    var gain: Int?
    var size: FigureSize = .regular
    /// In a widget: the values, and the flame once it is not an outline, join the accent group of a tinted rendering.
    var accentable = false

    var body: some View {
        VStack(alignment: .leading, spacing: size == .regular ? 10 : 2) {
            StreakFigure(step: step, size: size, accentable: accentable)
            moment
            if let words { learned(words) }
        }
    }

    /// The next moment, its minutes unbroken; a dash while it has no price.
    private var moment: some View {
        let moment = step.moment
        return Figure(label: Text(verbatim: moment.label), value: Text(verbatim: NextStep.unbroken(moment.value ?? "–")), tint: .appAccent, size: size, accentable: accentable)
    }

    private func learned(_ words: Int) -> some View {
        Figure(label: Text("Words learned"), value: Text(words, format: .number), caption: gain.flatMap { $0 > 0 ? Text("+\($0) today") : nil }, size: size, accentable: accentable)
    }
}

/// The streak as a figure: "Day streak" over the flame by its state and the days in the streak's orange; the small widget draws
/// it alone. VoiceOver reads the days and the state, which the flame's shape shows.
struct StreakFigure: View {
    var step: NextStep
    var size: FigureSize = .regular
    var accentable = false

    var body: some View {
        Figure(label: Text("Day streak"), value: Text(verbatim: step.days.formatted(.number.grouping(.never))), tint: .streak, size: size, accentable: accentable) {
            StreakFlame(state: step.state)
                .font(size.valueFont)
                .widgetAccentable(accentable && step.state != .open)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: step.streakSpoken))
    }
}

/// Today's card, which the iPhone's list draws as its first section and the Mac's page on a ground of its own: the ring on the
/// left (112 pt, scaled with the text), its three figures on the right (`TodayFigures`) and, under a divider, the week's small
/// rings with their letters. Where the figures do not fit beside the ring, at the large text sizes, the ring stands over them.
///
/// With `open` the whole card is a button to Progress, a chevron at the end of the week's row; the button sits behind the
/// card, so VoiceOver reads the ring and each figure on its own. `nil` for a picture.
struct TodayCard: View {
    var progress: DailyProgress?
    var now: Date
    /// `false` until the decks are read: the figures are placeholders then.
    var isLoaded: Bool
    var open: (() -> Void)?
    var showsWeek = true

    @ScaledMetric(relativeTo: .title) private var ringSize: CGFloat = 112

    var body: some View {
        VStack(spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) {
                    ring
                    figures
                }
                VStack(spacing: 16) {
                    ring
                    figures
                }
            }
            if showsWeek {
                Divider()
                week
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background { opener }
    }

    private var ring: some View {
        HeroRing(progress: isLoaded ? progress : nil, diameter: ringSize)
    }

    /// The figures of the day, or placeholders (12 days, 2 min, 412 words) while the decks are read.
    private var figures: some View {
        guard let progress = isLoaded ? progress : nil else {
            return TodayFigures(step: NextStep(days: 12, state: .open, isClosed: false, minutesToKeep: 2), words: 412, gain: 12)
                .redacted(reason: .placeholder)
        }
        return TodayFigures(step: NextStep(progress), words: progress.learned.words, gain: progress.learned.shownGain)
            .redacted(reason: [])
    }

    @ViewBuilder
    private var opener: some View {
        if let open {
            Button(action: open) { Color.clear.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Progress"))
        }
    }

    private var week: some View {
        let loaded = isLoaded ? progress : nil
        let chevron = Image(systemName: "chevron.forward")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
        // The rings stay centred: an invisible chevron balances the visible one, and the two never overlap the letters.
        return HStack(spacing: 8) {
            if open != nil { chevron.hidden() }
            WeekRings(week: loaded?.week.count == 7 ? loaded!.week : Array(repeating: nil, count: 7), rings: loaded?.weekRings, today: DailyRingFigure.fraction(loaded, shown: nil), now: now)
                .frame(maxWidth: .infinity)
            if open != nil { chevron }
        }
    }
}

/// The card of a day with no deck: the empty ring and what to do, "Add the words you are learning."
struct EmptyTodayCard: View {
    @ScaledMetric(relativeTo: .title) private var ringSize: CGFloat = 112
    @Environment(\.dynamicTypeSize) private var type

    /// The sentence wraps beside the ring; at the accessibility sizes the ring stands over it.
    var body: some View {
        let layout = type.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 16)) : AnyLayout(HStackLayout(spacing: 20))
        layout {
            HeroRing(progress: nil, diameter: ringSize)
            Text("Add the words you are learning.")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

extension View {
    /// The date of today's study day under the title, "Tuesday, October 27": the study day, which a night before 04:00 still
    /// belongs to the day before.
    func todaySubtitle(_ now: Date) -> some View {
        let calendar = StudyCalendar()
        return navigationSubtitle(Text(calendar.start(ofDay: calendar.dayNumber(for: now)), format: .dateTime.weekday(.wide).day().month(.wide)))
    }
}

/// What Today's one button does next, named with the words of the rests: **Study** while the ring is open; **Catch
/// Up** once the ring is closed and the plan has cards left; **Learn 10 New Words** (case `pushOn`) once the day's
/// stack is done, ten new cards at once. The iPhone's Today and the Mac's Today window say the same.
enum DayAction: Equatable {
    case study, catchUp, pushOn

    /// What the button does for a day with `due` cards of the plan left.
    init(due: Int, progress: DailyProgress?) {
        if due == 0 {
            self = .pushOn
        } else if progress?.ring.isGoalMet == true {
            self = .catchUp
        } else {
            self = .study
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .study: "Study"
        case .catchUp: "Catch Up"
        case .pushOn: "Learn 10 New Words"
        }
    }
}
