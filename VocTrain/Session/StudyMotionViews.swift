import SwiftUI
import VocabCore

// The views of what moves on the study screen besides the card under the finger; the timeline and
// the places are in `StudyMotion`.

/// The curves of a card's way. Each axis has its own, which is what bends the way into an arc, and the
/// grade's flight has the finger's speed in it: a spring that starts with the release velocity, so the
/// card does not stop where it is let go and start again.
struct PathCurves {
    var x: Animation
    var y: Animation
    /// Scale and turn.
    var q: Animation
    /// The fade.
    var o: Animation

    /// A card that leaves. `velocity` is the finger's, in points a second; `shift` how far the card has to go.
    /// A grade by button or key has none, and eases in.
    static func forward(velocity: CGSize, shift: CGSize, duration: Double) -> PathCurves {
        func axis(_ speed: CGFloat, _ distance: CGFloat, fallback: Animation) -> Animation {
            guard hypot(velocity.width, velocity.height) > 200, abs(distance) > 24 else { return fallback }
            // The spring's velocity is in whole ways a second.
            return .interpolatingSpring(duration: duration, bounce: 0, initialVelocity: max(-6, min(8, Double(speed / distance))))
        }
        return PathCurves(
            x: axis(velocity.width, shift.width, fallback: .easeInOut(duration: duration)),
            y: axis(velocity.height, shift.height, fallback: .easeIn(duration: duration)),
            q: .easeIn(duration: duration),
            o: .easeIn(duration: 0.2).delay(duration - 0.22))
    }

    /// The same way the other way round, as Undo brings a card back: each axis is the mirror of the one above.
    static func backward(duration: Double) -> PathCurves {
        PathCurves(x: .easeIn(duration: duration), y: .easeOut(duration: duration), q: .easeOut(duration: duration), o: .easeOut(duration: 0.2))
    }
}

/// A card on its way along `path`, as four numbers from 0 (where it began) to 1 (where it ends): how far
/// across, how far down, how much smaller and turned, how faded. Each goes by its own curve, and
/// each is a straight function of its number, so any instant of the way can be drawn from the numbers alone.
private struct PathMotion: ViewModifier {
    var path: CardPath
    /// How far the way carries the card from where it began: the end of the path less the offset it was let go at.
    var shift: CGSize
    var turn: Angle
    var pivot: UnitPoint
    var x: Double
    var y: Double
    var q: Double
    var o: Double
    var curves: PathCurves

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(turn.degrees * q), anchor: pivot)
            .scaleEffect(1 + (path.endScale - 1) * q)
            .animation(curves.q, value: q)
            .opacity(path.fades ? 1 - o : 1)
            .animation(curves.o, value: o)
            .offset(x: shift.width * x)
            .animation(curves.x, value: x)
            .offset(y: shift.height * y)
            .animation(curves.y, value: y)
    }
}

/// A card that has been graded, going on as a card of its own from the pose it was let go in, with the finger's
/// speed, until it is off the screen. It takes no touch; the card that was under it is on top already. Nothing
/// is written on it: a label on a card that is leaving is never read. With Reduce Motion it stays where it is
/// and fades.
struct DepartingCard: View {
    var departure: Departure
    /// A picture's instant: how far along its way the card is.
    var frozen: Double?

    @State private var flight: CardFlight
    @State private var x: Double
    @State private var y: Double
    @State private var q: Double
    @State private var o: Double

    init(departure: Departure, frozen: Double? = nil) {
        self.departure = departure
        self.frozen = frozen
        _flight = State(initialValue: CardFlight(release: departure.release))
        let progress = frozen ?? 0
        _x = State(initialValue: progress)
        _y = State(initialValue: progress)
        _q = State(initialValue: progress)
        _o = State(initialValue: max(0, (progress - 0.7) / 0.3))
    }

    var body: some View {
        Group {
            if let path = departure.path {
                flies(along: path)
            } else {
                fades
            }
        }
        .environment(\.speakerPlaces, nil)
        .disabled(true)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear(perform: begin)
    }

    private func flies(along path: CardPath) -> some View {
        let shift = CGSize(width: path.end.width - departure.release.offset.width, height: path.end.height - departure.release.offset.height)
        return FlightCard(flight: flight) {
            CardFace(card: departure.card, isRevealed: true)
        }
        .modifier(
            PathMotion(
                path: path, shift: shift, turn: turn, pivot: departure.release.pivot, x: x, y: y, q: q, o: o,
                curves: .forward(velocity: departure.velocity, shift: shift, duration: StudyMotion.Timing.flight)))
    }

    /// Where the card has turned to by the end: it keeps turning the way it went.
    private var turn: Angle {
        let rotation = departure.release.rotation.degrees
        let direction = rotation != 0 ? (rotation > 0 ? 1.0 : -1.0) : (departure.path.map { $0.end.width >= 0 ? 1.0 : -1.0 } ?? 1)
        return .degrees(direction * CardFlight.maxRotation - rotation)
    }

    private var fades: some View {
        FlightCard(flight: flight) {
            CardFace(card: departure.card, isRevealed: true)
        }
        .opacity(1 - o)
        .animation(.easeOut(duration: StudyMotion.Timing.fade), value: o)
    }

    private func begin() {
        guard frozen == nil else { return }
        flight.tintFully(departure.grade)
        x = 1
        y = 1
        q = 1
        o = 1
    }
}

/// The card on top of the stack and how it came there. It rises out of the stack where it was the next
/// card: from the pose of level 1, a little narrower and lower, to its place, its words fading in over
/// 0.15 s. Undo's card comes back along the way it went (`CardArrival.returns`), in from the edge it left by.
/// The card is the same view as ever (`FlightCard`), so the finger moves it at once.
struct TopCard<Face: View>: View {
    var flight: CardFlight
    var arrival: CardArrival
    /// A picture's instant: how far the rising card has come, 0 to 1.
    var frozenRise: Double?
    var face: Face

    @State private var rise: Double
    @State private var words: Double
    @State private var x: Double
    @State private var y: Double
    @State private var q: Double
    @State private var o: Double

    init(flight: CardFlight, arrival: CardArrival, frozenRise: Double? = nil, @ViewBuilder face: () -> Face) {
        self.flight = flight
        self.arrival = arrival
        self.frozenRise = frozenRise
        self.face = face()
        let rises = arrival == .rises
        let back = if case .returns = arrival { 1.0 } else { 0.0 }
        _rise = State(initialValue: frozenRise ?? (rises ? 0 : 1))
        _words = State(initialValue: frozenRise.map { min(1, $0 * 2) } ?? (rises ? 0 : 1))
        _x = State(initialValue: back)
        _y = State(initialValue: back)
        _q = State(initialValue: back)
        _o = State(initialValue: back)
    }

    private static var rising: Animation { .spring(duration: 0.3, bounce: 0.15) }

    var body: some View {
        FlightCard(flight: flight) {
            face
                .opacity(words)
                .animation(.easeOut(duration: 0.15), value: words)
        }
        .modifier(returning)
        .scaleEffect(x: narrow + (1 - narrow) * rise, y: 1)
        .animation(Self.rising, value: rise)
        .offset(y: StackPose.drop(1) * (1 - rise))
        .animation(Self.rising, value: rise)
        .onAppear(perform: begin)
    }

    /// How wide the card is in the pose of level 1, as a share of its width.
    private var narrow: CGFloat {
        let width = flight.size.width
        return width > 0 ? StackPose.width(1, cardWidth: width) / width : 1
    }

    /// The way back, from `path` to the place of the card; a card that did not come back by Undo has none.
    private var returning: PathMotion {
        guard case let .returns(path) = arrival else {
            return PathMotion(
                path: CardPath(end: .zero, endScale: 1, fades: false), shift: .zero, turn: .zero, pivot: .center, x: 0, y: 0, q: 0, o: 0,
                curves: .backward(duration: StudyMotion.Timing.flight))
        }
        return PathMotion(
            path: path, shift: path.end, turn: .zero, pivot: .center, x: x, y: y, q: q, o: o, curves: .backward(duration: StudyMotion.Timing.flight))
    }

    private func begin() {
        guard frozenRise == nil else { return }
        rise = 1
        words = 1
        x = 0
        y = 0
        q = 0
        o = 0
    }
}

/// The cards under the top one, as the edges of a book's pages: up to `StackPose.maxEdges` hairline outlines
/// under the card's bottom edge, each a little lower and narrower than the one above, fainter with depth.
/// They are behind the card and show only below it. A card that went back today comes in as a blank sheet by
/// the edge it left by, slides under the stack, and becomes the deepest edge. When the stack is dealt, as a
/// round begins, the edges spread out from under the top card one after the other.
struct CardStack: View {
    /// The edges to show, at most `StackPose.maxEdges`; 0 is no stack.
    var edges: Int
    var sheets: [Sheet] = []
    /// A picture's instant: how far the sheets have slid, 0 to 1.
    var frozenSheet: Double?
    @State private var isSpread: Bool

    init(edges: Int, sheets: [Sheet] = [], frozenSheet: Double? = nil, dealt: Bool = true) {
        self.edges = edges
        self.sheets = sheets
        self.frozenSheet = frozenSheet
        _isSpread = State(initialValue: !dealt)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(sheets) { sheet in
                    SheetOnItsWay(sheet: sheet, size: proxy.size, frozen: frozenSheet)
                        .transition(.opacity)
                }
                ForEach((1...StackPose.maxEdges).reversed(), id: \.self) { level in
                    if level <= edges {
                        page(level, size: proxy.size, spread: isSpread)
                            .transition(.opacity)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .animation(.smooth(duration: 0.25), value: edges)
            .animation(.smooth(duration: 0.25), value: sheets.map(\.id))
        }
        .onAppear { isSpread = true }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    /// The edge of `level`: a blank page the width and place its level gives it.
    private func page(_ level: Int, size: CGSize, spread: Bool) -> some View {
        Self.page(
            width: spread ? StackPose.width(level, cardWidth: size.width) : size.width, height: size.height, faintness: StackPose.faintness(level),
            shade: StackPose.shade(Double(level))
        )
        .offset(y: spread ? StackPose.drop(level) : 0)
        .animation(.spring(duration: 0.4, bounce: 0.2).delay(0.05 * Double(level)), value: spread)
    }

    /// A blank sheet of the stack, `StackSheet`.
    static func page(width: CGFloat, height: CGFloat, faintness: Double, shade: Double, tint: Color = .clear) -> some View {
        StackSheet(width: width, height: height, faintness: faintness, shade: shade, tint: tint)
    }
}

/// A sheet on its way from the edge of the screen to its place under the stack: from the size of the card,
/// where the card left, to the width and depth of the edge it becomes.
private struct SheetOnItsWay: View {
    var sheet: Sheet
    var size: CGSize
    var frozen: Double?
    @State private var along: Double

    init(sheet: Sheet, size: CGSize, frozen: Double?) {
        self.sheet = sheet
        self.size = size
        self.frozen = frozen
        _along = State(initialValue: frozen ?? 0)
    }

    var body: some View {
        CardStack.page(
            width: size.width + (StackPose.width(sheet.level, cardWidth: size.width) - size.width) * along, height: size.height,
            faintness: 1 - (1 - StackPose.faintness(sheet.level)) * along, shade: StackPose.shade(Double(sheet.level) * along),
            tint: sheet.grade.tint.opacity(0.45 * (1 - along))
        )
        .offset(x: sheet.from.width * (1 - along), y: sheet.from.height * (1 - along) + StackPose.drop(sheet.level) * along)
        .animation(.spring(duration: StudyMotion.Timing.sheet, bounce: 0.1), value: along)
        .onAppear { if frozen == nil { along = 1 } }
    }
}

/// The place of a card that has left and not been replaced, as the last card of a round leaves: a faint
/// rounded outline, where the ring comes down into.
struct SlotOutline: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1.5)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

/// The ring steps: it swells to 1.35 and back with a little overshoot, and glows in the accent for 0.45 s. A step is a card
/// landing in it; with Reduce Motion the ring only steps.
private struct RingBump: ViewModifier {
    var landings: Int
    var swell: Double
    var glow: Double

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: landings) { content, level in
            content
                .scaleEffect(1 + swell * level)
                .shadow(color: Color("AccentColor").opacity(glow * min(1, level)), radius: 14 * min(1, level))
        } keyframes: { _ in
            CubicKeyframe(1, duration: 0.14)
            SpringKeyframe(0, duration: 0.31, spring: .bouncy(duration: 0.31, extraBounce: 0.15))
        }
    }
}

extension View {
    func ringBump(_ landings: Int, reduceMotion: Bool) -> some View {
        modifier(RingBump(landings: landings, swell: reduceMotion ? 0 : 0.35, glow: reduceMotion ? 0 : 0.9))
    }
}

/// The ring that comes down from the bar to the rest and back, drawn above the screen: one ring in one
/// continuous motion, from the small one the cards went into to the big one of the rest, which the
/// rest's own layout only leaves the place for. It is drawn at the size of the rest's ring and
/// scaled down in the bar, so it is drawn once and moved as a picture.
struct RingTraveler: View {
    var motion: StudyMotion
    var progress: DailyProgress?
    var reduceMotion: Bool

    /// The size the ring is drawn at: the rest's.
    static let diameter: CGFloat = 96

    var body: some View {
        GeometryReader { proxy in
            let home = motion.ringHome
            let rest = motion.ringRest
            let travel = motion.frozen?.travel ?? motion.travel
            if motion.travels, home.width > 0, rest.width > 0 {
                let origin = proxy.frame(in: .global).origin
                let width = home.width + (rest.width - home.width) * travel
                RingBurst(startedAt: reduceMotion ? nil : motion.burstStartedAt, diameter: Self.diameter) {
                    DailyRingView(progress: progress, diameter: Self.diameter, shown: motion.shown)
                }
                .ringBump(motion.landings, reduceMotion: reduceMotion)
                .scaleEffect(width / Self.diameter)
                .position(x: home.midX + (rest.midX - home.midX) * travel - origin.x, y: home.midY + (rest.midY - home.midY) * travel - origin.y)
                .allowsHitTesting(motion.hasArrived)
            }
        }
    }
}
