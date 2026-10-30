import Foundation
import VocabCore

/// The progress ledger (`DayLedger`) on disk, shared by the Mac and the iPhone: `.mnemit-progress/` in the folder of the
/// decks, one JSON Lines file per device, `<device id>.jsonl`. A device writes only its own file and reads all of
/// them, merged by the per-day rule of `DayLedger.merging`, so iCloud Drive never has two devices write one file.
///
/// Every read and write goes through `NSFileCoordinator`, inside the folder's security-scoped access. A file that
/// iCloud Drive has not downloaded yet is only a hidden placeholder, ".<name>.icloud": its download starts here and it is
/// skipped this time. Call it off the main actor.
struct ProgressLedgerStore: Equatable, Sendable {
    /// The user defaults key of the device id.
    static let deviceKey = "ProgressLedgerDevice"
    static let directoryName = ".mnemit-progress"
    static let fileExtension = "jsonl"

    /// The folder of the decks, the one whose security-scoped access the reads and writes take.
    let folder: URL
    let deviceID: String

    var directory: URL { folder.appending(path: Self.directoryName, directoryHint: .isDirectory) }

    /// The ledger of the decks in `folder`; without a folder (none chosen yet) the app's own Application Support
    /// directory, which only this device reads. `defaults` keeps the device id, made on first use.
    init(folder: URL?, defaults: UserDefaults = .standard) {
        self.folder = folder ?? URL.applicationSupportDirectory.appending(path: "Mnemit", directoryHint: .isDirectory)
        if let id = defaults.string(forKey: Self.deviceKey), !id.isEmpty {
            deviceID = id
        } else {
            deviceID = UUID().uuidString
            defaults.set(deviceID, forKey: Self.deviceKey)
        }
    }

    /// This device's file.
    var file: URL { directory.appending(path: "\(deviceID).\(Self.fileExtension)", directoryHint: .notDirectory) }

    /// Every device's file, merged. Empty where there is none.
    func read() -> DayLedger {
        let isAccessing = folder.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                folder.stopAccessingSecurityScopedResource()
            }
        }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        var ledger = DayLedger()
        for name in names {
            if name.hasPrefix("."), name.hasSuffix(".icloud") {
                let real = String(name.dropFirst().dropLast(".icloud".count))
                if real.hasSuffix(".\(Self.fileExtension)") {
                    try? FileManager.default.startDownloadingUbiquitousItem(at: directory.appending(path: real, directoryHint: .notDirectory))
                }
            } else if name.hasSuffix(".\(Self.fileExtension)"), let data = Self.data(at: directory.appending(path: name, directoryHint: .notDirectory)) {
                ledger = ledger.merging(DayLedger.decode(data))
            }
        }
        return ledger
    }

    /// Makes this device's file `ledger` (what `read()` gave, with the updates merged in), in one coordinated write.
    func write(_ ledger: DayLedger) {
        let isAccessing = folder.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                folder.stopAccessingSecurityScopedResource()
            }
        }
        // This device's file as it can't be read now (a placeholder iCloud Drive hasn't downloaded, a failed
        // coordinated read) holds the sizes of the days it recorded: replacing it with `ledger`, which lacks them,
        // would write them anew. The next evaluation reads it.
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        if names.contains(".\(file.lastPathComponent).icloud") || (FileManager.default.fileExists(atPath: file.path) && Self.data(at: file) == nil) {
            return
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var error: NSError?
        NSFileCoordinator().coordinate(writingItemAt: file, options: .forReplacing, error: &error) { url in
            try? ledger.encoded().write(to: url, options: .atomic)
        }
    }

    private static func data(at url: URL) -> Data? {
        var data: Data?
        var error: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { url in
            data = try? Data(contentsOf: url)
        }
        return data
    }
}
