import CryptoKit
import Foundation
import VocabCore

/// What a run does to a deck: cards to add, to edit in place, to adopt, to suspend.
/// Nothing is ever removed, and no card loses its learning state or log.
public struct SyncPlan: Sendable {
    /// An existing card that takes new text, and note and kind if it is adopted.
    public struct Change: Sendable {
        public var card: Card
        public var text: CardText
        public var note: String
        public var kind: CardKind
    }

    public var added: [Card] = []
    public var edited: [Change] = []
    /// Cards without a note that took one from a row, keeping their ID and reviews.
    public var adopted: [Change] = []
    public var suspended: [Card] = []
    public var unchanged = 0

    public init() {}

    /// Matches every row to a card of `deck`:
    /// 1. by note and kind;
    /// 2. else by adopting a card without a note: see `adoptable(for:among:)`;
    /// 3. else a new card, whose ID follows from note and kind (`cardID(note:kind:avoiding:)`).
    ///
    /// - Parameter suspendMissing: Also suspends the cards with a note that no row has.
    public static func make(rows: [SyncRow], deck: Deck, suspendMissing: Bool, now: Date) -> SyncPlan {
        var plan = SyncPlan()
        var byKey: [String: Card] = [:]
        for card in deck.cards {
            guard let note = card.note, let kind = card.kind else { continue }
            let key = SyncRow.key(note: note, kind: kind)
            if byKey[key] == nil { byKey[key] = card }
        }

        var claimed = Set<Card.ID>()
        var unmatched: [SyncRow] = []
        for row in rows {
            guard let card = byKey[row.key] else {
                unmatched.append(row)
                continue
            }
            claimed.insert(card.id)
            if (card.question, card.answer, card.hint) == (row.text.question, row.text.answer, row.text.hint) {
                plan.unchanged += 1
            } else {
                plan.edited.append(Change(card: card, text: row.text, note: row.note, kind: row.kind))
            }
        }

        let withoutNote = deck.cards.filter { $0.note == nil }
        var usedIDs = Set(deck.cards.map(\.id))
        for row in unmatched {
            if let card = adoptable(for: row, among: withoutNote.filter { !claimed.contains($0.id) }) {
                claimed.insert(card.id)
                plan.adopted.append(Change(card: card, text: row.text, note: row.note, kind: row.kind))
            } else {
                let id = cardID(note: row.note, kind: row.kind, avoiding: usedIDs)
                usedIDs.insert(id)
                plan.added.append(Card(id: id, text: row.text, note: row.note, kind: row.kind, created: now))
            }
        }

        if suspendMissing {
            let notes = Set(rows.map { SyncRow.normalized($0.note) })
            plan.suspended = deck.cards.filter { card in
                guard let note = card.note, !card.isSuspended else { return false }
                return !notes.contains(SyncRow.normalized(note))
            }
        }
        return plan
    }

    /// The card without a note that `row` takes over, if any: one whose answer equals the
    /// first line of the row's answer, or, for a production row, the first line the way
    /// the former deck stored it (`LegacyAnswer`). Of several, one with the row's question
    /// goes first, then the first in deck order.
    static func adoptable(for row: SyncRow, among cards: [Card]) -> Card? {
        let firstLine = LegacyAnswer.firstLine(of: row.text.answer)
        let forms = row.kind == .production ? LegacyAnswer.forms(of: firstLine) : [LegacyAnswer.key(firstLine)]
        let matching = cards.filter { card in
            !forms.isDisjoint(with: LegacyAnswer.storedForms(of: card.answer, lenient: row.kind == .production))
        }
        let question = CardText.key(forQuestion: row.text.question)
        return matching.first { CardText.key(forQuestion: $0.question) == question } ?? matching.first
    }

    /// A UUID version 5 of "note|kind", so every run, on every machine, gives the card
    /// of a word's direction the same ID; a second device that syncs the same TSV before
    /// the first one's deck has arrived makes the same card, which a merge joins. An ID
    /// the deck uses already gets a counter in its name.
    static func cardID(note: String, kind: CardKind, avoiding used: Set<UUID>) -> UUID {
        var attempt = 0
        while true {
            let name = "\(SyncRow.normalized(note))|\(kind.rawValue)" + (attempt == 0 ? "" : "|\(attempt)")
            let id = uuidVersion5(name: name)
            if !used.contains(id) { return id }
            attempt += 1
        }
    }

    /// Namespace of this tool's IDs, itself arbitrary.
    private static let namespace = UUID(uuidString: "6D1E5F8A-3B44-4C0E-9A57-2F8B1C7D9E01")!

    static func uuidVersion5(namespace: UUID = SyncPlan.namespace, name: String) -> UUID {
        var sha = Insecure.SHA1()
        withUnsafeBytes(of: namespace.uuid) { sha.update(bufferPointer: $0) }
        sha.update(data: Data(name.utf8))
        var bytes = Array(sha.finalize().prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
            ))
    }

    /// Makes the plan's changes to `deck` through `DeckChange`, in the order adopt, edit,
    /// add, suspend.
    ///
    /// - Throws: `SyncError` if a card lost its learning state, log or creation date, which
    ///   no change here may do. `deck` is then left as it was.
    public func apply(to deck: inout Deck, at now: Date, calendar: StudyCalendar) throws {
        var result = deck
        for change in adopted {
            if let note = DeckChange.settingNote(change.note, kind: change.kind, of: change.card.id, in: result) {
                _ = result.apply(note, at: now, calendar: calendar)
            }
        }
        for change in adopted + edited {
            if let edit = DeckChange.editingText(of: change.card.id, to: change.text, in: result) {
                _ = result.apply(edit, at: now, calendar: calendar)
            }
        }
        if let adding = DeckChange.adding(added, to: result) {
            _ = result.apply(adding, at: now, calendar: calendar)
        }
        if let suspending = DeckChange.settingSuspended(true, of: Set(suspended.map(\.id)), in: result, at: now) {
            _ = result.apply(suspending, at: now, calendar: calendar)
        }
        try SyncPlan.verifyNothingLost(before: deck, after: result, suspended: Set(suspended.map(\.id)))
        deck = result
    }

    static func verifyNothingLost(before: Deck, after: Deck, suspended: Set<Card.ID>) throws {
        for card in before.cards {
            guard let kept = after.card(withID: card.id) else {
                throw SyncError("card “\(card.question)” would be lost; nothing written")
            }
            let same =
                kept.learningState == card.learningState && kept.log == card.log && kept.learningStateReset == card.learningStateReset
                && kept.created == card.created && (kept.isSuspended == card.isSuspended || suspended.contains(card.id))
            guard same else {
                throw SyncError("card “\(card.question)” would lose progress; nothing written")
            }
        }
    }
}

/// How the former deck stored the Greek word of a card, to find the cards a TSV with notes
/// takes over. That deck asked from the meaning to the word and kept the word as the
/// answer: nouns with their article ("η παρέα"), adjectives without their endings
/// ("δυναμικός" for "δυναμικός-ή-ό").
enum LegacyAnswer {
    static let articles: Set<String> = ["ο", "η", "το", "οι", "τα", "ένας", "μια", "μία", "ένα"]

    /// The first line of `answer`, trimmed.
    static func firstLine(of answer: String) -> String {
        let line = answer.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? answer
        return CardText.trimmed(line)
    }

    /// Case and Unicode form of a word for comparing.
    static func key(_ word: String) -> String {
        CardText.trimmed(word).precomposedStringWithCanonicalMapping.lowercased()
    }

    /// The forms a first line may have had in the former deck: as it is, cut before the
    /// first alternative or gloss ("ο ψεύτης / η ψεύτρα"), without the endings of its
    /// last word ("-ή-ό"), and each of these without a leading article.
    static func forms(of line: String) -> Set<String> {
        var forms: Set = [key(line)]
        var head = line
        for separator in [" / ", " · ", ", ", "; ", " ("] {
            if let range = head.range(of: separator) { head = String(head[..<range.lowerBound]) }
        }
        forms.insert(key(head))
        var words = head.split(separator: " ").map(String.init)
        if let last = words.last, let dash = last.firstIndex(of: "-"), dash != last.startIndex {
            words[words.count - 1] = String(last[..<dash])
            forms.insert(key(words.joined(separator: " ")))
        }
        for form in forms {
            forms.insert(strippingArticle(form))
        }
        return forms
    }

    /// The answer of a card as it is, and without its article if `lenient`.
    static func storedForms(of answer: String, lenient: Bool) -> Set<String> {
        let stored = key(answer)
        return lenient ? [stored, strippingArticle(stored)] : [stored]
    }

    private static func strippingArticle(_ word: String) -> String {
        let parts = word.split(separator: " ", maxSplits: 1).map(String.init)
        guard parts.count == 2, articles.contains(parts[0]) else { return word }
        return parts[1]
    }
}
