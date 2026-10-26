import SwiftUI
import VocabCore

/// The daily ring: today's cards done against the daily goal (`ProgressRing`), full once the goal is met, laps past it; a
/// picture with no number in it.
///
/// On the iPhone on the rests, on the Mac in the header of the study stream and on its rests, and in the widget. The
/// model (`DailyRingModel`) takes the figures from the review logs of all decks the app knows.
struct DailyRingView: View {
    /// `nil` before the first evaluation: an empty ring.
    var progress: DailyProgress?
    var diameter: CGFloat = 28
    /// What the ring shows as done while it is ahead of the figures, a card having landed in it; `nil`
    /// shows the figures.
    var shown: Double?
    /// The stroke's thickness; `nil` takes `ProgressRing.lineWidth(diameter:)`.
    var lineWidth: CGFloat?
    /// A tinted or clear widget's ring: one tone, a stronger track (`ProgressRing.isFlat`).
    var isFlat = false

    var body: some View {
        ProgressRing(fraction: DailyRingFigure.fraction(progress, shown: shown), diameter: diameter, lineWidth: lineWidth, isFlat: isFlat)
            .accessibilityElement(children: .ignore)
            .accessibilityHidden(false)
            .accessibilityLabel(Text("Daily Goal"))
            .accessibilityValue(Text(verbatim: Format.percent(min(1, DailyRingFigure.fraction(progress, shown: shown)))))
    }
}
