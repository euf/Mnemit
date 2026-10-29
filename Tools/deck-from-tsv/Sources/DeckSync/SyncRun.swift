import Foundation
import VocabCore

/// One run of the tool: reads the TSV and the deck, plans, and unless it is a dry run
/// backs the deck up and writes it.
///
/// The deck is read and written inside one coordinated write (`NSFileCoordinator`), as an app
/// writes it: iCloud Drive and the apps that have the deck open are told of the change, and
/// the deck can't change between the read and the write. A dry run only reads.
public enum SyncRun {
    /// - Returns: The report to print.
    /// - Throws: `SyncError` before anything is written if the input or the deck can't be
    ///   read, or if a change would lose a card or its progress.
    public static func run(_ options: SyncOptions, now: Date = Date(), calendar: StudyCalendar = StudyCalendar()) throws -> String {
        let input: SyncInput
        do {
            input = try TSVReader.read(Data(contentsOf: options.input))
        } catch let error as SyncError {
            throw error
        } catch {
            throw SyncError("can't read \(options.input.path): \(error.localizedDescription)")
        }

        var coordinationError: NSError?
        var report: Result<String, any Error>?
        let coordinator = NSFileCoordinator()
        let accessor = { (url: URL) in report = Result { try sync(options, input: input, deckAt: url, now: now, calendar: calendar) } }
        if options.dryRun {
            coordinator.coordinate(readingItemAt: options.deck, options: [], error: &coordinationError, byAccessor: accessor)
        } else {
            coordinator.coordinate(writingItemAt: options.deck, options: .forMerging, error: &coordinationError, byAccessor: accessor)
        }
        if let coordinationError {
            throw SyncError("can't get access to \(options.deck.path): \(coordinationError.localizedDescription)")
        }
        return try report!.get()
    }

    /// Plans and writes at `url`, which the caller holds the coordination of.
    private static func sync(_ options: SyncOptions, input: SyncInput, deckAt url: URL, now: Date, calendar: StudyCalendar) throws -> String {
        let exists = FileManager.default.fileExists(atPath: url.path)
        var deck = Deck()
        if exists {
            do {
                // Read at once: a lazy wrapper listed an empty package when the same
                // process had replaced the package before.
                deck = try DeckFile.decode(FileWrapper(url: url, options: .immediate))
            } catch {
                throw SyncError("can't read the deck \(url.path): \(error)")
            }
        }
        let before = deck

        var plan: SyncPlan
        var skipped = 0
        switch input {
        case let .notes(rows):
            plan = SyncPlan.make(rows: rows, deck: deck, suspendMissing: options.suspendMissing, now: now)
        case let .plain(rows):
            guard !options.suspendMissing else {
                throw SyncError("--suspend-missing needs a TSV with notes: a plain question/answer table has none")
            }
            let result = CardImporter.candidates(from: rows, existing: deck.cards, isHeader: { _ in false }, created: now)
            plan = SyncPlan()
            plan.added = result.candidates.filter { $0.duplicate == nil }.map(\.card)
            plan.unchanged = result.candidates.count - plan.added.count
            skipped = result.skippedRows
        }
        try plan.apply(to: &deck, at: now, calendar: calendar)
        let renewed = try renew(options.renew, in: &deck, at: now, calendar: calendar)
        let removed = try remove(options.remove, from: &deck, at: now, calendar: calendar)

        let updated = options.overrides.applied(to: deck.learningOptions)
        if let change = DeckChange.changingLearningOptions(updated, in: deck, calendar: calendar) {
            _ = deck.apply(change, at: now, calendar: calendar)
        }
        let optionChanges = OptionOverrides.changes(from: before.learningOptions, to: deck.learningOptions)

        var report = ["\(url.lastPathComponent): \(before.cards.count) → \(deck.cards.count) cards"]
        report.append(
            "added \(plan.added.count), edited \(plan.edited.count), adopted \(plan.adopted.count), suspended \(plan.suspended.count), unchanged \(plan.unchanged)"
                + (skipped > 0 ? ", \(skipped) empty rows skipped" : ""))
        report += optionChanges.map { "option: \($0)" }
        if options.renew != nil {
            report.append("renewed \(renewed) new cards: today's addition, first among the new cards")
        }
        if options.remove != nil {
            report.append("removed \(removed) cards never studied")
        }

        if options.dryRun {
            report += lists(of: plan)
            report.append("dry run: nothing written")
            return report.joined(separator: "\n")
        }

        guard deck != before || !exists else {
            report.append("nothing to change; deck not written")
            return report.joined(separator: "\n")
        }
        if exists {
            let copy = try Backup.make(of: url, in: options.backupDirectory, at: now)
            report.append("backup: \(copy.path)")
        }
        try DeckFile.fileWrapper(for: deck).write(to: url, options: .atomic, originalContentsURL: nil)
        return report.joined(separator: "\n")
    }

    /// Removes the cards of the word keys listed in `file` that were never studied (`DeckChange.removing(_:from:)`).
    /// - Returns: How many cards were removed.
    private static func remove(_ file: URL?, from deck: inout Deck, at now: Date, calendar: StudyCalendar) throws -> Int {
        guard let file else { return 0 }
        let notes = Set(try noteLines(of: file).map(SyncRow.normalized))
        let ids = deck.cards.filter { card in
            card.isNew && card.log.isEmpty && card.note.map { notes.contains(SyncRow.normalized($0)) } == true
        }.map(\.id)
        guard let change = DeckChange.removing(Set(ids), from: deck) else { return 0 }
        _ = deck.apply(change, at: now, calendar: calendar)
        return ids.count
    }

    /// The lines of a file of word keys.
    private static func noteLines(of file: URL) throws -> [String] {
        do {
            return try String(contentsOf: file, encoding: .utf8).split(whereSeparator: \.isNewline).map(String.init)
        } catch {
            throw SyncError("can't read \(file.path): \(error.localizedDescription)")
        }
    }

    /// Renews the new cards of the word keys listed in `file`, in its order (`DeckChange.renewing(_:in:at:)`).
    /// - Returns: How many cards were renewed.
    /// - Throws: `SyncError` if the file can't be read, or if the stamps, a second apart, would reach back
    ///   into the day before: the cards would then not all be today's addition.
    private static func renew(_ file: URL?, in deck: inout Deck, at now: Date, calendar: StudyCalendar) throws -> Int {
        guard let file else { return 0 }
        var byNote: [String: [Card.ID]] = [:]
        for card in deck.cards {
            if let note = card.note { byNote[SyncRow.normalized(note), default: []].append(card.id) }
        }
        let ids = try noteLines(of: file).flatMap { byNote[SyncRow.normalized($0)] ?? [] }
        guard let change = DeckChange.renewing(ids, in: deck, at: now) else { return 0 }
        let before = deck
        _ = deck.apply(change, at: now, calendar: calendar)
        let renewed = deck.cards.filter { card in before.card(withID: card.id)?.created != card.created }
        if let first = renewed.map(\.created).min(), calendar.dayNumber(for: first) != calendar.dayNumber(for: now) {
            throw SyncError("--renew: \(renewed.count) cards a second apart reach back into yesterday; run it later in the day")
        }
        return renewed.count
    }

    /// The cards of each kind of change, one per line.
    static func lists(of plan: SyncPlan) -> [String] {
        func line(_ question: String, _ answer: String) -> String {
            "  \(oneLine(question)) → \(oneLine(answer))"
        }
        func changed(_ change: SyncPlan.Change) -> String {
            let old = change.card
            let was = (old.question, old.answer) == (change.text.question, change.text.answer) ? "" : "   (was: \(oneLine(old.question)) → \(oneLine(old.answer)))"
            return line(change.text.question, change.text.answer) + "   [\(change.note) \(change.kind.rawValue)]" + was
        }
        var lines: [String] = []
        if !plan.added.isEmpty {
            lines.append("added:")
            lines += plan.added.map { card in
                line(card.question, card.answer) + (card.note.map { "   [\($0) \(card.kind?.rawValue ?? "")]" } ?? "")
            }
        }
        if !plan.edited.isEmpty {
            lines.append("edited:")
            lines += plan.edited.map(changed)
        }
        if !plan.adopted.isEmpty {
            lines.append("adopted:")
            lines += plan.adopted.map(changed)
        }
        if !plan.suspended.isEmpty {
            lines.append("suspended:")
            lines += plan.suspended.map { line($0.question, $0.answer) + "   [\($0.note ?? "")]" }
        }
        return lines
    }

    private static func oneLine(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: " ⏎ ")
    }
}
