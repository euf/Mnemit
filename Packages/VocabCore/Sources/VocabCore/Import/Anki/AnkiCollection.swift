import Foundation

/// Reads notes, cards and reviews from an Anki collection. Two schemas exist: 11, where
/// note types and decks are JSON in the one row of `col` (Legacy 1 and 2), and 18, where
/// they are tables with protobuf columns (Latest). `notes`, `cards` and `revlog` are the
/// same in both.
struct AnkiCollection {
    /// What the import needs to know about a note type.
    struct NoteType {
        var isCloze = false
        var fieldNames: [String] = []
        /// The question template of each card, by `cards.ord`.
        var questionFormats: [Int: String] = [:]
    }

    let database: AnkiDatabase

    func imported() throws -> AnkiImport {
        let isCurrent = try database.hasTable("notetypes")
        let noteTypes = try isCurrent ? currentNoteTypes() : legacyNoteTypes()
        let decks = try isCurrent ? currentDecks() : legacyDecks()
        let threeButtons = try !isCurrent && usesThreeLearningButtons()
        var log = try reviews(threeButtons: threeButtons)

        var result = AnkiImport()
        var usedDecks = Set<Int>()
        // The deck a filtered card came from is `odid`.
        let cards = try database.rows(
            """
            SELECT c.id, c.ord, c.queue, CASE WHEN c.odid != 0 THEN c.odid ELSE c.did END, n.mid, n.flds
            FROM cards c JOIN notes n ON n.id = c.nid
            ORDER BY n.id, c.ord, c.id
            """
        ) { ($0.int(0), $0.int(1), $0.int(2), $0.int(3), $0.int(4), $0.text(5)) }

        for (id, ord, queue, deck, noteType, fields) in cards {
            let type = noteTypes[noteType] ?? NoteType()
            if type.isCloze {
                result.skippedCloze += 1
                continue
            }
            let values = fields.split(separator: "\u{1F}", omittingEmptySubsequences: false).map(String.init)
            let (front, back) = fieldIndices(ofCardAt: ord, in: type)
            let question = AnkiText.plain(front < values.count ? values[front] : "")
            let answer = AnkiText.plain(back < values.count ? values[back] : "")
            result.skippedMediaRefs += (question.hadMedia ? 1 : 0) + (answer.hadMedia ? 1 : 0)
            guard !question.text.isEmpty, !answer.text.isEmpty else {
                result.skippedEmpty += 1
                continue
            }
            usedDecks.insert(deck)
            result.notes.append(AnkiImport.Note(front: question.text, back: answer.text, reviews: log.removeValue(forKey: id) ?? [], isSuspended: queue == -1))
        }
        result.deckNames = usedDecks.compactMap { decks[$0] }.sorted()
        return result
    }

    /// The fields a card asks from and answers with: the first field its question template
    /// shows, and the first of the others. Without a template to read, the first and the second.
    private func fieldIndices(ofCardAt ord: Int, in type: NoteType) -> (front: Int, back: Int) {
        guard let format = type.questionFormats[ord], let shown = Self.firstField(shownBy: format, in: type.fieldNames), shown != 0 else {
            return (0, 1)
        }
        return (shown, 0)
    }

    /// The index of the first field a template shows. Conditions (`{{#Field}}`, `{{^Field}}`)
    /// don't show anything, and a filter (`{{type:Field}}`, `{{hint:Field}}`) leaves the field after it.
    static func firstField(shownBy format: String, in fieldNames: [String]) -> Int? {
        var rest = Substring(format)
        while let open = rest.range(of: "{{"), let close = rest.range(of: "}}", range: open.upperBound..<rest.endIndex) {
            let tag = rest[open.upperBound..<close.lowerBound].trimmingCharacters(in: .whitespaces)
            rest = rest[close.upperBound...]
            guard let first = tag.first, !"#^/!".contains(first) else { continue }
            let name = tag.split(separator: ":", omittingEmptySubsequences: false).last.map(String.init) ?? tag
            if let index = fieldNames.firstIndex(of: name) { return index }
        }
        return nil
    }

    // MARK: Reviews

    /// The reviews of the cards, by card, oldest first.
    private func reviews(threeButtons: Bool) throws -> [Int: [ReviewLogEntry]] {
        var result: [Int: [ReviewLogEntry]] = [:]
        let entries = try database.rows("SELECT id, cid, ease, type, factor FROM revlog ORDER BY id") {
            ($0.int(0), $0.int(1), $0.int(2), $0.int(3), $0.int(4))
        }
        for (id, card, ease, type, factor) in entries {
            guard let grade = Self.grade(ease: ease, type: type, factor: factor, threeButtons: threeButtons) else { continue }
            // `id` is the time in milliseconds; the review log of a deck counts whole seconds.
            let date = Date(timeIntervalSince1970: Double(id / 1000))
            result[card, default: []].append(ReviewLogEntry(date: date, grade: grade, mode: .revealed))
        }
        return result
    }

    /// `type`: 0 learning, 1 review, 2 relearning, 3 filtered (cram), 4 manual, 5 rescheduled.
    /// A manual entry and cramming with `factor` 0, which Anki leaves out of the memory
    /// state as well, give none. With the scheduler of Anki 2.0 a card in (re)learning
    /// had three buttons: Again, Good, Easy.
    static func grade(ease: Int, type: Int, factor: Int, threeButtons: Bool) -> Grade? {
        guard (1...4).contains(ease), type != 4, type != 5, !(type == 3 && factor == 0) else { return nil }
        if threeButtons, type == 0 || type == 2 {
            return ease == 1 ? .again : ease == 2 ? .good : ease == 3 ? .easy : nil
        }
        return Grade(rawValue: ease)
    }

    /// Whether the entries of learning cards come from the first scheduler, `schedVer`
    /// missing or 1 in the configuration. Schema 11 only; a current collection has
    /// four buttons everywhere.
    private func usesThreeLearningButtons() throws -> Bool {
        let configuration = try database.rows("SELECT conf FROM col") { $0.text(0) }.first ?? ""
        let object = try? JSONSerialization.jsonObject(with: Data(configuration.utf8)) as? [String: Any]
        return ((object?["schedVer"] as? Int) ?? 1) == 1
    }

    // MARK: Schema 11

    private func legacyJSON(_ column: String) throws -> [String: [String: Any]] {
        let text = try database.rows("SELECT \(column) FROM col") { $0.text(0) }.first ?? ""
        guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: [String: Any]] else {
            throw AnkiImport.Error.unreadableCollection
        }
        return object
    }

    private func legacyNoteTypes() throws -> [Int: NoteType] {
        var result: [Int: NoteType] = [:]
        for (key, model) in try legacyJSON("models") {
            guard let id = Int(key) else { continue }
            var type = NoteType()
            type.isCloze = (model["type"] as? Int) == 1
            let fields = (model["flds"] as? [[String: Any]]) ?? []
            type.fieldNames = fields.sorted { ($0["ord"] as? Int ?? 0) < ($1["ord"] as? Int ?? 0) }.map { $0["name"] as? String ?? "" }
            for template in (model["tmpls"] as? [[String: Any]]) ?? [] {
                if let ord = template["ord"] as? Int, let format = template["qfmt"] as? String {
                    type.questionFormats[ord] = format
                }
            }
            result[id] = type
        }
        return result
    }

    private func legacyDecks() throws -> [Int: String] {
        var result: [Int: String] = [:]
        for (key, deck) in try legacyJSON("decks") {
            if let id = Int(key), let name = deck["name"] as? String { result[id] = name }
        }
        return result
    }

    // MARK: Schema 18

    private func currentNoteTypes() throws -> [Int: NoteType] {
        var result: [Int: NoteType] = [:]
        for (id, config) in try database.rows("SELECT id, config FROM notetypes", { ($0.int(0), $0.data(1)) }) {
            // KIND_CLOZE = 1; proto3 leaves out the default, KIND_NORMAL.
            result[id] = NoteType(isCloze: ProtobufFields(config).varint(1) == 1)
        }
        for (id, name) in try database.rows("SELECT ntid, name FROM fields ORDER BY ntid, ord", { ($0.int(0), $0.text(1)) }) {
            result[id]?.fieldNames.append(name)
        }
        for (id, ord, config) in try database.rows("SELECT ntid, ord, config FROM templates", { ($0.int(0), $0.int(1), $0.data(2)) }) {
            // Template.Config.q_format is field 1.
            if let format = ProtobufFields(config).bytes(1) {
                result[id]?.questionFormats[ord] = String(decoding: format, as: UTF8.self)
            }
        }
        return result
    }

    private func currentDecks() throws -> [Int: String] {
        // A deck's name holds its parents separated by U+001F.
        Dictionary(
            uniqueKeysWithValues: try database.rows("SELECT id, name FROM decks") {
                ($0.int(0), $0.text(1).replacingOccurrences(of: "\u{1F}", with: "::"))
            })
    }
}
