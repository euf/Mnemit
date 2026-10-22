# Screens: Today, deck, card browser, pause, onboarding, widget

The screens around Study. The contract of every screen: `references/flows.md`; the visual spec:
`references/design-spec.md`; the Study screen itself: `references/study-screen.md`.

## Today (iPhone)

- The iPhone starts on Today (`StartScreen` holds the state, `TodayScreen` draws).
- Title: the day's next goal. Before the first round "≈ 2 min to keep your streak", then "N cards left ·
  ≈ M min", once the ring is closed "Ring closed"; without cards "All done" or "Nothing due". Rounds never
  show (`learning-flow.md`).
- Second line "M of K cards · N left": done cards against the day's goal, and the plan's cards not done
  yet, not raw due. M, N and K are one unit, M + N ≥ K, equal while the plan fits the day's time and
  nothing was added to it; Forgot doesn't break it.
- "+N to catch up this week" when there is a backlog. Streak "N-day streak", with "· kept today" once
  the first round is done.
- Words in memory on one line "≈ 28 words in memory · +15 today" under the ring, as wide as the row
  (`MemoryLine`: the row's width, not the column next to the ring, where the gain doesn't fit on 375 pt;
  at large text sizes the single text wraps).
- Ring and streak cover all decks; decks are rows. Study opens the stream with one tap over the screen
  (`StudyRunView`).
- Search on Today (`AllCardsSearch`) reads the files of all decks without opening them;
  `CardSearchIndex` also searches the word key. A result pushes `CardDetailScreen` on the deck opened by
  slot.
- The "+" menu: Add Cards into the last used deck (`KnownDecks.last`: studied or added to), New Deck
  (into the deck folder; without one, into the app's Documents).
- Undo of edits: `UndoWatch` (a bar button while there is something to undo) and shake (`StartScreen`,
  when no sheet is open).
- The card from the stream (`CardInfoSheet`) is the same `CardDetailScreen`.

## Study across decks

- Study without a deck is one stream over all active decks with a plan. `StudyRun` opens them all,
  `StudyModel` holds one `SessionDriver` per deck, a "lane".
- Each card comes from the lane whose next card is most urgent: a card in learning, then the review
  with the lowest recall probability, then a new card from the lane that gave fewer new ones.
- The grade goes to the card's deck; Card Info and Undo go to the card's deck too (`stepLanes` remembers
  each step's deck). Rounds count what was done in all lanes (`SessionDriver.setDoneElsewhere`); the
  stopwatch runs only in the lane whose card is on screen.
- "Done for today" shows when the plan has ended in every deck. Study This Deck is the same model with
  one deck. Tests: `MultiDeckStudyTests`.

## Deck screen

- A deck row pushes the deck screen onto Today's stack (`DeckScreen`/`DeckContent`: the day's counters,
  Study This Deck, Cards → browser, Add Cards, practices, Statistics, Options; menu: Rename…, Delete
  Deck).
- `PushedDecks` keeps the stack's decks open: it opens one when a route is pushed (`DeckRoute`, the deck
  named by slot, not by file, so a rename doesn't change the route) and closes it when the route leaves
  `path`. Screens above (`CardBrowserScreen`, `CardDetailScreen`, options) show one document.
- Study This Deck runs on the screen's deck (`StudyRun(ownsDeck: false)`: the stream doesn't close it;
  after the stream `undoManager.removeAllActions()`, so the browser's Undo doesn't roll back reviews).
- Rename and Delete close the deck before `DeckFiles.rename`/`trash` and update `KnownDecks` (`replace`,
  `forget`).

## Card browser

- Filters **All · Due · New · Learning · Suspended · Difficult**, the same names in both apps. Rules in
  `CardFilter` (VocabCore: `matches`, `Deck.filterCounts(at:)`): Due, New and Learning exclude suspended
  cards, Difficult includes them; a suspended card is only in All, Suspended and, if a leech, Difficult.
  Titles: `CardFilter.title` in `Shared/Support/Presentation.swift`.
- Search (`CardSearchIndex`) looks into `note` too.
- iPhone: sorts `BrowserSort`; the logic is in `CardBrowserList`, without a screen and with tests.
- Mac: a segmented control `ScopeBar` above the table with a count in each segment (`searchScopes` on the
  Mac live only during a search, and the filters must always be visible). The Kind column sorts by
  `CardRow.kindRank`. The inspector links to the sibling (`Deck.siblings(of:)`). The edit sheet changes
  the word key through `VocabularyDocument.setNote` (`DeckChange.settingNote`, kind stays) and hides it
  while the session still asks the card: the key of a "translation → Greek" card is the answer.
- On macOS 27 a click on a `Table` row selects the row but takes no focus (`NSTableView.mouseDown` is
  not called; measured with a live click on 22.10.2026), and the form field stays first responder:
  Delete, ⌘E and the arrows go to it. `TableClickFocus` (the table's background) moves focus into the
  table after a mouse click on it; a selection that changes by itself doesn't touch focus.

## Pausing a deck

- `LearningOptions.isPaused`; the key `paused` in `deck.json` is written only when true, same format
  version: an old build drops the key and the deck is active again. The key travels with the options and
  merges by `learningOptionsChanged`, later wins.
- A paused deck is in none of: plan, goal, rounds, capacity, allowance (the other decks share it),
  streak, words in memory, widget, reminders, Study. `DailyProgress.evaluate` and `DayBreakdown` skip
  `DeckActivity.isPaused` (such a deck's place in `newCardAllowances` holds 0; `DailyRingModel` gives it
  no allowance, and its plan follows its own limits). `KnownDeckCounts` counts no cards for it and keeps
  it in `paused`; `TodayDecks` splits Today's sections and the Study queue (`studyQueue`); its stream has
  no `RoundGuide`.
- The deck still opens: screen, browser and Study This Deck work, and reviews are written as always,
  but they reach the ring only through cards of active decks.
- Today row: swipe and context menu "Pause Deck" / "Resume Deck" (`pause.circle` / `play.circle`;
  `OpenDeck` opens the file, `VocabularyDocument.setPaused` changes it, then it closes). Paused decks sit
  in a "Paused" section at the bottom, grey, without counts, subtitle "Paused"; the deck screen menu has
  the same item. Mac: Study ▸ Pause Deck / Resume Deck; ring and tooltip count open documents that aren't
  paused.
- "How Today Works" names it in the plan with the line "Paused: <name>".
- After resuming, its overdue cards are backlog under `DailyGoal.backlogShare`, with no special rules.

## Accent

- The system indigo `#5856D6` in `AccentColor` (all three asset catalogs: iPhone, Mac, widget): button
  fill, ring, glyph, never text.
- A glyph in a sheet uses `Color.appAccentOnRaised`: in dark mode a sheet raises surfaces to `#2C2C2E`
  (`#363638` with Increase Contrast), where the accent gives 2.47:1 (2.57:1). Reading the view's
  `userInterfaceLevel`, the colour takes the same hue lighter, `#706FDC` (3.32:1) and `#7B79EA` (3.31:1).
  A button fill with a white label stays the accent; on screen and in the full-screen cover (the Study
  stream) the colour is the plain accent (`AccentContrastTests`).
- The New/Learning/Review counters are neutral.
- Frames: Today and the deck screen in `VocTrainTests/HomeSnapshotTests` (directory
  `TEST_RUNNER_HOME_SHOTS_DIR`); browser, card and edit in `BrowserSnapshotTests`
  (`TEST_RUNNER_STUDY_SHOTS_DIR`).

## First launch, deck folder, reminders, welcome window

- First launch on the iPhone (`OnboardingView`, steps `OnboardingStep`): a welcome with one button →
  swipe practice (`GesturePracticeView`; order and sample cards in `SwipePractice`: ← forgot,
  ↑ instantly, ↓ with effort, → remember; the four meanings are the rules, there is no separate rules
  screen; "Skip" leads to sync) → sync (iCloud Drive: folder picker, `chooseFolder`; "Only on This
  iPhone": `useLocalFolder`, the app's Documents folder without bookmark or scope, in Files On My iPhone
  ▸ Mnemit) → reminder.
- A single deck opens through "Open Deck…" in the start screen's menu.
- Deck folder. iPhone: `KnownDecks.chooseFolder` (a folder bookmark; its decks are listed;
  `refreshFolder` on pull-to-refresh and on coming to the foreground; an empty folder is accepted only if
  named `Mnemit`). Mac: `DeckFolder` (a scoped bookmark, entitlement `bookmarks.app-scope`).
- Reminders: `Reminders`, local notifications 7 days ahead, each day with its own numbers from
  `StudySession.counts(for:at:)`, the number on the badge; recomputed on going to the background, after
  closing a deck and on a time change.
- The Mac welcome window: `AppDelegate` and `WelcomeWindow` (to turn it off:
  `defaults write <bundle id> showsWelcomeWindow -bool NO`).

## Widget

- Target `MnemitWidget`, folder `MnemitWidget/`, bundle id `com.euf.mnemit.ios.widget`, embedded in the
  iPhone app. Home screen small and medium, lock screen circular and rectangular; a tap goes through
  `mnemit://study` straight into the stream (`StartScreen.open`).
- Data travels as one snapshot `WidgetSnapshot` (`Shared/Widget`): date, done cards and the day's goal,
  streak and whether the ring is closed, rounds (`rounds`, `roundsDone`, `minutesToNextRound`), words in
  memory (`wordsInMemory`, `wordsToday`; optional fields, an old app's snapshot still reads and shows "N
  cards left"), the price of a card left (`secondsPerCard`), a forecast of how many cards are in the plan
  for each hour 48 hours ahead across all decks, and the time of the next reminder
  (`Reminders.nextFire`).
- The app writes its JSON into a keychain item of the shared group
  `$(AppIdentifierPrefix)com.euf.mnemit.shared` (`KeychainSnapshotStore`, `AfterFirstUnlock`). There are
  no App Groups: the free Personal Team gives only keychain sharing. One `VocTrain/Mnemit.entitlements`
  is the `CODE_SIGN_ENTITLEMENTS` of both app and widget, and the iPhone signing script must sign both
  bundles with it. The team prefix is never written in code: it is read from the group the keychain
  puts an item without a group into.
- `WidgetSync` writes the snapshot (after a review, at launch, on a change of decks or reminder, at once
  on going to the background; a 2 s pause glues a series of reviews together), then
  `reloadAllTimelines()`; under tests it is off.
- The timeline (`WidgetSnapshot.timeline`) puts entries at the forecast hours, at the start of the next
  study day (4:00, not midnight: the ring resets then) and at the reminder time. While the snapshot isn't
  updated, the streak holds through one missed day.
- The widget target builds all of `Shared` (that's where `DailyRingView`, everything it needs and the
  string catalog live): a new file in `Shared` with nothing to do in an extension
  (`UIApplication.shared`) must be excluded from its membership.
- Frames: `VocTrainTests/WidgetShotsTests` (`TEST_RUNNER_STUDY_SHOTS_DIR`).
- `PRODUCT_BUNDLE_IDENTIFIER=…` on the `xcodebuild` command line overrides the widget's bundle id too.
