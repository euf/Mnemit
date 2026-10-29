# Getting cards in and out: TSV sync, Anki, deck sites, CSV/TSV, lesson words, word key

Cards come in through Add Cards, `deck-from-tsv`, CSV/TSV files and Anki packages. Mnemit has no import of
MacVocTrain 1 documents.

## deck-from-tsv: sync a deck with a TSV in place

- Keeps progress:
  `swift run -c release --package-path Tools/deck-from-tsv deck-from-tsv <tsv> <deck.mnemit | deck.voctrain> [--dry-run] [--suspend-missing] [--backup-dir DIR] [--new-per-session N|none] [--new-production-per-session N|none] [--unlock-days N] [--renew NOTES]`.
- TSV with the header `note⇥kind⇥question⇥answer⇥hint` (kind is `recognition` or `production`; `\n`
  in a field is a line break).
- A card is found by (note, kind). An old card without a note is adopted (its id and reviews stay) if
  its answer equals the first line of the row's answer or, for production, that line without endings
  and article. Otherwise a new card is created with a UUID v5 id from `note|kind`.
- Text is edited in place; nothing is deleted. `--suspend-missing` freezes cards whose note is not in
  the TSV.
- Before writing, a copy of the deck goes to `<deck directory>/.backups` (the 10 newest; a copy gets
  `.mnemit`, and the cleanup counts copies of both extensions). A `.voctrain` deck is written in place
  under its own name.
- A TSV without the header (question, answer, hint) works as before: only new questions are added.
- `--new-per-session` and `--new-production-per-session` set the daily limit (the old names stay).
- One run sets one `created` on its cards: they are that day's addition, first among the new cards, in the
  order of the TSV (`references/scheduling.md`).
- `--renew NOTES`: a file of word keys, one per line. After the sync, the new cards of those words join the run's
  addition in the file's order (`DeckChange.renewing`), so a deck's waiting cards can be put in a new order. The
  stamps are a second apart; a run refuses when they would reach back into the previous study day.

## Production cards

- The model and the selection rules (production unlock, hiding siblings) live in VocabCore:
  `Card.note`/`kind`, `LearningOptions.productionUnlockDays` (default 7; a value saved in a deck stays;
  0 = don't hold) and its neighbours, `StudySession.selectCards`.
- New production cards already unlocked come in the order the words were first learned: by the date of
  the first review of the recognition sibling, oldest first, whatever their addition. The newest addition
  first stays the order of recognition cards and of cards without such a date
  (`StudySession.productionOldestLearnedFirst`).
- The daily production limit works through the accumulated cards from the oldest word.
- Sources, the unlock threshold and what would change the verdict: `references/production-cards-research.md`.

## Anki import: core

- `.apkg`, `.colpkg`; VocabCore, `Import/Anki`. `AnkiImport.read(url)` reads three layouts
  (`collection.anki2`, `.anki21`, `.anki21b` under zstd with a protobuf `meta`) and returns `notes`
  (front, back, `media`, `reviews`, `isSuspended`, `preset`), skip counters (`skippedCloze`,
  `skippedMediaRefs`, `skippedEmpty`, and of it `skippedMediaOnly`: a side whose image or sound is not
  in the package), `deckNames`, `presets` and `media`. Synchronous and heavy; never call it on the main
  thread.
- Front and back come from the card's templates (`AnkiCollection.sides(ofCardAt:…)`): front is the
  first field with text among those the question shows (`qfmt`), back the first with text among those
  the answer (`afmt`) adds to the question. `{{FrontSide}}` is not a field; `{{type:Field}}` is an input
  box that shows the field only in the answer; the extra `{` of `{{{Field}}` is dropped.
- A field holding only an image or sound has no text, so the next one is taken: for the note type
  "Front, Image, Audio, Back" the front is the word and the back the translation.
- Back carries all the text the answer adds: the first field with text, then each further answer field
  with text on its own line, in template order (meaning, then example). A field whose name contains
  `freq`, `rank` or `id` (case-insensitive), or whose text has no letter at all, stays out of back
  (`AnkiCollection.isExtra`); this doesn't apply to the first field.
- If the template can't be read or shows no fields, the first two fields with text are taken, back from
  one field.
- A side's media: the first image (`<img src>`) and the first sound (`[sound:…]`) from the fields that
  side's template shows, with or without text; in the type "Front, Image, …" the image sits in a
  question field. A reference may be percent-encoded or carry HTML entities
  (`AnkiText.mediaReferences`).
- A side with no text but an image or sound is not skipped: a card needs text, an image or a sound on
  each side, and the text of an empty side is empty. Images and sounds with no place (file missing from
  the package, a second image on a side) are counted by `skippedMediaRefs`.
- `AnkiMedia` reads each layout's media list: JSON "number → name" in Legacy 1 and 2, protobuf
  `MediaEntries` under zstd in Latest (an entry is its place in the list or field 255
  `legacy_zip_filename`); a Latest file is under zstd too.
- Only the files cards name are unpacked, into a temporary folder, under a content name (`DeckMedia`);
  the folder lives while any file of `AnkiImport.media` lives. `AnkiImport.mediaSummary` gives the
  number of images, sounds and bytes for the preview.
- `Card.questionKey` tells cards without question text apart by their files; it drives the duplicate
  search.
- Cards of one Anki note stay siblings (`AnkiCollection.NoteType.sibling(ofCardAt:guid:)`): in a note
  type with several templates every card gets `note` = the note's `guid` and `kind` = `recognition`,
  except the second card of a forward/reverse pair (two templates, the second's question is the field
  the first answers with, `isReversePair`): it is `production` and waits to unlock. A type with one
  template gets neither `note` nor `kind`. A duplicate on re-import is still found by the question.
- Order: the cards studied in Anki first, in the order their notes were made, then the new ones in Anki's
  new-card order (the position in `cards.due`, `odue` for a card in a filtered deck), so the author's order of a
  shared deck is the order its new cards come in here (`AnkiCollection.imported()`).
- Cards with history: `AnkiImport.cards(from:learningOptions:calendar:created:)`. The state comes from
  replaying the reviews through `Scheduler.replaying` with the deck's FSRS parameters (Anki's own memory
  state is not read). `DeckChange.importing(_:into:learningOptions:media:)` puts them in the deck
  together with the files they name (`adding` takes only new cards without a log); one Undo removes the
  cards and the files that were new to the deck.
- Presets (`AnkiPreset`: name, `parameters`, `desiredRetention`) come from `col.dconf` of schema 11 (keys
  `fsrsWeights`, `fsrsParams5`, `fsrsParams6`, `desiredRetention`) and the `deck_config` table of schema
  18 (protobuf fields 3, 5, 6 and 37; `decks.kind` leads to the deck's preset). The newest non-empty
  list is taken, as in rslib's `DeckConfig::fsrs_params`.
- `fsrsParameters` gives 21 values: 17 and 19 are filled as `check_and_fill_parameters_fsrs6` does in
  fsrs-rs 6.6.2 and clamped to the ranges (`clip_parameters`); any other length is not taken.
- `AnkiImport.learningOptions(applyingTo:)` sets the parameters and retention (in
  `LearningOptions.sanitize`) of the preset most cards use. A preset without FSRS settings (no readable
  parameters, retention 0.9 like Anki's default) gives `nil`.
- Not read: the deck's retention (`Deck.Normal.desired_retention`) over the preset, and a card's `dr`
  from `cards.data`.
- One dependency: `facebook/zstd` (SwiftPM, BSD, in `THIRD_PARTY_NOTICES.md`); Compression doesn't know
  zstd.
- Fixtures of real packages: `Tests/VocabCoreTests/Resources/Anki`; the script that builds them sits
  next to them (`uv run --with anki`).

## Anki import: screens

- `Shared/Support/CardImport+Anki.swift`. The iPhone picker, the Mac panel and "Open in Mnemit" accept
  `.apkg` and `.colpkg`.
- Types: `UTType.ankiPackage`, imported `com.euf.mnemit.anki-package` (extension `apkg`, conforms to
  `public.zip-archive` and `public.data`), in both `Info.plist` files a Viewer document type with
  `LSHandlerRank` Alternate. The collection is `UTType.ankiCollection`, `com.euf.mnemit.anki-collection`
  (extension `colpkg`, same parents, same pair of entries in both `Info.plist` files).
  `UTType.ankiPackages` holds both: the iPhone picker (`cardFileImporter`) and the Mac panel
  (`CardImport.chooseFile`) offer them along with tables. `URL.isAnkiPackage`: extension `apkg` or
  `colpkg`.
- The preview is the CSV one (`CardImport.Preview`; a package has `anki: AnkiSummary`: Anki deck names,
  how many cards have history, skipped cloze, media, empty). `skipLines` names the reasons with counts:
  cloze, "image or sound of a side is not in the package", "empty side". `mediaLine` reads "75 images,
  75 sounds, 3.4 MB" (`AnkiImport.mediaSummary`); the files go into `Preview.media`, and "Add N Cards"
  hands them to `importCards(_:learningOptions:media:)`.
- Duplicates by question against the target deck come unchecked (`CardImporter.candidates(of:existing:)`,
  shared with CSV).
- A package without cards isn't silently empty: "No Cards" on the iPhone and the error window on the Mac
  take `AnkiSummary.noCardsMessage(fileName:)`, the file name and the same reasons with counts.
- `CardImport.loadAnki(at:)` reads the package off the main thread (access, `NSFileCoordinator`), and
  `ankiPreview` counts the cards there too. FSRS parameters and calendar come from the target deck; a
  new deck (`isNewDeck`, no cards) takes parameters and retention from the Anki preset
  (`Preview.learningOptions`).
- "Add N Cards": `importCards(_:learningOptions:)` → `DeckChange.importing`, one Undo: the cards and
  options of a new deck go in one change.
- The preview line `AnkiSummary.settings`: "Uses Anki's FSRS settings: 90 % target" for a new deck,
  "Anki's settings for this deck are not applied to an existing deck." for an existing one; no line when
  the preset has no FSRS settings.
- iPhone: `IncomingLink` (study, ankiPackage, deck) parses the URL in `StartScreen.open`. The package is
  copied into `tmp/IncomingAnki` (`IncomingPackages`: the URL may be scoped, in Inbox or in iCloud). The
  sheet `AnkiDestinationSheet` reads it and asks where: "New Deck “<name>”" (`DeckFiles.create` in the
  current folder, name from `CardImport.deckName`, a taken name gets " 2", " 3"; the file is marked
  `ImportedFile.isNewDeck`) or a deck from the list; then the same `AddCardsHost` with
  `ImportPreviewSheet`.
- While onboarding or the Study stream covers the screen, the package waits (`waitingAnki`).
- The link "Shared Decks on AnkiWeb" (`AnkiWebLink`), in the "+" menu, on an empty Today and on the
  deck screen, opens the deck site browser (below).
- Mac: `AppDelegate.application(_:open:)` hands an `.apkg` from Finder to `Shell.receive`, as the AnkiWeb
  window's downloads and File ▸ Import Cards… with no deck selected reach `Shell.importIntoNewDeck(from:)`.
  It reads the package once (`CardImport.loadAnki`, passed on to the preview), makes a deck in the Mnemit folder
  named after the Anki deck (`CardImport.deckName`; a taken name gets " 2", " 3"),
  selects it and shows the preview of its cards, which takes the preset's settings. A table does the same, named after the file. File ▸ Import Cards… (⇧⌘I) with a
  deck selected imports into that deck, keeps its settings and asks nothing. New Deck… (⌘N) asks the name.
  Decks from Finder go to `Shell.open`.

## Deck site browser

- `Shared/Web/DeckWebBrowser` and `DeckWebBrowserView`: a sheet on the iPhone, the window
  `DeckWebWindow` on the Mac (from the sidebar's (+) menu, Today's empty state and File ▸ "Shared Decks on AnkiWeb…").
- A plain `WKWebView` driven by the person: no scripts in pages, no custom user agent, no page parsing
  or preloading. The app gets only the file the person downloaded.
- Sources: one constant `DeckSources.all` in `Shared/Support/DeckSources.swift` (AnkiWeb Shared Decks as
  the start page, MintDeck Free Decks). It is both the toolbar bookmarks and the host list.
- A source's host or its subdomain (https) stays in the window; a click on a link to any other host
  goes to Safari; the source's redirects don't count as clicks.
- Download: a main-frame response becomes `.download` if the file name (`Content-Disposition` or path)
  ends in `apkg`, `csv`, `tsv`, or the header says `attachment`, or the MIME type is
  `application/octet-stream`, `zip`, `text/csv`, `text/tab-separated-values`, or WebKit can't show the
  response (`DeckDownload.shouldDownload`); a link with the `download` attribute too.
- `WKDownloadDelegate` puts the file in `tmp/DeckDownloads/<uuid>/` (a name without
  `.apkg`/`.csv`/`.tsv` gets `.apkg`; the import names a read error); the next download clears the
  folder.
- The file goes the same way as "Open in Mnemit" and the picker. iPhone: `StartScreen.receiveDownload`
  (a package to `receiveAnki`, a table to the preview of the last used deck, or with no decks into a new
  one named after the file). Mac: `Shell.importIntoNewDeck(from:)`.
- WebKit files are excluded from the widget target (`PBXFileSystemSynchronizedBuildFileExceptionSet` on
  the `Shared` group). The sandboxed Mac app has `com.apple.security.network.client`; without it
  `WKWebView` loads nothing.

## CSV/TSV import and export

- Shared logic: `CardImport` and `CardExport` in `Shared/Support`. The Mac adds file panels
  (`CardImportPanel`, `CardExportPanel`), the iPhone the sheets below.
- An export starts with Anki's lines `#separator:tab` (or `comma`), `#html:false`,
  `#columns:Front⇥Back⇥Hint⇥Word Key⇥Kind` (on the Mac with learning state also `Maturity`, `Due`,
  `Reviews`). There is no header row with names: Anki would take it for a card. Column names are English
  in any language; Front and Back are the field names of Anki's basic note type, by which its dialog
  maps the first two columns itself. `kind` is `recognition` or `production`, empty on a card without a
  word key.
- Reading: `DelimitedText.decode` skips the `#…` lines at the start of the file, takes the separator
  from `#separator` and returns `columns`. `CardImporter` finds Question or Front, Answer or Back, Hint,
  Word Key and Kind by name (from `#columns` or a header row); a kind without a word key is dropped.
  Older exports with a header row in the app's language still read through `CardImport.isHeader`.
- Not read from Anki: the columns `#guid column`, `#notetype column`, `#deck column`, `#tags column` and
  `#html:true` (HTML stays in the text).
- Export doesn't carry card images and sounds: the table doesn't know them.
- iPhone: "Import Cards…" on the deck screen and "Import…" in Today's "+" menu (into the last used
  deck) go through `cardFileImporter` to `ImportPreviewSheet` (duplicates, words of other decks too,
  unchecked; "Add N Cards" is one `importCards`, one Undo). "Export…" in the deck screen menu is a
  `ShareLink` with `DeckExport` (TSV in a temporary file `<deck>.tsv`).
- Two `fileImporter`s on one view cancel each other: in `StartScreen` the deck picker is on the stack,
  the card picker on `TodayScreen`.

## Lesson words

- The From a List mode of Add Cards is `LessonWords` in VocabCore with `WordList` in `Shared/Support`. The Mac's
  sheet (`AddCardsView`, Study ▸ Add Cards… ⇧⌘L) has the iPhone's two modes, One Card and From a List. `note` is
  the recorded word key (`WordKey`, below; `key()` in `greek-lessons/vocab/merge.py` cuts only at the first comma and
  bracket), two cards per word, one Undo.
- Sides are separated by `=`, `–`, `—`, a tab, or a hyphen with spaces on both sides (the phone keyboard
  types it); a hyphen inside a word doesn't split.
- A word of the list the deck holds already is a duplicate, unchecked. Its cards that aren't started yet join
  the addition in the same undo step (`WordListPreview.renewable(in:)`, `VocabularyDocument.addLessonCards(_:renewing:)`):
  the lesson goes first among the new cards as a whole, and Study These Now asks those cards too.

## Word key

- `WordKey` in VocabCore, `Import/WordKey.swift`; `Card.note` stores it as `lemma#article`. Two cards are
  about one word if, after NFC and lower case (final sigma ς), the lemma matches and the articles are
  compatible.
- The lemma is the text before the first `,`, `; `, ` / `, ` · `, `(` or ` -`, and before an endings
  tail (`-ή-ό`). A hyphen inside a word stays; `;` without a space is the Greek question mark.
- The article counts: `κύριος` and `ο κύριος` are two words. `ο/η` (and `η/ο`) matches `ο` and `η` of the
  same lemma; the others (`το`, `οι`, `τα`, `ένας`, `μια`, `μία`, `ένα`) only themselves.
- Accents stay: `πώς` and `πως` are two words. `WordKey.same(as:)` is one word; `looksLike(_:)` is words
  that differ only in accents (`CardSearchIndex.fold`); the latter only informs.
- Only Greek has a key. A card takes it from `note`, and if `note` has no Greek letters (none, or a
  random Anki note string) from the question; without Greek letters there is no key.
- `WordKey.groups(of:)` joins keys into words through a third one (`ο` and `η` through `ο/η`).
- `WordIndex` holds the words of several decks by key: deck name, Greek side, answer (first line),
  cards. `match(_:)` returns `.same` or `.looksLike`.
- The index is advisory: it sets checkmarks and adds lines of text, and an empty index gives back
  single-deck behaviour. Its users:
  - import (`CardImporter.candidates(…elsewhere:)`): `Duplicate.inOtherDeck` unchecked, line "Also in
    <deck>: word → answer"; `Candidate.similar` checked, "Similar to word in <deck>: answer". The "in the
    deck" and "earlier in the file" checks come first; the per-deck summary is
    `CardImport.Preview.otherDeckLines`;
  - Add Cards, both apps (`WordList`): in From a List a row whose word another deck holds is unchecked with the
    line "Also in <deck>", and a similar one is checked; One Card shows a caption under the field. As a
    function the same is `LessonWords.plan(…elsewhere:)` (`Plan.skippedElsewhere`, `Plan.similar`); the deck's
    notes compare as keys, `οδηγός#ο/η` holds `ο οδηγός`;
  - the card in the browser and inspector ("Also in <deck>" next to the sibling, `Deck.siblings(of:)`).
- The index is built off the main thread when the sheet or screen opens. iPhone: all known decks
  (`KnownDeckFiles` in the environment, set by `StartScreen`; files read by `DeckFileReader`; the
  screen's own deck, by `document.packageURL`, is left out). Mac: open documents
  (`OpenDecks.wordIndex(excluding:)`). Paused decks are included.
- Decks are linked by text only: words are not glued together, every card keeps its own schedule,
  siblings are not hidden across decks.
- The verdict, the threshold for hiding (1 % of the active decks' cards in pairs with two active
  copies) and measurements on EF's decks: `references/cross-deck-overlap.md`.
