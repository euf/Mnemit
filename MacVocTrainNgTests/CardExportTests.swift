import Foundation
import Testing
import VocabCore

@testable import MacVocTrain

@MainActor
struct CardExportTests {
    let calendar = StudyCalendar.testing
    let created = Date(timeIntervalSince1970: 1_791_216_000)

    private var studied: Card {
        let due = calendar.start(ofDay: CivilDate(year: 2026, month: 10, day: 9).dayNumber)
        let learningState = LearningState(phase: .review, stability: 6, difficulty: 5, lastReview: due.addingTimeInterval(-6 * 86400), due: due, reviews: 4)
        return Card(question: "kot", answer: "Katze", hint: "Tier", learningState: learningState)
    }

    @Test func exportsQuestionAnswerHintWordKeyAndKind() {
        let word = Card(text: CardText(question: "kot", answer: "Katze")!, note: "kot#", kind: .recognition, created: created)
        let rows = CardExport.rows(of: [Card(question: "dom", answer: "Haus"), studied, word], includingLearningState: false, calendar: calendar)
        #expect(
            rows == [
                ["dom", "Haus", "", "", ""],
                ["kot", "Katze", "Tier", "", ""],
                ["kot", "Katze", "", "kot#", "recognition"],
            ])
    }

    @Test func learningStateAddsReadableColumns() {
        let rows = CardExport.rows(of: [Card(question: "dom", answer: "Haus"), studied], includingLearningState: true, calendar: calendar)
        #expect(CardExport.columns(includingLearningState: true).suffix(3) == ["Maturity", "Due", "Reviews"])
        #expect(rows[0].suffix(3) == [MaturityCategory.new.title, "", "0"])
        #expect(rows[1].suffix(3) == [MaturityCategory.young.title, "2026-10-09", "4"])
    }

    @Test func fileIsUTF8WithByteOrderMarkAndAnkiHeaderLines() {
        let data = CardExport.data(of: [Card(question: "dzień", answer: "Tag")], format: .tsv, includingLearningState: false, calendar: calendar)
        #expect(data.starts(with: [0xEF, 0xBB, 0xBF]))
        let text = String(decoding: data.dropFirst(3), as: UTF8.self)
        #expect(text == "#separator:tab\r\n#html:false\r\n#columns:Front\tBack\tHint\tWord Key\tKind\r\ndzień\tTag\t\t\t\r\n")
    }

    @Test func csvHasItsOwnSeparatorLine() {
        let data = CardExport.data(of: [Card(question: "dzień", answer: "Tag")], format: .csv, includingLearningState: true, calendar: calendar)
        let text = String(decoding: data.dropFirst(3), as: UTF8.self)
        #expect(text.hasPrefix("#separator:comma\r\n#html:false\r\n#columns:Front,Back,Hint,Word Key,Kind,Maturity,Due,Reviews\r\n"))
    }
}
