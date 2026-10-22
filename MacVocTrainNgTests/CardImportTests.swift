import Foundation
import Testing
import VocabCore

@testable import MacVocTrain

@MainActor
struct CardImportTests {
    let calendar = StudyCalendar.testing
    let created = Date(timeIntervalSince1970: 1_791_216_000)

    @Test func recognisesHeadersInEveryLanguage() {
        #expect(CardImport.isHeader(["Question", "Answer", "Hint"]))
        #expect(CardImport.isHeader([" question ", "ANSWER"]))
        #expect(CardImport.isHeader(["Frage", "Antwort", "Hinweis", "Reifegrad"]))
        #expect(!CardImport.isHeader(["dom", "Haus"]))
        #expect(!CardImport.isHeader(["Question"]))
    }

    @Test func readsAnExportBack() {
        let cards = [
            Card(question: "dom", answer: "Haus, Heim"),
            Card(question: "kot", answer: "Katze", hint: "Tier \"miau\""),
            Card(text: CardText(question: "pies", answer: "Hund")!, note: "pies#", kind: .production, created: created),
        ]
        for format in CardExport.Format.allCases {
            for includingLearningState in [false, true] {
                let data = CardExport.data(of: cards, format: format, includingLearningState: includingLearningState, calendar: calendar)
                let preview = CardImport.preview(of: data, fileName: "x", existing: [], created: created)
                #expect(preview.candidates.map(\.card.question) == ["dom", "kot", "pies"])
                #expect(preview.candidates.map(\.card.answer) == ["Haus, Heim", "Katze", "Hund"])
                #expect(preview.candidates.map(\.card.hint) == ["", "Tier \"miau\"", ""])
                #expect(preview.candidates.map(\.card.note) == [nil, nil, "pies#"])
                #expect(preview.candidates.map(\.card.kind) == [nil, nil, .production])
                #expect(preview.skippedRows == 0)
            }
        }
    }

    /// Exports before the header lines had a row of titles instead, three columns and the
    /// learning state.
    @Test func readsAnOlderExportWithATitleRow() {
        let data = Data("Frage;Antwort;Hinweis;Reifegrad\ndom;Haus;;Neu\n".utf8)
        let preview = CardImport.preview(of: data, fileName: "x", existing: [], created: created)
        #expect(preview.candidates.map(\.card.question) == ["dom"])
        #expect(preview.skippedRows == 0)
    }

    @Test func duplicatesStartOutUnselected() {
        let data = Data("dom;Haus\nkot;Katze\nKot;Kater\npies;Hund\n".utf8)
        let preview = CardImport.preview(of: data, fileName: "x", existing: [Card(question: "dom", answer: "Heim")], created: created)
        #expect(preview.selectedCards.map(\.answer) == ["Katze", "Hund"])

        preview.selection = Set(preview.candidates.map(\.id))
        #expect(preview.selectedCards.map(\.answer) == ["Haus", "Katze", "Kater", "Hund"])
    }
}
