import Foundation

/// What a Mnemit deck can take from an Anki package (`.apkg`): the front and back of every
/// card of a plain note type, with the reviews of the card.
///
/// Anki writes three layouts, all read here (see `references/deck-formats-and-sources.md`):
///
/// | Layout   | Collection entry       | Compression |
/// |----------|------------------------|-------------|
/// | Legacy 1 | `collection.anki2`     | none        |
/// | Legacy 2 | `collection.anki21`    | none        |
/// | Latest   | `collection.anki21b`   | zstd, with a protobuf `meta` entry |
///
/// Only notes, cards, the review log, the names and presets of the decks and the fields and
/// templates of the note types are read; scheduling state, media, tags, styles and the
/// other collection settings are left. Of a preset the FSRS parameters and the desired
/// retention are read (`AnkiPreset`), which a new deck takes (`learningOptions(applyingTo:)`). Cards come out in the order the notes were created.
///
/// - Front and back are the first and second field of the note type, unless the card's
///   question template shows another field first: the second card of "Basic (and reversed
///   card)" asks from the second field, so its front is that one.
/// - HTML is reduced to plain text (`AnkiText`). A field with an image or a sound loses it,
///   and counts in `skippedMediaRefs`.
/// - Cards of cloze note types are left out, counted in `skippedCloze`. A card whose front
///   or back is empty is left out as well (`skippedEmpty`), often because it held only an
///   image.
/// - A review of the log is a rating of 1 to 4 (Again, Hard, Good, Easy) at the time the
///   entry's `id` gives. Manual entries, and cramming that Anki did not count, are skipped.
///
/// `cards(learningOptions:calendar:created:)` turns the notes into cards.
public struct AnkiImport: Sendable {
    /// One card of Anki.
    public struct Note: Sendable, Equatable {
        public var front: String
        public var back: String
        /// Oldest first, in whole seconds, rated `.revealed`: Anki asks no typed answer.
        public var reviews: [ReviewLogEntry]
        /// Whether the card is suspended in Anki (buried cards are not).
        public var isSuspended: Bool
        /// The preset of the card's deck, as an index into `AnkiImport.presets`; `nil` if the
        /// package doesn't say.
        public var preset: Int?

        public init(front: String, back: String, reviews: [ReviewLogEntry] = [], isSuspended: Bool = false, preset: Int? = nil) {
            self.front = front
            self.back = back
            self.reviews = reviews
            self.isSuspended = isSuspended
            self.preset = preset
        }
    }

    public enum Error: Swift.Error, Equatable {
        /// Not a ZIP file, or one of its entries is damaged or of a kind not read here.
        case unreadableArchive
        /// The package is from an Anki version this one doesn't know.
        case unsupportedVersion
        /// The package has no collection.
        case missingCollection
        /// The collection isn't a database of the shape Anki writes.
        case unreadableCollection
    }

    /// One per Anki card of a note type that isn't cloze, in the order of creation.
    public var notes: [Note]
    /// Cards of cloze note types, left out.
    public var skippedCloze: Int
    /// Fields (front or back of a note) that referenced an image or a sound, now stripped of it.
    public var skippedMediaRefs: Int
    /// Cards left out because their front or back is empty, once stripped.
    public var skippedEmpty: Int
    /// The decks the notes belong to, as "Parent::Child", sorted.
    public var deckNames: [String]
    /// The deck presets the notes use, by their number in Anki (see `Note.preset`).
    public var presets: [AnkiPreset]

    public init(
        notes: [Note] = [], skippedCloze: Int = 0, skippedMediaRefs: Int = 0, skippedEmpty: Int = 0, deckNames: [String] = [], presets: [AnkiPreset] = []
    ) {
        self.notes = notes
        self.skippedCloze = skippedCloze
        self.skippedMediaRefs = skippedMediaRefs
        self.skippedEmpty = skippedEmpty
        self.deckNames = deckNames
        self.presets = presets
    }

    /// Reads the package at `url`.
    ///
    /// - Throws: `Error`. Whatever the file holds that isn't listed above is ignored.
    public static func read(_ url: URL) throws -> AnkiImport {
        let file: Data
        do {
            // Mapped, so the media of a large package doesn't have to fit in memory.
            file = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw Error.unreadableArchive
        }
        return try read(file)
    }

    static func read(_ file: Data) throws -> AnkiImport {
        let archive = try ZipArchive(file)
        let layout = try Layout(archive)
        guard var collection = try archive.contents(of: layout.collectionEntry) else { throw Error.missingCollection }
        if layout.isCompressed {
            collection = try Zstd.decompress(collection)
        }
        return try AnkiCollection(database: AnkiDatabase(bytes: collection)).imported()
    }

    /// Which entry holds the collection. The `meta` entry says it; without one, Legacy 2
    /// is the package with a `collection.anki21`. Packages of Legacy 2 and Latest also
    /// hold a `collection.anki2` that is only a placeholder, so it is never read then.
    struct Layout {
        var collectionEntry: String
        var isCompressed: Bool

        init(_ archive: ZipArchive) throws {
            let version: UInt64
            if let meta = try archive.contents(of: "meta") {
                // Version 0 is left out by proto3, and is unknown.
                version = ProtobufFields(meta).varint(1) ?? 0
                guard (1...3).contains(version) else { throw AnkiImport.Error.unsupportedVersion }
            } else {
                version = archive.entries["collection.anki21"] != nil ? 2 : 1
            }
            switch version {
            case 1: (collectionEntry, isCompressed) = ("collection.anki2", false)
            case 2: (collectionEntry, isCompressed) = ("collection.anki21", false)
            default: (collectionEntry, isCompressed) = ("collection.anki21b", true)
            }
        }
    }
}
