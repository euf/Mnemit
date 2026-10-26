import Foundation
import Testing

@testable import VocabCore

struct DeckFileTests {
    let date = Date(timeIntervalSince1970: 1_791_216_000)

    func sampleDeck() throws -> Deck {
        var learningOptions = LearningOptions()
        learningOptions.targetRecall = 0.85
        learningOptions.newCardsPerSession = 15
        learningOptions.cardsPerSession = nil
        learningOptions.newProductionPerSession = 0
        learningOptions.productionUnlockDays = 30
        learningOptions.newCardOrder = .newestFirst
        var card = Card(question: "dom", answer: "Haus / Gebäude", hint: "Substantiv", note: "dom", kind: .recognition, created: date, learningState: nil)
        card.learningState = LearningState(phase: .review, step: 0, stability: 12.5, difficulty: 4.2, lastReview: date, due: date.addingTimeInterval(86400), reviews: 3, lapses: 1)
        // One review short, like a card imported from MacVocTrain 1 with a learning state.
        card.log = [ReviewLogEntry(date: date.addingTimeInterval(-86400), grade: .again), ReviewLogEntry(date: date, grade: .hard, mode: .revealed)]
        card.learningStateReset = date.addingTimeInterval(-2 * 86400)
        card.isSuspended = true
        card.suspensionChanged = date.addingTimeInterval(-3600)
        var resumed = Card(question: "kot", answer: "Katze", created: date)
        resumed.suspensionChanged = date.addingTimeInterval(-7200)
        return try Deck(
            learningOptions: learningOptions,
            cards: [card, resumed],
            progress: [DailySnapshot(day: 20_000, bins: [1, 1])],
            contentModified: date
        )
    }

    func file(_ wrapper: FileWrapper, _ name: String) -> String {
        String(decoding: wrapper.fileWrappers![name]!.regularFileContents!, as: UTF8.self)
    }

    /// The package of `deck` with `lines` appended to its `reviews.jsonl`.
    func package(of deck: Deck, appendingReviews lines: [String]) throws -> FileWrapper {
        let wrapper = try DeckFile.fileWrapper(for: deck)
        let reviews = file(wrapper, DeckFile.reviewsFileName) + lines.map { $0 + "\n" }.joined()
        wrapper.removeFileWrapper(wrapper.fileWrappers![DeckFile.reviewsFileName]!)
        wrapper.addRegularFile(withContents: Data(reviews.utf8), preferredFilename: DeckFile.reviewsFileName)
        return wrapper
    }

    func reviewLine(of id: Card.ID) -> String {
        "{\"card\":\"\(id.uuidString)\",\"date\":1791216000,\"grade\":3}"
    }

    /// A `deck.json` with one card whose learning state has the given values.
    func deckJSON(step: Int = 0, stability: Double = 12.5, difficulty: Double = 5, reviews: Int = 1, lapses: Int = 0, parameters: [Double] = FSRSParameters.default.weights) -> Data {
        let learningState = """
            {"phase": "review", "step": \(step), "stability": \(stability), "difficulty": \(difficulty),
             "lastReview": "2026-10-05T16:00:00Z", "due": "2026-10-06T02:00:00Z", "reviews": \(reviews), "lapses": \(lapses)}
            """
        let json = """
            {"format": "de.fluch-it-consulting.voctrain.deck", "version": 3, "progress": [], "learningOptions": {"parameters": \(parameters)},
             "cards": [{"id": "6F9619FF-8B86-D011-B42D-00C04FC964FF", "question": "dom", "answer": "Haus", "learningState": \(learningState)}]}
            """
        return Data(json.utf8)
    }

    @Test func packageRoundTripPreservesEverything() throws {
        let deck = try sampleDeck()
        #expect(try DeckFile.decode(DeckFile.fileWrapper(for: deck)) == deck)
    }

    /// What merges between devices that both edit cards need: the stamp of a card's last
    /// edit, that of the learning options and the deleted cards. They come without a new
    /// version, so a deck without them writes none of their keys.
    @Test func editStampsAndDeletionsRoundTripAndAreLeftOutWhenEmpty() throws {
        var card = Card(question: "dom", answer: "Haus", created: date)
        card.contentChanged = date.addingTimeInterval(60)
        let deleted = [UUID(), UUID()]
        let deck = try Deck(
            cards: [card], contentModified: date,
            learningOptionsChanged: date.addingTimeInterval(120),
            deletedCards: [deleted[0]: date.addingTimeInterval(180), deleted[1]: date.addingTimeInterval(240), card.id: date]
        )
        // A deleted card that is in the deck is no longer deleted.
        #expect(deck.deletedCards.keys.sorted { $0.uuidString < $1.uuidString } == deleted.sorted { $0.uuidString < $1.uuidString })

        let wrapper = try DeckFile.fileWrapper(for: deck)
        let read = try DeckFile.decode(wrapper)
        #expect(read == deck)
        #expect(read.cards[0].contentChanged == date.addingTimeInterval(60))
        #expect(read.learningOptionsChanged == date.addingTimeInterval(120))
        #expect(read.deletedCards == deck.deletedCards)
        // The same bytes every time, whatever the order of the dictionary.
        #expect(try DeckFile.encodeDeck(read) == DeckFile.encodeDeck(deck))

        let plain = String(decoding: try DeckFile.encodeDeck(sampleDeck()), as: UTF8.self)
        #expect(!plain.contains("deletedCards") && !plain.contains("learningOptionsChanged") && !plain.contains("contentChanged"))
    }

    /// A `deck.json` of the current version as the app writes it, with every kind of value.
    @Test func fixedDeckReadsAndWritesBackUnchanged() throws {
        let url = try #require(Bundle.module.url(forResource: "Resources/deck-v5", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let deck = try DeckFile.decode(data)
        expectFixedDeck(deck)
        #expect(deck.contentModified == date)
        #expect(deck.cards[1].learningStateReset == date.addingTimeInterval(-22 * 3600))
        #expect(deck.cards[0].isSuspended)
        #expect(deck.cards[0].suspensionChanged == date.addingTimeInterval(3600))
        #expect(!deck.cards[1].isSuspended)
        #expect(deck.cards[1].suspensionChanged == date.addingTimeInterval(-4 * 3600))
        #expect(!deck.cards[2].isSuspended)
        #expect(deck.cards[2].suspensionChanged == nil)
        #expect(deck.cards[2].note == "kot")
        #expect(deck.cards[2].kind == .production)
        #expect(deck.cards[0].note == nil)
        #expect(deck.cards[0].kind == nil)
        #expect(deck.learningOptions.newProductionPerSession == nil)
        #expect(deck.learningOptions.productionUnlockDays == 14)
        #expect(deck.learningOptions.newCardOrder == .newestFirst)
        #expect(!deck.learningOptions.optimizeFromRevealed)
        #expect(deck.learningOptions.leechThreshold == 6)

        #expect(deck.cards[0].media == CardMedia(questionImage: "e3b0c44298fc1c14.png", questionAudio: "ba7816bf8f01cfea.mp3", answerAudio: "ba7816bf8f01cfea.mp3"))
        #expect(deck.cards[1].media == CardMedia(answerImage: "e3b0c44298fc1c14.png"))
        #expect(deck.cards[2].media.isEmpty)

        // The fixture still has the option `revealedRecallWeight` of ADR 0005, which the app no longer writes.
        #expect(String(decoding: try DeckFile.encodeDeck(deck), as: UTF8.self) == withoutRevealedRecallWeight(data))
    }

    /// A deck written while the option `revealedRecallWeight` existed reads, and its next save leaves the key out.
    func withoutRevealedRecallWeight(_ data: Data) -> String {
        String(decoding: data, as: UTF8.self).replacingOccurrences(of: "    \"revealedRecallWeight\" : 0.5,\n", with: "")
    }

    /// Version 4 has no media; it is written back as version 5 and is otherwise the same.
    @Test func fixedDeckOfVersion4IsRead() throws {
        let url = try #require(Bundle.module.url(forResource: "Resources/deck-v4", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let deck = try DeckFile.decode(data)
        expectFixedDeck(deck)
        #expect(deck.cards.allSatisfy { $0.media.isEmpty })
        #expect(deck.media.isEmpty)
        let written = withoutRevealedRecallWeight(data).replacingOccurrences(of: "\"version\" : 4", with: "\"version\" : \(DeckFile.currentVersion)")
        #expect(String(decoding: try DeckFile.encodeDeck(deck), as: UTF8.self) == written)
    }

    /// The options for revealed reviews (ADR 0005) are new: an older deck lacks them and
    /// reads with the defaults of the fork.
    @Test func revealedReviewAndLeechOptionsRoundTripAndDefault() throws {
        var deck = try sampleDeck()
        #expect(deck.learningOptions.optimizeFromRevealed)
        #expect(deck.learningOptions.leechThreshold == 8)
        var options = deck.learningOptions
        options.optimizeFromRevealed = false
        options.leechThreshold = 0
        _ = deck.apply(try #require(DeckChange.changingLearningOptions(options, in: deck, calendar: .testing)), day: 100)
        let read = try DeckFile.decode(DeckFile.fileWrapper(for: deck))
        #expect(!read.learningOptions.optimizeFromRevealed)
        #expect(read.learningOptions.leechThreshold == 0)

        let old = try DeckFile.decode(deckJSON()).learningOptions
        #expect(old.optimizeFromRevealed)
        #expect(old.leechThreshold == 8)
    }

    /// The option `revealedRecallWeight` (ADR 0004, ADR 0005) is gone: a deck with it, whatever the value, reads with
    /// the other options as they are, and saving leaves the key out.
    @Test func theRevealedRecallWeightOfOlderDecksIsIgnored() throws {
        for stored in ["0.05", "0.33", "1", "7", "\"nonsense\""] {
            let older = Data(
                """
                {"format": "de.fluch-it-consulting.voctrain.deck", "version": 4, "progress": [],
                 "learningOptions": {"revealedRecallWeight": \(stored), "optimizeFromRevealed": false, "leechThreshold": 5}, "cards": []}
                """.utf8)
            let deck = try DeckFile.decode(older)
            #expect(!deck.learningOptions.optimizeFromRevealed)
            #expect(deck.learningOptions.leechThreshold == 5)
            #expect(!String(decoding: try DeckFile.encodeDeck(deck), as: UTF8.self).contains("revealedRecallWeight"))
        }
    }

    /// The automatic refit of the parameters (`ParameterRefit`) keeps its switch and the note of
    /// the last fit in the options: both are left out of the file while they hold the default,
    /// and an older deck lacks them.
    @Test func automaticFitOptionsRoundTripAndAreLeftOutAtTheirDefaults() throws {
        var deck = try sampleDeck()
        #expect(deck.learningOptions.updatesParametersAutomatically)
        #expect(deck.learningOptions.lastAutoFit == nil)
        let plain = String(decoding: try DeckFile.encodeDeck(deck), as: UTF8.self)
        #expect(!plain.contains("updatesParametersAutomatically"))
        #expect(!plain.contains("lastAutoFit"))

        var options = deck.learningOptions
        options.updatesParametersAutomatically = false
        options.lastAutoFit = LearningOptions.AutoFit(date: date, reviewCount: 2314, adopted: false)
        _ = deck.apply(try #require(DeckChange.changingLearningOptions(options, in: deck, calendar: .testing)), at: date, calendar: .testing)
        let read = try DeckFile.decode(DeckFile.fileWrapper(for: deck))
        #expect(!read.learningOptions.updatesParametersAutomatically)
        #expect(read.learningOptions.lastAutoFit == LearningOptions.AutoFit(date: date, reviewCount: 2314, adopted: false))
        #expect(read == deck)
        #expect(String(decoding: try DeckFile.encodeDeck(deck), as: UTF8.self).contains("\"lastAutoFit\""))

        options.updatesParametersAutomatically = true
        options.lastAutoFit = LearningOptions.AutoFit(date: date, reviewCount: 4000, adopted: true)
        _ = deck.apply(try #require(DeckChange.changingLearningOptions(options, in: deck, calendar: .testing)), at: date, calendar: .testing)
        #expect(try DeckFile.decode(DeckFile.fileWrapper(for: deck)).learningOptions == options)

        // A file from before: the switch is on, nothing was fitted.
        let old = try DeckFile.decode(deckJSON()).learningOptions
        #expect(old.updatesParametersAutomatically)
        #expect(old.lastAutoFit == nil)

        // A damaged note of a fit costs one more fit, not the deck.
        let damaged = Data(
            """
            {"format": "de.fluch-it-consulting.voctrain.deck", "version": 4, "progress": [],
             "learningOptions": {"lastAutoFit": {"date": "yesterday"}}, "cards": []}
            """.utf8)
        #expect(try DeckFile.decode(damaged).learningOptions.lastAutoFit == nil)
    }

    /// A paused deck (`LearningOptions.isPaused`) is written with the key `paused` and no other deck
    /// is: the key is left out while the deck is not paused, and a file without it reads as not paused,
    /// which is also what an older app version leaves behind when it saves a paused deck.
    @Test func thePausedKeyRoundTripsAndIsLeftOutWhileTheDeckIsNotPaused() throws {
        var deck = try sampleDeck()
        #expect(!deck.learningOptions.isPaused)
        #expect(!String(decoding: try DeckFile.encodeDeck(deck), as: UTF8.self).contains("\"paused\""))

        var options = deck.learningOptions
        options.isPaused = true
        _ = deck.apply(try #require(DeckChange.changingLearningOptions(options, in: deck, calendar: .testing)), at: date, calendar: .testing)
        #expect(String(decoding: try DeckFile.encodeDeck(deck), as: UTF8.self).contains("\"paused\""))
        let read = try DeckFile.decode(DeckFile.fileWrapper(for: deck))
        #expect(read.learningOptions.isPaused)
        #expect(read == deck)

        options.isPaused = false
        _ = deck.apply(try #require(DeckChange.changingLearningOptions(options, in: deck, calendar: .testing)), at: date, calendar: .testing)
        #expect(!String(decoding: try DeckFile.encodeDeck(deck), as: UTF8.self).contains("\"paused\""))
        #expect(!(try DeckFile.decode(DeckFile.fileWrapper(for: deck))).learningOptions.isPaused)

        // A file from before has no such key, and a key that is not a Boolean costs the pause, not the deck.
        #expect(!(try DeckFile.decode(deckJSON())).learningOptions.isPaused)
        let odd = Data(
            """
            {"format": "de.fluch-it-consulting.voctrain.deck", "version": 4, "progress": [],
             "learningOptions": {"paused": "yes"}, "cards": []}
            """.utf8)
        #expect(!(try DeckFile.decode(odd)).learningOptions.isPaused)
    }

    /// The keys for notes and production cards are new: an older deck lacks them and reads
    /// with the defaults, and a value out of range or unknown is clamped or ignored.
    @Test func noteKindAndProductionOptionsRoundTripAndDefault() throws {
        let deck = try sampleDeck()
        let read = try DeckFile.decode(DeckFile.fileWrapper(for: deck))
        #expect(read.cards[0].note == "dom")
        #expect(read.cards[0].kind == .recognition)
        #expect(read.cards[1].note == nil)
        #expect(read.learningOptions.newProductionPerSession == 0)
        #expect(read.learningOptions.productionUnlockDays == 30)
        #expect(read.learningOptions.newCardOrder == .newestFirst)

        let old = try DeckFile.decode(deckJSON())
        #expect(old.cards[0].note == nil)
        #expect(old.cards[0].kind == nil)
        #expect(old.learningOptions.newProductionPerSession == 7)
        #expect(old.learningOptions.productionUnlockDays == 7)
        #expect(old.learningOptions.newCardOrder == .deckOrder)

        let odd = Data(
            """
            {"format": "de.fluch-it-consulting.voctrain.deck", "version": 4, "progress": [],
             "learningOptions": {"newProductionPerSession": 100000, "productionUnlockDays": 100000, "newCardOrder": "random"},
             "cards": [{"id": "6F9619FF-8B86-D011-B42D-00C04FC964FF", "question": "dom", "answer": "Haus", "note": "  ", "kind": "listening"}]}
            """.utf8)
        let clamped = try DeckFile.decode(odd)
        #expect(clamped.learningOptions.newProductionPerSession == LearningOptions.productionLimitRange.upperBound)
        #expect(clamped.learningOptions.productionUnlockDays == LearningOptions.productionUnlockDaysRange.upperBound)
        #expect(clamped.learningOptions.newCardOrder == .deckOrder)
        #expect(clamped.cards[0].note == nil)
        #expect(clamped.cards[0].kind == nil)
    }

    /// Version 3 lacks `contentModified` and has the former `format`; it is written
    /// back as the current version with the current `format`.
    @Test func fixedDeckOfVersion3IsRead() throws {
        let url = try #require(Bundle.module.url(forResource: "Resources/deck-v3", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let deck = try DeckFile.decode(data)
        expectFixedDeck(deck)
        #expect(deck.contentModified == nil)

        let written = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "\"version\" : 3", with: "\"version\" : \(DeckFile.currentVersion)")
            .replacingOccurrences(of: "com.mfluch.voctrain.deck", with: DeckFile.format)
            // The options added since take their defaults.
            .replacingOccurrences(of: "\"newCardsPerSession\" : 15,", with: "\"newCardOrder\" : \"deckOrder\",\n    \"newCardsPerSession\" : 15,\n    \"newProductionPerSession\" : 7,")
            .replacingOccurrences(of: "    \"steps\" : 2,", with: "    \"productionUnlockDays\" : 7,\n    \"steps\" : 2,")
            .replacingOccurrences(of: "    \"parameters\" : [", with: "    \"optimizeFromRevealed\" : true,\n    \"parameters\" : [")
            .replacingOccurrences(of: "    \"maximumInterval\" :", with: "    \"leechThreshold\" : 8,\n    \"maximumInterval\" :")
        #expect(String(decoding: try DeckFile.encodeDeck(deck), as: UTF8.self) == written)
    }

    /// The values of the fixed decks.
    func expectFixedDeck(_ deck: Deck) {
        #expect(deck.cards.map(\.question) == ["dom", "pies", "kot"])
        #expect(deck.cards[0].hint == "Substantiv")
        #expect(deck.cards[0].created == date.addingTimeInterval(-7 * 86400))
        #expect(deck.cards[1].learningState?.phase == .relearning)
        #expect(deck.cards[1].learningState?.due == date.addingTimeInterval(600))
        #expect(deck.cards[2].isNew)
        #expect(deck.learningOptions.cardsPerSession == nil)
        #expect(deck.learningOptions.newCardsPerSession == 15)
        #expect(deck.learningOptions.parameters == .default)
        #expect(deck.progress.map(\.day) == [CivilDate(isoString: "2026-10-04")!.dayNumber, CivilDate(isoString: "2026-10-05")!.dayNumber])
    }

    @Test func packageHoldsDeckAndReviewLogSeparately() throws {
        let deck = try sampleDeck()
        let wrapper = try DeckFile.fileWrapper(for: deck)
        #expect(wrapper.isDirectory)
        #expect(Set(wrapper.fileWrappers!.keys) == [DeckFile.deckFileName, DeckFile.reviewsFileName])

        let deckJSON = file(wrapper, DeckFile.deckFileName)
        #expect(deckJSON.contains("\"format\" : \"de.fluch-it-consulting.voctrain.deck\""))
        #expect(deckJSON.contains("\"version\" : \(DeckFile.currentVersion)"))
        #expect(deckJSON.contains("\"question\" : \"dom\""))
        for key in ["learningOptions", "targetRecall", "steps", "learningState", "learningStateReset", "reviews", "hint", "progress", "contentModified", "suspended", "suspensionChanged", "note", "kind", "newProductionPerSession", "productionUnlockDays", "newCardOrder"] {
            #expect(deckJSON.contains("\"\(key)\" :"), "missing key \(key)")
        }
        #expect(deckJSON.contains("\"optimizeFromRevealed\" :"))
        #expect(!deckJSON.contains("revealedRecallWeight"))
        #expect(!deckJSON.contains("\"log\""))
        #expect(!deckJSON.contains("\"hint\" : \"\""))

        let id = deck.cards[0].id.uuidString
        #expect(
            file(wrapper, DeckFile.reviewsFileName) == """
                {"card":"\(id)","date":1791129600,"grade":1}
                {"card":"\(id)","date":1791216000,"grade":2,"mode":"revealed"}

                """)
    }

    @Test func rejectsVersionsBeforeTheFirstRelease() {
        let version1 = Data(
            """
            {"format": "de.fluch-it-consulting.voctrain.deck", "version": 1, "settings": {}, "history": [],
             "cards": [{"id": "6F9619FF-8B86-D011-B42D-00C04FC964FF", "question": "dom", "answer": "Haus",
                        "created": "2026-10-05T16:00:00Z", "log": [{"date": "2026-10-05T16:00:00Z", "grade": 3}]}]}
            """.utf8)
        #expect(throws: DeckFile.Error.outdatedVersion(1)) { try DeckFile.decode(FileWrapper(regularFileWithContents: version1)) }

        let version2 = Data(
            """
            {"format": "de.fluch-it-consulting.voctrain.deck", "version": 2, "settings": {}, "history": [], "cards": []}
            """.utf8)
        let package = FileWrapper(directoryWithFileWrappers: [DeckFile.deckFileName: FileWrapper(regularFileWithContents: version2)])
        #expect(throws: DeckFile.Error.outdatedVersion(2)) { try DeckFile.decode(package) }
    }

    @Test func singleFileOfCurrentVersionIsNoDeck() throws {
        let deckJSON = try DeckFile.encodeDeck(sampleDeck())
        #expect(throws: DeckFile.Error.notADeck) { try DeckFile.decode(FileWrapper(regularFileWithContents: deckJSON)) }
    }

    @Test func packageWithoutReviewLogIsRejectedOnceACardWasStudied() throws {
        let wrapper = try DeckFile.fileWrapper(for: sampleDeck())
        wrapper.removeFileWrapper(wrapper.fileWrappers![DeckFile.reviewsFileName]!)
        #expect(throws: DeckFile.Error.missingReviewLog) { try DeckFile.decode(wrapper) }
    }

    @Test func packageWithoutReviewLogOpensWhileAllCardsAreNew() throws {
        let deck = try Deck(cards: [Card(question: "kot", answer: "Katze", created: date)])
        let wrapper = try DeckFile.fileWrapper(for: deck)
        wrapper.removeFileWrapper(wrapper.fileWrappers![DeckFile.reviewsFileName]!)
        #expect(try DeckFile.decode(wrapper) == deck)
    }

    @Test func reviewsOfUnknownCardsAreRejected() throws {
        let deck = try sampleDeck()
        let wrapper = try package(of: deck, appendingReviews: [reviewLine(of: UUID())])
        #expect(throws: DeckFile.Error.reviewsOfUnknownCard(line: 3)) { try DeckFile.decode(wrapper) }

        let reviews = Data(file(try DeckFile.fileWrapper(for: deck), DeckFile.reviewsFileName).utf8)
        var remaining = [deck.cards[1]]  // the card with reviews was deleted
        #expect(throws: DeckFile.Error.reviewsOfUnknownCard(line: 1)) { try ReviewLogEncoder.attach(reviews, to: &remaining) }
    }

    @Test func reviewLogLongerThanReviewsIsRejected() throws {
        let deck = try sampleDeck()
        let studied = deck.cards[0]
        let tooLong = try package(of: deck, appendingReviews: [reviewLine(of: studied.id), reviewLine(of: studied.id)])
        #expect(throws: DeckFile.Error.reviewLogTooLong(question: "dom")) { try DeckFile.decode(tooLong) }

        let ofNewCard = try package(of: deck, appendingReviews: [reviewLine(of: deck.cards[1].id)])
        #expect(throws: DeckFile.Error.reviewLogTooLong(question: "kot")) { try DeckFile.decode(ofNewCard) }
    }

    @Test func reviewLogShorterThanReviewsIsAllowed() throws {
        let deck = try sampleDeck()
        let card = try DeckFile.decode(DeckFile.fileWrapper(for: deck)).cards[0]
        #expect(card.log == deck.cards[0].log)
        #expect(card.log.count < card.learningState!.reviews)
    }

    @Test func duplicateCardIDsAreRejected() throws {
        var deck = try sampleDeck()
        deck.appendUnchecked([Card(id: deck.cards[1].id, question: "kot", answer: "Kater", created: date)])
        #expect(throws: DeckFile.Error.duplicateCardID(question: "kot")) { try DeckFile.decode(DeckFile.fileWrapper(for: deck)) }
        #expect(throws: DeckFile.Error.duplicateCardID(question: "kot")) { try DeckFile.decode(DeckFile.encodeDeck(deck)) }
    }

    @Test func parametersOutOfRangeAreRejected() throws {
        var weights = FSRSParameters.default.weights
        weights[20] = 0.001
        #expect(throws: DeckFile.Error.parameterOutOfRange(index: 20)) { try DeckFile.decode(deckJSON(parameters: weights)) }

        // Above the ceiling the optimizer sets for several learning steps, but within the fixed one.
        weights = FSRSParameters.default.weights
        weights[17] = 2
        weights[18] = 2
        #expect(try DeckFile.decode(deckJSON(parameters: weights)).learningOptions.parameters.weights == weights)
    }

    /// Values the app never writes are clamped, so studying the card neither crashes
    /// nor yields values the deck can't be saved with.
    @Test(arguments: [
        (step: 0, stability: 0.0, difficulty: 5.0, reviews: 1, lapses: 0),
        (step: 0, stability: 12.5, difficulty: -3.0, reviews: 1, lapses: 0),
        (step: 0, stability: 12.5, difficulty: 50.0, reviews: 1, lapses: 0),
        (step: 0, stability: 12.5, difficulty: 5.0, reviews: Int.max, lapses: Int.max),
        (step: -2, stability: 12.5, difficulty: 5.0, reviews: -1, lapses: -1),
        (step: Int.max, stability: 1e300, difficulty: 5.0, reviews: 1, lapses: 0),
    ])
    func learningStateOutOfRangeIsClamped(values: (step: Int, stability: Double, difficulty: Double, reviews: Int, lapses: Int)) throws {
        let json = deckJSON(step: values.step, stability: values.stability, difficulty: values.difficulty, reviews: values.reviews, lapses: values.lapses)
        let deck = try DeckFile.decode(json)
        let learningState = try #require(deck.cards[0].learningState)
        #expect(learningState.stability >= FSRS.minimumStability)
        #expect(FSRS.difficultyRange.contains(learningState.difficulty))
        #expect(learningState.step >= 0 && learningState.reviews >= 0 && learningState.lapses >= 0)

        for phase in [LearningPhase.review, .relearning] {
            for days in [0.0, 3, 400] {
                for grade in [Grade.good, .easy, .again] {
                    var studied = deck
                    studied.cards[0].learningState?.phase = phase
                    var random = SeededRandom(seed: 1)
                    let scheduler = Scheduler(learningOptions: deck.learningOptions, calendar: .testing)
                    studied.cards[0] = scheduler.review(studied.cards[0], grade: grade, at: date.addingTimeInterval(days * 86400), using: &random)
                    let reviewed = try #require(studied.cards[0].learningState)
                    #expect(reviewed.stability.isFinite && reviewed.difficulty.isFinite, "\(phase) \(grade) after \(days) days")
                    // Values at the upper bounds are clamped again, so the deck itself may differ.
                    #expect(try DeckFile.decode(DeckFile.fileWrapper(for: studied)).cards[0].log == studied.cards[0].log)
                }
            }
        }
    }

    @Test func damagedReviewLineIsReported() throws {
        let wrapper = try DeckFile.fileWrapper(for: sampleDeck())
        var lines = file(wrapper, DeckFile.reviewsFileName)
        lines += "{\"card\":\"nonsense\"}\n"
        wrapper.removeFileWrapper(wrapper.fileWrappers![DeckFile.reviewsFileName]!)
        wrapper.addRegularFile(withContents: Data(lines.utf8), preferredFilename: DeckFile.reviewsFileName)
        #expect(throws: DeckFile.Error.damagedReviewLog(line: 3)) { try DeckFile.decode(wrapper) }
    }

    /// Only revealed reviews name their mode; a missing or unknown one reads as typed.
    @Test func reviewModesAreReadBack() throws {
        let deck = try sampleDeck()
        let id = deck.cards[0].id.uuidString
        let wrapper = try package(of: deck, appendingReviews: ["{\"card\":\"\(id)\",\"date\":1791302400,\"grade\":3,\"mode\":\"spoken\"}"])
        let fileDeck = try DeckFile.decode(wrapper)
        #expect(fileDeck.cards[0].log.map(\.mode) == [.typed, .revealed, .typed])
        #expect(Array(fileDeck.cards[0].log.prefix(2)) == deck.cards[0].log)
    }

    /// `ms` is the duration in whole milliseconds, written only where there is one.
    @Test func reviewDurationsRoundTripAndAreLeftOutWhenMissing() throws {
        var deck = try sampleDeck()
        deck.cards[0].learningState?.reviews = 4
        deck.cards[0].log.append(ReviewLogEntry(date: date.addingTimeInterval(60), grade: .good, mode: .revealed, duration: .milliseconds(4210)))
        deck.cards[0].log.append(ReviewLogEntry(date: date.addingTimeInterval(120), grade: .good, duration: .milliseconds(900)))
        let wrapper = try DeckFile.fileWrapper(for: deck)
        let lines = file(wrapper, DeckFile.reviewsFileName).split(separator: "\n").map(String.init)
        #expect(lines.count == 4)
        #expect(lines[0..<2].allSatisfy { !$0.contains("\"ms\"") })
        #expect(lines[2].hasSuffix(",\"mode\":\"revealed\",\"ms\":4210}"))
        #expect(lines[3].hasSuffix(",\"grade\":3,\"ms\":900}"))

        let read = try DeckFile.decode(wrapper)
        #expect(read.cards[0].log == deck.cards[0].log)
        #expect(read.cards[0].log.map(\.duration) == [nil, nil, .milliseconds(4210), .milliseconds(900)])
    }

    /// A duration is kept in whole milliseconds, so what is in memory is what the file holds.
    @Test func aDurationIsRoundedToWholeMillisecondsAndNeverNegative() {
        #expect(ReviewLogEntry(date: date, grade: .good, duration: .seconds(4) + .microseconds(600)).duration == .milliseconds(4001))
        #expect(ReviewLogEntry(date: date, grade: .good, duration: .milliseconds(-5)).duration == .zero)
    }

    @Test func packageWithoutDeckIsRejected() {
        let wrapper = FileWrapper(directoryWithFileWrappers: [:])
        #expect(throws: DeckFile.Error.notADeck) { try DeckFile.decode(wrapper) }
    }

    @Test func optionalFieldsMayBeMissing() throws {
        let json = """
            {"format": "de.fluch-it-consulting.voctrain.deck", "version": 3, "learningOptions": {},
             "cards": [{"id": "6F9619FF-8B86-D011-B42D-00C04FC964FF", "question": "dom", "answer": "Haus"}],
             "progress": []}
            """
        let deck = try DeckFile.decode(Data(json.utf8))
        #expect(deck.cards.first?.hint == "")
        #expect(deck.cards.first?.learningState == nil)
        #expect(deck.learningOptions == LearningOptions())
    }

    /// What a newer app version adds without a new format version, an older one reads
    /// and drops on the next save (see `DeckFile`).
    @Test func unknownKeysAndFilesAreReadAndDroppedOnSave() throws {
        let deckJSON = """
            {"format": "de.fluch-it-consulting.voctrain.deck", "version": 3, "progress": [], "futureDeckKey": 1,
             "learningOptions": {"targetRecall": 0.85, "futureOption": 7},
             "cards": [{"id": "6F9619FF-8B86-D011-B42D-00C04FC964FF", "question": "dom", "answer": "Haus", "futureCardKey": "x",
                        "learningState": {"phase": "learning", "step": 1, "stability": 2.3, "difficulty": 2.1, "reviews": 1, "lapses": 0,
                                          "lastReview": "2026-10-05T16:00:00Z", "due": "2026-10-05T16:00:00Z"}}]}
            """
        let reviews = """
            {"card":"6F9619FF-8B86-D011-B42D-00C04FC964FF","date":1791216000,"grade":3,"futureReviewKey":true}

            """
        let package = FileWrapper(directoryWithFileWrappers: [
            DeckFile.deckFileName: FileWrapper(regularFileWithContents: Data(deckJSON.utf8)),
            DeckFile.reviewsFileName: FileWrapper(regularFileWithContents: Data(reviews.utf8)),
            "future.json": FileWrapper(regularFileWithContents: Data("{}".utf8)),
        ])

        let deck = try DeckFile.decode(package)
        #expect(deck.learningOptions.targetRecall == 0.85)
        #expect(deck.cards.map(\.question) == ["dom"])
        #expect(deck.cards[0].log == [ReviewLogEntry(date: date, grade: .good)])

        let written = try DeckFile.fileWrapper(for: deck)
        #expect(Set(written.fileWrappers!.keys) == [DeckFile.deckFileName, DeckFile.reviewsFileName])
        let writtenDeck = file(written, DeckFile.deckFileName)
        for key in ["futureDeckKey", "futureOption", "futureCardKey"] {
            #expect(!writtenDeck.contains(key), "kept key \(key)")
        }
        #expect(file(written, DeckFile.reviewsFileName) == "{\"card\":\"6F9619FF-8B86-D011-B42D-00C04FC964FF\",\"date\":1791216000,\"grade\":3}\n")
    }

    @Test func clampsInvalidLearningOptions() throws {
        let json = """
            {"format": "de.fluch-it-consulting.voctrain.deck", "version": 3, "progress": [], "cards": [],
             "learningOptions": {"targetRecall": 0, "steps": 0, "maximumInterval": -5, "cardsPerSession": 0,
                                 "newCardsPerSession": 100000}}
            """
        let learningOptions = try DeckFile.decode(Data(json.utf8)).learningOptions
        #expect(learningOptions.targetRecall == LearningOptions.targetRecallRange.lowerBound)
        #expect(learningOptions.steps == LearningOptions.stepsRange.lowerBound)
        #expect(learningOptions.maximumInterval == LearningOptions.maximumIntervalRange.lowerBound)
        #expect(learningOptions.cardsPerSession == LearningOptions.sessionLimitRange.lowerBound)
        #expect(learningOptions.newCardsPerSession == LearningOptions.sessionLimitRange.upperBound)
    }

    @Test func rejectsInvalidValues() {
        let parameters = """
            {"format": "de.fluch-it-consulting.voctrain.deck", "version": 3, "progress": [], "cards": [],
             "learningOptions": {"parameters": [1, 2]}}
            """
        #expect(throws: DecodingError.self) { try DeckFile.decode(Data(parameters.utf8)) }

        let day = """
            {"format": "de.fluch-it-consulting.voctrain.deck", "version": 3, "learningOptions": {}, "cards": [],
             "progress": [{"day": "2026-13-45", "bins": []}]}
            """
        #expect(throws: DecodingError.self) { try DeckFile.decode(Data(day.utf8)) }
    }

    @Test func rejectsForeignAndFutureFiles() {
        #expect(throws: DeckFile.Error.notADeck) { try DeckFile.decode(Data("{\"foo\": 1}".utf8)) }
        #expect(throws: DeckFile.Error.notADeck) { try DeckFile.decode(Data("not json".utf8)) }
        let future = Data("{\"format\": \"de.fluch-it-consulting.voctrain.deck\", \"version\": 99}".utf8)
        #expect(throws: DeckFile.Error.unsupportedVersion(99)) { try DeckFile.decode(future) }
    }
}

struct ReviewLogEncoderTests {
    let date = Date(timeIntervalSince1970: 1_791_216_000)

    func cards(_ count: Int) -> [Card] {
        (0..<count).map { index in
            var card = Card(question: "q\(index)", answer: "a\(index)")
            card.log = (0..<3).map { ReviewLogEntry(date: date.addingTimeInterval(Double($0 * 86400 + index)), grade: .good) }
            return card
        }
    }

    /// Encodes with the cached encoder and checks it matches a fresh one.
    func encode(_ cards: [Card], with encoder: ReviewLogEncoder) -> Int {
        let data = encoder.encode(cards)
        #expect(data == ReviewLogEncoder().encode(cards))
        return encoder.lastEncodedCardCount
    }

    @Test func onlyChangedCardsAreEncodedAgain() {
        let encoder = ReviewLogEncoder()
        var deck = cards(50)
        #expect(encode(deck, with: encoder) == 50)
        #expect(encode(deck, with: encoder) == 0)

        deck[7].log.append(ReviewLogEntry(date: date.addingTimeInterval(10 * 86400), grade: .again))
        #expect(encode(deck, with: encoder) == 1)

        deck[7].log.removeLast()  // undo
        #expect(encode(deck, with: encoder) == 1)

        deck[8].log = []  // reset
        #expect(encode(deck, with: encoder) == 0)

        deck.remove(at: 3)  // delete
        deck.append(cards(1)[0])  // add a studied card
        #expect(encode(deck, with: encoder) == 1)
    }

    @Test func replacedLogOfSameLengthIsNoticed() {
        let encoder = ReviewLogEncoder()
        var deck = cards(2)
        _ = encode(deck, with: encoder)
        deck[0].log[2].grade = .easy
        #expect(encode(deck, with: encoder) == 1)
    }

    /// A review with a duration is one more line at the end; the lines before it stay as they were.
    @Test func aReviewWithADurationIsAppendedWithoutRewritingTheLines() {
        let encoder = ReviewLogEncoder()
        var deck = cards(3)
        func lines(_ data: Data) -> [String] { String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init) }
        let before = lines(encoder.encode(deck))
        deck[1].log.append(ReviewLogEntry(date: date.addingTimeInterval(9 * 86400), grade: .good, mode: .revealed, duration: .milliseconds(2750)))
        let after = lines(encoder.encode(deck))
        #expect(encoder.lastEncodedCardCount == 1)
        #expect(after.count == before.count + 1)
        #expect(after.filter { !$0.contains("\"ms\"") } == before)
        #expect(after[after.firstIndex { $0.contains("\"ms\":2750") } ?? 0].contains(deck[1].id.uuidString))
    }

    @Test func cardsWithoutReviewsWriteNothing() {
        #expect(ReviewLogEncoder().encode([Card(question: "q", answer: "a")]).isEmpty)
    }
}
