# The day: plan, goal, rounds, ring, streak, pace

How the day is measured, and the screen that explains it. Terms with their Russian equivalents:
`GLOSSARY.md`, section "Mnemit". Code: `DailyProgress` in VocabCore, `DailyRingModel` and
`DailyRingView` in `Shared/Session`.

## Principle

- Ring and streak come only from the review log (`reviews.jsonl`); nothing is stored.
- The day is measured in cards: the ring, "M of K cards", "N cards left", the widget and the streak
  count cards. A review (one grade of one card) counts toward neither the goal, the ring nor the
  streak; reviews are for the optimizer, statistics and pace.

## Plan

- **Plan**: the cards the day asks for under FSRS (`StudySession.counts`): cards due, overdue too, and
  new cards within the day's limits and the deck's allowance `newCardAllowance`; overdue cards are part
  of it (Backlog below). `nil` instead of an allowance means only the deck's limits: tests and tools count
  that way.
- The plan at the start of the day comes from `DeckActivity.history(from:at:calendar:)`: the log is
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
- The goal doesn't change: Add Cards, Learn 10 New Words and Again don't raise it.
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
- The step never shows by number (`learning-flow.md`). `RoundStatus` (`Shared/Session/DayLines.swift`)
  gives the day's title: before the step "≈ 2 min to keep your streak", after the goal "Ring
  closed", in between none, and the screens say the cards left. `TodayHeadline.text`
  (`Shared/Session/TodaySummary.swift`, pure and tested) puts the headline together for both apps: the
  title where there is one, else "20 cards left · ≈ 5 min", "All done", "Nothing due · next tomorrow", and
  on the day after a missed one "Close the ring to save your 12-day streak". The widget and the Mac ring
  chip's help take the title from `RoundStatus`.
- In a day that started with an empty plan, the ends cut the cards as they are.

## Day's time

- **Day's time**: the seconds of work the day asks (`DailyProgress.time`), from the log, forward from the
  first study day, the same on every device, never rounded. The goal is the cards of the plan that fit
  it, and new cards fill what the plan's other cards leave.
- **The rule**, one pure step per study day, `DailyGoal.nextTime(after:)`, over the days before it as plain
  values (`DailyGoal.RingDay`): a staircase. The last study day (a day with work) asked T (its
  `RingDay.time`); the next time is T × 1.15 (`DailyGoal.grows`, reason `ringClosed`) when its ring was the
  `DailyGoal.closedToGrow`-th (2nd, 4th, …) in a row closed on a goal that filled T, T when it was the first of
  such a run (reason `closedInARow`), T when it closed on a plan smaller than T (`RingDay.filled` false: a deck's
  new-card limit or an exhausted deck set the goal; reason `smallPlan`; such a day neither counts in the run nor
  breaks it), and T × 0.775 (`DailyGoal.shrinks`) when it stayed open, which ends the run; clamped to
  120…3600 s; 150 s before any study day. A day without work is no step, and the days after it ask what they
  would have asked without it. worked(d) is the cards done on `d` at the day's own prices, new × new price +
  other × other price at the pace of the seven study days before `d`, cards beyond the goal included; How It Works shows it.
- **Filled** (`DayRounds.filled`): the goal's cost plus one new card's price exceeds T, so the time, not the
  plan, set the goal. A closed ring on a smaller plan says nothing about more time and moves nothing.
- **Why**: `ring-design.md`. The staircase puts the share of closed rings where p² ln 1.15 = (1 − p²) ln(1/0.775),
  0.80, whatever the work, and changes the ring on half the study days. How It Works names the direction only
  ("Ring closed", "Ring open"), never the rule.
- Model learners (`RingRuleTests`): one who stops at the ring asks 150, 150, 172.5, 172.5, 198.4 s …, 150 × 1.15^⌊(d − 1)/2⌋
  on study day d; one who works less than the ring asks falls to 2 minutes on day 2 (150 × 0.775 = 116.25 is under
  the floor) and holds there; a ring closed on a small plan keeps its time; a day without work changes nothing.
- `DailyProgress.ringDays` holds every day's `RingDay` (time, reason, work, ring, filled) with today live, and
  the reason is `start`, `ringClosed`, `smallPlan` or `ringOpen`; `DailyProgressCache.Before.days` keeps the
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
- Cards first reviewed today are subtracted from the allowance; Learn 10 New Words goes beyond it. A card
  counts against the allowance when its first grade is logged.

## Done card, ring, cards left

- **Done card** (`DeckActivity.done(onDayOf:calendar:)`): a card reviewed on this study day whose due
  date is after the end of the day, so FSRS let it go to another day. A Review graded Hard, Good or
  Easy is done at once; a new card after its last learning step; Forgot when the card leaves learning.
  It counts once a day, however many reviews it took. Reviews per day (`reviewsByDay`) are needed only
  for the start of the streak and for the days before `planRuleStart`.
- A card is done in any mode, including Catch Up, the ring's rest.
- **Partial credit**: the ring also shows the cards on their way (`DailyRing.underway`,
  `Deck.cardsUnderway`): each reviewed today and still due today counts the answers recalled today
  (Hard, Good, Easy) over those plus the learning steps it still needs, at its best moment of the day
  (`Card.credit(onDayOf:calendar:steps:)`). Every answer recalled moves the ring; Forgot moves nothing
  and takes nothing back. The counts ("M of K cards", "N left") stay in whole cards.
- **Ring**: done cards against the day's goal. The ring is full at the goal and stays full
  (`DailyRing.fraction` is capped at 1). Done cards beyond the goal (Catch Up, Learn 10 New Words) count as cards
  done: "31 cards today".
- **Middle of the ring**: the ring's own quantity. `RingCenter` is `.cardsLeft(n)` (`DailyProgress.cardsToClose`: the
  plan's cards left, at most the goal less the done), `.done` (a `checkmark`, once the ring is closed) or `.none`;
  `RingCenter.shown(at:)` drops it below 56 pt and adds the caption "cards left" from 88 pt, so the bars' and the
  week's rings are empty inside. The streak is never in a ring. The `StreakState` of the day
  (`DailyProgress.streakState`) has three values: `open` (today's streak step not done), `kept` (done) and
  `atRisk` (the day after a missed one, ring open: `DailyProgress.isStreakAtRisk`). `StreakFlame(state:)` draws
  them, an outline in grey, `flame.fill` in `Color.streak`, an outline in `Color.streak` with an `exclamationmark`
  after it. `StreakChip` (`Shared/Support/StreakChip.swift`) puts the flame and one sentence under the hero ring
  of Today (`HeroRing`, `TodayHero` in `Shared/Session/TodaySummary.swift`) and on the rests: kept "12-day
  streak", open "≈ 2 min to keep your 12-day streak" (`RoundStatus.minutesToKeep`), at risk "Close the ring to save
  your 12-day streak", no streak "Start your streak · ≈ 2 min". The gain line under it leads with the time that
  closes the ring (`TodayLead`) and goes on with the words in memory. VoiceOver reads "12 cards left" or "Ring
  closed" for the ring and the chip's sentence with its state. `DailyRingView(progress:, showsCenter:)` has no
  popover and is no button. Sizes, colours and VoiceOver: `design-spec.md` §5.7.
- **Cards left**: the plan's cards not done yet: `StudySession.counts(...).total` now, the line "N
  cards left". Done + left = plan, which is the goal or more (review cards beyond the day's time are
  left too).
- Next to it "≈ 7 min" (Today line, stream header while the goal is open, widget, Mac ring chip's help):
  `DailyGoal.minutesLeft` = ceil((new × new pace + other × other pace) / 60); under a minute it reads
  "< 1 min"; without cards there is no line. New: the cards left that were new at the start of the day,
  including a new card started today and still in its steps (`StudyCounts.newAtDayStart`); other: the
  rest of the cards left.

## Pace

- **Pace**: seconds per done card at two prices (`Pace`, `DailyGoal.pace`): for cards that were new at
  the start of their study day (no reviews before the day), and for the others (review, relearning,
  learning from earlier days).
- A review's time is how long the card stood on screen from showing the question to the grade while
  the app was active (`ReviewLogEntry.duration`, key `ms` in `reviews.jsonl`, in milliseconds).
  `SessionDriver` measures it with `ActiveStopwatch` on `SuspendingClock`: the iPhone reports a
  `scenePhase` other than `.active`, the Mac `NSApplication.didResignActive`. Background, lock and
  another app don't count; there is no cap.- A category with fewer than 20 reviews with a duration (old logs, imports without time) takes instead
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

- A day counts when its streak step is done (done ≥ the end of its streak step), an empty plan too.
- A past day is judged by what was done on it (the log replay gives done cards per day) and by its plan
  at the start: a day made up later stays missed.
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
  rings, streak) over the set of `Past` of all decks and the rule.
- The reference is the full recount: `DeckHistoryCacheTests` compares both paths on random reviews and
  edits of two decks.

## Which decks count

- Both apps count every deck of the Mnemit folder: the iPhone from `KnownDecks` (files read by
  `DeckFileReader`), the Mac from the files of `DeckFolder` and the open documents (`OpenDecks`), the
  open ones as their documents have them (`DocumentView.refreshRing()`). The Mac's toolbar chip, session
  header and Today window show the same ring and streak as the iPhone. `KnownDeckCounts`
  (`Shared/Document`, `refresh(_ urls: [URL])`) holds the counts per deck file for the iPhone's Today and
  the Mac's Today window. Paused decks (`LearningOptions.isPaused`) enter none of these numbers.
- The widget snapshot (`WidgetSnapshot.done`, `.goal`) holds the done cards and the goal; its JSON key
  stays `reviews` through `CodingKeys` so a saved snapshot still reads.

## Words in memory

- `MemoryEstimate` in VocabCore, on screen "≈ N words in memory": the sum of recall probabilities
  (`Scheduler.recallProbability`) over learned, unsuspended recognition cards. A card without a kind is a
  word too; production cards don't count. A word held by several decks or by two cards of one deck counts
  once, at the highest probability among cards with the same word key (`MemoryEstimate.total`).
- Taken at the start of the study day (04:00), from the card states before today's reviews. Nothing is
  stored. Words show rounded down, the day's gain to a whole number; milestones 50…5000
  (`MemoryEstimate.milestones`).
- The apps read `DailyProgress.memory`: Today "412 words in memory · +15 today" (`MemoryLine`); the day's milestone
  "50 words in memory!" with a glyph in the accent (text is never accent-coloured,
  `references/design-spec.md`); the round-end screen and "Done for today" "+N words in memory today";
  the medium widget and the Mac ring chip's help the number of words (`MemoryEstimate.line`,
  `DayLines.swift`).

## How It Works

- `HowTodayWorks` and `HowTodayWorksView` in `Shared/Statistics`: the numbers and rules under the ring
  for people who know Anki and FSRS. Read-only, no controls or charts; each section's rule in its
  footer.
- Sections in order:
  0. Today: three plain sentences, no figures (`HowTodayWorks.Row.text`, empty footer): what the ring is,
     what Catch Up does, what Learn 10 New Words does.
  1. Day's plan: the parts of the plan at the start of the day (due today, overdue included; learning;
     new admitted), each deck's allowance and ceiling, goal, rounds, done, left.
  2. Today's time: the time in minutes, the streak step and the goal in cards; 14 days with the minutes
     asked, the minutes worked, ring closed or open and why the time.
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
  `DailyGoal.pace`, and `DayBreakdownTests` keeps them together.
- iPhone: the last row of the Progress screen, "How It Works", in a section with the footer "The plan, the
  day's time and the FSRS parameters behind the ring." (`HowTodayWorksButton` and the sheet `HowTodayWorksSheet`,
  `VocTrain/Views/HowTodayWorksSheet.swift`); decks are read from files when the sheet opens. Mac: Study ▸ How It Works (`HowTodayWorksWindow`), the decks of open documents, without
  names ("Deck 1", "Deck 2").
- Row data: `VocTrainTests/HowTodayWorksTests`; the sheet's frame comes from there too (directory
  `TEST_RUNNER_HOME_SHOTS_DIR`).
