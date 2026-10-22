import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// CSV/TSV import on the iPhone and the Anki-compatible export of both platforms: the shared
/// `CardImport` and `CardExport`, the file of the picker, the file of the share sheet and the one
/// undo step of "Add N Cards".
@MainActor @Suite(.timeLimit(.minutes(3)))
struct CardExchangeTests {
    let created = Date(timeIntervalSince1970: 1_791_216_000)
    let calendar = StudyCalendar(timeZone: TimeZone(identifier: "Europe/Berlin")!, rolloverHour: 4)

    private func makeDocument(_ cards: [Card]) throws -> (VocabularyDocument, UndoManager) {
        let document = try VocabularyDocument(deck: Deck(cards: cards), clock: StudyClock { created.addingTimeInterval(60) })
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        return (document, undoManager)
    }

    private var wordCards: [Card] {
        [
            Card(text: CardText(question: "ο κλέφτης", answer: "thief, robber", hint: "noun")!, note: "κλέφτης#ο", kind: .recognition, created: created),
            Card(text: CardText(question: "thief", answer: "ο κλέφτης")!, note: "κλέφτης#ο", kind: .production, created: created),
            Card(text: CardText(question: "η αστυνομία", answer: "the \"police\"")!, created: created),
        ]
    }

    // MARK: Export

    @Test func exportHasAnkiHeaderLinesAndNoTitleRow() {
        let tsv = CardExport.data(of: wordCards, format: .tsv, includingLearningState: false, calendar: calendar)
        #expect(tsv.starts(with: [0xEF, 0xBB, 0xBF]))
        let lines = String(decoding: tsv.dropFirst(3), as: UTF8.self).components(separatedBy: "\r\n")
        #expect(lines[0] == "#separator:tab")
        #expect(lines[1] == "#html:false")
        #expect(lines[2] == "#columns:Front\tBack\tHint\tWord Key\tKind")
        #expect(lines[3] == "ο κλέφτης\tthief, robber\tnoun\tκλέφτης#ο\trecognition")
        #expect(lines[4] == "thief\tο κλέφτης\t\tκλέφτης#ο\tproduction")
        #expect(lines[5] == "η αστυνομία\t\"the \"\"police\"\"\"\t\t\t")
        #expect(lines.count == 7)  // the last line ends with CRLF

        let csv = CardExport.data(of: wordCards, format: .csv, includingLearningState: false, calendar: calendar)
        let csvLines = String(decoding: csv.dropFirst(3), as: UTF8.self).components(separatedBy: "\r\n")
        #expect(csvLines[0] == "#separator:comma")
        #expect(csvLines[2] == "#columns:Front,Back,Hint,Word Key,Kind")
        #expect(csvLines[3] == "ο κλέφτης,\"thief, robber\",noun,κλέφτης#ο,recognition")
    }

    @Test func aWordTheOtherDecksHaveStartsUncheckedAndIsCountedPerDeck() throws {
        let other = try Deck(cards: wordCards)
        let index = WordIndex(decks: [("Greek A1–A2", other)])
        let table = """
            #separator:tab
            #html:false
            #columns:Front\tBack\tHint\tWord Key\tKind
            ο κλέφτης\tthe thief\t\tκλέφτης#ο\trecognition
            the thief\tο κλέφτης\t\tκλέφτης#ο\tproduction
            το σπίτι\thouse\t\t\t
            η αστυνομία\tpolice\t\t\t
            """
        let preview = CardImport.preview(of: Data(table.utf8), fileName: "deck", existing: [], elsewhere: index, created: created)

        guard case let .inOtherDeck(match)? = preview.candidates.first?.duplicate else {
            Issue.record("the first card is in the other deck")
            return
        }
        #expect(match.deck == "Greek A1–A2")
        #expect(preview.candidates.map { $0.duplicate == nil } == [false, false, true, false])
        #expect(preview.selection == Set(preview.candidates.filter { $0.duplicate == nil }.map(\.id)))
        #expect(preview.candidates[0].otherDeckLine == match.alsoInLine)
        #expect(preview.candidates[2].otherDeckLine == nil)
        // The two cards of the thief, and η αστυνομία, which the other deck has without a word key: by its Greek question.
        #expect(preview.otherDeckLines == [String(localized: "\(3) cards are also in \("Greek A1–A2") and start unticked.")])
        // Without the other decks the preview is the one of one deck.
        let alone = CardImport.preview(of: Data(table.utf8), fileName: "deck", existing: [], created: created)
        #expect(alone.otherDeckLines.isEmpty)
        #expect(alone.selection.count == 4)
    }

    @Test func ourOwnExportComesBackWithWordKeyAndKind() {
        for format in CardExport.Format.allCases {
            let data = CardExport.data(of: wordCards, format: format, includingLearningState: false, calendar: calendar)
            let preview = CardImport.preview(of: data, fileName: "deck", existing: [], created: created)
            let cards = preview.candidates.map(\.card)
            #expect(cards.map(\.question) == wordCards.map(\.question))
            #expect(cards.map(\.answer) == wordCards.map(\.answer))
            #expect(cards.map(\.hint) == wordCards.map(\.hint))
            #expect(cards.map(\.note) == wordCards.map(\.note))
            #expect(cards.map(\.kind) == wordCards.map(\.kind))
            #expect(preview.skippedRows == 0)
        }
    }

    /// The share sheet gets a file named after the deck, written when it asks.
    @Test func shareFileIsNamedAfterTheDeckAndHoldsTheTSV() throws {
        let export = DeckExport(name: "Greek A2", cards: wordCards, calendar: calendar)
        let url = try export.write()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        #expect(url.lastPathComponent == "Greek A2.tsv")
        #expect(try Data(contentsOf: url) == CardExport.data(of: wordCards, format: .tsv, includingLearningState: false, calendar: calendar))
    }

    // MARK: Import

    /// A TSV of Anki's own kind: header lines and no word key or kind.
    @Test func readsAnAnkiTextFile() {
        let text = "\u{FEFF}#separator:tab\n#html:false\n#columns:Front\tBack\ndom\tHaus\nkot\tKatze\n"
        let preview = CardImport.preview(of: Data(text.utf8), fileName: "anki.txt", existing: [], created: created)
        #expect(preview.candidates.map(\.card.question) == ["dom", "kot"])
        #expect(preview.candidates.map(\.card.note) == [nil, nil])
        #expect(preview.skippedRows == 0)
    }

    @Test func previewFlagsDuplicatesAndCountsSkippedRows() {
        let existing = [Card(text: CardText(question: "dom", answer: "Heim")!, created: created)]
        let file = "dom;Haus\nkot;Katze\nKot;Kater\nmysz;\n;Maus\npies;Hund\n"
        let preview = CardImport.preview(of: Data(file.utf8), fileName: "x.csv", existing: existing, created: created)
        #expect(preview.candidates.count == 4)
        #expect(preview.skippedRows == 2)
        #expect(preview.candidates.map(\.duplicate) == [.inDeck, nil, .inFile(question: "kot", answer: "Katze"), nil])
        #expect(preview.selectedCards.map(\.question) == ["kot", "pies"])
    }

    @Test func titlesOfOlderExportsAreHeadersInEveryLanguage() {
        #expect(CardImport.isHeader(["Question", "Answer", "Hint"]))
        #expect(CardImport.isHeader(["Frage", "Antwort", "Hinweis"]))
        #expect(!CardImport.isHeader(["Front", "Back"]))
        #expect(!CardImport.isHeader(["dom", "Haus"]))
    }

    @Test func addingTheCheckedCardsIsOneUndoStep() throws {
        let existing = Card(text: CardText(question: "dom", answer: "Heim")!, created: created)
        let (document, undoManager) = try makeDocument([existing])
        let file = "dom;Haus\nkot;Katze\npies;Hund\nmysz;Maus\n"
        let preview = CardImport.preview(of: Data(file.utf8), fileName: "x.csv", existing: document.deck.cards, created: created)
        // The learner checks the duplicate and unchecks one card.
        preview.selection.formUnion(preview.candidates.map(\.id))
        preview.selection.remove(preview.candidates[2].id)

        undoManager.beginUndoGrouping()
        document.importCards(preview.selectedCards)
        undoManager.endUndoGrouping()

        #expect(document.deck.cards.map(\.question) == ["dom", "dom", "kot", "mysz"])
        #expect(undoManager.undoActionName == String(localized: "Import Cards"))
        undoManager.undo()
        #expect(document.deck.cards == [existing])
        #expect(!undoManager.canUndo)
    }

    @Test func theFilePickedIsReadWhole() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "words.tsv")
        try Data("dom\tHaus\n".utf8).write(to: url)

        let file = try ImportedFile(contentsOf: url)
        #expect(file.name == "words.tsv")
        #expect(file.data == Data("dom\tHaus\n".utf8))
        #expect(throws: (any Error).self) { try ImportedFile(contentsOf: folder.appending(path: "missing.tsv")) }
    }
}
