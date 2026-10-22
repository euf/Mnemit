import Foundation
import Testing

@testable import VocabCore

struct LessonWordsTests {
    let created = Date(timeIntervalSince1970: 1_791_216_000)

    /// The examples of `key()` in `greek-lessons/vocab/merge.py`.
    @Test(arguments: [
        ("η παρέα", "παρέα#η"),
        ("υπεύθυνος, -η, -ο", "υπεύθυνος"),
        ("τρώω (έφαγα)", "τρώω"),
        ("ο νέος", "νέος#ο"),
        ("νέος, -α, -ο", "νέος"),
        ("ο/η φοιτητής", "φοιτητής#ο/η"),
        ("το νερό", "νερό#το"),
        ("οι άνθρωποι", "άνθρωποι#οι"),
        ("  Η  Κλοπή ", "κλοπή#η"),
        ("πού είναι…;", "πού είναι…;"),
        ("ΟΔΌΣ", "οδός"),
    ])
    func noteIsMadeLikeMergePy(greek: String, note: String) {
        #expect(LessonWords.note(forGreek: greek) == note)
    }

    @Test func accentsAreKept() {
        #expect(LessonWords.note(forGreek: "πότε") != LessonWords.note(forGreek: "ποτέ"))
        #expect(LessonWords.note(forGreek: "πού") != LessonWords.note(forGreek: "που"))
    }

    @Test func aDecomposedAccentGivesTheSameNoteAsTheComposedOne() {
        #expect(LessonWords.note(forGreek: "παρέα") == LessonWords.note(forGreek: "παρε\u{0301}α"))
    }

    @Test func readsEqualsSignDashesAndTab() {
        let parsed = LessonWords.parse("κλέβω = красть\nη κλοπή – кража\nο κλέφτης — вор\nτο νερό\tвода")
        #expect(parsed.entries.map(\.greek) == ["κλέβω", "η κλοπή", "ο κλέφτης", "το νερό"])
        #expect(parsed.entries.map(\.translation) == ["красть", "кража", "вор", "вода"])
        #expect(parsed.entries.map(\.note) == ["κλέβω", "κλοπή#η", "κλέφτης#ο", "νερό#το"])
        #expect(parsed.invalidLines.isEmpty)
    }

    /// A phone keyboard types the plain hyphen, with spaces around it.
    @Test func readsASpacedHyphen() {
        let parsed = LessonWords.parse("το σπίτι - the house\nη ώρα = Stunde - Uhrzeit\nη κλοπή - theft = Diebstahl\nthe thief - ο κλέφτης")
        #expect(parsed.entries.map(\.greek) == ["το σπίτι", "η ώρα", "η κλοπή", "ο κλέφτης"])
        // The first separator splits: the later ones belong to the translation.
        #expect(parsed.entries.map(\.translation) == ["the house", "Stunde - Uhrzeit", "theft = Diebstahl", "the thief"])
        #expect(parsed.invalidLines.isEmpty)
    }

    /// Only the spaced hyphen separates: a hyphen inside a word, or at the end of a line, doesn't.
    @Test func aHyphenWithoutSpacesOnBothSidesIsPartOfTheWord() {
        let parsed = LessonWords.parse("υπεύθυνος, -η, -ο = verantwortlich\nthe ex-wife\nsomething -\n- something\nτο καλό-καιρινό = summery")
        #expect(parsed.entries.map(\.greek) == ["υπεύθυνος, -η, -ο", "το καλό-καιρινό"])
        #expect(parsed.entries.map(\.note) == ["υπεύθυνος", "καλό-καιρινό#το"])
        #expect(parsed.invalidLines == [2, 3, 4])
    }

    @Test func turnsALineWithTheGreekOnTheRightRound() {
        let parsed = LessonWords.parse("красть = κλέβω")
        #expect(parsed.entries.map(\.greek) == ["κλέβω"])
        #expect(parsed.entries.map(\.translation) == ["красть"])
    }

    @Test func theFirstSeparatorSplitsAndTheTranslationKeepsTheRest() {
        let parsed = LessonWords.parse("η ώρα = Stunde – Uhrzeit = Zeit")
        #expect(parsed.entries.map(\.translation) == ["Stunde – Uhrzeit = Zeit"])
    }

    @Test func countsLinesThatCannotBeUsed() {
        let parsed = LessonWords.parse("κλέβω = красть\n\nnur ein Wort\n= leer\nη κλοπή =  \nο κλέφτης = вор")
        #expect(parsed.entries.map(\.greek) == ["κλέβω", "ο κλέφτης"])
        #expect(parsed.invalidLines == [3, 4, 5])
    }

    @Test func eachWordMakesARecognitionAndAProductionCard() throws {
        let plan = LessonWords.plan(for: LessonWords.parse("η κλοπή = кража").entries, existingNotes: [String](), created: created)
        let recognition = try #require(plan.cards.first)
        let production = try #require(plan.cards.last)
        #expect(plan.cards.count == 2)
        #expect((recognition.question, recognition.answer, recognition.hint, recognition.kind) == ("η κλοπή", "кража", "", .recognition))
        #expect((production.question, production.answer, production.hint, production.kind) == ("кража", "η κλοπή", "", .production))
        #expect(plan.cards.allSatisfy { $0.note == "κλοπή#η" && $0.isNew && $0.created == created })
    }

    @Test func everyRecognitionCardComesBeforeTheProductionCards() {
        let plan = LessonWords.plan(for: LessonWords.parse("κλέβω = красть\nη κλοπή = кража").entries, existingNotes: [String](), created: created)
        #expect(plan.cards.map(\.kind) == [.recognition, .recognition, .production, .production])
        #expect(plan.cards.map(\.question) == ["κλέβω", "η κλοπή", "красть", "кража"])
    }

    @Test func skipsNotesTheDeckHasAndRepeatedLines() {
        let entries = LessonWords.parse("κλέβω = красть\nη κλοπή = кража\nη κλοπή = кражи\nο κλέφτης = вор").entries
        let plan = LessonWords.plan(for: entries, existingNotes: ["κλέβω", "κλέφτης#ο"], created: created)
        #expect(plan.cards.map(\.note) == ["κλοπή#η", "κλοπή#η"])
        #expect(plan.skipped.map(\.greek) == ["κλέβω", "η κλοπή", "ο κλέφτης"])
    }

    @Test func nothingIsLeftOfAnEmptyText() {
        let plan = LessonWords.plan(for: LessonWords.parse("  \n\n").entries, existingNotes: [String](), created: created)
        #expect(plan.cards.isEmpty && plan.skipped.isEmpty)
    }
}
