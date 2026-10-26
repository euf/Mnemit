import Foundation
import Testing
import VocabCore

@testable import MacVocTrain

@MainActor
struct CardTableTests {
    let cards = [
        Card(question: "kot", answer: "Katze"),
        Card(question: "dzień", answer: "Tag"),
        Card(question: "dom", answer: "Haus"),
    ]
    let calendar = StudyCalendar(timeZone: TimeZone(identifier: "UTC")!)
    var basis: RecallBasis { RecallBasis(options: LearningOptions(), calendar: calendar, now: today) }
    let today = Date(timeIntervalSince1970: 1_800_000_000)
    let deckOrder = [KeyPathComparator(\CardRow.position)]
    let byQuestion = [KeyPathComparator(\CardRow.question)]

    @Test func keepsDeckOrderByDefault() {
        let rows = CardTable().rows(of: cards, sortedBy: deckOrder, matching: "", recall: basis)
        #expect(rows.map(\.question) == ["kot", "dzień", "dom"])
        #expect(rows.map(\.position) == [0, 1, 2])
    }

    @Test func searchKeepsTheSortOrder() {
        let table = CardTable()
        #expect(table.rows(of: cards, sortedBy: byQuestion, matching: "", recall: basis).map(\.question) == ["dom", "dzień", "kot"])
        #expect(table.rows(of: cards, sortedBy: byQuestion, matching: "d", recall: basis).map(\.question) == ["dom", "dzień"])
        #expect(table.rows(of: cards, sortedBy: byQuestion, matching: "DZIEN", recall: basis).map(\.question) == ["dzień"])
        #expect(table.rows(of: cards, sortedBy: byQuestion, matching: "", recall: basis).count == 3)
    }

    @Test func followsChangedSortOrder() {
        let table = CardTable()
        _ = table.rows(of: cards, sortedBy: byQuestion, matching: "", recall: basis)
        let reversed = [KeyPathComparator(\CardRow.question, order: .reverse)]
        #expect(table.rows(of: cards, sortedBy: reversed, matching: "", recall: basis).map(\.question) == ["kot", "dzień", "dom"])
        #expect(table.rows(of: cards, sortedBy: deckOrder, matching: "", recall: basis).map(\.question) == ["kot", "dzień", "dom"])
    }

    @Test func followsChangedCards() {
        let table = CardTable()
        #expect(table.rows(of: cards, sortedBy: byQuestion, matching: "haus", recall: basis).map(\.question) == ["dom"])

        var changed = cards
        changed[2] = changed[2].withAnswer("Heim")
        changed.append(Card(question: "chata", answer: "Haus"))
        #expect(table.rows(of: changed, sortedBy: byQuestion, matching: "haus", recall: basis).map(\.question) == ["chata"])
        #expect(table.rows(of: changed, sortedBy: byQuestion, matching: "", recall: basis).map(\.position) == [3, 2, 1, 0])
    }

    /// The Kind column sorts recognition cards before production cards, cards without a kind
    /// last, and a card's edit of its kind moves its row.
    @Test func sortsByKind() {
        let kinds = [
            Card(question: "a", answer: "1", note: "a", kind: .production),
            Card(question: "b", answer: "2"),
            Card(question: "c", answer: "3", note: "c", kind: .recognition),
            Card(question: "d", answer: "4", note: "d", kind: .production),
        ]
        let table = CardTable()
        let ascending = [KeyPathComparator(\CardRow.kindRank)]
        let rows = table.rows(of: kinds, sortedBy: ascending, matching: "", recall: basis)
        #expect(rows.map(\.question) == ["c", "a", "d", "b"])
        #expect(rows.map(\.kind) == [.recognition, .production, .production, nil])

        let descending = [KeyPathComparator(\CardRow.kindRank, order: .reverse)]
        #expect(table.rows(of: kinds, sortedBy: descending, matching: "", recall: basis).map(\.question) == ["b", "a", "d", "c"])

        var changed = kinds
        changed[1] = Card(id: kinds[1].id, question: "b", answer: "2", note: "b", kind: .recognition)
        #expect(table.rows(of: changed, sortedBy: ascending, matching: "", recall: basis).map(\.question) == ["b", "c", "a", "d"])
    }

    /// The word key is searched like the texts, in the table too.
    @Test func searchFindsTheWordKey() {
        let cards = [Card(question: "lieben", answer: "αγαπώ", note: "agapo", kind: .production), Card(question: "Katze", answer: "γάτα")]
        #expect(CardTable().rows(of: cards, sortedBy: deckOrder, matching: "AGAPO", recall: basis).map(\.question) == ["lieben"])
    }

    @Test func equalValuesKeepDeckOrder() {
        let twins = [
            Card(question: "b", answer: "1"),
            Card(question: "a", answer: "2"),
            Card(question: "b", answer: "3"),
            Card(question: "a", answer: "4"),
        ]
        let table = CardTable()
        #expect(table.rows(of: twins, sortedBy: byQuestion, matching: "", recall: basis).map(\.answer) == ["2", "4", "1", "3"])

        var changed = twins
        changed[0] = changed[0].withAnswer("5")
        changed.insert(Card(question: "a", answer: "6"), at: 0)
        #expect(table.rows(of: changed, sortedBy: byQuestion, matching: "", recall: basis).map(\.answer) == ["6", "2", "4", "5", "3"])
    }

    @Test func undoneDeletionReturnsToItsPlace() {
        let table = CardTable()
        _ = table.rows(of: cards, sortedBy: byQuestion, matching: "", recall: basis)
        _ = table.rows(of: [cards[0], cards[2]], sortedBy: byQuestion, matching: "", recall: basis)
        #expect(table.rows(of: cards, sortedBy: byQuestion, matching: "", recall: basis).map(\.position) == [2, 1, 0])
    }

    /// Lapses, Stability, Difficulty and Recall sort by their values; a new card has none, shows
    /// nothing and comes first, as in Due.
    @Test func sortsByMemory() {
        func studied(_ question: String, stability: Double, difficulty: Double, lapses: Int, daysAgo: Double) -> Card {
            let lastReview = today.addingTimeInterval(-daysAgo * 86_400)
            return Card(
                question: question, answer: question,
                learningState: LearningState(
                    phase: .review, stability: stability, difficulty: difficulty, lastReview: lastReview, due: today, reviews: 5, lapses: lapses))
        }
        let cards = [
            studied("a", stability: 10, difficulty: 3, lapses: 2, daysAgo: 10),
            Card(question: "n", answer: "n"),
            studied("b", stability: 100, difficulty: 8, lapses: 0, daysAgo: 10),
            studied("c", stability: 5, difficulty: 6, lapses: 9, daysAgo: 30),
            studied("d", stability: 50, difficulty: 1, lapses: 3, daysAgo: 200),
        ]
        let table = CardTable()
        func order(_ order: [KeyPathComparator<CardRow>]) -> String {
            table.rows(of: cards, sortedBy: order, matching: "", recall: basis).map(\.question).joined()
        }
        #expect(order([KeyPathComparator(\CardRow.lapses)]) == "nbadc")
        #expect(order([KeyPathComparator(\CardRow.stability)]) == "ncadb")
        #expect(order([KeyPathComparator(\CardRow.difficulty)]) == "ndacb")
        #expect(order([KeyPathComparator(\CardRow.recall)]) == "ncdab")
        #expect(order([KeyPathComparator(\CardRow.lapses, order: .reverse)]) == "cdabn")

        let rows = table.rows(of: cards, sortedBy: deckOrder, matching: "", recall: basis)
        #expect(rows.map(\.hasMemory) == [true, false, true, true, true])
        #expect(abs(rows[0].recall - 0.9) < 1e-9 && rows[0].lapses == 2 && rows[0].stability == 10 && rows[0].difficulty == 3)
    }

    /// Recall moves with the study day: the same cards get new values when the day turns.
    @Test func recallFollowsTheStudyDay() {
        let card = Card(
            question: "a", answer: "a",
            learningState: LearningState(phase: .review, stability: 10, difficulty: 5, lastReview: today, due: today))
        let table = CardTable()
        let before = table.rows(of: [card], sortedBy: deckOrder, matching: "", recall: basis)[0].recall
        let sameDay = RecallBasis(options: LearningOptions(), calendar: calendar, now: today.addingTimeInterval(3600))
        #expect(table.rows(of: [card], sortedBy: deckOrder, matching: "", recall: sameDay)[0].recall == before)
        let nextDay = RecallBasis(options: LearningOptions(), calendar: calendar, now: today.addingTimeInterval(10 * 86_400))
        let after = table.rows(of: [card], sortedBy: deckOrder, matching: "", recall: nextDay)[0].recall
        #expect(before > after)
        #expect(abs(after - 0.9) < 1e-9)
    }

    /// Edits, insertions and removals sorted in step by step give the same rows as
    /// sorting from scratch.
    @Test(arguments: [
        [KeyPathComparator(\CardRow.question)],
        [KeyPathComparator(\CardRow.answer, order: .reverse)],
        [KeyPathComparator(\CardRow.categoryRank), KeyPathComparator(\CardRow.question)],
        [KeyPathComparator(\CardRow.position, order: .reverse)],
    ])
    func stepwiseSortingMatchesFullSort(order: [KeyPathComparator<CardRow>]) throws {
        var random = SeededRandom(seed: 21)
        let words = ["dom", "Dom", "dzień", "dzien", "kot", "Kot", "a", "b", "żaba", "zebra", "10", "9"]
        func makeCard() -> Card {
            let question = words.randomElement(using: &random)!
            let answer = words.randomElement(using: &random)!
            var learningState: LearningState?
            if Bool.random(using: &random) {
                learningState = LearningState(
                    phase: .review, stability: .random(in: 0.5...300, using: &random), difficulty: 5,
                    lastReview: Date(), due: Date()
                )
            }
            return Card(question: question, answer: answer, learningState: learningState)
        }

        var deck = (0..<40).map { _ in makeCard() }
        let table = CardTable()
        _ = table.rows(of: deck, sortedBy: order, matching: "", recall: basis)
        for _ in 0..<100 {
            for _ in 0..<Int.random(in: 1...3, using: &random) {
                switch Int.random(in: 0..<4, using: &random) {
                case 0 where !deck.isEmpty:
                    deck.remove(at: Int.random(in: deck.indices, using: &random))
                case 1:
                    deck.insert(makeCard(), at: Int.random(in: 0...deck.count, using: &random))
                case 2 where !deck.isEmpty:
                    let position = Int.random(in: deck.indices, using: &random)
                    let replacement = makeCard()
                    deck[position] = Card(
                        id: deck[position].id,
                        question: replacement.question,
                        answer: deck[position].answer,
                        learningState: replacement.learningState
                    )
                default:
                    deck.append(makeCard())
                }
            }
            let stepwise = table.rows(of: deck, sortedBy: order, matching: "", recall: basis).map(\.position)
            let full = CardTable().rows(of: deck, sortedBy: order, matching: "", recall: basis).map(\.position)
            try #require(stepwise == full)
        }
    }

    /// Cards changed in place, as by an edit or a review, give the same rows as
    /// building the table from scratch (#232).
    @Test(arguments: [
        ([KeyPathComparator(\CardRow.position)], ""),
        ([KeyPathComparator(\CardRow.question)], ""),
        ([KeyPathComparator(\CardRow.answer, order: .reverse)], ""),
        ([KeyPathComparator(\CardRow.question)], "o"),
        ([KeyPathComparator(\CardRow.categoryRank), KeyPathComparator(\CardRow.answer)], "ze"),
    ])
    func editsInPlaceMatchFullRebuild(order: [KeyPathComparator<CardRow>], query: String) throws {
        var random = SeededRandom(seed: 232)
        let words = ["dom", "Dom", "dzień", "dzien", "kot", "Kot", "a", "b", "żaba", "zebra", "10", "9"]
        func word() -> String { words.randomElement(using: &random)! }
        func describe(_ rows: [CardRow]) -> [String] {
            rows.map { "\($0.position) \($0.question) \($0.answer) \($0.hint) \($0.categoryRank)" }
        }

        var deck = (0..<40).map { _ in Card(question: word(), answer: word(), hint: word()) }
        let table = CardTable()
        _ = table.rows(of: deck, sortedBy: order, matching: query, recall: basis)
        for _ in 0..<100 {
            for _ in 0..<Int.random(in: 1...2, using: &random) {
                let position = Int.random(in: deck.indices, using: &random)
                let card = deck[position]
                switch Int.random(in: 0..<4, using: &random) {
                case 0: deck[position] = Card(id: card.id, question: word(), answer: card.answer, hint: card.hint)
                case 1: deck[position] = card.withAnswer(card.answer + word())
                case 2: deck[position] = Card(id: card.id, question: card.question, answer: card.answer, hint: word())
                default:
                    let learningState = LearningState(
                        phase: .review, stability: .random(in: 0.5...300, using: &random), difficulty: 5, lastReview: Date(), due: Date()
                    )
                    deck[position] = Card(id: card.id, question: card.question, answer: card.answer, hint: card.hint, learningState: learningState)
                }
            }
            let stepwise = describe(table.rows(of: deck, sortedBy: order, matching: query, recall: basis))
            let full = describe(CardTable().rows(of: deck, sortedBy: order, matching: query, recall: basis))
            try #require(stepwise == full)
        }
    }

    /// Time of `rows(of:sortedBy:matching:)` per edit while the text of one card of 5000
    /// is edited again and again (#232). Prints the median and has no time limit. Runs
    /// only with `CARD_TABLE_MEASURE` set; through `xcodebuild`, set
    /// `TEST_RUNNER_CARD_TABLE_MEASURE=1`, best with `-configuration Release`.
    @Test(
        .enabled(if: ProcessInfo.processInfo.environment["CARD_TABLE_MEASURE"] != nil),
        arguments: [("unsorted", [KeyPathComparator(\CardRow.position)], ""), ("by question", [KeyPathComparator(\CardRow.question)], ""), ("by question, search", [KeyPathComparator(\CardRow.question)], "ka")]
    )
    func measureEdits(name: String, order: [KeyPathComparator<CardRow>], query: String) {
        var random = SeededRandom(seed: 232)
        let letters = Array("abcdefghijklmnoprstuwyzłóżćęąś")
        func word() -> String {
            String((0..<Int.random(in: 3...10, using: &random)).map { _ in letters.randomElement(using: &random)! })
        }
        var deck = (0..<5000).map { _ in Card(question: word(), answer: word() + " " + word(), hint: word()) }
        let table = CardTable()
        _ = table.rows(of: deck, sortedBy: order, matching: query, recall: basis)

        var durations: [Duration] = []
        for edit in 0..<50 {
            let edited = deck[2500]
            deck[2500] = edited.withAnswer(edited.answer + String(letters[edit % letters.count]))
            durations.append(ContinuousClock().measure { _ = table.rows(of: deck, sortedBy: order, matching: query, recall: basis) })
        }
        let median = durations.sorted()[durations.count / 2]
        print("CardTable, 5000 cards, \(name): \(median.formatted(.units(allowed: [.milliseconds], fractionalPart: .show(length: 2)))) per edit (median)")
    }
}
