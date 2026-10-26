import Foundation

/// Decides in which order the cards of a session are asked.
///
/// Cards flow through three stages:
/// 1. `backlog`: all remaining cards, most urgent first.
/// 2. `staging`: the next block of up to `stagingSize` backlog cards, in random order.
/// 3. `rotation`: up to `rotationSize` cards that are asked in turn.
///
/// The next card is picked at random from the front of the rotation and then moved
/// to its end. A card graded `.again` therefore comes back after a few others, and
/// the same card is never asked twice in a row while others are left.
/// (Same idea as the IndexCardRevisionPool of MacVocTrain 1.)
///
/// A card the learner has been introduced to (`hold(_:for:)`) leaves the rotation for a few
/// questions and is asked again after that many others, or next if no other card is left.
struct SessionQueue: Sendable {
    static let stagingSize = 25
    static let rotationSize = 10
    /// How many other cards are asked between a card's introduction and its first question.
    static let introductionGap = 3

    /// A card waiting for its first question after an introduction.
    struct Held: Sendable {
        var id: Card.ID
        /// How many other cards are still asked before it.
        var left: Int
    }

    private(set) var backlog: [Card.ID]
    private(set) var staging: [Card.ID] = []
    private(set) var rotation: [Card.ID] = []
    /// Cards that were introduced and wait for their first question, in order of introduction.
    private(set) var held: [Held] = []
    /// Cards that have been asked at least once.
    private(set) var seen: Set<Card.ID> = []

    init(cardIDs: [Card.ID]) {
        backlog = cardIDs
    }

    var count: Int { backlog.count + staging.count + rotation.count + held.count }
    var isEmpty: Bool { count == 0 }

    /// Cards asked at least once that are still in the queue.
    var startedCount: Int { rotation.filter(seen.contains).count + held.count }

    func contains(_ id: Card.ID) -> Bool {
        rotation.contains(id) || staging.contains(id) || backlog.contains(id) || held.contains { $0.id == id }
    }

    /// Takes the card, which was just asked, out of the rotation until `others` more cards have been
    /// asked; it is the next one once they have, or at once if nothing else is left.
    mutating func hold(_ id: Card.ID, for others: Int = introductionGap) {
        guard rotation.contains(id) else { return }
        rotation.removeAll { $0 == id }
        held.append(Held(id: id, left: others))
    }

    mutating func next<R: RandomNumberGenerator>(using random: inout R) -> Card.ID? {
        if let due = held.firstIndex(where: { $0.left <= 0 }) { return ask(held.remove(at: due).id) }
        fillRotation(using: &random)
        guard !rotation.isEmpty else {
            guard let soonest = held.indices.min(by: { held[$0].left < held[$1].left }) else { return nil }
            return ask(held.remove(at: soonest).id)
        }
        for index in held.indices { held[index].left -= 1 }
        // Pick from the front half. The card just asked sits at the end, outside the
        // window, and moves up one place per question: no card comes twice in a row
        // while others are left, and an `.again` card returns only after at least
        // `rotation.count - window` others.
        let window = (rotation.count + 1) / 2
        let index = Int.random(in: 0..<window, using: &random)
        let id = rotation.remove(at: index)
        rotation.append(id)
        seen.insert(id)
        return id
    }

    /// Puts a card that leaves the hold at the end of the rotation, as asked.
    private mutating func ask(_ id: Card.ID) -> Card.ID {
        rotation.append(id)
        seen.insert(id)
        return id
    }

    mutating func remove(_ id: Card.ID) {
        held.removeAll { $0.id == id }
        rotation.removeAll { $0 == id }
        staging.removeAll { $0 == id }
        backlog.removeAll { $0 == id }
    }

    /// Drops every card that has not been asked yet.
    mutating func finishUp() {
        backlog.removeAll()
        staging.removeAll()
        rotation.removeAll { !seen.contains($0) }
    }

    private mutating func fillRotation<R: RandomNumberGenerator>(using random: inout R) {
        while rotation.count < Self.rotationSize, !(staging.isEmpty && backlog.isEmpty) {
            if staging.isEmpty {
                let blockSize = min(Self.stagingSize, backlog.count)
                staging = Array(backlog.prefix(blockSize)).shuffled(using: &random)
                backlog.removeFirst(blockSize)
            }
            rotation.append(staging.removeFirst())
        }
    }
}
