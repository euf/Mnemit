import Foundation
import Testing
import UniformTypeIdentifiers

@testable import VocTrain
@testable import VocabCore

/// What the Anki import screens stand on: the routing of the URLs the app is opened with, the
/// copy of a package that "Open in Mnemit" brings, the preview of a package with its counts and
/// duplicates, and "Add N Cards" with the review history. The packages are the fixtures of
/// VocabCore, made by Anki's own library: six cards, four of them with reviews, two cloze cards,
/// two fields with media and one empty card left out.
@MainActor @Suite(.timeLimit(.minutes(3)))
struct AnkiImportScreenTests {
    let created = Date(timeIntervalSince1970: 1_791_216_000)

    /// The fixtures lie in the package of the core, which the tests of the app read in place.
    static func fixture(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Packages/VocabCore/Tests/VocabCoreTests/Resources/Anki/\(name).apkg")
    }

    private func makeDocument(_ cards: [Card] = []) throws -> (VocabularyDocument, UndoManager) {
        let document = try VocabularyDocument(deck: Deck(cards: cards), clock: StudyClock { created.addingTimeInterval(60) })
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        return (document, undoManager)
    }

    private func preview(_ name: String, for document: VocabularyDocument, isNewDeck: Bool = false) async throws -> CardImport.Preview {
        let package = try await CardImport.loadAnki(at: Self.fixture(name))
        return await CardImport.ankiPreview(of: package, fileName: "\(name).apkg", for: document, isNewDeck: isNewDeck)
    }

    // MARK: Routing

    @Test func aUrlTheAppIsOpenedWithIsRoutedByWhatItIs() {
        #expect(IncomingLink(WidgetLink.study) == .study)
        #expect(IncomingLink(URL(string: "mnemit://study")!) == .study)
        #expect(IncomingLink(URL(fileURLWithPath: "/files/Greek.apkg")) == .ankiPackage)
        // Whatever the case of the extension, and wherever the file lies.
        #expect(IncomingLink(URL(fileURLWithPath: "/private/var/mobile/Inbox/GREEK.APKG")) == .ankiPackage)
        #expect(IncomingLink(URL(fileURLWithPath: "/files/Greek.mnemit", isDirectory: true)) == .deck)
        #expect(IncomingLink(URL(fileURLWithPath: "/files/Greek.voctrain", isDirectory: true)) == .deck)
        // A deck whose name only mentions the extension is a deck.
        #expect(IncomingLink(URL(fileURLWithPath: "/files/apkg notes.mnemit", isDirectory: true)) == .deck)
        // The other links of the scheme are not Study, so they end up with the decks as before.
        #expect(IncomingLink(URL(string: "mnemit://settings")!) == .deck)
    }

    /// What makes "Open in Mnemit" offer the package: the imported type and a document type of
    /// the viewer role with the alternate rank, in the Info.plist of the app under test.
    @Test func theInfoPlistDeclaresThePackageForOpenIn() {
        let info = Bundle.main.infoDictionary ?? [:]
        let imported = (info["UTImportedTypeDeclarations"] as? [[String: Any]] ?? []).first { $0["UTTypeIdentifier"] as? String == UTType.ankiPackage.identifier }
        #expect(imported?["UTTypeConformsTo"] as? [String] == ["public.zip-archive", "public.data"])
        #expect((imported?["UTTypeTagSpecification"] as? [String: Any])?["public.filename-extension"] as? [String] == ["apkg"])
        let document = (info["CFBundleDocumentTypes"] as? [[String: Any]] ?? []).first { $0["LSItemContentTypes"] as? [String] == [UTType.ankiPackage.identifier] }
        #expect(document?["CFBundleTypeRole"] as? String == "Viewer")
        #expect(document?["LSHandlerRank"] as? String == "Alternate")
        #expect(UTType.ankiPackage.conforms(to: .zip) && UTType.ankiPackage.conforms(to: .data))
    }

    @Test func theLinkToAnkiWebIsTheListOfSharedDecks() {
        #expect(AnkiWebLink.url.absoluteString == "https://ankiweb.net/shared/decks")
    }

    @Test func thePickerKeepsAPackageAsAFileAndReadsATable() throws {
        let package = try ImportedFile(contentsOf: Self.fixture("greek-latest"))
        #expect(package.name == "greek-latest.apkg")
        #expect(package.data == nil)
        guard case let .anki(url, known) = package.content else {
            Issue.record("a package is not read by the picker")
            return
        }
        #expect(url == Self.fixture("greek-latest"))
        #expect(known == nil)
    }

    // MARK: The copy of "Open in Mnemit"

    @Test func aPackageIsCopiedUnderItsNameAndTheCopiesCanGoAway() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { IncomingPackages.purge(folder) }
        let copy = try await IncomingPackages.copy(Self.fixture("greek-legacy2"), into: folder)
        #expect(copy.lastPathComponent == "greek-legacy2.apkg")
        #expect(copy.deletingLastPathComponent().deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL)
        #expect(try Data(contentsOf: copy) == Data(contentsOf: Self.fixture("greek-legacy2")))
        // The copy reads as the original does.
        #expect(try CardImport.readAnki(at: copy).notes.count == 6)

        IncomingPackages.purge(folder)
        #expect(!FileManager.default.fileExists(atPath: copy.path))
        #expect(FileManager.default.fileExists(atPath: Self.fixture("greek-legacy2").path))

        await #expect(throws: (any Error).self) { try await IncomingPackages.copy(folder.appending(path: "missing.apkg"), into: folder) }
    }

    // MARK: Reading

    @Test func aFileThatIsNoPackageSaysSo() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).apkg")
        try Data("not a zip".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(throws: AnkiImport.Error.unreadableArchive) { try CardImport.readAnki(at: url) }
        #expect(CardImport.failureMessage(AnkiImport.Error.unreadableArchive) == String(localized: "This isn't an Anki package, or the file is damaged."))
        #expect(throws: (any Error).self) { try CardImport.readAnki(at: url.deletingLastPathComponent().appending(path: "missing.apkg")) }
    }

    // MARK: The preview

    @Test(arguments: ["greek-latest", "greek-latest-cli", "greek-legacy2", "greek-legacy1"])
    func thePreviewCountsWhatThePackageBroughtAndLeftOut(name: String) async throws {
        let (document, _) = try makeDocument()
        let preview = try await preview(name, for: document)
        let anki = try #require(preview.anki)
        #expect(preview.candidates.map(\.card.question) == ["γάτα", "σπίτι\nτο", "ήχος", "νερό", "water", "σκύλος"])
        #expect(anki.deckNames == ["Greek::Lesson 1"])
        #expect(anki.withHistory == 4)
        #expect(anki.skippedCloze == 2)
        #expect(anki.skippedMediaRefs == 2)
        #expect(anki.skippedEmpty == 1)
        #expect(preview.skippedRows == 0)
        #expect(preview.candidates.allSatisfy { $0.duplicate == nil })
        // Everything is checked: the cards, the suspended one among them.
        #expect(preview.selection.count == 6)
        // The package's preset has FSRS settings, which an existing deck doesn't take.
        #expect(anki.settings == .keptForExistingDeck)
        #expect(anki.lines.count == 5)
        #expect(anki.lines.first == String(localized: "4 with review history"))
        #expect(anki.lines[1] == String(localized: "Anki's settings for this deck are not applied to an existing deck."))
    }

    @Test func cardsTheTargetDeckHasStartUncheckedAndTheHistoryIsReplayedWithItsOptions() async throws {
        let (document, _) = try makeDocument([Card(text: CardText(question: " Γάτα ", answer: "kitten")!, created: created)])
        let preview = try await preview("greek-latest", for: document)
        let duplicates = preview.candidates.filter { $0.duplicate != nil }
        #expect(duplicates.map(\.card.question) == ["γάτα"])
        #expect(duplicates.first?.duplicate == .inDeck)
        #expect(preview.selection.count == 5)
        #expect(!preview.selection.contains(duplicates[0].id))
        #expect(preview.selectedCards.map(\.question) == ["σπίτι\nτο", "ήχος", "νερό", "water", "σκύλος"])

        // The same package for a deck with other options comes out with other memory: it is the
        // deck's own steps that replay the reviews, a lapse of the cat taking one step or two to learn again.
        var options = document.deck.learningOptions
        options.steps = 1
        let other = try VocabularyDocument(deck: Deck(learningOptions: options, cards: []), clock: StudyClock { created })
        let kept = try await self.preview("greek-latest", for: document).candidates[0].card
        let replayed = try await self.preview("greek-latest", for: other).candidates[0].card
        #expect(kept.learningState?.phase != replayed.learningState?.phase)
        #expect(kept.log == replayed.log)
    }

    // MARK: Anki's FSRS settings

    @Test func aNewDeckTakesTheSettingsOfAnkisPresetAndReplaysWithThem() async throws {
        let (document, undoManager) = try makeDocument()
        let preview = try await preview("greek-latest", for: document, isNewDeck: true)
        let options = try #require(preview.learningOptions)
        #expect(options.targetRecall == 0.85)
        #expect(options.parameters.weights[0] == 0.3178)
        #expect(options.parameters.weights[20] == 0.173)
        // The rest of the deck's options stay.
        var plain = document.deck.learningOptions
        plain.parameters = options.parameters
        plain.targetRecall = options.targetRecall
        #expect(options == plain)

        let anki = try #require(preview.anki)
        #expect(anki.settings == .applied(target: 85))
        #expect(anki.lines[1] == String(localized: "Uses Anki's FSRS settings: \("85 %") target"))

        // The cat is replayed with them: another memory than under the deck's defaults.
        let defaults = try await self.preview("greek-latest", for: document)
        #expect(preview.candidates[0].card.learningState?.stability != defaults.candidates[0].card.learningState?.stability)

        undoManager.beginUndoGrouping()
        document.importCards(preview.selectedCards, learningOptions: preview.learningOptions)
        undoManager.endUndoGrouping()
        #expect(document.deck.learningOptions == options)
        #expect(document.deck.cards.count == 6)

        // One undo takes the cards and the settings back.
        undoManager.undo()
        #expect(document.deck.cards.isEmpty)
        #expect(document.deck.learningOptions == LearningOptions())
        #expect(!undoManager.canUndo)
    }

    @Test func anExistingDeckKeepsItsOptions() async throws {
        let existing = Card(text: CardText(question: "ο κλέφτης", answer: "thief")!, created: created)
        let (document, undoManager) = try makeDocument([existing])
        let before = document.deck.learningOptions
        // Even asked for as a new deck: a deck that has cards is not one.
        for isNewDeck in [false, true] {
            let preview = try await self.preview("greek-latest", for: document, isNewDeck: isNewDeck)
            #expect(preview.learningOptions == nil)
            #expect(preview.anki?.settings == .keptForExistingDeck)
            undoManager.beginUndoGrouping()
            document.importCards(preview.selectedCards, learningOptions: preview.learningOptions)
            undoManager.endUndoGrouping()
            #expect(document.deck.learningOptions == before)
            undoManager.undo()
        }
    }

    @Test func thePresetMostCardsUseDecidesAndAPresetWithoutSettingsSaysNothing() async throws {
        let (document, _) = try makeDocument()
        // Two cards of the FSRS-5 preset at 95 %, one of FSRS-4.5 at 80 %, one of the stock preset.
        let five = try await preview("presets-latest", for: document, isNewDeck: true)
        #expect(five.learningOptions?.targetRecall == 0.95)
        #expect(five.anki?.settings == .applied(target: 95))
        #expect(five.learningOptions?.parameters.weights[20] == 0.5)

        // A package whose preset is the stock one: nothing to take, and nothing to say.
        let package = AnkiImport(notes: [.init(front: "a", back: "b", preset: 0)], presets: [AnkiPreset(name: "Default", desiredRetention: 0.9)])
        let plain = await CardImport.ankiPreview(of: package, fileName: "a.apkg", for: document, isNewDeck: true)
        #expect(plain.learningOptions == nil)
        #expect(plain.anki?.settings == .absent)
        #expect(plain.anki?.lines.count == 1)
    }

    // MARK: Add

    @Test func addingTheCheckedCardsBringsTheHistoryAsOneUndoStep() async throws {
        let existing = Card(text: CardText(question: "ο κλέφτης", answer: "thief")!, created: created)
        let (document, undoManager) = try makeDocument([existing])
        let preview = try await preview("greek-latest", for: document)
        // The learner unchecks the water.
        preview.selection.remove(preview.candidates[3].id)

        undoManager.beginUndoGrouping()
        document.importCards(preview.selectedCards)
        undoManager.endUndoGrouping()

        let cards = document.deck.cards
        #expect(cards.map(\.question) == ["ο κλέφτης", "γάτα", "σπίτι\nτο", "ήχος", "water", "σκύλος"])
        let cat = try #require(cards.first { $0.question == "γάτα" })
        #expect(cat.log.count == 5)
        #expect(cat.learningState?.lapses == 1)
        #expect(cards.first { $0.question == "σκύλος" }?.isSuspended == true)
        #expect(cards.first { $0.question == "ήχος" }?.isNew == true)
        #expect(undoManager.undoActionName == String(localized: "Import Cards"))

        undoManager.undo()
        #expect(document.deck.cards == [existing])
        #expect(!undoManager.canUndo)
        undoManager.redo()
        #expect(document.deck.cards.first { $0.question == "γάτα" }?.log.count == 5)
    }

    // MARK: The name of a new deck

    @Test func aNewDeckIsNamedAfterTheAnkiDeck() {
        func name(_ decks: [String], file: String = "export.apkg") -> String {
            CardImport.deckName(forDecks: decks, fileName: file)
        }
        #expect(name(["Greek"]) == "Greek")
        // A file name can't hold "::", so the levels are set apart otherwise.
        #expect(name(["Greek::Lesson 1"]) == "Greek – Lesson 1")
        // Several decks: the top they share, else the file.
        #expect(name(["Greek::Lesson 1", "Greek::Lesson 2"]) == "Greek")
        #expect(name(["Greek", "Latin"], file: "Languages.apkg") == "Languages")
        // The deck that Anki makes for what has none says nothing; so does a package without decks.
        #expect(name(["Default"], file: "Words 2026.apkg") == "Words 2026")
        #expect(name([], file: "Words.apkg") == "Words")
        // A name a file can't have gives way to the file's.
        #expect(name(["a/b: c"]) == "a-b- c")
        #expect(name([".hidden"], file: "Words.apkg") == "Words")
        #expect(name([".hidden"], file: ".apkg") == "Anki")
    }
}
