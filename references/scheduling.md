# Scheduling and the day's stack

Today's counts and limits, introductions of new words, reviews, leeches, the automatic FSRS refit, the
day's stack (Study), Learn 10 New Words and the practices. Terms: `GLOSSARY.md`; the day's goal, rounds and ring:
`references/daily-ring.md`.

## Today's counts and daily limits

- The "today" numbers (New · Learning · Review, plan size, next date) come only from
  `StudySession.counts(for:at:calendar:)`. It selects like the day's plan, so the numbers of Today's
  deck rows, of the deck screen and of the Mac's windows match what the stream will take: the whole plan.
  `cardsPerSession` doesn't count.
- The limits `newCardsPerSession` and `newProductionPerSession` apply per study day (it turns at 4 am);
  the names stay for `deck.json`. A card whose first review fell on the current day is subtracted from
  the limit, so entering the stream again takes no new cards beyond the limit, and the next day restores
  the full count.
- A deck row on Today reads the whole deck including `reviews.jsonl` (`KnownDeckCounts` through
  `DeckFileReader`), as the document on the deck screen does: only the log knows the cards started
  today, and counting from `deck.json` alone (`DeckFile.decode(_ data:)`) showed the full limit.
- The `deck-from-tsv` flags `--new-per-session` and `--new-production-per-session` keep the old names
  too and set the daily limit.
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

## Introductions

- A new word's first showing is an introduction, not a review (ADR 0006). The mark is
  `LearningOptions.introducesNewCards` (`deck.json` key `introducesNewCards`, left out while off, no
  `DeckFile.currentVersion` bump; an older app drops it on save). Options and New Deck call it **Words in
  this deck**: New words (on) and Words I know (off, also what a deck without the key reads as).
- In a deck with the mark on, `StudySession` takes the cards that are new when a segment starts
  (`Urgency.new`, no learning state) as the cards to introduce (`Session.isIntroduction` is true while
  one is current). A learning or review card is never introduced; practices (`Practice`, the practice
  stages of `StudyStream`) never introduce.
- An introduction is shown with the answer open and gives no grade: `SessionMode.grade` and
  `StudySession.review` return nil for it. Moving on is `StudyStream.introduce(duration:)`. It writes no log
  entry, sets no learning state and takes no step (`stepCount`), so Undo after an introduction goes back to
  the previous graded card.
- The card is then held out of the rotation (`SessionQueue.hold`, `introductionGap` = 3) and asked as a
  normal question after three other cards, or next when none is left. Its first grade sets the FSRS
  initial state, and the introduction's time on screen (`Session.introductionTime`) is added to that
  review's `ms`, so the pace prices the time of reading the word.
- The session's total and `completedCount` stay as they are through an introduction: the card is still to
  do. A stream that ends between the introduction and the question leaves the card new, and the next stream
  introduces it again. A card counts against the day's new-card allowance when its first grade is logged.
- Across decks, `StudyModel.introduce()` counts the introduction as a new card asked for taking turns
  between the decks (`mostUrgentLane()`); `grade(_:)` refuses an introduction and counts the new card once.
  The first card of a stream, and a card that comes after a rest, Undo or Redo, arrives with the stage
  `.revealed` when it is an introduction.
- Tests: `IntroductionTests` (VocabCore).

## Leech

- `LearningOptions.leechThreshold` (8 lapses, 0 = off). A lapse that brings `lapses` to the threshold
  or any later multiple of it is turned into a suspend by `StudySession.review` at once (both apps, one
  undoable `DeckChange`); the card leaves the session and `GradeReceipt` says "leech, suspended".
- There is no flag in the file: `Card.isLeech(threshold:)` derives from `lapses`, so the Difficult
  filter shows resumed cards too, and merges need no new rule.

## Automatic FSRS refit

- `ParameterRefit` in VocabCore, `ParameterRefitter` in `Shared/Document`.
- When: the first fit once the deck has `FSRSOptimizer.minimumReviewCount` (400) usable reviews, the
  second at 1,500, then at most once in 30 days or after 1,000 new reviews, whichever comes first. A
  deck that arrives with a long log is fitted once right away.
- The judge is a time holdout: the optimizer learns on the oldest 80 % of reviews, and the current and
  new parameters are scored by log loss on the newest 20 % (`FSRSOptimizer.compareOnNewest`). The new
  ones stay if their log loss is lower than the current one by any amount (`requiredImprovement` = 0;
  that constant is the threshold); otherwise the parameters stay and the attempt is recorded.
- The manual "Compute from Review Log" compares over the whole log (`compare(with:)`), and the person
  decides.
- State in `LearningOptions`: `lastAutoFit` (date, number of usable reviews, accepted or not) and
  `updatesParametersAutomatically` (default yes). Both keys sit in `deck.json` without a version bump
  and are written only when not at the default.
- The optimizer runs off the main thread at background priority, one deck at a time for the whole app
  (`ParameterRefitter.run`). `VocabularyDocument.applyParameterRefit` applies the result as one Undo step
  "Update Parameters" and drops it if the switch is off or another fit is newer.
- Mac: on opening the document (`DocumentView`), not during the Study stream. iPhone: after launch, once
  Today is read and nothing is open (`StartScreen.canRefitParameters`), `DeckRefits` reads the file of
  each known deck, opens a due one through `OpenDeck`, applies and closes it.
- The switch and the line about the last fit: `ParametersSection` (iPhone: Options → Advanced; Mac: the
  Learning Options sheet).

## The day's stack

What the learner sees and the paths through a day: `learning-flow.md`, "The journey". The mechanics:

- Study opens the day's stack, which ends with the plan; there are no sessions (`StudyStream` in
  VocabCore, driven by `SessionDriver` in both apps). Every review is written at once, and leaving loses nothing.
- Within the plan the stream rests twice a day at most (`StudyStream.roundRest`,
  `restAtRoundEnd(roundsDone:rounds:)`, `continueRound()`): at the end of the first round ("Streak
  kept", Keep Going or Done for Now) and at the end of the last while the plan has cards beyond the
  goal ("Ring closed", Catch Up or Done). The segment stays in place.
- The rest is a state of the same stream: `isResting` is true on it, `StreamRest.roundEnd` carries the
  round, `roundsPassed` holds the rounds passed, all inside the value. So Undo across a round boundary
  brings the card back and lifts the rest, and Redo finds it again.
- `SessionDriver` looks for the boundary on every move: `RoundGuide` (`DailyProgress.roundEnds` and the
  cards done in other decks when the stream opened; the apps take it from `DailyRingModel.progress`)
  plus the done cards of the live document (`Deck.doneCards`). Without a `RoundGuide` (progress not
  computed yet) and in practice the stream doesn't rest.
- While resting there is no card (`currentCard == nil`): speech doesn't say the hidden word, and grades
  and Suspend are refused (`StudyModel.isRoundRest`).
- The stack is the day's plan (`StudySession.counts`, same selection and limits, every card due, overdue
  ones included; while the plan is not empty it is recounted after every segment). When it is empty the
  stream rests for good: "Ring closed" (or "Done for today") with Done and, while a deck has new cards
  left, Learn 10 New Words.
- Learn 10 New Words is the only way past the end: `addNewCards(_:)`, `StudyStream.newCardChunk` (10) new
  cards beyond the limits. Over several decks `StudyModel` shares them out one at a time to the deck that
  has given the fewest new cards (`pushOnCounts`), and the stack asks them mixed (`mostUrgentLane()`). It
  puts every round behind the stream (`roundsPassed = .max`): its cards lie beyond a closed ring, and no
  rest of a round comes after them. Today's button of that name (`StudyModel.Entry.pushOn` on the iPhone,
  `SessionViewModel.Entry.pushOn` on the Mac, from the Today window and the deck window's toolbar; the
  code keeps the old name) opens the stream with the ten cards at once, without the plan-end rest first.
  In a deck marked New words these cards are introduced like any new card.
- Undo runs through the whole stream: the `UndoCompanion` snapshot is the whole `StudyStream` value.
- "Practice Mistakes" and "Practice Newest Words" are entries to separate streams
  (`practicingMistakesIn:`, `practicingNewestWordsIn:`) from the deck screen and the Mac's menu; they
  change no card, practice once and end in a pause with the results.

## Newest batch

- `Deck.newestBatchIDs`: the cards with the same `created` (to the second) as the newest card of the
  deck, without suspended ones. `deck-from-tsv` sets one `created` per run.
- Practicing the batch doesn't touch the schedule. Mac: Study ▸ Practice Newest Words
  (`SessionViewModel(entry: .practiceNewest)`); iPhone: the deck screen's ⋯ menu
  (`StudyModel(entry: .practiceNewest)`).
- A card added by hand later starts a batch of its own.
