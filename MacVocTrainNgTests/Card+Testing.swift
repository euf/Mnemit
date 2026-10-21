import Foundation
@testable import VocabCore

extension Card {
    /// A card created at a fixed date, for tests that don't care when.
    init(
        id: UUID = UUID(),
        question: String,
        answer: String,
        hint: String = "",
        learningState: LearningState? = nil,
        log: [ReviewLogEntry] = []
    ) {
        self.init(
            id: id,
            question: question,
            answer: answer,
            hint: hint,
            created: Date(timeIntervalSince1970: 1_791_216_000),
            learningState: learningState,
            log: log
        )
    }

    /// The card with another answer, as an edit would leave it, but for its stamp.
    func withAnswer(_ answer: String) -> Card {
        var card = self
        card.answer = answer
        return card
    }

    /// The card without the stamp of its last change of content: a change of the content
    /// stamps the time it is applied, and so does undoing it, which a card built by hand
    /// doesn't have.
    var unstamped: Card {
        var card = self
        card.contentChanged = nil
        return card
    }
}

extension [Card] {
    var unstamped: [Card] { map(\.unstamped) }
}
