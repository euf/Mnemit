import Foundation
import Testing
import VocabCore

struct CardImporterTests {
    let created = Date(timeIntervalSince1970: 1_791_216_000)

    private func candidates(_ rows: [[String]], existing: [Card] = [], header: Bool = false) -> CardImporter.Result {
        CardImporter.candidates(from: rows, existing: existing, isHeader: { _ in header }, created: created)
    }

    @Test func readsQuestionAnswerAndHint() {
        let result = candidates([[" dom ", "Haus"], ["kot", "Katze", "Tier", "Jung", "2026-10-09", "4"]])
        #expect(result.candidates.map(\.card.question) == ["dom", "kot"])
        #expect(result.candidates.map(\.card.answer) == ["Haus", "Katze"])
        #expect(result.candidates.map(\.card.hint) == ["", "Tier"])
        #expect(result.candidates.allSatisfy { $0.card.isNew && $0.card.created == created })
    }

    @Test func skipsHeaderAndIncompleteRows() {
        let result = candidates([["Question", "Answer"], ["dom", ""], ["nur eine Spalte"], ["", "Haus"], ["kot", "Katze"]], header: true)
        #expect(result.candidates.map(\.card.question) == ["kot"])
        #expect(result.skippedRows == 3)
    }

    @Test func onlyTheFirstRowCanBeAHeader() {
        let rows = [["dom", "Haus"], ["Question", "Answer"]]
        let result = CardImporter.candidates(from: rows, existing: [], isHeader: { $0 == ["Question", "Answer"] }, created: created)
        #expect(result.candidates.count == 2)
    }

    @Test func readsWordKeyAndKindByTheNamesOfTheColumns() {
        let rows = [
            ["ο κλέφτης", "thief", "noun", "κλέφτης#ο", "recognition", "Young"],
            ["thief", "ο κλέφτης", "", " κλέφτης#ο ", " Production ", "New"],
            ["το σπίτι", "the house", "", "", "production", ""],
            ["η αστυνομία", "the police", "", "αστυνομία#η", "backwards", ""],
        ]
        let columns = ["Front", "Back", "Hint", "Word Key", "Kind", "Maturity"]
        let cards = CardImporter.candidates(from: rows, existing: [], isHeader: { _ in false }, created: created, columns: columns).candidates.map(\.card)
        #expect(cards.map(\.note) == ["κλέφτης#ο", "κλέφτης#ο", nil, "αστυνομία#η"])
        // A kind without a word key means nothing; one that is none of ours is left out.
        #expect(cards.map(\.kind) == [.recognition, .production, nil, nil])
        #expect(cards.map(\.hint) == ["noun", "", "", ""])
    }

    @Test func namesMayBeInAnyOrderAndLeaveOutTheHint() {
        let rows = [["Haus", "dom", "production", "dom#"]]
        let columns = ["Back", "front", "KIND", "word key"]
        let card = CardImporter.candidates(from: rows, existing: [], isHeader: { _ in false }, created: created, columns: columns).candidates[0].card
        #expect(card.question == "dom")
        #expect(card.answer == "Haus")
        #expect(card.hint == "")
        #expect(card.note == "dom#")
        #expect(card.kind == .production)
    }

    @Test func aHeaderRowNamesTheColumnsToo() {
        let rows = [["Question", "Answer", "Hint", "Word Key", "Kind"], ["dom", "Haus", "", "dom#", "recognition"]]
        let result = CardImporter.candidates(from: rows, existing: [], isHeader: { $0.first == "Question" }, created: created)
        #expect(result.candidates.count == 1)
        #expect(result.candidates[0].card.note == "dom#")
        #expect(result.candidates[0].card.kind == .recognition)
    }

    /// With names given, the first row is a card, as in Anki.
    @Test func theFirstRowIsACardWhenTheColumnsAreNamed() {
        let rows = [["Question", "Answer"], ["dom", "Haus"]]
        let result = CardImporter.candidates(from: rows, existing: [], isHeader: { _ in true }, created: created, columns: ["Front", "Back"])
        #expect(result.candidates.map(\.card.question) == ["Question", "dom"])
    }

    @Test func readsAnExportWithItsHeaderLines() {
        let rows = [["dom", "Haus", "", "dom#", "recognition"], ["Haus", "dom", "Gebäude", "dom#", "production"]]
        for delimiter in DelimitedText.Delimiter.allCases {
            let text = DelimitedText.encode(rows, delimiter: delimiter, ankiColumns: ["Front", "Back", "Hint", "Word Key", "Kind"])
            let decoded = DelimitedText.decode(Data(text.utf8))
            let result = CardImporter.candidates(from: decoded.rows, existing: [], isHeader: { _ in false }, created: created, columns: decoded.columns)
            #expect(result.skippedRows == 0)
            #expect(result.candidates.map(\.card.question) == ["dom", "Haus"])
            #expect(result.candidates.map(\.card.hint) == ["", "Gebäude"])
            #expect(result.candidates.map(\.card.note) == ["dom#", "dom#"])
            #expect(result.candidates.map(\.card.kind) == [.recognition, .production])
        }
    }

    @Test func marksDuplicates() {
        let existing = [Card(question: "Dom ", answer: "Haus")]
        let result = candidates([["dom", "Heim"], ["kot", "Katze"], ["KOT", "Kater"], ["pies", "Hund"], ["Kot ", "Kocur"]], existing: existing)
        let kot = CardImporter.Duplicate.inFile(question: "kot", answer: "Katze")
        #expect(result.candidates.map(\.duplicate) == [.inDeck, nil, kot, nil, kot])
    }

    /// Header, skipped and empty rows don't shift the reference to the earlier card (#188).
    @Test func duplicateInFileNamesTheEarlierCard() {
        let file = Data("Question;Answer\ndom;Haus\nmysz;\n\nkot;Katze\nKot;Kater\n".utf8)
        let rows = DelimitedText.decode(file).rows
        let result = CardImporter.candidates(from: rows, existing: [], isHeader: { $0 == ["Question", "Answer"] }, created: created)
        #expect(result.candidates.map(\.card.question) == ["dom", "kot", "Kot"])
        #expect(result.skippedRows == 1)
        #expect(result.candidates.map(\.duplicate) == [nil, nil, .inFile(question: "kot", answer: "Katze")])
    }
}
