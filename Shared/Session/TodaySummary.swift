import SwiftUI
import VocabCore

/// Today's ring at hero size, 168 pt on the iPhone: a picture with no number in it, its stroke a tenth of its size,
/// filling slowly. With no figures (`progress` is `nil`) an empty ring. The same ring as everywhere (`ProgressRing`); only
/// the size and the speed of the fill are Today's.
struct HeroRing: View {
    var progress: DailyProgress?
    var diameter: CGFloat = 168

    var body: some View {
        ProgressRing(
            fraction: DailyRingFigure.fraction(progress, shown: nil), diameter: diameter, filling: .smooth(duration: 1.4),
            lineWidth: diameter * 18 / 168)
    }
}

/// Today's hero: the ring, a picture; under it the streak line (`StreakLine`: the status of the day, which the ring leads);
/// then the sentence, the next moment of the day and its minutes (`NextStep`: the action, which leads to the button), the
/// words learned ("412 words learned · +12 today") and the week's rings. On the iPhone's Today at 168 pt, with the whole
/// hero a button to Progress; the Mac's Today at its own size.
struct TodayHero: View {
    var progress: DailyProgress?
    var now: Date
    /// `false` until the decks are read: the figures are placeholders then.
    var isLoaded: Bool
    var ringSize: CGFloat = 168
    var showsWeek = true
    /// A chevron at the end of the week's row: this hero opens Progress.
    var showsChevron = false

    var body: some View {
        // 24 pt between the parts: the status (the ring and its streak line), the action (the sentence with the words), the week.
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                HeroRing(progress: isLoaded ? progress : nil, diameter: ringSize)
                StreakLine(step: step)
                    .multilineTextAlignment(.center)
                    .redacted(reason: isLoaded ? [] : .placeholder)
            }
            VStack(spacing: 12) {
                NextStepText(step: step)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .redacted(reason: isLoaded ? [] : .placeholder)
                learned
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .redacted(reason: isLoaded ? [] : .placeholder)
            }
            if showsWeek { week }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// The day's words and streak, or a placeholder's while the decks are read.
    private var step: NextStep {
        if let progress, isLoaded { return NextStep(progress) }
        return NextStep(days: 12, state: .open, isClosed: false, minutesToKeep: 2)
    }

    /// "412 words learned · +12 today": the gain of the day is left out on a day that has none.
    @ViewBuilder
    private var learned: some View {
        if let progress, isLoaded {
            if let line = progress.learned.line { Text(verbatim: line) }
        } else {
            Text("\(412) words learned")
        }
    }

    private var week: some View {
        let loaded = isLoaded ? progress : nil
        return WeekRings(week: loaded?.week.count == 7 ? loaded!.week : Array(repeating: nil, count: 7), rings: loaded?.weekRings, today: DailyRingFigure.fraction(loaded, shown: nil), now: now)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
                if showsChevron {
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
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
