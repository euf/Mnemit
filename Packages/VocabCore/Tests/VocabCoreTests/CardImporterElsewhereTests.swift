import Foundation
import Testing

@testable import VocabCore

/// The words of other decks, see `WordIndex`, in the candidates of an import.
struct CardImporterElsewhereTests {
    let created = Date(timeIntervalSince1970: 1_791_216_000)

    private func elsewhere(_ name: String, _ cards: [Card]) throws -> WordIndex {
        WordIndex(decks: [(name, try Deck(cards: cards))])
    }

    private func word(_ greek: String, _ translation: String, note: String) -> [Card] {
        [
            Card(question: greek, answer: translation, note: note, kind: .recognition),
            Card(question: translation, answer: greek, note: note, kind: .production),
        ]
    }

    @Test func theSameWordInAnotherDeckIsADuplicate() throws {
        let other = try elsewhere("Greek A1–A2", word("ο/η οδηγός", "driver", note: "οδηγός#ο/η"))
        let made = word("ο οδηγός", "the driver; guide", note: "οδηγός#ο") + word("το νερό", "water", note: "νερό#το")
        let result = CardImporter.candidates(of: made, existing: [], elsewhere: other)
        let driver = result.prefix(2).compactMap { candidate -> String? in
            guard case let .inOtherDeck(match)? = candidate.duplicate else { return nil }
            return "\(match.deck): \(match.question) · \(match.answer)"
        }
        // Both cards of the word, the second asked from the translation.
        #expect(driver == ["Greek A1–A2: ο/η οδηγός · driver", "Greek A1–A2: ο/η οδηγός · driver"])
        #expect(result.suffix(2).map(\.duplicate) == [nil, nil])
        #expect(result.map(\.similar).allSatisfy { $0 == nil })
    }

    @Test func aRowOfAFileIsFoundByItsGreekQuestionToo() throws {
        let other = try elsewhere("Greek A1–A2", word("απλός, -ή, -ό", "plain; simple", note: "απλός"))
        let rows = [["Απλός", "easy"], ["dog", "σκύλος"]]
        let result = CardImporter.candidates(from: rows, existing: [], elsewhere: other, isHeader: { _ in false }, created: created)
        guard case .inOtherDeck? = result.candidates[0].duplicate else {
            Issue.record("the first row is the word of the other deck")
            return
        }
        #expect(result.candidates[1].duplicate == nil)
    }

    @Test func anAccentOnlyDifferenceIsSimilarAndNoDuplicate() throws {
        let other = try elsewhere("Greek A1–A2", word("άπλος", "simple", note: "άπλος"))
        let result = CardImporter.candidates(of: word("απλός, -ή, -ό", "plain; simple", note: "απλός"), existing: [], elsewhere: other)
        #expect(result.map(\.duplicate) == [nil, nil])
        #expect(result[0].similar?.deck == "Greek A1–A2")
        #expect(result[0].similar?.question == "άπλος")
        #expect(result[0].similar?.answer == "simple")
    }

    @Test func theDeckAndTheFileComeBeforeAnotherDeck() throws {
        let other = try elsewhere("Other", word("νερό", "water", note: "νερό"))
        let made = [Card(question: "νερό", answer: "w", note: "νερό", kind: .recognition), Card(question: "Νερό", answer: "x")]
        #expect(CardImporter.candidates(of: made, existing: [Card(question: "νερό", answer: "w")], elsewhere: other).map(\.duplicate) == [.inDeck, .inDeck])
        let inFile = CardImporter.candidates(of: made, existing: [], elsewhere: other).map(\.duplicate)
        guard case .inOtherDeck? = inFile[0] else {
            Issue.record("the first is a duplicate of the other deck")
            return
        }
        #expect(inFile[1] == .inFile(question: "νερό", answer: "w"))
    }

    @Test func noIndexMarksNothing() {
        let made = word("νερό", "water", note: "νερό")
        #expect(CardImporter.candidates(of: made, existing: []).map(\.duplicate) == [nil, nil])
    }
}
