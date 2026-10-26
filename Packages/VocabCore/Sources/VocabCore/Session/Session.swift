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
    /// Cards that became leeches during the session and were suspended for it, in order.
    public private(set) var leechIDs: [Card.ID] = []

    /// The card being asked is shown as a new word, which is no question: its answer is open and
    /// nothing is graded. `introduce(duration:)` moves on; the card is asked a few cards later.
    public private(set) var isIntroduction = false

    private var queue: SessionQueue
    private var random: SeededRandom
    /// The cards that are shown once as new words before they are asked, until they are.
    private var unintroduced: Set<Card.ID>
    /// How long each introduced card was on screen, until its first review takes it.
    private var introductionTimes: [Card.ID: Duration] = [:]

    /// - Parameter introducing: The cards whose first showing is an introduction, see `isIntroduction`.
    init(cardIDs: [Card.ID], startedAt: Date, random: SeededRandom, introducing: Set<Card.ID> = []) {
        self.startedAt = startedAt
        self.random = random
        unintroduced = introducing
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

    /// How long the card was on screen as an introduction, if it was introduced and not reviewed yet.
    func introductionTime(of id: Card.ID) -> Duration? { introductionTimes[id] }

    /// Whether the card was introduced in this session and has not been reviewed since.
    public func wasIntroduced(_ id: Card.ID) -> Bool { introductionTimes[id] != nil }

    /// The introduction of the current card is over: no grade is recorded, and the card is asked as
    /// a question after a few others (`SessionQueue.introductionGap`).
    ///
    /// - Parameter duration: How long the introduction was on screen; the card's first review adds it
    ///   to its own.
    mutating func introduce(duration: Duration) {
        guard isIntroduction, let id = currentCardID else { return }
        unintroduced.remove(id)
        introductionTimes[id] = duration
        queue.hold(id)
        advance()
    }

    /// Counts the review of the current card at `now` and moves on to the next one.
    ///
    /// - Parameters:
    ///   - isDone: Whether the current card leaves the session.
    ///   - isLeech: Whether the review made the card a leech, which suspends it: it leaves
    ///     the session, too, and counts as suspended.
    mutating func record(_ grade: Grade, isDone: Bool, isLeech: Bool = false, at now: Date) {
        guard let id = currentCardID else { return }
        lastReviewedAt = now
        introductionTimes[id] = nil
        reviewCount += 1
        if grade.isRecall {
            recalledCount += 1
        } else if !mistakeIDs.contains(id) {
            mistakeIDs.append(id)
        }
        if isLeech {
            leechIDs.append(id)
            suspendedCount += 1
        }
        if isDone || isLeech {
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
        isIntroduction = currentCardID.map(unintroduced.contains) ?? false
    }
}
