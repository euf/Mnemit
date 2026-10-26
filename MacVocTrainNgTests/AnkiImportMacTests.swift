import Foundation
import Testing
import UniformTypeIdentifiers
import VocabCore

@testable import MacVocTrain

/// The Mac side of the Anki import: the preview of a package, built here from notes, as the
/// sandbox of the test host can't read the fixtures of VocabCore (the iPhone's tests read them).
@MainActor
struct AnkiImportMacTests {
    let calendar = StudyCalendar.testing
    let created = Date(timeIntervalSince1970: 1_791_216_000)

    @Test func aPackageIsRecognisedByItsExtension() {
        #expect(URL(fileURLWithPath: "/Downloads/Greek.apkg").isAnkiPackage)
        #expect(URL(fileURLWithPath: "/Downloads/GREEK.APKG").isAnkiPackage)
        #expect(!URL(fileURLWithPath: "/Downloads/Greek.mnemit", isDirectory: true).isAnkiPackage)
        #expect(!URL(fileURLWithPath: "/Downloads/words.tsv").isAnkiPackage)
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

    @Test func thePreviewCountsTheCardsTheirHistoryAndWhatWasLeftOut() {
        let review = ReviewLogEntry(date: created, grade: .good, mode: .revealed)
        let package = AnkiImport(
            notes: [
                .init(front: "γάτα", back: "cat", reviews: [review]),
                .init(front: "σκύλος", back: "dog", isSuspended: true),
                .init(front: "γάτα", back: "kitty"),
            ],
            skippedCloze: 2, skippedMediaRefs: 3, skippedEmpty: 1, deckNames: ["Greek::Lesson 1"])
        let existing = [Card(question: "σκύλος", answer: "hound")]
        let made = CardImport.ankiCandidates(of: package, existing: existing, learningOptions: LearningOptions(), calendar: calendar, created: created)
        #expect(made.candidates.map(\.card.question) == ["γάτα", "σκύλος", "γάτα"])
        #expect(made.candidates.map(\.duplicate) == [nil, .inDeck, .inFile(question: "γάτα", answer: "cat")])
        #expect(made.summary == CardImport.AnkiSummary(deckNames: ["Greek::Lesson 1"], withHistory: 1, skippedCloze: 2, skippedMediaRefs: 3, skippedEmpty: 1))
        #expect(made.summary.lines.count == 4)

        let preview = CardImport.Preview(fileName: "greek.apkg", candidates: made.candidates, skippedRows: 0, anki: made.summary)
        #expect(preview.selectedCards.map(\.answer) == ["cat"])
    }

    /// A note whose text the rules of a card leave out is counted with the empty ones.
    @Test func aNoteThatMakesNoCardIsCountedAsEmpty() {
        let package = AnkiImport(notes: [.init(front: "  ", back: "x"), .init(front: "a", back: "b")], skippedEmpty: 1)
        let made = CardImport.ankiCandidates(of: package, existing: [], learningOptions: LearningOptions(), calendar: calendar, created: created)
        #expect(made.candidates.count == 1)
        #expect(made.summary.skippedEmpty == 2)
    }

    /// A new deck takes the FSRS settings of the Anki preset most cards use and replays with them;
    /// a deck that exists keeps its options and says so.
    @Test func aNewDeckTakesTheSettingsOfTheDominantPreset() {
        let review = ReviewLogEntry(date: created, grade: .good, mode: .revealed)
        let weights = FSRSParameters.default.weights.map { Float($0) }
        let package = AnkiImport(
            notes: [.init(front: "a", back: "1", reviews: [review], preset: 1), .init(front: "b", back: "2", preset: 1), .init(front: "c", back: "3", preset: 0)],
            deckNames: ["Greek"],
            presets: [AnkiPreset(name: "Default", desiredRetention: 0.9), AnkiPreset(name: "Greek", parameters: weights, desiredRetention: 0.85)])

        let newDeck = CardImport.ankiCandidates(of: package, existing: [], learningOptions: LearningOptions(), calendar: calendar, created: created, isNewDeck: true)
        #expect(newDeck.learningOptions?.targetRecall == 0.85)
        #expect(newDeck.summary.settings == .applied(target: 85))
        #expect(newDeck.summary.lines.count == 2)
        #expect(newDeck.summary.lines[1] == String(localized: "Uses Anki's FSRS settings: \("85 %") target"))

        let existingDeck = CardImport.ankiCandidates(of: package, existing: [], learningOptions: LearningOptions(), calendar: calendar, created: created)
        #expect(existingDeck.learningOptions == nil)
        #expect(existingDeck.summary.settings == .keptForExistingDeck)
        #expect(existingDeck.summary.lines[1] == String(localized: "Anki's settings for this deck are not applied to an existing deck."))

        // Without a preset in the package there is nothing to take and nothing to say.
        let plain = CardImport.ankiCandidates(of: AnkiImport(notes: [.init(front: "a", back: "1")]), existing: [], learningOptions: LearningOptions(), calendar: calendar, created: created, isNewDeck: true)
        #expect(plain.learningOptions == nil && plain.summary.settings == .absent && plain.summary.lines.count == 1)
    }

    /// The browser of the Mac is the iPhone's: the same sources, and the files it saves are the
    /// ones the import takes.
    @Test func theBrowserKeepsItsSourcesAndSendsOtherHostsToSafari() {
        #expect(DeckSources.all.count == 2)
        #expect(DeckSources.isKnown(URL(string: "https://ankiweb.net/shared/decks")))
        #expect(DeckSources.isKnown(URL(string: "https://www.mintdeck.app/decks")))
        #expect(DeckSources.opensInSafari(URL(string: "https://example.com"), isLinkActivation: true))
        #expect(DeckDownload.localName(forSuggested: "Greek Core.apkg").hasSuffix(".apkg"))
        #expect(DeckDownload.shouldDownload(url: nil, mimeType: "text/csv", contentDisposition: nil, canShow: true))
    }
}
