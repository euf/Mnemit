import Foundation
import VocabCore

extension URL {
    /// Whether this is an Anki package, by its extension.
    var isAnkiPackage: Bool {
        pathExtension.caseInsensitiveCompare("apkg") == .orderedSame
    }
}

/// The Anki side of "Import Cards…" on both platforms: reads a package (`.apkg`) off the main
/// thread and turns it into the same preview a CSV file gets, with the cards' review history
/// replayed into the deck's own FSRS parameters (`AnkiImport.cards(from:…)`). "Add N Cards"
/// puts them in with `DeckChange.importing`, so the history comes along.
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

        /// The names of the decks in one line.
        var deckTitle: String {
            deckNames.formatted(.list(type: .and, width: .narrow))
        }

        /// One line each: the cards with history, then whatever was left out.
        var lines: [String] {
            var lines = [String(localized: "\(withHistory) with review history")]
            if skippedCloze > 0 {
                lines.append(String(localized: "\(skippedCloze) cloze cards are left out."))
            }
            if skippedEmpty > 0 {
                lines.append(String(localized: "\(skippedEmpty) cards with an empty side are left out."))
            }
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
    nonisolated static func ankiCandidates(
        of package: AnkiImport, existing: [Card], learningOptions: LearningOptions, calendar: StudyCalendar, created: Date
    ) -> (candidates: [CardImporter.Candidate], summary: AnkiSummary) {
        let cards = package.cards(learningOptions: learningOptions, calendar: calendar, created: created)
        let summary = AnkiSummary(
            deckNames: package.deckNames, withHistory: cards.filter { !$0.log.isEmpty }.count,
            skippedCloze: package.skippedCloze, skippedMediaRefs: package.skippedMediaRefs,
            // The reader counts the notes with an empty side, `cards(from:…)` those that the text rules leave out.
            skippedEmpty: package.skippedEmpty + package.notes.count - cards.count)
        return (CardImporter.candidates(of: cards, existing: existing), summary)
    }

    /// The preview of `package` for `document`'s deck, made off the main thread.
    static func ankiPreview(of package: AnkiImport, fileName: String, for document: VocabularyDocument) async -> Preview {
        let existing = document.deck.cards
        let options = document.deck.learningOptions
        let calendar = document.calendar
        let created = document.clock.now
        let made = await Task.detached { ankiCandidates(of: package, existing: existing, learningOptions: options, calendar: calendar, created: created) }.value
        return Preview(fileName: fileName, candidates: made.candidates, skippedRows: 0, anki: made.summary)
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
