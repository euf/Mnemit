import Foundation
import Testing

@testable import VocabCore

/// The cards of one Anki note stay siblings: the word key and the direction of each card
/// (`Card.note`, `Card.kind`), and what a study session makes of them.
struct AnkiSiblingsTests {
    typealias Fixtures = AnkiFixtures

    static let basic = Fixtures.RawNoteType(id: 1)
    /// Anki's stock "Basic (and reversed card)".
    static let reversed = Fixtures.RawNoteType(
        id: 2, name: "Basic (and reversed card)", templates: ["{{Front}}", "{{Back}}"],
        answers: [#"{{FrontSide}}<hr id="answer">{{Back}}"#, #"{{FrontSide}}<hr id="answer">{{Front}}"#])
    /// Anki's stock "Basic (optional reversed card)": the second card exists if "Add Reverse" has text.
    static let optional = Fixtures.RawNoteType(
        id: 3, name: "Basic (optional reversed card)", fields: ["Front", "Back", "Add Reverse"],
        templates: ["{{Front}}", "{{#Add Reverse}}{{Back}}{{/Add Reverse}}"],
        answers: [#"{{FrontSide}}<hr id="answer">{{Back}}"#, #"{{FrontSide}}<hr id="answer">{{Front}}"#])
    static let threeWays = Fixtures.RawNoteType(
        id: 4, name: "Word, Meaning, Sentence", fields: ["Word", "Meaning", "Sentence"], templates: ["{{Word}}", "{{Meaning}}", "{{Sentence}}"],
        answers: ["{{FrontSide}}{{Meaning}}", "{{FrontSide}}{{Word}}", "{{FrontSide}}{{Word}}"])
    /// Two templates whose second asks from a field the first doesn't answer with.
    static let otherField = Fixtures.RawNoteType(
        id: 5, name: "Front, Back, Extra", fields: ["Front", "Back", "Extra"], templates: ["{{Front}}", "{{Extra}}"],
        answers: ["{{FrontSide}}{{Back}}", "{{FrontSide}}{{Front}}"])
    /// The note type of `AnkiImportTests`: two templates with no answer template to read.
    static let unanswered = Fixtures.RawNoteType(id: 6, name: "No answers", templates: ["{{Front}}", "{{Back}}"])

    /// A collection of `noteTypes` holding `notes` with the `cards` listed as (note, ord), in both schemas, read back.
    static func read(
        _ noteTypes: [Fixtures.RawNoteType], notes: [Fixtures.RawNote], cards: [(note: Int, ord: Int)], reviews: [Fixtures.RawReview] = [], current: Bool
    ) throws -> AnkiImport {
        let raw = cards.map { Fixtures.RawCard(id: $0.note * 10 + $0.ord, note: $0.note, ord: $0.ord) }
        let collection =
            current
            ? Fixtures.currentCollection(noteTypes: noteTypes, notes: notes, cards: raw, reviews: reviews)
            : Fixtures.legacyCollection(noteTypes: noteTypes, notes: notes, cards: raw, reviews: reviews)
        return try AnkiImport.read(Fixtures.zip([("collection.anki2", collection)]))
    }

    static func package(_ name: String) throws -> AnkiImport {
        let url = try #require(Bundle.module.url(forResource: "Resources/Anki/\(name)", withExtension: "apkg"))
        return try AnkiImport.read(url)
    }

    // MARK: Note and kind

    @Test(arguments: [false, true])
    func theTwoCardsOfAReversePairShareTheNoteAndAskBothWays(current: Bool) throws {
        let result = try Self.read(
            [Self.basic, Self.reversed],
            notes: [
                .init(id: 100, model: 1, fields: ["γάτα", "cat"], guid: "cat-guid"),
                .init(id: 101, model: 2, fields: ["νερό", "water"], guid: "water-guid"),
                .init(id: 102, model: 2, fields: ["ψωμί", "bread"], guid: "bread-guid"),
            ],
            cards: [(100, 0), (101, 0), (101, 1), (102, 0), (102, 1)], current: current)
        #expect(result.notes.map(\.front) == ["γάτα", "νερό", "water", "ψωμί", "bread"])
        #expect(result.notes.map(\.note) == [nil, "water-guid", "water-guid", "bread-guid", "bread-guid"])
        #expect(result.notes.map(\.kind) == [nil, .recognition, .production, .recognition, .production])

        // The key is the same when the package is read again, which is what a re-import needs.
        let again = try Self.read(
            [Self.reversed], notes: [.init(id: 555, model: 2, fields: ["νερό", "water"], guid: "water-guid")], cards: [(555, 1), (555, 0)], current: !current)
        #expect(again.notes.map(\.note) == ["water-guid", "water-guid"])

        let cards = result.cards(learningOptions: LearningOptions(), calendar: .testing, created: Date(timeIntervalSince1970: 1_791_216_000))
        #expect(cards.map(\.note) == result.notes.map(\.note))
        #expect(cards.map(\.kind) == result.notes.map(\.kind))
        #expect(cards.map(\.question) == result.notes.map(\.front))
    }

    @Test(arguments: [false, true])
    func aNoteOfThreeTemplatesSharesItsNoteAndEveryCardIsRecognition(current: Bool) throws {
        let result = try Self.read(
            [Self.threeWays],
            notes: [.init(id: 100, model: 4, fields: ["σπίτι", "house", "Το σπίτι μου είναι μεγάλο."], guid: "house-guid")],
            cards: [(100, 0), (100, 1), (100, 2)], current: current)
        #expect(result.notes.map(\.front) == ["σπίτι", "house", "Το σπίτι μου είναι μεγάλο."])
        #expect(result.notes.map(\.note) == ["house-guid", "house-guid", "house-guid"])
        #expect(result.notes.map(\.kind) == [.recognition, .recognition, .recognition])
    }

    @Test(arguments: [false, true])
    func twoTemplatesThatAreNoReversePairAreAllRecognition(current: Bool) throws {
        let result = try Self.read(
            [Self.otherField, Self.unanswered],
            notes: [
                .init(id: 100, model: 5, fields: ["a", "b", "c"], guid: "g1"),
                .init(id: 101, model: 6, fields: ["d", "e"], guid: "g2"),
            ],
            cards: [(100, 0), (100, 1), (101, 0), (101, 1)], current: current)
        #expect(result.notes.map(\.note) == ["g1", "g1", "g2", "g2"])
        #expect(result.notes.map(\.kind) == [.recognition, .recognition, .recognition, .recognition])
    }

    @Test(arguments: [false, true])
    func theOptionalReverseIsAPairWhetherOrNotTheNoteMadeItsSecondCard(current: Bool) throws {
        let result = try Self.read(
            [Self.optional],
            notes: [
                .init(id: 100, model: 3, fields: ["dog", "σκύλος", "y"], guid: "dog-guid"),
                .init(id: 101, model: 3, fields: ["bread", "ψωμί", ""], guid: "bread-guid"),
            ],
            cards: [(100, 0), (100, 1), (101, 0)], current: current)
        #expect(result.notes.map(\.front) == ["dog", "σκύλος", "bread"])
        #expect(result.notes.map(\.note) == ["dog-guid", "dog-guid", "bread-guid"])
        #expect(result.notes.map(\.kind) == [.recognition, .production, .recognition])
    }

    @Test(arguments: [false, true])
    func aNoteTypeWithOneTemplateHasNeitherNoteNorKind(current: Bool) throws {
        let typing = Fixtures.RawNoteType(id: 7, name: "Basic (type in the answer)", templates: ["{{Front}}{{type:Back}}"], answers: ["{{FrontSide}}{{type:Back}}"])
        let result = try Self.read(
            [Self.basic, typing],
            notes: [.init(id: 100, model: 1, fields: ["γάτα", "cat"], guid: "g1"), .init(id: 101, model: 7, fields: ["ψωμί", "bread"], guid: "g2")],
            cards: [(100, 0), (101, 0)], current: current)
        #expect(result.notes.count == 2)
        #expect(result.notes.allSatisfy { $0.note == nil && $0.kind == nil })
        let cards = result.cards(learningOptions: LearningOptions(), calendar: .testing, created: Date(timeIntervalSince1970: 1_791_216_000))
        #expect(cards.allSatisfy { $0.note == nil && $0.kind == nil })
    }

    @Test func aNoteWithoutAGuidHasNoKeyAndSoNoKind() throws {
        let result = try Self.read(
            [Self.reversed], notes: [.init(id: 100, model: 2, fields: ["νερό", "water"], guid: " ")], cards: [(100, 0), (100, 1)], current: false)
        #expect(result.notes.map(\.front) == ["νερό", "water"])
        #expect(result.notes.allSatisfy { $0.note == nil && $0.kind == nil })
    }

    @Test func aReversePairIsRecognizedByWhatItsTemplatesShow() {
        func type(_ templates: [String], _ answers: [String], fields: [String] = ["Front", "Back", "Extra"]) -> AnkiCollection.NoteType {
            var type = AnkiCollection.NoteType(fieldNames: fields, templateCount: templates.count)
            for (ord, format) in templates.enumerated() { type.questionFormats[ord] = format }
            for (ord, format) in answers.enumerated() { type.answerFormats[ord] = format }
            return type
        }
        #expect(type(["{{Front}}", "{{Back}}"], ["{{FrontSide}}{{Back}}", "{{FrontSide}}{{Front}}"]).isReversePair)
        // The reverse may ask with more than the one field, or name conditions around it.
        #expect(type(["{{Front}}", "{{#Extra}}{{Back}}{{/Extra}}{{Extra}}"], ["{{FrontSide}}{{Back}}", "x"]).isReversePair)
        #expect(type(["{{Front}}", "{{Back}}"], ["{{FrontSide}}{{type:Back}}", "x"]).isReversePair)
        #expect(!type(["{{Front}}", "{{Extra}}"], ["{{FrontSide}}{{Back}}", "x"]).isReversePair)
        #expect(!type(["{{Front}}", "{{Back}}"], ["{{FrontSide}}", "x"]).isReversePair)
        #expect(!type(["{{Front}}", "{{Back}}"], []).isReversePair)
        #expect(!type(["{{Front}}", "{{Back}}", "{{Extra}}"], ["{{FrontSide}}{{Back}}", "x", "x"]).isReversePair)
        #expect(!type(["{{Front}}{{Back}}"], ["{{FrontSide}}{{Back}}"]).isReversePair)
    }

    // MARK: Packages made by Anki

    /// `Resources/Anki/make_anki_fixtures.py` builds the packages with Anki's own library: a Basic
    /// note, a reversed pair, a note type of three templates, and the optional reverse with and without.
    @Test(arguments: ["siblings-latest", "siblings-legacy2"])
    func readsTheSiblingsOfPackagesMadeByAnki(name: String) throws {
        let result = try Self.package(name)
        #expect(
            result.notes.map(\.front) == ["γάτα", "νερό", "water", "σπίτι", "house", "Το σπίτι μου είναι μεγάλο.", "dog", "σκύλος", "bread"])
        #expect(result.notes.map(\.kind) == [nil, .recognition, .production, .recognition, .recognition, .recognition, .recognition, .production, .recognition])
        let keys = result.notes.map(\.note)
        #expect(keys[0] == nil)
        #expect(keys[1] == keys[2] && keys[3] == keys[4] && keys[4] == keys[5] && keys[6] == keys[7])
        // Four notes with several templates, four keys, each a guid of Anki.
        let distinct = Set(keys.compactMap { $0 })
        #expect(distinct.count == 4 && distinct.allSatisfy { !$0.isEmpty })
        #expect(keys[1] != keys[3] && keys[3] != keys[6] && keys[6] != keys[8])
    }

    @Test func bothLayoutsOfOneCollectionGiveTheSameKeys() throws {
        #expect(try Self.package("siblings-latest").notes.map(\.note) == Self.package("siblings-legacy2").notes.map(\.note))
        let greek = try Self.package("greek-latest")
        let water = greek.notes.filter { $0.front == "νερό" || $0.front == "water" }
        #expect(water.map(\.kind) == [.recognition, .production] && water[0].note != nil && water[0].note == water[1].note)
        #expect(try Self.package("greek-legacy2").notes.map(\.note) == greek.notes.map(\.note))
    }

    // MARK: A study session

    let calendar = StudyCalendar.testing

    func options() -> LearningOptions {
        var options = LearningOptions()
        options.fuzzing = false
        options.cardsPerSession = nil
        options.newCardsPerSession = nil
        options.newProductionPerSession = nil
        return options
    }

    func deck(_ result: AnkiImport, created: Date) throws -> Deck {
        let learning = options()
        return try Deck(learningOptions: learning, cards: result.cards(learningOptions: learning, calendar: calendar, created: created))
    }

    /// The questions a session takes at `now` from the cards of `result`.
    func selected(_ result: AnkiImport, at now: Date) throws -> [String] {
        let deck = try deck(result, created: now.addingTimeInterval(-90 * 86400))
        var random = SeededRandom(seed: 1)
        let ids = StudySession.selectCards(from: deck, at: now, calendar: calendar, using: &random)
        return ids.map { deck.card(withID: $0)!.question }
    }

    static let start = 1_768_000_000_000 + 15 * 3_600_000
    static let day = 86_400_000

    /// A reversed note whose forward card was reviewed good at the start, ten minutes later, and then after `days` days
    /// each. Returns the package and when the forward card was last reviewed.
    func reversePair(reviewedAfter days: [Int]) throws -> (result: AnkiImport, forward: LearningState) {
        let log = [(0, 0), (600_000, 0)] + days.map { ($0 * Self.day, 1) }
        let result = try Self.read(
            [Self.reversed], notes: [.init(id: 100, model: 2, fields: ["νερό", "water"], guid: "water-guid")], cards: [(100, 0), (100, 1)],
            reviews: log.map { .init(id: Self.start + $0.0, card: 1000, ease: 3, type: $0.1) }, current: false)
        let created = Date(timeIntervalSince1970: Double(Self.start / 1000) - 86400)
        let forward = try #require(try deck(result, created: created).cards.first?.learningState)
        #expect(forward.phase == .review)
        return (result, forward)
    }

    @Test func theReverseCardOfANewNoteWaitsForTheForwardCardToBeLearned() throws {
        let result = try Self.read(
            [Self.reversed], notes: [.init(id: 100, model: 2, fields: ["νερό", "water"], guid: "water-guid")], cards: [(100, 0), (100, 1)], current: false)
        let now = Date(timeIntervalSince1970: 1_791_216_000)
        // Both are new on the same day, but only one asks: the forward card.
        #expect(try selected(result, at: now) == ["νερό"])
        // The note is locked: its reverse card is production, which waits for the forward card to be learned.
        #expect(StudySession.notesAwaitingRecognition(in: try deck(result, created: now), calendar: calendar) == ["water-guid"])
    }

    @Test func theReverseCardStaysLockedWhileTheForwardIntervalIsShort() throws {
        // Two good reviews graduate the card, to an interval of two days.
        let (result, forward) = try reversePair(reviewedAfter: [])
        let interval = calendar.days(from: forward.lastReview, to: forward.due)
        #expect(interval >= 2 && interval < options().productionUnlockDays)
        // The next study day the forward card is not due yet and the reverse card is not unlocked.
        #expect(try selected(result, at: forward.lastReview.addingTimeInterval(86400)) == [])
    }

    @Test func theReverseCardIsBuriedTheDayItsSiblingWasReviewedAndFollowsOnceUnlocked() throws {
        let (result, forward) = try reversePair(reviewedAfter: [1, 4, 10, 24])
        // The forward card is in review with an interval that unlocks the reverse card.
        #expect(calendar.days(from: forward.lastReview, to: forward.due) >= options().productionUnlockDays)
        // The same study day: the forward card is not due, and the reverse is new but buried.
        #expect(try selected(result, at: forward.lastReview.addingTimeInterval(3600)) == [])
        // The next study day the reverse card is unlocked and nothing buries it.
        #expect(try selected(result, at: forward.lastReview.addingTimeInterval(86400)) == ["water"])
    }

    @Test func theCardsOfANoteOfThreeTemplatesComeOneADay() throws {
        let result = try Self.read(
            [Self.threeWays], notes: [.init(id: 100, model: 4, fields: ["σπίτι", "house", "Το σπίτι μου είναι μεγάλο."], guid: "house-guid")],
            cards: [(100, 0), (100, 1), (100, 2)], current: true)
        // All three are new and none is locked, but they are siblings: one of them asks.
        let asked = try selected(result, at: Date(timeIntervalSince1970: 1_791_216_000))
        #expect(asked.count == 1)
    }
}
