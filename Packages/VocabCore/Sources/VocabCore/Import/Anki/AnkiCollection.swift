import Foundation

/// Reads notes, cards and reviews from an Anki collection. Two schemas exist: 11, where
/// note types, decks and deck presets are JSON in the one row of `col` (Legacy 1 and 2), and
/// 18, where they are tables with protobuf columns (Latest). `notes`, `cards` and `revlog`
/// are the same in both.
struct AnkiCollection {
    /// What the import needs to know about a note type.
    struct NoteType {
        var isCloze = false
        var fieldNames: [String] = []
        /// How many card templates the note type has: the cards a note makes, at most.
        var templateCount = 0
        /// The question and the answer template of each card, by `cards.ord`.
        var questionFormats: [Int: String] = [:]
        var answerFormats: [Int: String] = [:]

        /// Whether the note type is a reverse pair: two templates, the second of which asks from
        /// the field the first answers with ("Basic (and reversed card)", "Basic (optional reversed
        /// card)"). A template that can't be read makes it no pair.
        var isReversePair: Bool {
            guard templateCount == 2, let asks = questionFormats[0], let answers = answerFormats[0], let reverse = questionFormats[1] else { return false }
            let asked = AnkiCollection.fields(shownBy: asks, in: fieldNames, showsTyped: false)
            let answer = AnkiCollection.fields(shownBy: answers, in: fieldNames, showsTyped: true).first { !asked.contains($0) }
            return answer != nil && answer == AnkiCollection.fields(shownBy: reverse, in: fieldNames, showsTyped: false).first
        }

        /// The word key and the direction of the card `ord` of the note `guid`, which make the cards
        /// of one note siblings (`Card.note`, `Card.kind`). A note type with one template has
        /// neither. One with several shares the key of the note, so that the siblings are buried for
        /// the day; the second card of a reverse pair asks the other way (`.production`, which waits
        /// for the first to be learned), every other card is `.recognition`.
        func sibling(ofCardAt ord: Int, guid: String) -> (note: String?, kind: CardKind?) {
            guard templateCount > 1, let note = Card.normalized(guid) else { return (nil, nil) }
            return (note, ord == 1 && isReversePair ? .production : .recognition)
        }
    }

    /// One side of a card: its text, and the first image and the first sound of the fields the
    /// side shows, by their names in Anki. Without a text, an image and a sound it is empty.
    struct Side {
        var text = ""
        var image: String?
        var audio: String?
        /// Whether a field the side shows referred to an image or a sound at all.
        var referencesMedia = false
        /// Whether one of them is left out: the package lacks the file, or the side already has
        /// another image or sound.
        var leavesMediaOut = false

        var isEmpty: Bool { text.isEmpty && image == nil && audio == nil }
    }

    /// A deck: its name, and the number of its preset if it names one.
    struct Deck {
        var name: String
        var preset: Int?
    }

    let database: AnkiDatabase
    /// The files the package holds, which a card's image or sound has to be among.
    var media = AnkiMedia()

    func imported() throws -> AnkiImport {
        let isCurrent = try database.hasTable("notetypes")
        let noteTypes = try isCurrent ? currentNoteTypes() : legacyNoteTypes()
        let decks = try isCurrent ? currentDecks() : legacyDecks()
        // The presets only add settings, so a collection whose presets can't be read still imports.
        let presets = (try? isCurrent ? currentPresets() : legacyPresets()) ?? [:]
        let threeButtons = try !isCurrent && usesThreeLearningButtons()
        var log = try reviews(threeButtons: threeButtons)

        var result = AnkiImport()
        var usedDecks = Set<Int>()
        // The deck a filtered card came from is `odid`. The cards studied come first, in the order their notes were
        // made; the new ones (`type` 0) follow in Anki's new-card order, the position `due` holds (`odue` in a
        // filtered deck), so the deck's author's order is the order the new cards come in here.
        let cards = try database.rows(
            """
            SELECT c.id, c.ord, c.queue, CASE WHEN c.odid != 0 THEN c.odid ELSE c.did END, n.mid, n.flds, n.guid
            FROM cards c JOIN notes n ON n.id = c.nid
            ORDER BY c.type = 0, CASE WHEN c.type = 0 THEN (CASE WHEN c.odid != 0 THEN c.odue ELSE c.due END) END, n.id, c.ord, c.id
            """
        ) { ($0.int(0), $0.int(1), $0.int(2), $0.int(3), $0.int(4), $0.text(5), $0.text(6)) }

        for (id, ord, queue, deck, noteType, fields, guid) in cards {
            let type = noteTypes[noteType] ?? NoteType()
            if type.isCloze {
                result.skippedCloze += 1
                continue
            }
            let values = fields.split(separator: "\u{1F}", omittingEmptySubsequences: false).map(String.init)
            let (question, answer) = sides(ofCardAt: ord, in: type, values: values)
            result.skippedMediaRefs += (question.leavesMediaOut ? 1 : 0) + (answer.leavesMediaOut ? 1 : 0)
            guard !question.isEmpty, !answer.isEmpty else {
                result.skippedEmpty += 1
                if (question.isEmpty && question.referencesMedia) || (answer.isEmpty && answer.referencesMedia) {
                    result.skippedMediaOnly += 1
                }
                continue
            }
            usedDecks.insert(deck)
            // For now the preset is its number in Anki, which `presetNumbers` turns into an index below.
            let preset = decks[deck]?.preset.flatMap { presets[$0] == nil ? nil : $0 }
            let sibling = type.sibling(ofCardAt: ord, guid: guid)
            result.notes.append(
                AnkiImport.Note(
                    front: question.text, back: answer.text, reviews: log.removeValue(forKey: id) ?? [], isSuspended: queue == -1, preset: preset,
                    note: sibling.note, kind: sibling.kind,
                    media: CardMedia(questionImage: question.image, questionAudio: question.audio, answerImage: answer.image, answerAudio: answer.audio)))
        }
        result.deckNames = usedDecks.compactMap { decks[$0]?.name }.sorted()
        let presetNumbers = Set(result.notes.compactMap(\.preset)).sorted()
        result.presets = presetNumbers.compactMap { presets[$0] }
        for index in result.notes.indices {
            result.notes[index].preset = result.notes[index].preset.flatMap(presetNumbers.firstIndex(of:))
        }
        return result
    }

    /// What a card asks and answers with, from the fields of its note (`values`, in the order of
    /// the note type). The front is the first field with text that the question template shows;
    /// the back is the first with text that the answer template adds to those, and then, each on a
    /// line of its own and in the order of the template, the other fields the answer adds that have
    /// text (`isExtra(fieldNamed:text:)` leaves out those that are no words: frequency, rank, ids and the like). So
    /// a card with an example sentence in a field of its own has it on the back after the meaning.
    /// A field of an image or a sound has no text, so the next one is taken: "Front, Image, Audio,
    /// Back" gives the front and the back, not the image. Without a template to read, or one that
    /// shows no field, the first and the second field with text stand in for what it would have named.
    ///
    /// The image and the sound of a side are the first of each in the fields its template shows, text
    /// or not: the question of the vocabulary note type has its picture in a field of its own. Without
    /// a template, the fields the text was looked for in. The package has to hold the file; a side whose
    /// every reference is lost is empty if it has no text, and remembers that it had references.
    private func sides(ofCardAt ord: Int, in type: NoteType, values: [String]) -> (front: Side, back: Side) {
        func firstWithText(_ indices: [Int]) -> (index: Int?, text: String) {
            for index in indices where index < values.count {
                let text = AnkiText.plain(values[index]).text
                if !text.isEmpty { return (index, text) }
            }
            return (nil, "")
        }
        let all = Array(values.indices)
        let asked = type.questionFormats[ord].map { Self.fields(shownBy: $0, in: type.fieldNames, showsTyped: false) } ?? []
        let answered = type.answerFormats[ord].map { Self.fields(shownBy: $0, in: type.fieldNames, showsTyped: true) } ?? []
        let front = firstWithText(asked.isEmpty ? all : asked)
        let added = answered.filter { !asked.contains($0) }
        let candidates = (added.isEmpty ? all : added).filter { $0 != front.index }
        let back = firstWithText(candidates)

        var backText = back.text
        if !added.isEmpty, let first = back.index, let position = candidates.firstIndex(of: first) {
            for index in candidates[candidates.index(after: position)...] where index < values.count {
                let text = AnkiText.plain(values[index]).text
                if !text.isEmpty, !Self.isExtra(fieldNamed: index < type.fieldNames.count ? type.fieldNames[index] : "", text: text) {
                    backText += "\n" + text
                }
            }
        }
        // The fields a side shows hold its media. With no template, those the text was looked for in,
        // up to the one it came from.
        func shown(_ indices: [Int], upTo chosen: Int?, byTemplate: Bool) -> [Int] {
            guard !byTemplate, let chosen, let end = indices.firstIndex(of: chosen) else { return indices }
            return Array(indices[...end])
        }
        let frontShown = shown(asked.isEmpty ? all : asked, upTo: front.index, byTemplate: !asked.isEmpty)
        let backShown = shown(candidates, upTo: back.index, byTemplate: !added.isEmpty)
        return (side(front.text, shown: frontShown, values: values), side(backText, shown: backShown, values: values))
    }

    /// Whether a field that is not the first the answer adds is left off the back of a card:
    /// a field named for a frequency, a rank or an ID, or one whose text has no letter in it.
    static func isExtra(fieldNamed name: String, text: String) -> Bool {
        let name = name.lowercased()
        return ["freq", "rank", "id"].contains { name.contains($0) } || !text.contains { $0.isLetter }
    }

    /// The side with `text`, and the first image and the first sound the fields `shown` refer to
    /// that the package holds.
    private func side(_ text: String, shown: [Int], values: [String]) -> Side {
        var side = Side(text: text)
        for index in shown where index < values.count {
            for reference in AnkiText.mediaReferences(in: values[index]) {
                side.referencesMedia = true
                let file = media.name(for: reference.name)
                switch reference.kind {
                case .image where file != nil && (side.image == nil || side.image == file): side.image = file
                case .sound where file != nil && (side.audio == nil || side.audio == file): side.audio = file
                default: side.leavesMediaOut = true
                }
            }
        }
        return side
    }

    /// The indices of the fields a template shows, in order, each once. Conditions (`{{#Field}}`,
    /// `{{^Field}}`) don't show anything, and a filter (`{{hint:Field}}`) leaves the field after it.
    /// `{{type:Field}}` is a box to type the answer in: it shows the field only where `showsTyped`,
    /// on the answer side. Braces around a name are dropped, for a template that has a stray one
    /// (`{{{Field}}`).
    static func fields(shownBy format: String, in fieldNames: [String], showsTyped: Bool) -> [Int] {
        var result: [Int] = []
        var rest = Substring(format)
        while let open = rest.range(of: "{{"), let close = rest.range(of: "}}", range: open.upperBound..<rest.endIndex) {
            let tag = rest[open.upperBound..<close.lowerBound].trimmingCharacters(in: CharacterSet(charactersIn: "{} \t\n"))
            rest = rest[close.upperBound...]
            guard let first = tag.first, !"#^/!".contains(first) else { continue }
            let parts = tag.split(separator: ":", omittingEmptySubsequences: false)
            guard showsTyped || !parts.dropLast().contains("type") else { continue }
            if let index = fieldNames.firstIndex(of: parts.last.map(String.init) ?? tag), !result.contains(index) {
                result.append(index)
            }
        }
        return result
    }

    // MARK: Reviews

    /// The reviews of the cards, by card, oldest first.
    private func reviews(threeButtons: Bool) throws -> [Int: [ReviewLogEntry]] {
        var result: [Int: [ReviewLogEntry]] = [:]
        let entries = try database.rows("SELECT id, cid, ease, type, factor, time FROM revlog ORDER BY id") {
            ($0.int(0), $0.int(1), $0.int(2), $0.int(3), $0.int(4), $0.int(5))
        }
        for (id, card, ease, type, factor, time) in entries {
            guard let grade = Self.grade(ease: ease, type: type, factor: factor, threeButtons: threeButtons) else { continue }
            // `id` is the time in milliseconds; the review log of a deck counts whole seconds.
            let date = Date(timeIntervalSince1970: Double(id / 1000))
            // `time` is the milliseconds Anki's learner took to answer; 0 where it didn't measure.
            let duration: Duration? = time > 0 ? .milliseconds(time) : nil
            result[card, default: []].append(ReviewLogEntry(date: date, grade: grade, mode: .revealed, duration: duration))
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
            let templates = (model["tmpls"] as? [[String: Any]]) ?? []
            type.templateCount = templates.count
            for template in templates {
                if let ord = template["ord"] as? Int {
                    type.questionFormats[ord] = template["qfmt"] as? String
                    type.answerFormats[ord] = template["afmt"] as? String
                }
            }
            result[id] = type
        }
        return result
    }

    private func legacyDecks() throws -> [Int: Deck] {
        var result: [Int: Deck] = [:]
        for (key, deck) in try legacyJSON("decks") {
            if let id = Int(key), let name = deck["name"] as? String { result[id] = Deck(name: name, preset: deck["conf"] as? Int) }
        }
        return result
    }

    /// `col.dconf`: the keys of FSRS are `fsrsWeights` (FSRS-4.5), `fsrsParams5`, `fsrsParams6`
    /// and `desiredRetention`, as `DeckConfSchema11` in rslib names them.
    private func legacyPresets() throws -> [Int: AnkiPreset] {
        var result: [Int: AnkiPreset] = [:]
        for (key, configuration) in try legacyJSON("dconf") {
            func floats(_ key: String) -> [Float] {
                (configuration[key] as? [Any] ?? []).compactMap { ($0 as? NSNumber)?.floatValue }
            }
            guard let id = Int(key) else { continue }
            // `lapse.leechFails` and `lapse.leechAction` (0 suspend, 1 tag only).
            let lapse = configuration["lapse"] as? [String: Any]
            let leech = (lapse?["leechFails"] as? NSNumber).map { AnkiPreset.Leech(ankiThreshold: $0.intValue, ankiAction: (lapse?["leechAction"] as? NSNumber)?.intValue ?? 0) }
            result[id] = AnkiPreset(
                name: configuration["name"] as? String ?? "", fsrs4: floats("fsrsWeights"), fsrs5: floats("fsrsParams5"), fsrs6: floats("fsrsParams6"),
                desiredRetention: (configuration["desiredRetention"] as? NSNumber)?.floatValue ?? 0, leech: leech)
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
            // Template.Config.q_format is field 1, a_format field 2.
            result[id]?.templateCount += 1
            let fields = ProtobufFields(config)
            result[id]?.questionFormats[ord] = fields.bytes(1).map { String(decoding: $0, as: UTF8.self) }
            result[id]?.answerFormats[ord] = fields.bytes(2).map { String(decoding: $0, as: UTF8.self) }
        }
        return result
    }

    private func currentDecks() throws -> [Int: Deck] {
        // A deck's name holds its parents separated by U+001F. `kind` is a `KindContainer`:
        // field 1 is a normal deck, whose field 1 is the ID of its preset.
        Dictionary(
            uniqueKeysWithValues: try database.rows("SELECT id, name, kind FROM decks") {
                let normal = ProtobufFields($0.data(2)).bytes(1)
                let preset = normal.flatMap { ProtobufFields($0).varint(1) }.map { Int(truncatingIfNeeded: $0) }
                return ($0.int(0), Deck(name: $0.text(1).replacingOccurrences(of: "\u{1F}", with: "::"), preset: preset))
            })
    }

    /// `deck_config`: `config` is a `DeckConfig.Config`, where `fsrs_params_4`, `fsrs_params_5`
    /// and `fsrs_params_6` are the `repeated float` fields 3, 5 and 6 and `desired_retention`
    /// the `float` 37, `leech_action` the enum 21 (0 suspend, 1 tag only; proto3 leaves out 0) and
    /// `leech_threshold` the `uint32` 22 (`deck_config.proto`).
    private func currentPresets() throws -> [Int: AnkiPreset] {
        guard try database.hasTable("deck_config") else { return [:] }
        return Dictionary(
            uniqueKeysWithValues: try database.rows("SELECT id, name, config FROM deck_config") {
                let fields = ProtobufFields($0.data(2))
                // Anki writes the threshold of every preset, so a config without one has no leech settings.
                let leech = fields.varint(22).map { AnkiPreset.Leech(ankiThreshold: Int(truncatingIfNeeded: $0), ankiAction: Int(truncatingIfNeeded: fields.varint(21) ?? 0)) }
                return (
                    $0.int(0),
                    AnkiPreset(
                        name: $0.text(1), fsrs4: fields.floats(3), fsrs5: fields.floats(5), fsrs6: fields.floats(6), desiredRetention: fields.float(37) ?? 0,
                        leech: leech)
                )
            })
    }
}
