import Foundation
import VocabCore

/// Copies of a deck package made before a run writes it.
public enum Backup {
    public static let keep = 10

    /// Copies the package at `deck` to `<directory>/<name>-<yyyyMMdd-HHmmss>.mnemit`
    /// and removes all but the newest `keep` copies of that deck there, whichever
    /// deck extension they have.
    ///
    /// - Parameter directory: Defaults to `.backups` next to the deck.
    /// - Returns: The copy.
    @discardableResult
    public static func make(of deck: URL, in directory: URL?, at now: Date, keeping keep: Int = Backup.keep) throws -> URL {
        let directory = directory ?? deck.deletingLastPathComponent().appendingPathComponent(".backups")
        let name = deck.deletingPathExtension().lastPathComponent
        let files = FileManager.default
        try files.createDirectory(at: directory, withIntermediateDirectories: true)

        let stamp = stamp(of: now)
        var copy = directory.appendingPathComponent("\(name)-\(stamp).\(DeckFile.fileExtension)")
        var counter = 2
        while files.fileExists(atPath: copy.path) {
            copy = directory.appendingPathComponent("\(name)-\(stamp)-\(counter).\(DeckFile.fileExtension)")
            counter += 1
        }
        try files.copyItem(at: deck, to: copy)

        // Only this deck's copies, named like the ones above, count and go; the newest first.
        let copies = try files.contentsOfDirectory(atPath: directory.path)
            .compactMap { file in order(of: file, deck: name).map { (file, $0) } }
            .sorted { $0.1 > $1.1 }
        for (old, _) in copies.dropFirst(keep) {
            try files.removeItem(at: directory.appendingPathComponent(old))
        }
        return copy
    }

    private static func stamp(of date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    /// The age of a copy's file name as a sort key, `nil` if `file` isn't a copy of `deck`:
    /// the timestamp, then the counter of copies made in the same second.
    static func order(of file: String, deck: String) -> String? {
        guard file.hasPrefix(deck + "-"), let ext = DeckFile.fileExtensions.first(where: { file.hasSuffix("." + $0) }) else { return nil }
        let parts = file.dropFirst(deck.count + 1).dropLast(ext.count + 1).split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2 || parts.count == 3, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isWholeNumber) }),
            parts[0].count == 8, parts[1].count == 6
        else { return nil }
        let counter = parts.count == 3 ? String(parts[2]) : "1"
        return parts[0] + parts[1] + String(repeating: "0", count: max(0, 6 - counter.count)) + counter
    }
}
