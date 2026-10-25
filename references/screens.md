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

- Ring and the day's lines (`learning-flow.md`):
  - Headline: the day's next goal. "≈ 2 min to keep your streak" before the streak step (the first
    round), then "12 cards left · ≈ 4 min", and "Ring closed" once it is. Without cards "All done" or
    "Nothing due". Rounds never show by number.
  - Second line, before the first card of the day: yesterday's ring, "Yesterday's ring closed · 14 cards" or
    "Yesterday: 9 of 12 cards" (`DailyProgress.yesterday`). The day turns at 04:00, and work done just before
    it, on either device, belongs to the day before; the line shows it until today's first card.
  - Second line after that: "M of K cards" while the ring is open, the done cards against the day's goal; once the
    ring is closed "M cards today · N left", N the cards of today's plan not done yet, not the raw due
    count, and "M cards today" once the plan is done; with nothing done and nothing due "Next review …".
    M, N and K are one unit, M + N ≥ K, equal while the plan fits the day's time and nothing was added
    to it; Forgot doesn't break it. A day with nothing done and nothing due has a goal of 0
    (`DailyGoal.goal(done: 0, owed: 0, plan: 0)`), which counts as met: the ring is a track and the
    line hides the goal.
  - The streak is the flame in the middle of the ring (`RingCenter`): lit in `Color.streak` once the
    streak step is done, grey otherwise. Today at risk (`DailyProgress.isStreakAtRisk`, ring open, the
    day after a missed day): the headline reads "Close the ring to save your streak" and the flame is
    grey.
  - Words in memory on one line under the ring, "≈ 28 words in memory · +15 today", as wide as the
    row (`MemoryLine`: the row's width, not the column next to the ring, where the gain doesn't fit
    on 375 pt; at large text sizes the single text wraps). On the day a milestone is passed:
    "50 words in memory!".
  - The panel with the ring is a button that opens the Progress screen.
- The bottom button is named by `DayAction` (`Shared/Session/TodaySummary.swift`): **Study**
  (`.glassProminent`) while the ring is open; **Catch Up** (`.glass`) once the ring is closed and the
  plan has cards left; **Push On** (`.glass`) once the plan is done, with "More reviews in the days
  ahead" in footnote under it. Study and Catch Up open the stream over the screen (`StudyRunView`)
  over every active deck. Push On opens it with ten new cards at once over every active deck
  (`StudyModel.Entry.pushOn`), without the plan-end rest first. With every deck paused the button is
  disabled.
- Decks section: a row per deck with its counts, "4 new · 10 review": a kind with nothing left is left
  out (`StudyCounts.parts`). Ring and streak cover all decks; decks are rows.
  Tapping a row pushes the deck screen. Swipe and context menu: **Pause Deck** (`pause.circle`); a
  swipe also offers Remove from List where the list may forget the deck.
- **Paused** section at the bottom, only when a deck is paused (Pausing a deck).
- Toolbar, trailing: the **+** menu: Add
  Cards (into the last used deck, `KnownDecks.last`: studied or added to), Import… (into the deck
  used last), Shared Decks on AnkiWeb, New Deck (into the deck folder; without one, into the app's
  Documents). The **…** menu: Choose Mnemit Folder…, Open Deck…, Settings.
- `.searchable` over every card of every deck (`AllCardsSearch` reads the files of all decks without
  opening them; `CardSearchIndex` also searches the word key); a result pushes `CardDetailScreen` on
  the deck opened by slot.
- Undo of edits: `UndoWatch` (a bar button while there is something to undo) and shake (`StartScreen`,
  when no sheet is open).
- **Empty state** (no decks): **New Deck** (`.glassProminent`, large) and **Use iCloud Drive Folder**
  (`.glass`, large), at most 320 pt wide, with Shared Decks on AnkiWeb as a link under them; Open
  Deck… is in the **…** menu. No mention of the Mac.
- The month's screen (`MonthRecapSheet`) shows once on the first open of a month after a month with
  study; see Progress.
- Frames: `VocTrainTests/HomeSnapshotTests` (directory `TEST_RUNNER_HOME_SHOTS_DIR`).

## Progress (iPhone)

- The header of Today (ring, headline, detail line, words in memory) is a button with a chevron; it pushes
  `ProgressScreen` (`DeckRoute.progress`, no deck). `learning-flow.md` has the contract; everything
  comes from `DailyProgress.records` and `.achievements`.
- Sections in an inset-grouped list: the streak large, "12-day streak" (`flame.fill` in `Color.streak`
  while `DailyProgress.isStreakLit`, grey otherwise) with the totals Longest streak, Rings closed,
  Days studied, Cards done; Medals (the latest up to five, newest first, and All Medals); "Last 13 weeks"
  (`WeeksGrid`: a column per week, a row per weekday of the locale, today last; closed full, kept at
  its share of the goal, a missed day an empty track, before the first study day nothing); Memory
  (`LadderBar` and a row per step); and **How Today Works**, the last row, in a section with the footer
  "The plan, the day's time and the FSRS parameters behind the ring."
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
- Header: the close button, the small ring (`StreamRing`, empty in the middle) with "≈ 4 min" while the goal is open (after a done card,
  for 1.5 s, its interval: "tomorrow", "in 8 days"), "36 cards today" once the goal is met, an Undo
  button, the menu (Undo, Card Info, Suspend Card, Speak toggle). A practice names itself and has no
  ring. Closing loses nothing: every grade is saved, and Today picks up the count.
- The card lies on a stack drawn as a book's page edges; how cards leave it and come back:
  `learning-flow.md`, "The stack", and `study-screen.md`, Motion.
- Undo, from the button in the bar, the menu or a shake, takes back the review that ended the round
  and the rest with it; redo brings it back. The card from the stream (`CardInfoSheet`) is the same
  `CardDetailScreen`.
- The stream stops at four rests, one `StreamRestView`; the model is in `learning-flow.md`. The Streak kept
  rest takes a milestone's name as its title, the Ring closed rest "Streak saved"; both show the medals
  earned today, three at most, under the title.
  - *Streak kept* (once a day, after the streak step, inside the plan): the ring, the title, "12-day
    streak" with the lit flame (`flame.fill` in `Color.streak`) under it, the cards left to the ring with
    their time. **Keep Going** (default, prominent) or **Done for Now**. The rest has no card on
    screen, so nothing is spoken and nothing is graded.
  - *Ring closed* (the end of the last round while the plan has cards beyond it): the medal earned
    today, one line (the words' milestone, else the words gained, else "10 cards today"), the rings of the
    last seven days (`WeekRings`). **Done** (prominent) and **Catch Up**.
  - The end of the plan: "Ring closed", or "Done for today" when the plan ran out with the ring open;
    the same lines. **Done** (prominent) and, while a deck has new cards, **Push On** (bordered)
    with "More reviews in the days ahead" under it. Push On adds ten new cards beyond the limits and
    asks them at once, with no rest after; it is the only way past the end of the plan, and Today's
    Push On opens the stream with them directly. On the Mac a rest
    taller than the window scrolls under the header (`SessionView`).
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

## How Today Works

A sheet from the last row of the Progress screen (`HowTodayWorksSheet`). On the Mac
the window of Study ▸ How Today Works, over the open decks, which it names Deck 1, Deck 2.

- For the learner who knows Anki and FSRS: the numbers and rules under the ring and the rounds, as
  they are now. Read-only: no controls, no charts. A grouped form; each section's footer holds its
  rule.
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
  details sheet). Header: what today's plan takes from the deck (new, learning, review); under a
  paused deck's counts "Paused. Today's plan leaves this deck out."; with nothing due, "Nothing due.
  Next review …". The bottom button is **Study This Deck** while the deck has cards in today's plan,
  else **Push On** with "More reviews in the days ahead" under it: ten new cards of this deck at once.
- Rows: Cards (count) → Card Browser; Add Cards; Import Cards…; Shared Decks on AnkiWeb; a Practice
  section with Practice Newest Words and Practice Today's Mistakes, each only when the deck has cards
  for it, footer "Practice doesn't change when cards come back"; Statistics; Options.
- Toolbar menu: Rename…, **Pause Deck** / **Resume Deck** (`pause.circle` / `play.circle`), Export…,
  Delete Deck (moves the file to the Trash).
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
  visible). Table columns as before plus Kind; the Kind column sorts by `CardRow.kindRank`. The
  inspector shows the iPhone's Card Detail sections, kind and word key included, and links to the
  sibling (`Deck.siblings(of:)`).
  The edit sheet (Question, Answer, Hint, Word key) changes the word key through
  `VocabularyDocument.setNote` (`DeckChange.settingNote`, kind stays) and hides it while the session
  still asks the card: the key of a "translation → Greek" card is the answer. Keyboard: Delete, ⌘E,
  ⌘L, ⌘1/⌘2/⌘3 (Overview, Cards, Statistics), Space/arrows in the stream.
- On macOS 27 a click on a `Table` row selects the row but takes no focus (`NSTableView.mouseDown` is
  not called; measured with a live click on 22.10.2026), and the form field stays first responder:
  Delete, ⌘E and the arrows go to it. `TableClickFocus` (the table's background) moves focus into the
  table after a mouse click on it; a selection that changes by itself doesn't touch focus.
- Frames: browser, card and edit in `BrowserSnapshotTests` (`TEST_RUNNER_STUDY_SHOTS_DIR`).

## Card Detail and Edit Card (iPhone)

- **Card Detail** (pushed): both sides large, speaker beside the Greek. Kind (Greek → translation /
  translation → Greek) with a link to the sibling card. Memory: state, next review, stability (days),
  difficulty, recall now (%). History: each review with date and the grade's colour and arrow.
  Toolbar **Edit**; actions: Suspend/Resume, Reset Progress, Delete.
- **Edit Card** (sheet): Question, Answer, Hint; Word key under Advanced. Cancel / Save.

## Add Cards, New Deck, Import, Export (iPhone)

- **Add Cards** (sheet), two modes. One Card: Question, Answer, Hint, "Both directions" toggle; **Add**
  keeps the sheet open for the next card. From a List: paste lines `word = translation`, a live
  preview of the cards, Add N Cards; the same parser as the Mac's Lesson Words.
- **New Deck**: a name field; creates `<name>.mnemit` in the deck folder (iCloud Drive or this
  iPhone) and pushes its screen, where Add Cards opens by itself: the deck screen of an empty deck opens
  it once.
- **Import**: a file picker (CSV, TSV, `.apkg` or `.colpkg`) → the same preview as the Mac, a list
  with a checkmark per card (duplicates unchecked) → Add N Cards, one undo step. Entry points: Import
  Cards… on the deck screen, Import… in Today's + menu (into the deck used last). The preview of an
  Anki package heads with the Anki deck names, the number of cards, how many have review history and
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

## Options (iPhone form)

New cards per day; target recall (70–97 %, one-line explanation); translation→Greek: new per day and
unlock after N days; new-card order; difficult after N lapses. Advanced: maximum interval, FSRS
parameters with "Compute from Review Log".

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
  sit in a "Paused" section at the bottom, grey, without counts, subtitle "Paused", swipe and context
  menu Resume Deck; the deck screen menu has the same item. Mac: Study ▸ Pause Deck / Resume Deck
  pauses the deck of the window; the ring in the toolbar and its help count the decks of the Mnemit folder that
  aren't paused.
- "How Today Works" names it in the plan with the line "Paused: <name>".
- After resuming, its overdue cards are due like any and come back into the plan, with no special
  rules.

## First launch, deck folder, reminders

- First launch on the iPhone (`OnboardingView`, steps `OnboardingStep`): a welcome with one button →
  swipe practice (`GesturePracticeView`; order and sample cards in `SwipePractice`: ← forgot,
  ↑ instantly, ↓ with effort, → remember; the four meanings are the rules, there is no separate rules
  screen; "Skip" leads to sync) → sync (iCloud Drive: folder picker, `chooseFolder`; "Only on This
  iPhone": `useLocalFolder`, the app's Documents folder without bookmark or scope, in Files On My
  iPhone ▸ Mnemit) → reminder.
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
  - Circular: the ring with the cards left in its middle, the same number the headline counts
    (`toRing`, else the plan's cards left); with none left the flame over the streak's days, and with no
    streak a checkmark.
  - Rectangular (lock screen): the headline, the "N cards today" line once the ring is closed, and the
    streak line with the flame, in the streak's orange once the day keeps it.
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
| The day's button | Study / Catch Up / Push On | the same |
| Study over several decks | one stream mixes the decks | a deck's stream at a time; at its end, "Study <next deck>" |
| The stream | swipes, the stack, the ring travelling to the rests | keys and buttons, the stack, the rests |
| Progress, medals, How Today Works | pushed from Today | windows |
| A deck | the deck screen | the deck window's Overview |
| Cards | the browser, Card Detail, Edit Card | the table, the inspector, the edit sheet; multi-select, keyboard |
| Adding | Add Cards: One Card, From a List | the form above the table, Add Lesson Words |
| Import, export, AnkiWeb | yes | yes |
| Typing the answer | no | Study by typing (Preferences) |
| Reminders, the icon's number | yes | no: the iPhone's are enough |
| Widget | yes | no |
| Search over all decks | Today's search | a deck's table |
| The month's sheet, medal toasts | yes | the rests show today's medals |

## Mac windows

- **Today window** is the Mac's Today (`WelcomeWindow`, content `WelcomeView` → `TodayWindowContent`;
  window title "Today", Window ▸ Today ⌘0; shown at launch while no document is open, and by a click on
  the Dock icon then; to turn it off: `defaults write <bundle id> showsWelcomeWindow -bool NO`). It
  stays open beside the deck windows; like every Mac window it takes the app's indigo as its tint
  (`brandTint()`), whatever the system accent. Left: `SummaryRow` (the same view as the iPhone's Today header,
  ring 80 pt, a button with a chevron that opens Progress), the `DayAction` button (extra large, the default action) and the links Choose Mnemit
  Folder…, New Deck, Import Cards…, Open Deck…, Shared Decks on AnkiWeb…. Right: the decks of the Mnemit folder
  with what today's plan takes from each (`StudyCounts.parts`, else "Next review …", "Paused" for a
  paused deck) and the cards left or a checkmark; Recent Decks below. Before the folder is chosen: the
  icon, the name, the tagline, the version, Open Mnemit Folder… and the links. The button opens the deck
  with cards left that was used last, and that deck's window starts the stream
  (`WelcomeRequest.requestStudy(of:entry:)`); Push On opens the deck used last
  (`SessionViewModel.Entry.pushOn`). The window reads again when it becomes key and every minute
  (`KnownDeckCounts.refresh(_:)`). Import Cards… takes CSV, TSV, `.apkg`
  and `.colpkg`; a package makes a new deck named after the Anki deck, in the window title as well as
  in Save As. Opening an `.apkg` from Finder does the same, not a document window.
- **Progress window** (`ProgressWindow`): the iPhone's `ProgressScreen` (`Shared/Statistics`) with All
  Medals and, in its last section, a link to How Today Works. From the day in the Today window, the ring
  chip of a deck window and Window ▸ Progress; it reads the decks again when it becomes key.
- The Mac's day counts `AllDecks`: the open documents and the rest of the Mnemit folder. The ring chip,
  the session header, Today, Progress and How Today Works all count them.
- **Deck window**: Overview | Cards | Statistics (Study ▸ ⌘1, ⌘2, ⌘3), titled with the deck's name: the
  window hides the package's extension (`hideExtension()`). A deck opens on **Overview**
  (`DeckOverviewView`), the iPhone's deck screen: Today's counts (`CountsRow`) with the plan's footer, Study
  This Deck (Push On with its footnote once nothing is due), Practice Newest Words and Practice Today's
  Mistakes, and rows to Cards, Statistics and Learning Options…. The toolbar carries the ring chip (a click
  opens Progress) and the button: **Study** (prominent) while the deck has cards due, else **Push On**
  (`design-spec.md` §6.2). Cards, filters, inspector and edit sheet: Card browser. Study ▸ Pause Deck /
  Resume Deck: Pausing a deck.
- **The Mac's stream** (`SessionView`) looks as the iPhone's does: the card on the grouped backdrop
  (`Color.studyBackdrop`, the card `Color.cardSurface`) over the stack's edges (`StackEdges`, the cards of the
  round behind it, at most four, `StackPose` in `Shared/Session/CardStackEdges.swift`); the bar with Done, the
  day's ring and its figures in the middle ("≈ 4 min", then "36 cards today"), Undo and a menu with Edit Card…
  (⌘E) and Suspend Card; Show Answer prominent in indigo, Space or Return. Typing keeps the bar of the last
  answer under the card. At the end of a deck's plan, while another deck of the folder has cards in today's
  plan, the rest's first button is "Study Greek B1 · 14 cards" (`NextDeck`): it ends this stream and starts
  that deck's in its window, so the day goes on over the decks as the iPhone's mixed stream does.
- How Today Works: its own window (Study ▸ How Today Works, or the link at the end of Progress), over
  `AllDecks`, each deck named by its file.
