# Scheduling and the study stream

Today's counts and limits, revealed reviews, leeches, the automatic FSRS refit, the endless Study
stream and its practices. Terms: `GLOSSARY.md`; the day's goal, rounds and ring:
`references/daily-ring.md`.

## Today's counts and daily limits

- The "today" numbers (New · Learning · Review, plan size, next date) come only from
  `StudySession.counts(for:at:calendar:)`. It selects like the day's plan, so the numbers on the deck
  screen, in the toolbar and in the status line match what the stream will take: the whole plan.
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
- `Deck.dueCount` counts every untouched card; don't feed it to the Study button or count rows.

## Revealed reviews

- `.revealed` reviews (flashcards: the whole iPhone app and the Mac in Flashcards mode) are the main
  signal in the fork, as in Anki. `LearningOptions.revealedRecallWeight` (1/3…1, default 1) replaced the
  fixed third of ADR 0004; `optimizeFromRevealed` (default `true`) lets these reviews into the optimizer
  as targets.
- Back to ADR 0004: weight 0.33 and the switch in Learning Options (ADR 0005).

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

## The Study stream

- Study opens an endless stream; there are no sessions (`StudyStream` in VocabCore, driven by
  `SessionDriver` in both apps). Every review is written at once, and leaving loses nothing.
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
- Order:
  1. The day's plan (`StudySession.counts`, same selection and limits, every card due, overdue ones
     included; while the plan is not empty it is recounted after every segment).
  2. Pause "Done for today": plan size, share recalled, "Ring closed" if the ring is closed, "+N words
     in memory today", next date; buttons "Keep Going" and "+10 new".
  3. Practice that doesn't touch the schedule: `Deck.mistakes(onDayOf:calendar:)`, then
     `Deck.newestBatchIDs`, round and round.
- New cards beyond the limit come only through `addNewCards(10)`, with the line "≈ +N cards/day next
  week" (cards per day next week; `NewCardLoad`: an FSRS simulation, every grade Good, no lapses, a due
  day is one review and one plan card).
- Undo runs through the whole stream: the `UndoCompanion` snapshot is the whole `StudyStream` value.
- "Practice Mistakes" and "Practice Newest Words" are entries to separate streams
  (`practicingMistakesIn:`, `practicingNewestWordsIn:`); they end in a pause with the results.

## Newest batch

- `Deck.newestBatchIDs`: the cards with the same `created` (to the second) as the newest card of the
  deck, without suspended ones. `deck-from-tsv` sets one `created` per run.
- Practicing the batch doesn't touch the schedule. Mac: Study ▸ Practice Newest Words
  (`SessionViewModel(entry: .practiceNewest)`); iPhone: a row in the deck details sheet
  (`StudyModel(entry: .practiceNewest)`).
- A card added by hand later starts a batch of its own.
