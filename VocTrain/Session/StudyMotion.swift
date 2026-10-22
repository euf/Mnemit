import SwiftUI
import VocabCore

/// The places of the cards in the stack under the one on top, as poses of a card: a level is how
/// deep it lies, 0 the top card, 1 the card that rises next. A card of level `n` is a little
/// smaller than the one above and peeks out `peek` points further below it, so the cards under the
/// top one show as a few edges, and a card that rises takes the pose of level 1 before it does.
enum StackPose {
    /// The edges that show under the top card, however many cards wait.
    static let maxEdges = 3
    /// What each level loses of the scale of the one above.
    static let shrink: CGFloat = 0.04

    static func scale(_ level: Int) -> CGFloat { 1 - shrink * CGFloat(level) }

    /// How far the card of `level` lies below the place of the top card, so that its lower edge is
    /// `peek` points below that of the level above: a card scaled about its middle loses height at
    /// the bottom too, which the offset adds back.
    static func offset(_ level: Int, height: CGFloat, peek: CGFloat) -> CGFloat {
        peek * CGFloat(level) + (1 - scale(level)) * height / 2
    }

    /// The room the edges take under the top card, the same whether or not there are any, so the
    /// card never changes its size with the number of cards behind it.
    static func reserve(peek: CGFloat) -> CGFloat { peek * CGFloat(maxEdges) }
}

/// The way of a card from its place to a place where it is a small thing, and back: into the ring
/// in the bar, under the stack, or off the screen. Offsets are from the card's own place.
struct CardPath: Equatable {
    var end: CGSize
    /// The scale the card has at the end of its way.
    var endScale: CGFloat
    /// The card fades out as it arrives.
    var fades: Bool
}

/// How the card on top comes to its place.
enum CardArrival: Equatable {
    /// It was there when the screen came.
    case still
    /// It rises out of the stack: from the pose of the next card to the top, its words fading in.
    case rises
    /// Undo: it comes back along `path`, from where its grade sent it.
    case returns(CardPath)
}

/// A card that has been graded and leaves while the next one is already on top: the card as it was
/// let go, and where it goes.
struct Departure: Identifiable {
    let id = UUID()
    var card: Card
    var grade: Grade
    var label: String?
    var release: CardFlight.Release
    var destination: GradeReceipt.Destination
    /// The way it takes; `nil` for a card that fades out where it is (Reduce Motion).
    var path: CardPath?
    /// The finger's velocity as it let go, in points a second.
    var velocity: CGSize
    /// How long the card stays on screen, in seconds.
    var lifetime: Double
    /// The place of the cards when it was graded, in global coordinates.
    var slot: CGRect
}

/// What moves on the iPhone's study screen apart from the card under the finger: the cards that
/// have been graded and fly on, the ring that takes them, the stack the next card rises from, and the
/// ring that comes down to the rest and back up again. It holds the places the views report (the ring
/// in the bar, the card, the rest's ring) and the timeline of the rest, so a view only draws what it
/// is told.
///
/// Nothing here waits for the card on top: a grade is applied at once, the card that was graded
/// leaves as a card of its own (`Departure`), and the one under it is already on top and takes the
/// next touch while the first still flies.
@MainActor @Observable
final class StudyMotion {
    enum Timing {
        /// A graded card takes this long to its destination.
        static let flight = 0.45
        /// It is in the ring after this long, and the ring steps.
        static let landing = 0.42
        /// The ring takes this long between the bar and the rest.
        static let travel = 0.55
        /// The lines of the rest come in this far apart.
        static let line = 0.1
        /// Reduce Motion: the card fades out over this long, with its label on it.
        static let fade = 0.6
    }

    /// The instants of a picture: a test freezes what moves.
    struct Frozen {
        /// A card that leaves, how far along its way: 0 to 1.
        var departure: Double?
        /// The card that rises, how far: 0 to 1.
        var rise: Double?
        /// The ring between the bar (0) and the rest (1).
        var travel: Double?
        /// How many of the lines of the rest have come in.
        var lines: Int?
    }

    // MARK: The places the views report, in global coordinates

    /// The small ring in the bar.
    var ringHome = CGRect.zero
    /// The place of the card.
    @ObservationIgnored var cardSlot = CGRect.zero
    /// The place the rest wants its ring in.
    var ringRest = CGRect.zero

    // MARK: The cards that leave and the ring that takes them

    private(set) var departures: [Departure] = []
    /// How many cards have landed in the ring: the ring bumps with each.
    private(set) var landings = 0
    /// What the ring in the bar shows as done, ahead of the figures: a card that lands steps it at
    /// once, and the figures, which wait for the card that speaks, catch up. `nil` shows the figures.
    private(set) var shown: Double?
    private var inFlight = 0

    // MARK: The rest

    /// The rest is on screen, which it is from the card of the round's end leaving until the cards
    /// have been dealt again, a moment after the stream moved on.
    private(set) var showsRest = false
    /// The ring in the rest is drawn by `RingTraveler`: in the bar (0) and the rest (1).
    private(set) var travel = 0.0
    private(set) var travels = false
    /// The ring has come down: the lines come in.
    private(set) var hasArrived = true
    /// The place where the card was shows as an empty slot until the ring has come into it.
    private(set) var showsSlot = false
    private(set) var burstStartedAt: Date?
    /// What the rest said when the stream left it, for the moment it takes the ring to go back up.
    private(set) var restSnapshot: StreamRest?
    private var restTask: Task<Void, Never>?

    /// How the next card on top comes: set by whoever sends the next move.
    var arrival = CardArrival.still
    var frozen: Frozen?

    @ObservationIgnored private weak var ring: DailyRingModel?

    init(ring: DailyRingModel? = nil) {
        self.ring = ring
    }

    /// Whether a rest is on its way in or out, so a change of the stream is not a surprise.
    var isChoreographing: Bool { restTask != nil }

    // MARK: Grading

    /// Sends the card that has been graded on its way. Called as the grade is given, after it is applied.
    ///
    /// - Parameters:
    ///   - behind: How many cards waited behind it in the round, before the grade: a card that comes
    ///     back today goes under the last of them.
    ///   - velocity: The finger's velocity as it let go; the card goes on with it.
    func depart(
        _ card: Card, receipt: GradeReceipt, release: CardFlight.Release, velocity: CGSize, behind: Int, peek: CGFloat, reduceMotion: Bool
    ) {
        let slot = cardSlot
        let destination = receipt.destination
        if destination == .ring { inFlight += 1 }
        guard slot.width > 0 else {
            if destination == .ring { landed() }
            return
        }
        var release = release
        var path: CardPath?
        var lifetime = Timing.flight + 0.1
        if reduceMotion {
            release.offset = .zero
            release.rotation = .zero
            release.pivot = .center
            lifetime = Timing.fade
        } else {
            path = self.path(to: destination, grade: receipt.grade, behind: behind, peek: peek)
        }
        let departure = Departure(
            card: card, grade: receipt.grade, label: receipt.flightLabel, release: release, destination: destination, path: path,
            velocity: velocity, lifetime: lifetime, slot: slot)
        departures.append(departure)
        guard frozen == nil else { return }
        Task { [weak self] in
            if destination == .ring {
                try? await Task.sleep(for: .seconds(reduceMotion ? 0.05 : Timing.landing))
                self?.landed()
            }
            try? await Task.sleep(for: .seconds(max(0, lifetime - (destination == .ring ? Timing.landing : 0))))
            self?.departures.removeAll { $0.id == departure.id }
        }
    }

    /// The way of a card to where its grade sends it, from the place of the card: into the ring in the bar, to the pose under
    /// the last card of the stack, or off the screen.
    private func path(to destination: GradeReceipt.Destination, grade: Grade, behind: Int, peek: CGFloat) -> CardPath {
        let slot = cardSlot
        switch destination {
        case .ring:
            let to =
                ringHome.width > 0
                ? CGSize(width: ringHome.midX - slot.midX, height: ringHome.midY - slot.midY) : CGSize(width: 0, height: -slot.height / 2)
            return CardPath(end: to, endScale: 0.08, fades: true)
        case .stack:
            let level = min(behind, StackPose.maxEdges) + 1
            return CardPath(
                end: CGSize(width: 0, height: StackPose.offset(level, height: slot.height, peek: peek)), endScale: StackPose.scale(level), fades: true)
        case .away:
            return CardPath(end: GradeSwipe.exit(of: grade), endScale: 1, fades: false)
        }
    }

    /// How the card that Undo brings back arrives: the same way as it went, the other way round. Without
    /// travel (Reduce Motion), or after a grade that went nowhere, it is there.
    func returnArrival(from destination: GradeReceipt.Destination, behind: Int, peek: CGFloat, reduceMotion: Bool) -> CardArrival {
        guard !reduceMotion, destination != .away, cardSlot.width > 0 else { return .still }
        return .returns(path(to: destination, grade: .good, behind: behind, peek: peek))
    }

    /// A card is in the ring: it steps, and glows.
    private func landed() {
        inFlight = max(0, inFlight - 1)
        landings += 1
        guard let ring = ring?.progress?.ring else { return }
        let real = Double(ring.done) + ring.underway
        shown = max((shown ?? real) + 1, real)
    }

    /// The figures of the ring changed: the ring shows them, unless a card is still on its way to it.
    func figuresChanged() {
        guard inFlight == 0 else { return }
        shown = nil
    }

    /// Undo brings a card back out of the ring: the ring takes its step back.
    func retractStep() {
        guard let ring = ring?.progress?.ring else { return }
        let real = Double(ring.done) + ring.underway
        shown = max(0, (shown ?? real) - 1)
    }

    // MARK: The rest

    /// The stream is at rest from the start, or after something the view did not see coming.
    func snapRest(_ isResting: Bool) {
        restTask?.cancel()
        restTask = nil
        burstStartedAt = nil
        showsRest = isResting
        travels = isResting
        travel = isResting ? 1 : 0
        hasArrived = true
        showsSlot = false
        restSnapshot = nil
    }

    /// The last card of the round has left: its place stays as an empty slot, and the ring, once the card
    /// is in it, comes down into the slot. Without travel (Reduce Motion) the rest comes with a crossfade.
    func restBegan(afterLanding: Bool, reduceMotion: Bool) {
        restTask?.cancel()
        restSnapshot = nil
        burstStartedAt = nil
        showsRest = true
        guard !reduceMotion else {
            travels = false
            travel = 1
            hasArrived = true
            showsSlot = false
            restTask = nil
            return
        }
        travels = true
        travel = 0
        hasArrived = false
        showsSlot = true
        guard frozen == nil else { return }
        restTask = Task { [weak self] in
            if afterLanding { try? await Task.sleep(for: .seconds(Timing.landing)) }
            guard !Task.isCancelled, let self else { return }
            withAnimation(.spring(duration: Timing.travel, bounce: 0.1)) { travel = 1 }
            try? await Task.sleep(for: .seconds(Timing.travel * 0.85))
            guard !Task.isCancelled else { return }
            hasArrived = true
            showsSlot = false
            burstStartedAt = .now
            restTask = nil
        }
    }

    /// The stream leaves the rest: `apply` moves it on (the next round, going on, new cards, Undo), the
    /// ring goes back up to the bar, and `cardsAfter` seconds later the cards are dealt, the top one arriving
    /// as `arrival` says. `then` runs as they are. If the stream did not leave (`didLeave`), nothing changes.
    func leaveRest(
        snapshot: StreamRest, reduceMotion: Bool, cardsAfter: Double, arrival: CardArrival, apply: () -> Void, didLeave: () -> Bool,
        then: @escaping () -> Void
    ) {
        restTask?.cancel()
        restSnapshot = snapshot
        hasArrived = false
        burstStartedAt = nil
        apply()
        guard didLeave() else {
            restSnapshot = nil
            hasArrived = true
            restTask = nil
            return
        }
        guard !reduceMotion else {
            snapRest(false)
            self.arrival = arrival
            then()
            return
        }
        withAnimation(.spring(duration: Timing.travel, bounce: 0.05)) { travel = 0 }
        restTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(cardsAfter))
            guard !Task.isCancelled, let self else { return }
            self.arrival = arrival
            showsRest = false
            restSnapshot = nil
            then()
            try? await Task.sleep(for: .seconds(max(0, Timing.travel - cardsAfter)))
            guard !Task.isCancelled else { return }
            travels = false
            restTask = nil
        }
    }

    /// For a picture: the rest as it stands `travel` of the way down, with `lines` of its lines in.
    func freezeRest(travel: Double, lines: Int) {
        frozen = Frozen(travel: travel, lines: lines)
        showsRest = true
        travels = true
        self.travel = travel
        hasArrived = travel >= 1
        showsSlot = travel < 1
    }
}
