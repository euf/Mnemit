# The learning flow: one day, one ring, one streak

What the learner sees and does from opening the app to closing the ring, and which parts of 4.0 go.
Evidence: `learning-flow-research.md` (Duolingo, Apple rings, Anki and FSRS, Brainscape, Quizlet,
Clozemaster). Rules behind the numbers: `daily-ring.md`; terms: `GLOSSARY.md`, section "Mnemit".

## Verdict

4.0 shows five measures at once: rounds, minutes, cards, words and days. The ring fills by cards while
the line beside it counts rounds; the stream stops every two minutes; the streak, the ring and the
rounds are three goals of one day. The model below keeps one unit on screen, the card, and one goal a
day, the ring. The day's time stays inside, in seconds the app learns from the learner's work, and leaves every
screen but How Today Works; the streak step, the first two minutes of the plan, is the one unit of its own. The day's
stack stops twice a day at most: once the streak is kept, and once the ring is closed. It has an end: when it is done,
only Push On puts more cards in it.

## The day in six rules

| # | Rule | Answers | Evidence |
|---|---|---|---|
| 1 | Your time follows your rings, out of sight: two rings closed in a row make the next day ask 15 % more time; a ring left open, a quarter less (× 0.775); a ring closed on a plan smaller than the time, or a day without study, changes nothing; 2.5 minutes before any study, 2 minutes to an hour | how much the learner really does | a staircase on closed and open rings (Levitt's transformed up-down): the share of closed rings settles near 0.8 whatever the work, and the ring changes on half the study days; averages and quantiles of the work stall for a learner who stops at the ring, since the work of a closed day is the ring itself; 2.5 minutes are reached on 77 % of a newcomer's first-week study days; an hour holds the usual day of nine in ten Anki users (`ring-design.md`) |
| 2 | The goal is the cards FSRS has due, most forgotten first, as many as fit your time | what to do today | FSRS: reviews are the work owed; the Anki manual caps reviews so a return after a break is manageable |
| 3 | If time is left, new cards fill it | how many new | new cards are FSRS's only free input; the Anki manual sizes them by the workload one can sustain, and the time already holds it: the reviews of earlier new cards leave less time for new ones |
| 4 | The ring closes when the goal is done; work beyond it fills laps, and closed rings raise the next days' time | how to grow | growth comes from closing the ring |
| 5 | The first two minutes keep the streak; one missed day is forgiven when the next ring closes | the habit | a low bar keeps the habit (Duolingo A/B, +3.3 % day-14 retention); slack keeps a streak (Streak Freeze, Apple's paused rings) |
| 6 | Once the ring is closed: Catch Up while the plan has cards left; once the stack is done, Push On: ten new words, whose reviews make the next days harder | what next | FSRS decides which cards come; the learner decides only whether to raise the stakes, and the button says what it costs |

Every number of the day's time comes from a measurement on synthetic learners and on the logs of 2,000 Anki users,
with the alternatives that lost: `ring-design.md`. A learner who stops at the ring has closed it, so the day's time
grows. The 2-minute streak step stays a choice (`decisions-evidence.md` §3).

## The journey

### One day

```
Today ─Study─► the stack: today's plan over all decks, mixed by FSRS's urgency
  ≈ 2 min ─► Streak kept ─Keep Going─► … ─► the ring closes
                 │ Done for Now             ├─ cards left (after a break) ─► Ring closed ─Catch Up─► … ─► stack done
                 ▼                          └─ none left ─────────────────► stack done
               Today              stack done ─► Done, or Push On ─► ten new words, mixed ─► stack done ─► Done, or Push On …
```

The two ordinary days:

1. Study, the streak kept after two minutes, the ring closed, the stack done: Done or Push On.
2. After a break: Study, the streak kept, the ring closed with cards left, Catch Up, the stack done: Done or Push On.

A plan of two minutes or less closes the ring without the streak's rest. Leaving anywhere loses nothing: Today picks
up the count, and Study goes on where the stack was.

### Push On raises the stakes

- **What it adds.** Ten new cards beyond the daily limits, from every deck that has new cards left, one at a time to
  the deck that has given the fewest so far, and asked mixed as the plan is. No count to choose: FSRS keeps deciding
  which cards come.
- **What it costs.** Each new card comes back as reviews. Ten cards bring about 2 reviews the next day, 8 the day after,
  3 on the third, 12 more over days 4 to 14, then a thin tail (FSRS-6 defaults with Mnemit's fuzz, `cards.py --echo`: short
  intervals are not fuzzed, so the first return is a peak, and the later ones spread). Reviews come first in the plan, so the peak
  fits the day's time and takes the place of the ring's new words: on the logs of 854 Anki users, a learner who pushes
  on one day in three has no new word in the ring on 46 % of study days, one who stops at the ring on 13 %.
- **What it doesn't change.** The day's time. A day of pushing on is a good day, and the next one is usually an
  ordinary one: raising the time to what the learner did (at least 0.6 of the work) cut the closed share of real users
  from 0.81 to 0.70 and perfect first weeks from 41 % to 28 % (`ring-design.md`).
- **The button.** "Push On", and under it "More reviews in the days ahead": more words now, harder days next.

### The day after

The time follows the rings by rule 1, out of sight; the screens show cards. A missed day is forgiven when the next ring
closes; two in a row end the streak.

### A newcomer's first days with a new deck

Day 1 asks 2.5 minutes. At 30 s a new card, the price until the learner's own pace is measured, that is five new words;
the first four keep the streak. A new word is done after two right answers. A learner of about ten minutes a day who
stops at the ring (FSRS-6 cards, 400 learners, means; `Tools/ring-sim/cards.py --first`):

| study day | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| time (min) | 2.5 | 2.5 | 2.8 | 2.9 | 3.1 | 3.2 | 3.5 | 3.6 | 3.9 | 4.1 |
| new words in the ring | 5 | 4 | 4 | 3 | 4 | 4 | 4 | 4 | 5 | 5 |
| reviews | 0 | 1 | 5 | 5 | 5 | 6 | 6 | 6 | 7 | 7 |
| rings closed | 1.00 | 1.00 | 1.00 | 0.99 | 0.99 | 1.00 | 0.99 | 0.99 | 0.98 | 0.96 |

The first weeks are built to close: seven rings of seven for 0.87 of synthetic newcomers and 0.43 of real ones, whose
first-week days are short (`ring-design.md`, "The first two weeks"). A learner of five minutes closes 0.84 to 0.94 of
the first ten rings. The time climbs about 7 % a study day, so a learner of twenty minutes reaches them after a month;
until then their extra words come through Push On.

### A return after a break

Days without study leave the time as it was. The plan holds every overdue card; the ring is the most forgotten that fit
the time, with no new word while reviews fill it; the rest waits behind Catch Up once the ring is closed. A learner who
stops at the ring meets Catch Up on 6.9 % of a newcomer's study days and 10.4 % of a real user's.

### An Anki user

The imported collection brings its history, and the replay of the history runs rule 1, so the time arrives near the
learner's usual day. The ring holds the whole queue up to an hour; How Today Works shows the plan, the time and the FSRS
parameters.

### Several decks

One stack over every active deck with a plan for today. The next card comes from the deck whose next card is the most
urgent: a card in learning, then the review with the lowest recall probability, then a new card from the deck that
has given the fewest. The day's new-card allowance is split between the decks by their ceilings; Push On shares its ten
cards the same way, one at a time. A paused deck is out of the day. A deck with nothing in today's plan does not open
with the stack, so Push On takes from the decks that did.

## The model

| Learner's word | What it is | Where it comes from |
|---|---|---|
| Card | the one thing on screen; swiped once, graded by the swipe | the deck |
| Today's cards (the ring) | the cards FSRS asks today that fit the learner's day; every answer recalled moves the ring by its share of a card | the plan at 04:00, priced by pace, cut to the day's time |
| The stack | the cards still waiting today, in the middle of the screen; it ends | today's plan over all decks, mixed by FSRS's urgency |
| Streak | days in a row with the first ≈ 2 min of cards done | the review log |
| Words in memory | how many words the learner would recall now | FSRS's recall probability, summed |
| Catch Up | the plan's cards beyond today's ring, after a break | the rest of the plan |
| Push On | ten more new words once the stack is done, from all the decks, mixed | new cards beyond the daily limits |

Never on screen: review counts (a card is never a review), the day's time, plan against goal,
seconds per card, intervals before a grade.

A card is done when FSRS sends it to another day, and a new word takes two right answers to get
there. The learner feels swipes, not cards: a right answer that moved nothing would read as wasted.
So the ring counts cards with partial credit (`Card.credit`): an answer recalled (Hard, Good, Easy)
moves its card by the answers recalled today over those plus the steps still needed, Forgot moves
nothing, and nothing is taken back. A new word is half a card after its first Good. The count beside
the ring stays in whole cards; the closing screen joins the two: "10 cards · 22 answers".

FSRS decides what is urgent; the learner decides only whether to go on. Due cards are the work owed;
new cards are the only free input, and the app admits as many as the learner's time holds after today's
reviews, so the ring is a size the learner has shown they finish. The size is learned, never asked: no budget, no slider.

## Horizons

| Horizon | The learner does | Sees, as reward | Rule |
|---|---|---|---|
| Seconds | swipes one card | the card leaves past the edge; recalled, the ring steps by its share; done, the stack loses a sheet, the ring bumps and "in 8 days" shows beside it; back today, the card comes in again from the edge it left by and slides under the stack | done = FSRS sent the card to another day; partial credit by steps |
| ≈ 2 min | the first cards of the day | the streak screen: "Streak kept", the streak in days | streak step of the day done (Duolingo: one lesson keeps the streak, apart from the goal) |
| The day | today's cards | the ring closes: the ring screen with the day's figures and the week | done ≥ goal |
| The week | closes rings on most days | seven rings in a row, Monday to Sunday, on the ring screen | ring per day from the log; the day's time follows the recent work |
| Months | keeps the streak, learns | the streak in days in the ring's centre; words-in-memory milestones (50, 100, 250, 500, 1,000 …) | FSRS recall, the log |

A missed day is forgiven when the next day closes its ring (the streak survives; Duolingo's Freeze
and Apple's paused rings are the same slack). Pausing a deck takes it out of the day.

## Screens

```
Today ──Study──► card ─► card ─► … ─► Streak kept ──Keep Going──► card ─► … ─► Ring closed
  ▲                                      │ Done for Now                        │ Catch Up / Push On
  └──────────────────────────────────────┴─────────────────────────────────────┴─ Done
```

**Today.** The ring (centre: the streak in days), one headline, one detail line, Study.

| State | Headline | Detail |
|---|---|---|
| before the streak step | ≈ 2 min to keep your streak | 12 of 24 cards · 12 left |
| streak kept, ring open | 12 cards left · ≈ 4 min | 12 of 24 cards · 12 left |
| ring closed | Ring closed | 24 cards today |
| nothing due | Nothing due | Next review tomorrow |

Under them: "13-day streak · kept today" and "≈ 412 words in memory · +15 today".

**Study.** The stack in the middle, the small ring in the bar with "≈ 4 min" (after a done card, for
a moment, "in 8 days"), the close button. Closing loses nothing; Today picks up the count.

**The stack.** The card on top lies on the sheets under it, drawn as the edges of a book's pages:
under its bottom edge hairline outlines with its corner radius, each 3 pt lower and 2 pt narrower
on each side than the one above it, fainter with depth; `min(cards left − 1, 5)` of them, so a long
day looks thick and the last six thin out one line at a time.
- Graded, the card goes on with the finger and leaves past the edge of the screen. Nothing rides on
  it: a label on a card that is leaving is never read.
- Done (another day): the deepest line fades, the stack moves up a step, the next card rises from
  the first line; the ring in the bar steps, bumps and bursts, and its caption shows the interval.
- Back today (a step to go, or Forgot): the card comes in again from the edge it left by, already
  a sheet, and slides under the stack, where it becomes the deepest line: the stack is as thick as
  before, which is why the card comes back.
- The last card has no lines. When it leaves, what lay under it shows: the ring comes down from the
  bar into its place and closes there, and the day's lines come in.
- Undo plays the grade backwards: the card comes in from the edge it left by to the top, out from
  under the stack if it went there; the ring takes its step back.
- Reduce Motion: the card fades in place, the ring steps without a bump, nothing travels.

**Streak kept** (once a day, after the first ≈ 2 min; not when the day's cards end there too): the
ring, "Streak kept", the streak in days, "+4 words in memory today", "12 cards left · ≈ 4 min".
**Keep Going** (default), **Done for Now**.

**Ring closed** (when today's cards are done, and when the plan has run out): the ring closes with its
burst, then the day: "10 cards · 22 answers", the share recalled, "+15 words in memory today", the streak, the
week's seven rings; a milestone when one was passed today. One way on, the most useful first:
**Catch Up** when the plan has cards left beyond the ring; else **Push On**, with "More reviews in the days ahead"
under it; and **Done**. The week is seven small rings, today last, with the weekday initials.

**How Today Works** keeps everything for the learner who knows FSRS: the plan and its parts, the
the day's time and the streak step, pace, the streak's repair, FSRS parameters.

## Progression: the ladder of memory

The stack shows today, the ring the day, the streak the habit, words in memory the sum. What a learner
of a month, or an Anki user of years, misses is the path of a word: that today's swipes move words
up. FSRS has that path already: a card's stability, the days until its recall falls to 90 %, which
`MaturityCategory` cuts into steps with the validated colour ramp, and each deck keeps a histogram of
them per day (`DailySnapshot`). No points, no levels of our own: the steps are FSRS's numbers.

| Step | Stability | Colour |
|---|---|---|
| New | never studied | grey |
| Shaky | under 4 days | lightest blue |
| Young | 4–16 days | |
| Maturing | 16–64 days | |
| Mature | 64–256 days | |
| Mastered | 256 days and more | darkest blue |

- **Seconds.** A grade that lifts a card to Young or above says so where the interval shows, beside the
  ring: "in 25 days · Maturing", in the step's colour. Most grades lift nothing, so the moment stays rare.
- **The day.** The Ring closed screen shows the ladder of all cards as one segmented bar in the ramp's
  colours, and "+6 climbed today": the cards whose step rose today.
- **Today.** The same bar, thin, under the words in memory: the shape of the collection, filling to
  the right over weeks.
- **For the Anki user**, How Today Works keeps the numbers: the cards per step and the true retention of
  the last 30 days against the target.

Not added, as they reward volume over memory and pull against FSRS: points, leagues, hearts, reviewing
ahead for a bigger number. The laps and big-day medals count done cards, cards FSRS sent to another day,
never answers: grading fast or reviewing early earns nothing.

## Milestones, achievements and the Progress screen

Who it is for. A newcomer has to want to come back every day of the first two weeks, which is their way
into FSRS without knowing the community; the first rewards come early and often. An Anki user has to
find the reviews and the decks better than what they leave; their rewards are records and the numbers
of FSRS. Everything is worked out from the review log, as the ring and the streak are: nothing is stored
but which monthly screen this device has shown.

**Streak milestones**, celebrated on the day they are reached, on the Streak kept screen (its title
becomes the milestone, with a medal and the burst): 3 days, a week (7), 2 weeks (14), a month (30),
2 months (61), 3 months (91), half a year (183), a year (365), a year and a half (548), 2 years (730).
They are named in words, never as a count of days; the widget and Today only show the number growing.

**Achievements**, each earned on a study day and kept with its date:

| Line | Tiers | Earned when |
|---|---|---|
| Streak | the milestones above | the streak reaches the tier |
| First ring | one | the first day a ring closes |
| Perfect week | one, then again each time | seven rings closed in a row |
| Laps | 2, 3, 5, 10 rings in a day | the cards done in a day reach that many times the day's goal |
| Big day | 50, 100, 200, 500 cards | the cards done in a day (cards FSRS sent to another day) |
| Comeback | one, then counted | a missed day made up by closing the next day's ring: the streak survived |

**The comeback scenario.** The day after a missed day, Today's headline says "Close the ring to save
your streak" (with the cards it takes) instead of "≈ 2 min to keep your streak", and the streak line
reads "12-day streak · at risk" with a grey flame. When that ring closes, the Ring closed screen's
title is "Streak saved", and Comeback is earned. Two missed days in a row end the streak as before.

**Hidden progression.** On the Progress screen each line shows its earned tiers in colour with their
dates, the next tier as a grey medal (a dashed outline, the line's symbol and its hint in tertiary grey, an earned
one on a gradient of the accent with a shadow) with how far there is to go ("12 of 14 days"), and nothing of the
tiers after it: there is always one more to find. A line that repeats shows how often as a badge on the disc,
never in the title.

**Emoji or SF Symbols.** An earned medal's face is an emoji, for colour and the moment of joy; it is
seen only once earned, so the next tier, a grey medal, shows the line's SF Symbol and keeps its emoji a
surprise. Everything else is SF Symbols: the streak's flame on Today and in the widget, the rows of
records and figures, the lines of the rests. The faces:

| Line | Faces, tier by tier | Next tier's symbol |
|---|---|---|
| Streak | 🔥 3 days · ⭐️ a week · 🌟 2 weeks · 🌙 a month · 🌿 2 months · 🌳 3 months · ⛰️ half a year · 🏆 a year · 💎 a year and a half · 👑 2 years | `flame` |
| First ring | 🎯 | `circle.circle` |
| Perfect week | 🌈 | `calendar` |
| Laps | ⚡️ 2 rings · 🚀 3 · 🌋 5 · 🪐 10 | `repeat` |
| Big day | 📚 50 · 🧠 100 · 🦉 200 · 🐘 500 | `rectangle.stack` |
| Comeback | 🐦‍🔥 | `arrow.uturn.up` |

**The Progress screen**, from Today (a tap on the ring's panel, which gets a chevron), top to bottom: the
streak large, with "Longest: 30 days · 24 rings closed"; the achievements (one row for the lines of one
medal, then a row per line of tiers); the calendar, Monday to Sunday under the weekday initials, a row per
week from the one of the first study day, at most 13 ("Last 13 weeks" once there are 13, else "Calendar");
the ladder of memory, a bar of the cards started with "N not started" under it and a legend of the five
steps; the records: most cards in a day, most rings in a day, rings closed, days studied, cards done. For the Anki user the same screen ends with the FSRS
figures: true retention of the last 30 days against the target, cards by step.

**Celebrations.** A medal is celebrated the moment it is earned: in the stack a toast slides down under the
bar for 2.5 s (one after another), the ring in the bar bumps and bursts, and a success haptic plays; a rest
shows today's medals under its title, at most three, and Today lists the medals of earlier days that this
device never celebrated (earned on the Mac) once as "New medals". The device keeps what it has celebrated in
`UserDefaults` (`CelebratedMedals`, `"<kind key>@<day>"`), and its first read marks everything from before
today silently, so an update brings no flood. **Every month** has a screen of its own: on the first
open of a new month, after a month with study, Today shows "October" as a sheet: rings closed of days,
cards done, the best streak of the month, the achievements of the month, and See All Progress.

## What goes, and why

| In 4.0 | Now | Why |
|---|---|---|
| A rest after every round | one rest, at the streak; the next at the ring | a stop every 2 min breaks the flow; the ring already shows progress; the one stop that pays is the streak (Duolingo: the streak screen raised day-7 retention by 1.7 %) |
| "Round 2 of 4 · ≈ 2 min" on Today, in the bar, in the widget, on the Mac | cards left and time | two progress measures beside one ring; rounds are an internal unit of time |
| The day's time, "Next round ≈ 2 min" | How Today Works only | the size of the day is learned, not chosen |
| Review ahead after catch-up | gone from Keep Going | reviewing before due gains FSRS little, and fills the ring with low-value work; more work is a new card |
| Keep Going running catch-up, then review ahead, then practice | Catch Up when the plan has cards left; Push On once the stack is done | one named way on; practice stays on the deck screen |
| Practice after the plan, a stream that never ended | gone: the stack ends with the plan | a day with an end; practice changes no card and stays on the deck screen |
| "+10 new" with "≈ +2 cards/day next week" | Push On, with "More reviews in the days ahead" | the learner decides whether to raise the stakes, FSRS which cards come; the count and the forecast asked for a choice the learner can't weigh |
| The ring closing in the middle of a stream after a break | the stack stops at the ring | the ring is the day's goal; the cards beyond it stay in the plan and Catch Up goes on with them |

Kept as they are: one stack over all decks, the 04:00 day, the ring in cards, laps (×2, ×3) for
work beyond the goal, the streak's repair by a closed ring, words in
memory, pausing a deck, practice from the deck screen.
