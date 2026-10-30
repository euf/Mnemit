import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// What the card browser lists: the six filters, the four sorts, the search and the state at
/// the right of a row, without a screen.
@MainActor
struct CardBrowserListTests {
    let now = Date(timeIntervalSince1970: 1_792_000_000)
    let created = Date(timeIntervalSince1970: 1_791_216_000)
    let threshold = 8

    func state(_ phase: LearningPhase, due: TimeInterval, difficulty: Double = 5, lapses: Int = 0) -> LearningState {
        LearningState(
            phase: phase, stability: 6, difficulty: difficulty, lastReview: now.addingTimeInterval(-86_400), due: now.addingTimeInterval(due),
            reviews: 3, lapses: lapses)
    }

    func card(
        _ question: String, answer: String = "x", note: String? = nil, learning: LearningState? = nil, suspended: Bool = false,
        created: Date? = nil
    ) -> Card {
        Card(
            question: question, answer: answer, note: note, created: created ?? self.created, learningState: learning, isSuspended: suspended)
    }

    /// One card for every place a card can be.
    var cards: [Card] {
        [
            card("new"),
            card("learning now", learning: state(.learning, due: -60)),
            card("relearning later", learning: state(.relearning, due: 3600)),
            card("review due", learning: state(.review, due: -3600)),
            card("review later", learning: state(.review, due: 5 * 86_400)),
            card("suspended new", suspended: true),
            card("suspended leech", learning: state(.review, due: -60, lapses: 9), suspended: true),
            card("leech", learning: state(.review, due: 86_400, lapses: 8)),
        ]
    }

    func questions(_ filter: CardFilter) -> [String] {
        cards.filter { filter.matches($0, at: now, leechThreshold: threshold) }.map(\.question)
    }

    // MARK: Filters

    @Test func theFiltersHoldTheirCards() {
        #expect(questions(.all).count == 8)
        // Due: studied, and the date has come; the new cards are New.
        #expect(questions(.due) == ["learning now", "review due"])
        #expect(questions(.new) == ["new"])
        #expect(questions(.learning) == ["learning now", "relearning later"])
        #expect(questions(.suspended) == ["suspended new", "suspended leech"])
        // Leeches is what the leech rule says, suspended or not.
        #expect(questions(.leeches) == ["suspended leech", "leech"])
    }

    @Test func aSuspendedCardIsInNoFilterButAllSuspendedAndLeeches() {
        let suspended = card("s", learning: state(.learning, due: -60, lapses: 9), suspended: true)
        let holding = CardFilter.allCases.filter { $0.matches(suspended, at: now, leechThreshold: threshold) }
        #expect(holding == [.all, .suspended, .leeches])
    }

    @Test func aThresholdOfZeroHasNoLeeches() {
        #expect(cards.filter { CardFilter.leeches.matches($0, at: now, leechThreshold: 0) }.isEmpty)
    }

    @Test func theCountsAreThoseOfTheFilters() throws {
        let counts = try Deck(cards: cards).filterCounts(at: now)
        for filter in CardFilter.allCases {
            #expect(counts[filter] == questions(filter).count, "\(filter)")
        }
    }

    // MARK: Sorts

    func shown(_ cards: [Card], filter: CardFilter = .all, sort: BrowserSort, positions: Set<Int>? = nil) -> [String] {
        CardBrowserList.shown(cards, filter: filter, sort: sort, positions: positions, leechThreshold: threshold, now: now).map(\.question)
    }

    @Test func dueComesNewFirstThenByDateAndSuspendedLast() {
        #expect(
            shown(cards, sort: .due) == [
                "new", "review due", "learning now", "relearning later", "leech", "review later", "suspended new", "suspended leech",
            ])
    }

    @Test func addedPutsTheNewestFirstAndKeepsDeckOrderForEqualOnes() {
        let list = [
            card("old", created: created),
            card("pair a", created: created.addingTimeInterval(86_400)),
            card("pair b", created: created.addingTimeInterval(86_400)),
            card("newest", created: created.addingTimeInterval(2 * 86_400)),
        ]
        #expect(shown(list, sort: .added) == ["newest", "pair a", "pair b", "old"])
    }

    @Test func alphabeticalIgnoresCaseAndAccents() {
        let list = [card("βήτα"), card("Άλφα"), card("άλφα δ"), card("Alpha"), card("beta")]
        // Latin letters sort before Greek ones.
        #expect(shown(list, sort: .alphabetical) == ["Alpha", "beta", "Άλφα", "άλφα δ", "βήτα"])
    }

    @Test func alphabeticalSortsAWordUnderItsFirstLetterNotItsArticle() {
        let list = [card("το σπίτι"), card("η θάλασσα"), card("ο δρόμος"), card("βάζω"), card("η στάση")]
        #expect(shown(list, sort: .alphabetical) == ["βάζω", "ο δρόμος", "η θάλασσα", "το σπίτι", "η στάση"])
    }

    @Test func aDueCardSaysDueWhereANewOneSaysNew() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        #expect(BrowserState.due(now.addingTimeInterval(-60)).text(now: now) == String(localized: "Due"))
        #expect(BrowserState.new.text(now: now) == String(localized: "New"))
    }

    @Test func difficultyPutsTheHardestFirstAndNewCardsLast() {
        let list = [
            card("easy", learning: state(.review, due: 0, difficulty: 2)),
            card("new"),
            card("hard", learning: state(.review, due: 0, difficulty: 9)),
            card("middle", learning: state(.review, due: 0, difficulty: 5)),
        ]
        #expect(shown(list, sort: .difficulty) == ["hard", "middle", "easy", "new"])
    }

    @Test func lapsesPutTheMostForgottenFirstAndNewCardsLast() {
        let list = [
            card("two", learning: state(.review, due: 0, lapses: 2)),
            card("new"),
            card("nine", learning: state(.review, due: 0, lapses: 9)),
            card("none", learning: state(.review, due: 0)),
            card("two too", learning: state(.review, due: 0, lapses: 2)),
        ]
        #expect(shown(list, sort: .lapses) == ["nine", "two", "two too", "none", "new"])
    }

    // MARK: Search

    @Test func aSearchNarrowsWhatTheFilterHoldsIgnoringCaseAccentsAndTheWordKey() {
        let list = [
            card("το σπίτι", answer: "дом · the house", note: "σπίτι|house"),
            card("the house", answer: "το σπίτι", note: "σπίτι|house"),
            card("ο Άγγλος", answer: "англичанин"),
            card("η μητέρα", answer: "мать", learning: state(.review, due: -60)),
        ]
        let index = CardSearchIndex(cards: list)
        func search(_ query: String, _ filter: CardFilter = .all) -> [String] {
            shown(list, filter: filter, sort: .alphabetical, positions: Set(index.positions(matching: query)))
        }
        #expect(search("σπιτι") == ["the house", "το σπίτι"])
        #expect(search("ΑΓΓΛΟΣ") == ["ο Άγγλος"])
        // Only the word key has the bar.
        #expect(search("σπιτι|house") == ["the house", "το σπίτι"])
        #expect(search("μητέρα", .due) == ["η μητέρα"])
        #expect(search("μητέρα", .new).isEmpty)
        #expect(search("zzz").isEmpty)
    }

    // MARK: State

    @Test func aRowSaysSuspendedBeforeLeechBeforeNewBeforeTheDate() {
        let due = now.addingTimeInterval(3 * 86_400)
        #expect(BrowserState(card("a", learning: state(.review, due: 0, lapses: 9), suspended: true), leechThreshold: threshold) == .suspended)
        #expect(BrowserState(card("b", learning: state(.review, due: 0, lapses: 9)), leechThreshold: threshold) == .leech)
        #expect(BrowserState(card("c"), leechThreshold: threshold) == .new)
        #expect(BrowserState(card("d", learning: state(.review, due: 3 * 86_400)), leechThreshold: threshold) == .due(due))
        #expect(BrowserState.new.symbol == nil)
        #expect(BrowserState.due(due).symbol == nil)
        #expect(BrowserState.suspended.symbol != nil)
        #expect(BrowserState.due(due).text(now: now) == Format.due(due, now: now))
    }

    // MARK: Memo

    @Test func theMemoAnswersTheSameInputOnceAndNewInputAgain() throws {
        let memo = CardBrowserMemo()
        let list = cards
        let first = try memo.output(deck: Deck(cards: list), filter: .due, sort: .alphabetical, query: "", now: now)
        #expect(first.rows.map(\.question) == ["learning now", "review due"])
        #expect(first.counts[.all] == 8)

        // A query with blanks around it is the query without them.
        let searched = try memo.output(deck: Deck(cards: list), filter: .all, sort: .alphabetical, query: "  LEECH ", now: now)
        #expect(searched.rows.map(\.question) == ["leech", "suspended leech"])

        // A card that changed is in the new answer, with a new index.
        var changed = list
        changed[0] = card("leech new")
        let again = try memo.output(deck: Deck(cards: changed), filter: .all, sort: .alphabetical, query: "leech", now: now)
        #expect(again.rows.map(\.question) == ["leech", "leech new", "suspended leech"])
    }
}
