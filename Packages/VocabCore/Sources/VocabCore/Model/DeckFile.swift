import Foundation

/// Reading and writing decks.
///
/// A deck is a package (a directory shown as one file):
///
/// ```
/// Stapel.mnemit/
///   deck.json       learning options, cards with their learning state, progress
///   reviews.jsonl   one line per review: {"card":"…","date":1791216000,"grade":3}
///   media/          images and sounds of the cards, one file each (left out without any)
/// ```
///
/// The files of `media/` are named by their content, `3f2a9c0b7d1e4a58.jpg`, see `DeckMedia`;
/// a card names its files in the keys `questionImage`, `questionAudio`, `answerImage` and
/// `answerAudio` of `deck.json`, which are left out for a side without one. Version 5 added
/// them: an older app version would drop the folder, and the media with it, the next time it
/// saves the deck, so it rejects the deck instead. So did version 6 for `retired` in `deck.json`,
/// the cards deleted that had reviews (`Deck.retiredCards`), and their lines in `reviews.jsonl`: an
/// older app version would drop the key and reject the lines of a card it doesn't know. Version 7 added the lines
/// of `reviews.jsonl` with `"undone":true`, the reviews the learner took back (`Card.undone`): an older app version
/// would read them as reviews and bring the taken-back ones back, so it rejects the deck. The app writes every
/// deck as version 7, so an older app version no longer opens, and drops keys from, a deck of this one.
///
/// `deck.json` is pretty-printed JSON with sorted keys, so it stays readable and
/// diffs well. Its keys are spelled out by the records at the end of this file and
/// nowhere else; the domain types know nothing about the format. The review log lives apart because it grows with every review: kept
/// in `deck.json` it made every autosave re-encode the whole log (#4).
///
/// Versions 1 (a single JSON file with the log inside each card) and 2 (the package
/// with the keys before the glossary of #23) date from before the first release and
/// are no longer read. Version 4 added `contentModified` and the review mode, which
/// a merge needs (#249); version 3 reads with neither. `learningStateReset` of a card
/// (#273) came later without a new version: an older app version drops it on save,
/// and a merge may then bring back the reviews from before a reset, as it did before.
/// So did `suspended` and `suspensionChanged` of a card (#290): an older app version
/// asks a suspended card and drops both on save. A merge with a newer version that
/// still holds them keeps the card suspended. `note` and `kind` of a card
/// came without a new version too: an older app version drops them on save, and its sessions
/// then ask production cards like any other. The options `revealedRecallWeight` (ADR 0005),
/// `optimizeFromRevealed`, `caseSensitive`, `newCardOrder`, `cardsPerSession`, `newProductionPerSession` and
/// `productionUnlockDays` are gone: a deck that has the keys still
/// reads, and the next save leaves them out; an older app version reads their defaults.
/// `leechThreshold` came the same way: an older app
/// version drops it, and its sessions suspend no leeches. `leechAction` too: an older app version drops it,
/// and the deck reads as keep again. So did `contentChanged` of a
/// card, `learningOptionsChanged` and `deletedCards` of the deck, which merges between
/// devices that both edit cards need: an older app version drops them on save, and a
/// merge then settles the texts and options by `contentModified` as before, and may
/// bring back a card deleted on the other device. `updatesParametersAutomatically` and
/// `lastAutoFit` of the options (`ParameterRefit`) came without one too, and are left out
/// of the file while they hold their defaults: an older app version drops them, fits
/// nothing by itself and forgets when the newer one last did. `paused` of the options, left
/// out while the deck is not paused, came the same way: an older app version drops it, and
/// the deck is no longer paused. `maximumReviewsPerDay` (Maximum reviews/day) came the same way, written as
/// null while unlimited: an older app version drops it, and the deck asks every review that is due again.
///
/// When `currentVersion` goes up: a missing key takes its default, so a newer app
/// version reads an older deck of the same version. The other way round, an older
/// app version reads a newer deck of the same version without complaint, skips the
/// keys it doesn't know and drops them on the next save, as it rebuilds the package
/// from just `deck.json` and `reviews.jsonl`. So a new key in `deck.json`, a new
/// field in the lines of `reviews.jsonl` or a new file in the package comes without
/// a new version only if an older app version may silently lose it. Otherwise
/// `currentVersion` goes up, and older app versions reject the deck as
/// `unsupportedVersion`. Incompatible changes always raise it.
public enum DeckFile {
    /// The extension of a deck package.
    public static let fileExtension = "mnemit"
    /// The extension the decks of MacVocTrain NG have: such a deck is read like any other
    /// and saved in place under its name, never renamed.
    public static let legacyFileExtension = "voctrain"
    public static let fileExtensions = [fileExtension, legacyFileExtension]

    /// Whether `name`, the last component of a path, names a deck package.
    public static func isDeckName(_ name: String) -> Bool {
        fileExtensions.contains { name.hasSuffix("." + $0) }
    }

    /// The identifier in the `format` key of `deck.json`. It stays that of the decks of
    /// MacVocTrain NG, so both extensions hold the same contents.
    public static let format = "de.fluch-it-consulting.voctrain.deck"
    /// What decks said in `format` before the app moved to the company's identifiers;
    /// still read, never written.
    static let legacyFormats: Set = ["com.mfluch.voctrain.deck"]
    public static let currentVersion = 7
    /// The oldest version this app version reads: 3 and 4 read as decks without media.
    public static let oldestReadableVersion = 3
    public static let deckFileName = "deck.json"
    public static let reviewsFileName = "reviews.jsonl"

    public enum Error: Swift.Error, Equatable {
        case notADeck
        /// Written by a newer version of the app.
        case unsupportedVersion(Int)
        /// Written before the first release, in a format that is no longer read.
        case outdatedVersion(Int)
        /// A line of `reviews.jsonl` could not be read (1-based).
        case damagedReviewLog(line: Int)
        /// `reviews.jsonl` is missing, although a card has been reviewed.
        case missingReviewLog
        /// A line of `reviews.jsonl` belongs to no card of the deck (1-based).
        case reviewsOfUnknownCard(line: Int)
        /// The review log of a card is longer than its count of reviews.
        case reviewLogTooLong(question: String)
        /// The review log of a card stops before its last review, which the card's learning state holds: lines of
        /// `reviews.jsonl` are missing.
        case reviewLogTooShort(question: String)
        /// Several cards have the ID of the card with this question.
        case duplicateCardID(question: String)
        /// A weight of the FSRS parameters is outside its range (0-based, as in w0…w20).
        case parameterOutOfRange(index: Int)
    }

    // MARK: - Writing

    /// The package for `deck`.
    ///
    /// - Parameters:
    ///   - reviewLog: Pass the same encoder for every save of a document,
    ///     so only reviews added since the last save are encoded.
    ///   - original: The package the deck was read from and is saved over, if there is one. Media
    ///     files that are in it are cloned from there and not written again (`DeckMedia`).
    public static func fileWrapper(for deck: Deck, reviewLog: ReviewLogEncoder = ReviewLogEncoder(), original: URL? = nil) throws -> FileWrapper {
        let deckFile = FileWrapper(regularFileWithContents: try encodeDeck(deck))
        deckFile.preferredFilename = deckFileName
        let reviewsFile = FileWrapper(regularFileWithContents: reviewLog.encode(deck.trainingCards))
        reviewsFile.preferredFilename = reviewsFileName
        var children = [deckFileName: deckFile, reviewsFileName: reviewsFile]
        children[DeckMedia.folderName] = deck.media.folderWrapper(original: original)
        return FileWrapper(directoryWithFileWrappers: children)
    }

    /// `deck.json`: everything except the review log.
    static func encodeDeck(_ deck: Deck) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(Envelope(deck))
    }

    // MARK: - Reading

    /// Reads a package.
    ///
    /// Rejects a review log that doesn't fit the cards, as the app never writes one:
    /// it is missing although a card was reviewed, has lines of unknown cards, is
    /// longer than a card's count of reviews, or stops before the last review of a card
    /// (`Card.hasLostReviews`): a torn write or a partial sync, which saving would make permanent.
    /// A shorter one that ends with the card's last review is fine; cards imported
    /// from MacVocTrain 1 lack the reviews before the import. A card with reviews and no lines at all
    /// reads too, as an import not studied since looks the same.
    ///
    /// - Parameters:
    ///   - withMedia: Whether the deck holds the media files of the package, `true` unless the deck
    ///     is only counted: a deck read without them loses them if it is saved. The files that no
    ///     card names are never held (`DeckMedia`).
    ///   - url: Where the package is, if it is a package on disk: the media files are then read
    ///     from there when needed, and cloned when saved, instead of kept as the wrappers of `wrapper`.
    public static func decode(_ wrapper: FileWrapper, withMedia: Bool = true, at url: URL? = nil) throws -> Deck {
        guard wrapper.isDirectory else {
            // Only version 1 was a single file; its header reports it as outdated.
            _ = try decode(wrapper.regularFileContents ?? Data())
            throw Error.notADeck
        }
        guard let deckData = wrapper.fileWrappers?[deckFileName]?.regularFileContents else {
            throw Error.notADeck
        }
        var deck = try decode(deckData)
        // The retired cards keep their reviews in the same file, after those of the cards.
        var all = deck.trainingCards
        if let reviews = wrapper.fileWrappers?[reviewsFileName]?.regularFileContents {
            try ReviewLogEncoder.attach(reviews, to: &all)
        } else if all.contains(where: { ($0.learningState?.reviews ?? 0) > 0 }) {
            throw Error.missingReviewLog
        }
        if let card = all.first(where: { $0.log.count > ($0.learningState?.reviews ?? 0) }) {
            throw Error.reviewLogTooLong(question: card.question)
        }
        if let card = all.first(where: \.hasLostReviews) {
            throw Error.reviewLogTooShort(question: card.question)
        }
        deck.cards = Array(all[..<deck.cards.count])
        deck.retiredCards = Array(all[deck.cards.count...])
        if withMedia {
            let named = deck.namedMedia
            if let url {
                deck.media = DeckMedia(folderAt: url.appending(path: DeckMedia.folderName, directoryHint: .isDirectory), keeping: named)
            } else {
                deck.media = DeckMedia(folder: wrapper.fileWrappers?[DeckMedia.folderName], keeping: named)
            }
        }
        return deck
    }

    /// Reads the package at `url`, through a `FileWrapper` that holds nothing but the listing of
    /// the files: `deck.json` and `reviews.jsonl` are read now, the media when they are needed.
    /// Not for the main thread of an app, and not outside the coordination of the file; see
    /// `decode(_:withMedia:at:)` for `withMedia`.
    public static func read(at url: URL, withMedia: Bool = true) throws -> Deck {
        try decode(FileWrapper(url: url, options: []), withMedia: withMedia, at: url)
    }

    /// Reads the `deck.json` of a package, without the review log.
    ///
    /// Not for counting a day: the daily limit on new cards subtracts the cards introduced
    /// today, which only the log knows. Read the whole package, `decode(_:)` of a
    /// `FileWrapper`, for anything that must agree with the deck screen.
    ///
    /// Rejects duplicate card IDs and FSRS parameters outside their ranges; clamps
    /// learning options and learning states into theirs.
    public static func decode(_ data: Data) throws -> Deck {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let header = try? decoder.decode(Header.self, from: data)
        let isDeck = header?.format.map { $0 == format || legacyFormats.contains($0) } ?? false
        guard let header, isDeck, let version = header.version else {
            throw Error.notADeck
        }
        guard version <= currentVersion else {
            throw Error.unsupportedVersion(version)
        }
        guard version >= oldestReadableVersion else {
            throw Error.outdatedVersion(version)
        }

        return try decoder.decode(Envelope.self, from: data).deck()
    }

    private struct Header: Decodable {
        var format: String?
        var version: Int?
    }
}

// MARK: - Records

/// The records of `deck.json`, one property per key. They convert from and to the
/// domain types and check the values on the way in, with the ranges of those
/// (`FSRSParameters.ranges`, `LearningState.sanitize()`); the deck itself checks its
/// card IDs and clamps its learning options (`Deck.init(learningOptions:cards:progress:contentModified:)`).
extension DeckFile {
    private struct Envelope: Codable {
        var format: String
        var version: Int
        var learningOptions: OptionsRecord
        var cards: [CardRecord]
        var progress: [SnapshotRecord]
        /// Left out until the content first changes.
        var contentModified: Date?
        /// Left out until the learning options first change.
        var learningOptionsChanged: Date?
        /// Left out while no card was deleted; by ID, so the file stays the same when the
        /// deck is saved again.
        var deletedCards: [DeletionRecord]?
        /// The cards deleted that had reviews, without their logs, which `reviews.jsonl` holds
        /// after those of `cards` (`Deck.retiredCards`); left out while there are none.
        var retired: [CardRecord]?

        init(_ deck: Deck) {
            format = DeckFile.format
            version = currentVersion
            learningOptions = OptionsRecord(deck.learningOptions)
            cards = deck.cards.map(CardRecord.init)
            progress = deck.progress.map(SnapshotRecord.init)
            contentModified = deck.contentModified
            learningOptionsChanged = deck.learningOptionsChanged
            let deletions = deck.deletedCards.map { DeletionRecord(id: $0.key, date: $0.value) }
            deletedCards = deletions.isEmpty ? nil : deletions.sorted { $0.id.uuidString < $1.id.uuidString }
            retired = deck.retiredCards.isEmpty ? nil : deck.retiredCards.map(CardRecord.init)
        }

        func deck() throws -> Deck {
            do {
                return try Deck(
                    learningOptions: try learningOptions.learningOptions(),
                    cards: cards.map(\.card),
                    progress: try progress.map { try $0.snapshot() },
                    contentModified: contentModified,
                    learningOptionsChanged: learningOptionsChanged,
                    deletedCards: Dictionary((deletedCards ?? []).map { ($0.id, $0.date) }) { first, _ in first },
                    retiredCards: (retired ?? []).map(\.card)
                )
            } catch Deck.Error.duplicateCardID(let card) {
                throw DeckFile.Error.duplicateCardID(question: card.question)
            }
        }
    }

    /// A card the learner deleted, see `Deck.deletedCards`.
    private struct DeletionRecord: Codable {
        var id: UUID
        var date: Date
    }

    /// Missing keys take the default. Whether a new option needs a new format
    /// version is up to the rule in `DeckFile`.
    private struct OptionsRecord: Codable {
        var targetRecall: Double
        var maximumInterval: Int
        var steps: Int
        var newCardsPerSession: Int?
        /// Null while unlimited; a missing key reads as unlimited.
        var maximumReviewsPerDay: Int?
        var fuzzing: Bool
        var parameters: [Double]
        var leechThreshold: Int
        /// `LeechAction.rawValue`, left out while keep, the default; missing or unknown reads as keep.
        var leechAction: String?
        /// Left out while on, the default.
        var updatesParametersAutomatically: Bool?
        /// Left out until the app first fits the parameters by itself.
        var lastAutoFit: AutoFitRecord?
        /// Left out while the deck is not paused.
        var paused: Bool?

        init(_ options: LearningOptions) {
            targetRecall = options.targetRecall
            maximumInterval = options.maximumInterval
            steps = options.steps
            newCardsPerSession = options.newCardsPerSession
            maximumReviewsPerDay = options.maximumReviewsPerDay
            fuzzing = options.fuzzing
            parameters = options.parameters.weights
            leechThreshold = options.leechThreshold
            leechAction = options.leechAction == .keep ? nil : options.leechAction.rawValue
            updatesParametersAutomatically = options.updatesParametersAutomatically ? nil : false
            lastAutoFit = options.lastAutoFit.map(AutoFitRecord.init)
            paused = options.isPaused ? true : nil
        }

        func learningOptions() throws -> LearningOptions {
            guard let parameters = FSRSParameters(parameters) else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Expected \(FSRSParameters.count) finite FSRS weights."))
            }
            if let index = parameters.indexOutOfRange {
                throw DeckFile.Error.parameterOutOfRange(index: index)
            }
            var options = LearningOptions()
            options.targetRecall = targetRecall
            options.maximumInterval = maximumInterval
            options.steps = steps
            options.newCardsPerSession = newCardsPerSession
            options.maximumReviewsPerDay = maximumReviewsPerDay
            options.fuzzing = fuzzing
            options.parameters = parameters
            options.leechThreshold = leechThreshold
            options.leechAction = leechAction.flatMap(LeechAction.init(rawValue:)) ?? options.leechAction
            options.updatesParametersAutomatically = updatesParametersAutomatically ?? options.updatesParametersAutomatically
            options.lastAutoFit = lastAutoFit?.autoFit
            options.isPaused = paused ?? false
            return options
        }

        private enum CodingKeys: String, CodingKey {
            case targetRecall, maximumInterval, steps, newCardsPerSession, maximumReviewsPerDay
            case fuzzing, parameters, leechThreshold, leechAction
            case updatesParametersAutomatically, lastAutoFit, paused
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let defaults = OptionsRecord(LearningOptions())
            targetRecall = try container.decodeIfPresent(Double.self, forKey: .targetRecall) ?? defaults.targetRecall
            maximumInterval = try container.decodeIfPresent(Int.self, forKey: .maximumInterval) ?? defaults.maximumInterval
            steps = try container.decodeIfPresent(Int.self, forKey: .steps) ?? defaults.steps
            // A missing limit takes the default, null means unlimited.
            newCardsPerSession =
                container.contains(.newCardsPerSession)
                ? try container.decodeIfPresent(Int.self, forKey: .newCardsPerSession)
                : defaults.newCardsPerSession
            maximumReviewsPerDay = try container.decodeIfPresent(Int.self, forKey: .maximumReviewsPerDay)
            fuzzing = try container.decodeIfPresent(Bool.self, forKey: .fuzzing) ?? defaults.fuzzing
            parameters = try container.decodeIfPresent([Double].self, forKey: .parameters) ?? defaults.parameters
            leechThreshold = try container.decodeIfPresent(Int.self, forKey: .leechThreshold) ?? defaults.leechThreshold
            leechAction = try container.decodeIfPresent(String.self, forKey: .leechAction)
            updatesParametersAutomatically = try container.decodeIfPresent(Bool.self, forKey: .updatesParametersAutomatically)
            // A damaged record costs the deck one more fit, not its readability.
            lastAutoFit = try? container.decodeIfPresent(AutoFitRecord.self, forKey: .lastAutoFit)
            paused = try? container.decodeIfPresent(Bool.self, forKey: .paused)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(targetRecall, forKey: .targetRecall)
            try container.encode(maximumInterval, forKey: .maximumInterval)
            try container.encode(steps, forKey: .steps)
            // Written as null when unlimited, so a missing key can mean the default.
            try container.encode(newCardsPerSession, forKey: .newCardsPerSession)
            try container.encode(maximumReviewsPerDay, forKey: .maximumReviewsPerDay)
            try container.encode(fuzzing, forKey: .fuzzing)
            try container.encode(parameters, forKey: .parameters)
            try container.encode(leechThreshold, forKey: .leechThreshold)
            try container.encodeIfPresent(leechAction, forKey: .leechAction)
            try container.encodeIfPresent(updatesParametersAutomatically, forKey: .updatesParametersAutomatically)
            try container.encodeIfPresent(lastAutoFit, forKey: .lastAutoFit)
            try container.encodeIfPresent(paused, forKey: .paused)
        }
    }

    /// `LearningOptions.AutoFit`.
    private struct AutoFitRecord: Codable {
        var date: Date
        var reviewCount: Int
        var adopted: Bool

        init(_ fit: LearningOptions.AutoFit) {
            date = fit.date
            reviewCount = fit.reviewCount
            adopted = fit.adopted
        }

        var autoFit: LearningOptions.AutoFit {
            LearningOptions.AutoFit(date: date, reviewCount: reviewCount, adopted: adopted)
        }
    }

    /// A card without its review log, which `ReviewLogEncoder` stores apart.
    private struct CardRecord: Codable {
        var id: UUID
        var question: String
        var answer: String
        /// Left out when empty.
        var hint: String?
        /// Left out for a card on its own.
        var note: String?
        /// `CardKind.rawValue`, left out for a card without a kind; a kind this version
        /// doesn't know reads as none.
        var kind: String?
        /// Read as 1970 when missing.
        var created: Date?
        /// Left out while the card is new.
        var learningState: LearningStateRecord?
        /// Left out unless the learning state was ever reset.
        var learningStateReset: Date?
        /// Left out unless the card is suspended.
        var suspended: Bool?
        /// Left out unless the card was ever suspended.
        var suspensionChanged: Date?
        /// Left out unless the texts, the media, the note or the kind were ever changed.
        var contentChanged: Date?
        /// The names of media files (`DeckMedia`), each left out for a side without one.
        var questionImage: String?
        var questionAudio: String?
        var answerImage: String?
        var answerAudio: String?

        init(_ card: Card) {
            id = card.id
            question = card.question
            answer = card.answer
            hint = card.hint.isEmpty ? nil : card.hint
            note = card.note
            kind = card.kind?.rawValue
            created = card.created
            learningState = card.learningState.map(LearningStateRecord.init)
            learningStateReset = card.learningStateReset
            suspended = card.isSuspended ? true : nil
            suspensionChanged = card.suspensionChanged
            contentChanged = card.contentChanged
            questionImage = card.questionImage
            questionAudio = card.questionAudio
            answerImage = card.answerImage
            answerAudio = card.answerAudio
        }

        var card: Card {
            Card(
                id: id,
                question: question,
                answer: answer,
                hint: hint ?? "",
                note: Card.normalized(note),
                kind: kind.flatMap(CardKind.init(rawValue:)),
                media: CardMedia(questionImage: questionImage, questionAudio: questionAudio, answerImage: answerImage, answerAudio: answerAudio).checked,
                created: created ?? Date(timeIntervalSince1970: 0),
                learningState: learningState?.learningState,
                learningStateReset: learningStateReset,
                isSuspended: suspended ?? false,
                suspensionChanged: suspensionChanged,
                contentChanged: contentChanged
            )
        }
    }

    private struct LearningStateRecord: Codable {
        enum Phase: String, Codable {
            case learning, review, relearning

            init(_ phase: LearningPhase) {
                switch phase {
                case .learning: self = .learning
                case .review: self = .review
                case .relearning: self = .relearning
                }
            }

            var learningPhase: LearningPhase {
                switch self {
                case .learning: .learning
                case .review: .review
                case .relearning: .relearning
                }
            }
        }

        var phase: Phase
        var step: Int
        var stability: Double
        var difficulty: Double
        var lastReview: Date
        var due: Date
        var reviews: Int
        var lapses: Int

        init(_ state: LearningState) {
            phase = Phase(state.phase)
            step = state.step
            stability = state.stability
            difficulty = state.difficulty
            lastReview = state.lastReview
            due = state.due
            reviews = state.reviews
            lapses = state.lapses
        }

        var learningState: LearningState {
            var state = LearningState(
                phase: phase.learningPhase,
                step: step,
                stability: stability,
                difficulty: difficulty,
                lastReview: lastReview,
                due: due,
                reviews: reviews,
                lapses: lapses
            )
            state.sanitize()
            return state
        }
    }

    private struct SnapshotRecord: Codable {
        /// The study day as an ISO date, e.g. "2026-10-05".
        var day: String
        var bins: [Int]

        init(_ snapshot: DailySnapshot) {
            day = CivilDate(dayNumber: snapshot.day).isoString
            bins = snapshot.bins
        }

        func snapshot() throws -> DailySnapshot {
            guard let date = CivilDate(isoString: day) else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid date \(day)"))
            }
            return DailySnapshot(day: date.dayNumber, bins: bins)
        }
    }
}
