import CryptoKit
import Foundation

/// The media of a card, one file name per slot: an image and a sound for each side. A name is
/// that of a file in the `media` folder of the deck's package (`DeckMedia`). Content like the
/// texts of a card: `Card.contentChanged` stamps a change, and a merge takes it with them.
public struct CardMedia: Hashable, Sendable {
    public var questionImage: String?
    public var questionAudio: String?
    public var answerImage: String?
    public var answerAudio: String?

    public init(questionImage: String? = nil, questionAudio: String? = nil, answerImage: String? = nil, answerAudio: String? = nil) {
        self.questionImage = questionImage
        self.questionAudio = questionAudio
        self.answerImage = answerImage
        self.answerAudio = answerAudio
    }

    /// The names of the files the card has, without a repeat.
    public var names: Set<String> {
        Set([questionImage, questionAudio, answerImage, answerAudio].compactMap { $0 })
    }

    public var isEmpty: Bool { names.isEmpty }
    /// Whether the question has an image or a sound.
    public var hasQuestionMedia: Bool { questionImage != nil || questionAudio != nil }
    /// Whether the answer has an image or a sound.
    public var hasAnswerMedia: Bool { answerImage != nil || answerAudio != nil }

    /// The same slots, with every name that doesn't name a file (`DeckMedia.isValidName`) left out.
    var checked: CardMedia {
        func valid(_ name: String?) -> String? { name.flatMap { DeckMedia.isValidName($0) ? $0 : nil } }
        return CardMedia(
            questionImage: valid(questionImage), questionAudio: valid(questionAudio), answerImage: valid(answerImage), answerAudio: valid(answerAudio))
    }
}

/// The media files of a deck: the images and sounds its cards name (`CardMedia`).
///
/// In the package they sit in the folder `media`, each named by its content: the first 16 hex
/// characters of the file's SHA-256, a dot and the original extension in lower case
/// (`3f2a9c0b7d1e4a58.jpg`). A file never changes under its name, so identical media are stored
/// once, two versions of a deck can be joined by the names alone, and iCloud Drive syncs each
/// file apart from `deck.json`.
///
/// The deck holds the files as `FileWrapper`s and reads none of them until something asks: an
/// open deck costs the folder listing, not the bytes. Which files a package keeps:
/// - Reading a package keeps the files some card names (`init(folder:keeping:)`). A file no card
///   names is an orphan; leaving it out of what is read is what removes it at the next save.
/// - The files of a deck only grow while the deck is open: deleting a card, editing its media or
///   undoing an import takes no file out, so undoing the deletion finds it still there. Only
///   undoing the change that brought a file in takes it out again, and only if no card names it
///   (`Deck.apply(_:at:calendar:)`).
/// - Writing a package (`DeckFile.fileWrapper(for:reviewLog:original:)`) writes every file the
///   deck holds. One that is in the package already, which `original` names, is cloned from there,
///   not written again.
///
/// A name that a card holds but this deck has no file for, because the file hasn't arrived from
/// iCloud Drive yet, stays with the card; the next version that has the file brings it in
/// (`DeckChange.merging(_:into:calendar:)`).
public struct DeckMedia: Hashable, Sendable {
    /// The folder of a package that holds the files.
    public static let folderName = "media"

    /// One file. Equal by name, as the name says what the file holds.
    public struct File: Hashable, @unchecked Sendable {
        public let name: String
        /// A regular file, or a `MediaFileWrapper`. A `FileWrapper` isn't `Sendable`; this one is
        /// only read, and written to disk by a save.
        let wrapper: FileWrapper

        public static func == (lhs: File, rhs: File) -> Bool { lhs.name == rhs.name }
        public func hash(into hasher: inout Hasher) { hasher.combine(name) }
    }

    private(set) var files: [String: File] = [:]

    public init() {}

    public var isEmpty: Bool { files.isEmpty }
    public var count: Int { files.count }
    public var names: Set<String> { Set(files.keys) }

    public func contains(_ name: String) -> Bool { files[name] != nil }

    /// The bytes of the file `name`, `nil` if the deck has none or it can't be read now.
    public func contents(of name: String) -> Data? {
        files[name]?.wrapper.regularFileContents
    }

    // MARK: Names

    /// The name of a file with `data` and the extension `fileExtension`, which may come with a
    /// dot and in any case: the first 16 hex characters of SHA-256, then the extension in lower
    /// case. An extension that isn't 1 to 8 letters and digits is left out.
    public static func name(for data: Data, fileExtension: String) -> String {
        name(forDigest: SHA256.hash(data: data), fileExtension: fileExtension)
    }

    static func name(forDigest digest: SHA256.Digest, fileExtension: String) -> String {
        let hash = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        let ext = normalizedExtension(fileExtension)
        return ext.isEmpty ? hash : hash + "." + ext
    }

    /// `fileExtension` in lower case, without a leading dot; empty if it isn't 1 to 8 ASCII letters
    /// and digits.
    static func normalizedExtension(_ fileExtension: String) -> String {
        let ext = fileExtension.drop { $0 == "." }.lowercased()
        return (1...8).contains(ext.count) && ext.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) ? ext : ""
    }

    /// Whether `name` is of the form `name(for:fileExtension:)` makes. A card names its files by
    /// such names only, so a name from a damaged or foreign `deck.json` never reaches the file
    /// system as a path.
    public static func isValidName(_ name: String) -> Bool {
        let parts = name.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard let hash = parts.first, hash.count == 16, hash.allSatisfy({ $0.isASCII && $0.isHexDigit && !$0.isUppercase }) else { return false }
        return parts.count == 1 || (1...8).contains(parts[1].count) && parts[1].allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber) }
    }

    // MARK: Building

    /// Adds `data` as a file and returns its name. The file is held in memory; for a large one see
    /// `MediaFileWrapper`.
    @discardableResult
    public mutating func add(_ data: Data, fileExtension: String) -> String {
        let name = Self.name(for: data, fileExtension: fileExtension)
        if files[name] == nil {
            files[name] = File(name: name, wrapper: FileWrapper(regularFileWithContents: data))
        }
        return name
    }

    /// Adds the file at `url`, which has to stay where it is, or at least be kept alive by `owner`
    /// (the wrapper keeps it): the file is read when a save needs it, and cloned. `name` is that
    /// of `file`'s content, which the caller has worked out.
    mutating func add(fileAt url: URL, named name: String, owner: AnyObject?) {
        if files[name] == nil {
            files[name] = File(name: name, wrapper: MediaFileWrapper(source: url, owner: owner))
        }
    }

    /// The files of `other` this one lacks, as a collection of their own.
    func missing(from other: DeckMedia) -> DeckMedia {
        var result = DeckMedia()
        result.files = files.filter { other.files[$0.key] == nil }
        return result
    }

    /// Adds the files of `other`; a name already here keeps its file.
    mutating func formUnion(_ other: DeckMedia) {
        files.merge(other.files) { mine, _ in mine }
    }

    /// Takes the files `names` out and returns them.
    mutating func remove(_ names: Set<String>) -> DeckMedia {
        var removed = DeckMedia()
        for name in names {
            removed.files[name] = files.removeValue(forKey: name)
        }
        return removed
    }

    /// The files of `self` that `names` name.
    func keeping(_ names: Set<String>) -> DeckMedia {
        var result = DeckMedia()
        result.files = files.filter { names.contains($0.key) }
        return result
    }

    // MARK: Package

    /// The files of the `media` folder of a package that `names` name; the folder may be missing.
    /// Wrappers of the folder are kept as they are.
    init(folder: FileWrapper?, keeping names: Set<String>) {
        for (name, wrapper) in folder?.fileWrappers ?? [:] where wrapper.isRegularFile && names.contains(name) {
            files[name] = File(name: name, wrapper: wrapper)
        }
    }

    /// The same for a package at `url`, whose files are read, and cloned, from there.
    init(folderAt url: URL, keeping names: Set<String>) {
        let listing = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        for name in listing where names.contains(name) {
            files[name] = File(name: name, wrapper: MediaFileWrapper(source: url.appending(path: name), owner: nil))
        }
    }

    /// The `media` folder to write, `nil` while the deck has no file.
    ///
    /// - Parameter original: The package this deck was read from, saved before. A file that is in
    ///   its `media` folder is cloned from there (`MediaFileWrapper`), so a save writes none of the
    ///   media that stays: on APFS a clone shares the bytes of the original.
    func folderWrapper(original: URL?) -> FileWrapper? {
        guard !files.isEmpty else { return nil }
        let originalFolder = original?.appending(path: Self.folderName, directoryHint: .isDirectory)
        var children: [String: FileWrapper] = [:]
        for (name, file) in files {
            if let source = originalFolder?.appending(path: name), FileManager.default.fileExists(atPath: source.path) {
                children[name] = MediaFileWrapper(source: source, owner: nil)
            } else {
                children[name] = file.wrapper
            }
        }
        let folder = FileWrapper(directoryWithFileWrappers: children)
        folder.preferredFilename = Self.folderName
        return folder
    }
}

/// A media file on disk. Writing it clones the file (`FileManager.copyItem(at:to:)` does, on APFS)
/// instead of reading its bytes and writing them again: a package write of a deck with
/// hundreds of megabytes of media costs milliseconds, where `FileWrapper` writes every byte of the
/// files it holds again (measured on macOS 27: 400 MB in 2 ms against 0.3 s, and the `originalContentsURL`
/// of `FileWrapper.write(to:options:originalContentsURL:)` links nothing).
///
/// A `FileWrapper` that is the child of a directory wrapper is written through this override, as
/// `NSDocument` and `UIDocument` do it. The contents are read only when someone asks for them
/// (a deck shows the file), mapped, not copied.
final class MediaFileWrapper: FileWrapper, @unchecked Sendable {
    let source: URL
    /// Keeps what the file lives in alive, a temporary folder of an import.
    private let owner: AnyObject?

    init(source: URL, owner: AnyObject?) {
        self.source = source
        self.owner = owner
        super.init(regularFileWithContents: Data())
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override var regularFileContents: Data? {
        try? Data(contentsOf: source, options: .mappedIfSafe)
    }

    /// Throws if the source is gone, and never writes the empty contents the superclass holds.
    override func write(to url: URL, options: FileWrapper.WritingOptions = [], originalContentsURL: URL?) throws {
        try FileManager.default.copyItem(at: source, to: url)
    }
}
