import Compression
import Foundation
import SQLite3
import libzstd

@testable import VocabCore

/// Builds the files an Anki package is made of, for tests of `AnkiImport`: a ZIP, a
/// zstd frame, and the SQLite collections of schema 11 and 18 with the columns the
/// importer reads.
enum AnkiFixtures {
    // MARK: ZIP

    /// A ZIP file with `entries` in order; an entry is deflated unless it is listed in `stored`.
    static func zip(_ entries: [(name: String, data: Data)], stored: Set<String> = [], comment: Data = Data()) -> Data {
        var file = Data()
        var directory = Data()
        for (name, data) in entries {
            let isStored = stored.contains(name)
            let packed = isStored ? data : deflate(data)
            let nameBytes = Data(name.utf8)
            // Version, flags, method, time and date, then CRC and sizes, then the lengths of name and extra.
            let common = [
                le16(20), le16(0), le16(isStored ? 0 : 8), le32(0),
                le32(crc32(data)), le32(UInt32(packed.count)), le32(UInt32(data.count)), le16(UInt16(nameBytes.count)), le16(0),
            ]
            let local = [le32(0x0403_4B50)] + common + [nameBytes]
            // The directory holds a version made by, and after the lengths a comment, disk, attributes and the offset.
            let entry =
                [le32(0x0201_4B50), le16(20)] + common
                + [le16(0), le16(0), le16(0), le32(0), le32(UInt32(file.count)), nameBytes]
            directory.append(Data(entry.joined()))
            file.append(Data(local.joined()))
            file.append(packed)
        }
        let directoryOffset = file.count
        file.append(directory)
        let end = [
            le32(0x0605_4B50), le16(0), le16(0), le16(UInt16(entries.count)), le16(UInt16(entries.count)),
            le32(UInt32(directory.count)), le32(UInt32(directoryOffset)), le16(UInt16(comment.count)), comment,
        ]
        file.append(Data(end.joined()))
        return file
    }

    static func deflate(_ data: Data) -> Data {
        guard !data.isEmpty else { return Data() }
        var output = Data(count: data.count + 1024)
        let size = output.withUnsafeMutableBytes { destination in
            data.withUnsafeBytes { source in
                compression_encode_buffer(
                    destination.bindMemory(to: UInt8.self).baseAddress!, destination.count,
                    source.bindMemory(to: UInt8.self).baseAddress!, source.count, nil, COMPRESSION_ZLIB)
            }
        }
        return output.prefix(size)
    }

    private static func le16(_ value: UInt16) -> Data { Data([UInt8(value & 0xFF), UInt8(value >> 8)]) }
    private static func le32(_ value: UInt32) -> Data { le16(UInt16(value & 0xFFFF)) + le16(UInt16(value >> 16)) }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = crc & 1 == 1 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1 }
        }
        return ~crc
    }

    // MARK: zstd

    static func zstd(_ data: Data, level: Int32 = 3) -> Data {
        var output = Data(count: ZSTD_compressBound(data.count))
        let size = output.withUnsafeMutableBytes { destination in
            data.withUnsafeBytes { source in
                ZSTD_compress(destination.baseAddress, destination.count, source.baseAddress, source.count, level)
            }
        }
        return output.prefix(size)
    }

    // MARK: Protobuf

    static func varint(_ value: UInt64) -> Data {
        var value = value
        var bytes = Data()
        while value >= 0x80 {
            bytes.append(UInt8(value & 0x7F) | 0x80)
            value >>= 7
        }
        bytes.append(UInt8(value))
        return bytes
    }

    /// A message with one varint field, like `PackageMetadata`.
    static func varintField(_ number: Int, _ value: UInt64) -> Data { varint(UInt64(number << 3)) + varint(value) }

    /// A message field: a length-delimited `payload`.
    static func bytesField(_ number: Int, _ payload: Data) -> Data {
        varint(UInt64(number << 3 | 2)) + varint(UInt64(payload.count)) + payload
    }

    private static func littleEndian(_ value: Float) -> Data {
        Data((0..<4).map { UInt8(truncatingIfNeeded: value.bitPattern >> UInt32(8 * $0)) })
    }

    /// A `float` field: wire type 5, four bytes little-endian.
    static func floatField(_ number: Int, _ value: Float) -> Data {
        varint(UInt64(number << 3 | 5)) + littleEndian(value)
    }

    /// A `repeated float` field, packed (as proto3 writes it) or as one field per value.
    static func floatsField(_ number: Int, _ values: [Float], packed: Bool = true) -> Data {
        guard packed else { return values.reduce(Data()) { $0 + floatField(number, $1) } }
        return values.isEmpty ? Data() : bytesField(number, values.reduce(Data()) { $0 + littleEndian($1) })
    }

    /// A message with one string field, like `Notetype.Template.Config`.
    static func stringField(_ number: Int, _ value: String) -> Data {
        varint(UInt64(number << 3 | 2)) + varint(UInt64(value.utf8.count)) + Data(value.utf8)
    }

    // MARK: SQLite

    /// The bytes of a new database after running `statements`.
    static func database(_ statements: [String]) -> Data {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("anki-fixture-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: url) }
        var handle: OpaquePointer?
        precondition(sqlite3_open(url.path, &handle) == SQLITE_OK)
        AnkiDatabase.addCollation(to: handle)
        for statement in statements {
            precondition(sqlite3_exec(handle, statement, nil, nil, nil) == SQLITE_OK, "\(statement)")
        }
        sqlite3_close(handle)
        return try! Data(contentsOf: url)
    }

    /// A card of a collection in the shape `cards` and `notes` have in both schemas.
    struct RawCard {
        var id: Int
        var note: Int
        var deck = 1
        var ord = 0
        var queue = 0
        var filteredFrom = 0
    }

    struct RawNote {
        var id: Int
        var model: Int
        var fields: [String]
    }

    struct RawReview {
        var id: Int
        var card: Int
        var ease: Int
        var type = 1
        var factor = 2500
        /// Milliseconds the answer took; 0 where Anki didn't measure.
        var time = 0
    }

    static func quoted(_ text: String) -> String { "'" + text.replacingOccurrences(of: "'", with: "''") + "'" }

    private static let commonTables = [
        "CREATE TABLE notes (id integer PRIMARY KEY, mid integer, flds text)",
        "CREATE TABLE cards (id integer PRIMARY KEY, nid integer, did integer, ord integer, queue integer, odid integer)",
        "CREATE TABLE revlog (id integer PRIMARY KEY, cid integer, ease integer, type integer, factor integer, time integer)",
    ]

    private static func rows(notes: [RawNote], cards: [RawCard], reviews: [RawReview]) -> [String] {
        notes.map { "INSERT INTO notes VALUES (\($0.id), \($0.model), \(quoted($0.fields.joined(separator: "\u{1F}"))))" }
            + cards.map { "INSERT INTO cards VALUES (\($0.id), \($0.note), \($0.deck), \($0.ord), \($0.queue), \($0.filteredFrom))" }
            + reviews.map { "INSERT INTO revlog VALUES (\($0.id), \($0.card), \($0.ease), \($0.type), \($0.factor), \($0.time))" }
    }

    /// A deck preset: the FSRS lists of Anki's three versions and the desired retention
    /// (`nil` leaves it out, as proto3 does for 0 and old collections do altogether).
    struct RawPreset {
        var id: Int
        var name = "Default"
        var fsrs4: [Float] = []
        var fsrs5: [Float] = []
        var fsrs6: [Float] = []
        var desiredRetention: Float? = 0.9
        /// Schema 18 only: whether the lists are written packed.
        var isPacked = true
    }

    struct RawNoteType {
        var id: Int
        var name = "Basic"
        var fields = ["Front", "Back"]
        var templates = ["{{Front}}"]
        /// The answer template of each card; a card without one has an empty one.
        var answers: [String] = []
        var isCloze = false
    }

    /// A collection of schema 11, where note types, decks and the configuration are JSON in `col`.
    static func legacyCollection(
        noteTypes: [RawNoteType] = [RawNoteType(id: 1)], decks: [Int: String] = [1: "Default"], schedulerVersion: Int? = 2,
        presets: [RawPreset]? = nil, deckPresets: [Int: Int] = [:],
        notes: [RawNote], cards: [RawCard], reviews: [RawReview] = []
    ) -> Data {
        func json(_ object: Any) -> String {
            String(decoding: try! JSONSerialization.data(withJSONObject: object), as: UTF8.self)
        }
        var models: [String: Any] = [:]
        for type in noteTypes {
            models[String(type.id)] = [
                "name": type.name, "type": type.isCloze ? 1 : 0,
                "flds": type.fields.enumerated().map { ["name": $0.element, "ord": $0.offset] },
                "tmpls": type.templates.enumerated().map { ["name": "Card \($0.offset + 1)", "ord": $0.offset, "qfmt": $0.element, "afmt": type.answers.indices.contains($0.offset) ? type.answers[$0.offset] : ""] },
            ]
        }
        let conf: [String: Any] = schedulerVersion.map { ["schedVer": $0] } ?? [:]
        var deckObjects: [String: [String: Any]] = [:]
        for (id, name) in decks {
            var object: [String: Any] = ["name": name]
            object["conf"] = deckPresets[id]
            deckObjects[String(id)] = object
        }
        // `dconf` is only there if there are presets, so the importer is tried without it, too.
        var table = "CREATE TABLE col (conf text, models text, decks text"
        var values = "\(quoted(json(conf))), \(quoted(json(models))), \(quoted(json(deckObjects)))"
        if let presets {
            var objects: [String: [String: Any]] = [:]
            for preset in presets {
                var object: [String: Any] = ["name": preset.name, "fsrsWeights": preset.fsrs4, "fsrsParams5": preset.fsrs5, "fsrsParams6": preset.fsrs6]
                object["desiredRetention"] = preset.desiredRetention
                objects[String(preset.id)] = object
            }
            table += ", dconf text"
            values += ", \(quoted(json(objects)))"
        }
        return database([table + ")"] + commonTables + ["INSERT INTO col VALUES (\(values))"] + rows(notes: notes, cards: cards, reviews: reviews))
    }

    /// A collection of schema 18: tables for note types, fields, templates and decks, with
    /// protobuf `config` blobs and Anki's own collation on the names.
    static func currentCollection(
        noteTypes: [RawNoteType] = [RawNoteType(id: 1)], decks: [Int: String] = [1: "Default"],
        presets: [RawPreset]? = nil, deckPresets: [Int: Int] = [:],
        notes: [RawNote], cards: [RawCard], reviews: [RawReview] = []
    ) -> Data {
        func hex(_ data: Data) -> String { "X'" + data.map { String(format: "%02x", $0) }.joined() + "'" }
        var statements = [
            "CREATE TABLE notetypes (id integer NOT NULL PRIMARY KEY, name text NOT NULL COLLATE unicase, mtime_secs integer, usn integer, config blob NOT NULL)",
            "CREATE UNIQUE INDEX idx_notetypes_name ON notetypes (name)",
            "CREATE TABLE fields (ntid integer NOT NULL, ord integer NOT NULL, name text NOT NULL COLLATE unicase, config blob, PRIMARY KEY (ntid, ord)) without rowid",
            "CREATE UNIQUE INDEX idx_fields_name_ntid ON fields (name, ntid)",
            "CREATE TABLE templates (ntid integer NOT NULL, ord integer NOT NULL, name text NOT NULL COLLATE unicase, config blob NOT NULL, PRIMARY KEY (ntid, ord)) without rowid",
            "CREATE TABLE decks (id integer PRIMARY KEY NOT NULL, name text NOT NULL COLLATE unicase, common blob, kind blob)",
            "CREATE UNIQUE INDEX idx_decks_name ON decks (name)",
        ]
        for type in noteTypes {
            // Kind 0 is the default and not written.
            let config = type.isCloze ? varintField(1, 1) : varintField(2, 0)
            statements.append("INSERT INTO notetypes VALUES (\(type.id), \(quoted(type.name)), 0, 0, \(hex(config)))")
            for (ord, name) in type.fields.enumerated() {
                statements.append("INSERT INTO fields VALUES (\(type.id), \(ord), \(quoted(name)), X'')")
            }
            for (ord, format) in type.templates.enumerated() {
                // Template.Config: q_format is field 1, a_format field 2.
                let answer = type.answers.indices.contains(ord) ? stringField(2, type.answers[ord]) : Data()
                statements.append("INSERT INTO templates VALUES (\(type.id), \(ord), 'Card \(ord + 1)', \(hex(stringField(1, format) + answer)))")
            }
        }
        for (id, name) in decks {
            // `kind` is a `KindContainer`: field 1 is the normal deck, whose field 1 is the preset.
            let kind = deckPresets[id].map { bytesField(1, varintField(1, UInt64($0))) } ?? Data()
            statements.append("INSERT INTO decks VALUES (\(id), \(quoted(name.replacingOccurrences(of: "::", with: "\u{1F}"))), X'', \(hex(kind)))")
        }
        if let presets {
            statements.append("CREATE TABLE deck_config (id integer NOT NULL PRIMARY KEY, name text NOT NULL COLLATE unicase, mtime_secs integer NOT NULL, usn integer NOT NULL, config blob NOT NULL)")
            for preset in presets {
                // Fields of other kinds come before, between and after the ones read: learn_steps (1), new_per_day (9), other (255).
                var config = floatsField(1, [1, 10]) + floatsField(3, preset.fsrs4, packed: preset.isPacked) + varintField(9, 20)
                config += floatsField(5, preset.fsrs5, packed: preset.isPacked) + floatsField(6, preset.fsrs6, packed: preset.isPacked)
                config += preset.desiredRetention.map { floatField(37, $0) } ?? Data()
                config += bytesField(255, Data("{}".utf8))
                statements.append("INSERT INTO deck_config VALUES (\(preset.id), \(quoted(preset.name)), 0, 0, \(hex(config)))")
            }
        }
        return database(commonTables + statements + rows(notes: notes, cards: cards, reviews: reviews))
    }

    // MARK: Packages

    static let latestMeta = varintField(1, 3)
    static let legacy2Meta = varintField(1, 2)
    static let placeholder = database(["CREATE TABLE placeholder (note text)", "INSERT INTO placeholder VALUES ('Please update to the latest Anki')"])
}
