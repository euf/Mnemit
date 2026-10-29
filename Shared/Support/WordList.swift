import SwiftUI
import VocabCore

/// One word of the list preview: checked to be added, with what is wrong with it, if anything. The same row on both platforms.
struct WordListRow: View {
    var row: WordListPreview.Row
    var isSelected: Bool
    var toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: Spacing.gap) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.appAccentOnRaised : Color.secondary)
                    .imageScale(.large)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.entry.greek)
                    Text(row.entry.translation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let duplicate = row.duplicate {
                        Label {
                            switch duplicate {
                            case .inDeck:
                                Text("Already in this deck")
                            case let .inFile(question, answer):
                                Text("Already earlier in the list: \(question) → \(answer)")
                            case let .inOtherDeck(match):
                                Text(match.alsoInLine)
                            }
                        } icon: {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    } else if let similar = row.similar {
                        Label {
                            Text(similar.similarLine)
                        } icon: {
                            Image(systemName: "info.circle")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Words

/// The two cards of one word typed on the form of One Card, as Lesson Words makes them:
/// recognition (the Greek asks) and production (the translation asks), with the word key
/// they share, so the deck holds production back until recognition is learned.
enum WordPair {
    /// The cards of `text`, recognition first. The Greek side asks in recognition,
    /// whichever side was typed as the question; the hint goes on both cards.
    static func cards(for text: CardText, created: Date) -> [Card] {
        var greek = text.question
        var translation = text.answer
        if !greek.hasGreekLetters, translation.hasGreekLetters {
            swap(&greek, &translation)
        }
        var note = LessonWords.note(forGreek: greek)
        if note.isEmpty { note = greek }
        guard let recognition = CardText(question: greek, answer: translation, hint: text.hint),
            let production = CardText(question: translation, answer: greek, hint: text.hint)
        else { return [] }
        return [
            Card(text: recognition, note: note, kind: .recognition, created: created),
            Card(text: production, note: note, kind: .production, created: created),
        ]
    }
}

/// What the lines of the From a List mode make: a row per word with its two cards, and
/// the lines that are no word. A word the deck has already, or an earlier line made, or
/// another deck has, stays in the list as a duplicate, unchecked by default, as the import
/// preview does; a word that differs from one of another deck by an accent only is checked,
/// with a line that says so.
struct WordListPreview {
    struct Row: Identifiable {
        /// The word key, numbered if an earlier line has it too.
        var id: String
        var entry: LessonWords.Entry
        /// Recognition, then production.
        var cards: [Card]
        var duplicate: CardImporter.Duplicate?
        /// The word of another deck that this one differs from by an accent only.
        var similar: WordIndex.Match?

        var isSelectedByDefault: Bool { duplicate == nil }
    }

    var rows: [Row] = []
    /// The lines with text but no "word = translation": their number, from 1, and text.
    var invalidLines: [(number: Int, text: String)] = []

    init(text: String, deck: Deck, elsewhere: WordIndex = WordIndex(), created: Date) {
        let parsed = LessonWords.parse(text)
        let lines = text.components(separatedBy: .newlines)
        invalidLines = parsed.invalidLines.map { ($0, CardText.trimmed(lines[$0 - 1])) }

        // The same keys as the deck's own checks: a word key as `LessonWords.plan` compares
        // them, a question as `CardText.key(forQuestion:)` does.
        let notesInDeck = Set(deck.cards.compactMap { $0.note.flatMap { WordKey($0) } }.flatMap(\.sameKeys))
        let questionsInDeck = Set(deck.cards.map { CardText.key(forQuestion: $0.question) })
        var firstOfWord: [String: LessonWords.Entry] = [:]
        var linesOfNote: [String: Int] = [:]
        for entry in parsed.entries {
            let id = Self.normalized(entry.note)
            let wordKey = WordKey(entry.note)
            let keys = wordKey?.sameKeys ?? []
            var duplicate: CardImporter.Duplicate?
            var similar: WordIndex.Match?
            if !notesInDeck.isDisjoint(with: keys) || questionsInDeck.contains(CardText.key(forQuestion: entry.greek)) {
                duplicate = .inDeck
            } else if let first = keys.lazy.compactMap({ firstOfWord[$0] }).first {
                duplicate = .inFile(question: first.greek, answer: first.translation)
            } else {
                switch wordKey.flatMap(elsewhere.match) {
                case let .same(match)?: duplicate = .inOtherDeck(match)
                case let .looksLike(match)?: similar = match
                case nil: break
                }
            }
            for key in keys where firstOfWord[key] == nil {
                firstOfWord[key] = entry
            }
            let number = linesOfNote[id, default: 0] + 1
            linesOfNote[id] = number
            let cards = LessonWords.plan(for: [entry], existingNotes: [String](), created: created).cards
            rows.append(Row(id: number == 1 ? id : "\(id)#\(number)", entry: entry, cards: cards, duplicate: duplicate, similar: similar))
        }
    }

    /// The new cards of `deck` for the words of the list it holds already, in the order of the list: a card whose
    /// word key is one of the word's, or whose question is the word, as the duplicate check found it; only cards not
    /// started yet and not suspended. What `VocabularyDocument.addLessonCards(_:renewing:)` moves into the day's
    /// addition, so the lesson's known-but-unstarted words go first with its new ones.
    func renewable(in deck: Deck) -> [Card.ID] {
        let waiting = deck.cards.filter { $0.isNew && $0.log.isEmpty && !$0.isSuspended }
        var ids: [Card.ID] = []
        for row in rows where row.duplicate == .inDeck {
            let keys = Set(WordKey(row.entry.note)?.sameKeys ?? [])
            let question = CardText.key(forQuestion: row.entry.greek)
            for card in waiting where !ids.contains(card.id) {
                let cardKeys = card.note.flatMap { WordKey($0) }?.sameKeys ?? []
                if !keys.isDisjoint(with: cardKeys) || CardText.key(forQuestion: card.question) == question {
                    ids.append(card.id)
                }
            }
        }
        return ids
    }

    /// Word keys compare in composed Unicode form, as `LessonWords` does.
    private static func normalized(_ note: String) -> String {
        CardText.trimmed(note).precomposedStringWithCanonicalMapping
    }
}

extension String {
    /// Whether the text has Greek letters, of the modern alphabet or the polytonic one.
    var hasGreekLetters: Bool {
        unicodeScalars.contains { (0x0370...0x03FF).contains($0.value) || (0x1F00...0x1FFF).contains($0.value) }
    }
}

/// "Added", with the cards of the sheet's session so far, briefly under the bar; the Mac's Add Cards sheet shows it too.
struct ConfirmationBadge: View {
    var count: Int

    var body: some View {
        Label("Added · \(count) cards so far", systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, Spacing.tight)
            .background(.regularMaterial, in: Capsule())
            .padding(.top, Spacing.tight)
    }
}

extension VocabularyDocument {
    /// Adds the card of `text`, or its two directions, see `WordPair`, as one undo step.
    /// Returns the number of cards added, 0 while the document can't be changed.
    func addCards(for text: CardText, bothDirections: Bool) -> Int {
        if bothDirections {
            return add(WordPair.cards(for: text, created: clock.now))
        }
        return add(text) == nil ? 0 : 1
    }
}
