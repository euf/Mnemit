import Foundation
import Testing

struct LocalizationTests {
    /// The strings of `value` in the app's bundle for `language`, the way
    /// `CardImport.titles(for:)` loads them.
    private func localized(_ value: String.LocalizationValue, in language: String) throws -> String {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        return String(localized: value, bundle: bundle, locale: Locale(identifier: language))
    }

    @Test func countsAreSingularForOne() throws {
        let file = "x.csv"
        let english: [(String.LocalizationValue, String)] = [
            ("Import \(1) Cards", "Import 1 Card"),
            ("Import \(2) Cards", "Import 2 Cards"),
            ("\(1) cards in “\(file)”", "1 card in “x.csv”"),
            ("\(2) cards in “\(file)”", "2 cards in “x.csv”"),
            ("\(1) rows without a question or an answer are left out.", "1 row without a question or an answer is left out."),
            ("\(2) rows without a question or an answer are left out.", "2 rows without a question or an answer are left out."),
            ("Export \(1) cards.", "Export 1 card."),
            ("Export \(2) cards.", "Export 2 cards."),
            ("Save the imported deck with \(1) cards.", "Save the imported deck with 1 card."),
            ("Save the imported deck with \(2) cards.", "Save the imported deck with 2 cards."),
            ("\(0) of \(1) cards", "0 of 1 card"),
            ("\(1) of \(2) cards", "1 of 2 cards"),
        ]
        let german: [(String.LocalizationValue, String)] = [
            ("Import \(1) Cards", "1 Karte importieren"),
            ("Import \(2) Cards", "2 Karten importieren"),
            ("\(1) cards in “\(file)”", "1 Karte in „x.csv“"),
            ("\(2) cards in “\(file)”", "2 Karten in „x.csv“"),
            ("\(1) rows without a question or an answer are left out.", "1 Zeile ohne Frage oder Antwort wird ausgelassen."),
            ("\(2) rows without a question or an answer are left out.", "2 Zeilen ohne Frage oder Antwort werden ausgelassen."),
            ("Export \(1) cards.", "1 Karte exportieren."),
            ("Export \(2) cards.", "2 Karten exportieren."),
            ("Save the imported deck with \(1) cards.", "Sichere den importierten Stapel mit 1 Karte."),
            ("Save the imported deck with \(2) cards.", "Sichere den importierten Stapel mit 2 Karten."),
            ("\(0) of \(1) cards", "0 von 1 Karte"),
            ("\(1) of \(2) cards", "1 von 2 Karten"),
        ]
        for (language, cases) in [("en", english), ("de", german)] {
            for (value, expected) in cases {
                let actual = try localized(value, in: language)
                #expect(actual == expected)
            }
        }
    }

    /// The phrases of the undo chip, "in 1 day" but "in 2 days", end to end.
    @Test func intervalPhrasesAreSingularForOne() throws {
        let english: [(String.LocalizationValue, String)] = [
            ("in \(1) days", "in 1 day"),
            ("in \(2) days", "in 2 days"),
            ("in \(1) months", "in 1 month"),
            ("in \(3) months", "in 3 months"),
            ("in \(1) years", "in 1 year"),
            ("in \(2) years", "in 2 years"),
        ]
        let german: [(String.LocalizationValue, String)] = [
            ("in \(1) days", "in 1 Tag"),
            ("in \(2) days", "in 2 Tagen"),
            ("in \(1) months", "in 1 Monat"),
            ("in \(3) months", "in 3 Monaten"),
            ("in \(1) years", "in 1 Jahr"),
            ("in \(2) years", "in 2 Jahren"),
        ]
        for (language, cases) in [("en", english), ("de", german)] {
            for (value, expected) in cases {
                #expect(try localized(value, in: language) == expected)
            }
        }
    }

    /// The phrases of the lesson words sheet.
    @Test func lessonWordPhrasesAreSingularForOne() throws {
        let deck = "Greek B1"
        let english: [(String.LocalizationValue, String)] = [
            ("Add \(1) cards to \(deck)", "Add 1 card to Greek B1"),
            ("Add \(4) cards to \(deck)", "Add 4 cards to Greek B1"),
            ("\(1) lines without a word and a translation are left out.", "1 line without a word and a translation is left out."),
            ("\(3) lines without a word and a translation are left out.", "3 lines without a word and a translation are left out."),
        ]
        let german: [(String.LocalizationValue, String)] = [
            ("Add \(1) cards to \(deck)", "1 Karte zu Greek B1 hinzufügen"),
            ("Add \(4) cards to \(deck)", "4 Karten zu Greek B1 hinzufügen"),
            ("\(1) lines without a word and a translation are left out.", "1 Zeile ohne Wort und Übersetzung wird ausgelassen."),
            ("\(3) lines without a word and a translation are left out.", "3 Zeilen ohne Wort und Übersetzung werden ausgelassen."),
        ]
        for (language, cases) in [("en", english), ("de", german)] {
            for (value, expected) in cases {
                #expect(try localized(value, in: language) == expected)
            }
        }
    }

    /// The lines of the stream at rest: "≈ +1 card/day" but "≈ +2 cards/day".
    @Test func streamPhrasesAreSingularForOne() throws {
        let english: [(String.LocalizationValue, String)] = [
            ("\(1) answers", "1 answer"),
            ("\(2) answers", "2 answers"),
        ]
        let german: [(String.LocalizationValue, String)] = [
            ("\(1) answers", "1 Antwort"),
            ("\(2) answers", "2 Antworten"),
        ]
        let russian: [(String.LocalizationValue, String)] = [
            ("\(1) answers", "1 ответ"),
            ("\(2) answers", "2 ответа"),
            ("\(5) answers", "5 ответов"),
            ("\(21) answers", "21 ответ"),
        ]
        let greek: [(String.LocalizationValue, String)] = [
            ("\(1) answers", "1 απάντηση"),
            ("\(2) answers", "2 απαντήσεις"),
        ]
        for (language, cases) in [("en", english), ("de", german), ("ru", russian), ("el", greek)] {
            for (value, expected) in cases {
                #expect(try localized(value, in: language) == expected)
            }
        }
    }

    /// A text whose wording depends on a count has plural forms in every language.
    @Test func everyLanguageHasThePluralsOfTheOthers() throws {
        let languages = ["en", "de"]
        let pluralKeys = try languages.map { language in
            let url = try #require(Bundle.main.url(forResource: "Localizable", withExtension: "stringsdict", subdirectory: nil, localization: language))
            let plurals = try #require(NSDictionary(contentsOf: url) as? [String: Any])
            return Set(plurals.keys)
        }
        #expect(!pluralKeys[0].isEmpty)
        #expect(pluralKeys[0] == pluralKeys[1])
    }
}
