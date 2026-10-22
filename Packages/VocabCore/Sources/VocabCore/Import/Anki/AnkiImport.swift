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
/// templates of the note types are read, and the media files the cards use; scheduling state,
/// tags, styles and the other collection settings are left. Of a preset the FSRS parameters and the desired
/// retention are read (`AnkiPreset`), which a new deck takes (`learningOptions(applyingTo:)`). Cards come out in the order the notes were created.
///
/// - Front and back come from the card templates: the front is the first field with text
///   that the question template shows, the back the first with text that the answer template
///   adds, then each other field the answer adds that has text, on a line of its own, in the
///   order of the template: the meaning, then an example sentence. A field named for a frequency,
///   a rank or an ID, and one without a letter in its text, stays out. The second card of "Basic (and reversed card)" asks from the second field, so its
///   front is that one; a note type "Front, Image, Audio, Back" with the image on the question
///   gives the front and the back, as an image has no text. Where a template can't be read or
///   shows no field, the first and the second field with text stand in.
/// - The cards of one note stay siblings (`Card.note`). A note type with several templates gives
///   each of its cards the `guid` of the note as the word key; with two templates where the
///   second asks from the field the first answers with ("Basic (and reversed card)") the first is
///   `.recognition` and the second `.production`, so a study session holds it back until the
///   first is learned; with any other set of templates all are `.recognition`, buried for the
///   day but never locked. A note type with one template gives no key and no kind.
/// - HTML is reduced to plain text (`AnkiText`).
/// - The first image (`<img src>`) and the first sound (`[sound:…]`) of the fields a side shows
///   come with the card as that side's media (`Note.media`); the files are unpacked into a temporary
///   folder, named by their content as the media of a deck are (`media`, `DeckMedia`), and only those
///   a card uses. An image or a sound that is left out, because the package lacks the file or the
///   side has another already, counts in `skippedMediaRefs`.
/// - Cards of cloze note types are left out, counted in `skippedCloze`. A card needs a text, an
///   image or a sound on each side; one with a side that has none is left out (`skippedEmpty`), and
///   `skippedMediaOnly` counts those where the side referred to media the package lacks.
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
        /// The word key of the card (`Card.note`): the `guid` of its Anki note, which stays the
        /// same when the package is read again, for a card whose note type has several templates;
        /// `nil` for the cards of a note type with one.
        public var note: String?
        /// Which way the card asks (`Card.kind`), with a `note` only. The second card of a reverse
        /// pair is `.production`, every other card of a note with several `.recognition`.
        public var kind: CardKind?
        /// The image and the sound of each side, by their names in `AnkiImport.media`. A side with
        /// no text has at least one of them.
        public var media: CardMedia

        public init(
            front: String, back: String, reviews: [ReviewLogEntry] = [], isSuspended: Bool = false, preset: Int? = nil, note: String? = nil,
            kind: CardKind? = nil, media: CardMedia = CardMedia()
        ) {
            self.front = front
            self.back = back
            self.reviews = reviews
            self.isSuspended = isSuspended
            self.preset = preset
            self.note = note
            self.kind = kind
            self.media = media
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
    /// Of `skippedEmpty`, the cards where a side that is empty held an image or a sound.
    public var skippedMediaOnly: Int
    /// The decks the notes belong to, as "Parent::Child", sorted.
    public var deckNames: [String]
    /// The deck presets the notes use, by their number in Anki (see `Note.preset`).
    public var presets: [AnkiPreset]
    /// The images and sounds the notes use, unpacked and named by their content, which
    /// `DeckChange.importing(_:into:learningOptions:media:)` takes into a deck. The files sit in a
    /// temporary folder that goes when nothing holds the media any more.
    public var media: DeckMedia
    /// The size in bytes of each file of `media`, by its name.
    var mediaSizes: [String: Int]

    public init(
        notes: [Note] = [], skippedCloze: Int = 0, skippedMediaRefs: Int = 0, skippedEmpty: Int = 0, skippedMediaOnly: Int = 0, deckNames: [String] = [],
        presets: [AnkiPreset] = [], media: DeckMedia = DeckMedia()
    ) {
        self.notes = notes
        self.skippedCloze = skippedCloze
        self.skippedMediaRefs = skippedMediaRefs
        self.skippedEmpty = skippedEmpty
        self.skippedMediaOnly = skippedMediaOnly
        self.deckNames = deckNames
        self.presets = presets
        self.media = media
        mediaSizes = [:]
    }

    /// How many images and sounds the notes use and how much room the files take.
    public struct MediaSummary: Equatable, Sendable {
        public var images: Int
        public var sounds: Int
        public var bytes: Int

        public init(images: Int = 0, sounds: Int = 0, bytes: Int = 0) {
            self.images = images
            self.sounds = sounds
            self.bytes = bytes
        }

        public var isEmpty: Bool { images == 0 && sounds == 0 }
    }

    /// The files the notes use, each counted once.
    public var mediaSummary: MediaSummary {
        var images = Set<String>()
        var sounds = Set<String>()
        for note in notes {
            images.formUnion([note.media.questionImage, note.media.answerImage].compactMap { $0 })
            sounds.formUnion([note.media.questionAudio, note.media.answerAudio].compactMap { $0 })
        }
        return MediaSummary(images: images.count, sounds: sounds.count, bytes: images.union(sounds).reduce(0) { $0 + (mediaSizes[$1] ?? 0) })
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
        let media = AnkiMedia(archive: archive, isCompressed: layout.isCompressed)
        var result = try AnkiCollection(database: AnkiDatabase(bytes: collection), media: media).imported()
        result.unpackMedia(of: media, from: archive, isCompressed: layout.isCompressed)
        return result
    }

    /// Unpacks the files the notes name, which `imported()` leaves under their names in Anki, and
    /// names them by their content. A note whose side has lost its only image or sound because its
    /// file can't be read is left out.
    private mutating func unpackMedia(of index: AnkiMedia, from archive: ZipArchive, isCompressed: Bool) {
        var wanted = Set<String>()
        for note in notes { wanted.formUnion(note.media.names) }
        let unpacked = index.unpack(wanted, from: archive, isCompressed: isCompressed)
        media = unpacked.media
        mediaSizes = unpacked.sizes
        guard !wanted.isEmpty else { return }
        func renamed(_ name: String?) -> String? { name.flatMap { unpacked.names[$0] } }
        notes = notes.compactMap { note in
            var note = note
            note.media = CardMedia(
                questionImage: renamed(note.media.questionImage), questionAudio: renamed(note.media.questionAudio),
                answerImage: renamed(note.media.answerImage), answerAudio: renamed(note.media.answerAudio))
            guard (!note.front.isEmpty || note.media.hasQuestionMedia) && (!note.back.isEmpty || note.media.hasAnswerMedia) else {
                skippedEmpty += 1
                skippedMediaOnly += 1
                return nil
            }
            return note
        }
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
