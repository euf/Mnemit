import SwiftUI

/// Today's ring: one ring in the accent colour, a track behind it, a check mark once it is
/// full. It is not an Activity ring: no gradient, no glyph at the head, no second ring.
///
/// Decoration only, the text beside it says the figures; the caller combines them for
/// VoiceOver.
struct ProgressRing: View {
    /// 0 to 1; more than 1 shows a full ring.
    var fraction: Double
    var diameter: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let line = diameter * 0.14
        ZStack {
            Circle()
                .stroke(.fill.tertiary, lineWidth: line)
            if fraction > 0 {
                Circle()
                    .trim(from: 0, to: min(fraction, 1))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            if fraction >= 1 {
                Image(systemName: "checkmark")
                    .font(.system(size: diameter * 0.34, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: diameter, height: diameter)
        .animation(reduceMotion ? nil : .smooth, value: fraction)
        .accessibilityHidden(true)
    }
}
