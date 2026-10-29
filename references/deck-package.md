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
- Format version 6 (`DeckFile.currentVersion`): `deck.json` has the key `retired`, the cards deleted that had reviews
  (`Deck.retiredCards`), as card records without logs, left out while there are none. Their lines in `reviews.jsonl` come
  after those of the cards. An older app would drop the key and reject the lines of a card it doesn't know, so it rejects the
  deck. A deck without the key reads with no retired cards.
- The options `leechThreshold` and `leechAction` came without a version bump. `leechAction` is `"suspend"` or left out
  (`keep`, the default); a missing or unknown value reads `keep`. An older app drops both on save, and the deck reads as keep
  again.
- The option key for new cards is `newCardsPerSession`, which holds New cards/day. A `deck.json` that still has
  `cardsPerSession`, `newProductionPerSession` or `productionUnlockDays` reads, and the next save leaves them out.
- Key rules for `deck.json` and `reviews.jsonl` and when to bump `DeckFile.currentVersion`: CLAUDE.md,
  Conventions.

## Editing on iPhone and Mac

- Both apps edit through the same methods, `VocabularyDocument+Editing` in `Shared`, with shared undo and
  action names.
- Both apps hold a deck the same way. `OpenDeck` (`Shared/Document/OpenDeck.swift`) owns the
  `VocabularyDocument` the views show and a file document that reads and saves the package: a UIDocument
  on the iPhone, the headless NSDocument `DeckFileDocument` (`MacVocTrainNg/Document/`) on the Mac. The Mac
  document is an NSDocument without windows; it registers itself in
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
  later than everything done to the card (edit, reset, pause, review); on a tie the card stays. The retired cards of both
  versions are joined by id, their logs like a card's: a card the deletion rule drops is retired with its log joined to the
  other side's retired one, and a card that stays (changed after the deletion) takes the retired log.
- A deck that changes while it is open changes in place. Kept cards keep their progress, new cards come as new, and a deleted
  card leaves the plan and the stream with its reviews kept (retired), so today's ring keeps what it counted. Edited texts
  follow the later `contentChanged`; the stream shows `document.card(withID:)`, so the card on screen and those to come show
  the new text. The file keeps times to the second.
- A review's change is `learningOnly`: it and its inverse replace only the learning state, log, reset stamp and suspension of
  a card the deck holds. Undoing a review keeps a text a merge brought in and brings no deleted card back; if a merge deleted
  the graded card, undo does nothing to it. Ceiling: if the other device graded the same card meanwhile, undo restores this
  device's state of it.
- Undo survives a reread. UIDocument and NSDocument empty their undo manager inside `revert(toContentsOf:…)`, which is how a
  file is read again after another device changed it. Both `DeckFileDocument`s (iPhone and Mac) override the revert: they swap
  in a scratch `UndoManager` and put the real one back when the read ends (the iPhone in the completion handler, the Mac in a
  `defer`). Reviews register their undo action with the document, edits, suspensions and merges with `editsUndoTarget`.
  `OpenDeck.forgetUndoSteps` → `VocabularyDocument.forgetEditUndoSteps()` drops only the second kind after a merge of a deck
  read again, so undo takes back the last grade and brings its card back into the stream, never the merge or an earlier
  edit. Practice undo stays on the document too.
- A running stream holds card ids. When its card goes (deleted or suspended, in the file or in the app),
  `SessionDriver.deckDidChange` moves on to the next card without a grade, and `skipUnaskableCards` skips such cards at every
  move. Cards added in the file wait for the next stream; the due counts (`DueCardCounter`) take them in within the day's
  allowance.
- `Tools/deck-from-tsv` (`SyncRun`) writes like an app: it reads the deck, plans, backs up and writes inside one
  `NSFileCoordinator` write (`.forMerging`), so iCloud Drive and open apps are told and nothing changes between the read and
  the write. A dry run reads coordinated.
- The keys `contentChanged`, `learningOptionsChanged` and `deletedCards` in `deck.json` came without a
  format version bump.
- Deck file operations on the iPhone (create `<name>.mnemit`, rename, move to trash) are `DeckFiles` in
  `Shared/Document`: through `NSFileCoordinator`, `async`, off the main thread. Where the volume has no
  trash (the app's folder on the iPhone), the deck moves to a sibling folder `Deleted Decks` and is never
  deleted for good.

## Progress ledger

The records of past study days (`DayLedger`, `daily-ring.md`) are not part of a package. They live in the deck folder, beside
the decks.

- `<deck folder>/.mnemit-progress/<device id>.jsonl`: one file per device, JSON Lines, a record per study day, oldest first. Keys
  of a record: `day` (ISO date), `reviews`, `done`, `goal`, `keep`, `kept`, `closed`, `time`, `worked`, `reason`, `filled`,
  `words`. The deck folder is the Mac's `DeckFolder.shared.url` and the iPhone's `KnownDecks.folder` (the local Documents folder
  counts). With no folder chosen the files are in the app's `Application Support/Mnemit/.mnemit-progress/`, read by this device
  only.
- The device id is a UUID string in `UserDefaults` (`ProgressLedgerDevice`), made on first use, one per app install.
- A device writes only its own file, and that file is the merge of every file it read and its own updates, so each file grows
  to the whole ledger. Two devices never write one file, so iCloud Drive makes no conflict copy of it, and the per-day merge
  makes a reread of any file idempotent.
- Reading takes every `*.jsonl` of the folder, merged. A hidden placeholder `.<name>.jsonl.icloud` is skipped and its download
  started (`startDownloadingUbiquitousItem`). Each read and write goes through `NSFileCoordinator` inside the folder's
  security-scoped access; a write is atomic and makes the folder if it is missing. An unreadable line costs its day only.
- The deck listings skip the folder: `DeckFolder.decks(in:)` skips hidden files, `KnownDecks.decks(in:)` takes only deck names.
- `ProgressLedgerStore` (`Shared/Document`) does all of it.

## Media

- `CardMedia` and `DeckMedia` in VocabCore, `Deck.media`. A `Card` has four optional file names:
  `questionImage`, `questionAudio`, `answerImage`, `answerAudio`. `deck.json` uses the same keys; a side
  without a file has none.
- Files live in `X.mnemit/media/`. The name is the first 16 hex characters of the content's SHA-256 plus
  the extension in lower case (`3f2a9c0b7d1e4a58.jpg`, `DeckMedia.name(for:fileExtension:)`). A file never
  changes under its name, identical files are stored once, and iCloud Drive syncs each file on its own.
- A name of any other shape in `deck.json` (`DeckMedia.isValidName`) reads as "no file" and never reaches
  a path.
- Format version 5 added the media keys: an older app would save the deck without `media/` and
  lose the files, so it rejects the deck. Versions 3 and 4 are read, as decks without media.
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
