import Foundation
import Testing

@testable import VocabCore

struct AnkiImportTests {
    typealias Fixtures = AnkiFixtures

    static let base = 1_768_000_000_000
    static let day = 86_400_000

    // MARK: A collection with one of everything

    /// Note types of Anki's stock set: Basic, Basic (and reversed card), Cloze, Basic (optional
    /// reversed card) and Basic (type in the answer).
    static let noteTypes = [
        Fixtures.RawNoteType(id: 1),
        Fixtures.RawNoteType(id: 2, name: "Basic (and reversed card)", templates: ["{{Front}}", "{{Back}}"]),
        Fixtures.RawNoteType(id: 3, name: "Cloze", fields: ["Text", "Extra"], templates: ["{{cloze:Text}}"], isCloze: true),
        Fixtures.RawNoteType(
            id: 4, name: "Basic (optional reversed card)", fields: ["Front", "Back", "Add Reverse"],
            templates: ["{{Front}}", "{{#Add Reverse}}{{Back}}{{/Add Reverse}}"]),
        Fixtures.RawNoteType(id: 5, name: "Basic (type in the answer)", templates: ["{{Front}}\n\n{{type:Back}}"]),
    ]

    static let decks = [1: "Default", 10: "Greek::Lesson 1", 11: "Greek::Lesson 2", 99: "Filtered Deck 1"]

    static let notes = [
        Fixtures.RawNote(id: 100, model: 1, fields: ["<b>γάτα</b>", "cat"]),
        Fixtures.RawNote(id: 101, model: 2, fields: ["νερό", "water"]),
        Fixtures.RawNote(id: 102, model: 3, fields: ["{{c1::Αθήνα}} is in {{c2::Greece}}", ""]),
        Fixtures.RawNote(id: 103, model: 1, fields: ["σπίτι<br>το", "house &amp; home"]),
        Fixtures.RawNote(id: 104, model: 1, fields: ["εικόνα", "<img src=\"x.jpg\">"]),
        Fixtures.RawNote(id: 105, model: 1, fields: ["ήχος [sound:x.mp3]", "sound"]),
        Fixtures.RawNote(id: 106, model: 4, fields: ["dog", "σκύλος", "y"]),
        Fixtures.RawNote(id: 107, model: 5, fields: ["ψωμί", "bread"]),
        Fixtures.RawNote(id: 108, model: 1, fields: ["τυρί", "cheese"]),
    ]

    // Listed out of order: the order of the result is the order of creation.
    static let cards = [
        Fixtures.RawCard(id: 1080, note: 108, deck: 99, filteredFrom: 10),
        Fixtures.RawCard(id: 1031, note: 103, deck: 11, queue: -1),
        Fixtures.RawCard(id: 1021, note: 102, deck: 10, ord: 1),
        Fixtures.RawCard(id: 1011, note: 101, deck: 10, ord: 1),
        Fixtures.RawCard(id: 1000, note: 100, deck: 10),
        Fixtures.RawCard(id: 1010, note: 101, deck: 10),
        Fixtures.RawCard(id: 1020, note: 102, deck: 10),
        Fixtures.RawCard(id: 1040, note: 104, deck: 10),
        Fixtures.RawCard(id: 1050, note: 105, deck: 10),
        Fixtures.RawCard(id: 1061, note: 106, deck: 10, ord: 1),
        Fixtures.RawCard(id: 1060, note: 106, deck: 10),
        Fixtures.RawCard(id: 1070, note: 107, deck: 10, queue: -2),
    ]

    static let reviews = [
        Fixtures.RawReview(id: base + 3 * day, card: 1000, ease: 1, type: 1, time: 9_500),
        Fixtures.RawReview(id: base, card: 1000, ease: 3, type: 0, time: 4_210),
        Fixtures.RawReview(id: base + day + 999, card: 1000, ease: 3, type: 1),
        Fixtures.RawReview(id: base + 600_000, card: 1000, ease: 4, type: 0),
        // Not reviews: manual and rescheduled entries, cramming without a rescheduling, a rating Anki has no button for.
        Fixtures.RawReview(id: base + 4 * day, card: 1000, ease: 0, type: 4, factor: 0),
        Fixtures.RawReview(id: base + 4 * day + 1, card: 1000, ease: 3, type: 5, factor: 0),
        Fixtures.RawReview(id: base + 4 * day + 2, card: 1000, ease: 3, type: 3, factor: 0),
        Fixtures.RawReview(id: base + 4 * day + 3, card: 1000, ease: 7, type: 1),
        // Cramming that counts, and a review of the reverse card of a note.
        Fixtures.RawReview(id: base + 5 * day, card: 1000, ease: 2, type: 3, factor: 2500),
        Fixtures.RawReview(id: base + 1000, card: 1011, ease: 2, type: 0),
        // A card that is left out has its reviews left out, too.
        Fixtures.RawReview(id: base + 2000, card: 1020, ease: 3, type: 0),
    ]

    static func collection(current: Bool, schedulerVersion: Int? = 2) -> Data {
        current
            ? Fixtures.currentCollection(noteTypes: noteTypes, decks: decks, notes: notes, cards: cards, reviews: reviews)
            : Fixtures.legacyCollection(noteTypes: noteTypes, decks: decks, schedulerVersion: schedulerVersion, notes: notes, cards: cards, reviews: reviews)
    }

    static func date(_ milliseconds: Int) -> Date { Date(timeIntervalSince1970: Double(milliseconds / 1000)) }

    private func verify(_ result: AnkiImport) {
        #expect(
            result.notes.map { [$0.front, $0.back] } == [
                ["γάτα", "cat"],
                ["νερό", "water"],
                ["water", "νερό"],  // the reverse card asks from the second field
                ["σπίτι\nτο", "house & home"],
                ["ήχος", "sound"],
                ["dog", "σκύλος"],
                ["σκύλος", "dog"],  // optional reverse
                ["ψωμί", "bread"],
                ["τυρί", "cheese"],
            ])
        #expect(result.notes.map(\.isSuspended) == [false, false, false, true, false, false, false, false, false])
        #expect(result.skippedCloze == 2)
        #expect(result.skippedMediaRefs == 2)
        #expect(result.skippedEmpty == 1)
        #expect(result.deckNames == ["Greek::Lesson 1", "Greek::Lesson 2"])

        let cat = result.notes[0].reviews
        #expect(cat.map(\.grade) == [.good, .easy, .good, .again, .hard])
        #expect(cat.map(\.date) == [Self.date(Self.base), Self.date(Self.base + 600_000), Self.date(Self.base + Self.day + 999), Self.date(Self.base + 3 * Self.day), Self.date(Self.base + 5 * Self.day)])
        #expect(cat.allSatisfy { $0.mode == .revealed })
        // The time Anki took per answer, in milliseconds; 0 is no time at all.
        #expect(cat.map(\.duration) == [.milliseconds(4_210), nil, nil, .milliseconds(9_500), nil])
        #expect(result.notes[2].reviews.map(\.grade) == [.hard])
        #expect(result.notes[1].reviews.isEmpty)
    }

    @Test(arguments: [false, true])
    func readsAllNoteTypesOfBothSchemas(current: Bool) throws {
        let reading = try AnkiImport.read(Fixtures.zip([("collection.anki2", Self.collection(current: current))]))
        verify(reading)
    }

    @Test func aCardWithoutItsNoteTypeCountsAsBasic() throws {
        let collection = Fixtures.legacyCollection(noteTypes: [], notes: [.init(id: 1, model: 77, fields: ["a", "b"])], cards: [.init(id: 2, note: 1)])
        let result = try AnkiImport.read(Fixtures.zip([("collection.anki2", collection)]))
        #expect(result.notes.map(\.front) == ["a"])
    }

    // MARK: Front and back from the templates

    private func read(noteTypes: [Fixtures.RawNoteType], notes: [Fixtures.RawNote], current: Bool) throws -> AnkiImport {
        let cards = notes.map { Fixtures.RawCard(id: $0.id * 10, note: $0.id) }
        let collection =
            current
            ? Fixtures.currentCollection(noteTypes: noteTypes, notes: notes, cards: cards)
            : Fixtures.legacyCollection(noteTypes: noteTypes, notes: notes, cards: cards)
        return try AnkiImport.read(Fixtures.zip([("collection.anki2", collection)]))
    }

    /// The deck that imported with no card: the second field is an image, and the question
    /// template shows the word and the image, the answer template the translation and more.
    @Test(arguments: [false, true])
    func theFrontAndTheBackComeFromTheTemplates(current: Bool) throws {
        let types = [
            Fixtures.RawNoteType(
                id: 1, name: "Vocabulary", fields: ["Front", "Image", "Audio", "Back", "Examples"],
                templates: ["<div>{{Front}}</div>{{{Image}}"], answers: ["{{FrontSide}}<hr>{{Back}}{{{Examples}}"]),
            Fixtures.RawNoteType(id: 2, name: "Reordered", fields: ["Note", "Word", "Meaning"], templates: ["{{Word}}"], answers: ["{{FrontSide}}{{Meaning}}"]),
            // The typing box is no part of the question: it is the answer, with the line after it.
            Fixtures.RawNoteType(
                id: 3, name: "Type", fields: ["Front", "Back", "Extra"], templates: ["{{Front}}{{type:Back}}"],
                answers: ["{{FrontSide}}<hr>{{type:Back}}{{Extra}}"]),
            // Neither template names a field.
            Fixtures.RawNoteType(id: 4, name: "Unreadable", fields: ["A", "B", "C"], templates: ["{{FrontSide}}"], answers: ["no fields"]),
            // The question starts with an image.
            Fixtures.RawNoteType(id: 5, name: "Image first", fields: ["Image", "Word", "Meaning"], templates: ["{{Image}}{{Word}}"], answers: ["{{FrontSide}}{{Meaning}}"]),
        ]
        let notes = [
            Fixtures.RawNote(id: 1, model: 1, fields: ["παίρνω", "<img src=\"a.jpg\">", "[sound:a.mp3]", "get", "<div>Παίρνω καφέ.</div>"]),
            Fixtures.RawNote(id: 2, model: 2, fields: ["n", "νερό", "water"]),
            Fixtures.RawNote(id: 3, model: 3, fields: ["ψωμί", "bread", "with butter"]),
            Fixtures.RawNote(id: 4, model: 4, fields: ["", "σκύλος", "dog"]),
            Fixtures.RawNote(id: 5, model: 5, fields: ["<img src=\"a.jpg\">", "σπίτι", "house"]),
        ]
        let result = try read(noteTypes: types, notes: notes, current: current)
        #expect(
            result.notes.map { [$0.front, $0.back] } == [
                ["παίρνω", "get\nΠαίρνω καφέ."],
                ["νερό", "water"],
                ["ψωμί", "bread\nwith butter"],
                ["σκύλος", "dog"],
                ["σπίτι", "house"],
            ])
        #expect(result.skippedEmpty == 0)
    }

    @Test(arguments: [false, true])
    func saysWhySidesWhoseMediaIsLostAreLeftOut(current: Bool) throws {
        let types = [
            Fixtures.RawNoteType(id: 1, name: "Listening", fields: ["Audio", "Text"], templates: ["{{Audio}}"], answers: ["{{FrontSide}}{{Text}}"]),
            Fixtures.RawNoteType(id: 2, name: "Basic"),
        ]
        let notes = [
            Fixtures.RawNote(id: 1, model: 1, fields: ["[sound:a.mp3]", "ακούω"]),
            Fixtures.RawNote(id: 2, model: 2, fields: ["εικόνα", "<img src=\"a.jpg\">"]),
            Fixtures.RawNote(id: 3, model: 2, fields: ["τίποτα", ""]),
            Fixtures.RawNote(id: 4, model: 2, fields: ["γάτα", "cat"]),
        ]
        let result = try read(noteTypes: types, notes: notes, current: current)
        #expect(result.notes.map(\.front) == ["γάτα"])
        #expect(result.skippedEmpty == 3)
        #expect(result.skippedMediaOnly == 2)
        #expect(result.skippedMediaRefs == 2)
    }

    @Test func aTemplateShowsAFieldOnceAndIgnoresWhatShowsNone() {
        let names = ["Front", "Image", "Back", "Extra"]
        func shown(_ format: String, typed: Bool = false) -> [Int] {
            AnkiCollection.fields(shownBy: format, in: names, showsTyped: typed)
        }
        #expect(shown("{{Front}}<br>{{Front}}{{FrontSide}}{{Tags}}") == [0])
        #expect(shown("{{{Image}}") == [1])  // a stray brace
        #expect(shown("{{{Image}}}{{Back}}") == [1, 2])
        #expect(shown("{{#Extra}}{{Back}}{{/Extra}}{{^Image}}x{{/Image}}{{! Front }}") == [2])
        #expect(shown("{{hint:Extra}}{{tts en_US:Back}}{{text:Front}}") == [3, 2, 0])
        #expect(shown("{{Front}}{{type:Back}}") == [0])
        #expect(shown("{{Front}}{{type:Back}}", typed: true) == [0, 2])
        #expect(shown("{{Missing}} {{ Front }} {{") == [0])
        #expect(shown("").isEmpty)
    }

    @Test(arguments: ["media-fields-latest", "media-fields-legacy2"])
    func readsADeckWhoseSecondFieldIsAnImage(name: String) throws {
        let result = try Self.package(name)
        // The note with no word has its picture to ask with, and the one that asks with its audio has
        // that; the meaning is the first field the answer adds, then the example, not the frequency.
        #expect(
            result.notes.map { [$0.front, $0.back] } == [
                ["παίρνω", "get\nΠαίρνω τον καφέ μου στις οκτώ.\nI get my coffee at eight."], ["χρόνος", "time"], ["", "no word"], ["", "ακούω"],
            ])
        #expect(result.deckNames == ["Media"])
        #expect(result.skippedCloze == 0)
        // The note with no translation is empty, and says nothing of media.
        #expect(result.skippedEmpty == 1)
        #expect(result.skippedMediaOnly == 0)
        #expect(result.skippedMediaRefs == 0)
        #expect(result.notes.map(\.media.hasQuestionMedia) == [true, true, true, true])
        #expect(result.notes.map(\.media.hasAnswerMedia) == [true, false, false, false])
        #expect(result.media.count == 2)
        #expect(result.mediaSummary.images == 1 && result.mediaSummary.sounds == 1)
    }

    @Test func aNoteWithTooFewFieldsIsEmpty() throws {
        let collection = Fixtures.legacyCollection(notes: [.init(id: 1, model: 1, fields: ["only one"])], cards: [.init(id: 2, note: 1)])
        let result = try AnkiImport.read(Fixtures.zip([("collection.anki2", collection)]))
        #expect(result.notes.isEmpty)
        #expect(result.skippedEmpty == 1)
    }

    // MARK: Ratings

    @Test func firstSchedulerGaveLearningCardsThreeButtons() throws {
        let reviews = [
            Fixtures.RawReview(id: Self.base, card: 2, ease: 2, type: 0),  // learning: Good
            Fixtures.RawReview(id: Self.base + 1000, card: 2, ease: 3, type: 0),  // learning: Easy
            Fixtures.RawReview(id: Self.base + 2000, card: 2, ease: 2, type: 1),  // review: Hard
            Fixtures.RawReview(id: Self.base + 3000, card: 2, ease: 3, type: 2),  // relearning: Easy
            Fixtures.RawReview(id: Self.base + 4000, card: 2, ease: 4, type: 0),  // no such button
            Fixtures.RawReview(id: Self.base + 5000, card: 2, ease: 1, type: 0),
        ]
        func grades(schedulerVersion: Int?) throws -> [Grade] {
            let collection = Fixtures.legacyCollection(schedulerVersion: schedulerVersion, notes: [.init(id: 1, model: 1, fields: ["a", "b"])], cards: [.init(id: 2, note: 1)], reviews: reviews)
            return try AnkiImport.read(Fixtures.zip([("collection.anki2", collection)])).notes[0].reviews.map(\.grade)
        }
        #expect(try grades(schedulerVersion: nil) == [.good, .easy, .hard, .easy, .again])
        #expect(try grades(schedulerVersion: 1) == [.good, .easy, .hard, .easy, .again])
        #expect(try grades(schedulerVersion: 2) == [.hard, .good, .hard, .good, .easy, .again])
    }

    // MARK: Layouts

    @Test func readsLegacy1() throws {
        let file = Fixtures.zip([("collection.anki2", Self.collection(current: false)), ("media", Data("{}".utf8))])
        verify(try AnkiImport.read(file))
    }

    @Test func legacy2WithoutMetaIsRecognizedByItsCollection() throws {
        let file = Fixtures.zip([("collection.anki2", Fixtures.placeholder), ("collection.anki21", Self.collection(current: false)), ("media", Data("{}".utf8))])
        verify(try AnkiImport.read(file))
    }

    @Test func legacy2WithMetaIgnoresThePlaceholder() throws {
        let file = Fixtures.zip([("meta", Fixtures.legacy2Meta), ("collection.anki2", Fixtures.placeholder), ("collection.anki21", Self.collection(current: false))])
        verify(try AnkiImport.read(file))
    }

    @Test func readsTheLatestLayout() throws {
        let file = Fixtures.zip([
            ("meta", Fixtures.latestMeta),
            ("collection.anki21b", Fixtures.zstd(Self.collection(current: true))),
            ("collection.anki2", Fixtures.placeholder),
            ("media", Fixtures.zstd(Data())),
        ])
        verify(try AnkiImport.read(file))
    }

    @Test func theLatestLayoutNeedsItsCollection() throws {
        // Without it the placeholder must not be read instead.
        let file = Fixtures.zip([("meta", Fixtures.latestMeta), ("collection.anki2", Fixtures.placeholder)])
        #expect(throws: AnkiImport.Error.missingCollection) { try AnkiImport.read(file) }
        #expect(throws: AnkiImport.Error.missingCollection) { try AnkiImport.read(Fixtures.zip([("media", Data("{}".utf8))])) }
    }

    @Test func refusesAnUnknownVersion() {
        for meta in [Fixtures.varintField(1, 4), Fixtures.varintField(1, 99), Data(), Fixtures.varintField(1, 0)] {
            let file = Fixtures.zip([("meta", meta), ("collection.anki21b", Fixtures.zstd(Self.collection(current: true)))])
            #expect(throws: AnkiImport.Error.unsupportedVersion) { try AnkiImport.read(file) }
        }
    }

    @Test func refusesDamagedCollections() {
        let garbage = Data("this is no database, and long enough to look like a file".utf8)
        #expect(throws: AnkiImport.Error.unreadableCollection) { try AnkiImport.read(Fixtures.zip([("collection.anki2", garbage)])) }
        #expect(throws: AnkiImport.Error.unreadableArchive) {
            try AnkiImport.read(Fixtures.zip([("meta", Fixtures.latestMeta), ("collection.anki21b", garbage)]))
        }
        // A database of some other program.
        let other = Fixtures.database(["CREATE TABLE things (id integer)"])
        #expect(throws: AnkiImport.Error.unreadableCollection) { try AnkiImport.read(Fixtures.zip([("collection.anki2", other)])) }
        #expect(throws: AnkiImport.Error.unreadableArchive) { try AnkiImport.read(Data("not a zip".utf8)) }
    }

    @Test func readsAFileByURL() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).apkg")
        defer { try? FileManager.default.removeItem(at: url) }
        try Fixtures.zip([("collection.anki2", Self.collection(current: false))]).write(to: url)
        verify(try AnkiImport.read(url))
        #expect(throws: AnkiImport.Error.unreadableArchive) { try AnkiImport.read(url.appendingPathExtension("missing")) }
    }

    @Test func leavesNoTemporaryDatabaseBehind() throws {
        func databases() -> Set<String> {
            Set(((try? FileManager.default.contentsOfDirectory(atPath: FileManager.default.temporaryDirectory.path)) ?? []).filter { $0.hasPrefix("anki-import-") })
        }
        let before = databases()
        _ = try AnkiImport.read(Fixtures.zip([("collection.anki2", Self.collection(current: false))]))
        #expect(throws: AnkiImport.Error.unreadableCollection) { try AnkiImport.read(Fixtures.zip([("collection.anki2", Data("garbage".utf8))])) }
        #expect(databases().subtracting(before).isEmpty)
    }

    // MARK: Packages made by Anki

    private static func package(_ name: String) throws -> AnkiImport {
        let url = try #require(Bundle.module.url(forResource: "Resources/Anki/\(name)", withExtension: "apkg"))
        return try AnkiImport.read(url)
    }

    /// `Resources/Anki/make_anki_fixtures.py` builds the packages with Anki's own library.
    @Test(arguments: ["greek-latest", "greek-latest-cli", "greek-legacy2", "greek-legacy1"])
    func readsPackagesMadeByAnki(name: String) throws {
        let result = try Self.package(name)
        #expect(
            result.notes.map { [$0.front, $0.back] } == [
                ["γάτα", "cat"],
                ["σπίτι\nτο", "house & home"],
                ["εικόνα", ""],  // its picture is the back
                ["ήχος", "sound"],
                ["νερό", "water"],
                ["water", "νερό"],
                ["σκύλος", "dog"],
            ])
        #expect(result.notes.map(\.isSuspended) == [false, false, false, false, false, false, true])
        #expect(result.skippedCloze == 2)
        // The picture is in the package, the sound of "ήχος" is not.
        #expect(result.skippedMediaRefs == 1)
        #expect(result.skippedEmpty == 0)
        #expect(result.notes[2].media.answerImage != nil && result.notes[3].media.isEmpty)
        #expect(result.media.count == 1)
        #expect(result.deckNames == ["Greek::Lesson 1"])

        let base = 1_768_000_000_000
        let cat = result.notes[0].reviews
        #expect(cat.map(\.grade) == [.good, .good, .good, .again, .good])
        #expect(cat.first?.date == Self.date(base))
        #expect(cat.last?.date == Self.date(base + 5 * Self.day + 300_000))
        // Anki's own library logs 3000 ms for each of them.
        #expect(cat.map(\.duration) == [Duration](repeating: .milliseconds(3_000), count: 5))
        #expect(result.notes[1].reviews.map(\.duration) == [.milliseconds(3_000)])
        #expect(result.notes[1].reviews.map(\.grade) == [.easy])
        #expect(result.notes[4].reviews.map(\.grade) == [.good])
        #expect(result.notes[5].reviews.map(\.grade) == [.hard])
        #expect(result.notes[2].reviews.isEmpty && result.notes[3].reviews.isEmpty && result.notes[6].reviews.isEmpty)
    }
}
