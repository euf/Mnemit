# The day: plan, goal, rounds, ring, streak, pace

How the day is measured, and the screen that explains it. Terms with their Russian equivalents:
`GLOSSARY.md`, section "Mnemit". Code: `DailyProgress` and `DayLedger` in VocabCore, `DailyRingModel` and
`DailyRingView` in `Shared/Session`, `ProgressLedgerStore` in `Shared/Document`.

## Principle

- Today (the ring, the plan, the goal, the pace) comes from the review log (`reviews.jsonl`) of the active decks. The days
  before today come from the progress ledger, one record per study day (next section). A deck stores no ring and no streak.
- The day is measured in cards: the ring, the goal and the streak count cards; the screens translate
  cards into minutes ("≈ 2 min", an estimate at the learner's pace; `product-model.md` §3). A review (one grade of one card) counts toward neither the goal, the ring nor the
  streak; reviews are for the optimizer, statistics and pace.

## The ledger: past days

- A study day, once over, is a record (`LedgerDay`, `Packages/VocabCore/Sources/VocabCore/Statistics/DayLedger.swift`):
  `day`, `reviews` (log entries of the day), `done` (cards done), `goal`, `keepAt` (the cards done that keep the streak:
  the end of the first round, 0 for an empty plan), `kept`, `closed`, `time` (the day's seconds), `reason`
  (`DailyGoal.SizeReason`), `worked` (seconds of the cards done at the day's prices), `filled`, `wordsLearned` (cumulative at
  the day's end). A missed day has a record too, done 0, so a later pause cannot turn its empty plan into a kept day.
  `DayLedger` holds one record per day.
- **What reads from where** (`DailyProgress.evaluate(_:at:calendar:planRuleStart:ledger:cache:)`). From the ledger: the days
  before today (the first study day through yesterday), their `records`, `week`, `weekRings`, `ringDays` (the size rule's
  input), `achievements`, and the streak (`Streak.walk`: kept and closed from the records, the ledger's `reviews` for past
  days and the logs' for today). From the logs: today's ring, plan, rounds, allowances, pace and `memory`. Words learned:
  `learned.wordsAtDayStart` is the ledger's cumulative count of yesterday, `learned.words` that plus
  `max(0, logs.words - logs.wordsAtDayStart)`; without a past day the logs' own. The first day is the earlier of the ledger's
  first day with reviews and the logs' first.
- **The raise rule** (`LedgerDay.raised(reviews:done:worked:wordsLearned:)`). Each day before today is its record raised by
  the logs of the active decks. Reviews, done and words take the larger value. `worked` takes the logs' value only when `done`
  rises: a price that changed since (a deck paused or deleted) says nothing of the day. `kept` is true once it was, or once
  done reaches `keepAt`; `closed` likewise at `goal`. `goal`, `keepAt`, `time`, `reason` and `filled` never change. A day
  that is over only rises, when real reviews of it arrive late (the other device's log, an Anki import).
- **`ledgerUpdates`**: the days before today whose record is new or differs from the ledger `evaluate` was given, oldest first,
  today never. A day the ledger lacks (the first run, a missed day) is worked out from the logs and the days before it, and
  is listed there. The app merges the updates into its ledger and writes it (`DayLedger.updating(_:)`).
- **Merge** (`DayLedger.merging`): per day the record with the larger `done`, then `reviews`, `wordsLearned` and `goal`, then
  the smaller encoded line. Commutative and idempotent, so any device can read any file again.
- **File**: JSON Lines, one record per day, oldest first (`DayLedger.encoded()`, `decode(_:)`); keys `day` (ISO date),
  `reviews`, `done`, `goal`, `keep`, `kept`, `closed`, `time` and `worked` (to 0.1 s), `reason` (`start`, `ringClosed`,
  `closedInARow`, `ringOpen`, `smallPlan`, `sustainedOvershoot`; an unknown one reads `ringOpen`), `filled`, `words`. `decode` never
  throws: an unreadable line costs its day only. Where the files live: `deck-package.md`.
- **The app side**: `DailyRingModel.refresh(documents:files:ledger:reloadFiles:delay:)` takes a `ProgressLedgerStore?` (`nil` in
  previews and tests: no ledger, no write). It reads the ledger off the main actor, with the deck files, when `reloadFiles` is set
  or the store changed, and otherwise keeps the last one. After an evaluation with `ledgerUpdates` it writes
  `ledger.updating(updates)` to this device's file. Callers: the Mac's `DailyRingModel.refreshAllDecks`, the iPhone's
  `StartScreen` and `StudyRunView` (the store is `KnownDecks.ledgerStore`).

## Plan

- **Plan**: the cards the day asks for under FSRS (`StudySession.counts`): cards due, overdue too, and
  new cards within the day's limits and the deck's allowance `newCardAllowance`; overdue cards are part
  of it (Backlog below). `nil` instead of an allowance means only the deck's limits: tests and tools count
  that way.
- The plan at the start of a day the logs work out (today, and a past day the ledger lacks) comes from
  `DeckActivity.history(from:at:calendar:)`: the log is
  replayed forward once (`replayLog`, card states at the end of every day), a copy of the deck takes
  each card's state at the start of the day, and `StudySession.counts(... past:)` with
  `DayIndex(lockedNotes:)` gives the day's plan. `ProductionLocks` tracks the production cards' locks
  by transitions; cards created later are not in the plan.
- For today the same is `DeckActivity.plan(onDayOf:calendar:)`: cards reviewed today go back to the
  state of their last review before the day (`Scheduler.replaying`).

## Goal

- **Goal**: the plan's cards at the start of the day (04:00) that fit in the day's time
  (`DayRounds.goal`): learning and review in stream order, then new, priced by pace, no more than the
  day's time in seconds, at least one card when the plan isn't empty. Review cards beyond the time
  (after a break) stay in the plan and are done beyond the goal.
- The goal doesn't change: Add Cards, Study These Now, Learn 10 New Words and Again don't raise it.
- The whole rule is in `DailyGoal` (VocabCore): `goal(done:owed:plan:)` takes the plan at the start of
  the day. The only exception: when the plan has nothing left to wait for (`owed == 0`) and fewer are
  done (cards were suspended or deleted during the day), the goal is the done cards, so the ring doesn't
  stay open next to "0 cards left". A day that started with an empty plan (the first deck, filled during
  the day) takes the plan as it is, `done + owed`, so the first day has a goal.
- A cap on the goal is a change to this type.
- `cardsPerSession` is the stream's segment size and doesn't cut the plan: `counts` doesn't know it,
  and nothing visible grows by segments.

## Streak step

- **Streak step**: the cards of the plan that fit the first 120 s of work at the learner's pace
  (`DailyGoal.streakSeconds`); a card costs the pace of its category. It ends at the first card where
  the cost reaches 120 s, and the goal ends the day (`DayRounds.ends`: at most two ends, one when they
  coincide). The first end is the streak's rest, the last the ring's.
- `DailyProgress`: `rounds` (the number of ends), `roundsDone`, `roundEnds`, `cardsToNextRound`,
  `minutesToNextRound` (at the pace the day started with), `minutes(ofRound:)` (for the rest screen),
  `memory` (`MemoryEstimate` over the decks), `streakKeptToday` (streak step done or the plan empty).
- The step never shows by number (`product-model.md` §3). `DailyProgress.minutesToStreak` gives its minutes while it is
  open, which the sentence (`NextStep`) says: before the step "≈ 2 min to keep your streak", after it "≈ 5 min to close the
  ring". `RoundStatus` (`Shared/Session/DayLines.swift`) carries the three round figures the widget
  snapshot stores.
- In a day that started with an empty plan, the ends cut the cards as they are.

## Day's time

- **Day's time**: the seconds of work the day asks (`DailyProgress.time`), forward from the first study day
  over the days before it (a past day's `LedgerDay.time`), the same on every device, never rounded. The goal is the cards of the plan that fit
  it, and new cards fill what the plan's other cards leave.
- **The rule**, one pure step per study day, `DailyGoal.nextTime(after:)`, over the days before it as plain
  values (`DailyGoal.RingDay`): a staircase and, above it, the sustained-overshoot step (below). The staircase: the last study day (a day with work) asked T (its
  `RingDay.time`); the next time is T × 1.15 (`DailyGoal.grows`, reason `ringClosed`) when its ring was the
  `DailyGoal.closedToGrow`-th (2nd, 4th, …) in a row closed on a goal that filled T, T when it was the first of
  such a run (reason `closedInARow`), T when it closed on a plan smaller than T (`RingDay.filled` false: a deck's
  new-card limit or an exhausted deck set the goal; reason `smallPlan`; such a day neither counts in the run nor
  breaks it), and T × 0.775 (`DailyGoal.shrinks`) when it stayed open, which ends the run; clamped to
  120…3600 s; 150 s before any study day. A day without work is no step, and the days after it ask what they
  would have asked without it. worked(d) is the cards done on `d` at the day's own prices, new × new price +
  other × other price at the pace of the seven study days before `d`, cards beyond the goal included; How It Works shows it.
- **Sustained overshoot** (`DailyGoal.nextTime(after:)`, reason `sustainedOvershoot`): a study day is *past the ring*
  when worked ≥ `overshootRatio` (1.5) × its own time. From the end of the `overshootFromStudyDay`-th (8th) study
  day, when `overshootHits` (3) of the last `overshootWindow` (4) study days are past the ring, the next time is
  max(the staircase's T, the `overshootQuantile` (25th) percentile of those four days' worked, over all four, linear
  interpolation), at most `overshootJump` (1.5) × the last study day's time and at most 3600 s (`timeRange`). The reason is
  `sustainedOvershoot` only where this is above the staircase's T. Study days 1–8 ask the staircase's time alone, and
  rest days are no study days in the window. The work is `RingDay.worked`, the same quantity the sim calls work; the
  staircase's counters (`closed`, `filled`) read the days as before, whatever raised T. A learner who stops at the
  ring never works 1.5 × the time (the goal's cost never exceeds T), so the step never acts for them. The constants are
  named static values of `DailyGoal`, the flags for a rollback; the rule is rule D of `Tools/ring-sim/overshoot.md`,
  and `RingRuleTests` reproduces its numbers on fixed days (342.2, 513.3, 600 s; 475 s with an open day; the hour).
- **Filled** (`DayRounds.filled`): the goal's cost plus one new card's price exceeds T, so the time, not the
  plan, set the goal. A closed ring on a smaller plan says nothing about more time and moves nothing.
- **Why**: `ring-design.md`. The staircase puts the share of closed rings where p² ln 1.15 = (1 − p²) ln(1/0.775),
  0.80, whatever the work, and changes the ring on half the study days; the overshoot step is what lets a learner who
  goes on every day see fewer laps (`product-model.md` §8, `Tools/ring-sim/overshoot.md`: Double ring on 26 % → 16 % of
  days synthetic, 50 % → 25 % real, at a closure of 0.75 / 0.70). How It Works names the direction only
  ("Ring closed", "Ring open", "Plan under the time", "Past the ring"), never the rule.
- Model learners (`RingRuleTests`): one who stops at the ring asks 150, 150, 172.5, 172.5, 198.4 s …, 150 × 1.15^⌊(d − 1)/2⌋
  on study day d; one who works less than the ring asks falls to 2 minutes on day 2 (150 × 0.775 = 116.25 is under
  the floor) and holds there; a ring closed on a small plan keeps its time; a day without work changes nothing; one who
  works 600 s every day asks 150 … 228.1 s on days 1–8, then 342.2, 513.3 and 600 s (the jump limit, then the percentile).
- `DailyProgress.ringDays` holds every day's `RingDay` (time, reason, work, ring, filled), the days before today from the ledger and today live, and
  the reason is `start`, `ringClosed`, `closedInARow`, `smallPlan`, `ringOpen` or `sustainedOvershoot`; `DailyProgressCache.Before.days` keeps the
  days before today.

## New-card allowance

- **Allowance**: the day's time minus the plan's non-new cards at the start of the day at the other price,
  divided by the price of a new card, at least 0 (`DailyGoal.newCardsAllowed`). Today and past days alike.
- **Why**: under FSRS the reviews are fixed by the schedule and new cards are the only free input; the Anki manual
  sizes them by the review workload one can sustain, and the day's time already holds that workload: as the
  reviews of earlier new cards grow, the time left for new ones shrinks. A second bound that looked a week ahead
  never set the allowance on any simulated or real learner and is gone (`ring-design.md`).
- The decks' limits (`newCardsPerSession`, `newProductionPerSession`) are ceilings. The allowance is
  split between decks in proportion to their ceilings by largest remainder (`DailyGoal.split`). A
  deck's ceiling is the new cards its limits would take at the start of the day plus those created
  since (`DeckActivity.History.newCeilingToday`).
- `DailyProgress.newCardAllowances`: the allowances per deck in `evaluate` order. The apps pass them to
  `StudySession`/`StudyStream` (`newCardAllowance`). `DailyRingModel` gives the allowance to the open
  document (`VocabularyDocument.newCardAllowance`, read by `DueCardCounter`, `StudyModel`,
  `SessionViewModel`, `SessionDriver`) and to `NewCardAllowances.today` per deck file (read by
  `OpenDeck`, `KnownDeckCounts`, `Reminders`, `WidgetSync`; the forecast for future days takes today's
  allowance).
- Cards first reviewed today are subtracted from the allowance, Study These Now's cards among them (they stand in for the
  plan's new cards); Learn 10 New Words goes beyond it. A card
  counts against the allowance when its first grade is logged.

## Done card, ring, minutes

- **Done card** (`DeckActivity.done(onDayOf:calendar:)`): a card reviewed on this study day whose due
  date is after the end of the day, so FSRS let it go to another day. A Review graded Hard, Good or
  Easy is done at once; a new card after its last learning step; Forgot when the card leaves learning.
  It counts once a day, however many reviews it took. A card deleted after it was done stays done: a deleted card that has
  reviews is a retired card (`Deck.retiredCards`), and `Deck.doneCards(onDayOf:)` and `Deck.cardsUnderway(onDayOf:)` count
  cards and retired cards alike, so deleting a card never moves the ring back. A retired card is in no plan, count, browser,
  search, export, words learned or statistics; it is in `reviewsByDay` and in the FSRS refit (`Deck.trainingCards`).
  Reviews per day (`reviewsByDay`) are needed only for the start of the streak and for the days before `planRuleStart`.
- A card is done in any mode, including Catch Up, the ring's rest.
- **Partial credit**: the ring also shows the cards on their way (`DailyRing.underway`,
  `Deck.cardsUnderway`): each reviewed today and still due today counts the answers recalled today
  (Hard, Good, Easy) over those plus the learning steps it still needs, at its best moment of the day
  (`Card.credit(onDayOf:calendar:steps:)`). Every answer recalled moves the ring; Forgot moves nothing
  and takes nothing back. The counts ("M of K cards", "N left") stay in whole cards.
- **Ring**: done cards against the day's goal. The ring is full at the goal and goes on over itself past it, a second
  lap and a third, as the Fitness rings do: the drawn value is done over goal, at most 3 (`DailyRingFigure.fraction`,
  `ProgressRing.maxLaps`; `DailyRing.fraction` itself stays capped at 1 and says whether the goal is met). Done cards
  beyond the goal (Catch Up, Study These Now, Learn 10 New Words) count as cards done and draw the laps. A past day's ring is drawn
  the same way from `DayRecord.ringShare`: its share of its goal, a closed day at least full and up to 3 laps, a day
  with none done an empty track. `DailyProgress.weekRings` (seven days, today last) feeds the week's rings on Today and
  on the rests, and the Progress calendar draws the same share.
- **The ring holds nothing**: a picture of done over goal and its laps, at every size. The `StreakState` of the day
  (`DailyProgress.streakState`) has three values: `open` (today's streak step not done), `kept` (done) and `atRisk` (the day
  after a missed one, ring open: `DailyProgress.isStreakAtRisk`). `StreakFlame(state:)` draws them, an outline in grey,
  `flame.fill` in `Color.streak`, an outline in `Color.streak` with an `exclamationmark` after it. `NextStep`
  (`Shared/Support/NextStep.swift`, pure) says the next moment of the day and its minutes, with no days in it. As a figure
  (`NextStep.moment`) it is a label over a value: "To keep your streak" · "≈ 2 min", "To close the ring" · "≈ 5 min", "To save
  your streak" (the day after a miss), "Reviews left" · "≈ 12 min" (ring closed, cards left), "To start your streak" (no
  streak), "Today" · "All done"; without a price the label is "Next" over the moment in words ("Keep your streak", "Close the
  ring", "Save your streak", "Catch Up", "Start your streak"). As a sentence, where one line is all there is room for: "≈ 2
  min to keep your streak", "≈ 5 min to close the ring", at risk "≈ 6 min to close the ring and save your streak", without a
  streak "≈ 2 min to start your streak", "Ring closed · ≈ 12 min of reviews left" (two parts, `NextStep.lines`), "All done for
  today". Without a price (`nil` minutes) the time is left out: "Keep your streak", "Close the ring", "Close the ring to save
  your streak", "Start your streak", "Ring closed". `priceLine` is what a rest says under its title ("≈ 5 min to close the
  ring", "≈ 12 min of reviews left"); `short` is "12 · ≈ 2 min" for a line with room for little.
- **The streak line** (`StreakLine`): `StreakFlame`, then "12-day streak" (`NextStep.streakText`), hidden at 0 days. VoiceOver
  reads `streakSpoken`: "12-day streak, kept today", "not kept yet" or "at risk". `StreakCount` is the header form, "🔥 12",
  the flame alone at 0 days.
- **Where they stand.** Today draws the figures (`TodayCard`, `Shared/Session/TodaySummary.swift`: the ring, Day streak, the
  moment, Words learned, the week). The rests carry the streak line in their chip and the price line under their title; the
  stream's header is the ring, `StreakCount` and "≈ N min"; the small and rectangular widgets say the sentence, the medium
  shows the figures, the inline one "🔥 12 · ≈ 2 min"; the reminders take its streak and its "≈ 2 min". `DailyRingView` has no
  popover and is no button. Sizes, colours and VoiceOver: `design-spec.md` §5.7.
- **The stack** is drawn as the cards left before the next moment, up to four edges, never as a number. Past the goal, after
  the ring, it counts the cards left in the plan's lanes (Catch Up), or the cards of Learn 10 New Words or Study These
  Now (`StudyModel.cardsBehind`).
- **Cards left**: the plan's cards not done yet, `StudySession.counts(...).total` now (`DailyProgress.cardsLeft`). Done +
  left = plan, which is the goal or more (review cards beyond the day's time are left too). No screen shows it as a count;
  the Study button's VoiceOver value says it.
- **Minutes** ("≈ 7 min", `Format.timeLeft`, under a minute "< 1 min"; estimates, cards × pace, never a goal):
  `DailyGoal.minutesLeft` = ceil((new × new pace + other × other pace) / 60). New: the cards left that were new at the start
  of the day, including a new card started today and still in its steps (`StudyCounts.newAtDayStart`); other: the rest of the
  cards left. The sentence uses three figures: `DailyProgress.minutesToStreak` (the first round; nil once the streak is
  kept), `.minutesToRing` (nil once the ring is closed) and `.minutesOfDueAfterRing` (the plan's due cards that stay after
  the goal × the other price; nil if none); `DayRounds.minutesToGoal(cardsDone:)` prices the cards still to the goal. A deck's
  row and header price its whole plan left, backlog included (`DeckMinutes.minutes(_:pace:)`). The ring and the streak step
  stay in cards.

## Pace

- **Pace**: seconds per done card at two prices (`Pace`, `DailyGoal.pace`): for cards that were new at
  the start of their study day (no reviews before the day), and for the others (review, relearning,
  learning from earlier days).
- A review's time is how long the card stood on screen from showing the question to the grade while
  the app was active (`ReviewLogEntry.duration`, key `ms` in `reviews.jsonl`, in milliseconds).
  `SessionDriver` measures it with `ActiveStopwatch` on `SuspendingClock`: the iPhone reports a
  `scenePhase` other than `.active`, the Mac `NSApplication.didResignActive`. Background, lock and
  another app don't count; there is no cap.
- A category with fewer than 20 reviews with a duration (old logs, imports without time) takes instead
  the gap between neighbouring reviews of the study day (across all decks together), of any length. The
  gap goes to the card of the later review, into the category the card had that day: a new card's steps
  to new, Again on a review card and its relearning to other.
- A category's price is its typical seconds per review times the number of reviews its done card
  needed.
- Typical seconds from durations: the mean of the lognormal the category's durations follow, from the
  median m and the interquartile range of their logarithms (times no shorter than 1 s,
  s = IQR / 1.349): exp(m + s² / 2). A duration holds no break and the background isn't recorded, and
  the mean estimates the long right tail of real times.
- Typical seconds from gaps: their median. A break (minutes, hours) is a gap too, on some days more than
  a quarter of them, and spreads the logarithms so far that the lognormal mean leaves the review time.
  The median ignores breaks while they are fewer than half the gaps; at a break share p it takes the
  0.5/(1−p) quantile of the working gaps, slightly above their median.
- Reviews per done card: the reviews of the category's cards that were done on the day of those
  reviews, over the 7 study days before today and today, including each day's first review (it has no
  gap), divided by those done cards (`DeckActivity.paceLog`, a log replay through `Scheduler`; each
  review carries "card done this day").
- A card left in its steps or in relearning at the end of the day is not done: its reviews, Again
  included, enter neither numerator nor denominator, but the gaps around them stay in the review-time
  count. The steps and Again of a done card enter the price.
- Fewer than 20 times or fewer than 10 done cards in a category: 30 s for new, 10 s for other
  (`DailyGoal.paceMinimumGaps`, `paceMinimumCards`).
- A gap includes the time between cards too (menu, rest screen), so the price from gaps is higher than
  the price from durations.
- `DailyProgress.cardsLeft`, `.newCardsLeft`, `.pace`, `.minutesLeft`. The widget's forecast knows only
  the number of cards per hour, so the snapshot holds one price (`WidgetSnapshot.secondsPerCard` =
  `DailyProgress.secondsPerCardLeft`: the time of the cards left now divided by their number; without
  cards, the other price) and counts each hour's minutes by it.
- Practice is not written to the log and doesn't count.

## Backlog

- **Backlog**: Review cards that were due before the start of the study day. They are part of the plan
  like any card due, most forgotten first.
- The goal takes the plan's cards that fit the day's time (`DayRounds`); the rest stay in the plan, and the
  ring's rest offers Catch Up, which goes on with it.

## Streak

- A day counts when its streak step is done (done ≥ its `keepAt`, the end of the step), an empty plan too (`keepAt` 0).
- A past day is judged by its record (`kept`, `closed`), which holds the day's own goal and `keepAt` and only rises, when
  reviews of that day arrive late; a day made up on a later day stays missed.
- Days before `DailyGoal.planRuleStart` (23.10.2026) count with one review, so as not to break a streak
  started under the old rule of a fixed number of reviews a day (a `ponytail:` marker; remove it with
  the condition in `Streak.evaluate`).
- A missed day is repaired when the next day closes the ring (done ≥ goal; the streak step alone is not
  enough, and then the streak restarts from that day; `Streak.repairCards` is how many cards are left
  to a closed ring). Two misses in a row break it.

## Cost and caches

- A full recount costs O(days × cards). Measured on 3,000 cards and 400 days of log (35,000 reviews):
  0.31 s in release on the Mac, 2.4 s in debug (`DailyProgressPerformanceTests`, `MNEMIT_PERF=1`).
- An open deck doesn't recount the days before today on every change. `DeckHistoryCache` (per document,
  held by `DailyRingModel`) keeps `DeckActivity.Past`: the history without today, a copy of the deck at
  the start of today and the production locks, as long as nothing the past days read changes
  (`DeckActivity.PastKey`: the options; for each card its place in the deck, `kind`, `note`, `created`,
  suspended, the log before today, and for a card with an incomplete log its state too).
- Reviewing a card with a complete log, editing text and time passing within the day don't change the
  key: only today is computed (the day's reviews from card states at its start, the day's plan, the new
  ceiling), 8.5 ms on 3,000 cards and 400 days instead of 0.31 s.
- Suspend, options, adding and deleting a card, note and kind, reset, reviewing a card with an
  incomplete log and a new study day mean a full recount (the first review of a never-reviewed card
  doesn't change the key).
- `DailyProgressCache` keeps the same for the per-day steps of `evaluate` (time and why, work, closed
  rings, streak) over the set of `Past` of all decks, the ledger and the rule.
- The reference is the full recount: `DeckHistoryCacheTests` compares both paths on random reviews and
  edits of two decks.

## Which decks count

- Both apps count every deck of the Mnemit folder: the iPhone from `KnownDecks` (files read by
  `DeckFileReader`), the Mac from the files of `DeckFolder` and the open documents (`OpenDecks`), the
  open ones as their documents have them (`DocumentView.refreshRing()`). The Mac's session
  header and Today page show the same ring and streak as the iPhone. `KnownDeckCounts`
  (`Shared/Document`, `refresh(_ urls: [URL])`) holds the counts per deck file for the iPhone's Today and
  the Mac's Today window. Paused decks (`LearningOptions.isPaused`) are in no plan, goal or allowance, and their work
  counts like any: done, pace, streak, words in memory and words learned take every deck, so a pause takes nothing from
  today, and a day already in the ledger keeps what it counted.
- The widget snapshot (`WidgetSnapshot.done`, `.goal`) holds the done cards and the goal; its JSON key
  stays `reviews` through `CodingKeys` so a saved snapshot still reads. The snapshot also holds `wordsLearned` and
  `wordsLearnedToday` (optional: a snapshot without them leaves the third figure out; the gain is nil after the snapshot's day).

## Words learned

- `WordsLearned` (VocabCore/Statistics), the gain Today shows as its figure ("Words learned" 412, "+12 today"): the words whose Word →
  Meaning card (kind not production; a card without a kind is a word) is in the review phase, not suspended, in active decks.
  A word held twice (the same `WordKey`) counts once, a card without a word key is a word of its own. A lapse takes the word
  out until it is relearned; a suspended card is in neither number. `wordsAtDayStart` is the same from the card states before
  today's reviews (`Scheduler.standing(_:atStartOf:now:)`, shared with `MemoryEstimate`); `shownGain` is "+N today" and is nil
  unless above 0. `DailyProgress.learned` holds it; `WordsLearned.line` is the text. With a past day in the ledger,
  `learned.wordsAtDayStart` is the ledger's count of the day before and `learned.words` that plus today's gain from the
  logs, so a word that lapsed stays counted, as in the medals.
- Words-learned medals: `DayRecord.wordsLearned` is the count of words that had left learning by the end of that day
  (`WordsLearned.cumulative`, kept in the ledger as `wordsLearned`; the first day by the Steps rule over the log; a lapse takes
  none back; a card without a full log counts from the first study day). `AchievementKind.wordsLearned(count:)` for `WordsLearned.milestones(upTo:)`: 10, 50, 100,
  250, 500, 1000, then every 1000; earned once, on the first day the count reaches it.
- Lap medals: `Double ring` and `Triple ring` are days whose `DayRecord.ringShare` reached 2 or 3 laps, earned once each (the
  first such day), derived from the records so history earns them; a 3-lap day earns both. Order within a day: streak, first
  ring, perfect week, double, triple, words, comeback.

## Words in memory

- `MemoryEstimate` in VocabCore, in the Memory section of Progress and in How It Works: the sum of recall probabilities
  (`Scheduler.recallProbability`) over learned, unsuspended recognition cards. A card without a kind is a word too; production
  cards don't count. A word held by several decks or by two cards of one deck counts once, at the highest probability among
  cards with the same word key (`MemoryEstimate.total`).
- Taken at the start of the study day (04:00), from the card states before today's reviews. Nothing is stored. Words show
  rounded down, the day's gain to a whole number; milestones 50…5000 (`MemoryEstimate.milestones`). Today shows words
  learned, not this number.

## How It Works

- `HowTodayWorks` and `HowTodayWorksView` in `Shared/Statistics`: the numbers and rules under the ring
  for people who know Anki and FSRS. Read-only, no controls or charts; each section's rule in its
  footer.
- Sections in order:
  0. Today: the three moments in three plain sentences, no figures (`HowTodayWorks.Row.text`, empty footer): the first minutes
     keep the streak, the ring is the goal and Catch Up studies the reviews waiting, nothing due is all done and Learn 10 New
     Words adds ten.
  1. Day's plan: the parts of the plan at the start of the day (due today, overdue included; learning;
     new admitted), each deck's allowance and ceiling, goal, rounds, done, left.
  2. Today's time: the time in minutes, the streak step and the goal in cards; 14 days with the minutes
     asked, the minutes worked, ring closed or open and why the time (Start, Ring closed, Ring open, Plan under the time, Past the
     ring).
  3. Pace: new and other price, the price's source (durations, gaps or the default), reviews per done
     card.
  4. Streak.
  5. Words in memory.
  6. Swipes, iPhone only: "N of M today", the swipes the sector gap returned out of all that reached the
     threshold or flick during the study day (`SwipeTally`); the footer gives the sectors in compass
     degrees. The Mac has no such section.
  7. FSRS per deck: retention, 21 parameters, fit, steps, maximum interval.
- Numbers come from `DailyProgress`, `MemoryEstimate`, the deck settings and `DayBreakdown` (VocabCore,
  `Statistics/DayBreakdown.swift`). Its days are `DailyProgress.ringDays`; only the pace window repeats
  `DailyGoal.pace`, and `DayBreakdownTests` keeps them together. The sheet reads the ledger and writes nothing
  (`HowTodayWorks.make(..., ledger:)`, `HowTodayWorks.read(..., ledger:)`; loaders: Mac `HowTodayWorksLoader`, iPhone
  `HowTodayWorksButton(ledger:)`), so it shows what Today shows.
- iPhone: the last row of the Progress screen, "How It Works", in a section with the footer "The plan, the
  day's time and the FSRS parameters behind the ring." (`HowTodayWorksButton` and the sheet `HowTodayWorksSheet`,
  `VocTrain/Views/HowTodayWorksSheet.swift`); decks are read from files when the sheet opens. Mac: Study ▸ How It Works (`HowTodayWorksWindow`), the decks of open documents, without
  names ("Deck 1", "Deck 2").
- Row data: `VocTrainTests/HowTodayWorksTests`; the sheet's frame comes from there too (directory
  `TEST_RUNNER_HOME_SHOTS_DIR`).
