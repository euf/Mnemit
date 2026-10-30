import Foundation
import Testing

@testable import MacVocTrain
@testable import VocabCore

/// The progress ledger on disk: one file per device in `.mnemit-progress/` of the deck folder, every file read and
/// merged; and the daily ring over it, which keeps the past days when a deck goes away.
@MainActor
struct ProgressLedgerStoreTests {
    func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// A device: its own user defaults, so its own device id.
    func device() -> UserDefaults {
        UserDefaults(suiteName: "ProgressLedgerStoreTests-\(UUID().uuidString)")!
    }

    func day(_ day: Int, done: Int, words: Int = 0) -> LedgerDay {
        LedgerDay(day: day, reviews: done, done: done, goal: 10, keepAt: 4, time: 150, reason: .start, worked: 100, filled: false, wordsLearned: words)
    }

    @Test func aLedgerWrittenIsReadBack() throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let defaults = device()
        let store = ProgressLedgerStore(folder: folder, defaults: defaults)
        #expect(store.read().days.isEmpty)

        let ledger = DayLedger().updating([day(20_000, done: 5), day(20_001, done: 12, words: 3)])
        store.write(ledger)

        #expect(store.read() == ledger)
        #expect(FileManager.default.fileExists(atPath: folder.appending(path: ".mnemit-progress/\(store.deviceID).jsonl").path))
        // The device id stays with the device.
        #expect(ProgressLedgerStore(folder: folder, defaults: defaults).deviceID == store.deviceID)
    }

    @Test func theFilesOfTwoDevicesAreMergedDayByDay() throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let phone = ProgressLedgerStore(folder: folder, defaults: device())
        let mac = ProgressLedgerStore(folder: folder, defaults: device())
        #expect(phone.deviceID != mac.deviceID)

        phone.write(DayLedger().updating([day(20_000, done: 5), day(20_001, done: 6)]))
        mac.write(DayLedger().updating([day(20_001, done: 9), day(20_002, done: 2)]))

        let merged = phone.read()
        #expect(merged == mac.read())
        #expect(merged.days.keys.sorted() == [20_000, 20_001, 20_002])
        // The day both knew is the one with more done.
        #expect(merged.days[20_001]?.done == 9)
        #expect(merged.days[20_000]?.done == 5)
        // Each device wrote only its own file.
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.appending(path: ".mnemit-progress").path).count == 2)
    }

    @Test func aPlaceholderIsSkippedAndAnUnreadableLineCostsItsDayOnly() throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = ProgressLedgerStore(folder: folder, defaults: device())
        store.write(DayLedger().updating([day(20_000, done: 5), day(20_001, done: 6)]))
        let directory = folder.appending(path: ".mnemit-progress", directoryHint: .isDirectory)

        // A file iCloud Drive has not downloaded yet is only a hidden placeholder: its content is not the ledger's.
        let other = DayLedger().updating([day(20_005, done: 99)]).encoded()
        try other.write(to: directory.appending(path: ".\(UUID().uuidString).jsonl.icloud"))
        // A damaged line in another device's file.
        var damaged = DayLedger().updating([day(20_002, done: 7)]).encoded()
        damaged.append(Data("{not json\n".utf8))
        damaged.append(DayLedger().updating([day(20_003, done: 8)]).encoded())
        try damaged.write(to: directory.appending(path: "\(UUID().uuidString).jsonl"))

        let read = store.read()
        #expect(read.days.keys.sorted() == [20_000, 20_001, 20_002, 20_003])
        #expect(read.days[20_005] == nil)
    }

    @Test func withoutAFolderTheLedgerLivesInTheAppsOwnDirectory() {
        let store = ProgressLedgerStore(folder: nil, defaults: device())
        #expect(store.folder.path.hasSuffix("/Mnemit"))
        #expect(store.directory.lastPathComponent == ".mnemit-progress")
    }

    // MARK: The daily ring over the ledger

    /// `count` cards, each reviewed once a day for the three days before today.
    func reviewedCards(_ count: Int, now: Date) -> [Card] {
        (0..<count).map { index in
            let log = (1...3).reversed().map { ReviewLogEntry(date: now.addingTimeInterval(-Double($0) * 86400), grade: .good) }
            let state = LearningState(phase: .review, stability: 20, difficulty: 5, lastReview: log.last!.date, due: now.addingTimeInterval(20 * 86400), reviews: 3)
            return Card(question: "q\(index)", answer: "a", learningState: state, log: log)
        }
    }

    /// This device's file that iCloud Drive has not downloaded is a placeholder: the ledger is not written over it.
    @Test func aPlaceholderOfTheOwnFileIsNotWrittenOver() throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = ProgressLedgerStore(folder: folder, defaults: device())
        store.write(DayLedger().updating([day(20_000, done: 5)]))
        let placeholder = store.directory.appending(path: ".\(store.file.lastPathComponent).icloud", directoryHint: .notDirectory)
        try FileManager.default.moveItem(at: store.file, to: placeholder)

        store.write(DayLedger().updating([day(20_000, done: 1)]))
        #expect(!FileManager.default.fileExists(atPath: store.file.path))
        #expect(FileManager.default.fileExists(atPath: placeholder.path))
    }

    /// A deck file that fails to read leaves the ledger as it is: the days before today would be sized from the
    /// decks that did read.
    @Test func noLedgerIsWrittenWhileADeckFileFailsToRead() async throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let now = Date()
        let first = try writeDeck(named: "First", cards: reviewedCards(12, now: now), in: folder)
        let missing = folder.appending(path: "Missing.mnemit", directoryHint: .isDirectory)
        let store = ProgressLedgerStore(folder: folder, defaults: device())

        let model = DailyRingModel()
        await model.refresh(documents: [], files: [first, missing], ledger: store, reloadFiles: true, delay: .zero).value
        #expect(store.read().days.isEmpty)

        let whole = DailyRingModel()
        await whole.refresh(documents: [], files: [first], ledger: store, reloadFiles: true, delay: .zero).value
        #expect(!store.read().days.isEmpty)
    }

    func writeDeck(named name: String, cards: [Card], in directory: URL) throws -> URL {
        let url = directory.appending(path: "\(name).mnemit", directoryHint: .isDirectory)
        try DeckFile.fileWrapper(for: Deck(cards: cards)).write(to: url, options: .atomic, originalContentsURL: nil)
        return url
    }

    @Test func theRingKeepsThePastDaysWhenADeckGoesAway() async throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let now = Date()
        let first = try writeDeck(named: "First", cards: reviewedCards(12, now: now), in: folder)
        let second = try writeDeck(named: "Second", cards: reviewedCards(12, now: now), in: folder)
        let store = ProgressLedgerStore(folder: folder, defaults: device())

        let before = DailyRingModel()
        await before.refresh(documents: [], files: [first, second], ledger: store, reloadFiles: true, delay: .zero).value
        let progress = try #require(before.progress)
        #expect(progress.records.count >= 3)
        let past = progress.records.dropLast().map(\.done)
        #expect(past.reduce(0, +) > 0)
        // The first evaluation wrote the days before today.
        let written = store.read()
        #expect(written.days.count >= 3)
        #expect(written.days.values.allSatisfy { $0.reviews == 24 })

        try FileManager.default.removeItem(at: second)

        // Without the records the past would shrink with the deck: the control that the check can fail.
        let forgetful = DailyRingModel()
        await forgetful.refresh(documents: [], files: [first], reloadFiles: true, delay: .zero).value
        #expect(forgetful.progress?.records.dropLast().map(\.done) != past)

        // A new run of the app reads the ledger: the past days stand, the streak and the words learned too.
        let after = DailyRingModel()
        await after.refresh(documents: [], files: [first], ledger: store, reloadFiles: true, delay: .zero).value
        let later = try #require(after.progress)
        #expect(later.records == progress.records)
        #expect(later.streak == progress.streak)
        #expect(later.learned.words == progress.learned.words)
        #expect(later.week == progress.week)
        #expect(store.read() == written)
    }
}
