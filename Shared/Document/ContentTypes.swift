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
}
