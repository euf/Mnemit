import Foundation
import Testing

@testable import VocabCore

/// The images and sounds of an Anki package: the media list of each layout, which files come along
/// and how they are named, and the sides that have no text but a file.
struct AnkiMediaTests {
    typealias Fixtures = AnkiFixtures

    static let picture = Data([0x89, 0x50, 0x4E, 0x47, 0x01, 0x02, 0x03])
    static let sound = Data("RIFF....WAVEfmt ".utf8)

    static var pictureName: String { DeckMedia.name(for: picture, fileExtension: "png") }
    static var soundName: String { DeckMedia.name(for: sound, fileExtension: "wav") }

    /// A package of Basic notes with `media`, in the layout of Legacy 2 or the Latest one.
    static func package(_ fields: [[String]], media: [(name: String, data: Data)], current: Bool, damagedList: Bool = false) -> Data {
        let notes = fields.enumerated().map { Fixtures.RawNote(id: $0.offset + 1, model: 1, fields: $0.element) }
        let cards = notes.map { Fixtures.RawCard(id: $0.id * 10, note: $0.id) }
        if current {
            var entries: [(String, Data)] = [("meta", Fixtures.latestMeta), ("collection.anki21b", Fixtures.zstd(Fixtures.currentCollection(notes: notes, cards: cards)))]
            var list = Data()
            for (index, file) in media.enumerated() {
                entries.append((String(index), Fixtures.zstd(file.data)))
                list += Fixtures.bytesField(1, Fixtures.stringField(1, file.name) + Fixtures.varintField(2, UInt64(file.data.count)) + Fixtures.bytesField(3, Data(count: 20)))
            }
            entries.append(("media", damagedList ? Data("garbage".utf8) : Fixtures.zstd(list)))
            return Fixtures.zip(entries, stored: Set(entries.map(\.0)))
        }
        var entries: [(String, Data)] = [("meta", Fixtures.legacy2Meta), ("collection.anki21", Fixtures.legacyCollection(notes: notes, cards: cards))]
        var list: [String: String] = [:]
        for (index, file) in media.enumerated() {
            entries.append((String(index), file.data))
            list[String(index)] = file.name
        }
        entries.append(("media", damagedList ? Data("garbage".utf8) : try! JSONSerialization.data(withJSONObject: list)))
        return Fixtures.zip(entries, stored: Set(media.indices.map(String.init)))
    }

    static func image(_ name: String) -> String { "<img src=\"\(name)\">" }

    // MARK: Which files come, and how they are named

    @Test(arguments: [false, true])
    func onlyTheFilesTheCardsUseComeAlongNamedByTheirContent(current: Bool) throws {
        let file = Self.package(
            [["a", Self.image("used.png")], ["b", "text [sound:used.wav]"]],
            media: [("used.png", Self.picture), ("unused.png", Data("not referenced".utf8)), ("used.wav", Self.sound)], current: current)
        let result = try AnkiImport.read(file)
        #expect(result.notes.map(\.media) == [CardMedia(answerImage: Self.pictureName), CardMedia(answerAudio: Self.soundName)])
        #expect(result.media.names == [Self.pictureName, Self.soundName])
        #expect(result.media.contents(of: Self.pictureName) == Self.picture)
        #expect(result.media.contents(of: Self.soundName) == Self.sound)
        #expect(result.mediaSummary == AnkiImport.MediaSummary(images: 1, sounds: 1, bytes: Self.picture.count + Self.sound.count))
        #expect(result.skippedMediaRefs == 0)
    }

    @Test(arguments: [false, true])
    func aFileUsedTwiceOrUnderTwoNamesIsStoredOnce(current: Bool) throws {
        let file = Self.package(
            [["a", Self.image("one.png")], ["b", Self.image("two.png")], ["c", Self.image("one.png")]],
            media: [("one.png", Self.picture), ("two.png", Self.picture)], current: current)
        let result = try AnkiImport.read(file)
        #expect(result.media.count == 1)
        #expect(Set(result.notes.compactMap(\.media.answerImage)) == [Self.pictureName])
        #expect(result.mediaSummary == AnkiImport.MediaSummary(images: 1, sounds: 0, bytes: Self.picture.count))
        // The same bytes under another extension are another file.
        let other = Self.package([["a", Self.image("one.png")], ["b", Self.image("one.jpeg")]], media: [("one.png", Self.picture), ("one.jpeg", Self.picture)], current: current)
        #expect(try AnkiImport.read(other).media.count == 2)
    }

    @Test(arguments: [false, true])
    func aFileIsFoundByItsPercentEncodedOrDecomposedName(current: Bool) throws {
        let composed = "caf\u{E9}.png"
        let decomposed = "cafe\u{301}.png"
        // Swift compares the two as the same text; the package and the field spell them differently.
        #expect(Array(composed.unicodeScalars) != Array(decomposed.unicodeScalars))
        let file = Self.package(
            [["a", Self.image("my%20pic.png")], ["b", Self.image(decomposed)], ["c", Self.image("a&amp;b.png")]],
            media: [("my pic.png", Self.picture), (composed, Data("accent".utf8)), ("a&b.png", Data("amp".utf8))], current: current)
        let result = try AnkiImport.read(file)
        #expect(result.notes.count == 3)
        #expect(result.skippedMediaRefs == 0)
        #expect(result.media.count == 3)
        #expect(result.media.contents(of: result.notes[1].media.answerImage ?? "") == Data("accent".utf8))
    }

    @Test func aFileTheLatestListNumbersItselfIsReadFromThatNumber() throws {
        // `legacy_zip_filename`: the entry is 7, whatever its place in the list.
        let entries: [(String, Data)] = [
            ("meta", Fixtures.latestMeta),
            ("collection.anki21b", Fixtures.zstd(Fixtures.currentCollection(notes: [.init(id: 1, model: 1, fields: ["a", Self.image("x.png")])], cards: [.init(id: 10, note: 1)]))),
            ("7", Fixtures.zstd(Self.picture)),
            ("media", Fixtures.zstd(Fixtures.bytesField(1, Fixtures.stringField(1, "x.png") + Fixtures.varintField(255, 7)))),
        ]
        let result = try AnkiImport.read(Fixtures.zip(entries, stored: Set(entries.map(\.0))))
        #expect(result.notes.first?.media.answerImage == Self.pictureName)
    }

    // MARK: What is lost

    @Test(arguments: [false, true])
    func aFileThePackageLacksIsLeftOutAndSaidSo(current: Bool) throws {
        let file = Self.package(
            [["a", "text " + Self.image("lost.png")], ["b", Self.image("lost.png")], ["c", Self.image("here.png")], ["d", "[sound:lost.wav]"]],
            media: [("here.png", Self.picture)], current: current)
        let result = try AnkiImport.read(file)
        // The card with only a lost file is left out, and so is the one with only a lost sound.
        #expect(result.notes.map(\.front) == ["a", "c"])
        #expect(result.notes.map(\.media.answerImage) == [nil, Self.pictureName])
        #expect(result.skippedEmpty == 2)
        #expect(result.skippedMediaOnly == 2)
        #expect(result.skippedMediaRefs == 3)
    }

    @Test(arguments: [false, true])
    func aSideKeepsTheFirstImageAndTheFirstSoundOnly(current: Bool) throws {
        let file = Self.package(
            [["a", "x \(Self.image("one.png")) \(Self.image("two.png")) \(Self.image("one.png")) [sound:one.wav][sound:two.wav]"]],
            media: [("one.png", Self.picture), ("two.png", Data("second".utf8)), ("one.wav", Self.sound), ("two.wav", Data("second sound".utf8))], current: current)
        let result = try AnkiImport.read(file)
        #expect(result.notes[0].media == CardMedia(answerImage: Self.pictureName, answerAudio: Self.soundName))
        #expect(result.media.count == 2)
        #expect(result.skippedMediaRefs == 1)
    }

    @Test(arguments: [false, true])
    func aDamagedMediaListLeavesTheTextAndNoMedia(current: Bool) throws {
        let file = Self.package([["a", "text " + Self.image("x.png")], ["b", Self.image("x.png")]], media: [("x.png", Self.picture)], current: current, damagedList: true)
        let result = try AnkiImport.read(file)
        #expect(result.notes.map(\.front) == ["a"])
        #expect(result.media.isEmpty)
        #expect(result.skippedMediaOnly == 1)
    }

    @Test func aFileThatCannotBeUnpackedIsLeftOutLikeALostOne() throws {
        // The Latest layout compresses each file; one entry is no zstd frame.
        let notes = [Fixtures.RawNote(id: 1, model: 1, fields: ["a", Self.image("bad.png")]), .init(id: 2, model: 1, fields: ["b", "text " + Self.image("bad.png")])]
        let entries: [(String, Data)] = [
            ("meta", Fixtures.latestMeta),
            ("collection.anki21b", Fixtures.zstd(Fixtures.currentCollection(notes: notes, cards: notes.map { .init(id: $0.id * 10, note: $0.id) }))),
            ("0", Data("not a frame".utf8)),
            ("media", Fixtures.zstd(Fixtures.bytesField(1, Fixtures.stringField(1, "bad.png")))),
        ]
        let result = try AnkiImport.read(Fixtures.zip(entries, stored: Set(entries.map(\.0))))
        #expect(result.notes.map(\.front) == ["b"])
        #expect(result.notes[0].media.isEmpty)
        #expect(result.skippedMediaOnly == 1)
        #expect(result.media.isEmpty)
    }

    @Test func theTemporaryFolderLivesAsLongAsTheMediaDo() throws {
        let file = Self.package([["a", Self.image("x.png")]], media: [("x.png", Self.picture)], current: false)
        var folder: URL?
        do {
            var result: AnkiImport? = try AnkiImport.read(file)
            let wrapper = try #require(result?.media.files[Self.pictureName]?.wrapper as? MediaFileWrapper)
            folder = wrapper.source.deletingLastPathComponent()
            #expect(FileManager.default.fileExists(atPath: wrapper.source.path))
            // The media alone keep it, as a deck does that took them in.
            let media = try #require(result?.media)
            result = nil
            #expect(FileManager.default.fileExists(atPath: try #require(folder).path))
            #expect(media.contents(of: Self.pictureName) == Self.picture)
        }
        #expect(!FileManager.default.fileExists(atPath: try #require(folder).path))
    }

    // MARK: References in HTML

    @Test func readsEveryWayAReferenceIsWritten() {
        typealias Reference = AnkiText.MediaReference
        #expect(AnkiText.mediaReferences(in: "<img src=\"a.png\">") == [Reference(kind: .image, name: "a.png")])
        #expect(AnkiText.mediaReferences(in: "<IMG class='x' SRC='b c.png' />") == [Reference(kind: .image, name: "b c.png")])
        #expect(AnkiText.mediaReferences(in: "<img alt=x src=d.png>") == [Reference(kind: .image, name: "d.png")])
        #expect(AnkiText.mediaReferences(in: "<img src=\"a&amp;b.png\">") == [Reference(kind: .image, name: "a&b.png")])
        #expect(
            AnkiText.mediaReferences(in: "[sound:s.mp3] text <img src=\"i.png\"><div>[sound:t.mp3]</div>") == [
                Reference(kind: .sound, name: "s.mp3"), Reference(kind: .image, name: "i.png"), Reference(kind: .sound, name: "t.mp3"),
            ])
        // Neither an image without a source nor a plain tag that begins with img refers to anything.
        #expect(AnkiText.mediaReferences(in: "<img>").isEmpty)
        #expect(AnkiText.mediaReferences(in: "<imgx src=\"a.png\"> [sound x]").isEmpty)
    }

    // MARK: A package made by Anki

    private static func package(_ name: String) throws -> AnkiImport {
        let url = try #require(Bundle.module.url(forResource: "Resources/Anki/\(name)", withExtension: "apkg"))
        return try AnkiImport.read(url)
    }

    /// `Resources/Anki/make_anki_fixtures.py`: the vocabulary note type of a shared deck with an image,
    /// two sounds and a frequency; a note type that asks with its audio; Basic notes with an image on
    /// either side, a file name with a space, a file the package lacks and several files on one side.
    @Test(arguments: ["media-files-latest", "media-files-legacy2"])
    func readsAPackageWithMediaMadeByAnki(name: String) throws {
        let result = try Self.package(name)
        let notes = result.notes
        #expect(
            notes.map { [$0.front, $0.back] } == [
                // The meaning, then the example; the frequency, named and numbered so, is no part of the back.
                ["παίρνω", "get\nΠαίρνω τον καφέ μου στις οκτώ.\nI get my coffee at eight."],
                ["χρόνος", "time"],
                ["", "ακούω"],
                ["", "picture"],
                ["εικόνα", ""],
                ["με κενό", ""],
                ["δύο", "two"],
            ])
        #expect(result.deckNames == ["Files"])
        #expect(result.skippedEmpty == 1)
        #expect(result.skippedMediaOnly == 1)
        // The file that is lost, and the second image and the second sound of "δύο".
        #expect(result.skippedMediaRefs == 2)

        let red = try #require(notes[0].media.questionImage)
        let word = try #require(notes[2].media.questionAudio)
        let example = try #require(notes[0].media.answerAudio)
        #expect(
            notes.map(\.media) == [
                // The audio field of the vocabulary type is no field of its question.
                CardMedia(questionImage: red, answerAudio: example),
                CardMedia(questionImage: red),
                CardMedia(questionAudio: word),
                CardMedia(questionImage: red),
                CardMedia(answerImage: try #require(notes[4].media.answerImage)),
                CardMedia(answerImage: try #require(notes[5].media.answerImage)),
                CardMedia(answerImage: red, answerAudio: word),
            ])
        // "copy.png" is the bytes of "pic.png": one file. "pic2.png" and "my pic.png" are others.
        #expect(Set([red, notes[4].media.answerImage, notes[5].media.answerImage].compactMap { $0 }).count == 3)
        #expect(result.media.count == 5)
        #expect(result.mediaSummary.images == 3)
        #expect(result.mediaSummary.sounds == 2)

        for file in result.media.names {
            let data = try #require(result.media.contents(of: file))
            let ext = (file as NSString).pathExtension
            #expect(file == DeckMedia.name(for: data, fileExtension: ext))
            #expect(ext == "png" ? data.starts(with: [0x89, 0x50, 0x4E, 0x47]) : data.starts(with: Data("RIFF".utf8)))
        }
        #expect(result.mediaSummary.bytes == result.media.names.reduce(0) { $0 + (result.media.contents(of: $1)?.count ?? 0) })
    }

    /// The cards of the package: a side with media only has an empty text, two such cards are not
    /// duplicates of each other, and the deck takes the files with the cards, in one change.
    @Test func theCardsOfAPackageBringTheirFilesIntoADeck() throws {
        let result = try Self.package("media-files-latest")
        let date = Date(timeIntervalSince1970: 1_791_216_000)
        let cards = result.cards(learningOptions: LearningOptions(), calendar: .testing, created: date)
        #expect(cards.count == 7)
        #expect(cards[2].question.isEmpty && cards[2].questionAudio != nil && cards[2].answer == "ακούω")
        #expect(cards[4].answer.isEmpty && cards[4].answerImage != nil)

        // Cards 2 and 3 have an empty question each, of an audio and of an image: different questions.
        let candidates = CardImporter.candidates(of: cards, existing: [])
        #expect(candidates.allSatisfy { $0.duplicate == nil })
        // The same audio as the question of another card is the same question.
        var twin = cards[2]
        twin = Card(question: "", answer: "other", media: twin.media, created: date, learningState: nil)
        #expect(CardImporter.candidates(of: [twin], existing: [cards[2]]).first?.duplicate == .inDeck)

        var deck = Deck()
        let change = try #require(DeckChange.importing(cards, into: deck, media: result.media))
        let undo = deck.apply(change, at: date, calendar: .testing)
        #expect(deck.media.names == result.media.names)
        #expect(deck.namedMedia == result.media.names)

        // Saved and read again: every file is in the package, and the cards name them.
        let wrapper = try DeckFile.fileWrapper(for: deck)
        let files = wrapper.fileWrappers?[DeckMedia.folderName]?.fileWrappers ?? [:]
        #expect(Set(files.keys) == result.media.names)
        let read = try DeckFile.decode(wrapper)
        #expect(read.cards.map(\.media) == cards.map(\.media))
        #expect(read.media.contents(of: cards[0].questionImage ?? "") == result.media.contents(of: cards[0].questionImage ?? ""))

        // One undo takes the cards and the files out.
        _ = deck.apply(undo, at: date, calendar: .testing)
        #expect(deck.cards.isEmpty && deck.media.isEmpty)
    }

    /// Importing again takes the files it has already only once, and a card a deck holds is not added.
    @Test func importingTwiceAddsNoFileAndNoCardTwice() throws {
        let result = try Self.package("media-files-legacy2")
        let date = Date(timeIntervalSince1970: 1_791_216_000)
        var deck = Deck()
        let cards = result.cards(learningOptions: LearningOptions(), calendar: .testing, created: date)
        _ = deck.apply(try #require(DeckChange.importing(cards, into: deck, media: result.media)), at: date, calendar: .testing)
        let again = result.cards(learningOptions: LearningOptions(), calendar: .testing, created: date)
        let change = try #require(DeckChange.importing(again, into: deck, media: result.media))
        #expect(change.addedMedia.count == result.media.count)
        _ = deck.apply(change, at: date, calendar: .testing)
        #expect(deck.cards.count == 14)
        #expect(deck.media.count == result.media.count)
    }

    // MARK: The back of a card

    private func read(types: [Fixtures.RawNoteType], notes: [Fixtures.RawNote], current: Bool) throws -> AnkiImport {
        let cards = notes.map { Fixtures.RawCard(id: $0.id * 10, note: $0.id) }
        let collection =
            current
            ? Fixtures.currentCollection(noteTypes: types, notes: notes, cards: cards)
            : Fixtures.legacyCollection(noteTypes: types, notes: notes, cards: cards)
        return try AnkiImport.read(Fixtures.zip([("collection.anki2", collection)]))
    }

    /// The back is the first field the answer adds that has text, then every other such field on a
    /// line of its own, in the order of the template; a frequency, a rank, an id and a number are no words.
    @Test(arguments: [false, true])
    func theBackTakesEveryTextFieldTheAnswerAddsInTheOrderOfTheTemplate(current: Bool) throws {
        let types = [
            Fixtures.RawNoteType(
                id: 1, name: "Vocabulary", fields: ["Front", "Back", "Examples", "Frequency"], templates: ["{{Front}}"],
                answers: ["{{FrontSide}}<hr>{{Back}}{{{Examples}}{{{Frequency}}"]),
            // Fields out of the order of the note type, one the answer lacks, one of ids and ranks.
            Fixtures.RawNoteType(
                id: 2, name: "Ordered", fields: ["Word", "Notes", "Meaning", "Item ID", "Word Rank", "Hidden", "Sentence", "Year"], templates: ["{{Word}}"],
                answers: ["{{FrontSide}}{{Meaning}}{{Sentence}}{{Item ID}}{{Word Rank}}{{Hidden}}{{Year}}"]),
            // Without a template that names fields there is one field, as before.
            Fixtures.RawNoteType(id: 3, name: "Unreadable", fields: ["A", "B", "C"], templates: ["{{FrontSide}}"], answers: ["no fields"]),
        ]
        let notes = [
            Fixtures.RawNote(id: 1, model: 1, fields: ["παίρνω", "get", "<div>Παίρνω καφέ.</div><div>I get coffee.</div>", "<b>1243</b>"]),
            Fixtures.RawNote(id: 2, model: 2, fields: ["σπίτι", "not on the answer", "house", "17", "3", "hidden text", "Το σπίτι μου.", "2024"]),
            Fixtures.RawNote(id: 3, model: 3, fields: ["x", "y", "z"]),
            // Only the field named for a frequency has text: the back is that, as it was, rather than empty.
            Fixtures.RawNote(id: 4, model: 1, fields: ["only", "", "", "Frequency text"]),
            // The second field of text is a number: it stays out.
            Fixtures.RawNote(id: 5, model: 1, fields: ["third", "meaning", "2024", ""]),
        ]
        let result = try read(types: types, notes: notes, current: current)
        #expect(
            result.notes.map { [$0.front, $0.back] } == [
                ["παίρνω", "get\nΠαίρνω καφέ.\nI get coffee."],
                // "Item ID", "Word Rank" and "Hidden" (it contains "id") stay out, "Year" has no letter.
                ["σπίτι", "house\nΤο σπίτι μου."],
                ["x", "y"],
                ["only", "Frequency text"],
                ["third", "meaning"],
            ])
    }

    @Test func aFieldIsExtraByItsNameOrByHavingNoLetter() {
        #expect(AnkiCollection.isExtra(fieldNamed: "FrequencyBlock", text: "common"))
        #expect(AnkiCollection.isExtra(fieldNamed: "Word rank", text: "common"))
        #expect(AnkiCollection.isExtra(fieldNamed: "Note ID", text: "common"))
        #expect(AnkiCollection.isExtra(fieldNamed: "Examples", text: "1243"))
        #expect(AnkiCollection.isExtra(fieldNamed: "Examples", text: "…"))
        #expect(!AnkiCollection.isExtra(fieldNamed: "Examples", text: "Παίρνω καφέ."))
        #expect(!AnkiCollection.isExtra(fieldNamed: "Audio", text: "word 2"))
    }
}
