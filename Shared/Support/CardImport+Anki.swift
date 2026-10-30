import Foundation
import VocabCore

extension URL {
    /// Whether this is an Anki package, a deck (`.apkg`) or a collection (`.colpkg`), by its extension.
    var isAnkiPackage: Bool {
        ["apkg", "colpkg"].contains { pathExtension.caseInsensitiveCompare($0) == .orderedSame }
    }
}

/// The Anki side of "Import Cards…" on both platforms: reads a package (`.apkg`) off the main
/// thread and turns it into the same preview a CSV file gets, with the cards' review history
/// replayed into the deck's FSRS parameters (`AnkiImport.cards(from:…)`): those of the deck, or,
/// for a new deck, those of the Anki preset most cards use, which the deck then keeps
/// (`AnkiImport.learningOptions(applyingTo:)`). "Add N Cards" puts the cards in with
/// `DeckChange.importing`, so the history comes along.
extension CardImport {
    /// What an Anki package brought and what it left out, for the head of the preview.
    struct AnkiSummary: Equatable, Sendable {
        /// The decks of the package as Anki names them, "Parent::Child", sorted.
        var deckNames: [String]
        /// The cards that come with reviews.
        var withHistory: Int
        var skippedCloze: Int
        /// Fields that had an image or a sound, which are left out of them.
        var skippedMediaRefs: Int
        var skippedEmpty: Int
        /// Of `skippedEmpty`, the cards where a side held only an image or a sound that the package lacks.
        var skippedMediaOnly = 0
        /// The images and sounds that come with the cards, and the room they take.
        var media = AnkiImport.MediaSummary()
        /// What became of the FSRS settings of the preset most cards use.
        var settings = Settings.absent

        enum Settings: Equatable, Sendable {
            /// The preset has none Mnemit can take.
            case absent
            /// A new deck takes them: the desired retention, in percent.
            case applied(target: Int)
            /// The cards go to a deck that exists and keeps its options.
            case keptForExistingDeck
        }

        /// The names of the decks in one line.
        var deckTitle: String {
            deckNames.formatted(.list(type: .and, width: .narrow))
        }

        /// One line each for what was left out: cloze cards, cards whose only image or sound on a side
        /// isn't in the package, cards with an empty side. The other empty sides are those that nothing
        /// was left of.
        var skipLines: [String] {
            var lines: [String] = []
            if skippedCloze > 0 {
                lines.append(String(localized: "\(skippedCloze) cloze cards are left out."))
            }
            if skippedMediaOnly > 0 {
                lines.append(String(localized: "\(skippedMediaOnly) cards whose image or sound is missing from the package are left out."))
            }
            if skippedEmpty > skippedMediaOnly {
                lines.append(String(localized: "\(skippedEmpty - skippedMediaOnly) cards with an empty side are left out."))
            }
            return lines
        }

        /// Why a package gives no card: the file, then what was left out.
        func noCardsMessage(fileName: String) -> String {
            ([String(localized: "“\(fileName)” has no cards Mnemit can import.")] + skipLines).joined(separator: "\n")
        }

        /// "75 images, 75 sounds, 3.4 MB": what the package brings along, `nil` if it brings no media.
        var mediaLine: String? {
            guard !media.isEmpty else { return nil }
            var parts: [String] = []
            if media.images > 0 {
                parts.append(String(localized: "\(media.images) images"))
            }
            if media.sounds > 0 {
                parts.append(String(localized: "\(media.sounds) sounds"))
            }
            parts.append(ByteCountFormatter.string(fromByteCount: Int64(media.bytes), countStyle: .file))
            return parts.joined(separator: ", ")
        }

        /// One line each: the cards with history, the settings, the media, whatever was left out, then
        /// the images and sounds that couldn't come.
        var lines: [String] { facts + warnings }

        /// What the package brings: the cards with history, the settings, the media.
        var facts: [String] {
            var lines = [String(localized: "\(withHistory) with review history")]
            switch settings {
            case .absent:
                break
            case let .applied(target):
                // The percent sign stays out of the key: an interpolated "%" is a format escape.
                let percent = "\(target) %"
                lines.append(String(localized: "Uses Anki's FSRS settings: \(percent) target"))
            case .keptForExistingDeck:
                lines.append(String(localized: "Anki's settings for this deck are not applied to an existing deck."))
            }
            lines += mediaLine.map { [$0] } ?? []
            return lines
        }

        /// What the import leaves out: whole cards, then the images and sounds of fields that stay.
        var warnings: [String] {
            var lines = skipLines
            if skippedMediaRefs > 0 {
                lines.append(String(localized: "Images and sounds are left out of \(skippedMediaRefs) fields."))
            }
            return lines
        }
    }

    /// Reads the package at `url`, which is as a file picker or Finder gave it: the app
    /// accesses it for the time, and iCloud Drive downloads it first. Heavy: not for the
    /// main thread, see `loadAnki(at:)`.
    nonisolated static func readAnki(at url: URL) throws -> AnkiImport {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        var result: Result<AnkiImport, any Error>?
        var coordination: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordination) { url in
            result = Result { try AnkiImport.read(url) }
        }
        if let coordination { throw coordination }
        guard let result else { throw AnkiImport.Error.unreadableArchive }
        return try result.get()
    }

    /// `readAnki(at:)` off the main thread.
    static func loadAnki(at url: URL) async throws -> AnkiImport {
        try await Task.detached { try readAnki(at: url) }.value
    }

    /// The cards of `package` made for a deck with these options, as candidates: the ones the
    /// deck has already, or an earlier card of the package, are marked duplicates. Replays
    /// every review, so it takes a while for a large package: not for the main thread.
    ///
    /// `isNewDeck`: the deck has no cards yet, and takes the FSRS settings and the leech settings of the Anki preset most
    /// cards use, if it has any; the cards are replayed with them, and `learningOptions` of the
    /// result are what the deck is to have. A deck that exists keeps its options.
    nonisolated static func ankiCandidates(
        of package: AnkiImport, existing: [Card], learningOptions: LearningOptions, calendar: StudyCalendar, created: Date, isNewDeck: Bool = false,
        elsewhere: WordIndex = WordIndex()
    ) -> (candidates: [CardImporter.Candidate], summary: AnkiSummary, learningOptions: LearningOptions?) {
        let preset = package.learningOptions(applyingTo: learningOptions)
        let taken = isNewDeck ? package.deckOptions(applyingTo: learningOptions) : nil
        let cards = package.cards(learningOptions: taken ?? learningOptions, calendar: calendar, created: created)
        var summary = AnkiSummary(
            deckNames: package.deckNames, withHistory: cards.filter { !$0.log.isEmpty }.count,
            skippedCloze: package.skippedCloze, skippedMediaRefs: package.skippedMediaRefs,
            // The reader counts the notes with an empty side, `cards(from:…)` those that the text rules leave out.
            skippedEmpty: package.skippedEmpty + package.notes.count - cards.count, skippedMediaOnly: package.skippedMediaOnly,
            media: package.mediaSummary)
        if isNewDeck, let preset {
            summary.settings = .applied(target: Int((preset.targetRecall * 100).rounded()))
        } else if preset != nil {
            summary.settings = .keptForExistingDeck
        }
        return (CardImporter.candidates(of: cards, existing: existing, elsewhere: elsewhere), summary, taken)
    }

    /// The preview of `package` for `document`'s deck, made off the main thread. `isNewDeck`:
    /// the document is the new deck the package makes (see `ankiCandidates`); it takes the
    /// settings of Anki's preset when "Add N Cards" imports the preview. `elsewhere`: the words of the other decks.
    static func ankiPreview(
        of package: AnkiImport, fileName: String, for document: VocabularyDocument, isNewDeck: Bool = false, elsewhere: WordIndex = WordIndex()
    ) async -> Preview {
        let existing = document.deck.cards
        let options = document.deck.learningOptions
        let calendar = document.calendar
        let created = document.clock.now
        // Settings from Anki replace those of the deck only where there is nothing else to replay.
        let isNew = isNewDeck && existing.isEmpty
        let made = await Task.detached {
            ankiCandidates(
                of: package, existing: existing, learningOptions: options, calendar: calendar, created: created, isNewDeck: isNew, elsewhere: elsewhere)
        }.value
        return Preview(
            fileName: fileName, candidates: made.candidates, skippedRows: 0, anki: made.summary, learningOptions: made.learningOptions,
            media: package.media)
    }

    /// The name of the deck a package makes: the Anki deck's, with its levels apart by an en
    /// dash since a file name can't hold "::". Several decks take the one they share the top
    /// of, else the name of the file; so does Anki's "Default", which holds what no deck was
    /// made for.
    nonisolated static func deckName(forDecks deckNames: [String], fileName: String) -> String {
        let file = (fileName as NSString).deletingPathExtension
        let names = deckNames.filter { $0.caseInsensitiveCompare("Default") != .orderedSame }
        let tops = Set(names.map { $0.components(separatedBy: "::")[0] })
        let chosen: String
        if names.count == 1 {
            chosen = names[0].replacingOccurrences(of: "::", with: " – ")
        } else {
            chosen = tops.count == 1 ? tops.first ?? file : file
        }
        func usable(_ name: String) -> String? {
            DeckFiles.fileName(for: name.replacingOccurrences(of: ":", with: "-").replacingOccurrences(of: "/", with: "-"))
        }
        return usable(chosen) ?? usable(file) ?? "Anki"
    }

    /// Why a file couldn't be read, in words for the learner.
    nonisolated static func failureMessage(_ error: any Error) -> String {
        switch error as? AnkiImport.Error {
        case .unreadableArchive: String(localized: "This isn't an Anki package, or the file is damaged.")
        case .unsupportedVersion: String(localized: "This Anki package is from a version Mnemit can't read.")
        case .missingCollection, .unreadableCollection: String(localized: "The package holds no collection Mnemit can read.")
        case nil: error.localizedDescription
        }
    }
}
