import SwiftUI
import VocabCore

/// How a flash card moves and looks while it is swiped, graded and replaced: it goes with the
/// finger but bent toward the target of the grade the swipe would give (`GradeSwipe.cardOffset`),
/// turns about the point where it was grabbed, tints with the colour of that grade, springs back
/// when let go too early or between two zones, and flies out when a grade is given, by swipe,
/// key or button. A view shows it with `FlightCard`.
@MainActor @Observable
final class CardFlight {
    /// How long a grade shows before the next card comes, in seconds: the card flies out,
    /// or with Reduce Motion the tint only flashes.
    static let duration = 0.25
    /// The tint never covers the card completely: at 70 % the card's text keeps 5.3:1 or more
    /// in light mode and 7.6:1 in dark mode on all four grades, so the text never has to change
    /// colour (`Grade.color` has the numbers).
    static let fullTint = 0.7
    /// The tint grows with the distance of the finger and reaches `fullTint` here.
    private static let tintDistance: CGFloat = 160
    /// The card turns at most this far, in degrees, and reaches it with a horizontal offset of
    /// `rotationDistance` points when it is grabbed at the top or bottom edge.
    static let maxRotation = 12.0
    private static let rotationDistance: CGFloat = 200
    /// A card grabbed at the middle still turns this share of what it does at the edge.
    private static let minimumLever = 0.35
    /// How the card eases when the finger crosses into another zone or a gap, where the card's
    /// way jumps (`GradeSwipe.cardOffset`): a short spring that keeps the card's speed, used for
    /// `glideDuration` after the crossing and not on the rest of the swipe, so the card stays
    /// under the finger.
    static let glide = Animation.interactiveSpring(response: 0.12, dampingFraction: 0.85)
    static let glideDuration = Duration.milliseconds(300)

    private(set) var offset = CGSize.zero
    private(set) var rotation = Angle.zero
    /// The point the card turns about, in unit coordinates of the card: where the finger
    /// grabbed it, so that point stays under the finger.
    private(set) var pivot = UnitPoint.center
    private(set) var opacity = 1.0
    /// The grade whose colour tints the card, and how strongly; the grade stays while the
    /// tint fades out.
    private(set) var tint: Grade?
    private(set) var tintStrength = 0.0
    /// The grade the direction of the finger stands for now, for a haptic when it changes;
    /// `nil` in the dead zone, in a gap between zones (`isInGap`) and before the answer shows.
    private(set) var zone: Grade?
    /// The finger points into a gap between two zones: no grade, no tint, the card half way.
    private(set) var isInGap = false
    /// The grade letting go now would give, for the commit threshold.
    private(set) var committing: Grade?
    /// A grade has been given: the card is on its way out, and takes no more input.
    private(set) var isFlying = false
    /// The size of the card, which `FlightCard` reports: the point where the card was grabbed
    /// is a share of it.
    var size = CGSize.zero

    /// Where the finger is, for easing the card when it changes: the dead zone, a gap or a zone.
    private enum Region: Equatable {
        case none
        case gap
        case zone(Grade)
    }

    private var region = Region.none
    private var glideUntil = ContinuousClock.now

    /// The grade whose button the row of buttons lights up: the one a swipe would give if
    /// let go now, or, while the card flies out, the one just given by swipe, key or button.
    var highlighted: Grade? { tintStrength > 0 ? tint : nil }

    /// How far a card turns for a horizontal offset `dx`, when it is grabbed `grabY` points
    /// from its top and is `height` high, like a card in a stack that is dragged by one of its
    /// halves: grabbed in the upper half it turns the way it moves, grabbed in the lower half
    /// the other way, because its middle trails behind the finger. Without a grab point, as the
    /// upper half. At most `maxRotation`.
    static func rotation(dx: CGFloat, grabY: CGFloat?, height: CGFloat) -> Angle {
        var lever = 1.0
        if let grabY, height > 0 {
            let above = Double(max(-1, min(1, (height / 2 - grabY) / (height / 2))))
            lever = (above < 0 ? -1 : 1) * (minimumLever + (1 - minimumLever) * abs(above))
        }
        let degrees = lever * Double(dx / rotationDistance) * maxRotation
        return .degrees(max(-maxRotation, min(maxRotation, degrees)))
    }

    /// The card goes with the finger, bent toward the target of the grade the finger's direction
    /// stands for (`GradeSwipe.cardOffset`), and turns about the point grabbed at `start`, in the
    /// card's own coordinates. In a gap between two zones it takes no grade and goes half way.
    /// Before the answer is shown it only gives way a little, without tint. When the finger
    /// crosses into another zone or a gap the card eases to its new way with `glide`.
    func drag(_ translation: CGSize, from start: CGPoint? = nil, isRevealed: Bool, glide: Animation = CardFlight.glide) {
        guard !isFlying else { return }
        let distance = hypot(translation.width, translation.height)
        let grade = isRevealed ? GradeSwipe.zone(translation) : nil
        let gap = isRevealed && GradeSwipe.isInGap(translation)
        let region: Region = grade.map { .zone($0) } ?? (gap ? .gap : .none)
        if region != self.region {
            self.region = region
            glideUntil = .now + Self.glideDuration
        }
        let moved = isRevealed ? GradeSwipe.cardOffset(for: translation) : CGSize(width: translation.width * 0.25, height: translation.height * 0.25)
        if let start, size.width > 0, size.height > 0 {
            pivot = UnitPoint(x: start.x / size.width, y: start.y / size.height)
        }
        zone = grade
        isInGap = gap
        if let grade { tint = grade }
        committing = grade.flatMap { distance >= GradeSwipe.commitDistance ? $0 : nil }
        let strength = grade == nil ? 0 : min(Self.fullTint, Double(distance / Self.tintDistance))
        let follow = {
            self.offset = moved
            self.rotation = Self.rotation(dx: moved.width, grabY: start?.y, height: self.size.height)
            self.tintStrength = strength
        }
        if ContinuousClock.now < glideUntil {
            withAnimation(glide, follow)
        } else {
            follow()
        }
    }

    /// Whether a change of `zone` is felt as a light tick: entering a zone, or a gap from a zone.
    func isTick(from old: Grade?, to new: Grade?) -> Bool {
        new != nil || (old != nil && isInGap)
    }

    /// Springs back, with a little bounce, and fades the tint out with it.
    func springBack() {
        guard !isFlying else { return }
        committing = nil
        zone = nil
        isInGap = false
        region = .none
        withAnimation(.spring(response: 0.4, dampingFraction: 0.62)) {
            offset = .zero
            rotation = .zero
            tintStrength = 0
        }
    }

    /// Gives `grade`: tints the card in its colour and flies it out in its direction, from
    /// where it is, then runs `finish`, which shows the next card, and puts the card back
    /// in place. With Reduce Motion the card stays and the tint flashes.
    func fly(_ grade: Grade, reduceMotion: Bool, then finish: @escaping @MainActor () -> Void) {
        guard !isFlying else { return }
        isFlying = true
        committing = nil
        zone = nil
        isInGap = false
        region = .none
        tint = grade
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.1)) {
                offset = .zero
                rotation = .zero
                tintStrength = Self.fullTint
            }
        } else {
            let exit = GradeSwipe.exit(of: grade)
            // Turns on the way the swipe began; a card sent by key or button turns the way it goes.
            let direction = rotation.degrees != 0 ? (rotation.degrees > 0 ? 1.0 : -1.0) : (exit.width >= 0 ? 1.0 : -1.0)
            withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.8)) {
                offset = exit
                rotation = .degrees(direction * Self.maxRotation)
                tintStrength = Self.fullTint
                #if os(macOS)
                // The window is wider than a phone: the card is gone before it reaches the edge.
                opacity = 0
                #endif
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.2 : Self.duration))
            finish()
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                offset = .zero
                rotation = .zero
                pivot = .center
                opacity = 1
                tint = nil
                tintStrength = 0
                isFlying = false
            }
        }
    }
}

extension Color {
    /// Secondary text on a flash card: 75 % of the primary colour, so it keeps 4.2:1 or more
    /// on a card at its full tint (the system's secondary label would drop to 1.8:1 on a red
    /// card in light mode) and never changes colour during a swipe.
    static var cardSecondary: Color { Color.primary.opacity(0.75) }
}

/// A flash card's face: the content on a rounded card that moves, turns and tints as
/// `flight` says.
///
/// The card is one layer while it moves. The surface, the tint under the text and the text
/// are composed in one group, and the group is moved and turned as a whole, so nothing in it
/// can lag behind the card. The text is drawn once into a bitmap of its own (iPhone), which
/// is moved with the card instead of being drawn again at every step, where each step
/// would round the glyphs to pixels differently from the card's edge. Nothing in the content
/// changes with the swipe: no colour, no size, no view appearing.
struct FlightCard<Content: View>: View {
    var flight: CardFlight
    var content: Content

    private let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    init(flight: CardFlight, @ViewBuilder content: () -> Content) {
        self.flight = flight
        self.content = content()
    }

    var body: some View {
        ZStack {
            shape.fill(Color.cardSurface)
            shape
                .fill((flight.tint ?? .good).color)
                .opacity(max(0, flight.tintStrength))
                .animation(.easeOut(duration: 0.12), value: flight.tint)
            text
            shape.strokeBorder(Color.primary.opacity(0.12))
        }
        .compositingGroup()
        .geometryGroup()
        .onGeometryChange(for: CGSize.self, of: \.size) { flight.size = $0 }
        .rotationEffect(flight.rotation, anchor: flight.pivot)
        .offset(flight.offset)
        .opacity(flight.opacity)
        .allowsHitTesting(!flight.isFlying)
    }

    @ViewBuilder
    private var text: some View {
        #if os(iOS)
        content.drawingGroup()
        #else
        content
        #endif
    }
}

#if os(iOS)
extension View {
    /// The haptics of a swipe: a light tick whenever the finger enters another grade's zone or a
    /// gap from one, and a medium one when the card is graded, whether by swipe or by button.
    func swipeHaptics(_ flight: CardFlight) -> some View {
        sensoryFeedback(.impact(weight: .light), trigger: flight.zone) { old, new in flight.isTick(from: old, to: new) }
            .sensoryFeedback(.impact(weight: .medium), trigger: flight.isFlying) { _, isFlying in isFlying }
    }
}
#endif
