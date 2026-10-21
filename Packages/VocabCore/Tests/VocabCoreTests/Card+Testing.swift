import Foundation
@testable import VocabCore

extension Card {
    /// A card created at a fixed date, for tests that don't care when.
    init(
        id: UUID = UUID(),
        question: String,
        answer: String,
        hint: String = "",
        note: String? = nil,
        kind: CardKind? = nil,
        learningState: LearningState? = nil,
        log: [ReviewLogEntry] = []
    ) {
        self.init(
            id: id,
            question: question,
            answer: answer,
            hint: hint,
            note: note,
            kind: kind,
            created: Date(timeIntervalSince1970: 1_791_216_000),
            learningState: learningState,
            log: log
        )
    }
}

extension Card {
    /// The card without the stamp of its last change of content, to compare it with one
    /// built by hand: a change of the content stamps the time it is applied, and so does
    /// undoing it.
    var unstamped: Card {
        var card = self
        card.contentChanged = nil
        return card
    }
}

extension [Card] {
    var unstamped: [Card] { map(\.unstamped) }
}
