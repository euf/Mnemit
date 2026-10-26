import Foundation
import VocabCore

/// Creating, renaming and deleting deck packages as files, for the iPhone's start and
/// deck screens. The folder of the decks may be on iCloud Drive, where other processes
/// work on the same files, so each goes through an `NSFileCoordinator`.
///
/// Every function is `async` and coordinates off the main thread: a deck that is open
/// has a UIDocument as its file presenter, which gives the file up on the main thread, so
/// a coordinated change on the main thread would wait for itself. Close an open deck
/// first (`OpenDeck.close()`) and open it at its new URL after a rename; a deck that is
/// closed no longer holds the file.
///
/// The caller must have access to the folder, as a folder from the file picker needs
/// `startAccessingSecurityScopedResource()`; `KnownDecks` keeps it while the app runs.
enum DeckFiles {
    enum Failure: LocalizedError, Equatable {
        /// The name is empty, starts with a dot or has a character a file name can't have.
        case invalidName
        /// The folder holds a deck of that name already, of either extension.
        case nameTaken(String)

        var errorDescription: String? {
            switch self {
            case .invalidName:
                String(localized: "A deck name can't be empty, start with a dot or contain “/” or “:”.")
            case let .nameTaken(name):
                String(localized: "A deck named “\(name)” already exists.")
            }
        }
    }

    /// Where `trash(_:)` put a deck.
    enum Trashed: Equatable {
        /// In the Trash of the location, from where Files or the Finder restore it.
        case trash
        /// The location has no Trash, as the folder of the app in the Simulator, which
        /// answers `featureUnsupported`: in the folder "Deleted Decks" next to the deck, at
        /// this URL. Nothing is deleted.
        case setAside(URL)
    }

    /// The folder `trash(_:)` moves a deck to where the location has no Trash.
    static let setAsideFolderName = "Deleted Decks"

    /// What `name` makes of a deck's file name, without the extension: trimmed, without a
    /// deck extension typed by habit; `nil` if it can't name a file.
    static func fileName(for name: String) -> String? {
        var name = CardText.trimmed(name)
        if let fileExtension = DeckFile.fileExtensions.first(where: { name.lowercased().hasSuffix("." + $0) }) {
            name = CardText.trimmed(String(name.dropLast(fileExtension.count + 1)))
        }
        let forbidden = CharacterSet(charactersIn: "/:").union(.controlCharacters)
        // A file name has at most 255 bytes.
        guard !name.isEmpty, !name.hasPrefix("."), name.rangeOfCharacter(from: forbidden) == nil, name.utf8.count <= 255 - 1 - DeckFile.fileExtension.utf8.count else {
            return nil
        }
        return name
    }

    // MARK: - Creating

    /// Creates an empty deck `<name>.mnemit` in `folder` and returns its URL. `introducesNewCards` is the
    /// mark the deck starts with, see `LearningOptions.introducesNewCards`.
    ///
    /// - Throws: `Failure.invalidName`; `Failure.nameTaken` if the folder holds a deck of
    ///   that name already, `.voctrain` too, or one iCloud Drive hasn't downloaded yet.
    @discardableResult
    static func create(named name: String, introducesNewCards: Bool = false, in folder: URL) async throws -> URL {
        guard let name = fileName(for: name) else { throw Failure.invalidName }
        return try await Task.detached {
            let url = deckURL(named: name, extension: DeckFile.fileExtension, in: folder)
            let package = try DeckFile.fileWrapper(for: Deck.new(introducesNewCards: introducesNewCards))
            try coordinate(writing: url, options: .forReplacing) { url in
                guard !holdsDeck(named: name, in: folder, except: nil) else { throw Failure.nameTaken(name) }
                try package.write(to: url, options: .atomic, originalContentsURL: nil)
            }
            return url
        }.value
    }

    // MARK: - Renaming

    /// Renames the deck package at `deck` to `name`, keeping its extension: a `.voctrain`
    /// deck stays one. Returns the new URL, `deck` if the name stays. Only the case of the
    /// name may change on its own.
    ///
    /// - Throws: `Failure.invalidName`, `Failure.nameTaken`.
    @discardableResult
    static func rename(_ deck: URL, to name: String) async throws -> URL {
        guard let name = fileName(for: name) else { throw Failure.invalidName }
        return try await Task.detached {
            let folder = deck.deletingLastPathComponent()
            let target = deckURL(named: name, extension: deck.pathExtension, in: folder)
            guard target.lastPathComponent != deck.lastPathComponent else { return deck }
            try coordinate(writing: deck, options: .forMoving, and: target, options: .forReplacing) { coordinator, old, new in
                guard !holdsDeck(named: name, in: folder, except: old) else { throw Failure.nameTaken(name) }
                try FileManager.default.moveItem(at: old, to: new)
                coordinator.item(at: old, didMoveTo: new)
            }
            return target
        }.value
    }

    // MARK: - Deleting

    /// Moves the deck package at `deck` to the Trash. Where the location has no Trash,
    /// which on the iPhone depends on where the folder is, it moves the deck to the
    /// folder "Deleted Decks" next to it instead and says so with `Trashed.setAside`:
    /// the learner can still take it back. It never deletes a deck for good.
    ///
    /// - Parameter trashItem: Moves the deck to the Trash; throws `CocoaError.featureUnsupported`
    ///   where there is none. A test replaces it to try the fallback.
    @discardableResult
    static func trash(_ deck: URL, using trashItem: @escaping @Sendable (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }) async throws -> Trashed {
        try await Task.detached {
            try coordinate(writing: deck, options: .forDeleting) { coordinator, url -> Trashed in
                do {
                    try trashItem(url)
                    return .trash
                } catch let error as CocoaError where error.code == .featureUnsupported {
                    let folder = url.deletingLastPathComponent().appending(path: setAsideFolderName, directoryHint: .isDirectory)
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    let target = uniqueURL(for: url.lastPathComponent, in: folder)
                    try FileManager.default.moveItem(at: url, to: target)
                    coordinator.item(at: url, didMoveTo: target)
                    return .setAside(target)
                }
            }
        }.value
    }

    // MARK: - Helpers

    private static func deckURL(named name: String, extension fileExtension: String, in folder: URL) -> URL {
        folder.appending(path: name + "." + fileExtension, directoryHint: .isDirectory)
    }

    /// Whether `folder` holds a deck called `name`, of any extension and also as the
    /// hidden placeholder of one iCloud Drive hasn't downloaded, other than `deck`. Names
    /// compare without regard to case or composition, whatever the file system does: the
    /// list shows names, and "greek" next to "Greek" would be one deck twice.
    private static func holdsDeck(named name: String, in folder: URL, except deck: URL?) -> Bool {
        func key(_ name: String) -> String {
            name.precomposedStringWithCanonicalMapping.folding(options: .caseInsensitive, locale: nil)
        }
        let wanted = Set(DeckFile.fileExtensions.flatMap { ["\(name).\($0)", ".\(name).\($0).icloud"] }.map(key))
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return entries.contains { $0 != deck?.lastPathComponent && wanted.contains(key($0)) }
    }

    /// `name` in `folder`, or with a number before its extension if the folder holds one.
    private static func uniqueURL(for name: String, in folder: URL) -> URL {
        let url = folder.appending(path: name, directoryHint: .isDirectory)
        guard FileManager.default.fileExists(atPath: url.path) else { return url }
        let base = (name as NSString).deletingPathExtension
        let fileExtension = (name as NSString).pathExtension
        for number in 2... {
            let candidate = folder.appending(path: "\(base) \(number).\(fileExtension)", directoryHint: .isDirectory)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        fatalError("unreachable")
    }

    /// Runs `body` as the writer of `url`, once nobody else uses the file, and returns
    /// what it returns or throws what it throws.
    private static func coordinate<Value>(writing url: URL, options: NSFileCoordinator.WritingOptions, _ body: (NSFileCoordinator, URL) throws -> Value) throws -> Value {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var outcome: Result<Value, any Error>?
        coordinator.coordinate(writingItemAt: url, options: options, error: &coordinationError) { url in
            outcome = Result { try body(coordinator, url) }
        }
        return try finish(outcome, coordinationError)
    }

    private static func coordinate(writing url: URL, options: NSFileCoordinator.WritingOptions, _ body: (URL) throws -> Void) throws {
        try coordinate(writing: url, options: options) { _, url in try body(url) }
    }

    /// The same for a change that touches two files, a move.
    private static func coordinate(
        writing first: URL, options firstOptions: NSFileCoordinator.WritingOptions,
        and second: URL, options secondOptions: NSFileCoordinator.WritingOptions,
        _ body: (NSFileCoordinator, URL, URL) throws -> Void
    ) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var outcome: Result<Void, any Error>?
        coordinator.coordinate(writingItemAt: first, options: firstOptions, writingItemAt: second, options: secondOptions, error: &coordinationError) { first, second in
            outcome = Result { try body(coordinator, first, second) }
        }
        try finish(outcome, coordinationError)
    }

    @discardableResult
    private static func finish<Value>(_ outcome: Result<Value, any Error>?, _ coordinationError: NSError?) throws -> Value {
        if let coordinationError { throw coordinationError }
        // The coordinator runs the accessor exactly once, or reports an error.
        return try outcome!.get()
    }
}

extension Deck {
    /// An empty deck with its mark: New words, `LearningOptions.introducesNewCards`, or Words I know. What a
    /// learner makes in New Deck on either platform starts with the mark they chose.
    static func new(introducesNewCards: Bool) -> Deck {
        var deck = Deck()
        var options = deck.learningOptions
        options.introducesNewCards = introducesNewCards
        let calendar = StudyCalendar()
        if let change = DeckChange.changingLearningOptions(options, in: deck, calendar: calendar) {
            _ = deck.apply(change, at: Date(), calendar: calendar)
        }
        return deck
    }
}
