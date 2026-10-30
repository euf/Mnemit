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
   **All · Due · New · Learning · Suspended · Leeches**.
5. Every change goes through the document's undo. Deleting one card needs no confirmation (undo covers
   it); deleting several, or a deck, asks once.
6. Search matches question, answer, hint and the word key (`note`), ignoring case and accents.

## Today (iPhone)

The iPhone starts on Today, the root of a `NavigationStack` (`StartScreen` holds the state,
`TodayScreen` draws). State by state: `design-spec.md` §2.4.

- The Today card (`TodayCard`, `Shared/Session/TodaySummary.swift`) is the list's first section, in the screens' grammar
  (`design-spec.md` §2.6), the whole of it a button that opens the Progress screen. The date of the study day ("Tuesday,
  October 27") stands under the large title (`todaySubtitle`).
  - The ring (`HeroRing`, 112 pt, scaled with the text): a picture, with no number in it.
  - Three figures right of the ring (`TodayFigures`), each a label over a value:
    - **Day streak**: the flame by its state and the days in `Color.streak`. The flame has three states (`StreakState`): an
      outline until the streak step is done, `flame.fill` once it is, an outline with an `exclamationmark` at risk
      (`DailyProgress.isStreakAtRisk`: the day after a missed day, ring open). At 0 days the outline and "0" in the secondary
      colour. VoiceOver reads "12-day streak, kept today" (`NextStep.streakSpoken`).
    - **The next moment** (`NextStep.moment`), its value the minutes in the ring's indigo. The label names the moment: "To
      keep your streak" over "≈ 2 min"; the step done, "To close the ring"; the day after a missed day, "To save your
      streak"; without a streak, "To start your streak"; the ring closed with cards of the plan left, "Reviews left"; nothing
      left, "Today" over "All done". Without a price the label is "Next" and the value is the moment's name ("Keep your
      streak", "Close the ring", "Save your streak", "Start your streak", "Catch Up").
    - **Words learned**: the words, with "+12 today" after them on a day that added some; shown from 0 words too.
  - Under a divider, the week's seven rings with their weekday letters (`WeekRings`), a chevron at the end of the row.
  - Where the figures do not fit beside the ring (the larger text sizes, `ViewThatFits`) the ring stands over them.
  - The day turns at 04:00, and work done just before it, on either device, belongs to the day before. The card waits for
    every deck to be read and the ring to be evaluated for today (`isDayReady`, `DailyRingModel.isStale`); until then it
    shows placeholders. The ring is evaluated again on coming to the front and every minute, under a deck screen and the
    Add Cards sheet too, with the open decks as their documents have them (`refreshRingForNewDay`); the stream does the
    same for itself. The ring keeps its size with the text; the figures wrap and the list scrolls.
  - A streak that ended (two missed days, or a day that only kept the streak after one) is told once, on the first idle
    Today after the break, as a line under the card: "12-day streak ended · Best: 30", the best left out when the ended
    streak was it (`EndedStreak`, `StreakEndedNote`; the Mac's page shows the same line under its card). It goes when
    Study starts, and `shownStreakEnd` keeps the study day it ended on so that it is told once.
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
- A deck that can't be read (damaged, from a newer version, still downloading from iCloud) says why under its name, with a
  warning sign in place of the time (`DeckRow(failure:)`, `KnownDeckCounts.failed`); it does not hold the day back, the other
  decks show their figures and the ring counts them. Its screen offers **Try Again**.
- A Mnemit folder that can't be reached (signed out of iCloud, the folder gone) is kept, not forgotten: Today shows the card
  "The Mnemit folder can't be reached" with **Choose Folder Again** (`LostFolderCard`, `KnownDecks.folderLost`); a refresh
  reads the folder again once it is back, and New Deck waits.
- **Paused** section at the bottom, only when a deck is paused (Pausing a deck).
- Toolbar, trailing: the **+** menu: Add Cards (into the last used deck, `KnownDecks.last`: studied or added
  to), Import… (into the deck used last), Shared Decks on AnkiWeb, New Deck (into the deck folder; without
  one, into the app's Documents). The **…** menu: Choose Mnemit Folder…, Open Deck…, Settings.
- `.searchable` over every card of every deck (`AllCardsSearch` reads the files of all decks without
  opening them; `CardSearchIndex` also searches the word key); a result pushes `CardDetailScreen` on
  the deck opened by slot.
- Undo of edits: `UndoWatch` (a bar button while there is something to undo) and shake (`StartScreen`,
  when no sheet is open).
- **Empty state** (no decks): the card of an empty day (`EmptyTodayCard`: the empty ring and "Add the words you are
  learning.", on `Color.tileGround`), **New Deck** (`.borderedProminent`, large), **Shared Decks** (`.bordered`, large) and
  **Use iCloud Drive Folder** as a small text button under them; Open Deck… is in the **…** menu. No mention of the Mac.
- The month's screen (`MonthRecapSheet`) shows once on the first open of a month after a month with
  study; see Progress.
- Frames: `VocTrainTests/HomeSnapshotTests` (directory `TEST_RUNNER_HOME_SHOTS_DIR`).

## Progress (iPhone)

- The Today card is a button with a chevron; it pushes `ProgressScreen` (`DeckRoute.progress`, no deck).
  `learning-flow.md` has the contract; everything comes from `DailyProgress.records` and `.achievements`.
- A grouped form (`.formStyle(.grouped)`), top to bottom; each section stands under its list header:
  - The streak card (`StreakCard`): "Day streak" over the flame and the days large in `Color.streak`, "Best: 21" after them only
    when the best run is longer than the current one; at 0 days the outlined flame and "Start your streak".
  - The totals as `FigureTile`s on the page, not in a card, two to a row in an adaptive grid (at least 150 pt wide; one
    column at the accessibility sizes): Days studied, Rings closed (footnote "of 110 days": the days from the first study day
    to today), Words learned, Your ring ("8 MIN" in the ring's indigo, footnote "a day · started at 2.5", or "a day" while the
    ring has not moved; `RingSize.value` and `.footnote`). A tile with nothing under its value carries a blank line, so a row
    is of one height. On the Mac the grouped form keeps a card behind the row: the four figures share it, without tile
    grounds. No ring here: the day's ring is on Today.
  - The calendar, "Last 13 weeks" once there are 13 and "Calendar" before (`WeeksGrid`): rows of seven
    cells, a row per week, the oldest first, Monday to Sunday under the weekday initials; a day is a ring,
    each day its own share of its goal (`DayRecord.ringShare`): a closed day full, and laps past the goal up to
    three, any other day the share done, none done an empty track, before the first study day nothing; a capsule in `Color.streak` at 18 % lies behind each run of two or more kept days
    (`DayRecord.kept`) within a week row (`WeeksGrid.runs(ofKept:)`); a run does not cross rows.
  - Medals (the latest up to five, newest first, and Show All).
  - Memory, once a card is started: the line of words in memory (`MemoryEstimate.line`) and the ladder (`LadderBar` and a row
    per step).
  - **How It Works**, the last row, in a section with the footer "What's behind the ring."
- The medals screen (`MedalsScreen`, from Show All): one row for the lines of one medal (`AchievementLine.single`), then a row per
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
- Header, left, right after the close button: the small ring (`StreamRing`, empty inside) and the minutes to the next
  moment of the day beside it (no streak: the rests show it) ("≈ 2 min": to the streak, to the ring, of the reviews left; none once all is done); after a done card, for 1.5 s, its
  interval ("tomorrow", "in 8 days") takes the text's place. Then an Undo button and the menu "More". A practice names itself
  and has no ring. Closing loses nothing: every grade is saved, and Today picks up the count.
- The menu "More" is one menu on both apps (`StreamMenuItems`): Edit Card (the keyboard opens in the answer; on the Mac ⌘E, shown on the item and in the cheat sheet), Card Info, Suspend Card, a
  divider, Pronounce Automatically (where the device has a Greek voice). The iPhone adds Undo above them,
  which is also its own button. The items are disabled at a rest, never hidden.
- **The answer buttons** appear with the answer: two wide buttons side by side, as tall as the two rows the four once took,
  **Forgot** (red, ←, key 1) and **Good** (green, →, key 3). On a new card's first showing they read **Don't know** (the grade
  underneath is Again) and **Know** (Good); the receipt chip and its VoiceOver announcement use the same names
  (`Grade.buttonTitle(isNew:)`). The setting **Hard and Easy Buttons** (`@AppStorage("ShowsFourAnswerButtons")`, off, one key
  for both apps: `GradeChoice.showsFourButtonsKey`) lays out four on a later showing: Forgot full width, Hard, Good and Easy
  under it, Good wider; a first showing stays two. `GradeChoice.buttonGrades(isNew:showsFourButtons:)` is the one rule. At
  the accessibility sizes the two stack, Forgot over Good; the iPhone in landscape puts Forgot beside Good, or beside the
  three. The swipes give the grades of the buttons and no others (`GradeSwipe.grade(atAngle:among:)`): with two buttons left
  Forgot and right Good, up and down spring back; with four, up Easy and down Hard too. On the Mac ← or 1 and → or 3 grade
  the two buttons; ↓ ↑ and 2 4 give Hard and Easy only with the setting on. The rules: `scheduling.md`, "A new card's
  first showing".
- **The leech moment** (`LeechMomentView`, `SessionDriver.leechMoment`): right after the Forgot that makes a card a leech,
  before the next card, the stream stops on "Keeps slipping" with the card's question and answer as the stream shows them,
  media included, and three ways on: **Continue** (prominent), **Edit** (the card's edit sheet; the stream goes on once it is
  saved) and **Suspend Card**, which suspends the card; when the review already suspended it (the deck's action is Suspend)
  the button reads **Keep Card** and resumes it. A sentence under the title counts the lapses and names the choice. On the
  Mac Return continues, E edits, S suspends or keeps. VoiceOver reads the title, the sentence, the question, the answer, then
  the actions. A moment is the lapse that brings the card's lapses to the
  threshold or to each half of it after that (`scheduling.md`, "Leech"); undoing the grade takes back the moment and any
  suspension. A leech resumed under Suspend is asked again in the stream.
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
    deck has new cards, **Learn 10 New Words** (the accent on a wash of it, `SecondaryActionStyle`), ten new cards beyond the day's allowance and New cards/day asked at once, with no rest
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
- **Today**: the three moments in three plain sentences, no figures and an empty footer: the first two minutes keep the
  streak; the ring is today's goal and Catch Up takes the reviews still waiting; nothing due is a done day, and Learn 10 New
  Words gives more (`HowTodayWorks.Row.text`).
- **Today's Plan**: due today, overdue included; cards in learning; new cards admitted; each deck's
  admitted cards with its allowance, or its New cards/day where the deck sets it, a paused deck as "Paused: <name>" with
  no figures; cards done; cards left.
- **Today's time**: the day's time in minutes (one decimal), the streak step and the daily goal in
  cards; the last 14 days, newest first, with the minutes asked, the minutes worked, the ring (Closed
  or Open) and why the day had its size (Start, Ring closed, Ring open, Plan under the time, Past the ring); the footer
  says how the ring grows after closed rings and shrinks after an open one, grows to what you do when you go well past it
  most days, starts at 2½ minutes and stays between 2 minutes and an hour.
- **Pace**: seconds for a new card and for another card, each with its source (Durations (n), Gaps (n)
  or Default) and the reviews each done card took.
- **Streak**: days, whether today is kept, the cards that would repair yesterday.
- **Words in Memory**: the value to two decimals, at the start of the day, the gain, the next
  milestone.
- **Swipes** (iPhone only): "Swipes that sprang back from a gap: N of M today" (`SwipeTally`,
  `study-screen.md`), with the sectors in compass degrees in the footer.
- **Options**: seven sentences and no footer, one for each option with a rule behind it. A new word is answered Don't know
  and comes back in the session. Desired retention (higher means more reviews; 90 % is a good balance). A Meaning → Word card opens
  once its Word → Meaning card has an interval of 7 days. The leech: a card forgotten as often as the deck's threshold says, and again
  after every half of it; its answer stays on screen so the card can be edited or set aside. Learning steps (Hard keeps the
  step, Forgot starts it over, Easy finishes at once). The FSRS parameters (they start from averages, are fitted to the
  learner's reviews, give fewer reviews for the same recall, and keep the due dates). The refit schedule, read from
  `ParameterRefit`: the first fit at 400 reviews, again at 1,500, then every 30 days or after 1,000 more; a new fit is kept
  only if it predicts the latest reviews clearly better, on the reviews of all decks together.
- **FSRS**, one section per deck: desired retention, default or fitted parameters with the 21 values
  (monospaced, four decimals, wrapped), the last automatic fit, learning steps, maximum interval.
- Code: `HowTodayWorks` (the rows) and `HowTodayWorksView` in `Shared/Statistics`; `DayBreakdown` in
  VocabCore holds what `DailyProgress` does not: the parts of the plan, the decks' shares, the days,
  the base of the pace.

## Deck screen

- A deck row pushes the deck screen onto Today's stack (`DeckScreen`/`DeckContent`; it replaces the details sheet). Its first
  section is the deck's Today card (`DeckTodayCard`, `Shared/Session/`): the label "Today" over "≈ 4 min" in the ring's indigo
  (the minutes of what today's plan leaves in the deck, backlog included; a placeholder until the ring is worked out) and
  beside it Due, New and Learning as figures in the primary colour, a part of 0 left out. The counts go under the time when
  the card is narrow, all in one column at the accessibility sizes. A deck with nothing left: "Today" over a check and "Done",
  "Next review tomorrow" under it (none when no review is coming); a paused deck: "Today" over "Paused", which wins over the
  counts. A deck with no cards, or counts not read yet, has no card. VoiceOver reads `DeckHeadline.text`, the one line
  "≈ 4 min · 14 due · 6 new · 2 learning".
- Rows under it, at the body size: Cards (count) → Card Browser; Statistics; Options. **Study This Deck** is the bottom bar's
  button (`.borderedProminent`) while the deck has cards in today's plan, else **Learn 10 New Words** (grey): ten new cards of
  this deck at once; it is disabled for a deck without cards or one that cannot be edited.
- Toolbar: **+** (`AddMenu`: Add Cards, Import Cards…; both wait for `isReadyToEdit`) and **…**: Practice
  Newest Words and Practice Today's Mistakes (`DeckPractice`, grey with nothing to practise; practice
  doesn't change when cards come back), a divider, Rename…, **Pause Deck** / **Resume Deck**
  (`pause.circle` / `play.circle`), Export…, Delete Deck (moves the file to the Trash).
- A paused deck still opens: Study This Deck and the rest work, and the counts are those of the deck's
  own New cards/day; on Auto its plan holds no new card, and Learn 10 New Words adds ten.
- `PushedDecks` keeps the stack's decks open: it opens one when a route is pushed (`DeckRoute`, the
  deck named by slot, not by file, so a rename doesn't change the route) and closes it when the route
  leaves `path`. Screens above (`CardBrowserScreen`, `CardDetailScreen`, options) show one document.
- Study This Deck runs on the screen's deck (`StudyRun(ownsDeck: false)`: the stream doesn't close it;
  after the stream `undoManager.removeAllActions()`, so the browser's Undo doesn't roll back reviews).
- Rename and Delete close the deck before `DeckFiles.rename`/`trash` and update `KnownDecks`
  (`replace`, `forget`).
- Frames: `VocTrainTests/HomeSnapshotTests` (the deck screen too).

## Card browser

- Pushed from the deck screen. Filters **All · Due · New · Learning · Suspended · Leeches**, the same
  names in both apps. Rules in `CardFilter` (VocabCore: `matches`, `Deck.filterCounts(at:)`): Due, New
  and Learning exclude suspended cards, Leeches includes them; a suspended card is only in All,
  Suspended and, if a leech, Leeches. The empty Leeches list says "Words you keep forgetting appear here." Titles: `CardFilter.title` in
  `Shared/Support/Presentation.swift`.
- Search (`CardSearchIndex`) looks into `note` too.
- iPhone: a `List` with `.searchable` and the filter row; sort menu `BrowserSort`: Due, Added, A–Z,
  Difficulty, Lapses (most first, new cards last); the logic is in `CardBrowserList`, without a screen and with tests. Row: question
  (primary), answer (secondary), trailing state (relative due date / New / Suspended / Leech: a suspended leech says
  Suspended, a leech back in rotation says Leech in place of its date).
  Swipe: trailing Delete, Suspend/Resume; context menu: Edit, Speak, Suspend/Resume, Reset Progress,
  Delete. Edit mode: multi-select, then Suspend, Resume, Reset or Delete. Tap pushes Card Detail.
- Mac: a segmented control `ScopeBar` above the table with a count in each segment (`searchScopes` on the Mac live only during a search, and the filters must always be
  visible). Table columns: Question, Answer, Hint, Kind (Word → Meaning / Meaning → Word, `CardKind.title`; sorts by `CardRow.kindRank`), Maturity, Due, and the card's memory: Lapses, Stability (`Format.days`), Difficulty ("5.2 / 10", `Format.difficulty`) and Recall (the FSRS recall of the study day, as a percent). The memory columns sort, can be hidden (`customizationID`; the order stays fixed) and are empty for a new card, which sorts first; `RecallBasis` (the deck's options, the calendar and the study day) rebuilds the rows when the day turns. There is no add form above the table: cards come from Add Cards…, and the empty table offers a button for it. The status line under the table says only "N cards", or "M of N cards" while filtered; the counts of the day are in the filter strip above. The
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
  then notes for a suspended card or a leech ("Leech: you keep forgetting this card."; the Mac inspector says it too); then a collapsed **Details**: State, Stability, Difficulty,
  Recall Now, Reviews, Lapses and the Word Key (the Mac also Last Review). History: each review with date and
  the grade's colour and arrow, "Typed" on a typed review of an upstream deck. Toolbar **Edit**; actions:
  Suspend/Resume, Reset Progress, Delete.
- **Edit Card** (sheet): Question, Answer, Hint; Word key under Advanced. Cancel / Save.

## Add Cards, New Deck, Import, Export (iPhone)

- **Add Cards** (sheet), two modes in a segmented control, opened on the mode used last
  (`AddCardsMode`) with the keyboard up in it (the Question field, or the list's editor), and the deck the words go to named
  under the title. One Card: Question, Answer, Hint, "Both directions" toggle; **Add** keeps the sheet open
  for the next card and shows the badge "Added · N words so far" (a word is a line of the list, or one card or pair); **Done** adds what is typed and closes;
  Cancel asks before discarding typed text. From a List: paste lines `word = translation`, a live preview of
  the cards, a row per word with a tick (duplicates, and words another deck holds, unchecked; a tap
  switches), Add N Words (the checked rows). An addition is one undo step ("Add Cards"); the list's words the deck holds but hasn't
  started join it (`WordListPreview.renewable(in:)`), so the lesson goes first among the new cards. Once cards are added the bottom bar holds Add and **Study These Now**
  side by side (one under the other at large text sizes): while something is typed that can be added Add is the prominent
  button, with nothing left to add Study These Now is; it adds what is typed too, closes the sheet and starts the stream
  over the deck with the added cards first. It shows only while the added cards are addable now (`StudyStream.addableCards`:
  new, unlocked, not buried; the Meaning → Word card of a word waits until its Word → Meaning card has an interval of 7 days). From Today (`AddCardsHost`) the stream starts
  after the sheet has gone and the deck is saved and closed; from the deck screen the sheet's `onDismiss` starts it on the open
  deck. The sheet is the Mac's too
  (`WordList.swift` in `Shared/Support` holds what the two share). On the Mac **Study These Now**
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
Type. The tiles are `FigureTile`s in an adaptive grid (at least 150 pt wide), one column at the accessibility sizes; their help texts stay as
tooltips on the Mac. The iPhone screen (`StatisticsScreen`, pushed from the deck screen) is a grouped list: the tiles on the
page, then the section Retention with one table, Young / Mature / Total over Today … last 365 days (`TrueRetention.all`). The Mac's deck page
shows its charts beside the tiles under Statistics (⌘4).

## Options

Both screens use Anki's names, so a learner who knows Anki finds each setting where it expects it (German as
Anki's German UI, Greek and Russian as its translations). Each option row has a "?" button
(`HelpButton` in `Shared/Support`, SF Symbol `questionmark.circle`, accessibility label "Help") that opens a popover
with a few plain sentences for a newcomer: what the row does and what its default means. On the iPhone the popover
stays a popover (`presentationCompactAdaptation`). The sections have no footers of their own; only the FSRS
section keeps the hint "Needs 400 reviews, each on a later day than the card's previous one." while the log is short.
Restore Defaults is the way back to the defaults; a confirmation dialog ("Restore the defaults of this deck's options?",
the destructive button "Restore Defaults", Cancel) comes first. It puts every option back to
`LearningOptions()` and keeps the FSRS parameters, the note of the last automatic fit (`lastAutoFit`) and the pause
(`LearningOptions.restoringDefaults()`).

The iPhone's form (`DeckOptionsScreen`) saves every change at once, one undo step each. Top to bottom:
**Daily Limits** (New cards/day, Auto by default, and Maximum reviews/day, No limit by default, each a menu of round
numbers, `LimitMenu`);
**Memory Model (FSRS)** (Desired retention, 70–97 %); **Lapses** (Leech threshold, a menu of N lapses or Off, and Leech action,
Keep Card or Suspend Card, `LearningOptions.leechAction`); **Advanced** (pushed screen: Maximum interval, Learning steps,
and the section FSRS Parameters with Optimize); and, at the foot of the form only, a section with the destructive
button Restore Defaults and the footer "Your FSRS parameters stay: they come from your reviews.", which the
confirmation dialog repeats. Restore Defaults is one undo step named "Restore Defaults"
(`VocabularyDocument.restoreDefaultLearningOptions()`). A menu keeps a value off it, as another app or a file may have set, in its numeric place. New cards/day offers Auto, None
(0, a review-only stretch), 5, 10, 15, 20, 30, 40, 50, 75, 100; Maximum reviews/day 50 to 500 and No limit last;
the leech threshold Off, 4 to 20; Learning steps 1 to 5. A menu sets its value in one write and one undo step, where a
stepper takes one of each per press. Each "?" opens a popover of at most about twenty words that scrolls when the room
above or below its row is smaller than the text.
The deck's setting "Spread out intervals" is no longer offered; `fuzzing` stays in the model and is on.

The Mac's sheet (`DeckOptionsView`) has the same rows in one form, with Advanced (Maximum interval, Learning steps) folded
in a disclosure group, and Save and Cancel. Restore Defaults sits at the left of the bottom bar and fills the sheet's
edited options; Save applies everything as one change.

## Pausing a deck

- `LearningOptions.isPaused`; the key `paused` in `deck.json` is written only when true, same format
  version: an old build drops the key and the deck is active again. The key travels with the options
  and merges by `learningOptionsChanged`, later wins.
- A paused deck is in none of: plan, goal, rounds, time, allowance (the other decks share it), widget count,
  reminders, Study. `DailyProgress.evaluate` and `DayBreakdown` leave `DeckActivity.isPaused` out of the plan
  and count its work: cards done, pace, streak, words in memory and words learned take every deck, so pausing
  takes nothing from today (such a deck's place in `newCardAllowances` holds 0; `DailyRingModel` gives
  it no allowance, and its plan holds the new cards of its own New cards/day, none on Auto: `StudySession`). `KnownDeckCounts` counts no cards for it and
  keeps it in `paused`; `TodayDecks` splits Today's sections and the Study queue (`studyQueue`); its
  stream has no `RoundGuide`.
- The deck still opens: screen, browser and Study This Deck work, and its cards fill the ring like those of
  Learn 10 New Words.
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

- First launch on the iPhone (`OnboardingView`, steps `OnboardingStep`): six steps, welcome, first showing, swipe, day, sync and
  reminder: a welcome with one button → a new word's first showing ("A New Word", `FirstShowingView`: a sample card, "a janela" /
  "the window"; Show Answer or a touch shows the answer, then the two wide buttons of a new card; Don't know slides the card left
  under a small stack with "It comes back after a few cards.", Know slides it right with "It comes back once more before
  you're done."; nothing is graded, recorded or scheduled, and Reduce Motion only fades the card into the stack; the lines are
  true of the scheduler, `whatTheFirstShowingSaysIsWhatTheSchedulerDoes`) → swipe
  practice (`GesturePracticeView`; order and sample cards in `SwipePractice`: ← Forgot, ↑ Remembered
  instantly, ↓ Remembered with effort, → Remembered; the four meanings are the rules, there is no separate
  rules screen; "Skip" leads on) → "One stack a day" (four lines: the stack, the ring, the streak, the
  ladder) → sync (iCloud Drive: folder picker, `chooseFolder`; "Only on This iPhone": `useLocalFolder`,
  the app's Documents folder without bookmark or scope, in Files On My iPhone ▸ Mnemit; with no decks in
  the folder, "Decks in this folder appear here." or "Next, create your first deck.", neither naming the Mac) →
  reminder. The welcome step has **Skip Introduction** under Get Started: it ends the introduction there; Today's empty
  state offers New Deck, Shared Decks and the iCloud Drive folder, and Settings shows the introduction again.
- **Settings** (a sheet from the **…** menu of Today, `SettingsView`): Reminder (the Daily Reminder toggle
  and, while it is on, the time; its footer appears only when notifications are off in iOS Settings, with
  Open Settings), Hard and Easy Buttons (a toggle in a section of its own, footer "Adds Hard and Easy: buttons, and
  swipes down and up.") and Show Introduction, which plays the onboarding again, with "Version 1.2.3 (hash)" under it. The Mac's
  Settings (⌘,, `PreferencesView`): Pronounce Automatically, Hard and Easy Buttons (the same toggle, footer "Adds Hard and Easy: buttons, and keys 2
  and 4."), Mnemit Folder (its path and
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
  and the body "≈ 2 min" (the time to keep the streak, not the length of the day: the first two minutes of that day's plan at the
  price of a card, "< 1 min" for a plan shorter than one, `DailyGoal.streakStepCards`); "Start your streak" and the same body
  without a streak; never a count of the cards due. A daily reminder names the streak only while it still stands on its day
  (`ReminderPlan.streakNamed`, in study days like the evening one). The number on the icon is "1" while today's ring is open and 0 once it
  is closed (`ReminderPlan.badge`; without the ring's figures, 1 while cards are due). Recomputed on going to the background,
  after closing a deck and on a time change. The notifications are local and fixed at the app's last run: a step the learner
  does on the Mac afterwards reaches the iPhone's reminders only when the app next runs there.
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
- Every widget shows the day's ring as a picture (the arc and its laps, nothing in its middle) and the day in words, from
  the same figures as Today (`TodayFigures`, `NextStep`): the flame in the streak figure and the sentence, whose shape is the
  streak's state. No widget has a button, a capsule or a card count; the whole widget opens the stream. VoiceOver reads each
  widget as one element, the sentence with the state.
  - Small: the ring (56 pt) with the Day streak figure beside it, the sentence under them (caption2, up to two lines).
  - Medium: the ring (96 pt) at the left; at the right Day streak, the next moment and Words learned
    (`TodayFigures(size: .compact)`: label caption, value headline rounded), without the week.
  - Circular: the system gauge, in its middle the minutes of the next step ("2" over a small "min", "<1"), a `checkmark`
    once the ring is closed, nothing without a price.
  - Rectangular (lock screen): the ring (44 pt), beside it the streak line (caption semibold) and the sentence (caption2, up
    to two lines).
  - Inline (`accessoryInline`, over the lock screen's clock): the flame and the short form of the sentence, "12 · ≈ 2 min",
    "12 · Done" when nothing is left, the days alone without a price; with no streak the sentence, with no flame. Before the
    first snapshot: "Open Mnemit to start".
  - Tinted, clear and vibrant renderings (`widgetRenderingMode` not `.fullColor`): the ring is flat, one tone with its track at
    0.25 against the arc at 1.0 (`ProgressRing.isFlat`); a ring past its goal shows its lap as a number, "2×", in its middle
    (`DailyRingFigure.laps`); the ring, the values and a flame that is not an outline are `widgetAccentable`. Not verified on a
    device or in the real system tint.
- Data travels as one snapshot `WidgetSnapshot` (`Shared/Widget`): date, done cards and the day's
  goal, streak and whether the ring is closed, whether the streak is at risk (`isStreakAtRisk`), the week
  (`week`: seven entries, today last, true a closed ring, false an open one, null before the first study day; `weekRings`: the
  share of each day's goal, which the widget's week draws),
  rounds (`rounds`, `roundsDone`, `minutesToNextRound`), the price of a card left (`secondsPerCard`; the
  forecast holds only card counts per hour, so the snapshot keeps one price), the day's seconds (`daySeconds`, optional: with it
  the goal of a day that begins after the snapshot is the cards of the plan that fit those seconds, and the streak step has its
  two minutes; without it the goal is the plan), a forecast of how many cards are
  in the plan for each hour 48 hours ahead across all decks, and the time of the next reminder
  (`Reminders.nextFire`). `isStreakAtRisk` and `week` are optional and left out of the JSON when nil: an older
  snapshot decodes as not at risk with no week, and an older widget ignores the keys. `wordsInMemory` and
  `wordsToday` are still in the snapshot; the widget shows neither. `wordsLearned` and `wordsLearnedToday` (optional) feed the
  medium widget's third figure: a snapshot without them leaves it out, and the gain is nil after the snapshot's day while the
  words stay.
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
| The answer buttons | two wide buttons, Forgot and Good (Don't know and Know on a first showing); Hard and Easy by swipe, or as buttons with the setting Hard and Easy Buttons | the same, each with its arrow as a keycap (← and →); keys 1 and 3; 2 4 ↓ ↑ grade Hard and Easy; the same setting in Preferences |
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
- **Today page** (`TodayPageContent`): no large title; the window's title bar holds "Today" and the date (`todaySubtitle`).
  The iPhone's Today card (`TodayCard`) on `Color.tileGround` (radius 16, at most 560 pt wide) as a button to Progress, and the
  day's one button under it, `DayAction` (Study in the accent, Catch Up or Learn 10 New Words grey; extra large, the default
  action; also in the toolbar). Without a deck: `EmptyTodayCard`, **New Deck** (prominent), **Shared Decks** (bordered) and
  **Use iCloud Drive Folder** as a footnote-size link under them. The medals of earlier days this Mac never celebrated come once
  as toasts, and the month's sheet (`MonthRecapSheet`) shows on the first open of a month, its See All Progress opening
  Progress. The window reads the folder again when it becomes key and every minute.
- **Progress page** (`ProgressPage`): the iPhone's `ProgressScreen` over every deck (the streak card, the totals Days studied, Rings
  closed, Words learned and Your ring sharing one card, the calendar, Medals, the words in memory in the Memory section), with How It Works as a
  sheet (`HowItWorksSheet`, 520 x 640, Done).
- **A deck's page** (`DeckPage`, `DeckPageContent`): the strip, then the Cards table or the Statistics. The strip holds the
  deck's Today card (`DeckTodayCard`, as the iPhone's deck screen: "≈ 4 min" with Due, New and Learning beside it, the time left
  out until the ring is worked out; or a check and "Done" with "Next review tomorrow"; or "Paused") and **Study This Deck**
  (prominent, large) while the plan has cards left in the deck, else **Learn 10 New Words** (grey); the same button is the last
  toolbar item, after Add Cards and Learning Options, behind a fixed spacer. Toolbar: the segmented Cards | Statistics in the
  middle, Add Cards and Learning Options, and on Cards the Details button. Sheets: Learning Options, Add Cards and the
  preview of an import, the two that offer Study These Now (a stream over the deck once the sheet has gone); an empty deck opens Add Cards by itself, once. A deck still being read shows a spinner, with "Downloading from iCloud…" under it while the file is still arriving (iPhone);
  one that cannot be opened says why (a deck of a newer version also says to update Mnemit), with Try Again. An error of a deck (autosave, read) is a sheet of the window, never
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
  after it, the day's ring (empty inside) and the minutes to the next moment of the day as the iPhone's
  bar says them (`NextStep`: "≈ 4 min"; none once all is done), then Undo and the menu "More" (`StreamMenuItems`, the iPhone's: Edit Card, Card Info, Suspend Card, Pronounce
  Automatically, disabled at a rest); Show Answer prominent in indigo with a keycap "Space or ↩". The bar of
  the last answer (`UndoChip`) stays under the header. The rests are the iPhone's `StreamRestView`, titles included
  ("Ring closed", "All done for today").
  - Keys: Space or Return show the answer; then ← Forgot, ↓ Hard, → Good, ↑ Easy (the iPhone's swipes;
    `Grade.arrowKey`), 1–4 also grade, Return and Space mean Good, Esc, Z and ⌘Z undo, S pronounces, ⌘E edits
    the card. Each answer button shows its arrow as a keycap (`KeyCap`); the ring on Good marks Return. Done
    has no shortcut.
  - The answer buttons are the iPhone's two wide buttons, **Forgot** (←, key 1) and **Good** (→, key 3), **Don't know** and
    **Know** on a first showing, each with its arrow keycap; with Hard and Easy Buttons on in Preferences a later showing has
    the four. Return and Space mean Good (Know); ↓ and 2 give Hard, ↑ and 4 give Easy, with a button or without.
  - The leech moment (`LeechMomentView`) stops the stream after the Forgot that makes a leech: Return continues, E edits, S
    sets aside or keeps.
  - Edit Card opens `CardEditSheet`; Card Info a sheet with the card list's inspector
    (`MacVocTrainNg/Views/Session/CardInfoSheet.swift`), whose Edit swaps it for the edit sheet.
  - At the end of a deck's plan, while another deck of the day has cards left, the rest's first button is
    "Study Greek B1 · 14 cards" (`NextDeck`): it ends this stream and starts that deck's, the sidebar still
    away; a stream from Today mixes the decks of the day from the start.
- The Mac's stream is the iPhone's `StudyModel` (`Shared/Session`) under `SessionViewModel`, whose stages are
  asking, revealed and resting: `Shell.study` opens the decks of the run, the stream starts once every deck
  is read, each card comes from the deck whose next card is most urgent, and Undo (Z, Esc, ⌘Z) takes back the
  last step in its own deck. Medals earned by a grade come as toasts under the bar (`MedalToasts`).
