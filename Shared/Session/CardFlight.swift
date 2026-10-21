import SwiftUI
import VocabCore

/// How a flash card moves and looks while it is swiped, graded and replaced: it follows
/// the finger, tints with the colour of the grade the swipe would give, springs back when
/// let go too early, and flies out when a grade is given, by swipe, key or button. A view
/// shows it with `FlightCard`.
@MainActor @Observable
final class CardFlight {
    /// How long a grade shows before the next card comes, in seconds: the card flies out,
    /// or with Reduce Motion the tint only flashes.
    static let duration = 0.25
    /// The tint never covers the card completely.
    static let fullTint = 0.85
    /// The tint grows with the distance of the finger and reaches `fullTint` here.
    private static let tintDistance: CGFloat = 160
    /// From this tint on the text takes the colour made for the grade's fill.
    private static let textSwitch = 0.65

    private(set) var offset = CGSize.zero
    private(set) var rotation = Angle.zero
    private(set) var opacity = 1.0
    /// The grade whose colour tints the card, and how strongly; the grade stays while the
    /// tint fades out.
    private(set) var tint: Grade?
    private(set) var tintStrength = 0.0
    /// The grade letting go now would give, for a haptic when it changes.
    private(set) var committing: Grade?
    /// A grade has been given: the card is on its way out, and takes no more input.
    private(set) var isFlying = false

    /// The colour of text on the tinted card once the tint is strong enough to need it.
    var textColor: Color? {
        guard let tint, tintStrength >= Self.textSwitch else { return nil }
        return tint.onColor
    }

    /// The card follows the finger one to one, turning a little with its horizontal
    /// offset. Before the answer is shown it only gives way a little, without tint.
    func drag(_ translation: CGSize, isRevealed: Bool) {
        guard !isFlying else { return }
        let share: CGFloat = isRevealed ? 1 : 0.25
        offset = CGSize(width: translation.width * share, height: translation.height * share)
        rotation = .degrees(Double(offset.width) / 22)
        let distance = hypot(translation.width, translation.height)
        guard isRevealed, let zone = GradeSwipe.zone(translation) else {
            tintStrength = 0
            committing = nil
            return
        }
        tint = zone
        tintStrength = min(Self.fullTint, Double(distance / Self.tintDistance))
        committing = distance >= GradeSwipe.commitDistance ? zone : nil
    }

    /// Springs back, with a little bounce, and fades the tint out with it.
    func springBack() {
        guard !isFlying else { return }
        committing = nil
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
        tint = grade
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.1)) {
                offset = .zero
                rotation = .zero
                tintStrength = Self.fullTint
            }
        } else {
            let exit = GradeSwipe.exit(of: grade)
            withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.8)) {
                offset = exit
                rotation = .degrees(Double(exit.width) / 28)
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
                opacity = 1
                tint = nil
                tintStrength = 0
                isFlying = false
            }
        }
    }
}

/// A flash card's face: the content on a rounded card that moves, turns and tints as
/// `flight` says.
struct FlightCard<Content: View>: View {
    var flight: CardFlight
    var content: Content

    private let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    init(flight: CardFlight, @ViewBuilder content: () -> Content) {
        self.flight = flight
        self.content = content()
    }

    var body: some View {
        content
            .foregroundStyle(flight.textColor ?? Color.primary)
            .animation(.easeOut(duration: 0.1), value: flight.textColor != nil)
            .background {
                ZStack {
                    shape.fill(Color.cardSurface)
                    shape
                        .fill((flight.tint ?? .good).color)
                        .opacity(max(0, flight.tintStrength))
                        .animation(.easeOut(duration: 0.12), value: flight.tint)
                }
            }
            .overlay { shape.strokeBorder(Color.primary.opacity(0.12)) }
            .offset(flight.offset)
            .rotationEffect(flight.rotation)
            .opacity(flight.opacity)
            .allowsHitTesting(!flight.isFlying)
    }
}
