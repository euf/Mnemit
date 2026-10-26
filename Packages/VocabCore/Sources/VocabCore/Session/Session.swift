import Foundation

/// What a study session and practice have in common: which cards remain, which
/// one is asked, and how it went so far.
///
/// The session only tracks card IDs. Only its mode (`SessionMode`) changes it: the
/// mode records reviews and decides when a card is done.
public struct Session: Sendable {
    public let id = UUID()
    let startedAt: Date
    /// When the last review was recorded; `nil` before the first.
    private var lastReviewedAt: Date?
    public private(set) var currentCardID: Card.ID?
    public private(set) var totalCount: Int
    public private(set) var reviewCount = 0
    public private(set) var recalledCount = 0
    /// Cards graded `.again` at least once, in order of their first `.again`.
    public private(set) var mistakeIDs: [Card.ID] = []
    /// Cards suspended during the session, by the learner or as leeches; they left it.
    public private(set) var suspendedCount = 0
    /// Cards that became leeches during the session, in order: the moments the stream shows, whatever the
    /// deck's leech action does to the card.
    public private(set) var leechIDs: [Card.ID] = []

    private var queue: SessionQueue
    private var random: SeededRandom

    init(cardIDs: [Card.ID], startedAt: Date, random: SeededRandom) {
        self.startedAt = startedAt
        self.random = random
        queue = SessionQueue(cardIDs: cardIDs)
        totalCount = cardIDs.count
        advance()
    }

    public var isFinished: Bool { currentCardID == nil }
    public var remainingCount: Int { queue.count }
    public var completedCount: Int { totalCount - queue.count }
    /// Cards already asked that would still be finished by `SessionCommand.finishUp`.
    public var startedCount: Int { queue.startedCount }

    /// The time from the start to the last review, 0 without a review. A session ends
    /// with its last review, so the time stays the same once it is finished (#185).
    public var duration: TimeInterval {
        guard let lastReviewedAt else { return 0 }
        return max(0, lastReviewedAt.timeIntervalSince(startedAt))
    }

    /// Counts the review of the current card at `now` and moves on to the next one.
    ///
    /// - Parameters:
    ///   - isDone: Whether the current card leaves the session.
    ///   - isLeech: Whether the review made the card a leech: a moment of the stream.
    ///   - isSuspended: Whether the review suspended the card, as a leech under the deck's action
    ///     Suspend: it leaves the session, too, and counts as suspended.
    mutating func record(_ grade: Grade, isDone: Bool, isLeech: Bool = false, isSuspended: Bool = false, at now: Date) {
        guard let id = currentCardID else { return }
        lastReviewedAt = now
        reviewCount += 1
        if grade.isRecall {
            recalledCount += 1
        } else if !mistakeIDs.contains(id) {
            mistakeIDs.append(id)
        }
        if isLeech {
            leechIDs.append(id)
        }
        if isSuspended {
            suspendedCount += 1
        }
        if isDone || isSuspended {
            queue.remove(id)
        }
        advance()
    }

    mutating func perform(_ command: SessionCommand) {
        switch command {
        case .finishUp: finishUp()
        case .skip: skip()
        case .suspend:
            guard currentCardID != nil else { return }
            suspendedCount += 1
            skip()
        case let .setAside(id):
            guard queue.contains(id) else { return }
            queue.remove(id)
            suspendedCount += 1
            totalCount -= 1
            if currentCardID == id { advance() }
        case let .keep(id):
            guard suspendedCount > 0, !queue.contains(id) else { return }
            suspendedCount -= 1
            queue.add(id)
            if currentCardID == nil { advance() }
        }
    }

    private mutating func finishUp() {
        let completed = completedCount
        queue.finishUp()
        totalCount = completed + queue.count
        if let id = currentCardID, !queue.contains(id) {
            advance()
        }
    }

    private mutating func skip() {
        guard let id = currentCardID else { return }
        queue.remove(id)
        totalCount -= 1
        advance()
    }

    private mutating func advance() {
        currentCardID = queue.next(using: &random)
    }
}
