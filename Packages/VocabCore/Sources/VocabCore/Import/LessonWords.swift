import Foundation

/// Words from a lesson as the learner types them, one per line, "greek = translation", and
/// the two cards each makes: recognition (the Greek asks, the translation answers) and
/// production (the translation asks, the Greek answers). Both carry the note of the word,
/// so the deck knows them as siblings and holds the production card back until the
/// recognition card is learned, see `LearningOptions.productionUnlockDays`.
public enum LessonWords {
    /// One word of the lesson, its Greek side first whichever side was typed first.
    public struct Entry: Hashable, Sendable {
        public var greek: String
        public var translation: String
        /// The key of the word, see `note(forGreek:)`.
        public var note: String
    }

    /// What the text holds.
    public struct Parsed: Equatable, Sendable {
        public var entries: [Entry] = []
        /// The numbers, from 1, of the lines with text but no usable "greek = translation".
        public var invalidLines: [Int] = []
    }

    /// What adding the words to a deck would do.
    public struct Plan: Equatable, Sendable {
        /// The cards to add: every recognition card first, then every production card.
        public var cards: [Card] = []
        /// Words whose note the deck holds already, or an earlier line of the text made;
        /// they add nothing.
        public var skipped: [Entry] = []
    }

    /// The separators between the two sides of a line.
    private static let separators: Set<Character> = ["=", "–", "—", "\t"]

    /// The hyphen a phone keyboard types, a separator only with a space on both sides: a
    /// bare one belongs to a word ("ex-wife", "-η").
    private static let spacedHyphen = " - "

    /// Where the first separator of `line` is, the character or the spaced hyphen, whichever
    /// comes first.
    private static func separator(in line: String) -> Range<String.Index>? {
        let character = line.firstIndex(where: separators.contains).map { $0..<line.index(after: $0) }
        let hyphen = line.range(of: spacedHyphen)
        return [character, hyphen].compactMap(\.self).min { $0.lowerBound < $1.lowerBound }
    }

    /// The words of `text`. The first separator on a line splits it, so a translation may
    /// contain more; a line with the Greek on the right is turned round.
    public static func parse(_ text: String) -> Parsed {
        var parsed = Parsed()
        for (index, line) in text.components(separatedBy: .newlines).enumerated() {
            let line = line.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            guard let split = separator(in: line) else {
                parsed.invalidLines.append(index + 1)
                continue
            }
            var greek = CardText.trimmed(String(line[..<split.lowerBound]))
            var translation = CardText.trimmed(String(line[split.upperBound...]))
            guard !greek.isEmpty, !translation.isEmpty else {
                parsed.invalidLines.append(index + 1)
                continue
            }
            if !greek.hasGreekLetters, translation.hasGreekLetters {
                swap(&greek, &translation)
            }
            parsed.entries.append(Entry(greek: greek, translation: translation, note: note(forGreek: greek)))
        }
        return parsed
    }

    /// The cards that adding `entries` to a deck with `existingNotes` would make.
    public static func plan(for entries: [Entry], existingNotes: some Sequence<String>, created: Date) -> Plan {
        var known = Set(existingNotes.map(normalized))
        var plan = Plan()
        var recognition: [Card] = []
        var production: [Card] = []
        for entry in entries {
            guard known.insert(normalized(entry.note)).inserted else {
                plan.skipped.append(entry)
                continue
            }
            if let text = CardText(question: entry.greek, answer: entry.translation) {
                recognition.append(Card(text: text, note: entry.note, kind: .recognition, created: created))
            }
            if let text = CardText(question: entry.translation, answer: entry.greek) {
                production.append(Card(text: text, note: entry.note, kind: .production, created: created))
            }
        }
        plan.cards = recognition + production
        return plan
    }

    /// The note of a Greek word, made as `key()` in `greek-lessons/vocab/merge.py` makes
    /// it, so the deck finds the word again when that script's table is synced: the lemma
    /// in lower case, with its accents, endings and brackets cut off after the first comma
    /// or bracket, and the article of a noun moved behind a `#`:
    /// "η παρέα" is "παρέα#η", "υπεύθυνος, -η, -ο" is "υπεύθυνος", "τρώω (έφαγα)" is "τρώω".
    public static func note(forGreek greek: String) -> String {
        // Not `lowercased()`: only Foundation's version writes a final sigma as ς.
        var word = greek.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: nil).precomposedStringWithCanonicalMapping
        var article = ""
        for candidate in articles where word.hasPrefix(candidate) {
            word.removeFirst(candidate.count)
            article = "#" + candidate.trimmingCharacters(in: .whitespaces)
            break
        }
        let lemma = word.prefix { $0 != "(" && $0 != "," }
        return lemma.trimmingCharacters(in: .whitespacesAndNewlines) + article
    }

    private static let articles = ["ο/η ", "η/ο ", "ο ", "η ", "το ", "οι ", "τα "]

    /// Notes are compared in composed Unicode form, as `deck-from-tsv` does.
    private static func normalized(_ note: String) -> String {
        CardText.trimmed(note).precomposedStringWithCanonicalMapping
    }
}
