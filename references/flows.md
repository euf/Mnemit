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
- Ring, then the day in rounds: the headline is "≈ 2 min to keep your streak" before the first
  round, "Round 2 of 4 · ≈ 2 min" after it and "Ring closed" after the last (without cards,
  "All done" or "Nothing due"); under it "M of K cards · N left", the done cards against the
  daily goal and the cards of today's plan not done yet (not the raw due count); "+N to catch
  up this week" when a backlog is left; the streak, "12-day streak", with "· kept today" once
  the first round is done; under the ring, over the width of the row, "≈ 28 words in memory ·
  +15 today" on one line (one wrapping text at large type sizes), and on the day a milestone is
  passed "50 words in memory!"; **Study** (all decks).
- Decks section: a row per deck with its counts. Tapping a row pushes the Deck screen. Swipe and context menu:
  **Pause Deck** (`pause.circle`); a swipe also offers Remove from List where the list may forget the deck.
- **Paused** section at the bottom, only when a deck is paused: its rows in the secondary colour, no counts,
  the subtitle "Paused"; swipe and context menu **Resume Deck** (`play.circle`). A paused deck is no part of the
  day: the ring, the rounds, Study and the "Next: …" leave it out. With every deck paused, Study is disabled.
- Toolbar **+** menu: Add Cards (to the last deck used), New Deck, Import.
- `.searchable` over every card of every deck; a result pushes Card Detail.
- **Empty state** (no decks): New Deck, Import Cards, Use iCloud Drive Folder. No mention of
  the Mac.

**Study stream** (covers the screen; one deck at a time, the decks with cards due one after the other)
- Header: the close button, the small ring with "Round 2 of 4" while rounds remain, "36 cards
  today" after them, the menu. Catch-up and review ahead name their stage before the ring;
  practice names itself and has no ring.
- *Rest at the end of a round* (every round but the last, inside the plan): the ring, "Round 1
  done", for the first round "Streak kept", "Next round ≈ 2 min", "+4 words in memory today"
  when the day has added any. **Next Round** (default) goes on with the cards that were left;
  **Done for Now** closes the stream. No new cards, catch-up or next deck is offered here.
  Undo, from the chip or the menu, takes back the review that ended the round and the rest
  with it; redo brings it back.
- *Rest at the end of the plan* ("Done for today"): the size of the plan, the share recalled,
  "Ring closed" when the ring is closed, "+N words in memory today", the catch-up or the next
  review; **Keep Going**, "+10 new", **Done**, and **Next: <deck>** when another deck has cards due.
- *Rest of a practice* ("Practice complete"): its figures and **Done**.

**How Today Works** (sheet; the info button at the leading edge of Today's toolbar. On the Mac the window of
Study ▸ How Today Works, over the open decks, which it names Deck 1, Deck 2.)
- For the learner who knows Anki and FSRS: the numbers and rules under the ring and the rounds, as they are
  now. Read-only: no controls, no charts. A grouped form; each section's footer holds its rule.
- **Today's Plan**: reviews due today; overdue cards taken, of the backlog; cards in learning; new cards admitted,
  and each deck's ceiling with its limits (new / production), a paused deck as "Paused: <name>" with no figures;
  the daily goal in cards; the rounds and where each ends, in cards; cards done; cards left; catch-up beyond the
  plan.
- **Capacity**: the rounds of today and their time; the last 14 days, newest first, with rounds, ring
  (Closed or Open) and step (+1, 0, −1).
- **Pace**: seconds for a new card and for another card, each with its source (Durations (n), Gaps (n) or
  Default) and the reviews each done card took.
- **Streak**: days, whether today is kept, the cards that would repair yesterday.
- **Words in Memory**: the value to two decimals, at the start of the day, the gain, the next milestone.
- **FSRS**, one section per deck: target recall, default or fitted parameters with the 21 values (monospaced,
  four decimals, wrapped), the last automatic fit, steps per card, longest interval.
- Code: `HowTodayWorks` (the rows) and `HowTodayWorksView` in `Shared/Statistics`; `DayBreakdown` in VocabCore
  holds what `DailyProgress` does not: the parts of the plan, the decks' shares, the days, the base of the pace.

**Deck** (pushed; replaces the details sheet)
- Header: what today's plan takes from the deck (new, learning, review) and "+N to catch up
  this week"; **Study This Deck**.
- Rows: Cards (count) → Card Browser; Add Cards; Import Cards…; Practice Newest; Practice Mistakes;
  Statistics; Options.
- Toolbar menu: Rename, **Pause Deck** / **Resume Deck** (`pause.circle` / `play.circle`), Export…, Delete Deck
  (moves the file to the Trash).
- A paused deck says so under its counts: "Paused. Today's plan leaves this deck out." Study This Deck and the
  rest work; the counts are those of the deck's own limits.

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

**Import**: a file picker (CSV, TSV, `.apkg` or `.colpkg`) → the same preview as the
Mac, a list with a checkmark per card (duplicates unchecked) → Add N Cards, one undo step.
Entry points: Import Cards… on the Deck screen, Import… in Today's + menu (into the deck used
last). The preview of an Anki package heads with the Anki deck names, the number of cards,
how many have review history and what was left out (cloze, media, empty); the history comes
along. **Open in Mnemit** (Files, Safari, Mail) opens a sheet that asks where the cards go:
a New Deck named after the Anki deck, or one of the decks; then the same preview. "Shared
Decks on AnkiWeb" (Today's + menu, Today's empty state, the Deck screen) opens the deck browser:
a sheet with a web view at AnkiWeb's shared decks, Back, Forward, Reload, bookmarks (AnkiWeb, MintDeck) and
Open in Safari; a link to another host opens in Safari. A `.apkg` the learner downloads there goes to the
same sheet as "Open in Mnemit"; a `.csv` or `.tsv` goes to the preview over the deck used last (a new deck
named after the file when there is none). **Export**: Export… in the Deck screen's menu opens the share sheet with a TSV that
Anki imports as it is (header lines, word key and kind columns).

**Options** (form): new cards per day; target recall (70–97 %, one-line explanation);
translation→Greek: new per day and unlock after N days; new-card order; difficult after N
lapses. Advanced: maximum interval, FSRS parameters with "Compute from Review Log".

## Mac

**Welcome window** is the Mac's Today: decks with their counts; Study opens a deck's stream;
New Deck, Import Cards, Open Mnemit Folder.
Import Cards… takes CSV, TSV, `.apkg` and `.colpkg`; a package makes a new deck named after the Anki
deck, in the window title as well as in Save As. Opening an `.apkg` from Finder does the same, not a document window.

**Deck window**: Cards | Statistics. Study ▸ **Pause Deck** / **Resume Deck** pauses the deck of the window; the
ring in the toolbar and its help count the open decks that are not paused.
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
     registers `.apkg` and `.colpkg`, so "Open in Mnemit" from Files, Safari or Mail starts the import.
   - CSV/TSV import on the iPhone; export on both with Anki's `#separator` / `#columns`
     headers and the word key and kind columns, so Anki reads the file as is.
   - No in-app deck catalogue: AnkiWeb has no API and its terms allow only browser access.
     Import offers a browser the learner drives (AnkiWeb's shared decks, MintDeck's free decks):
     no script in its pages, no scraping; the app takes only the file the learner downloads,
     which enters the import the way of "Open in Mnemit".
4. Later: example sentences from Tatoeba's open API (CC BY) in Add Cards and Card Detail.
