import Foundation
import SQLite3

/// A read-only SQLite database made from the bytes of an Anki collection.
///
/// SQLite opens files, so the bytes go to a temporary file that goes away with the
/// object. The file is opened `immutable`: no locks and no journal, which also makes a
/// collection saved in WAL mode readable without its (absent) `-wal` file.
final class AnkiDatabase {
    struct Row {
        fileprivate let statement: OpaquePointer

        func int(_ column: Int32) -> Int {
            Int(sqlite3_column_int64(statement, column))
        }

        func text(_ column: Int32) -> String {
            sqlite3_column_text(statement, column).map { String(cString: $0) } ?? ""
        }

        func data(_ column: Int32) -> Data {
            guard let bytes = sqlite3_column_blob(statement, column) else { return Data() }
            return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, column)))
        }
    }

    private var handle: OpaquePointer?
    private let file: URL

    /// - Throws: `AnkiImport.Error.unreadableCollection` if the bytes aren't a database.
    init(bytes: Data) throws {
        file = FileManager.default.temporaryDirectory.appendingPathComponent("anki-import-\(UUID().uuidString).db")
        do {
            try bytes.write(to: file)
        } catch {
            throw AnkiImport.Error.unreadableCollection
        }
        let path = file.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? file.path
        guard sqlite3_open_v2("file:\(path)?immutable=1", &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
            close()
            throw AnkiImport.Error.unreadableCollection
        }
        Self.addCollation(to: handle)
    }

    /// The names of note types, fields and decks in a current collection use Anki's own
    /// collation, "unicase"; an index on them can't be used without it. Which way it
    /// orders hardly matters here.
    static func addCollation(to handle: OpaquePointer?) {
        sqlite3_create_collation(handle, "unicase", SQLITE_UTF8, nil) { _, lengthA, a, lengthB, b in
            func string(_ bytes: UnsafeRawPointer?, _ length: Int32) -> String {
                guard let bytes else { return "" }
                return String(decoding: UnsafeRawBufferPointer(start: bytes, count: Int(length)), as: UTF8.self)
            }
            switch string(a, lengthA).compare(string(b, lengthB), options: .caseInsensitive) {
            case .orderedAscending: return -1
            case .orderedSame: return 0
            case .orderedDescending: return 1
            }
        }
    }

    deinit {
        close()
    }

    private func close() {
        sqlite3_close(handle)
        handle = nil
        try? FileManager.default.removeItem(at: file)
    }

    func hasTable(_ name: String) throws -> Bool {
        try rows("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = '\(name)'") { _ in true }.isEmpty == false
    }

    /// Runs `sql`, which takes no parameters, and maps each row.
    func rows<T>(_ sql: String, _ transform: (Row) throws -> T) throws -> [T] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw AnkiImport.Error.unreadableCollection
        }
        defer { sqlite3_finalize(statement) }
        var result: [T] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW: result.append(try transform(Row(statement: statement)))
            case SQLITE_DONE: return result
            default: throw AnkiImport.Error.unreadableCollection
            }
        }
    }
}
