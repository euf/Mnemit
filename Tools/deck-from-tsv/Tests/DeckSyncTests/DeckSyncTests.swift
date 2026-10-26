import Foundation
import Testing
import VocabCore

@testable import DeckSync

struct TSVReaderTests {
    @Test func readsNotesWithEscapesAndOptionalHint() throws {
        let tsv = "note\tkind\tquestion\tanswer\thint\nσπίτι\trecognition\tσπίτι\thouse\t\nσπίτι\tproduction\thouse\tτο σπίτι\\nΤο σπίτι είναι μεγάλο.\tnoun\n"
        let input = try TSVReader.read(Data(tsv.utf8))
        guard case let .notes(rows) = input else {
            Issue.record("expected notes")
            return
        }
        #expect(rows.map(\.kind) == [.recognition, .production])
        #expect(rows[1].text.answer == "το σπίτι\nΤο σπίτι είναι μεγάλο.")
        #expect(rows[1].text.hint == "noun")
        #expect(rows[0].text.hint == "")
        #expect(rows[1].number == 3)
    }

    @Test func headerWithoutHintColumnIsAccepted() throws {
        let tsv = "note\tkind\tquestion\tanswer\nσπίτι\tproduction\thouse\tτο σπίτι\n"
        guard case let .notes(rows) = try TSVReader.read(Data(tsv.utf8)) else {
            Issue.record("expected notes")
            return
        }
        #expect(rows.count == 1)
    }

    @Test func listsEveryBadRow() {
        let tsv = "note\tkind\tquestion\tanswer\thint\n\trecognition\ta\tb\t\nx\tlistening\ta\tb\t\nx\tproduction\t\tb\t\nx\tproduction\ta\tb\t\nx\tproduction\ta\tb\t\n"
        #expect(throws: SyncError.self) { try TSVReader.read(Data(tsv.utf8)) }
        do {
            _ = try TSVReader.read(Data(tsv.utf8))
        } catch {
            let message = "\(error)"
            #expect(message.contains("row 2: empty note"))
            #expect(message.contains("row 3: kind must be"))
            #expect(message.contains("row 4: empty question or answer"))
            #expect(message.contains("row 6: x production already in row 5"))
        }
    }

    @Test func headerlessTableStaysPlain() throws {
        let tsv = "dynamic\tδυναμικός\tδυναμικός-ή-ό\nhasty\tβιαστικός\t\n"
        guard case let .plain(rows) = try TSVReader.read(Data(tsv.utf8)) else {
            Issue.record("expected plain")
            return
        }
        #expect(rows == [["dynamic", "δυναμικός", "δυναμικός-ή-ό"], ["hasty", "βιαστικός", ""]])
    }
}

struct SyncPlanTests {
    let now = Date(timeIntervalSince1970: 1_791_216_000)

    func row(_ note: String, _ kind: CardKind, _ question: String, _ answer: String, _ hint: String = "") -> SyncRow {
        SyncRow(note: note, kind: kind, text: CardText(question: question, answer: answer, hint: hint)!, number: 2)
    }

    func old(_ question: String, _ answer: String, hint: String = "") -> Card {
        Card(text: CardText(question: question, answer: answer, hint: hint)!, created: now.addingTimeInterval(-86400))
    }

    func plan(_ rows: [SyncRow], _ cards: [Card], suspendMissing: Bool = false) throws -> SyncPlan {
        SyncPlan.make(rows: rows, deck: try Deck.make(cards), suspendMissing: suspendMissing, now: now)
    }

    @Test func versionFiveIdsFollowTheSpecification() {
        let dns = UUID(uuidString: "6BA7B810-9DAD-11D1-80B4-00C04FD430C8")!
        #expect(SyncPlan.uuidVersion5(namespace: dns, name: "python.org") == UUID(uuidString: "886313E1-3B8A-5372-9B90-0C9AEE199E5D"))
        let id = SyncPlan.cardID(note: "σπίτι", kind: .production, avoiding: [])
        #expect(id == SyncPlan.cardID(note: " σπίτι ", kind: .production, avoiding: []))
        #expect(id != SyncPlan.cardID(note: "σπίτι", kind: .recognition, avoiding: []))
        #expect(SyncPlan.cardID(note: "σπίτι", kind: .production, avoiding: [id]) != id)
    }

    @Test func newRowsBecomeCardsWithStableIds() throws {
        let rows = [row("a", .recognition, "α", "a"), row("a", .production, "a", "α")]
        let first = try plan(rows, [])
        let second = try plan(rows, [])
        #expect(first.added.map(\.id) == second.added.map(\.id))
        #expect(first.added.map(\.kind) == [.recognition, .production])
        #expect(first.added.allSatisfy { $0.created == now && $0.note == "a" && $0.isNew })
    }

    @Test func rowsMatchByNoteAndKindAndEditInPlace() throws {
        let card = Card(id: UUID(), text: CardText(question: "house", answer: "σπίτι")!, note: "σπίτι", kind: .production, created: now)
        let same = try plan([row("σπίτι", .production, "house", "σπίτι")], [card])
        #expect((same.unchanged, same.edited.count, same.added.count) == (1, 0, 0))
        let changed = try plan([row("σπίτι", .production, "house", "το σπίτι\nΤο σπίτι είναι μεγάλο.", "n")], [card])
        #expect((changed.unchanged, changed.edited.count, changed.added.count, changed.adopted.count) == (0, 1, 0, 0))
        #expect(changed.edited[0].card.id == card.id)
    }

    @Test func productionRowAdoptsTheCardTheFormerDeckStoredWithoutEndings() throws {
        let adjective = old("dynamic", "δυναμικός", hint: "δυναμικός-ή-ό · энергичный")
        let noun = old("group of friends", "η παρέα")
        let other = old("hasty", "βιαστικός")
        let rows = [
            row("δυναμικός", .production, "dynamic", "δυναμικός-ή-ό\nΕίναι δυναμικός άνθρωπος."),
            row("παρέα", .production, "group of friends", "η παρέα"),
        ]
        let adopted = try plan(rows, [adjective, noun, other])
        #expect(adopted.adopted.map(\.card.id) == [adjective.id, noun.id])
        #expect(adopted.added.isEmpty)
    }

    @Test func recognitionRowAdoptsOnlyByExactAnswer() throws {
        let adjective = old("dynamic", "δυναμικός")
        let result = try plan([row("δυναμικός", .recognition, "δυναμικός-ή-ό", "δυναμικός")], [adjective])
        #expect(result.adopted.map(\.card.id) == [adjective.id])
        let stripped = try plan([row("δυναμικός", .recognition, "δυναμικός", "δυναμικός-ή-ό")], [adjective])
        #expect(stripped.adopted.isEmpty && stripped.added.count == 1)
    }

    @Test func sameAnswerCardsAreTakenByTheRowWithTheirQuestion() throws {
        let spill = old("to spill", "ρίχνω")
        let throwing = old("to throw", "ρίχνω")
        let rows = [row("ρίχνω-2", .production, "to throw", "ρίχνω"), row("ρίχνω-1", .production, "to spill", "ρίχνω")]
        let result = try plan(rows, [spill, throwing])
        #expect(result.adopted.map(\.card.id) == [throwing.id, spill.id])
    }

    @Test func aCardIsAdoptedOnceAndNotesAreNotAdopted() throws {
        let card = old("to like", "συμπαθώ")
        let noted = Card(id: UUID(), text: CardText(question: "x", answer: "συμπαθώ")!, note: "other", kind: .production, created: now)
        let rows = [row("a", .production, "to like", "συμπαθώ"), row("b", .production, "to like", "συμπαθώ")]
        let result = try plan(rows, [card, noted])
        #expect(result.adopted.count == 1)
        #expect(result.added.count == 1)
    }

    @Test func suspendMissingTouchesCardsWithAMissingNoteAndUnadoptedOldCards() throws {
        let kept = Card(id: UUID(), text: CardText(question: "a", answer: "b")!, note: "kept", kind: .production, created: now)
        let gone = Card(id: UUID(), text: CardText(question: "c", answer: "d")!, note: "gone", kind: .recognition, created: now)
        let plain = old("e", "f")
        let adoptable = old("g", "h")
        let rows = [row("kept", .production, "a", "b"), row("new", .production, "g2", "h")]
        #expect(try plan(rows, [kept, gone, plain, adoptable]).suspended.isEmpty)
        #expect(try plan(rows, [kept, gone, plain, adoptable], suspendMissing: true).suspended.map(\.id) == [gone.id, plain.id])
    }
}

extension Deck {
    static func make(_ cards: [Card]) throws -> Deck {
        var deck = Deck()
        if let change = DeckChange.adding(cards, to: deck) {
            _ = deck.apply(change, at: Date(timeIntervalSince1970: 1_791_216_000), calendar: StudyCalendar())
        }
        return deck
    }
}

struct SyncRunTests {
    let now = Date(timeIntervalSince1970: 1_791_216_000)

    func scratch() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("deck-sync-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// A deck with a studied card per question, written as a package.
    func writeDeck(at url: URL, questions: [(String, String)]) throws -> Deck {
        var deck = Deck()
        let calendar = StudyCalendar()
        let cards = questions.map { Card(text: CardText(question: $0.0, answer: $0.1)!, created: now.addingTimeInterval(-86400)) }
        _ = deck.apply(try #require(DeckChange.adding(cards, to: deck)), at: now, calendar: calendar)
        // Study every card to the review phase: two good grades each.
        var mode = SessionMode.study(StudySession(deck: deck, at: now, calendar: calendar, random: SeededRandom(seed: 1)))
        for _ in 0..<100 where !mode.session.isFinished {
            if case let .rescheduled(change)? = mode.grade(.good, in: deck, at: now, calendar: calendar) {
                _ = deck.apply(change, at: now, calendar: calendar)
            }
        }
        #expect(deck.cards.allSatisfy { $0.learningState?.phase == .review && $0.log.count == 2 })
        try DeckFile.fileWrapper(for: deck).write(to: url, options: .atomic, originalContentsURL: nil)
        return deck
    }

    func options(_ arguments: [String]) throws -> SyncOptions {
        try SyncOptions.parse(arguments)
    }

    @Test func syncKeepsEveryReviewBacksUpAndIsIdempotent() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let deckURL = directory.appendingPathComponent("Greek.voctrain")
        let before = try writeDeck(at: deckURL, questions: [("dynamic", "δυναμικός"), ("to like", "συμπαθώ"), ("unused", "άχρηστο")])
        let tsv = directory.appendingPathComponent("cards.tsv")
        try """
        note\tkind\tquestion\tanswer\thint
        δυναμικός\tproduction\tdynamic\tδυναμικός-ή-ό\\nΕίναι δυναμικός.\tadjective
        δυναμικός\trecognition\tδυναμικός\tdynamic\t
        σπίτι\trecognition\tσπίτι\thouse\t
        """.write(to: tsv, atomically: true, encoding: .utf8)

        let backups = directory.appendingPathComponent("backups")
        let arguments = [tsv.path, deckURL.path, "--backup-dir", backups.path, "--new-production-per-session", "0", "--unlock-days", "30", "--new-order", "newest"]
        let dry = try SyncRun.run(options(arguments + ["--dry-run"]), now: now)
        #expect(dry.contains("added 2, edited 0, adopted 1, suspended 0, unchanged 0"))
        #expect(dry.contains("adopted:"))
        #expect(dry.contains("option: new production per session 7 → 0"))
        #expect(dry.contains("dry run: nothing written"))
        #expect(try DeckFile.decode(FileWrapper(url: deckURL, options: .immediate)) == before)
        #expect(!FileManager.default.fileExists(atPath: backups.path))

        let report = try SyncRun.run(options(arguments), now: now)
        #expect(report.contains("3 → 5 cards"))
        #expect(report.contains("backup: "))
        let after = try DeckFile.decode(FileWrapper(url: deckURL, options: .immediate))
        for card in before.cards {
            let kept = try #require(after.card(withID: card.id))
            #expect(kept.learningState == card.learningState)
            #expect(kept.log == card.log)
        }
        let adopted = try #require(after.card(withID: before.cards[0].id))
        #expect((adopted.note, adopted.kind) == ("δυναμικός", .production))
        #expect(adopted.answer == "δυναμικός-ή-ό\nΕίναι δυναμικός.")
        #expect(after.learningOptions.newProductionPerSession == 0)
        #expect(after.learningOptions.productionUnlockDays == 30)
        #expect(after.learningOptions.newCardOrder == .newestFirst)
        #expect(try FileManager.default.contentsOfDirectory(atPath: backups.path).count == 1)
        // A deck with the old extension is written in place under its name, and no deck of the new one appears.
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("Greek.mnemit").path))

        // Again: nothing to do, nothing written, no new backup.
        let again = try SyncRun.run(options(arguments), now: now.addingTimeInterval(5))
        #expect(again.contains("added 0, edited 0, adopted 0, suspended 0, unchanged 3"))
        #expect(again.contains("nothing to change"))
        #expect(try FileManager.default.contentsOfDirectory(atPath: backups.path).count == 1)
    }

    @Test func suspendMissingSuspendsAndKeepsProgress() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let deckURL = directory.appendingPathComponent("Greek.mnemit")
        _ = try writeDeck(at: deckURL, questions: [("a", "α"), ("b", "β")])
        let tsv = directory.appendingPathComponent("cards.tsv")
        try "note\tkind\tquestion\tanswer\thint\nα\tproduction\ta\tα\t\nβ\tproduction\tb\tβ\t\n".write(to: tsv, atomically: true, encoding: .utf8)
        _ = try SyncRun.run(options([tsv.path, deckURL.path]), now: now)

        try "note\tkind\tquestion\tanswer\thint\nα\tproduction\ta\tα\t\n".write(to: tsv, atomically: true, encoding: .utf8)
        let report = try SyncRun.run(options([tsv.path, deckURL.path, "--suspend-missing"]), now: now.addingTimeInterval(60))
        #expect(report.contains("suspended 1"))
        let deck = try DeckFile.decode(FileWrapper(url: deckURL, options: .immediate))
        let suspended = deck.cards.filter(\.isSuspended)
        #expect(suspended.map(\.question) == ["b"])
        #expect(suspended[0].learningState != nil && suspended[0].log.count == 2)
    }

    @Test func plainTableStillAddsNewQuestionsOnly() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let deckURL = directory.appendingPathComponent("Greek.mnemit")
        _ = try writeDeck(at: deckURL, questions: [("dynamic", "δυναμικός")])
        let tsv = directory.appendingPathComponent("cards.tsv")
        try "dynamic\tδυναμικός\t\nhasty\tβιαστικός\tx\n".write(to: tsv, atomically: true, encoding: .utf8)
        // The former third argument still sets the new cards per session.
        let report = try SyncRun.run(options([tsv.path, deckURL.path, "15"]), now: now)
        #expect(report.contains("added 1, edited 0, adopted 0, suspended 0, unchanged 1"))
        let deck = try DeckFile.decode(FileWrapper(url: deckURL, options: .immediate))
        #expect(deck.cards.map(\.question) == ["dynamic", "hasty"])
        #expect(deck.learningOptions.newCardsPerSession == 15)
        #expect(throws: SyncError.self) { try SyncRun.run(options([tsv.path, deckURL.path, "--suspend-missing"]), now: now) }
    }

    /// An app with the deck open hears of a write of the tool, a coordinated one, and of none of a dry run.
    @Test func theWriteIsCoordinatedSoOpenAppsHearOfIt() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let deckURL = directory.appendingPathComponent("Greek.mnemit")
        _ = try writeDeck(at: deckURL, questions: [("a", "α")])
        let tsv = directory.appendingPathComponent("cards.tsv")
        try "note\tkind\tquestion\tanswer\thint\nα\tproduction\ta\tα\t\nβ\tproduction\tb\tβ\t\n".write(to: tsv, atomically: true, encoding: .utf8)
        let app = OpenApp(deckURL)
        NSFileCoordinator.addFilePresenter(app)
        defer { NSFileCoordinator.removeFilePresenter(app) }

        _ = try SyncRun.run(options([tsv.path, deckURL.path, "--dry-run"]), now: now)
        Thread.sleep(forTimeInterval: 0.5)
        #expect(app.heard == 0)

        _ = try SyncRun.run(options([tsv.path, deckURL.path]), now: now)
        let deadline = Date().addingTimeInterval(10)
        while app.heard == 0, Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
        #expect(app.heard > 0)
        #expect(try DeckFile.decode(FileWrapper(url: deckURL, options: .immediate)).cards.count == 2)
    }

    @Test func newDeckIsCreatedWithoutBackup() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let deckURL = directory.appendingPathComponent("New.mnemit")
        let tsv = directory.appendingPathComponent("cards.tsv")
        try "note\tkind\tquestion\tanswer\thint\nα\trecognition\tα\ta\t\n".write(to: tsv, atomically: true, encoding: .utf8)
        let report = try SyncRun.run(options([tsv.path, deckURL.path]), now: now)
        #expect(report.contains("0 → 1 cards"))
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent(".backups").path))
        #expect(try DeckFile.decode(FileWrapper(url: deckURL, options: .immediate)).cards.count == 1)
    }

    @Test func keepsTheTenNewestBackupsOfThisDeckOnly() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(at: directory) }
        let deckURL = directory.appendingPathComponent("Greek.mnemit")
        _ = try writeDeck(at: deckURL, questions: [("a", "α")])
        let backups = directory.appendingPathComponent(".backups")
        for second in 0..<14 {
            try Backup.make(of: deckURL, in: nil, at: now.addingTimeInterval(Double(second)))
        }
        // The same second twice gets a counter and counts as newer.
        let twin = try Backup.make(of: deckURL, in: nil, at: now.addingTimeInterval(13))
        let other = backups.appendingPathComponent("Other-20260101-000000.mnemit")
        try FileManager.default.copyItem(at: deckURL, to: other)
        // A copy from before the extension changed counts with the others, and as the oldest it goes.
        let oldest = backups.appendingPathComponent("Greek-20250101-000000.voctrain")
        try FileManager.default.copyItem(at: deckURL, to: oldest)
        try Backup.make(of: deckURL, in: nil, at: now.addingTimeInterval(14))

        let names = try FileManager.default.contentsOfDirectory(atPath: backups.path).filter { $0.hasPrefix("Greek-") }
        #expect(names.count == Backup.keep)
        #expect(names.contains(twin.lastPathComponent))
        #expect(FileManager.default.fileExists(atPath: other.path))
        #expect(!FileManager.default.fileExists(atPath: oldest.path))
    }

    @Test func parsesTheCommandLine() throws {
        let options = try SyncOptions.parse(["a.tsv", "b.mnemit", "--dry-run", "--new-per-session", "none", "--new-production-per-session", "0", "--unlock-days", "0", "--new-order", "deck"])
        #expect(options.dryRun && !options.suspendMissing)
        #expect(options.overrides.newPerSession == .unlimited)
        #expect(options.overrides.newProductionPerSession == .count(0))
        #expect(options.overrides.unlockDays == 0)
        #expect(options.overrides.newOrder == .deckOrder)
        #expect(throws: SyncError.self) { try SyncOptions.parse(["a.tsv"]) }
        #expect(throws: SyncError.self) { try SyncOptions.parse(["a.tsv", "b.mnemit", "--new-per-session", "0"]) }
        #expect(throws: SyncError.self) { try SyncOptions.parse(["a.tsv", "b.mnemit", "--new-order", "random"]) }
        #expect(throws: SyncError.self) { try SyncOptions.parse(["a.tsv", "b.mnemit", "--bogus"]) }
    }
}

/// Stands for an app that has the deck open: counts what it hears of a writer.
final class OpenApp: NSObject, NSFilePresenter, @unchecked Sendable {
    let presentedItemURL: URL?
    let presentedItemOperationQueue = OperationQueue()
    private let count = NSLock()
    private var hearings = 0

    init(_ url: URL) { presentedItemURL = url }

    var heard: Int { count.withLock { hearings } }

    private func hear() { count.withLock { hearings += 1 } }

    func relinquishPresentedItem(toWriter writer: @escaping @Sendable ((@Sendable () -> Void)?) -> Void) {
        hear()
        writer(nil)
    }

    func presentedItemDidChange() { hear() }
}
