import AppKit
import UniformTypeIdentifiers
import VocabCore
import os

/// The file of an open deck on the Mac: reads it, saves it in place and reads it again when
/// another process changed it, coordinated with iCloud Drive, as the iPhone's `DeckFileDocument`
/// does (#285). An NSDocument without windows: the app creates and registers it itself, so a deck
/// stays open while no window shows it, and `OpenDeck` uses the two classes alike.
///
/// NSDocument keeps what it does for any document: it counts the changes that register with its
/// undo manager and autosaves them, it sets unsaved changes aside as an `NSFileVersion` when
/// another process writes the file, and it reads the file again. The deck it reads is not the
/// document the views show: `OpenDeck` takes it (`takeLoadedDeck()`) and the `VersionMerger`
/// merges it into the document that is open.
final class DeckFileDocument: NSDocument {
    /// Posted after the file was read, at opening and after another process changed it.
    /// `takeLoadedDeck()` then returns what it read.
    static let didLoad = Notification.Name("DeckFileDocument.didLoad")
    /// Posted when the document closed.
    static let stateDidChange = Notification.Name("DeckFileDocument.stateDidChange")

    private nonisolated let savedDocument = OSAllocatedUnfairLock<VocabularyDocument?>(initialState: nil)
    private var loadedDeck: Deck?
    private(set) var failure: String?
    private(set) var isClosed = false

    /// Opens nothing yet: `open(completion:)` reads the file.
    init(fileURL: URL) {
        super.init()
        self.fileURL = fileURL
        fileType = Self.type(of: fileURL).identifier
        NSDocumentController.shared.addDocument(self)
    }

    override class var autosavesInPlace: Bool {
        true
    }

    /// The document whose deck `write(to:ofType:for:originalContentsURL:)` saves.
    nonisolated var document: VocabularyDocument? {
        get { savedDocument.withLock { $0 } }
        set { savedDocument.withLock { $0 = newValue } }
    }

    /// The document is never read again while a view could see it half: NSDocument reads on the
    /// main actor, in one step.
    var isEditingDisabled: Bool { false }

    /// The deck read last, once.
    func takeLoadedDeck() -> Deck? {
        defer { loadedDeck = nil }
        return loadedDeck
    }

    /// Reads the file, off the main actor and coordinated, then posts `didLoad`. A file that
    /// can't be read closes the document.
    func open(completion: @escaping @Sendable (Bool) -> Void) {
        guard let url = fileURL else { return completion(false) }
        Task { @MainActor in
            do {
                let deck = try await Self.read(at: url)
                fileModificationDate = Self.modificationDate(of: url)
                load(deck)
                completion(true)
            } catch {
                failure = error.localizedDescription
                close()
                completion(false)
            }
        }
    }

    /// Saves what is unsaved and closes the document. A save that fails leaves it open, with what it holds, and
    /// completes with `false`.
    func close(completion: @escaping @Sendable (Bool) -> Void) {
        Task { @MainActor in
            if isDocumentEdited {
                do {
                    try await saveInPlace()
                } catch {
                    failure = error.localizedDescription
                    return completion(false)
                }
            }
            close()
            completion(true)
        }
    }

    /// Saves what the document counted as unsaved, without waiting.
    func autosaveIfNeeded() {
        if isDocumentEdited {
            Task { try? await saveInPlace() }
        }
    }

    /// Saves in place, even if NSDocument hasn't counted the change yet: the `VersionMerger`
    /// of `OpenDeck` saves this way a few seconds after each change (#295), as autosave does.
    func saveInPlace() async throws {
        guard !isClosed, let fileURL, let fileType else { throw CocoaError(.fileWriteUnknown) }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            save(to: fileURL, ofType: fileType, for: .autosaveInPlaceOperation) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Reading

    /// NSDocument calls this when it reads the file again. The media stay in the package and are read
    /// when they are needed, from the file at `url` (`DeckFile.read(at:)`).
    override func read(from url: URL, ofType typeName: String) throws {
        load(try Self.decode(at: url))
    }

    /// NSDocument empties its undo manager as it reads the file again; it reads into one that is empty
    /// anyway, so the steps of the session's reviews stay undoable. `OpenDeck` drops the steps that
    /// must go once it merged what the file holds, see `VocabularyDocument.forgetEditUndoSteps()`.
    override func revert(toContentsOf url: URL, ofType typeName: String) throws {
        let undoManager = self.undoManager
        self.undoManager = UndoManager()
        defer { self.undoManager = undoManager }
        try super.revert(toContentsOf: url, ofType: typeName)
    }

    private func load(_ deck: Deck) {
        loadedDeck = deck
        NotificationCenter.default.post(name: Self.didLoad, object: self)
    }

    private nonisolated static func decode(at url: URL) throws -> Deck {
        do {
            return try DeckFile.read(at: url)
        } catch {
            throw VocabularyDocument.openingError(for: error)
        }
    }

    /// Reads the package at `url` coordinated, on a queue of its own: coordinating blocks the thread until
    /// the file's other readers and writers and their presenters have answered, and a thread of Swift's
    /// pool that blocks leaves too few for the work that would let them answer.
    private nonisolated static func read(at url: URL) async throws -> Deck {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Deck, any Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                var coordinationError: NSError?
                var result: Result<Deck, any Error>?
                NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { url in
                    result = Result { try decode(at: url) }
                }
                if let coordinationError {
                    continuation.resume(throwing: coordinationError)
                } else {
                    continuation.resume(with: result ?? .failure(CocoaError(.fileReadUnknown)))
                }
            }
        }
    }

    private static func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private static func type(of url: URL) -> UTType {
        let fileExtension = url.pathExtension.lowercased()
        return UTType.deckTypes.first { $0.tags[.filenameExtension]?.contains(fileExtension) == true } ?? .vocabularyDeck
    }

    // MARK: - Writing

    override func canAsynchronouslyWrite(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) -> Bool {
        true
    }

    /// Writes the deck of `document` as a package. The media of the package that are in it
    /// already are cloned from `originalContentsURL`, not written again. NSDocument writes on a
    /// queue of its own and keeps the main actor blocked until `unblockUserInteraction()`: the
    /// deck is snapshotted before, and the encoding, which takes tens of milliseconds, goes after.
    override nonisolated func write(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, originalContentsURL: URL?) throws {
        guard let document else { throw CocoaError(.fileWriteUnknown) }
        let deck = StallTrace.measure("saveSnapshot") { document.deckToSave }
        unblockUserInteraction()
        let wrapper = try StallTrace.measure("saveEncode") { try document.fileWrapper(for: deck, original: originalContentsURL) }
        try wrapper.write(to: url, options: [], originalContentsURL: originalContentsURL)
    }

    // MARK: - Closing and errors

    override func close() {
        isClosed = true
        super.close()
        NotificationCenter.default.post(name: Self.stateDidChange, object: self)
    }

    /// The app's one window, where an error of a deck is a sheet: a deck has no window of its own, and
    /// without one NSDocument shows the error app-modal. Set by the window (`UndoRouter`).
    static weak var sheetWindow: NSWindow?

    override var windowForSheet: NSWindow? {
        Self.sheetWindow ?? super.windowForSheet
    }

    /// Records why reading or saving failed, for the learner.
    override func willPresentError(_ error: any Error) -> any Error {
        failure = error.localizedDescription
        return super.willPresentError(error)
    }
}
