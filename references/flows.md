# Flows: iPhone and Mac

The target user flows of Mnemit on both platforms. Screens and wording here are the contract
agents build to. Visual rules (spacing, colour, type) are in `design-spec.md`; what exists in
code today is mapped in the inventory of 21.10.2026 (anchors in the commit that adds this file).

## Who

| User | Arrives with | Needs first |
|---|---|---|
| Newcomer | nothing, often an iPhone only | learn the swipes, make or import a first deck, study |
| Anki user | `.apkg` decks and Anki habits | import with progress, a card browser, deck options |
| Daily learner | decks already in iCloud Drive | one tap to study; after a lesson, add the new words in a minute |
| Curator (Mac) | a deck to keep tidy | table, keyboard, bulk edits, import and export, options, optimizer |

## Rules for both platforms

1. One tap from launch to study: Today's Study button studies every deck with due cards.
2. The deck is what people see. The folder is named only in the sync step and in Settings.
3. A card can be found, read, edited, suspended, reset and deleted on both platforms. The Mac
   adds multi-select, keyboard and the table; nothing about a card is Mac-only.
4. The same filters with the same names everywhere:
   **All · Due · New · Learning · Suspended · Difficult** (Difficult = leech).
5. Every change goes through the document's undo. Deleting one card needs no confirmation
   (undo covers it); deleting several, or a deck, asks once.
6. Search matches question, answer, hint and the word key (`note`), ignoring case and accents.

## iPhone

Root is a `NavigationStack` on Today.

**Today**
- Ring, due count, streak; **Study** (all decks).
- Decks section: a row per deck with its counts. Tapping a row pushes the Deck screen.
- Toolbar **+** menu: Add Cards (to the last deck used), New Deck, Import.
- `.searchable` over every card of every deck; a result pushes Card Detail.
- **Empty state** (no decks): New Deck, Import Cards, Use iCloud Drive Folder. No mention of
  the Mac.

**Deck** (pushed; replaces the details sheet)
- Header: due today, new, learning; **Study This Deck**.
- Rows: Cards (count) → Card Browser; Add Cards; Practice Newest; Practice Mistakes;
  Statistics; Options.
- Toolbar menu: Rename, Export…, Delete Deck (moves the file to the Trash).

**Card Browser** (pushed)
- `List` with `.searchable` and the filter row (rule 4); sort menu: Due, Added, A–Z,
  Difficulty.
- Row: question (primary), answer (secondary), trailing state (relative due date / New /
  Suspended / Difficult).
- Swipe: trailing Delete, Suspend/Resume; context menu: Edit, Speak, Suspend/Resume,
  Reset Progress, Delete.
- Edit mode: multi-select, then Suspend, Resume, Reset or Delete.
- Tap pushes Card Detail.

**Card Detail** (pushed)
- Both sides large, speaker beside the Greek.
- Kind (Greek → translation / translation → Greek) with a link to the sibling card.
- Memory: state, next review, stability (days), difficulty, recall now (%).
- History: each review with date and the grade's colour and arrow.
- Toolbar **Edit**; actions: Suspend/Resume, Reset Progress, Delete.

**Edit Card** (sheet): Question, Answer, Hint; Word key under Advanced. Cancel / Save.

**Add Cards** (sheet), two modes:
- One Card: Question, Answer, Hint, "Both directions" toggle; **Add** keeps the sheet open
  for the next card.
- From a List: paste lines `word = translation`, a live preview of the cards, Add N Cards.
  The same parser as the Mac's Lesson Words.

**New Deck**: a name field; creates `<name>.mnemit` in the deck folder (iCloud Drive or
this iPhone).

**Import**: a file picker (CSV/TSV now, `.apkg` when supported) → the same preview as the
Mac → into a new or the current deck. **Export**: the share sheet with a CSV.

**Options** (form): new cards per day; target recall (70–97 %, one-line explanation);
translation→Greek: new per day and unlock after N days; new-card order; difficult after N
lapses. Advanced: maximum interval, FSRS parameters with "Compute from Review Log".

## Mac

**Welcome window** is the Mac's Today: decks with their counts; Study opens a deck's stream;
New Deck, Import Cards, Open Mnemit Folder.

**Deck window**: Cards | Statistics.
- Cards: the filter row of rule 4 as a scope bar under the toolbar (replaces the Leeches
  toggle); search includes the word key; table columns as today plus Kind.
- Inspector: the iPhone's Card Detail sections, including kind, word key and sibling.
- Edit sheet: Question, Answer, Hint, Word key.
- Keyboard: as today (Delete, ⌘E, ⌘L, ⌘1/⌘2, Space/arrows in the stream).

## Waves

1. Shared editing layer for the iPhone document; Mac browser parity (filters, kind, word key,
   failing tests).
2. iPhone Deck screen and Card Browser with Card Detail and Edit; Add Cards; New Deck,
   Rename, Delete, Options; empty state.
3. Import and export on both platforms (facts in `deck-formats-and-sources.md`):
   - `.apkg` import, all three layouts, with review history replayed into FSRS; text fields
     with HTML stripped; media and cloze notes skipped and counted in the preview. Mnemit
     registers `.apkg`, so "Open in Mnemit" from Files, Safari or Mail starts the import.
   - CSV/TSV import on the iPhone; export on both with Anki's `#separator` / `#columns`
     headers and the word key and kind columns, so Anki reads the file as is.
   - No in-app deck catalogue: AnkiWeb has no API and its terms allow only browser access.
     Import offers a link to AnkiWeb's shared decks, which opens in Safari; the downloaded
     `.apkg` comes back through "Open in Mnemit".
4. Later: example sentences from Tatoeba's open API (CC BY) in Add Cards and Card Detail.
