import Foundation
import Testing

@testable import VocabCore

struct WordIndexTests {
    private func word(_ greek: String, _ translation: String, note: String) -> [Card] {
        [
            Card(question: greek, answer: translation, note: note, kind: .recognition),
            Card(question: translation, answer: greek, note: note, kind: .production),
        ]
    }

    private func index(_ decks: (String, [Card])...) throws -> WordIndex {
        WordIndex(decks: try decks.map { ($0.0, try Deck(cards: $0.1)) })
    }

    private func candidate(_ question: String, note: String, answer: String = "x") -> Card {
        Card(question: question, answer: answer, note: note, kind: .recognition)
    }

    @Test func findsTheSameWordInAnotherDeckWithItsCards() throws {
        let cards = word("ο/η οδηγός", "driver", note: "οδηγός#ο/η")
        let index = try index(("Greek A1–A2", cards))
        guard case let .same(match)? = index.match(candidate("ο οδηγός", note: "οδηγός#ο")) else {
            Issue.record("not found")
            return
        }
        #expect(match.deck == "Greek A1–A2")
        #expect(match.question == "ο/η οδηγός")
        #expect(match.answer == "driver")
        #expect(match.cards == cards.map(\.id))
    }

    @Test func glossesAreNeverCompared() throws {
        let index = try index(("X", word("απλός, -ή, -ό", "plain; simple", note: "απλός")))
        guard case .same? = index.match(candidate("απλός", note: "απλός", answer: "completely different")) else {
            Issue.record("not the same word")
            return
        }
        // The glosses «simple» and «plain; simple» do not join άπλος to it, the accent decides.
        guard case .looksLike? = index.match(candidate("άπλος", note: "άπλος", answer: "simple")) else {
            Issue.record("άπλος should look like απλός")
            return
        }
    }

    @Test func anAccentOnlyDifferenceLooksLike() throws {
        let index = try index(("Greek A1–A2", word("άπλος", "simple", note: "άπλος")))
        guard case let .looksLike(match)? = index.match(candidate("απλός, -ή, -ό", note: "απλός", answer: "plain; simple")) else {
            Issue.record("not found")
            return
        }
        #expect(match.question == "άπλος")
        #expect(match.answer == "simple")
    }

    @Test func differentWordsAreNotTheSame() throws {
        let index = try index(("X", word("κύριος", "main", note: "κύριος") + word("πώς", "how", note: "πώς")))
        #expect(index.match(candidate("ο κύριος", note: "κύριος#ο")) == nil)
        // Only the accent differs: a notice, not the same word.
        guard case .looksLike? = index.match(candidate("πως", note: "πως")) else {
            Issue.record("πως should look like πώς")
            return
        }
    }

    @Test func aProductionCardShowsTheGreekSide() throws {
        let production = Card(question: "driver", answer: "ο οδηγός\nExample sentence", note: "οδηγός#ο", kind: .production)
        let index = try index(("X", [production]))
        guard case let .same(match)? = index.match(candidate("ο οδηγός", note: "οδηγός#ο")) else {
            Issue.record("not found")
            return
        }
        #expect(match.question == "ο οδηγός")
        #expect(match.answer == "driver")
    }

    @Test func theFirstDeckAnswers() throws {
        let index = try index(("First", word("νερό", "water", note: "νερό")), ("Second", word("νερό", "H2O", note: "νερό")))
        guard case let .same(match)? = index.match(candidate("νερό", note: "νερό")) else {
            Issue.record("not found")
            return
        }
        #expect(match.deck == "First")
    }

    @Test func cardsWithoutAKeyAreLeftOut() throws {
        let index = try index(("X", [Card(question: "dog", answer: "σκύλος")]))
        #expect(index.isEmpty)
        #expect(index.match(Card(question: "dog", answer: "σκύλος")) == nil)
    }

    @Test func anEmptyIndexFindsNothing() {
        #expect(WordIndex().match(Card(question: "νερό", answer: "water")) == nil)
    }
}
