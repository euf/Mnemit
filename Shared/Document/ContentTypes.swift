import UniformTypeIdentifiers

extension UTType {
    /// Decks of this app: packages with the extension `.mnemit` (see `DeckFile`).
    static let vocabularyDeck = UTType(exportedAs: "com.euf.mnemit.deck", conformingTo: .package)
    /// Decks with the extension `.voctrain`, which MacVocTrain NG gave them: same contents,
    /// opened and saved in place under their name. Imported, as the app exports the type
    /// above.
    static let legacyVocabularyDeck = UTType(importedAs: "de.fluch-it-consulting.voctrain.deck", conformingTo: .package)
    /// Every type a deck may have, the one of new decks first.
    static let deckTypes = [vocabularyDeck, legacyVocabularyDeck]
    /// Documents of MacVocTrain 1 (`.mvt`), which can be imported.
    static let legacyMacVocTrain = UTType(importedAs: "com.mfluch.MacVocTrain", conformingTo: .data)
    /// Anki packages (`.apkg`), which both apps import cards from; the apps list them as
    /// viewer, rank alternate, so "Open in Mnemit" starts the import. Imported, as Anki
    /// owns the format.
    static let ankiPackage = UTType(importedAs: "com.euf.mnemit.anki-package", conformingTo: .zip)
    /// Anki collection packages (`.colpkg`), which `AnkiImport.read` reads like an `.apkg`; declared and
    /// listed in the same places.
    static let ankiCollection = UTType(importedAs: "com.euf.mnemit.anki-collection", conformingTo: .zip)
    /// Every type an Anki package may have: the pickers and panels of "Import Cards…" offer them with the tables.
    static let ankiPackages = [ankiPackage, ankiCollection]
}
