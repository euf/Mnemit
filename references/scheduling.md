# Scheduling and the day's stack

Today's counts, which new cards the day takes, a new card's first showing, reviews, leeches, the automatic FSRS refit, the
day's stack (Study), Learn 10 New Words and the practices. Terms: `GLOSSARY.md`; the day's goal, rounds and ring:
`references/daily-ring.md`.

## Today's counts and daily limits

- The "today" numbers (New · Learning · Review, plan size, next date) come only from
  `StudySession.counts(for:at:calendar:)`. It selects like the day's plan, so the numbers of Today's
  deck rows, of the deck screen and of the Mac's windows match what the stream will take: the whole plan.
- How many new cards a deck takes is the ring's allowance (`DailyGoal.newCardsAllowed`, `references/daily-ring.md`),
  unless the deck sets **New cards/day** (`newCardsPerSession`, Anki's name; Auto by default, the ring decides). A deck that sets it takes
  exactly that many new cards of both directions per study day (it turns at 4 am), as in Anki: outside the allowance, and
  without reducing what the other decks get. A card whose first review fell on the current day is subtracted from the
  count, so entering the stream again takes no new cards beyond it, and the next day restores the full count.
- **Maximum reviews/day** (`maximumReviewsPerDay`, Anki's name; No limit by default, every due review is asked) caps the review
  cards of the plan, in `StudySession.selection`, so the counts, the plan, the goal and the stream follow. At most that many
  cards in the review phase a study day: Cards in learning or relearning and new cards are no part of it. The review
  cards already reviewed on the current study day count against it (`StudySession.reviewsDone`: for each card reviewed
  today, its log is replayed from the grades to tell which reviews asked it in the review phase,
  `Card.reviewPhaseReviews`; a lapse counts, the relearning after it does not). The due reviews beyond the cap are not in the
  plan: they wait, as buried cards do, and come back on the next study day, the most urgent first (lowest recall
  probability, as the plan orders them). New cards/day and the allowance don't change. The plan of a past day is the
  plan at its start, with nothing reviewed yet. `deck.json` holds the key as `null` while unlimited; a missing key reads as
  unlimited, and an older app version drops the key on save. Range 0 to 9999; 0 is a review-only stretch.
- A `deck.json` that still has `cardsPerSession`, `newProductionPerSession` or `productionUnlockDays` reads, and the next
  save leaves the keys out.
- A deck row on Today reads the whole deck including `reviews.jsonl` (`KnownDeckCounts` through
  `DeckFileReader`), as the document on the deck screen does: only the log knows the cards started
  today, and counting from `deck.json` alone (`DeckFile.decode(_ data:)`) showed the full limit.
- The `deck-from-tsv` flag `--new-per-session` sets New cards/day.
- The counts of the card filters and of the Statistics tiles (Due, New, Suspended) are
  `Deck.filterCounts(at:)`: Due is due now, not new and not suspended; New is new and not suspended;
  Suspended is suspended. `Card.isDue(at:)` is the study session's own test, where a new card is due;
  don't feed it to a count that the learner reads as "Due".

## Reviews

- Both apps study one way: the question, Show Answer, a grade. There is no typed answer, no response
  checker and no review mode to choose; the Mac's stream has the stages asking, revealed and resting
  (`StudyModel.Stage`). Every review the app logs is `.revealed` (`StudySession` and `StudyStream` default
  to it). `ReviewMode` and the `mode` key stay in the log format so that a typed review of an upstream deck
  reads, and the card's history marks it "Typed"; `Scheduler.review` and `ReviewLogEntry` default to
  `.typed` for tests and for replays of old logs.
- A revealed review counts in full: a Good gains stability like any Good in FSRS. There is no damping
  weight (`revealedRecallWeight`, `stabilityGainShare` and `MemoryModel` are gone; ADR 0004 is superseded
  by ADR 0005). The refit learns from every review on a later study day than the previous review of the
  same card.
- A deck file that still carries `revealedRecallWeight`, `optimizeFromRevealed` or `caseSensitive`
  decodes; the next save leaves the keys out, and an older app reads their defaults.

## A new card's first showing

- A new card (`Card.isNew`, no learning state) is asked on its first showing like any card: question, Show
  Answer, then the answer buttons (Don't know and Know; Hard and Easy stay open as swipes and keys). Nothing is shown first and
  nothing is held back (ADR 0007).
- Its first grade sets the FSRS initial state S0 and D0 and is no lapse (`Scheduler` counts a lapse only in the
  review phase). A first Again puts the card into its learning step; it comes back in the session and is no
  longer new. `references/first-exposure-research.md` has the numbers.
- The grade underneath is Again; its name is **Don't know** while the card is new and **Forgot** afterwards
  (`Grade.buttonTitle(isNew:)`): the grade button (`GradeChoice.isNew`), the receipt chip and its VoiceOver
  announcement (`GradeReceipt.isNew`, set by `SessionDriver.grade`), the iPhone Card Detail history and the Mac
  inspector's history, where the Again of a card's first log entry reads Don't know. Position, key, swipe and
  colour are the same.
- A `deck.json` that still has the retired key `introducesNewCards` reads, and the next save leaves it out.

## Leech

- **The moments.** `LearningOptions.leechThreshold` is T (Leech threshold on the options screens: 8, as in Anki; 0 = Off). What counts is every Forgot but the first
  answer of a new card, in the review phase or not (`Card.forgotCount`: the Forgots of the log, or the stored `lapses` when
  an imported log holds fewer). The Forgot that brings the count to T is a leech moment, and so is every Forgot that brings it to
  T + k × ceil(T / 2) for k ≥ 1: T = 8 gives 8, 12, 16, 20; T = 5 gives 5, 8, 11 (`StudySession.isLeechMoment(lapses:threshold:)`).
  A moment comes only with a Forgot, so a card that is a leech by its old log meets its moment at its next checkpoint.
  `Session.leechIDs` holds every moment, whatever the action. In the stream a moment is a stop that keeps the answer on
  screen (`study-screen.md`).
- **Keep Card or Suspend Card.** The options screens call it Leech action. `LearningOptions.leechAction`: `.keep` (the default) leaves the card in rotation and FSRS goes on
  scheduling it; `.suspend`, Anki's classic action, makes the review suspend the card (`StudySession.review`), which leaves the
  session. The deck options offer the two as a picker. `deck.json` key `leechAction` is `"suspend"` and left out while keep
  (`deck-package.md`).
- **The moment's actions.** Edit, Suspend Card and Continue. Suspend Card suspends the card (`SessionCommand.setAside(id)`, an
  undoable step like `.suspend`: the session counts the card as suspended, not done). Where the review already suspended the
  card (Suspend), the button is Keep Card (`SessionCommand.keep(id)`): it resumes the card and the session asks it again. Undo of
  the grade takes back the moment and any suspension.
- **No flag in the file.** `Card.isLeech(threshold:)` derives from the Forgot count (`forgotCount >= T`), so the Leeches filter
  (`CardFilter.leeches`, the title "Leeches") shows resumed cards too, and merges need no rule.
- **Anki import.** `AnkiPreset.leech` carries the preset's threshold and action: Anki's `leech_threshold` (proto field 22) and
  `leech_action` (field 21: 0 suspend, 1 tag only, which is Keep); an older collection has `dconf.lapse.leechFails` and
  `leechAction`. Anki's stock preset is tag only, so a stock import gives threshold 8 and Keep.

## Automatic FSRS refit

- `ParameterRefit` in VocabCore, `ParameterRefitter` in `Shared/Document`.
- The memory model is the learner's: the log a deck is fitted on is the usable reviews of all the decks in the folder
  together (the caller passes their cards), and every deck whose parameters are not its own gets the fit. Parameters
  are a deck's own when they are not the defaults and no automatic fit made them (`ParameterRefit.hasOwnParameters`: an
  Anki preset, "Use New Parameters" on the options screen, which clears `lastAutoFit`); such a deck is left as it is,
  its reviews still in the others' log, and Reset FSRS Parameters hands it over again.
- When: the first fit once the folder has `FSRSOptimizer.minimumReviewCount` (400) usable reviews, the
  second at 1,500, then at most once in 30 days or after 1,000 new reviews, whichever comes first, counted per deck
  from its own `lastAutoFit`. A deck that arrives with a long log is fitted once right away.
- The judge is a time holdout: the optimizer learns on the oldest 80 % of reviews, and the current and
  new parameters are scored by log loss on the newest 20 % (`FSRSOptimizer.compareOnNewest`). The new
  ones stay if their log loss is lower than the current one by more than `ParameterRefit.requiredStandardErrors` (1.5)
  times the standard error of the difference, review by review (`Comparison.standardError`); otherwise the parameters
  stay and the attempt is recorded. Of 60 simulated learners with 430 usable reviews and the deck's own parameters as
  the truth, 18 fits were kept with no margin (17 worse on a fresh log) and 3 with this one.
- The manual "Optimize" compares over the whole log (`compare(with:)`), and the person
  decides.
- State in `LearningOptions`: `lastAutoFit` (date, number of usable reviews, accepted or not) and
  `updatesParametersAutomatically` (default yes). Both keys sit in `deck.json` without a version bump
  and are written only when not at the default.
- The optimizer runs off the main thread at background priority, one deck at a time for the whole app
  (`ParameterRefitter.run`). `VocabularyDocument.applyParameterRefit` applies the result as one Undo step
  "Update Parameters" and drops it if the switch is off or another fit is newer.
- The pool is a `ReviewPool` (`Shared/Document`): decks in memory and decks read from files. Mac: on opening the document
  (`DeckPage`), not during the Study stream, over the other open documents and the rest of the folder
  (`AllDecks.pool(besides:)`). iPhone: after launch, once Today is read and nothing is open (`StartScreen.canRefitParameters`),
  `DeckRefits` reads the files of all known decks once, then opens each due one through `OpenDeck`, applies and closes it.
- The switch, the line about the last fit ("Fitted on N reviews from all your decks"), "Usable reviews N / 400" counted over
  all decks, and the note on a deck whose parameters are its own: `ParametersSection` (iPhone: Options → Advanced; Mac: the
  Learning Options sheet). Optimize there fits on the pool too and applies to this deck only.

## The day's stack

What the learner sees and the paths through a day: `learning-flow.md`, "The journey". The mechanics:

- Study opens the day's stack, which ends with the plan; there are no sessions (`StudyStream` in
  VocabCore, driven by `SessionDriver` in both apps). Every review is written at once, and leaving loses nothing.
  The stream takes the plan in segments of 100 cards (`StudySession.segmentSize`, a constant); a segment doesn't cut the
  plan, and nothing visible grows by segments.
- Within the plan the stream rests twice a day at most (`StudyStream.roundRest`,
  `restAtRoundEnd(roundsDone:rounds:)`, `continueRound()`): at the end of the first round ("Streak
  kept", Keep Going or Done for Now) and at the end of the last while the plan has cards beyond the
  goal ("Ring closed", Keep Going or Done). The segment stays in place.
- The rest is a state of the same stream: `isResting` is true on it, `StreamRest.roundEnd` carries the
  round, `roundsPassed` holds the rounds passed, all inside the value. So Undo across a round boundary
  brings the card back and lifts the rest, and Redo finds it again.
- `SessionDriver` looks for the boundary on every move: `RoundGuide` (`DailyProgress.roundEnds` and the
  cards done in other decks when the stream opened; the apps take it from `DailyRingModel.progress`)
  plus the done cards of the live document (`Deck.doneCards`). Without a `RoundGuide` (progress not
  computed yet) and in practice the stream doesn't rest.
- While resting there is no card (`currentCard == nil`): speech doesn't say the hidden word, and grades
  and Suspend are refused (`StudyModel.isRoundRest`).
- The stack is the day's plan (`StudySession.counts`, same selection, every card due, overdue
  ones included; while the plan is not empty it is recounted after every segment). When it is empty the
  stream rests for good: "Ring closed" (or "Done for today") with Done and, while a deck has new cards
  left, Learn 10 New Words.
- Learn 10 New Words is the only way past the end: `addNewCards(_:)`, `StudyStream.newCardChunk` (10) new
  cards beyond the allowance and every deck's New cards/day. Over several decks `StudyModel` shares them out one at a time to
  the deck that has given the fewest new cards (`pushOnCounts`), and the stack asks them mixed (`mostUrgentLane()`). It
  puts every round behind the stream (`roundsPassed = .max`): its cards lie beyond a closed ring, and no
  rest of a round comes after them. Today's button of that name (`StudyModel.Entry.pushOn` on the iPhone,
  `SessionViewModel.Entry.pushOn` on the Mac, from the Today window and the deck window's toolbar; the
  code keeps the old name) opens the stream with the ten cards at once, without the plan-end rest first.
- Undo runs through the whole stream: the `UndoCompanion` snapshot is the whole `StudyStream` value.
- "Practice Mistakes" and "Practice Newest Words" are entries to separate streams
  (`practicingMistakesIn:`, `practicingNewestWordsIn:`) from the deck screen and the Mac's menu; they
  change no card, practice once and end in a pause with the results.

## Which new cards: one queue, the newest addition first

- The learner's unit is the word: a note (`Card.note`) with its cards. A card without a note is a word with one card;
  a pair is Word → Meaning (`CardKind.recognition`) and Meaning → Word (`CardKind.production`, the internal name of
  the card the screens call Meaning → Word).
- The ring's allowance says how many new cards the decks without New cards/day take; one queue over all decks that aren't
  paused says which. No option orders it.
- New words come newest addition first: the cards added on a later study day come before those of an earlier one;
  within a day they come as they were added, by `Card.created`, then in deck order (`StudySession.newestAdditionFirst`).
- A word's Meaning → Word card opens when its Word → Meaning card is in the review phase with an interval of 7 days or
  more (`StudySession.unlockDays`, a constant). Opened Meaning → Word cards, the oldest learned word first, alternate
  with the new words one for one (`StudySession.alternatingUnlocked`).
- Each deck's share of the day's allowance comes from that one queue: `DailyGoal.split(_:overQueues:)` over each deck's
  `DailyGoal.NewQueue`, kept as `DeckActivity.History.newQueueToday` (`references/daily-ring.md`). The split covers the
  decks without New cards/day; a deck with it gets its own queue's count. Within a deck its own cards alternate the same
  way.
- The unlock interval (7 days, `unlockDays`), the stream's segment (100 cards, `segmentSize`) and the order above are
  constants, no options. New cards/day is the one setting, under Anki's name. Learn 10 New Words goes beyond the
  allowance and New cards/day; Study These Now goes beyond the deck's day, and its cards then take the place of the day's new
  cards: they count against the deck's share of the allowance, or against New cards/day for a deck that has it.
- An addition is whatever puts cards in a deck that day: Add Cards, a list of lesson words, an import, a run of
  `deck-from-tsv`. An imported or shared deck has one `created` for all its cards, so its author's order holds
  (an Anki package in Anki's new-card order, `references/import-export.md`); words typed one by one come in the
  order they were typed.
- Renewing (`DeckChange.renewing(_:in:at:)`) moves cards not started yet into the day's addition, in a given
  order: `created` stamps a second apart that end at the moment of the change. A lesson list in Add Cards renews
  the words of the list the deck holds already (`WordListPreview.renewable(in:)`), so the whole lesson goes first;
  `deck-from-tsv --renew NOTES` does it for a list of word keys. A merge takes the stamps along with the card's
  content (`Card.contentChanged`).

## Newest batch

- `Deck.newestBatchIDs(calendar:)`: the cards whose `created` falls on the study day of the deck's newest card,
  without suspended ones: the same day's addition the order of new cards starts with.
- Practicing the batch doesn't touch the schedule. Mac: Study ▸ Practice Newest Words
  (`SessionViewModel(entry: .practiceNewest)`); iPhone: the deck screen's ⋯ menu
  (`StudyModel(entry: .practiceNewest)`).
