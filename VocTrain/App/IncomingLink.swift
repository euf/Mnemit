import Foundation

/// What a URL the app was opened with asks for, see `StartScreen.open(_:)`.
enum IncomingLink: Equatable {
    /// The widget's `mnemit://study`: Study starts at once.
    case study
    /// An Anki package from "Open in Mnemit" in Files, Safari or Mail: its cards go to a deck
    /// the learner chooses.
    case ankiPackage
    /// A deck file from Files, which joins the list; any other URL ends up here, too.
    case deck

    init(_ url: URL) {
        if WidgetLink.isStudy(url) {
            self = .study
        } else if url.isAnkiPackage {
            self = .ankiPackage
        } else {
            self = .deck
        }
    }
}

/// A package that "Open in Mnemit" brought, as the copy `IncomingPackages` made of it.
struct IncomingPackage: Identifiable {
    let id = UUID()
    var url: URL
}

/// The copies of Anki packages that "Open in Mnemit" brought. The URL the system hands over may
/// be security-scoped, in the Inbox, or in iCloud Drive without being downloaded, and it is
/// read much later than the call, so the package is copied at once. A copy lives in a folder of
/// its own under the temporary directory until the next package comes; the system clears the
/// directory in between.
enum IncomingPackages {
    static let folder = URL.temporaryDirectory.appending(path: "IncomingAnki", directoryHint: .isDirectory)

    /// Copies the package at `url` off the main thread and returns the copy, which keeps the name.
    static func copy(_ url: URL, into folder: URL = folder) async throws -> URL {
        try await Task.detached {
            let isScoped = url.startAccessingSecurityScopedResource()
            defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
            let directory = folder.appending(path: UUID().uuidString, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let target = directory.appending(path: url.lastPathComponent, directoryHint: .notDirectory)
            var coordination: NSError?
            var failure: (any Error)?
            // Coordinated, as a file of iCloud Drive is downloaded first.
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordination) { source in
                do {
                    try FileManager.default.copyItem(at: source, to: target)
                } catch {
                    failure = error
                }
            }
            if let coordination { throw coordination }
            if let failure { throw failure }
            return target
        }.value
    }

    /// Removes every copy.
    static func purge(_ folder: URL = folder) {
        try? FileManager.default.removeItem(at: folder)
    }
}
