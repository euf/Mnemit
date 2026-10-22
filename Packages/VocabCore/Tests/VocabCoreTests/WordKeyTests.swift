import Foundation
import Testing

@testable import VocabCore

/// The rules of `references/cross-deck-overlap.md` §4.1 and §4.2, with its probe pairs.
struct WordKeyTests {
    private func key(_ text: String) throws -> WordKey {
        try #require(WordKey(text))
    }

    private func same(_ first: String, _ second: String) throws -> Bool {
        try key(first).same(as: key(second))
    }

    private func looksLike(_ first: String, _ second: String) throws -> Bool {
        try key(first).looksLike(key(second))
    }

    // MARK: Section 4.1

    @Test(arguments: [
        ("απλός", "απλός, -ή, -ό"),
        ("απλός", "απλός -ή -ό"),
        ("απλός", "απλός-ή-ό"),
        ("απλός", "Απλός"),
        ("ο ψεύτης", "ο ψεύτης / η ψεύτρα"),
        ("ο/η οδηγός", "ο οδηγός"),
        ("ο/η οδηγός", "η οδηγός"),
        ("η/ο οδηγός", "ο οδηγός"),
        ("ο/η οδηγός", "η/ο οδηγός"),
    ])
    func theSameWord(first: String, second: String) throws {
        #expect(try same(first, second))
        #expect(try same(second, first))
    }

    @Test(arguments: [
        ("ο νέος", "νέος, -α, -ο"),
        ("πώς", "πως"),
        ("άπλος", "απλός, -ή, -ό"),
        ("ο οδηγός", "η οδηγός"),
        ("το νερό", "ο νερό"),
        ("το νερό", "τα νερό"),
        ("ο/η οδηγός", "το οδηγός"),
        ("ο οδηγός", "οδηγός"),
    ])
    func notTheSameWord(first: String, second: String) throws {
        #expect(try !same(first, second))
        #expect(try !same(second, first))
    }

    /// The six pairs of the owner's decks that differ by the article only: `ο/η` in one deck, `ο` in
    /// the other.
    @Test(arguments: ["αστυνομικός", "διπλωμάτης", "οδηγός", "παραγωγός", "συγγενής", "χορτοφάγος"])
    func theSixCommonGenderPairs(lemma: String) throws {
        #expect(try same("ο/η \(lemma)", "ο \(lemma)"))
        #expect(try same("\(lemma)#ο/η", "\(lemma)#ο"))
    }

    /// The five words the accent-free key alone would have joined to another: different words.
    @Test(arguments: [
        ("κύριος", "ο κύριος"),
        ("νέος, -α, -ο", "ο νέος"),
        ("οικονομικά", "τα οικονομικά"),
        ("συνέχεια", "η συνέχεια"),
        ("πώς", "πως"),
    ])
    func theFiveDifferentWords(first: String, second: String) throws {
        #expect(try !same(first, second))
        #expect(try !same(second, first))
    }

    @Test func aNoteIsAKeyToo() throws {
        #expect(try same("άγγλος / η αγγλίδα#ο", "άγγλος#ο"))
        #expect(try same("ένα κιλό", "κιλό#ένα"))
        #expect(try same("οδηγός#ο/η", "ο οδηγός"))
        #expect(try key("η παρέα").note == "παρέα#η")
        #expect(try key("παρέα#η") == key("η παρέα"))
        // A note from a table with an empty article column.
        #expect(try key("άγγλος#") == key("άγγλος"))
    }

    @Test(arguments: [
        ("η παρέα", "παρέα", "η"),
        ("υπεύθυνος, -η, -ο", "υπεύθυνος", ""),
        ("τρώω (έφαγα)", "τρώω", ""),
        ("τρώω(έφαγα)", "τρώω", ""),
        ("ο/η φοιτητής", "φοιτητής", "ο/η"),
        ("απλός-ή-ό", "απλός", ""),
        ("ένας φίλος", "φίλος", "ένας"),
        ("μια φορά", "φορά", "μια"),
        ("ο φίλος; η φίλη", "φίλος", "ο"),
        ("ο φίλος · friend", "φίλος", "ο"),
        ("  Η  Κλοπή ", "κλοπή", "η"),
        ("ΟΔΌΣ", "οδός", ""),
    ])
    func theLemmaAndItsArticle(text: String, lemma: String, article: String) throws {
        let key = try key(text)
        #expect(key.lemma == lemma)
        #expect(key.article == article)
    }

    /// What stays in the lemma: a hyphen inside a word, the Greek question mark, a phrase.
    @Test(arguments: [
        ("το καλό-καιρινό", "καλό-καιρινό"),
        ("αλήθεια;", "αλήθεια;"),
        ("πού είναι…;", "πού είναι…;"),
        ("από πού είσαι;", "από πού είσαι;"),
        ("γεια σου", "γεια σου"),
    ])
    func whatStaysInTheLemma(text: String, lemma: String) throws {
        #expect(try key(text).lemma == lemma)
    }

    @Test func aDecomposedAccentIsTheComposedOne() throws {
        #expect(try key("παρέα") == key("παρε\u{0301}α"))
    }

    @Test func aFinalSigmaIsWrittenAsOne() throws {
        #expect(try key("ΑΠΛΟΣ").lemma == "απλος")
    }

    @Test func noLemmaNoKey() {
        #expect(WordKey("") == nil)
        #expect(WordKey("(έφαγα)") == nil)
    }

    // MARK: Section 4.2

    @Test(arguments: [
        ("άπλος", "απλός, -ή, -ό"),
        ("ΑΠΛΟΣ", "απλός"),
        ("πώς", "πως"),
        ("ο ποτέ", "ο πότε"),
        ("ο/η οδηγος", "ο οδηγός"),
    ])
    func looksLikeButForAccents(first: String, second: String) throws {
        #expect(try looksLike(first, second))
        #expect(try looksLike(second, first))
    }

    @Test(arguments: [
        // The same word is not one that looks like it.
        ("απλός", "απλός, -ή, -ό"),
        ("ο/η οδηγός", "ο οδηγός"),
        // The article stays a difference, accents or not.
        ("κύριος", "ο κύριος"),
        ("νέος", "ο νέος"),
        ("οικονομικά", "τα οικονομικά"),
        ("συνέχεια", "η συνέχεια"),
        ("ο οδηγος", "η οδηγός"),
        ("άπλος", "απλά"),
    ])
    func doesNotLookLike(first: String, second: String) throws {
        #expect(try !looksLike(first, second))
        #expect(try !looksLike(second, first))
    }

    // MARK: Cards

    @Test func aCardAsksItsNoteOrItsGreekQuestion() throws {
        let noted = Card(question: "ο οδηγός", answer: "driver", note: "οδηγός#ο", kind: .recognition)
        #expect(WordKey(card: noted)?.note == "οδηγός#ο")
        // The production card has the translation as question: the note says the word.
        let production = Card(question: "driver", answer: "ο οδηγός", note: "οδηγός#ο", kind: .production)
        #expect(WordKey(card: production)?.note == "οδηγός#ο")
        let single = Card(question: "η παρέα", answer: "company")
        #expect(WordKey(card: single)?.note == "παρέα#η")
        // The note of an Anki card is a random string, and its question is Greek.
        let anki = Card(question: "ο σκύλος", answer: "dog", note: "kF2#]d9?xP", kind: .recognition)
        #expect(WordKey(card: anki)?.note == "σκύλος#ο")
        #expect(WordKey(card: Card(question: "the dog", answer: "ο σκύλος")) == nil)
        #expect(WordKey(card: Card(question: "dog", answer: "ο σκύλος", note: "kF2#]d9?xP", kind: .production)) == nil)
    }

    // MARK: Groups

    @Test func groupsJoinWhatIsOneWordThroughAThird() throws {
        let keys = try ["ο οδηγός", "η οδηγός", "ο/η οδηγός", "το νερό", "νερό", "ο οδηγός"].map(key)
        let groups = WordKey.groups(of: keys)
        // ο and η are joined by the ο/η; το νερό is not νερό.
        #expect(Set(groups[0...2]).count == 1)
        #expect(groups[5] == groups[0])
        #expect(groups[3] != groups[4])
        #expect(Set(groups).count == 3)
    }
}
