# The learning flow: the journeys through a day

What the learner does from opening the app to the last stack of the day, and how a newcomer, a course learner after a
lesson, a returner and an Anki veteran pass through it. The model (the promise, the entities, the day, its three moments,
the figures and the sentence, the goal and its size) is `product-model.md`. How the code computes it: `daily-ring.md`. Why each rule won:
`ring-design.md`, `day-model-research.md`, `first-exposure-research.md`. What each screen shows: `screens.md`. Terms:
`GLOSSARY.md`, section "Mnemit".

## The journey

### One day

```
Today ─Study─► the stack ─► Streak kept ─Keep Going─► the stack ─► Ring closed ─Catch Up─► the stack ─► All done
                                │ Done for Now                       │ Done, or Learn 10 New Words          │ Done, or Learn 10 New Words
                                ▼                                    ▼                                      ▼
                              Today                                Today                                  Today
```

The ordinary days:

1. A usual day: Study, the first ≈ 2 minutes fill the flame (Streak kept), Keep Going, the ring closes with the plan done:
   Done or Learn 10 New Words. The third moment does not exist.
2. After a lesson: Add Cards, Study These Now, the stream over that deck (the next journey), then the day as above.
3. After a break: Study, Streak kept, Ring closed with reviews left (Today's figure reads "Reviews left ≈ 12 min"), Catch Up,
   All done: Done or Learn 10 New Words.
4. After a missed day: the flame carries "!" and the first two moments are one: Study until the ring closes, "Streak saved",
   the Comeback medal; then as above.

A plan of two minutes or less closes the ring without the streak's rest. Leaving anywhere loses nothing: Today picks
up the count, and Study goes on where the stack was.

### After a lesson: Study These Now

The course learner adds the lesson's words at the desk, One Card or From a List, in a minute. Once cards are added the
bottom bar of Add Cards holds Add and Study These Now, which adds what is typed too, closes the sheet and starts a stream
over that deck: the added cards first, then the deck's plan. Words of the list the deck holds but hasn't started go
with them: the day's addition is the first of the new cards, today and on the days after, until it is learned. They are asked as new cards are (the Meaning → Word card of a word
waits until its Word → Meaning card has an interval of 7 days), they go beyond the deck's New cards/day and take the place of its
new cards of the day, so tomorrow's load is what it would have been had the queue chosen them, and they count toward the
ring and its laps. The lesson's words come first even without the button: the newest addition heads the queue, and the
ring decides how many come. A table of up to 50 cards imported into a new,
empty deck offers the same button.

### Learn 10 New Words raises the stakes

- **What it adds.** Ten new cards beyond the day's allowance and New cards/day, from every deck that has new cards left, one at a time to
  the deck that has given the fewest so far, and asked mixed as the plan is, at once and without another rest. No
  count to choose: FSRS keeps deciding which cards come. Each of them is asked like any new card.
- **What it costs.** Each new card comes back as reviews. Ten cards bring about 2 reviews the next day, 8 the day after,
  3 on the third, 12 more over days 4 to 14, then a thin tail (FSRS-6 defaults with Mnemit's fuzz, `cards.py --echo`: short
  intervals are not fuzzed, so the first return is a peak, and the later ones spread). Reviews come first in the plan, so the peak
  fits the day's time and takes the place of the ring's new words: on the logs of 854 Anki users, a learner who pushes
  on one day in three has no new word in the ring on 46 % of study days, one who stops at the ring on 13 %.
- **What it doesn't change.** The day's time. A day of pushing on is a good day, and the next one is usually an
  ordinary one: raising the time to what the learner did (at least 0.6 of the work) cut the closed share of real users
  from 0.81 to 0.70 and perfect first weeks from 41 % to 28 % (`ring-design.md`).
- **The button.** "Learn 10 New Words": the label says what happens, and no footnote repeats it. From Today it opens
  the stack with the ten cards at once, over every active deck, without the rest first; the ten count toward the ring and
  its laps. The code keeps the old name (`DayAction.pushOn`, `StudyModel.Entry.pushOn`).

### The day after

The time follows the rings, out of sight (`daily-ring.md`, "Day's time"). A missed day is forgiven when the next ring
closes; two in a row end the streak, and the best run stays in Progress.

### A newcomer's first days with a new deck

The first launch plays the introduction, six steps (`screens.md`, "First launch"): a welcome; **a new word's first
showing**; the two swipes (left Forgot, right Good); "One stack a day"; sync; the reminder. The first showing is a practice with one sample card
("a janela", "the window"): question, Show Answer, then the two wide buttons of a new card, Don't know and Know. Don't know
slides the card under a small stack with "It comes back after a few cards."; Know slides it right with "It comes back once
more before you're done." Both lines are true of the scheduler's first steps (`scheduling.md`, "A new card's first
showing"); nothing is graded, recorded or scheduled. The swipe practice then teaches the four grades, and "One stack a
day" says in four lines what the stack, the ring, the streak and the ladder of words are.

Today with no deck offers New Deck first and Shared Decks second, the iCloud folder as a link under them. Nothing is set for
new words: the ring decides how many come. A new deck opens
Add Cards by itself, and Study These Now studies what was just added. A new word is asked the first time it comes up, like any
card, with the same two buttons (Don't know is Again, Know is Good; the swipes give only these two), and the card comes
back in the session (`scheduling.md`, "A new card's first showing"). The first grade is the first review: it moves the ring
when the card is done and writes a log entry. Two minutes fill the flame (the Streak kept rest reads "1-day streak"), and the
first medal comes at 10 words learned.

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
until then their extra words come through Learn 10 New Words.

### A return after a break

Days without study leave the time as it was. The plan holds every overdue card; the ring is the most forgotten that fit
the time, with no new word while reviews fill it; the rest waits behind Catch Up once the ring is closed, where the next moment's figure prices it ("Reviews left ≈ 12 min"). A learner who
stops at the ring meets Catch Up on 6.9 % of a newcomer's study days and 10.4 % of a real user's.

### An Anki user

The imported collection brings its history, and the replay of the history runs the day's-time rule (`daily-ring.md`), so the time arrives near the
learner's usual day. The ring holds the whole queue up to an hour, and what is due beyond it is "Reviews left ≈ 45 min" after the ring, not a
ring that cannot close. A deck's Today card shows "≈ 4 min" beside Anki's counts, Due 14, New 6 and Learning 2; How It Works shows the plan,
the time and the FSRS parameters. A deck's new cards are asked at once, whether the deck is made in the app or by an Anki package.
An Anki package's new cards keep Anki's new-card order. New cards/day, Anki's setting under Anki's name, works as in
Anki: the deck takes that many new cards a day, outside the ring's allowance, and the other decks keep theirs.

### Several decks

One stack over every active deck with a plan for today. The next card comes from the deck whose next card is the most
urgent: a card in learning, then the review with the lowest recall probability, then a new card from the deck that
has given the fewest. The day's new-card allowance is split between the decks without New cards/day from one queue over them: new words
newest addition first, opened Meaning → Word cards alternating with them one for one; a deck with New cards/day takes that many,
outside the allowance. Learn 10 New Words shares its ten cards one at a time. A paused deck is out of the day's plan; what was done in it stays done. A deck with nothing in today's plan does not open
with the stack, so Learn 10 New Words takes from the decks that did. Study These Now and Study This Deck are streams over one deck.

## The stack in the stream

**The stack.** The card on top lies on the sheets under it, drawn as the edges of a book's pages:
under its bottom edge blank sheets with its corner radius, each 8 pt lower and 7 pt narrower
on each side than the one above it, darker and fainter with depth; up to four of them (`StackPose`), one fewer than the cards left before the next moment, so
a long stretch looks thick and the last five thin out one line at a time; after the ring the stack is the cards of Catch Up,
of Learn 10 New Words or of Study These Now.
- Graded, the card goes on with the finger and leaves past the edge of the screen. Nothing rides on
  it: a label on a card that is leaving is never read.
- Done (another day): the deepest line fades, the stack moves up a step, the next card rises from
  the first line; the ring in the bar steps, bumps and bursts, and the interval shows in the header's text for a moment.
- Back today (a step to go, or Forgot): the card comes in again from the edge it left by, already
  a sheet, and slides under the stack, where it becomes the deepest line: the stack is as thick as
  before, which is why the card comes back.
- A word that keeps slipping: after the Forgot that makes a card a leech (`scheduling.md`, "Leech") the stream stops before
  the next card on "Keeps slipping", the card's question and answer, and Continue, Edit and Set Aside (Keep It when the
  deck's action Suspend already suspended it). Undo takes back the grade and the moment together.
- The last card of a stack has no lines. When it leaves, what lay under it shows: the ring comes down from the
  bar into its place, and the rest's lines come in.
- Undo plays the grade backwards: the card comes in from the edge it left by to the top, out from
  under the stack if it went there; the ring takes its step back; a leech's moment goes with the grade.
- Reduce Motion: the card fades in place, the ring steps without a bump, nothing travels.

## Progression: the ladder of memory

The stack shows what is next, the ring the day, the streak the habit, words learned the gain. What a learner
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
- **Progress.** The Memory section of the Progress screen shows the ladder of all cards started as one segmented bar
  in the ramp's colours, with "N not started" under it and the five steps as a legend with their counts.
- **For the Anki user**, the same section has the cards per step, and a deck's Statistics the true retention
  against the target.

Not added, as they reward volume over memory and pull against FSRS: points, leagues, hearts, reviewing
ahead for a bigger number. No medal counts answers: the lap medals read the share of the goal done in a day, the words medals
the words that left learning; grading fast or reviewing early earns nothing.

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
| Words learned | 10, 50, 100, 250, 500, 1000, then every 1000 | the first day the count of words that left learning reaches the tier (`WordsLearned.milestones`) |
| Double ring, Triple ring | one each, on every day that reaches it | a day whose ring went round 2 or 3 times (`DayRecord.ringShare`); a 3-lap day earns both |
| Comeback | one, then counted | a missed day made up by closing the next day's ring: the streak survived |

**The comeback scenario.** The day after a missed day, Today's next moment reads "To save your streak ≈ 6 min" instead of
"To keep your streak ≈ 2 min", and the Day streak figure beside it, still 12 days, carries an orange outline of a flame with an
exclamation mark. When that ring closes, the rest's title is "Streak saved", and Comeback is earned. Two missed days in a row end the streak as before.

**Hidden progression.** On the Progress screen each line shows its earned tiers in colour with their
dates, the next tier as a grey medal (a dashed outline and the line's symbol in `Color.inactiveMark`, its title in secondary, an earned one on a
gradient of the accent with a shadow) without a count of how far there is to go (Deci, Koestner & Ryan 1999:
`ring-design.md`, "Medals and the monthly recap"), and nothing of the tiers after it: there is always one more to find. A line that repeats shows how often as a badge on the disc,
never in the title.

**Emoji or SF Symbols.** An earned medal's face is an emoji, for colour and the moment of joy; it is
seen only once earned, so the next tier, a grey medal, shows the line's SF Symbol and keeps its emoji a
surprise. Everything else is SF Symbols: the streak's flame on the Today card, in the stream's header and in the widget, the rows of
records and figures, the lines of the rests. The faces:

| Line | Faces, tier by tier | Next tier's symbol |
|---|---|---|
| Streak | 🔥 3 days · ⭐️ a week · 🌟 2 weeks · 🌙 a month · 🌿 2 months · 🌳 3 months · ⛰️ half a year · 🏆 a year · 💎 a year and a half · 👑 2 years | `flame` |
| First ring | 🎯 | `circle.circle` |
| Perfect week | 🌈 | `calendar` |
| Words learned | 🌱 10 · 🍀 50 · 💯 100 · 📖 250 · 📚 500 · 🧠 1000 · 🦉 2000 and more | `book` |
| Double ring, Triple ring | 💫 · 🌀 | `repeat` |
| Comeback | 🐦‍🔥 | `arrow.uturn.up` |

**The Progress screen**, from Today (a tap on the Today card, which has a chevron at the end of its week row), top to
bottom: the streak card (the flame, the days large and "Day streak", "Best: 21" when the best run is longer than
the current one); the totals as tiles, Days studied, Rings closed, Words learned and Your ring ("8 min", "a day · started
at 2.5"), with no ring, the day's ring being on Today; the calendar, Monday to Sunday under the weekday
initials, a row per week from the one of the first study day, at most 13 ("Last 13 weeks" once there are 13, else
"Calendar"), each day a ring of its share of its goal (laps past the goal, up to three), with a band in the streak's orange behind each run of two or more kept days within a week; the medals (the
latest up to five, and Show All: one row for the lines of one medal, then a row per line of tiers); the memory section (the words in memory, and the ladder of
memory, a bar of the cards started with "N not started" under it and a legend of the five steps); and How It Works as
the last row.

**Celebrations.** A medal is celebrated the moment it is earned: in the stack a compact toast stands in the gap
between the card and the buttons (on the Mac in the header's row) for 2.5 s (one after another), the ring in the bar bumps and bursts, and a success haptic plays; a rest
shows the most notable medal of today under its title, with "+2 more" when there were others, and Today lists the medals of earlier days that this
device never celebrated (earned on the Mac) once as "New medals". The device keeps what it has celebrated in
`UserDefaults` (`CelebratedMedals`, `"<kind key>@<day>"`), and its first read marks everything from before
today silently, so an update brings no flood. **Every month** has a screen of its own: on the first
open of a new month, after a month with study, Today shows "October" as a sheet: rings closed of days,
cards done, the best streak of the month, the achievements of the month, and See All Progress.

## What the day does not have, and why

| Not in the day | Instead | Why |
|---|---|---|
| A rest after every round | one rest, at the streak; the next at the ring | a stop every 2 min breaks the flow; the ring already shows progress; the one stop that pays is the streak (Duolingo: the streak screen raised day-7 retention by 1.7 %) |
| "Round 2 of 4 · ≈ 2 min" on Today, in the bar, in the widget, on the Mac | one figure with the minutes to the next moment | two progress measures beside one ring; rounds are an internal unit of time |
| The day's time, "Next round ≈ 2 min" | How It Works only | the size of the day is learned, not chosen |
| Review ahead after catch-up | gone from Keep Going | reviewing before due gains FSRS little, and fills the ring with low-value work; more work is a new card |
| Keep Going running catch-up, then review ahead, then practice | Catch Up when the plan has cards left; Learn 10 New Words once the stack is done | one named way on; practice stays on the deck screen |
| Practice after the plan, a stream that never ended | gone: the stack ends with the plan | a day with an end; practice changes no card and stays on the deck screen |
| "+10 new" with "≈ +2 cards/day next week" | Learn 10 New Words, with no footnote | the learner decides whether to raise the stakes, FSRS which cards come; the count and the forecast asked for a choice the learner can't weigh |
| The ring closing in the middle of a stream after a break | the stack stops at the ring | the ring is the day's goal; the cards beyond it stay in the plan and Catch Up goes on with them |

Kept as they are: one stack over all decks, the 04:00 day, the ring in cards, work beyond the goal counted
as cards done, the streak's repair by a closed ring, words in
learned, pausing a deck, practice from the deck screen.
