# Deck package: format, editing on two devices, media

The deck file, how both apps edit and merge it, and the media files of cards.

## Package and file types

- A deck is a package `X.mnemit`: `deck.json`, `reviews.jsonl` and a folder `media/` when cards have
  images or sounds. The type `com.euf.mnemit.deck` is exported from both `Info.plist` files and
  declared in `Shared/Document/ContentTypes.swift` (`UTType.vocabularyDeck`).
- VocabCore owns the extension and the name check: `DeckFile.fileExtension`, `DeckFile.isDeckName`. No
  other code writes the extension.
- `.voctrain` files (imported type `de.fluch-it-consulting.voctrain.deck`,
  `UTType.legacyVocabularyDeck`) work the same way: they open, show in folder lists next to `.mnemit`,
  are edited and saved in place under their own name. The app never renames them.
- `UTType.deckTypes` holds both types, the new one first. It is the iPhone picker's filter and the
  Mac's way to find a file's type from its extension (`DeckFileDocument`); File ▸ Open Deck… offers
  `DeckFile.fileExtensions`. Inside `deck.json` both extensions have the same `format` key and the same
  content.
- Key rules for `deck.json` and `reviews.jsonl` and when to bump `DeckFile.currentVersion`: CLAUDE.md,
  Conventions.

## Editing on iPhone and Mac

- Both apps edit through the same methods, `VocabularyDocument+Editing` in `Shared`, with shared undo and
  action names.
- Both apps hold a deck the same way. `OpenDeck` (`Shared/Document/OpenDeck.swift`) owns the
  `VocabularyDocument` the views show and a file document that reads and saves the package: a UIDocument
  on the iPhone, the headless NSDocument `DeckFileDocument` (`MacVocTrainNg/Document/`) on the Mac. The Mac
  document has no window and no `ReferenceFileDocument` conformance; it registers itself in
  `NSDocumentController`, so a deck stays open while no window shows it. It reads with
  `DeckFile.read(at:)` off the main actor, coordinated, saves in place (`autosavesInPlace`; the
  `VersionMerger` also saves a few seconds after each change) and writes through
  `write(to:ofType:for:originalContentsURL:)`. When another process changes the file it reads again, and
  `OpenDeck` merges what it read into the document it holds (`VersionMerger`), so the views keep their
  document and a study session goes on.
- Undo: the file document's own undo manager is the one every change registers with. `OpenDeck` attaches it
  to the document (`attachUndoManager`) on both apps, and NSDocument or UIDocument counts the changes from it
  and autosaves them. On the Mac the shell's `UndoRouter` answers Edit ▸ Undo with the manager of the deck
  the window shows. An error of a deck (autosave, read) is a sheet of the window
  (`DeckFileDocument.sheetWindow`, `windowForSheet`), never app-modal.
- The Mac keeps decks open in the registry `OpenDecks` (`MacVocTrainNg/Support/OpenDecks.swift`): one
  `OpenDeck` per file however its URL is spelled, `open(_:)`, `deck(for:)`, `close(_:)` (before a rename or a
  delete) and `closeAll()`. Closing saves first: `settleChanges()` waits for an open undo group to close, since
  NSDocument counts a change one run-loop turn after the group ends. A deck opens when it is selected or
  studied and stays open until the app quits, so its undo steps survive a switch to another deck.
  `StudyRun` (the decks of a stream; given `open`, it owns none of the upcoming decks) and `TodayDecks` (the
  decks of the day and the paused ones) sit in `Shared/Document/` beside `OpenDeck`; the shell model drives
  them (`screens.md`, The Mac's window).
- Finder: `application(_:open:)` hands the files to `Shell.receive`: a deck is opened and selected (a deck
  outside the Mnemit folder is listed under Other Decks until the app quits), an Anki package or a table
  fills a new deck. Quit: `applicationShouldTerminate` answers `.terminateLater`, `closeAll()` saves and
  closes every deck, then the app replies.
- Merging versions edited on both devices: cards are joined; text, note and kind come from the version
  with the later `Card.contentChanged` (undo stamps it again); options from the later
  `Deck.learningOptionsChanged`. A deletion is remembered in `Deck.deletedCards` and wins only if it is
  later than everything done to the card (edit, reset, pause, review); on a tie the card stays.
- The keys `contentChanged`, `learningOptionsChanged` and `deletedCards` in `deck.json` came without a
  format version bump.
- Deck file operations on the iPhone (create `<name>.mnemit`, rename, move to trash) are `DeckFiles` in
  `Shared/Document`: through `NSFileCoordinator`, `async`, off the main thread. Where the volume has no
  trash (the app's folder on the iPhone), the deck moves to a sibling folder `Deleted Decks` and is never
  deleted for good.

## Media

- `CardMedia` and `DeckMedia` in VocabCore, `Deck.media`. A `Card` has four optional file names:
  `questionImage`, `questionAudio`, `answerImage`, `answerAudio`. `deck.json` uses the same keys; a side
  without a file has none.
- Files live in `X.mnemit/media/`. The name is the first 16 hex characters of the content's SHA-256 plus
  the extension in lower case (`3f2a9c0b7d1e4a58.jpg`, `DeckMedia.name(for:fileExtension:)`). A file never
  changes under its name, identical files are stored once, and iCloud Drive syncs each file on its own.
- A name of any other shape in `deck.json` (`DeckMedia.isValidName`) reads as "no file" and never reaches
  a path.
- Format version 5 (`DeckFile.currentVersion`): an older app would save the deck without `media/` and
  lose the files, so it rejects the deck. Versions 3 and 4 are read.
- Media are card content: they change through `DeckChange.settingMedia` (undo, `contentChanged` stamp)
  and merge together with the texts, while the files of both versions are joined: `DeckChange.merging`
  takes from the other version the files this one lacks and a card of the merged deck names.
- The deck holds files as `FileWrapper` and reads no bytes; `DeckMedia.contents(of:)` reads on demand.
- Reading a package (`DeckFile.decode(_:withMedia:at:)`) keeps the files at least one card names. A file
  no card names stays out of the deck and leaves the package with the next save.
- While a deck is open, files are only added: deleting a card or changing its media removes nothing, so
  Undo finds the file in place. Undo of the change that brought a file (import, merge) removes it, and
  only if no card names it.
- A name on a card whose file is not in the package (iCloud Drive hasn't delivered it yet) stays on the
  card; the version with the file brings it in through the merge.
- Writing (`DeckFile.fileWrapper(for:reviewLog:original:)`) builds the `media` folder from `Deck.media`. A
  file already in the `original` package is cloned from there (`MediaFileWrapper`: `FileManager.copyItem`;
  on APFS a clone shares blocks and writes no bytes). `FileWrapper.write(to:options:originalContentsURL:)`
  links nothing (measured on macOS 27: 400 MB write in 0.3 s, a clone in 2 ms).
- `original` comes from the file document's `originalContentsURL`, UIDocument's on the iPhone and
  NSDocument's in `write(to:ofType:for:originalContentsURL:)` on the Mac; without one,
  `VocabularyDocument.packageURL`, set by `VersionMerger.attach`.
- Readers that need only the cards skip media: `DeckFileReader` reads through
  `DeckFile.read(at:withMedia: false)` and never saves. Versions in conflict are read by
  `DeckFile.read(at:)`; their files stay on disk until the first save.
- Reading through `FileWrapper(url:options: .immediate)` pulls every media file into memory, so the apps
  never read that way.
- Not built yet: showing media, recording one's own sound and picking one's own images in the apps.
