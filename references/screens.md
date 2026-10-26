# Screens of both apps: what each shows and does

The contract of every screen of Mnemit on the iPhone and the Mac, with the code that holds it. What the screens show
follows the entities of `references/product-model.md`; this file says where and how. The
visual spec (spacing, colour, type, rings, accent): `references/design-spec.md`; the iPhone Study
screen's layout, motion, speech window and swipe: `references/study-screen.md`; the paths through a
day: `references/learning-flow.md`, "The journey"; the stream's mechanics: `references/scheduling.md`;
the day's numbers: `references/daily-ring.md`.

## Users and rules for both apps

| User | Arrives with | Needs first |
|---|---|---|
| Newcomer | nothing, often an iPhone only | learn the swipes, make or import a first deck, study |
| Anki user | `.apkg` decks and Anki habits | import with progress, a card browser, deck options |
| Daily learner | decks already in iCloud Drive | one tap to study; after a lesson, add the new words in a minute |
| Curator (Mac) | a deck to keep tidy | table, keyboard, bulk edits, import and export, options, optimizer |

1. One tap from launch to study: Today's Study button studies every deck with due cards.
2. The deck is what people see. The folder is named only in the sync step and in Settings.
3. A card can be found, read, edited, suspended, reset and deleted on both platforms. The Mac adds
   multi-select, keyboard and the table; nothing about a card is Mac-only.
4. The same filters with the same names everywhere:
   **All · Due · New · Learning · Suspended · Difficult** (Difficult = leech).
5. Every change goes through the document's undo. Deleting one card needs no confirmation (undo covers
   it); deleting several, or a deck, asks once.
6. Search matches question, answer, hint and the word key (`note`), ignoring case and accents.

## Today (iPhone)

The iPhone starts on Today, the root of a `NavigationStack` (`StartScreen` holds the state,
`TodayScreen` draws). State by state: `design-spec.md` §2.4.

- The hero (`TodayHero`, `Shared/Session/TodaySummary.swift`), the whole of it a button that opens the
  Progress screen:
  - The ring (`HeroRing`, 168 pt): a picture, with no number in it.
  - The sentence (`NextStep`, drawn by `StreakSentence`), led by the flame: the next moment of the day and its minutes.
    The streak step not done: "≈ 2 min to keep your 12-day streak" ("Start your streak · ≈ 2 min" without a streak); the
    step done, the ring open: "12-day streak · ≈ 5 min to close the ring"; the ring closed with cards of the plan left:
    "Ring closed · ≈ 12 min of reviews left"; nothing left: "All done for today"; at risk: "≈ 6 min to close the ring and
    save your 12-day streak". Without a price the time is left out and the streak stays. The flame has three states
    (`StreakState`): a grey outline until the streak step is done, `flame.fill` in `Color.streak` once it is, an orange
    outline with an `exclamationmark` at risk (`DailyProgress.isStreakAtRisk`: the day after a missed day, ring open).
    VoiceOver reads the sentence with the state. One line when it fits; else the streak line over the price line, each
    wrapping by itself (`NextStepText`); "7-day" and "≈ 2 min" never break.
  - One line of words learned (`WordsLearned.line`): "412 words learned · +12 today"; the gain is left out on a day that
    has none, and the whole line while there are no words.
  - The week's seven rings (`WeekRings`, 22 pt), with a chevron at the end of the row.
  - The day turns at 04:00, and work done just before it, on either device, belongs to the day before.
    The hero waits for every deck to be read and the ring to be evaluated (`isDayReady`); until then it shows
    placeholders. The ring keeps its size at every text size; the sentence and the line wrap and the list scrolls.
- The bottom bar holds the day's one button beside Search All Cards, which is minimised to a button
  (`.searchToolbarBehavior(.minimize)`). The button is named by `DayAction`
  (`Shared/Session/TodaySummary.swift`): **Study** in the accent while the ring is open; **Catch Up** once the
  ring is closed and the plan has cards left; **Learn 10 New Words** once the plan is done, with no footnote. Its title is one
  line and shrinks to 75 %. Study and Catch Up open the stream over the screen (`StudyRunView`) over every active
  deck. Learn 10 New Words opens it with ten new cards at once over every active deck (`StudyModel.Entry.pushOn`),
  without the rest first. With every deck paused the button is disabled.
- Decks section: a row per deck with its name and what its plan leaves of today at the day's pace, "≈ 4 min", a check when
  nothing is (`DeckRow`, `DeckMinutes`: the deck's new cards at the new-card price, the others at the other price, whole
  minutes up, "< 1 min", backlog included); no subtitle. Ring and streak cover all decks; decks are rows. Tapping a
  row pushes the deck screen. Swipe and context menu: **Pause Deck** (`pause.circle`); a swipe also offers Remove from
  List where the list may forget the deck.
- **Paused** section at the bottom, only when a deck is paused (Pausing a deck).
- Toolbar, trailing: the **+** menu: Add Cards (into the last used deck, `KnownDecks.last`: studied or added
  to), Import… (into the deck used last), Shared Decks on AnkiWeb, New Deck (into the deck folder; without
  one, into the app's Documents). The **…** menu: Choose Mnemit Folder…, Open Deck…, Settings.
- `.searchable` over every card of every deck (`AllCardsSearch` reads the files of all decks without
  opening them; `CardSearchIndex` also searches the word key); a result pushes `CardDetailScreen` on
  the deck opened by slot.
- Undo of edits: `UndoWatch` (a bar button while there is something to undo) and shake (`StartScreen`,
  when no sheet is open).
- **Empty state** (no decks): the empty hero ring (`HeroRing(progress: nil)`), a line of explanation, **New Deck**
  (`.glassProminent`, large), **Shared Decks on AnkiWeb** (`.glass`, large), at most 320 pt wide, and **Use iCloud Drive
  Folder** as a small text button under them; Open Deck… is in the **…** menu. No mention of the Mac.
- The month's screen (`MonthRecapSheet`) shows once on the first open of a month after a month with
  study; see Progress.
- Frames: `VocTrainTests/HomeSnapshotTests` (directory `TEST_RUNNER_HOME_SHOTS_DIR`).

## Progress (iPhone)

- The hero of Today is a button with a chevron; it pushes `ProgressScreen` (`DeckRoute.progress`, no deck).
  `learning-flow.md` has the contract; everything comes from `DailyProgress.records` and `.achievements`.
- Sections in an inset-grouped list, top to bottom:
  - The streak as a statistic (`StreakStatistic`): the flame, the days large, "day streak", and "Best: 21" only when
    the best run is longer than the current one; under it the totals Days studied, Rings closed, Words learned, three in a
    row (one column at the accessibility sizes), and the line "Your ring: 8 min a day · started at 2.5"
    (`RingSize`; without the start while the ring has not moved). No ring: the day's ring is on Today.
  - The calendar, "Last 13 weeks" once there are 13 and "Calendar" before (`WeeksGrid`): rows of seven
    cells, a row per week, the oldest first, Monday to Sunday under the weekday initials; a day is a ring,
    each day its own share of its goal (`DayRecord.ringShare`): a closed day full, and laps past the goal up to
    three, any other day the share done, none done an empty track, before the first study day nothing; a capsule in `Color.streak` at 18 % lies behind each run of two or more kept days
    (`DayRecord.kept`) within a week row (`WeeksGrid.runs(ofKept:)`); a run does not cross rows.
  - Medals (the latest up to five, newest first, and All Medals).
  - Memory, once a card is started: the line of words in memory (`MemoryEstimate.line`) and the ladder (`LadderBar` and a row
    per step).
  - **How It Works**, the last row, in a section with the footer "The plan, the day's time and the FSRS
    parameters behind the ring."
- All Medals (`MedalsScreen`): one row for the lines of one medal (`AchievementLine.single`), then a row per
  line of tiers (`AchievementLine.tiered`: Streak, Words learned, Double and Triple ring): its earned medals in order, then
  the next as a grey medal without a count of how far there is to go (`NextTier.of`; `ring-design.md`, "Medals and the
  monthly recap"); a line that repeats (perfect week, comeback) is one medal with "×3". The lines are Streak,
  Words learned, Double ring and Triple ring, First ring, Perfect week and Comeback. `Medal` (`Shared/Session`) is
  44 pt, 36 on the rests. Names, faces and symbols are in `Presentation.swift`; no emoji anywhere
  else.
- True retention of the last 30 days is not here: no model computes it across decks, the deck
  statistics do per deck.
- The month's screen (`MonthRecapSheet`) shows once on the first open of a month after a month with
  study: `StartScreen` presents it while idle, `MonthRecapPlan.pending` decides, `UserDefaults` key
  `shownMonthRecap` holds "2026-10". Never in a test run. See All Progress dismisses it and pushes
  Progress.

## Study (the stream)

The stream covers the screen: one stream over every active deck with cards today, each card from the
deck whose next card is most urgent. Study This Deck runs it over one deck. The day's stack ends with
the plan; practices are entries to their own streams, from the deck screen and the Mac's Study menu.
Layout, motion, speech and swipe on the iPhone: `study-screen.md`; the header's, grade area's and rests'
sizes: `design-spec.md` §4.

- Across decks: `StudyRun` opens every active deck, `StudyModel` holds one `SessionDriver` per deck, a
  "lane". Each card comes from the lane whose next card is most urgent: a card in learning, then the
  review with the lowest recall probability, then a new card from the lane that gave fewer new ones.
  The grade goes to the card's deck; Card Info and Undo go to the card's deck too (`stepLanes`
  remembers each step's deck). Rounds count what was done in all lanes
  (`SessionDriver.setDoneElsewhere`); the stopwatch runs only in the lane whose card is on screen.
  Tests: `MultiDeckStudyTests`.
- Header, left, right after the close button: the small ring (`StreamRing`, empty inside), the flame by its state
  and the minutes to the next moment of the day beside them ("≈ 2 min": to the streak, to the ring, of the reviews left;
  none once all is done); after a done card, for 1.5 s, its interval ("tomorrow", "in 8 days") takes the text's
  place. Then an Undo button and the menu "More". A practice names itself and has no ring. Closing loses nothing: every
  grade is saved, and Today picks up the count.
- The menu "More" is one menu on both apps (`StreamMenuItems`): Edit Card, Card Info, Suspend Card, a
  divider, Pronounce Automatically (where the device has a Greek voice). The iPhone adds Undo above them,
  which is also its own button. The items are disabled at a rest, never hidden.
- **A new card's first showing** is asked like any card, with two wide buttons side by side, as tall as the two rows
  they replace: **Don't know** (the grade underneath is Again, red) and **Know** (Good, green); the swipes keep all four
  grades; on the Mac ← and → or the keys 1 and 3 grade the two buttons, and ↓ and ↑ or the keys 2 and 4 still
  give Hard and Easy. On every later showing the four buttons read Forgot, Hard, Good, Easy. The
  receipt chip and its VoiceOver announcement use the same names (`Grade.buttonTitle(isNew:)`). The rules: `scheduling.md`,
  "A new card's first showing".
- The card lies on a stack drawn as a book's page edges, 8 pt apart, each 7 pt narrower on a side and
  darker than the one above; up to four, one fewer than the cards left before the next moment, after the ring too (the
  cards of Catch Up, of Learn 10 New Words, of Study These Now). How cards leave it and come back:
  `learning-flow.md`, "The stack in the stream", and `study-screen.md`, Motion.
- Undo, from the button in the bar, the menu or a shake, takes back the review that ended the round
  and the rest with it; redo brings it back. Card Info (`CardInfoSheet`) shows the same
  `CardDetailScreen`.
- **Study These Now** is a stream over the one deck the cards were added to (`StudyModel.Entry.studyNow`): the added cards
  first, then that deck's plan; its stack, moments and rests are the day's.
- The stream stops at the day's moments, one `StreamRestView`: the ring (96 pt, a picture) with the streak under it
  (the flame and "12-day streak", left out at the streak rest, whose title is the streak, and in a practice), the title, the
  lines, the buttons. The most notable medal earned today shows at 56 pt with its name under it and "+2 more" when there
  were others.
  - *Streak kept* (once a day, after the streak step, inside the plan): the title "12-day streak" with the filled flame
    large beside it, which bursts as the title comes in (a milestone's name replaces the title on a milestone day), the
    medal, the price line of the sentence ("≈ 4 min to close the ring"). **Keep Going** (default, prominent) or **Done for
    Now**. The rest has no card on screen, so nothing is spoken and nothing is graded.
  - *Ring closed* (the end of the stack that closes the goal): the title "Ring closed" ("Streak saved" when the ring saved
    the streak), the medal, the price line "≈ 12 min of reviews left" while cards of the plan are left, the words learned
    ("412 words learned · +12 today"), the rings of the last seven days (`WeekRings`). **Done** (prominent) and **Catch
    Up** while the plan has cards left; with none, **Done** and **Learn 10 New Words**.
  - *All done* (the end of the plan, and the end of any stream that began past the ring's moment, Catch Up, Learn 10 New
    Words and Study These Now included): the title "All done for today"; the same lines. **Done** (prominent) and, while a
    deck has new cards, **Learn 10 New Words** (bordered), ten new cards beyond the limits asked at once, with no rest
    after. On the Mac a rest taller than the window scrolls under the header (`SessionView`).
  - *Practice complete*: its figures (cards, share recalled) and **Done**.
- Frames: `VocTrainTests/StudyScreenSnapshotTests`.

## Media on the card

- The study card (`CardFace`, both apps) shows a side's image above its text: scaled to fit, at most
  40 % of the card's height (`CardFace.maxImageShare`, read by `onGeometryChange`), corner radius 8,
  centred; a side without text shows the image alone. `SideImage` decodes a file once per name
  (`MediaImages`, an `NSCache`). The iPhone stream and the Mac session pass the deck's `DeckMedia`;
  the departing card doesn't, so it leaves without its image. Card Detail shows the image left
  aligned, at most 240 pt.
- `SpeakButton` / `SpokenWord`: a side with a sound the deck holds gets the button whatever its text
  or the voices, and a tap plays the sound (`GreekSpeech.play(sound:of:)`). A side without text shows
  the button alone. The Mac's S key still speaks the Greek text only.
- Browser rows and the Mac table: a side without text shows `MediaPlaceholder` (`photo` or
  `speaker.wave.2` and "Image" or "Sound", secondary colour; the image first) in `SideText`.
- `CardText(question:answer:hint:media:)` lets a side without text through if the card has media on
  that side; both edit sheets pass the card's media. A card with neither text nor media still can't
  be saved.

## How It Works

A sheet from the last row of the Progress screen (`HowTodayWorksSheet`). On the Mac a sheet of the
Progress page (`HowItWorksSheet`), over every deck, each named by its file.

- For the learner who knows Anki and FSRS: after the three sentences, the numbers and rules under the ring
  and the rounds. Read-only: no controls, no charts. A grouped form; each section's footer holds its
  rule.
- **Today**: the three moments in three plain sentences, no figures and an empty footer: the first minutes keep the
  streak, the ring is the goal and Catch Up studies the reviews waiting, nothing due is all done and Learn 10 New Words
  adds ten (`HowTodayWorks.Row.text`).
- **Today's Plan**: due today, overdue included; cards in learning; new cards admitted; each deck's
  admitted cards with its ceiling and limits (new / production), a paused deck as "Paused: <name>" with
  no figures; cards done; cards left.
- **Today's time**: the day's time in minutes (one decimal), the streak step and the daily goal in
  cards; the last 14 days, newest first, with the minutes asked, the minutes worked, the ring (Closed
  or Open) and why the day had its size (Start, Ring closed, Ring open, Plan under the time, Past the ring); the footer adds
  "Going well past the ring on most days lifts it to what you do."
- **Pace**: seconds for a new card and for another card, each with its source (Durations (n), Gaps (n)
  or Default) and the reviews each done card took.
- **Streak**: days, whether today is kept, the cards that would repair yesterday.
- **Words in Memory**: the value to two decimals, at the start of the day, the gain, the next
  milestone.
- **Swipes** (iPhone only): "Swipes that sprang back from a gap: N of M today" (`SwipeTally`,
  `study-screen.md`), with the sectors in compass degrees in the footer.
- **Options**: seven sentences and no footer, one for each option with a rule behind it. A new
  card is asked the first time it comes up (Don't know is the honest answer for a word never seen, and the
  card comes back in the session). Target recall (higher means better recall and more reviews; 90 % is the balance). The
  Meaning → Word unlock rule and one direction of a word per day. The leech rule (a card is suspended after N
  lapses and every further multiple, marked Difficult and resumed from the card list; Off never suspends).
  Learning steps (Good moves a step, Hard keeps it, Forgot resets it, Easy graduates at once). The FSRS
  parameters (they start from averages, are fitted to the deck's log, give fewer reviews for the same recall,
  and keep the due dates). The refit schedule, read from `ParameterRefit`: the first fit at 400 reviews, again at
  1,500, then every 30 days or after 1,000 more; a fit replaces the parameters only if it predicts the newest
  reviews better.
- **FSRS**, one section per deck: target recall, default or fitted parameters with the 21 values
  (monospaced, four decimals, wrapped), the last automatic fit, steps per card, longest interval.
- Code: `HowTodayWorks` (the rows) and `HowTodayWorksView` in `Shared/Statistics`; `DayBreakdown` in
  VocabCore holds what `DailyProgress` does not: the parts of the plan, the decks' shares, the days,
  the base of the pace.

## Deck screen

- A deck row pushes the deck screen onto Today's stack (`DeckScreen`/`DeckContent`; it replaces the
  details sheet). The list opens with one headline (`DeckHeadline`): "≈ 4 min · 14 due · 6 new · 2 learning" (the minutes of what today's
  plan leaves in the deck, backlog included, then Anki's counts, a part of 0 left out), a check and "Done · next review tomorrow" ("Done" when no
  review is coming), or "Paused", which wins over the counts. A deck with no cards, or counts not read yet,
  has no headline.
- Rows: Cards (count) → Card Browser; Statistics; Options. The bottom button is **Study This Deck** while
  the deck has cards in today's plan, else **Learn 10 New Words**: ten new cards of this deck at once.
- Toolbar: **+** (`AddMenu`: Add Cards, Import Cards…; both wait for `isReadyToEdit`) and **…**: Practice
  Newest Words and Practice Today's Mistakes (`DeckPractice`, grey with nothing to practise; practice
  doesn't change when cards come back), a divider, Rename…, **Pause Deck** / **Resume Deck**
  (`pause.circle` / `play.circle`), Export…, Delete Deck (moves the file to the Trash).
- A paused deck still opens: Study This Deck and the rest work, and the counts are those of the deck's
  own limits.
- `PushedDecks` keeps the stack's decks open: it opens one when a route is pushed (`DeckRoute`, the
  deck named by slot, not by file, so a rename doesn't change the route) and closes it when the route
  leaves `path`. Screens above (`CardBrowserScreen`, `CardDetailScreen`, options) show one document.
- Study This Deck runs on the screen's deck (`StudyRun(ownsDeck: false)`: the stream doesn't close it;
  after the stream `undoManager.removeAllActions()`, so the browser's Undo doesn't roll back reviews).
- Rename and Delete close the deck before `DeckFiles.rename`/`trash` and update `KnownDecks`
  (`replace`, `forget`).
- Frames: `VocTrainTests/HomeSnapshotTests` (the deck screen too).

## Card browser

- Pushed from the deck screen. Filters **All · Due · New · Learning · Suspended · Difficult**, the same
  names in both apps. Rules in `CardFilter` (VocabCore: `matches`, `Deck.filterCounts(at:)`): Due, New
  and Learning exclude suspended cards, Difficult includes them; a suspended card is only in All,
  Suspended and, if a leech, Difficult. Titles: `CardFilter.title` in
  `Shared/Support/Presentation.swift`.
- Search (`CardSearchIndex`) looks into `note` too.
- iPhone: a `List` with `.searchable` and the filter row; sort menu `BrowserSort`: Due, Added, A–Z,
  Difficulty; the logic is in `CardBrowserList`, without a screen and with tests. Row: question
  (primary), answer (secondary), trailing state (relative due date / New / Suspended / Difficult).
  Swipe: trailing Delete, Suspend/Resume; context menu: Edit, Speak, Suspend/Resume, Reset Progress,
  Delete. Edit mode: multi-select, then Suspend, Resume, Reset or Delete. Tap pushes Card Detail.
- Mac: a segmented control `ScopeBar` above the table with a count in each segment (it replaces the
  Leeches toggle; `searchScopes` on the Mac live only during a search, and the filters must always be
  visible). Table columns as before plus Kind (Word → Meaning / Meaning → Word, `CardKind.title`); the Kind column sorts by `CardRow.kindRank`. There is no add form above the table: cards come from Add Cards…, and the empty table offers a button for it. The status line under the table says only "N cards", or "M of N cards" while filtered; the counts of the day are in the filter strip above. The
  inspector (View ▸ Show Inspector, ⌥⌘I, or the toolbar's Details button) shows the iPhone's Card Detail sections, kind and word key included, and links to the
  sibling (`Deck.siblings(of:)`).
  The edit sheet (Question, Answer, Hint, Word key) changes the word key through
  `VocabularyDocument.setNote` (`DeckChange.settingNote`, kind stays) and hides it while the session
  still asks the card: the key of a Meaning → Word card is the answer. Keyboard: Delete, ⌘E;
  the window's other keys are under The Mac's window.
- On macOS 27 a click on a `Table` row selects the row but takes no focus (`NSTableView.mouseDown` is
  not called; measured with a live click on 22.10.2026), and the form field stays first responder:
  Delete, ⌘E and the arrows go to it. `TableClickFocus` (the table's background) moves focus into the
  table after a mouse click on it; a selection that changes by itself doesn't touch focus.
- Frames: browser, card and edit in `BrowserSnapshotTests` (`TEST_RUNNER_STUDY_SHOTS_DIR`).

## Card Detail and Edit Card (iPhone)

- **Card Detail** (pushed; the same screen is Card Info in the stream and the Mac inspector's content): both
  sides large, speaker beside the Greek. A Direction row (Word → Meaning / Meaning → Word, `CardKind.title`)
  with the card of the same word the other way round as a link, and "Also in <deck>" when another deck holds
  the word. Memory: one line (`CardMemoryLine`), a dot in the step's colour and the step with when the card
  returns, "Young · next review in 3 days", "Shaky · due now", "New" (the steps: `MaturityCategory.cardTitle`);
  then notes for a suspended or difficult card; then a collapsed **Details**: State, Stability, Difficulty,
  Recall Now, Reviews, Lapses and the Word Key (the Mac also Last Review). History: each review with date and
  the grade's colour and arrow, "Typed" on a typed review of an upstream deck. Toolbar **Edit**; actions:
  Suspend/Resume, Reset Progress, Delete.
- **Edit Card** (sheet): Question, Answer, Hint; Word key under Advanced. Cancel / Save.

## Add Cards, New Deck, Import, Export (iPhone)

- **Add Cards** (sheet), two modes in a segmented control, opened on the mode used last
  (`AddCardsMode`). One Card: Question, Answer, Hint, "Both directions" toggle; **Add** keeps the sheet open
  for the next card and shows the badge "Added · N cards so far"; **Done** adds what is typed and closes;
  Cancel asks before discarding typed text. From a List: paste lines `word = translation`, a live preview of
  the cards, a row per word with a tick (duplicates, and words another deck holds, unchecked; a tap
  switches), Add N Cards. An addition is one undo step ("Add Cards"). Once cards are added the bottom bar holds Add and **Study These Now**
  side by side (one under the other at large text sizes): while something is typed that can be added Add is the prominent
  button, with nothing left to add Study These Now is; it adds what is typed too, closes the sheet and starts the stream
  over the deck with the added cards first. It shows only while the added cards are addable now (`StudyStream.addableCards`:
  new, unlocked, not buried; the second direction of a pair waits for its first). From Today (`AddCardsHost`) the stream starts
  after the sheet has gone and the deck is saved and closed; from the deck screen the sheet's `onDismiss` starts it on the open
  deck. The sheet is the Mac's too
  (`WordList.swift`, `LimitStepper.swift` in `Shared/Support` hold what the two share). On the Mac **Study These Now**
  sits between Add and Done once cards are added, and Done stays the default button (Return): the iPhone's "prominent while
  nothing is left to add" has no counterpart. It adds what is typed, closes the sheet and the deck page starts the stream
  over that deck with the added cards first (`Shell.study(.deck(url), entry: .studyNow(ids))`, from the sheet's `onDismiss`).
- **New Deck**: a name field; creates `<name>.mnemit` in the deck folder (iCloud Drive or this iPhone)
  (`DeckFiles.create(named:in:)`) and pushes its screen, where Add Cards opens by
  itself: the deck screen of an empty deck opens it once.
- **Import**: a file picker (CSV, TSV, `.apkg` or `.colpkg`) → the same preview as the Mac, a list
  with a checkmark per card (duplicates unchecked) → Add N Cards, one undo step. Entry points: Import
  Cards… on the deck screen, Import… in Today's + menu (into the deck used last). The preview of an
  Anki package heads with the Anki deck names, the number of cards, how many have review history and
  what was left out (cloze, media, empty); the history comes along, replayed into FSRS; text fields
  have their HTML stripped. The preview of a table of 1 to 50 cards into a deck that had no card (a new deck) also offers **Study
  These Now**, which adds the checked cards and studies them; a package or a larger table goes to the plan. The Mac's
  preview (`ImportPreviewView`) offers it beside Import under the same rule, counted on the checked cards (1 to 50, a new
  card among them): File ▸ Import Cards… into an empty deck and the import into a new deck. Mnemit registers `.apkg` and `.colpkg`, so **Open in Mnemit** (Files,
  Safari, Mail) opens a sheet that asks where the cards go: a New Deck named after the Anki deck, or
  one of the decks; then the same preview. Facts of the formats: `deck-formats-and-sources.md`.
- "Shared Decks on AnkiWeb" (Today's + menu, Today's empty state, the deck screen) opens the deck
  browser: a sheet with a web view at AnkiWeb's shared decks, Back, Forward, Reload, bookmarks
  (AnkiWeb, MintDeck) and Open in Safari; a link to another host opens in Safari. A `.apkg` the learner
  downloads there goes to the same sheet as "Open in Mnemit"; a `.csv` or `.tsv` goes to the preview
  over the deck used last (a new deck named after the file when there is none). There is no in-app deck
  catalogue: AnkiWeb has no API and its terms allow only browser access. The browser is one the learner
  drives, with no script in its pages and no scraping; the app takes only the file the learner
  downloads.
- **Export**: Export… in the deck screen's menu opens the share sheet with a TSV that Anki imports as
  it is (`#separator` / `#columns` headers, word key and kind columns). The Mac exports the same way.
- Not built: example sentences from Tatoeba's open API (CC BY) in Add Cards and Card Detail.

## Statistics (both apps)

`SummaryTiles` (`Shared/Statistics`): Cards, Due, New, Suspended (only when above 0) and Recall Now, each the
figure of the card filters (`Deck.filterCounts(at:)`; `DeckStatistics.Summary`); the figures scale with Dynamic
Type. The iPhone screen (`StatisticsScreen`, pushed from the deck screen) shows the tiles over the Retention
table: one table, Young / Mature / Total over Today … last 365 days (`TrueRetention.all`). The Mac's deck page
shows its charts beside the tiles under Statistics (⌘4).

## Options

The iPhone's form (`DeckOptionsScreen`) saves every change at once, one undo step each. Top to bottom:
**New Cards** (New cards per day, New card order);
**Scheduling** (Target recall, 70–97 %); **Meaning → Word cards** (New per day, Unlock after N days); Difficult
after N lapses; **Advanced** (Longest interval, Spread out intervals, Steps per card, FSRS parameters with
"Compute from Review Log"). New cards per day, Meaning → Word per day and, on the Mac, Cards per session are
one stepper each (`LimitStepper`): plus past the ceiling (100, 30, 300) shows "Unlimited", minus from it comes
back to the ceiling. Every footer is one sentence.

The Mac's sheet (`DeckOptionsView`) has the same content in one form, plus Cards per session, with Save and
Cancel, and Restore Defaults, which keeps the mark.

## Pausing a deck

- `LearningOptions.isPaused`; the key `paused` in `deck.json` is written only when true, same format
  version: an old build drops the key and the deck is active again. The key travels with the options
  and merges by `learningOptionsChanged`, later wins.
- A paused deck is in none of: plan, goal, rounds, time, allowance (the other decks share it), streak,
  words learned, widget, reminders, Study. `DailyProgress.evaluate` and `DayBreakdown` skip
  `DeckActivity.isPaused` (such a deck's place in `newCardAllowances` holds 0; `DailyRingModel` gives
  it no allowance, and its plan follows its own limits). `KnownDeckCounts` counts no cards for it and
  keeps it in `paused`; `TodayDecks` splits Today's sections and the Study queue (`studyQueue`); its
  stream has no `RoundGuide`.
- The deck still opens: screen, browser and Study This Deck work, and reviews are written as always,
  but they reach the ring only through cards of active decks.
- Today row: swipe and context menu "Pause Deck" / "Resume Deck" (`pause.circle` / `play.circle`;
  `OpenDeck` opens the file, `VocabularyDocument.setPaused` changes it, then it closes). Paused decks
  sit in a "Paused" section at the bottom, grey, without counts or subtitle, swipe and context
  menu Resume Deck; the deck screen menu has the same item. Mac: the sidebar lists a paused deck
  under Paused, grey and without a badge; its row's menu and Study ▸ Pause Deck / Resume Deck pause and resume the
  selected deck.
- "How It Works" names it in the plan with the line "Paused: <name>".
- After resuming, its overdue cards are due like any and come back into the plan, with no special
  rules.

## First launch, deck folder, reminders

- First launch on the iPhone (`OnboardingView`, steps `OnboardingStep`): a welcome with one button → swipe
  practice (`GesturePracticeView`; order and sample cards in `SwipePractice`: ← Forgot, ↑ Remembered
  instantly, ↓ Remembered with effort, → Remembered; the four meanings are the rules, there is no separate
  rules screen; "Skip" leads on) → "One stack a day" (four lines: the stack, the ring, the streak, the
  ladder) → sync (iCloud Drive: folder picker, `chooseFolder`; "Only on This iPhone": `useLocalFolder`,
  the app's Documents folder without bookmark or scope, in Files On My iPhone ▸ Mnemit; with no decks in
  the folder, "Decks in this folder appear here." or "Add decks in Files, under On My iPhone → Mnemit.",
  neither naming the Mac) → reminder.
- **Settings** (a sheet from the **…** menu of Today, `SettingsView`): Reminder (the Daily Reminder toggle
  and, while it is on, the time; its footer appears only when notifications are off in iOS Settings, with
  Open Settings) and Show Introduction, which plays the onboarding again, with "Version 1.2.3 (hash)" under
  it. The Mac's Settings (⌘,, `PreferencesView`): Pronounce Automatically, Mnemit Folder (its path and
  Change…, which opens the folder chooser) and the same version line. The iPhone's "Pronounce
  Automatically" is in the stream's menu.
- A single deck opens through "Open Deck…" in Today's … menu.
- Deck folder. iPhone: `KnownDecks.chooseFolder` (a folder bookmark; its decks are listed;
  `refreshFolder` on pull-to-refresh, on coming to the foreground and every minute while Today is on screen,
  each time asking iCloud Drive for the latest version of every deck (`startDownloadingUbiquitousItem`), so
  reviews saved on the Mac arrive without leaving the app; an empty folder is accepted only
  if named `Mnemit`). Mac: `DeckFolder` (a scoped bookmark, entitlement `bookmarks.app-scope`).
- Reminders: `Reminders`, local notifications 7 days ahead on the days whose decks have cards
  (`StudySession.counts(for:at:)`), in the words of Today (`ReminderPlan.content`): the title "Keep your 12-day streak"
  and the body "≈ 2 min" (the time to keep the streak, not the length of the day); "Start your streak" and "≈ 2 min"
  without a streak; never a count of the cards due. The number on the icon is "1" while today's ring is open and 0 once it
  is closed (`ReminderPlan.badge`; without the ring's figures, 1 while cards are due). Recomputed on going to the background,
  after closing a deck and on a time change.
- Streak reminder: a second notification at 21:00 (`ReminderPlan.streakMinutes`), ids `streak-reminder-0…6`, in
  the first reminder's words (title "Keep your 12-day streak", body "≈ 2 min"), scheduled in the same
  pass for the next seven 21:00s. A streak must be at stake: it is 1 or more and, for today, the streak step is
  not done; for tomorrow, either way (a streak holds through one missed day); for the day after tomorrow, only
  when today's step is done; and the day must have cards. None when the first reminder's time is at or after
  21:00. The app withdraws today's when the streak step turns done (`StartScreen` reschedules when
  `ring.progress.streakKeptToday` becomes true), on becoming active and on every refresh; each pass starts by
  removing both sets of ids. Daily Reminder off removes both. There is no setting for the second. The badge is
  the one above and rides on this request too.

## Widget

- Target `MnemitWidget`, folder `MnemitWidget/`, bundle id `com.euf.mnemit.ios.widget`, embedded in the
  iPhone app. Home screen small and medium, lock screen circular, rectangular and inline; a tap goes through
  `mnemit://study` straight into the stream (`StartScreen.open`).
- Every widget is two things: the day's ring as a picture (the arc and its laps, nothing in its middle) and the sentence
  of Today (`NextStep`), led by the flame, whose shape is the streak's state. No widget has a button, a capsule or a card
  count; the whole widget opens the stream. VoiceOver reads each widget as one element, the sentence with the state.
  - Small: the ring (72 pt) and the sentence under it (caption, centred, up to three lines for the at-risk sentence).
  - Medium: the ring (104 pt) at the left; at the right the sentence as the headline (up to three lines) at the ring's
    top and the week's rings (18 pt, no initials) at its bottom.
  - Circular: the system gauge, in its middle the minutes of the next step ("2" over a small "min", "<1"), a `checkmark`
    once the ring is closed, nothing without a price.
  - Rectangular (lock screen): the ring (56 pt) and the sentence (caption, up to three lines).
  - Inline (`accessoryInline`, over the lock screen's clock): the flame and the short form of the sentence, "12 · ≈ 2 min",
    "12 · Done" when nothing is left, the days alone without a price; with no streak the sentence, with no flame. Before the
    first snapshot: "Open Mnemit to start".
- Data travels as one snapshot `WidgetSnapshot` (`Shared/Widget`): date, done cards and the day's
  goal, streak and whether the ring is closed, whether the streak is at risk (`isStreakAtRisk`), the week
  (`week`: seven entries, today last, true a closed ring, false an open one, null before the first study day; `weekRings`: the
  share of each day's goal, which the widget's week draws),
  rounds (`rounds`, `roundsDone`, `minutesToNextRound`), the price of a card left (`secondsPerCard`; the
  forecast holds only card counts per hour, so the snapshot keeps one price), a forecast of how many cards are
  in the plan for each hour 48 hours ahead across all decks, and the time of the next reminder
  (`Reminders.nextFire`). `isStreakAtRisk` and `week` are optional and left out of the JSON when nil: an older
  snapshot decodes as not at risk with no week, and an older widget ignores the keys. `wordsInMemory` and
  `wordsToday` are still in the snapshot; the widget shows neither.
- The app writes its JSON into a keychain item of the shared group
  `$(AppIdentifierPrefix)com.euf.mnemit.shared` (`KeychainSnapshotStore`, `AfterFirstUnlock`). There
  are no App Groups: the free Personal Team gives only keychain sharing. One
  `VocTrain/Mnemit.entitlements` is the `CODE_SIGN_ENTITLEMENTS` of both app and widget, and the
  iPhone signing script must sign both bundles with it. The team prefix is never written in code: it is
  read from the group the keychain puts an item without a group into.
- `WidgetSync` writes the snapshot (after a review, at launch, on a change of decks or reminder, at
  once on going to the background; a 2 s pause glues a series of reviews together), then
  `reloadAllTimelines()`; under tests it is off.
- The timeline (`WidgetSnapshot.timeline`) puts entries at the forecast hours, at the start of the
  next study day (4:00, not midnight: the ring resets then) and at the reminder time. While the
  snapshot isn't updated, `WidgetSnapshot.state(at:)` works out the later days: the week moves (the snapshot
  day's ring as it ended, a missed day is an open ring, today is closed only for an empty plan), and the streak
  is at risk when exactly one day was missed, the plan has cards and the streak is above 0. A day whose first
  round was done (`isStreakKept`) is no missed day, whatever its ring did.
- The widget target builds all of `Shared` (that's where `DailyRingView`, everything it needs and the
  string catalog live): a new file in `Shared` with nothing to do in an extension
  (`UIApplication.shared`) must be excluded from its membership.
- Frames: `VocTrainTests/WidgetShotsTests` (`TEST_RUNNER_STUDY_SHOTS_DIR`).
- `PRODUCT_BUNDLE_IDENTIFIER=…` on the `xcodebuild` command line overrides the widget's bundle id too.

## iPhone and Mac

What the two apps share, and where they differ on purpose. The day is the same on both: one ring, the streak and
the words over every deck of the Mnemit folder (`DailyRingModel`, the iPhone over `KnownDecks`, the Mac over
`AllDecks`).

| | iPhone | Mac |
|---|---|---|
| Today | the root screen | the Today page of the window |
| The day's button | Study / Catch Up / Learn 10 New Words | the same |
| Study over several decks | one stream mixes the decks (`StudyModel`) | the same `StudyModel`: Today's button opens the decks of the day and mixes them in one stream over the window |
| The stream | swipes, the stack, the ring travelling to the rests | keys and buttons, the stack, the rests |
| Progress, medals, How It Works | pushed from Today | the Progress page; How It Works is a sheet of it |
| A deck | the deck screen | the deck's page: the strip, Cards \| Statistics |
| Cards | the browser, Card Detail, Edit Card | the table, the inspector, the edit sheet; multi-select, keyboard |
| Adding | Add Cards: One Card, From a List | the same sheet: Study ▸ Add Cards… (⇧⌘L), the toolbar button, the empty table's button |
| Import, export, AnkiWeb | yes | yes |
| A deck from Today | swipe and menu: Pause Deck | the sidebar row's menu: Study This Deck, Pause Deck, Show in Finder, Rename…, Delete Deck |
| Search over all decks | Today's search | the window's search field; a hit shows the card in its deck's table |
| Medals | toasts in the stream, new medals of other days on Today, the month's sheet | the same |
| Studying | question, Show Answer, grade; swipes | question, Show Answer, grade; keys and buttons; no typed answer on either |
| A new card's first showing | asked like any card; two wide buttons, Don't know and Know | the same, each with its arrow as a keycap (← and →); keys 1 and 3; 2 and 4 and ↓ ↑ grade Hard and Easy |
| Study These Now | Add Cards; the import of a table of 1 to 50 cards into an empty deck | the same two places; File ▸ Import Cards… into an empty deck and the import into a new deck both reach it |
| Deck rows, deck header | "≈ 4 min" or a check; header "≈ 4 min · 14 due · 6 new · 2 learning" | the sidebar's badges and the deck page's strip say the same |
| Reminders, the icon's number | yes | no: one device reminds, the Mac would remind twice |
| Widget | yes | no: a Mac widget needs an App Group, which the self-signed Mac app has no team for |

## The Mac's window

One window, `Window("Mnemit", id: "shell")` (`MacVocTrainApp.shellID`; `ShellView` over `Shell.shared`, in
`MacVocTrainNg/Shell/`), titled by its page ("Today", "Progress", the deck's name), at least 760 x 520 pt. It opens
on Today at launch and takes the app's indigo as its tint (`brandTint()`). ⌘W closes it and the app runs on
(`applicationShouldTerminateAfterLastWindowClosed` is false); a click on the Dock icon, a file from Finder or any
menu item brings it back (`Shell.showWindow`, `applicationShouldHandleReopen`); ⌘Q saves and closes every deck
first (`applicationShouldTerminate` replies once `Shell.closeAll()` is done). Settings (⌘,) is the one other
window. `Support/` holds `DeckFolder`, `DeckWebWindow` and `HowTodayWorksLoader`.

- **Sidebar** (`SidebarContent`, 200 to 320 pt): Today with the plan left of the day as its badge, Progress, then
  the sections Decks, Paused and Other Decks. A badge (`SidebarBadge`) is the iPhone's deck row: "≈ 4 min" (`DailyGoal.minutesLeft`:
  the plan left in the deck at the day's pace, "< 1 min" under a minute) or a check once nothing is left. Today's
  badge prices the plan of all the decks of the day as one (the new cards at their price, the rest at theirs), so it can
  differ from the sum of the decks' rounded minutes. A paused deck, a deck not read yet and every row before the ring is
  worked out have no badge; VoiceOver says "Done" for the check. Decks lists the folder's decks that take part in the day, Paused the paused ones, Other
  Decks the decks opened from outside the Mnemit folder (Finder, Open Deck…) until the app quits; a deck of the
  folder is never listed there. A deck row's menu: Study This Deck, Pause Deck / Resume Deck, Show in Finder,
  Rename…, Delete Deck; Rename and Delete are only there. Rename is a sheet and selects the deck under its new
  name (a taken name leaves it as it was); Delete asks once, moves the file to the Trash and shows Today. The
  (+) menu under the list: New Deck…, Open Deck…, Shared Decks on AnkiWeb…, Choose Mnemit Folder….
- **Search All Cards** (`AllCardsSearch`) is the toolbar's search field, over every deck, on Today, Progress and
  a deck's Statistics (a deck's Cards has its own field). Hits list the card with its deck; a click shows the
  card selected in its deck's table (`Shell.showCard`).
- **Today page** (`TodayPageContent`): the iPhone's hero (`TodayHero` at 200 pt: the ring without a number, the
  sentence, "412 words learned · +12 today", the week of rings) as a button to Progress, and the day's one button under
  it, `DayAction` (Study in the accent, Catch Up or Learn 10 New Words grey; extra large, the default action; also in
  the toolbar). Without a deck: the empty ring, one line, **New Deck** (prominent), **Shared Decks on AnkiWeb…**
  (bordered) and **Use iCloud Drive Folder** as a footnote-size link under them. The medals of earlier days this Mac never
  celebrated come once as toasts, and the month's sheet (`MonthRecapSheet`) shows on the first open of a month,
  its See All Progress opening Progress. The window reads the folder again when it becomes key and every minute.
- **Progress page** (`ProgressPage`): the iPhone's `ProgressScreen` over every deck (the totals Days studied, Rings
  closed, Words learned; "Your ring: 8 min a day · started at 2.5"; the words in memory in the Memory section), with How It Works as a
  sheet (`HowItWorksSheet`, 520 x 640, Done).
- **A deck's page** (`DeckPage`, `DeckPageContent`): the strip, then the Cards table or the Statistics. The
  strip holds the deck's headline (`DeckHeadline`, priced at the day's pace as the iPhone's deck screen is: "≈ 4 min ·
  14 due · 6 new · 2 learning" with zero parts left out and the time left out until the ring is worked out; or a check and
  "Done · next review tomorrow"; or "Paused") and its one button, **Study This Deck** while the plan has cards left in it, else **Learn 10 New
  Words** (grey). Toolbar: the segmented Cards | Statistics in the middle, Add Cards and Learning Options, and on
  Cards the Details button. Sheets: Learning Options, Add Cards and the
  preview of an import, the two that offer Study These Now (a stream over the deck once the sheet has gone); an empty deck opens Add Cards by itself, once. A deck still being read shows a spinner,
  one that cannot be opened says why. An error of a deck (autosave, read) is a sheet of the window, never
  app-modal. Cards, filters, inspector and edit sheet: Card browser.
- **The stream** (`SessionView`) takes the whole window: the sidebar goes (`columnVisibility = .detailOnly`, the
  toggle removed) and Done gives it back in the state it had; the selection cannot change meanwhile. It is one
  stream over the decks of the day (the day's button, ⌘L) or over one deck (Study This Deck, ⌥⌘L, the sidebar
  menu, the practices). The decks of a run stay open until the app quits, the deck studied last first
  (`StudyRun` with `open`).
- **Files**: a deck from Finder or Open Deck… is selected; inside the Mnemit folder it is listed there, outside it
  sits under Other Decks. An `.apkg` or a table from Finder, the AnkiWeb window or Import Cards… with no deck
  selected makes a new deck named after the Anki deck or the file, numbered if taken, and shows the preview of its
  cards (`Shell.importIntoNewDeck`). Import Cards… with a deck selected imports into it.
- **Undo**: `UndoRouter` (`WindowUndoRouting.swift`), a responder in the window's chain, answers Edit ▸ Undo
  and Redo with the undo manager of the deck the window shows; Today, Progress and the stream have none. A deck's
  steps survive a switch to another page and back.
- **Menus** (`AppCommands`; the items read `Shell.menu`, a `MenuState`). In a stream every item but Help is off.
  - File: New Deck… ⌘N, Open Deck… ⌘O, Import Cards… ⇧⌘I, Shared Decks on AnkiWeb…, Export Deck…, Show in Finder
    (the last two need a read deck).
  - Study: the day's action ⌘L (Study, Catch Up or Learn 10 New Words, from any page), Study This Deck ⌥⌘L, Add
    Cards… ⇧⌘L, Practice Newest Words, Practice Today's Mistakes, Pause Deck / Resume Deck, Learning Options… ⌘;.
  - View: Today ⌘1, Progress ⌘2, Cards ⌘3, Statistics ⌘4 (the last two need a selected deck), Show Inspector / Hide
    Inspector ⌥⌘I (only on a deck's Cards), then the system's sidebar items.
  - Help: Keyboard Shortcuts, always on. `MenuKey` is the one table (shortcut, caps, title) that the menus and
    the cheat sheet (`ShortcutsHelp`) share; the sheet lists its twelve rows outside a stream and the five keys of
    the stream (Space, arrows, Z or Esc, S, ?) in one. In a stream the sheet names the grades of the card on screen
    (`MenuState.onNewCard`): on a first showing "Show the answer, then grade Know" and "Grade: ← Don't know, → Know,
    ↑ Easy, ↓ Hard", on later showings "… grade Good" and "← Forgot, → Good, ↑ Easy, ↓ Hard". "?" opens it in a stream
    only, and it comes up by itself in the first stream. Study's first item reads Study, Catch Up or Learn 10 New
    Words by `DayAction` (`MenuKey.studyDay.title`).
- The Mac's day counts `AllDecks`: the open decks and the rest of the Mnemit folder. The ring in the stream's
  header, Today, Progress and How It Works all count them.
- **The Mac's stream** (`SessionView`) looks as the iPhone's does: the card on the grouped backdrop
  (`Color.studyBackdrop`, the card `Color.cardSurface`) over the stack's edges (`StackEdges`, the cards left before the
  next moment, at most four, after the ring too: the cards of Catch Up, of Learn 10 New Words and of Study These Now;
  `StackPose` in `Shared/Session/CardStackEdges.swift`); the bar with Done and, right
  after it, the day's ring (empty inside), the streak's flame and the minutes to the next moment of the day as the iPhone's
  bar says them (`NextStep`: "≈ 4 min"; none once all is done), then Undo and the menu "More" (`StreamMenuItems`, the iPhone's: Edit Card, Card Info, Suspend Card, Pronounce
  Automatically, disabled at a rest); Show Answer prominent in indigo with a keycap "Space or ↩". The bar of
  the last answer (`UndoChip`) stays under the header. The rests are the iPhone's `StreamRestView`, titles included
  ("Ring closed", "All done for today").
  - Keys: Space or Return show the answer; then ← Forgot, ↓ Hard, → Good, ↑ Easy (the iPhone's swipes;
    `Grade.arrowKey`), 1–4 also grade, Return and Space mean Good, Esc, Z and ⌘Z undo, S pronounces, ⌘E edits
    the card. Every grade button shows its arrow as a keycap (`KeyCap`); the ring on Good marks Return. Done
    has no shortcut.
  - A card on its first showing has the iPhone's two wide buttons, **Don't know** (←, key 1) and **Know** (→, key 3),
    each with its arrow keycap; Return and Space mean Know; ↓ and 2 give Hard, ↑ and 4 give Easy.
  - Edit Card opens `CardEditSheet`; Card Info a sheet with the card list's inspector
    (`MacVocTrainNg/Views/Session/CardInfoSheet.swift`), whose Edit swaps it for the edit sheet.
  - At the end of a deck's plan, while another deck of the day has cards left, the rest's first button is
    "Study Greek B1 · 14 cards" (`NextDeck`): it ends this stream and starts that deck's, the sidebar still
    away; a stream from Today mixes the decks of the day from the start.
- The Mac's stream is the iPhone's `StudyModel` (`Shared/Session`) under `SessionViewModel`, whose stages are
  asking, revealed and resting: `Shell.study` opens the decks of the run, the stream starts once every deck
  is read, each card comes from the deck whose next card is most urgent, and Undo (Z, Esc, ⌘Z) takes back the
  last step in its own deck. Medals earned by a grade come as toasts under the bar (`MedalToasts`).
