import Foundation
import Testing

@testable import VocabCore

struct CardSearchIndexTests {
    let cards = [
        Card(question: "dzień", answer: "Tag"),
        Card(question: "dom", answer: "Haus", hint: "Gebäude"),
        Card(question: "kot", answer: "Katze"),
    ]

    @Test func searchesQuestionAnswerAndHint() {
        let index = CardSearchIndex(cards: cards)
        #expect(index.positions(matching: "dzie") == [0])
        #expect(index.positions(matching: "katz") == [2])
        #expect(index.positions(matching: "gebäude") == [1])
    }

    @Test func searchesTheWordKey() {
        let index = CardSearchIndex(cards: [Card(question: "το σπίτι", answer: "дом", note: "σπίτι|Haus"), Card(question: "dom", answer: "Haus")])
        #expect(index.positions(matching: "HAUS") == [0, 1])
        #expect(index.positions(matching: "σπιτι|") == [0])
    }

    @Test func replacedEntryFindsNewText() {
        var index = CardSearchIndex(cards: cards)
        index.replace(at: 1, with: Card(question: "chata", answer: "Hütte"))
        #expect(index.positions(matching: "haus").isEmpty)
        #expect(index.positions(matching: "hutte") == [1])
        #expect(index.positions(matching: "a") == [0, 1, 2])
    }

    @Test func ignoresCaseAndDiacritics() {
        let index = CardSearchIndex(cards: cards)
        #expect(index.positions(matching: "DZIEN") == [0])
        #expect(index.positions(matching: "gebaude") == [1])
        #expect(index.positions(matching: "dzien\u{0301}") == [0])  // n + combining acute accent
    }

    @Test func findsDecomposedText() {
        let index = CardSearchIndex(cards: [Card(question: "dzien\u{0301}", answer: "Tag")])
        #expect(index.positions(matching: "dzień") == [0])
    }

    @Test func ignoresStrokes() {
        let index = CardSearchIndex(cards: [Card(question: "łóżko", answer: "Bett"), Card(question: "Łóżko", answer: "Bett")])
        #expect(index.positions(matching: "lozko") == [0, 1])
        #expect(index.positions(matching: "LOZKO") == [0, 1])
    }

    /// Letters that have no canonical decomposition, in lower and upper case, and
    /// their plain spelling.
    @Test(arguments: [
        ("ł", "Ł", "l"), ("ø", "Ø", "o"), ("đ", "Đ", "d"), ("ħ", "Ħ", "h"), ("æ", "Æ", "ae"), ("œ", "Œ", "oe"),
    ])
    func foldsLettersWithoutDecomposition(lower: String, upper: String, plain: String) {
        let index = CardSearchIndex(cards: [
            Card(question: "x\(lower)y", answer: "Tag"),
            Card(question: "x\(upper)y", answer: "Tag"),
            Card(question: "x\(plain)y", answer: "Tag"),
        ])
        for query in ["x\(lower)y", "x\(upper)y", "x\(plain)y", "X\(plain.uppercased())Y"] {
            #expect(index.positions(matching: query) == [0, 1, 2], "query \(query)")
        }
    }

    @Test func blankQueryMatchesEverything() {
        let index = CardSearchIndex(cards: cards)
        #expect(index.positions(matching: "") == [0, 1, 2])
        #expect(index.positions(matching: "  ") == [0, 1, 2])
    }

    @Test func queryIsTrimmed() {
        #expect(CardSearchIndex(cards: cards).positions(matching: " kot ") == [2])
    }

    @Test func doesNotMatchAcrossFields() {
        #expect(CardSearchIndex(cards: cards).positions(matching: "domhaus").isEmpty)
        #expect(CardSearchIndex(cards: cards).positions(matching: "kotkatze").isEmpty)
    }

    @Test func filterKeepsTheGivenOrder() {
        let index = CardSearchIndex(cards: cards)
        #expect(index.filter([2, 1, 0], by: "a") == [2, 1, 0])
        #expect(index.filter([2, 0], by: "o") == [2])
    }
}

/// The word key (`Card.note`) is searched like the texts.
struct CardSearchIndexNoteTests {
    let cards = [
        Card(question: "αγαπώ", answer: "lieben", note: "αγαπώ", kind: .recognition),
        Card(question: "lieben", answer: "αγαπώ", note: "αγαπώ", kind: .production),
        Card(question: "Haus", answer: "casa", note: "σπίτι"),
        Card(question: "Katze", answer: "γάτα"),
    ]

    /// A key that appears in no other field finds its cards.
    @Test func findsCardsByTheirWordKey() {
        let index = CardSearchIndex(cards: [
            Card(question: "das Haus", answer: "σπίτι", note: "spiti-n"),
            Card(question: "die Katze", answer: "γάτα"),
        ])
        #expect(index.positions(matching: "spiti") == [0])
        #expect(index.positions(matching: "SPITI-N") == [0])
    }

    @Test func wordKeyIgnoresCaseAndAccents() {
        let index = CardSearchIndex(cards: cards)
        #expect(index.positions(matching: "ΑΓΑΠΩ") == [0, 1])
        #expect(index.positions(matching: "ΣΠΙΤΙ") == [2])
    }

    @Test func aCardWithoutAKeyMatchesNothingForIt() {
        #expect(CardSearchIndex(cards: cards).positions(matching: "katze") == [3])
        #expect(CardSearchIndex(cards: [Card(question: "kot", answer: "Katze")]).positions(matching: "note").isEmpty)
    }

    @Test func doesNotMatchAcrossHintAndKey() {
        let index = CardSearchIndex(cards: [Card(question: "dom", answer: "Haus", hint: "alt", note: "dom-n")])
        #expect(index.positions(matching: "altdom").isEmpty)
        #expect(index.positions(matching: "alt").count == 1)
        #expect(index.positions(matching: "dom-n").count == 1)
    }

    @Test func replacedEntryFindsTheNewKey() {
        var index = CardSearchIndex(cards: cards)
        #expect(index.positions(matching: "gata").isEmpty)
        index.replace(at: 3, with: Card(question: "Katze", answer: "γάτα", note: "gata"))
        #expect(index.positions(matching: "gata") == [3])
        index.replace(at: 3, with: Card(question: "Katze", answer: "γάτα"))
        #expect(index.positions(matching: "gata").isEmpty)
    }
}
