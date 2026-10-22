import SwiftUI
import VocabCore

/// The edges of the stack under the card on top, drawn as the edges of a book's pages: hairline outlines with
/// the card's corner radius under its bottom edge, each `step` lower and `side` narrower on each side than the
/// one above, and fainter with depth. A level is how deep an edge lies: 0 the top card, 1 the card that rises
/// next, which takes the pose of level 1 before it does.
enum StackPose {
    /// The edges that show under the top card, however many cards wait.
    static let maxEdges = 5
    /// How much lower each edge lies than the one above.
    static let step: CGFloat = 3
    /// How much narrower, on each side.
    static let side: CGFloat = 2

    /// How far the edge of `level` lies below the place of the top card.
    static func drop(_ level: Int) -> CGFloat { step * CGFloat(level) }

    static func width(_ level: Int, cardWidth: CGFloat) -> CGFloat { max(0, cardWidth - 2 * side * CGFloat(level)) }

    /// How much of the outline's colour an edge keeps: all of the first, less with depth.
    static func faintness(_ level: Int) -> Double { 1 - 0.15 * Double(level - 1) }

    /// The room the edges take under the top card, the same whether or not there are any, so the card never
    /// changes its size with the number of cards behind it. The edges' step is fixed: the parameter is the
    /// old one, which the screen still passes.
    static var reserve: CGFloat { step * CGFloat(maxEdges) }
}

/// The way of a card between its place and the edge of the screen, past which it leaves and from which Undo
/// brings it back. Offsets are from the card's own place.
struct CardPath: Equatable {
    var end: CGSize
    /// The scale the card has at the end of its way.
    var endScale: CGFloat
    /// The card fades out as it arrives.
    var fades: Bool

    /// Off the screen, along the direction of the grade.
    static func exit(of grade: Grade) -> CardPath {
        CardPath(end: GradeSwipe.exit(of: grade), endScale: 1, fades: false)
    }
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

/// A card that went back today, once it is past the edge: a blank sheet that comes in by the edge it left by
/// and slides under the stack to the deepest edge, where it becomes that edge.
struct Sheet: Identifiable {
    let id = UUID()
    /// Where it comes in from, from the card's own place.
    var from: CGSize
    /// The depth of the edge it becomes.
    var level: Int
}

/// What moves on the iPhone's study screen apart from the card under the finger: the cards that
/// have been graded and leave past the edge, the ring in the bar that steps with them, the stack the next
/// card rises from, and the ring that comes down to the rest and back up again. It holds the places the
/// views report (the ring in the bar, the card, the rest's ring) and the timeline of the rest, so a view only
/// draws what it is told.
///
/// Nothing here waits for the card on top: a grade is applied at once, the card that was graded
/// leaves as a card of its own (`Departure`), and the one under it is already on top and takes the
/// next touch while the first still leaves.
@MainActor @Observable
final class StudyMotion {
    enum Timing {
        /// A graded card takes this long to be off the screen.
        static let flight = 0.45
        /// The ring comes down to the rest this long after the last card has set off: as it goes past the edge.
        static let exit = 0.25
        /// A card that went back today slides under the stack for this long.
        static let sheet = 0.4
        /// What a done card's interval says beside the ring stays this long.
        static let interval = 1.5
        /// The ring takes this long between the bar and the rest.
        static let travel = 0.55
        /// The lines of the rest come in this far apart.
        static let line = 0.1
        /// Reduce Motion: the card fades out over this long.
        static let fade = 0.6
    }

    /// The instants of a picture: a test freezes what moves.
    struct Frozen {
        /// A card that leaves, how far along its way: 0 to 1.
        var departure: Double?
        /// The card that rises, how far: 0 to 1.
        var rise: Double?
        /// The sheet that slides under the stack, how far: 0 to 1.
        var sheet: Double?
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

    // MARK: The cards that leave and the ring that takes their step

    private(set) var departures: [Departure] = []
    /// How many done cards have stepped the ring: the ring bumps with each.
    private(set) var landings = 0
    /// What the ring in the bar shows as done, ahead of the figures: a grade steps it at once by its gain,
    /// and the figures, which wait for the card that speaks, catch up. `nil` shows the figures.
    private(set) var shown: Double?
    /// The figures changed while a card was still leaving, so they are shown once it is gone.
    private var figuresWait = false
    /// When the last done card stepped the ring: the burst around the ring in the bar.
    private(set) var barBurstAt: Date?
    /// What the text beside the ring in the bar says for a moment in place of the figures: the interval a done
    /// card was given.
    private(set) var interval: String?
    private var intervalTask: Task<Void, Never>?

    // MARK: The stack

    /// The sheets on their way under the stack.
    private(set) var sheets: [Sheet] = []
    /// The cards that went back today and are not under the stack yet: its edges lack them until they are.
    private(set) var sheetsAway = 0
    /// Undo is bringing a card back out from under the stack: its deepest edge fades while it comes.
    private var edgeFades = false

    /// How many edges the stack shows, for `cardsBehind` cards waiting.
    func edges(cardsBehind: Int) -> Int {
        max(0, min(cardsBehind - sheetsAway - (edgeFades ? 1 : 0), StackPose.maxEdges))
    }

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

    /// Sends the card that has been graded past the edge, and steps the ring by what the grade added to it. Called
    /// as the grade is given, after it is applied.
    ///
    /// - Parameters:
    ///   - behind: How many cards waited behind it in the round, before the grade: a card that comes
    ///     back today is the deepest of them again.
    ///   - velocity: The finger's velocity as it let go; the card goes on with it.
    func depart(
        _ card: Card, receipt: GradeReceipt, release: CardFlight.Release, velocity: CGSize, behind: Int, reduceMotion: Bool
    ) {
        let destination = receipt.destination
        step(by: receipt.gain)
        if destination == .ring {
            landings += 1
            if !reduceMotion { barBurstAt = .now }
            showInterval(receipt.flightLabel)
        }
        let slot = cardSlot
        guard slot.width > 0 else { return }
        var release = release
        var path: CardPath?
        var lifetime = Timing.flight + 0.1
        if reduceMotion {
            release.offset = .zero
            release.rotation = .zero
            release.pivot = .center
            lifetime = Timing.fade
        } else {
            path = .exit(of: receipt.grade)
        }
        let departure = Departure(
            card: card, grade: receipt.grade, release: release, destination: destination, path: path, velocity: velocity, lifetime: lifetime,
            slot: slot)
        departures.append(departure)
        // A card that went back today comes in again by the edge it left by, once it is past it.
        let sheet = destination == .stack && !reduceMotion ? path.map { Sheet(from: $0.end, level: max(1, min(behind, StackPose.maxEdges))) } : nil
        if let sheet {
            sheetsAway += 1
            if frozen?.sheet != nil { sheets.append(sheet) }
        }
        guard frozen == nil else { return }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(lifetime))
            guard let self else { return }
            departures.removeAll { $0.id == departure.id }
            if departures.isEmpty, figuresWait { figuresChanged() }
        }
        if let sheet {
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(Timing.flight))
                self?.sheets.append(sheet)
                try? await Task.sleep(for: .seconds(Timing.sheet))
                // The edge it becomes comes in as it goes.
                withAnimation(.smooth(duration: 0.25)) {
                    self?.sheets.removeAll { $0.id == sheet.id }
                    self?.sheetsAway -= 1
                }
            }
        }
    }

    /// The ring in the bar takes `gain` of a card, at once.
    private func step(by gain: Double) {
        guard gain > 0, let ring = ring?.progress?.ring else { return }
        shown = (shown ?? Double(ring.done) + ring.underway) + gain
    }

    /// What the bar says beside the ring in place of its figures, for `Timing.interval`.
    private func showInterval(_ text: String?) {
        intervalTask?.cancel()
        interval = text
        guard text != nil, frozen == nil else { return }
        intervalTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Timing.interval))
            guard !Task.isCancelled else { return }
            self?.interval = nil
        }
    }

    /// How the card that Undo brings back arrives: the way it went, the other way round, in from the edge. Without
    /// travel (Reduce Motion), or after a step that gave no grade, it is there.
    func returnArrival(_ receipt: GradeReceipt?, reduceMotion: Bool) -> CardArrival {
        guard !reduceMotion, let receipt, cardSlot.width > 0 else { return .still }
        return .returns(.exit(of: receipt.grade))
    }

    /// Undo has taken a grade back: the ring gives its step back, the interval it showed is void, and a card that comes
    /// out from under the stack takes its deepest edge with it for the time it needs.
    func undone(_ receipt: GradeReceipt?, reduceMotion: Bool) {
        intervalTask?.cancel()
        interval = nil
        if let receipt, receipt.gain > 0, let ring = ring?.progress?.ring {
            shown = max(0, (shown ?? Double(ring.done) + ring.underway) - receipt.gain)
        }
        guard receipt?.destination == .stack, !reduceMotion, frozen == nil else { return }
        withAnimation(.smooth(duration: 0.25)) { edgeFades = true }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Timing.flight))
            withAnimation(.smooth(duration: 0.25)) { self?.edgeFades = false }
        }
    }

    /// The figures of the ring changed: the ring shows them, unless a card is still leaving.
    func figuresChanged() {
        guard departures.isEmpty else {
            figuresWait = true
            return
        }
        figuresWait = false
        shown = nil
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

    /// The last card of the round has left: its place stays as an empty slot, and the ring, as the card goes
    /// past the edge, comes down into the slot. Without travel (Reduce Motion) the rest comes with a crossfade.
    func restBegan(afterExit: Bool, reduceMotion: Bool) {
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
            if afterExit { try? await Task.sleep(for: .seconds(Timing.exit)) }
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
