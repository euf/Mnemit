# Screens of both apps: what each shows and does

The contract of every screen of Mnemit on the iPhone and the Mac, with the code that holds it. The
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
  - The ring (`StreakHeroRing`, 168 pt) with the flame in the middle and the streak's days under it, "day
    streak" in caption; at 0 days the outlined flame and "Start your streak". The flame has three states
    (`StreakState`): a grey outline until the streak step is done, filled in `Color.streak` once it is, an
    orange outline at risk (`DailyProgress.isStreakAtRisk`: the day after a missed day, ring open).
    VoiceOver says the state: "12-day streak, kept today", "not kept yet", "at risk".
  - One headline for the state of the day (`TodayHeadline.text`): "≈ 2 min to keep your streak" before the
    streak step, then "20 cards left · ≈ 5 min", "Ring closed · 3 left", "All done", "Nothing due · next
    tomorrow", and the day after a missed one "Close the ring to save your 12-day streak". Rounds never
    show by number.
  - One gain line (`MemoryLine`): "412 words in memory · +15 today"; on the day a milestone is passed
    "50 words in memory!". At large text sizes the single text wraps.
  - The week's seven rings (`WeekRings`, 22 pt), with a chevron at the end of the row.
  - The day turns at 04:00, and work done just before it, on either device, belongs to the day before.
    The headline waits for every deck to be read and the ring to be evaluated (`isDayReady`); until then the
    hero shows placeholders. The ring's middle stops growing at xxxLarge and scales down; at AX5 the headline
    wraps and the list scrolls.
- The bottom bar holds the day's one button beside Search All Cards, which is minimised to a button
  (`.searchToolbarBehavior(.minimize)`). The button is named by `DayAction`
  (`Shared/Session/TodaySummary.swift`): **Study** in the accent while the ring is open; **Catch Up** once the
  ring is closed and the plan has cards left; **Learn 10 New Words** once the plan is done, with no footnote.
  Study and Catch Up open the stream over the screen (`StudyRunView`) over every active deck. Learn 10 New
  Words opens it with ten new cards at once over every active deck (`StudyModel.Entry.pushOn`), without the
  plan-end rest first. With every deck paused the button is disabled.
- Decks section: a row per deck with its name and the cards of today's plan left in it, a check when none
  (`StudyCounts.total`); no subtitle. Ring and streak cover all decks; decks are rows. Tapping a row pushes
  the deck screen. Swipe and context menu: **Pause Deck** (`pause.circle`); a swipe also offers Remove from
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
- **Empty state** (no decks): the empty hero ring ("Start your streak"), a line of explanation, **New Deck**
  (`.glassProminent`, large) and **Use iCloud Drive Folder** (`.glass`, large), at most 320 pt wide, with
  Shared Decks on AnkiWeb as a link under them; Open Deck… is in the **…** menu. No mention of the Mac.
- The month's screen (`MonthRecapSheet`) shows once on the first open of a month after a month with
  study; see Progress.
- Frames: `VocTrainTests/HomeSnapshotTests` (directory `TEST_RUNNER_HOME_SHOTS_DIR`).

## Progress (iPhone)

- The hero of Today is a button with a chevron; it pushes `ProgressScreen` (`DeckRoute.progress`, no deck).
  `learning-flow.md` has the contract; everything comes from `DailyProgress.records` and `.achievements`.
- Sections in an inset-grouped list, top to bottom:
  - The hero: `StreakHeroRing` at 220 pt (the flame and the days in it) with `MemoryLine` under it, one
    element for VoiceOver; the totals Longest streak, Rings closed, Days studied, Cards done, two by two.
    The hero has no headline and no week: Today has them.
  - The calendar, "Last 13 weeks" once there are 13 and "Calendar" before (`WeeksGrid`): rows of seven
    cells, a row per week, the oldest first, Monday to Sunday under the weekday initials; a day is a ring,
    closed full, kept at its share of the goal, a missed day an empty track, before the first study day
    nothing; a capsule in `Color.streak` at 18 % lies behind each run of two or more kept days
    (`DayRecord.kept`) within a week row (`WeeksGrid.runs(ofKept:)`); a run does not cross rows.
  - Medals (the latest up to five, newest first, and All Medals).
  - Memory (`LadderBar` and a row per step), once a card is started.
  - **How It Works**, the last row, in a section with the footer "The plan, the day's time and the FSRS
    parameters behind the ring."
- All Medals (`MedalsScreen`): one row for the lines of one medal (`AchievementLine.single`), then a row per
  line of tiers (`AchievementLine.tiered`): its earned medals in order, then the next as a grey medal without a count of how far there is to go (`NextTier.of`, the best day on record
  for the big day; `ring-design.md`, "Medals and the monthly recap"); a
  line that repeats (perfect week, comeback) is one medal with "×3". The lines are Streak, First ring,
  Perfect week, Big day and Comeback. `Medal` (`Shared/Session`) is
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
- Header: the close button, the small ring (`StreamRing`) with the streak's flame alone in its middle (an
  outline until the streak step is done, filled from then on; the ring bumps and bursts when it fills) and
  "≈ 4 min" beside it while the goal is open (after a done card, for 1.5 s, its interval: "tomorrow", "in 8
  days"), "36 cards today" once the goal is met, an Undo button, the menu "More". A practice names itself
  and has no ring. Closing loses nothing: every grade is saved, and Today picks up the count.
- The menu "More" is one menu on both apps (`StreamMenuItems`): Edit Card, Card Info, Suspend Card, a
  divider, Pronounce Automatically (where the device has a Greek voice). The iPhone adds Undo above them,
  which is also its own button. The items are disabled at a rest, never hidden.
- **A new word** (an introduction: the first showing of a card never seen in a deck marked New words, see
  Options): the answer is open, the corner chip says "New word", there are no grade buttons, and **Next**
  stands in Show Answer's place. A tap, Next or a swipe in any direction moves on and grades nothing: the
  ring does not step, no interval shows, Undo stays with the last graded card. The card comes back as an
  ordinary question three cards later. Gesture and motion: `study-screen.md`, "A new word"; the rules:
  `scheduling.md`, "Introductions".
- The card lies on a stack drawn as a book's page edges, 10 pt apart, each 9 pt narrower on a side and
  darker than the one above; how cards leave it and come back: `learning-flow.md`, "The stack", and
  `study-screen.md`, Motion.
- Undo, from the button in the bar, the menu or a shake, takes back the review that ended the round
  and the rest with it; redo brings it back. Card Info (`CardInfoSheet`) shows the same
  `CardDetailScreen`.
- The stream stops at four rests, one `StreamRestView`; the model is in `learning-flow.md`. Both rests of a
  round show the most notable medal earned today at 56 pt, with its name under it and "+2 more" when there
  were others.
  - *Streak kept* (once a day, after the streak step, inside the plan): the ring, the title "12-day streak"
    with the filled flame large beside it (a milestone's name replaces the title on a milestone day), the
    medal, the cards left to the ring with their time. **Keep Going** (default, prominent) or **Done for
    Now**. The rest has no card on screen, so nothing is spoken and nothing is graded.
  - *Ring closed* (the end of the last round while the plan has cards beyond it): the title "Ring closed"
    ("Streak saved" when the ring saved the streak), the medal, one line (the words' milestone, else the
    words gained, else "10 cards today"), the rings of the last seven days (`WeekRings`). **Done**
    (prominent) and **Catch Up**.
  - The end of the plan: "Ring closed", or "Done for today" when the plan ran out with the ring open; the
    same lines. **Done** (prominent) and, while a deck has new cards, **Learn 10 New Words** (bordered).
    It adds ten new cards beyond the limits and asks them at once, with no rest after; it is the only way
    past the end of the plan, and Today's button of that name opens the stream with them directly. On the
    Mac a rest taller than the window scrolls under the header (`SessionView`).
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

A sheet from the last row of the Progress screen (`HowTodayWorksSheet`). On the Mac
the window of Study ▸ How It Works, over the open decks, which it names Deck 1, Deck 2.

- For the learner who knows Anki and FSRS: after the three sentences, the numbers and rules under the ring
  and the rounds. Read-only: no controls, no charts. A grouped form; each section's footer holds its
  rule.
- **Today**: three plain sentences, no figures and an empty footer: what the ring is, what Catch Up does,
  what Learn 10 New Words does (`HowTodayWorks.Row.text`).
- **Today's Plan**: due today, overdue included; cards in learning; new cards admitted; each deck's
  admitted cards with its ceiling and limits (new / production), a paused deck as "Paused: <name>" with
  no figures; cards done; cards left.
- **Today's time**: the day's time in minutes (one decimal), the streak step and the daily goal in
  cards; the last 14 days, newest first, with the minutes asked, the minutes worked, the ring (Closed
  or Open) and why the day had its size (Start, Ring closed, Ring open, Plan under the time).
- **Pace**: seconds for a new card and for another card, each with its source (Durations (n), Gaps (n)
  or Default) and the reviews each done card took.
- **Streak**: days, whether today is kept, the cards that would repair yesterday.
- **Words in Memory**: the value to two decimals, at the start of the day, the gain, the next
  milestone.
- **Swipes** (iPhone only): "Swipes that sprang back from a gap: N of M today" (`SwipeTally`,
  `study-screen.md`), with the sectors in compass degrees in the footer.
- **FSRS**, one section per deck: target recall, default or fitted parameters with the 21 values
  (monospaced, four decimals, wrapped), the last automatic fit, steps per card, longest interval.
- Code: `HowTodayWorks` (the rows) and `HowTodayWorksView` in `Shared/Statistics`; `DayBreakdown` in
  VocabCore holds what `DailyProgress` does not: the parts of the plan, the decks' shares, the days,
  the base of the pace.

## Deck screen

- A deck row pushes the deck screen onto Today's stack (`DeckScreen`/`DeckContent`; it replaces the
  details sheet). The list opens with one headline (`DeckHeadline`): "14 cards today" (what today's plan
  takes from the deck, `StudyCounts.total`), a check and "Done · next review tomorrow" ("Done" when no
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
  inspector shows the iPhone's Card Detail sections, kind and word key included, and links to the
  sibling (`Deck.siblings(of:)`).
  The edit sheet (Question, Answer, Hint, Word key) changes the word key through
  `VocabularyDocument.setNote` (`DeckChange.settingNote`, kind stays) and hides it while the session
  still asks the card: the key of a Meaning → Word card is the answer. Keyboard: Delete, ⌘E,
  ⌘L, ⌘1/⌘2/⌘3 (Overview, Cards, Statistics), Space/arrows in the stream.
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
  switches), Add N Cards. An addition is one undo step ("Add Cards"). The sheet is the Mac's too
  (`WordList.swift`, `LimitStepper.swift` in `Shared/Support` hold what the two share).
- **New Deck**: a name field and **Words in this deck** (New words to begin with, see Options); creates
  `<name>.mnemit` in the deck folder (iCloud Drive or this iPhone) with the mark
  (`DeckFiles.create(named:introducesNewCards:in:)`) and pushes its screen, where Add Cards opens by
  itself: the deck screen of an empty deck opens it once.
- **Import**: a file picker (CSV, TSV, `.apkg` or `.colpkg`) → the same preview as the Mac, a list
  with a checkmark per card (duplicates unchecked) → Add N Cards, one undo step. Entry points: Import
  Cards… on the deck screen, Import… in Today's + menu (into the deck used last). The preview of an
  Anki package into a new deck asks "Words in this deck" first, preset to Words I know when any card has review
  history, else New words (`CardImport.Preview.makesDeck`); an import into an existing deck asks nothing and
  keeps its mark. The preview of an Anki package heads with the Anki deck names, the number of cards, how many have review history and
  what was left out (cloze, media, empty); the history comes along, replayed into FSRS; text fields
  have their HTML stripped. Mnemit registers `.apkg` and `.colpkg`, so **Open in Mnemit** (Files,
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
table: one table, Young / Mature / Total over Today … last 365 days (`TrueRetention.all`). The Mac keeps
its charts beside the tiles.

## Options

The iPhone's form (`DeckOptionsScreen`) saves every change at once, one undo step each. Top to bottom:
**Words in this deck** (an inline picker, New words / Words I know: `LearningOptions.introducesNewCards`;
New words introduce each new card before it is asked); **New Cards** (New cards per day, New card order);
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
  words in memory, widget, reminders, Study. `DailyProgress.evaluate` and `DayBreakdown` skip
  `DeckActivity.isPaused` (such a deck's place in `newCardAllowances` holds 0; `DailyRingModel` gives
  it no allowance, and its plan follows its own limits). `KnownDeckCounts` counts no cards for it and
  keeps it in `paused`; `TodayDecks` splits Today's sections and the Study queue (`studyQueue`); its
  stream has no `RoundGuide`.
- The deck still opens: screen, browser and Study This Deck work, and reviews are written as always,
  but they reach the ring only through cards of active decks.
- Today row: swipe and context menu "Pause Deck" / "Resume Deck" (`pause.circle` / `play.circle`;
  `OpenDeck` opens the file, `VocabularyDocument.setPaused` changes it, then it closes). Paused decks
  sit in a "Paused" section at the bottom, grey, without counts or subtitle, swipe and context
  menu Resume Deck; the deck screen menu has the same item. Mac: Study ▸ Pause Deck / Resume Deck
  pauses the deck of the window; the ring in the toolbar and its help count the decks of the Mnemit folder that
  aren't paused.
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
  (`StudySession.counts(for:at:)`), in the words of Today (`ReminderPlan.content`): "Keep your 12-day
  streak" and "≈ 2 min is enough." for the next two days, "Time to study" and "≈ 2 min is enough to start."
  without a streak or further ahead; never a count of the cards due. The number on the icon is the cards
  left to close today's ring, 0 once it is closed (`ReminderPlan.badge`); a later day's is that day's
  cards up to today's goal. Recomputed on going to the background, after closing a deck and on a time
  change.

## Widget

- Target `MnemitWidget`, folder `MnemitWidget/`, bundle id `com.euf.mnemit.ios.widget`, embedded in the
  iPhone app. Home screen small and medium, lock screen circular and rectangular; a tap goes through
  `mnemit://study` straight into the stream (`StartScreen.open`).
- It says what Today says, with the streak as the flame in the middle of every ring:
  - Small: the ring, the headline under it (two lines where it doesn't fit) and the "N cards today" line
    once the ring is closed.
  - Medium: the ring, the headline, the "N cards today" line once the ring is closed, "≈ 28 words in
    memory", and a Study button while
    the ring is open; once it is closed the headline has the width. It has no streak line and no
    reminder line.
  - Circular: the ring (`DailyRingView`, 58 pt) with the streak in its middle: the flame over the days,
    filled in the streak's orange once the day's streak step is done, a grey outline before. The cards left
    are never in the middle (the headline stays the VoiceOver label); at 0 days the ring is empty.
  - Rectangular (lock screen): the headline, the "N cards today" line once the ring is closed, and the
    streak line with the flame, in the streak's orange once the day keeps it. The widget has no at-risk state: its snapshot carries no
    repair cards, so the flame is open or kept.
  Where the rounds are not known (an older app's snapshot) "N cards left" carries "· ≈ 7 min" after
  it.
- Data travels as one snapshot `WidgetSnapshot` (`Shared/Widget`): date, done cards and the day's
  goal, streak and whether the ring is closed, rounds (`rounds`, `roundsDone`, `minutesToNextRound`),
  words in memory (`wordsInMemory`, `wordsToday`; optional fields, an old app's snapshot still reads
  and shows "N cards left"), the price of a card left (`secondsPerCard`; the forecast holds only card
  counts per hour, so the snapshot keeps one price), a forecast of how many cards are in the plan for
  each hour 48 hours ahead across all decks, and the time of the next reminder (`Reminders.nextFire`).
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
  snapshot isn't updated, the streak holds through one missed day.
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
| Today | the root screen | the Today window |
| The day's button | Study / Catch Up / Learn 10 New Words | the same |
| Study over several decks | one stream mixes the decks (`StudyModel`) | the same `StudyModel`: Today opens the decks of the day and mixes them in the window of the deck used last |
| The stream | swipes, the stack, the ring travelling to the rests | keys and buttons, the stack, the rests |
| Progress, medals, How It Works | pushed from Today | windows |
| A deck | the deck screen | the deck window's Overview |
| Cards | the browser, Card Detail, Edit Card | the table, the inspector, the edit sheet; multi-select, keyboard |
| Adding | Add Cards: One Card, From a List | the same sheet: File ▸ Add Cards… (⇧⌘L), the toolbar button, the empty table's button |
| Import, export, AnkiWeb | yes | yes |
| A deck from Today | swipe and menu: Pause Deck | menu: Study This Deck, Pause Deck, Show in Finder |
| Search over all decks | Today's search | the Today window's search; a hit shows the card in its deck's table |
| Medals | toasts in the stream, new medals of other days on Today, the month's sheet | the same |
| Studying | question, Show Answer, grade; swipes | question, Show Answer, grade; keys and buttons; no typed answer on either |
| A new word | introduction: the answer open, Next, swipe any way | introduction: Next, Space, Return, an arrow or a click |
| Reminders, the icon's number | yes | no: one device reminds, the Mac would remind twice |
| Widget | yes | no: a Mac widget needs an App Group, which the self-signed Mac app has no team for |

## Mac windows

- **Today window** is the Mac's Today (`WelcomeWindow`, content `WelcomeView` → `TodayWindowContent`;
  window title "Today", Window ▸ Today ⌘0; shown at launch while no document is open, and by a click on
  the Dock icon then; to turn it off: `defaults write <bundle id> showsWelcomeWindow -bool NO`). It
  stays open beside the deck windows; like every Mac window it takes the app's indigo as its tint
  (`brandTint()`), whatever the system accent. Above the decks, Search All Cards (`AllCardsSearch`, as on the iPhone): a hit opens its deck
  on Cards with the card selected and the inspector shown (`WelcomeRequest.requestCard(_:of:)`). A deck row's menu:
  Study This Deck, Pause Deck or Resume Deck (`WelcomeRequest.requestPause(of:isPaused:)`, through the deck's
  document), Show in Finder. The medals of earlier days this Mac never celebrated come once as toasts, and the
  month's sheet (`MonthRecapSheet`) shows on the first open of a month, its See All Progress opening Progress. Left: `SummaryRow` (the same view as the iPhone's Today header,
  ring 80 pt, a button with a chevron that opens Progress), the `DayAction` button (extra large, the default action) and the links Choose Mnemit
  Folder…, New Deck, Import Cards…, Open Deck…, Shared Decks on AnkiWeb…. Right: the decks of the Mnemit folder
  with what today's plan takes from each (`StudyCounts.parts`, else "Next review …", "Paused" for a
  paused deck) and the cards left or a checkmark; Recent Decks below. Before the folder is chosen: the
  icon, the name, the tagline, the version, Open Mnemit Folder… and the links. The button opens the deck
  with cards left that was used last, and that deck's window starts the stream
  (`WelcomeRequest.requestStudy(of:entry:)`); Learn 10 New Words opens the deck used last
  (`SessionViewModel.Entry.pushOn`). The window reads again when it becomes key and every minute
  (`KnownDeckCounts.refresh(_:)`). Import Cards… takes CSV, TSV, `.apkg`
  and `.colpkg`; a package makes a new deck named after the Anki deck, in the window title as well as
  in Save As. Opening an `.apkg` from Finder does the same, not a document window.
- **Progress window** (`ProgressWindow`): the iPhone's `ProgressScreen` (`Shared/Statistics`) with All
  Medals and, in its last section, a link to How It Works. From the day in the Today window, the ring
  chip of a deck window and Window ▸ Progress; it reads the decks again when it becomes key.
- The Mac's day counts `AllDecks`: the open documents and the rest of the Mnemit folder. The ring chip,
  the session header, Today, Progress and How It Works all count them.
- **Deck window**: Overview | Cards | Statistics (Study ▸ ⌘1, ⌘2, ⌘3), titled with the deck's name: the
  window hides the package's extension (`hideExtension()`). A deck opens on **Overview**
  (`DeckOverviewView`), the iPhone's deck screen: Today's counts (`CountsRow`) with the plan's footer, Study
  This Deck (Learn 10 New Words once nothing is due), Practice Newest Words and Practice Today's
  Mistakes, and rows to Cards, Statistics and Learning Options…. The toolbar carries the ring chip (a click
  opens Progress) and the button: **Study** (prominent) while the deck has cards due, else **Learn 10 New Words**
  (`design-spec.md` §6.2). Cards, filters, inspector and edit sheet: Card browser. Study ▸ Pause Deck /
  Resume Deck: Pausing a deck.
- **The Mac's stream** (`SessionView`) looks as the iPhone's does: the card on the grouped backdrop
  (`Color.studyBackdrop`, the card `Color.cardSurface`) over the stack's edges (`StackEdges`, the cards of the
  round behind it, at most four, `StackPose` in `Shared/Session/CardStackEdges.swift`); the bar with Done, the
  day's ring and its figures in the middle ("≈ 4 min", then "36 cards today"; the ring has no centre here),
  Undo and the menu "More" (`StreamMenuItems`, the iPhone's: Edit Card, Card Info, Suspend Card, Pronounce
  Automatically, disabled at a rest); Show Answer prominent in indigo with a keycap "Space or ↩". The bar of
  the last answer (`UndoChip`) stays under the header.
  - Keys: Space or Return show the answer; then ← Forgot, ↓ Hard, → Good, ↑ Easy (the iPhone's swipes;
    `Grade.arrowKey`), 1–4 also grade, Return and Space mean Good, Esc, Z and ⌘Z undo, S pronounces, ⌘E edits
    the card. Every grade button shows its arrow as a keycap (`KeyCap`); the ring on Good marks Return. Done
    has no shortcut.
  - A card shown as a new word: the answer open, the chip "New word", Next in Show Answer's place; Space,
    Return, the four arrows (the card flies the arrow's way) and a click on the card move on, keys 1–4 do
    nothing.
  - Edit Card opens `CardEditSheet`; Card Info a sheet with the card list's inspector
    (`MacVocTrainNg/Views/Session/CardInfoSheet.swift`), whose Edit swaps it for the edit sheet.
  - At the end of a deck's plan, while another deck of the folder has cards in today's plan, the rest's
    first button is "Study Greek B1 · 14 cards" (`NextDeck`): it ends this stream and starts that deck's in
    its window; a stream from Today mixes the decks of the day from the start.
- The Mac's stream is the iPhone's `StudyModel` (`Shared/Session`) under `SessionViewModel`, whose stages are
  asking, revealed and resting: Today's Study, Catch Up and Learn 10 New Words open the decks of the day
  (`WelcomeRequest.requestStudy(of:entry:with:)`) and start one stream in the window of the deck used last,
  the others joining once they can be edited (`WelcomeRequest.openDocuments(_:)`); each card from the deck
  whose next card is most urgent, Undo (Z, Esc, ⌘Z) the last step in its own deck. Medals earned by a grade
  come as toasts under the bar (`MedalToasts`).
- How It Works: its own window (Study ▸ How It Works, or the link at the end of Progress), over
  `AllDecks`, each deck named by its file.
