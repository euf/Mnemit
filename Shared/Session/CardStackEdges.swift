import SwiftUI

/// The cards of the stack under the card on top: blank sheets with the card's corner radius under its bottom
/// edge, each `step` lower and `side` narrower on each side than the one above, a shade darker and with a
/// fainter outline the deeper it lies, so the stack reads as a stack at a glance and thins out sheet by sheet. A level is how deep an edge lies: 0 the top card, 1 the card that rises
/// next, which takes the pose of level 1 before it does.
enum StackPose {
    /// The edges that show under the top card, however many cards wait.
    static let maxEdges = 4
    /// How much lower each edge lies than the one above.
    static let step: CGFloat = 6
    /// How much narrower, on each side.
    static let side: CGFloat = 6

    /// How far the edge of `level` lies below the place of the top card.
    static func drop(_ level: Int) -> CGFloat { step * CGFloat(level) }

    static func width(_ level: Int, cardWidth: CGFloat) -> CGFloat { max(0, cardWidth - 2 * side * CGFloat(level)) }

    /// How much of the outline's colour an edge keeps: all of the first, less with depth.
    static func faintness(_ level: Int) -> Double { 1 - 0.2 * Double(level - 1) }

    /// How much darker than the card's surface the sheet of `level` is (lighter in dark mode).
    static func shade(_ level: Double) -> Double { 0.035 * level }

    /// The room the edges take under the top card, the same whether or not there are any, so the card never
    /// changes its size with the number of cards behind it. The edges' step is fixed: the parameter is the
    /// old one, which the screen still passes.
    static var reserve: CGFloat { step * CGFloat(maxEdges) }
}

/// A blank sheet of the stack: the card's shape, its surface a `shade` darker (lighter in dark mode), a hairline
/// round it and a soft shadow under it, `tint` over it.
struct StackSheet: View {
    var width: CGFloat
    var height: CGFloat
    var faintness: Double
    var shade: Double
    var tint: Color = .clear

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        shape
            .fill(Color.cardSurface)
            .overlay { shape.fill(Color.primary.opacity(shade)) }
            .overlay { shape.fill(tint) }
            .overlay { shape.strokeBorder(Color.cardEdge.opacity(faintness), lineWidth: 1) }
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
            .frame(width: width, height: height)
    }
}

/// The edges of the stack under the top card, still: `edges` sheets, at most `StackPose.maxEdges`, each lower and
/// narrower than the one above. The Mac draws its stack with it; the iPhone's `CardStack` moves sheets in and out
/// of it as well.
struct StackEdges: View {
    var edges: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach((1...StackPose.maxEdges).reversed(), id: \.self) { level in
                    if level <= edges {
                        StackSheet(
                            width: StackPose.width(level, cardWidth: proxy.size.width), height: proxy.size.height,
                            faintness: StackPose.faintness(level), shade: StackPose.shade(Double(level))
                        )
                        .offset(y: StackPose.drop(level))
                        .transition(.opacity)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .animation(.smooth(duration: 0.25), value: edges)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

extension Color {
    /// The hairline round a card's sheets.
    static var cardEdge: Color {
        #if os(iOS)
        Color(.opaqueSeparator)
        #else
        Color(nsColor: .separatorColor)
        #endif
    }
}
