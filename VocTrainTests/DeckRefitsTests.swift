import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// The automatic refit of the parameters on the iPhone (`DeckRefits`): a deck that is due is
/// read from its file, fitted, changed through a document and saved; anything else is left as
/// the file has it.
@MainActor @Suite(.timeLimit(.minutes(3)))
struct DeckRefitsTests {
    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// 250 cards that were all forgotten three days after their first review and then recalled
    /// the day after, started over ten days so that the newest reviews hold both: 500 usable
    /// reviews, which the default parameters predict badly, so a fit beats them by far.
    func forgetfulDeck(cards count: Int = 250, options: LearningOptions = LearningOptions()) throws -> Deck {
        let noon = Date(timeIntervalSince1970: 1_791_201_600)
        let cards = (0..<count).map { index -> Card in
            let steps: [(days: Int, grade: Grade)] = [(0, .good), (3, .again), (4, .good)]
            let log = steps.map { ReviewLogEntry(date: noon.addingTimeInterval(Double(index % 10 + $0.days) * 86400 + Double(index)), grade: $0.grade) }
            let state = LearningState(phase: .review, stability: 3, difficulty: 5, lastReview: log[2].date, due: log[2].date, reviews: 3)
            return Card(question: "q\(index)", answer: "a", created: noon, learningState: state, log: log)
        }
        return try Deck(learningOptions: options, cards: cards)
    }

    @discardableResult
    func write(_ deck: Deck, named name: String = "Polish.mnemit") throws -> URL {
        let url = directory.appending(path: name, directoryHint: .isDirectory)
        try DeckFile.fileWrapper(for: deck).write(to: url, options: .atomic, originalContentsURL: nil)
        return url
    }

    func saved(_ url: URL) throws -> Deck {
        try DeckFile.decode(FileWrapper(url: url, options: .immediate))
    }

    @Test func aDueDeckIsFittedAndSavedWithTheNoteOfTheFit() async throws {
        let url = try write(forgetfulDeck())
        await DeckRefits.run([url]) { true }

        let options = try saved(url).learningOptions
        let fit = try #require(options.lastAutoFit)
        #expect(fit.adopted)
        #expect(fit.reviewCount == 500)
        #expect(options.parameters != .default)
        #expect(options.updatesParametersAutomatically)
    }

    @Test func aDeckThatIsNotDueOrSwitchedOffStaysAsItIs() async throws {
        let few = try write(forgetfulDeck(cards: 50), named: "Few.mnemit")
        var off = LearningOptions()
        off.updatesParametersAutomatically = false
        let switchedOff = try write(forgetfulDeck(options: off), named: "Off.mnemit")
        var recent = LearningOptions()
        recent.lastAutoFit = LearningOptions.AutoFit(date: .now.addingTimeInterval(-86400), reviewCount: 400, adopted: false)
        let fitted = try write(forgetfulDeck(options: recent), named: "Recent.mnemit")
        let before = try [few, switchedOff, fitted].map(saved)

        await DeckRefits.run([few, switchedOff, fitted]) { true }

        #expect(try [few, switchedOff, fitted].map(saved) == before)
    }

    @Test func nothingIsFittedWhileTheScreenIsBusy() async throws {
        let url = try write(forgetfulDeck())
        let before = try saved(url)
        await DeckRefits.run([url]) { false }
        #expect(try saved(url) == before)
    }

    @Test func aDeckThatCantBeReadIsSkippedAndTheNextOneFitted() async throws {
        let broken = directory.appending(path: "Broken.mnemit", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: broken, withIntermediateDirectories: true)
        let url = try write(forgetfulDeck())

        await DeckRefits.run([broken, url]) { true }

        #expect(try saved(url).learningOptions.lastAutoFit != nil)
    }
}
