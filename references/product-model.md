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

## 4. The entities

Seven, and only these appear on screen.

| Entity | What it is to the learner | Shown as |
|---|---|---|
| **Deck** | a set of words they study | name; on Today ≈ minutes left today or ✓ |
| **Card** | one question and its answer; a word gives two (Word → Meaning, Meaning → Word) | the card on screen; numbers only inside a deck (Due, New, Learning, Suspended) |
| **Stack** | the cards left before the next moment of the day | edges under the card, up to four, fewer at the end; never a number |
| **Ring** | how far today is | an arc of the cards done against today's goal, laps past it; never a number |
| **Streak** | the habit: days in a row | a flame and the days |
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

**The sentence** is the day in words, one at a time: "≈ 2 min to keep your 12-day streak" → "12-day streak · ≈ 5 min to
close the ring" → "Ring closed · ≈ 12 min of reviews left" → "All done for today". After a miss: "≈ 6 min to close the
ring and save your 12-day streak". **The button** follows it: Study, then Catch Up, then Learn 10 New Words.

**A card** is asked; a tap shows the answer; the learner grades it: left no (Forgot; "Don't know" on its first showing,
where two wide buttons, Don't know and Know, replace the four), right Good, up Easy, down Hard. A card leaves the stack
and moves the ring when FSRS lets it go until another day; a Forgot slides it back under the stack and moves neither.

## 6. The loops

- **The habit loop (daily):** the widget or the reminder says "≈ 2 min to keep your 12-day streak" → one tap to the first
  card → two minutes → the flame fills, the rest offers Keep Going. Cost two minutes, reward immediate.
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
| **Today** | the ring (no number), the sentence, "words learned · +today", the week of rings, deck rows (≈ min or ✓), the button; empty: New Deck, Shared Decks |
| **The stream** | the card, the stack, the header: ring, flame, ≈ minutes to the next moment; the rests at the moments |
| **A deck** | its header "≈ 4 min · 14 due · 6 new · 2 learning", Cards (browser with filters), Statistics (Cards, Due, New, Suspended, Recall now; retention), Options |
| **Progress** | the streak (days, best), days studied, rings closed, words learned, the ring's size, the calendar, medals, the memory ladder, How It Works |
| **Widgets** | the ring and the sentence; lock screen: the ring with ≈ minutes, inline "🔥 12 · ≈ 2 min" |
| **Reminders** | "Keep your 12-day streak · ≈ 2 min", and at 21:00 while the streak is at stake; the badge "1" while the ring is open |
| **The Mac** | one window: the same Today, stream, decks and Progress, by keyboard |

## 10. The personas through it

- **Newcomer, day 1:** no decks → New Deck or Shared Decks → the first card, "Don't know" or "Know" → two minutes: the flame
  fills, "1-day streak", first medal at 10 words. Their ring is 2.5 minutes; the first moments come fast.
- **Course learner, a lesson night:** the morning widget says "≈ 2 min to keep your 12-day streak"; the bus ride keeps it;
  the evening lesson's 20 words go in at the desk and Study These Now puts them first; the stack runs out at the ring;
  laps show the extra; tomorrow the words come back as reviews.
- **Anki veteran, the first week:** the import brings cards, history and review times; the goal starts at their usual day;
  2,000 overdue cards are "≈ 45 min of reviews left" after the ring, not a ring that can't close; the deck screen shows
  Anki's counts; FSRS is untouched.

## 11. What changes from 7.2 to this model

| Area | 7.2 | This model |
|---|---|---|
| Ring's middle | cards left (7.2.x) | nothing; the ring is a picture |
| Today's gain | words in memory (a sum of probabilities) | words learned (whole words), milestones as medals |
| Big day medal | cards in a day | Double ring, Triple ring |
| First showing of a new card | four buttons, Forgot reads Don't know | two buttons: Don't know, Know (swipes keep all four) |
| After Add Cards | the cards wait for the plan | Study These Now |
| The stack after the ring | gone | the stack of Catch Up and of Learn 10 New Words |
| The sentence | streak chip and a lead line | one sentence, the next moment and its ≈ minutes |
| Deck rows / sidebar | cards left today | ≈ minutes or ✓ |
| Progress totals | rings, days, cards done | days studied, rings closed, words learned, the ring's size |
| App icon badge | cards to the ring | "1" while the ring is open |
| Empty Today | three equal paths | New Deck first, Shared Decks second, the iCloud folder a link |
