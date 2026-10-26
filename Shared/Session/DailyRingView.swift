import SwiftUI
import VocabCore

/// The daily ring: today's cards done against the daily goal (`ProgressRing`), full once the goal is met, with the
/// cards left or a check in its middle where it is big enough (`RingCenter`).
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
    /// Whether the middle shows: the ring that comes down to the rest shows it once it has arrived.
    var showsCenter = true
    /// The stroke's thickness; `nil` takes `ProgressRing.lineWidth(diameter:)`.
    var lineWidth: CGFloat?

    var body: some View {
        ProgressRing(fraction: DailyRingFigure.fraction(progress, shown: shown), diameter: diameter, center: center, lineWidth: lineWidth)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(center.shown(at: diameter).spokenLabel.map { Text(verbatim: $0) } ?? Text("Daily Goal"))
            .accessibilityValue(progress.map { Text("\($0.ring.done) / \($0.ring.goal)") } ?? Text(verbatim: ""))
    }

    private var center: RingCenter { showsCenter ? RingCenter(progress) : .none }
}
