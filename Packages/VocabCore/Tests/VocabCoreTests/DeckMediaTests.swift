import Foundation
import Testing

@testable import VocabCore

/// The media of a deck: the files in the package, the names on the cards, and what a save, an undo
/// and a merge do with them.
struct DeckMediaTests {
    let date = Date(timeIntervalSince1970: 1_791_216_000)
    let picture = Data([0x89, 0x50, 0x4E, 0x47, 0x01])
    let sound = Data("sound of a word".utf8)
    let other = Data("another picture".utf8)

    /// A deck of two cards: the first has a picture and a sound on the question and a sound on the
    /// answer (the same file as on the question), the second the same picture on its answer.
    func deckWithMedia() throws -> (deck: Deck, picture: String, sound: String) {
        var media = DeckMedia()
        let pictureName = media.add(picture, fileExtension: "PNG")
        let soundName = media.add(sound, fileExtension: ".mp3")
        var first = Card(question: "γάτα", answer: "cat", created: date)
        first.media = CardMedia(questionImage: pictureName, questionAudio: soundName, answerAudio: soundName)
        var second = Card(question: "σπίτι", answer: "house", created: date)
        second.media = CardMedia(answerImage: pictureName)
        return (try Deck(cards: [first, second], media: media), pictureName, soundName)
    }

    /// A temporary directory for the length of `body`.
    func inTemporaryDirectory<T>(_ body: (URL) throws -> T) throws -> T {
        let url = FileManager.default.temporaryDirectory.appending(path: "DeckMediaTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url) }
        return try body(url)
    }

    func mediaFiles(of wrapper: FileWrapper) -> [String: Data] {
        (wrapper.fileWrappers?[DeckMedia.folderName]?.fileWrappers ?? [:]).compactMapValues(\.regularFileContents)
    }

    func listing(of package: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: package.appending(path: DeckMedia.folderName).path).sorted()
    }

    // MARK: Names

    @Test func aFileIsNamedByTheFirstSixteenHexCharactersOfItsHash() {
        // SHA-256 of "abc" begins ba7816bf8f01cfea414140de5dae2223.
        let abc = Data("abc".utf8)
        #expect(DeckMedia.name(for: abc, fileExtension: "mp3") == "ba7816bf8f01cfea.mp3")
        #expect(DeckMedia.name(for: abc, fileExtension: ".MP3") == "ba7816bf8f01cfea.mp3")
        #expect(DeckMedia.name(for: abc, fileExtension: "") == "ba7816bf8f01cfea")
        // An extension that is no extension is left out.
        #expect(DeckMedia.name(for: abc, fileExtension: "a/b") == "ba7816bf8f01cfea")
        #expect(DeckMedia.name(for: abc, fileExtension: "toolongext") == "ba7816bf8f01cfea")
    }

    @Test func onlyNamesOfThatFormAreNames() {
        #expect(DeckMedia.isValidName("ba7816bf8f01cfea.mp3"))
        #expect(DeckMedia.isValidName("ba7816bf8f01cfea"))
        for bad in ["", "../ba7816bf8f01cfea.mp3", "ba7816bf8f01cfe.mp3", "BA7816BF8F01CFEA.mp3", "ba7816bf8f01cfea.", "ba7816bf8f01cfea.mp3/x", "ba7816bf8f01cfea.MP3", "xx7816bf8f01cfea.mp3", "ba7816bf8f01cfea.mp3.mp3"] {
            #expect(!DeckMedia.isValidName(bad), "\(bad)")
        }
    }

    @Test func identicalMediaAreStoredOnce() throws {
        var media = DeckMedia()
        let first = media.add(picture, fileExtension: "png")
        let second = media.add(picture, fileExtension: "PNG")
        #expect(first == second)
        #expect(media.count == 1)
        // The same bytes under another extension are another file.
        #expect(media.add(picture, fileExtension: "jpg") != first)
        #expect(media.count == 2)
        #expect(media.contents(of: first) == picture)
    }

    // MARK: The package

    @Test func aDeckWithMediaRoundTripsThroughThePackage() throws {
        let (deck, pictureName, soundName) = try deckWithMedia()
        let wrapper = try DeckFile.fileWrapper(for: deck)
        // Three uses, two files.
        #expect(mediaFiles(of: wrapper) == [pictureName: picture, soundName: sound])
        #expect(Set(wrapper.fileWrappers!.keys) == [DeckFile.deckFileName, DeckFile.reviewsFileName, DeckMedia.folderName])

        let read = try DeckFile.decode(wrapper)
        #expect(read == deck)
        #expect(read.cards[0].media == CardMedia(questionImage: pictureName, questionAudio: soundName, answerAudio: soundName))
        #expect(read.cards[1].media == CardMedia(answerImage: pictureName))
        #expect(read.media.contents(of: pictureName) == picture)
        #expect(read.media.contents(of: soundName) == sound)

        let json = String(decoding: wrapper.fileWrappers![DeckFile.deckFileName]!.regularFileContents!, as: UTF8.self)
        for key in ["questionImage", "questionAudio", "answerImage", "answerAudio"] {
            #expect(json.contains("\"\(key)\" : \"\(key.hasSuffix("Image") ? pictureName : soundName)\""), "\(key)")
        }
    }

    @Test func aDeckWithoutMediaWritesNeitherKeysNorFolder() throws {
        var deck = Deck()
        _ = deck.apply(DeckChange(upserts: [Card(question: "a", answer: "b", created: date)]), at: date, calendar: .testing)
        let wrapper = try DeckFile.fileWrapper(for: deck)
        #expect(Set(wrapper.fileWrappers!.keys) == [DeckFile.deckFileName, DeckFile.reviewsFileName])
        let json = String(decoding: wrapper.fileWrappers![DeckFile.deckFileName]!.regularFileContents!, as: UTF8.self)
        #expect(!json.contains("Image") && !json.contains("Audio"))
    }

    @Test func versionSevenIsWrittenAndThePreviousOnesAreStillRead() throws {
        let (deck, _, _) = try deckWithMedia()
        let json = String(decoding: try DeckFile.encodeDeck(deck), as: UTF8.self)
        #expect(DeckFile.currentVersion == 7)
        #expect(json.contains("\"version\" : 7"))

        func deckJSON(version: Int) -> Data {
            Data(
                """
                {"format": "de.fluch-it-consulting.voctrain.deck", "version": \(version), "progress": [], "learningOptions": {},
                 "cards": [{"id": "6F9619FF-8B86-D011-B42D-00C04FC964FF", "question": "dom", "answer": "Haus"}]}
                """.utf8)
        }
        for version in [3, 4, 5, 6, 7] {
            let old = try DeckFile.decode(deckJSON(version: version))
            #expect(old.cards[0].media.isEmpty)
            #expect(old.media.isEmpty)
            #expect(old.retiredCards.isEmpty)
        }
        #expect(throws: DeckFile.Error.unsupportedVersion(8)) { try DeckFile.decode(deckJSON(version: 8)) }
        // A package of version 4 reads, and is written as 7.
        let package = try DeckFile.fileWrapper(for: Deck())
        package.removeFileWrapper(package.fileWrappers![DeckFile.deckFileName]!)
        package.addRegularFile(withContents: deckJSON(version: 4), preferredFilename: DeckFile.deckFileName)
        let read = try DeckFile.decode(package)
        #expect(String(decoding: try DeckFile.encodeDeck(read), as: UTF8.self).contains("\"version\" : 7"))
    }

    @Test func aNameThatIsNoFileNameReadsAsNone() throws {
        let data = Data(
            """
            {"format": "de.fluch-it-consulting.voctrain.deck", "version": 5, "progress": [], "learningOptions": {},
             "cards": [{"id": "6F9619FF-8B86-D011-B42D-00C04FC964FF", "question": "dom", "answer": "Haus",
                        "questionImage": "../../etc/passwd", "answerAudio": "ba7816bf8f01cfea.mp3"}]}
            """.utf8)
        let deck = try DeckFile.decode(data)
        #expect(deck.cards[0].media == CardMedia(answerAudio: "ba7816bf8f01cfea.mp3"))
    }

    @Test func aMissingFileLeavesItsNameOnTheCard() throws {
        // The package of a deck whose file has not come from iCloud Drive yet.
        let (deck, pictureName, soundName) = try deckWithMedia()
        let package = try DeckFile.fileWrapper(for: deck)
        let folder = package.fileWrappers![DeckMedia.folderName]!
        folder.removeFileWrapper(folder.fileWrappers![soundName]!)

        let read = try DeckFile.decode(package)
        #expect(read.cards[0].questionAudio == soundName)
        #expect(read.media.names == [pictureName])
        // Saving it does not fail, and keeps the name.
        let saved = try DeckFile.decode(DeckFile.fileWrapper(for: read))
        #expect(saved.cards[0].questionAudio == soundName)
        #expect(saved.media.names == [pictureName])
    }

    @Test func decodingWithoutMediaHoldsNoFile() throws {
        let (deck, _, _) = try deckWithMedia()
        let read = try DeckFile.decode(DeckFile.fileWrapper(for: deck), withMedia: false)
        #expect(read.media.isEmpty)
        #expect(read.cards[0].media == deck.cards[0].media)
    }

    // MARK: Saving

    /// A package on disk with the media of `deckWithMedia()` and one file no card names.
    func writePackage(_ deck: Deck, orphan: String? = nil, to directory: URL) throws -> URL {
        let url = directory.appending(path: "Deck.mnemit", directoryHint: .isDirectory)
        try DeckFile.fileWrapper(for: deck).write(to: url, options: .atomic, originalContentsURL: nil)
        if let orphan {
            try Data("orphan".utf8).write(to: url.appending(path: DeckMedia.folderName).appending(path: orphan))
        }
        return url
    }

    @Test func savingKeepsTheFilesCardsNameAndDropsTheOrphans() throws {
        let (deck, pictureName, soundName) = try deckWithMedia()
        try inTemporaryDirectory { directory in
            let orphan = "0000000000000001.jpg"
            let url = try writePackage(deck, orphan: orphan, to: directory)
            #expect(try listing(of: url) == [orphan, pictureName, soundName].sorted())

            // Read the package: the orphan is not part of the deck, so it is not written back.
            let read = try DeckFile.read(at: url)
            #expect(read.media.names == [pictureName, soundName])
            let next = directory.appending(path: "Saved.mnemit", directoryHint: .isDirectory)
            try DeckFile.fileWrapper(for: read, original: url).write(to: next, options: .atomic, originalContentsURL: url)
            #expect(try listing(of: next) == [pictureName, soundName].sorted())
            #expect(try Data(contentsOf: next.appending(path: "media").appending(path: soundName)) == sound)
            #expect(try DeckFile.read(at: next) == deck)
        }
    }

    @Test func aFileOfADeletedCardStaysForTheUndoAndGoesAtTheNextOpening() throws {
        let (deck, pictureName, soundName) = try deckWithMedia()
        var edited = deck
        let first = deck.cards[0].id
        // The first card is the only one that names the sound.
        let deletion = try #require(DeckChange.removing([first], from: edited))
        let undo = edited.apply(deletion, at: date, calendar: .testing)
        #expect(edited.cards.count == 1)
        #expect(!edited.namedMedia.contains(soundName))
        #expect(mediaFiles(of: try DeckFile.fileWrapper(for: edited)).keys.sorted() == [pictureName, soundName].sorted())

        // Undoing the deletion finds the file where it was.
        _ = edited.apply(undo, at: date, calendar: .testing)
        #expect(edited.card(withID: first)?.questionAudio == soundName)
        #expect(mediaFiles(of: try DeckFile.fileWrapper(for: edited)).keys.sorted() == [pictureName, soundName].sorted())

        // Reading the package after the deletion, as a later session does, drops the file.
        _ = edited.apply(deletion, at: date, calendar: .testing)
        let reopened = try DeckFile.decode(DeckFile.fileWrapper(for: edited))
        #expect(reopened.media.names == [pictureName])
        #expect(mediaFiles(of: try DeckFile.fileWrapper(for: reopened)).keys.sorted() == [pictureName])
    }

    @Test func savingOverThePackageClonesTheFilesThatStayAndDoesNotWriteThemAgain() throws {
        let (deck, pictureName, soundName) = try deckWithMedia()
        try inTemporaryDirectory { directory in
            let url = try writePackage(deck, to: directory)
            let read = try DeckFile.read(at: url)
            let wrapper = try DeckFile.fileWrapper(for: read, original: url)
            // The files are cloned from the package they are in; nothing holds their bytes.
            let clones = wrapper.fileWrappers![DeckMedia.folderName]!.fileWrappers!.compactMapValues { $0 as? MediaFileWrapper }
            #expect(Set(clones.keys) == [pictureName, soundName])
            #expect(clones[soundName]?.source == url.appending(path: "media").appending(path: soundName))

            let next = directory.appending(path: "Next.mnemit", directoryHint: .isDirectory)
            try wrapper.write(to: next, options: .atomic, originalContentsURL: url)
            #expect(try DeckFile.read(at: next) == read)
            #expect(try Data(contentsOf: next.appending(path: "media").appending(path: pictureName)) == picture)

            // A file the original lacks comes from the deck, and a deck written for the first
            // time has no original at all.
            var fresh = DeckMedia()
            let name = fresh.add(other, fileExtension: "gif")
            #expect(DeckMedia().folderWrapper(original: url) == nil)
            let folder = try #require(fresh.folderWrapper(original: url))
            #expect(folder.fileWrappers![name]?.regularFileContents == other)
        }
    }

    @Test func theIncrementalReviewLogStillWorksWithMedia() throws {
        var (deck, _, _) = try deckWithMedia()
        let encoder = ReviewLogEncoder()
        let first = try DeckFile.fileWrapper(for: deck, reviewLog: encoder)
        #expect(mediaFiles(of: first).count == 2)

        // A review of the first card, then a save with the same encoder: only that card's lines are encoded.
        let card = deck.cards[0]
        let scheduler = Scheduler(learningOptions: deck.learningOptions, calendar: .testing)
        var random = Scheduler.random(forReviewOf: card.id, at: date)
        let reviewed = scheduler.review(card, grade: .good, at: date, mode: .revealed, duration: nil, using: &random)
        _ = deck.apply(DeckChange(upserts: [reviewed], contentStamp: .keep), at: date, calendar: .testing)
        let second = try DeckFile.fileWrapper(for: deck, reviewLog: encoder)
        #expect(encoder.lastEncodedCardCount == 1)
        #expect(mediaFiles(of: second) == mediaFiles(of: first))
        let read = try DeckFile.decode(second)
        #expect(read.cards[0].log.count == 1)
        #expect(read.cards[0].media == deck.cards[0].media)
    }

    // MARK: Editing

    @Test func editingTheMediaOfACardIsAContentChangeWithAnUndo() throws {
        var deck = try Deck(cards: [Card(question: "a", answer: "b", created: date)])
        var files = DeckMedia()
        let name = files.add(picture, fileExtension: "jpg")
        let id = deck.cards[0].id
        let change = try #require(DeckChange.settingMedia(CardMedia(questionImage: name, answerAudio: "not a name"), of: id, in: deck, adding: files))
        let undo = deck.apply(change, at: date.addingTimeInterval(60), calendar: .testing)
        #expect(deck.cards[0].media == CardMedia(questionImage: name))
        #expect(deck.cards[0].contentChanged == date.addingTimeInterval(60))
        #expect(deck.media.names == [name])

        // The same media again change nothing; so does a card the deck lacks.
        #expect(DeckChange.settingMedia(CardMedia(questionImage: name), of: id, in: deck, adding: files) == nil)
        #expect(DeckChange.settingMedia(CardMedia(), of: UUID(), in: deck) == nil)

        // Undoing takes the media off the card and the file it brought out of the deck.
        _ = deck.apply(undo, at: date.addingTimeInterval(120), calendar: .testing)
        #expect(deck.cards[0].media.isEmpty)
        #expect(deck.media.isEmpty)
        #expect(deck.cards[0].contentChanged == date.addingTimeInterval(120))
    }

    @Test func undoingAnImportTakesItsFilesOutUnlessACardStillNamesThem() throws {
        var deck = Deck()
        var files = DeckMedia()
        let name = files.add(picture, fileExtension: "jpg")
        var card = Card(question: "a", answer: "b", created: date)
        card.media = CardMedia(questionImage: name)
        var later = Card(question: "c", answer: "d", created: date)
        later.media = CardMedia(answerImage: name)

        let importing = try #require(DeckChange.importing([card], into: deck, media: files))
        let undoImport = deck.apply(importing, at: date, calendar: .testing)
        #expect(deck.media.names == [name])
        #expect(deck.cards.count == 1)

        // Undone and done again: the file comes and goes with the cards.
        let redo = deck.apply(undoImport, at: date, calendar: .testing)
        #expect(deck.cards.isEmpty && deck.media.isEmpty)
        _ = deck.apply(redo, at: date, calendar: .testing)
        #expect(deck.media.contents(of: name) == picture)

        // A card that came later names the file too: undoing the import must not take it.
        _ = deck.apply(DeckChange(upserts: [later]), at: date, calendar: .testing)
        var undoNow = DeckChange(removals: [card.id], contentStamp: .keep)
        undoNow.removedMedia = [name]
        _ = deck.apply(undoNow, at: date, calendar: .testing)
        #expect(deck.cards.map(\.id) == [later.id])
        #expect(deck.media.names == [name])
    }

    // MARK: Merging

    /// Two versions of one card that differ in their media and the files of each.
    func twoVersions() throws -> (mine: Deck, theirs: Deck, first: String, second: String) {
        var firstFiles = DeckMedia()
        let first = firstFiles.add(picture, fileExtension: "png")
        var secondFiles = DeckMedia()
        let second = secondFiles.add(other, fileExtension: "png")
        var card = Card(question: "a", answer: "b", created: date)
        card.media = CardMedia(questionImage: first)
        var edited = card
        edited.media = CardMedia(questionImage: second)
        edited.contentChanged = date.addingTimeInterval(60)
        let mine = try Deck(cards: [card], contentModified: date, media: firstFiles)
        let theirs = try Deck(cards: [edited], contentModified: date.addingTimeInterval(60), media: secondFiles)
        return (mine, theirs, first, second)
    }

    @Test func aMergeTakesTheUnionOfTheFilesAndTheMediaOfTheLaterContent() throws {
        let (mine, theirs, first, second) = try twoVersions()

        var merged = mine
        let change = try #require(DeckChange.merging(theirs, into: merged, calendar: .testing))
        let undo = merged.apply(change, at: date, calendar: .testing)
        #expect(merged.cards[0].questionImage == second)
        #expect(merged.media.names == [first, second])

        // The other way round: the later version has all there is to take, as the file of the older
        // card is named by no card of the merged deck.
        #expect(DeckChange.merging(mine, into: theirs, calendar: .testing) == nil)

        // Merged again, nothing is left to do; undoing takes the file it brought out again.
        #expect(DeckChange.merging(theirs, into: merged, calendar: .testing) == nil)
        _ = merged.apply(undo, at: date, calendar: .testing)
        #expect(merged.cards[0].questionImage == first)
        #expect(merged.media.names == [first])
    }

    @Test func aMergeBringsInTheFileOfACardOnlyTheOtherVersionHolds() throws {
        let (mine, theirs, _, second) = try twoVersions()
        var extra = Card(question: "c", answer: "d", created: date)
        extra.media = CardMedia(answerAudio: second)
        var theirsWithExtra = theirs
        _ = theirsWithExtra.apply(DeckChange(upserts: [extra]), at: date.addingTimeInterval(120), calendar: .testing)
        var merged = mine
        _ = merged.apply(try #require(DeckChange.merging(theirsWithExtra, into: merged, calendar: .testing)), at: date, calendar: .testing)
        #expect(merged.cards.count == 2)
        #expect(merged.media.contents(of: second) == other)
    }

    @Test func aFileNoCardOfTheMergedDeckNamesDoesNotComeAndChangesNothing() throws {
        let (mine, _, _, _) = try twoVersions()
        var orphans = DeckMedia()
        orphans.add(Data("nobody names me".utf8), fileExtension: "jpg")
        let theirs = try Deck(cards: mine.cards, contentModified: date, media: mine.media)
        var withOrphan = theirs
        withOrphan.media.formUnion(orphans)
        #expect(DeckChange.merging(withOrphan, into: mine, calendar: .testing) == nil)
    }

    @Test func aFileThatHasNotArrivedYetComesWithTheVersionThatHasIt() throws {
        // This version names the file but doesn't hold it; the other holds it.
        let (mine, _, first, _) = try twoVersions()
        var lacking = try Deck(cards: mine.cards, contentModified: date)
        #expect(lacking.media.isEmpty && lacking.cards[0].questionImage == first)
        _ = lacking.apply(try #require(DeckChange.merging(mine, into: lacking, calendar: .testing)), at: date, calendar: .testing)
        #expect(lacking.media.contents(of: first) == picture)
    }
}
