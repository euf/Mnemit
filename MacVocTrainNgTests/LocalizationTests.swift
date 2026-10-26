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

    /// The phrases of the Add Cards sheet's list.
    @Test func addCardsPhrasesAreSingularForOne() throws {
        let english: [(String.LocalizationValue, String)] = [
            ("Add \(1) Cards", "Add 1 Card"),
            ("Add \(4) Cards", "Add 4 Cards"),
            ("\(1) lines without a word and a translation are left out.", "1 line without a word and a translation is left out."),
            ("\(3) lines without a word and a translation are left out.", "3 lines without a word and a translation are left out."),
        ]
        let german: [(String.LocalizationValue, String)] = [
            ("Add \(1) Cards", "1 Karte hinzufügen"),
            ("Add \(4) Cards", "4 Karten hinzufügen"),
            ("\(1) lines without a word and a translation are left out.", "1 Zeile ohne Wort und Übersetzung wird ausgelassen."),
            ("\(3) lines without a word and a translation are left out.", "3 Zeilen ohne Wort und Übersetzung werden ausgelassen."),
        ]
        for (language, cases) in [("en", english), ("de", german)] {
            for (value, expected) in cases {
                #expect(try localized(value, in: language) == expected)
            }
        }
    }

    /// A text with a count has the plural forms of each language: Russian has four.
    @Test func countsFollowThePluralsOfTheLanguage() throws {
        let english: [(String.LocalizationValue, String)] = [
            ("\(1) cards selected", "1 card selected"),
            ("\(2) cards selected", "2 cards selected"),
        ]
        let german: [(String.LocalizationValue, String)] = [
            ("\(1) cards selected", "1 Karte ausgewählt"),
            ("\(2) cards selected", "2 Karten ausgewählt"),
        ]
        let russian: [(String.LocalizationValue, String)] = [
            ("\(1) cards selected", "выбрана 1 карточка"),
            ("\(2) cards selected", "выбрано 2 карточки"),
            ("\(5) cards selected", "выбрано 5 карточек"),
            ("\(21) cards selected", "выбрана 21 карточка"),
        ]
        let greek: [(String.LocalizationValue, String)] = [
            ("\(1) cards selected", "1 επιλεγμένη κάρτα"),
            ("\(2) cards selected", "2 επιλεγμένες κάρτες"),
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
