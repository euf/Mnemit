# Mnemit: the product model

The one description of what Mnemit is for, the entities a learner holds, the loops that keep them learning, and how
every surface follows from them. Other documents explain how the code computes it (`daily-ring.md`), why each rule
won against its alternatives (`ring-design.md`, `first-exposure-research.md`, `ring-streak-design.md`) and what each
screen shows (`screens.md`). A new feature or screen starts here: if it needs an entity this page doesn't have, the
page changes first.

## 1. The promise

**Remember the words you are learning, for minutes a day, without managing a schedule.**

FSRS knows when each card should come back. Mnemit turns that into a day a person can keep: a habit that costs two
minutes, a goal sized to their usual day, and a gain they can see grow.

## 2. Who it is for

| Persona | Rhythm | Job | Leaves when |
|---|---|---|---|
| **Course learner** | phone, 2–10 min several times a day; a desk after each lesson | keep the habit at no cost; get a lesson's words in tonight; remember them by the next class | the habit costs more than a minute to start; new words wait for days |
| **Newcomer** | phone only, no decks, never used flashcards | start in two minutes; feel progress on day one; build a streak | a red failure or an unexplained number in the first minutes |
| **Anki veteran** | desk and phone, 30–60 min a day, years of history | bring the history; trust the schedule; study by keyboard; see the counts | counts don't match Anki; the schedule is second-guessed; the day is hidden |

## 3. Principles

1. **FSRS decides what to study; Mnemit decides how much and how it feels.** The learner never schedules anything.
2. **One unit of work: the card.** It is seen as objects (the stack, the ring) and counted only inside a deck.
3. **Minutes translate, they never measure.** "≈ 2 min" turns the cards ahead into a decision; it is always an estimate
   at the learner's own pace and never a goal.
4. **The habit costs two minutes; the goal is your usual day; extra is celebrated, never required.**
5. **One next thing at a time:** one sentence, one button, one stack.
6. **Words are the gain; everything else is effort.**
7. **Anki-grade truth one tap away:** counts, FSRS figures and retention live in the deck, not on Today.
8. **Nothing to configure to succeed.** Settings are ceilings and preferences, never a plan.
9. **Progress never goes back.** A day, once over, keeps what it earned: its ring, its place in the streak, its medals and
   the words it learned stay, whatever later happens to the decks and cards.

## 4. The entities

Seven, and only these appear on screen.

| Entity | What it is to the learner | Shown as |
|---|---|---|
| **Deck** | a set of words they study | name; on Today ≈ minutes left today or ✓ |
| **Card** | one question and its answer; a word gives two (Word → Meaning, Meaning → Word) | the card on screen; numbers only inside a deck (Due, New, Learning, Suspended) |
| **Stack** | the cards left before the next moment of the day | edges under the card, up to four, fewer at the end; never a number |
| **Ring** | how far today is | an arc of the cards done against today's goal, laps past it; never a number |
| **Streak** | the habit: days in a row | a flame and the days, a line of its own under the ring |
| **Words learned** | what they keep: words whose Word → Meaning card has left learning | "412 words learned · +12 today" |
| **Medal** | a moment worth remembering | a toast when earned, a shelf in Progress |

Not entities, never named on Today: minutes (a translation), reviews and answers, rounds and steps, the plan, the goal's
size, the allowance, stability and difficulty (the card's Details and How It Works hold them for those who look).

## 5. The day

**What FSRS gives.** Each card has a due date. Today's plan is every card due (overdue first, most forgotten first)
plus new cards: as many as the time left after the due cards allows, within the deck's per-day ceiling.

**What Mnemit adds: today's goal.** The plan's cards that fit the learner's usual time (the day's time, at their
measured pace; due cards first, then new). The ring is the cards done against that goal. The goal never grows with
a break: a backlog stays in the plan and waits after the ring.

**Up to three moments**, each the end of a stack:

| Moment | Reached when | What it gives | Rest |
|---|---|---|---|
| **Streak kept** | the first ~2 minutes' worth of cards are done | today counts in the streak; the flame fills | Keep Going · Done for Now |
| **Ring closed** | the goal's cards are done | the day's learning is done; the ring bursts | Done · Catch Up or Learn 10 New Words |
| **All done** | the plan's last due card is done (Catch Up) | nothing is due until tomorrow | Learn 10 New Words · Done |

On most days the ring takes the whole plan and the third moment doesn't exist. **After a missed day** the first two
moments are one: only the closed ring keeps the streak ("!" on the flame). Two missed days end it; the best run stays in
Progress.

**Beyond the day**, by choice: **Learn 10 New Words** (the next ten new cards) and **Study These Now** (the cards just
added after a lesson, first in a stream over that deck, then the deck's plan; they take the place of the day's new
cards, so tomorrow's load is the same as if the deck had chosen them). Both count toward the ring and its laps.

**The streak** stands beside the ring as a figure, "Day streak 🔥 12", in the same place and form all day; the flame's
shape is its state (an outline while today's step is open, filled once it is kept, an outline with "!" the day after a
miss). **The next moment** is the figure under it: its label names the moment and its value is the ≈ minutes: "To keep
your streak ≈ 2 min" → "To close the ring ≈ 5 min" → "Reviews left ≈ 12 min" → "Today: All done". After a miss: "To save
your streak ≈ 6 min" (the ring); without a streak the streak reads 0 and the moment "To start your streak". Where one line
of text is all there is room for (the rests, the small widgets, the reminders, VoiceOver) the figure reads as one
sentence: "≈ 2 min to keep your streak", "≈ 5 min to close the ring", "Ring closed · ≈ 12 min of reviews left", "All done
for today". **The button** follows the moment: Study, then Catch Up, then Learn 10 New Words.

**A card** is asked; a tap shows the answer; the learner grades it: left no (Forgot; "Don't know" on its first showing,
where two wide buttons, Don't know and Know, replace the four), right Good, up Easy, down Hard. A card leaves the stack
and moves the ring when FSRS lets it go until another day; a Forgot slides it back under the stack and moves neither.
The colour says how easily the word came: red for Forgot; three greens whose chroma rises from Hard, a dull sage, through
Good to Easy, a vivid jade.

**A word that keeps slipping** (a leech: as many lapses as the deck's threshold, 8 by default as in Anki, and again at
every half threshold after it, 12, 16 …) is never taken away silently. On the Forgot that makes it one, its answer stays on
screen under "Keeps slipping", with Edit (a hint, an example, a clearer question), Set Aside and Continue: the answer
right after an error is what helps most (Pashler 2005: +494 % at a week; Rowland 2014: g 0.73 with feedback, 0.39
without), and rewriting the card is Anki's and SuperMemo's first advice (`leech-research.md`). The deck's leech action decides what Continue
leaves: **Keep** (the default) keeps the card in rotation, where FSRS goes on scheduling it (on the logs of 2,000 Anki
users, cards past 8 lapses are 1 % of cards and 7.6 % of review time, and 72 % of their later answers are recalled, against
85 % overall, `Tools/ring-sim/leeches.md`); **Suspend**, Anki's classic action, sets it aside, and the moment offers Keep It instead of Set Aside. A
deck's Cards have a Leeches filter; the Mac's table adds the columns Lapses, Stability, Difficulty and Recall.

**The past is written down.** When a study day is over, its record is kept: the cards done against its goal, whether it
kept the streak and closed the ring, the words learned by its end. Past days are read from these records and today from
the cards, so pausing, resuming or deleting a deck, or deleting or rewriting a card, never changes a past day. A record
only rises, when answers of that day arrive late from the other device; both devices keep the same records beside the
decks.

**A deck that changes while it is open** (on the other device, or rebuilt from a table) changes in place: kept cards
keep their progress, new cards come as new, a deleted card leaves the stack without a grade while its answers stay in
the log, so today's ring keeps what it counted; an undo still takes back the last grade.

## 6. The loops

- **The habit loop (daily):** the widget shows the flame and the days with "≈ 2 min to keep your streak", or the reminder
  says "Keep your 12-day streak · ≈ 2 min" → one tap to the first card → two minutes → the flame fills, the rest offers
  Keep Going. Cost two minutes, reward immediate.
- **The learning loop (a sitting):** the card, the answer, the stack shrinking, the ring filling → the ring closes → Catch Up
  if due cards remain, Learn 10 New Words if not.
- **The progress loop (weeks):** words learned and their milestones, the week of rings, the calendar with streak runs and
  laps, medals, and the ring's own size growing with the learner ("Your ring: 8 min a day · you started at 2.5").

## 7. Rewards

| Medal | For | Why it matters |
|---|---|---|
| Streak milestones (3, 7, 14, 30, 50, 100 days …) | the habit | consistency is the goal; Duolingo's split of streak and goal raised 7-day streaks by over 40 % |
| First ring, Perfect week | the learning loop | the first full day; a week of closed rings |
| Comeback | returning after a break | a return is worth more than a perfect run |
| Double ring, Triple ring | 2 or 3 laps of the goal, on every day that reaches them | extra, kept rare by the goal's size (§8) |
| Words learned (10, 50, 100, 250, 500, 1000, then every 1000) | the gain | the newcomer's meta-progression |

Rewards are for consistency and gain, never for volume alone: no medal for cards answered.

## 8. The goal's size and the laps

The ring is only worth closing if closing it is usually possible, and laps only feel like a gift if they are not the
norm. The rule today is a staircase on closed and open days (×1.15 after every second closed ring in a row, ×0.775 after
an open one, 2–60 minutes), chosen in `ring-design.md` because it is the one rule that converges to about 80 % closed
days and doesn't stall for a learner who stops at the ring. Its weakness: a learner who goes on every day (EF, 1.4–3.5×
the goal on each of his first five days) sees laps every day, which empties laps and the Double/Triple ring medals.

Criteria for any change (measured in `Tools/ring-sim/` before it ships): closure 0.70–0.85 for learners who stop at the
ring, open runs no longer, words kept no fewer, and fewer laps for learners who go on.

**Decided (26.10, `Tools/ring-sim/overshoot.md`): the staircase plus a sustained-overshoot step.** From the 8th study
day, when the work reached 1.5 × T on 3 of the last 4 study days, T becomes the larger of the staircase's T and the 25th
percentile of those four days' minutes, at most × 1.5 per day, capped at 60 min. A learner who stops at the ring never
triggers it (their closure and words are the baseline's exactly); for learners who go on every day Double ring falls from
26 % to 16 % of days (synthetic) and from 50 % to 25 % (real Anki users) at a closure of 0.75 / 0.70, and their first week
is unchanged. Learners who go on in stretches lose 0.05 closure. The constants are flags in `DailyGoal`.

## 9. Surfaces

Every surface is the entities above and nothing else.

| Surface | Shows |
|---|---|
| **Today** | the date under the title; the Today card: the ring (no number) left, its figures right (Day streak, the next moment with ≈ minutes, Words learned with +today), the week of rings under them, the card opening Progress; the Decks card (rows ≈ min or ✓); the button; empty: the ring and "Add the words you are learning.", New Deck, Shared Decks |
| **The stream** | the card, the stack, the header: ring, flame and days, ≈ minutes to the next moment; the rests at the moments |
| **A deck** | its Today card: "≈ 4 min" as the large value, Due, New and Learning as figures beside it; then Cards (browser with filters), Statistics (tiles Cards, Due, New, Suspended, Recall Now; the Retention card), Options |
| **Progress** | the Streak card (flame, days, best); tiles Days studied, Rings closed, Words learned, Your ring (8 min a day, started at 2.5); the calendar card of rings; Medals; Memory; How It Works |
| **Widgets** | medium: the Today card (the ring left, the three figures right); small: the ring, the streak and the sentence under it; lock screen: circular the ring with ≈ minutes, rectangular the streak and the sentence beside a small ring, inline "🔥 12 · ≈ 2 min" |
| **Reminders** | "Keep your 12-day streak · ≈ 2 min", and at 21:00 while the streak is at stake; the badge "1" while the ring is open |
| **The Mac** | one window: the same Today, stream, decks and Progress, by keyboard |

A medal's toast never covers the ring, the card or a button: on the Mac's Today it stands below the Study button, on the
iPhone's over the large title; in the Mac's stream in the empty middle of the header row, in the iPhone's as one compact
line in the gap above the answer's buttons.

### The grammar of the screens

The owner's references of 27.10 are Apple's Fitness Summary and the Activity app: the Activity Rings card with the ring
on the left and its figures on the right, each a label over a large value in its ring's colour; tiles two to a row; a
row of small rings for the week; a calendar of rings. Mnemit takes that grammar through the iOS 26 and macOS 26 rules
(`hig-ios26.md`), not Fitness's look:

- **Content is solid, controls are glass.** Cards, rows, tiles, the ring and the figures sit on the grouped fills
  (secondary on the grouped background); Liquid Glass is only for the bars and the controls that float over content:
  Study and search in the iPhone's bottom toolbar, the toolbar groups. Buttons inside content are bordered, not glass.
- **A screen** is a large title (on the iPhone) over grouped sections; Today's date is the navigation subtitle. A section
  is one card under its title (the list's own section header, title case), a chevron on a row that opens more; never a
  box inside a box (tiles stand on the page, not in a card), and corners concentric with their container.
- **A hero card** holds the ring on the left and its figures on the right: each figure a label over a value, the value
  in a text style with rounded numerals and in its entity's colour (the ring's indigo for the minutes, the streak's
  orange for the days), the others in the primary colour; each value carries its unit or its label says it ("Day streak
  12", "≈ 2 min", "Words learned 412"). At accessibility text sizes the ring stands over the figures.
- **Tiles**, two to a row in an adaptive grid, one column at accessibility sizes: a label, a large value, at most one
  small line under it.
- **Days** are small rings with their letters (the week on Today) and a calendar of rings (Progress).
- **The ring** is one indigo ring with laps, never Apple's three colours or three rings; colour never says anything alone
  (the flame's shape, a check, numbers). In a tinted or clear widget the track and the arc differ by opacity, and laps
  past the goal show as a number.
- **The Mac** has no large title: the title and the date sit in the window's title bar, Study is in the toolbar and in the
  page, and nothing the learner needs stands at the window's bottom edge.

The ring still leads by size, and the figures beside it are the day in words: the streak first (the habit, a mechanic of its
own: Duolingo's split, day-14 retention +3.3 %, `today-layout-research.md`), the next moment with its ≈ minutes (what the
button does), words learned (the gain). Each entity shows once, as itself; the flame is never inside the ring (8.0's
confusion, `ring-streak-design.md` §2), and minutes stay beside the ring as words with "≈", never a label on it.

## 10. The personas through it

- **Newcomer, day 1:** the introduction shows one new word, Don't know or Know, and the word coming back in the same
  sitting, then the four swipes → no decks → New Deck or Shared Decks → the first card → two minutes: the flame fills,
  "1-day streak", first medal at 10 words. Their ring is 2.5 minutes; the first moments come fast.
- **Course learner, a lesson night:** the morning widget says "≈ 2 min to keep your 12-day streak"; the bus ride keeps it;
  the evening lesson's 20 words go in at the desk and Study These Now puts them first; the stack runs out at the ring;
  laps show the extra; tomorrow the words come back as reviews.
- **Anki veteran, the first week:** the import brings cards, history and review times; the goal starts at their usual day;
  2,000 overdue cards are "≈ 45 min of reviews left" after the ring, not a ring that can't close; the deck screen shows
  Anki's counts; FSRS is untouched.

## 11. What changes from 8.0 to this model

| Area | 8.0 | This model |
|---|---|---|
| Past days | worked out from the logs of the active decks at every look: pausing or deleting a deck, or deleting a card, rewrote them | written down when the day ends and read from the records; a record only rises |
| A deleted card | gone with its answers; today's ring could drop | leaves the plan and the stack; its answers stay in the log; the ring keeps what it counted |
| A deck changed while open | merged; the table tool wrote past the apps | merged in place; the tool writes like an app; the stream drops a card that is gone |
| A word that keeps slipping | suspended at 8 lapses, marked Difficult | a leech stays on screen with Edit, Set Aside, Continue; the deck chooses Keep (default) or Suspend; warned again every half threshold; a Leeches filter; the Mac shows Lapses, Stability, Difficulty, Recall |
| Grade colours | three greens by lightness, Hard the lightest | chroma rises from Hard to Easy: Hard a dull sage, Easy a vivid jade |
| The introduction | the four swipes, the day in four lines | first a new word's first showing (Don't know, Know, it comes back), then the swipes |
| Words on screen | sentences that explain | short and plain everywhere; no text that explains the interface |
| Today | the ring, then one sentence led by the flame with the days in it | the date under the title; one card: the ring left, Day streak, the next moment with ≈ minutes and Words learned right, the week under them |
| Progress, a deck, Statistics | a streak block with small totals; a bold header line; grey boxes | cards with their titles inside, tiles with large values, the deck's Today card |
| Medal toasts | over the ring (Mac), over the card or a deck row | where they cover nothing |

## 12. Details settled in the build

- **Study These Now** is a stream over the one deck the cards went to: the added cards first, then that deck's plan. It
  offers itself in Add Cards beside Add once cards are added (prominent while nothing is left to add; it adds what is
  typed first, as Done does), and in the import of a table of up to 50 cards into a new, empty deck. It asks only the
  cards a stream would ask now: new, unlocked and not buried, so the second direction of a pair waits for its first.
- **A rest "All done for today"** stands where the ring's moment lies behind the stream: the stream began past the ring,
  or went on from its rest.
- **Deck rows and headers** price the deck's whole plan left, backlog included: "≈ 5 min", and on the deck "≈ 5 min ·
  5 due · 4 new · 3 learning", zero parts left out. The Mac's deck strip and sidebar badges use the same rule.
- **Reminders** say "≈ 2 min" always: the time to keep the streak, not the length of the day.
- **The first showing** of a new card has two wide buttons side by side, Don't know and Know, as tall as the
  two rows of the four buttons they replace; on the Mac their keys are ← or 1 (Don't know) and → or 3 (Know); ↓ ↑ 2 4 still give Hard and Easy.
- **Progress totals** run Days studied, Rings closed, Words learned; the ring's size line reads "Your ring: 8 min a
  day · started at 2.5", or without the start while the ring has not moved; words in memory sit in the Memory section.
- **The sentence**, where a figure has no room, without a streak is "≈ 2 min to start your streak" and, once nothing is
  left, "All done for today".
- **Text** on every screen is one short sentence in plain words, in en, de, ru and el: what is there or what comes next,
  never how the interface works (no footers that explain a control, no "tap to …").
- **The records of past days** live in the deck folder, one file per device, merged by day (`daily-ring.md`,
  `deck-package.md`); a device writes a day when it first sees it over.
