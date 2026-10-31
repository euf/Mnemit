# Which number learners compare

Measured 31 Oct 2026, for a screenshot learners can brag with now and maybe a server later. The ring is no basis: its
closure tracker drives every learner to about 78 % closed rings (`ring-design.md`). Measurements, all in `Tools/ring-sim/`:
`cards.py --compete --days 168 --seeds 40 --sched fuzz` (honest learners against liars, FSRS-6) and `real.py`, sections 9
and 10 of `real-stats.md` (2,000 Anki users, 144 million answers).

## The recommendation

**The number: cards held three weeks, this week.** The answers of the last 7 days that passed (Hard, Good, Easy) on a card
whose interval was 21 days or more. The app computes it already: `TrueRetention`, period `last7Days`, mature reviews
passed (`matureInterval` 21). A card passes at such an interval at most once a week, so the count is of cards.

**The plausibility line: the week's median seconds an answer**, printed beside the number and marked under 2 s.

- It ranks honest learners by their time. From week 12 on, the median week holds 27–33 cards at 5 minutes a day, 108–124
  at 20 and 325–360 at 60 (simulation).
- Lying at a human pace buys little. Good on every review, whatever the learner recalled, scores like 24–29 honest
  minutes a day for 20 spent; Easy on every new card like 20–22 from week 12 on.
- Clicking at 1.5 s an answer scores like 250–320 honest minutes a day in weeks 8–12, and the clicker who presses
  Again on a tenth still like 137 in week 16; the pace line shows either every week. On real users a median under 2 s comes up in 2.5 % of user-weeks and on 0.65 % of users in half their weeks or
  more.
- It costs the newcomer a month: zero in 97.5 % of real users' weeks 1–4 and in 46 % of weeks 5–8; a quarter of an
  established user's weeks are zero too.

## The liars in the simulation

`compete()` in `cards.py`: honest learners of 5, 10, 20, 30, 45 and 60 minutes a day and four liars of 20, 40 of each,
168 days. Each spends the day's minutes (lognormal, sigma 0.5, 15 % of days skipped) on every card due, most forgotten
first, then on new cards from a deck of 10,000; Mnemit's fuzz sets the due dates, 30 s a new card and 10 s a review for
everyone but the clickers. Each card has two memories: the app's, FSRS-6 on the buttons pressed, which schedules the card;
and the true one, FSRS-6 on what the learner recalled. An honest button is the truth. The liars:

- **Easy on every new card**, reviews answered honestly.
- **Good on every review**, whatever the learner recalled; a forgotten card gets no relearning step.
- **Click for volume**: 1.5 s an answer, Good on everything. A new card is a glance (Again's stability, no steps), and a
  clicked review is no retrieval: the true memory takes the post-lapse stability, as on seeing the answer.
- **Click, Again on a tenth**: the same clicker pressing Again on a random 10 % of reviews and 22 % of new cards, the
  honest shares.

Each cell is the liar's median weekly score, given as the honest minutes a day whose median scores the same: the honest
peer is 20. The true columns are what the liar earned; for honest learners they equal the app's.

| liar, 20 min a day | answers, wk 4 | sum of R gained, wk 4 | sum of R gained, wk 16 | durable, wk 8 | durable, wk 12 | durable, wk 16 | durable, wk 24 | durable × retention closeness, wk 16 | truly durable, wk 16 |
|---|---|---|---|---|---|---|---|---|---|
| Easy on every new card | 19 | 22 | 25 | 116 | 20 | 20 | 22 | 7 | 20 |
| Good on every review | 19 | 23 | 34 | 29 | 26 | 28 | 24 | 0 | 24 |
| click, Good | 195 | 222 | below 0 | 251 | 323 | 17 | 0 | 0 | 6 |
| click, Again on a tenth | 196 | 191 | 4 | 323 | 205 | 137 | 54 | 152 | 53 |

Honest medians of the durable count, cards a week:

| honest learner | wk 6 | wk 8 | wk 12 | wk 16 | wk 24 |
|---|---|---|---|---|---|
| 5 min | 3 | 5 | 28.5 | 28.5 | 33 |
| 10 min | 4 | 11.5 | 51.5 | 53.5 | 56.5 |
| 20 min | 9 | 23 | 112 | 108 | 124 |
| 30 min | 10.5 | 32.5 | 162 | 172 | 184 |
| 45 min | 20 | 57.5 | 232 | 254 | 280 |
| 60 min | 30 | 61.5 | 325 | 354 | 360 |

What each metric does with them:

- **Answers done.** A clicker answers about 6,000 cards a week against an honest 20-minute learner's 550, the score of
  195 honest minutes a day. The clicker runs through the 10,000-word deck in its second week; Mnemit has no review ahead,
  so from then on only due cards feed it. Anki's leaderboard counts every answer, learning steps included, where an Again
  loop alone makes volume without bound.
- **Sum of R gained** (words in memory, the app's count). The clicker's first weeks score like 190–220 honest minutes;
  afterwards its sum falls in most weeks, since 10,000 barely learned cards decay faster than due cards top them up. Good on
  every review adds 60–85 % from week 12 on: every lapse it hides keeps a long interval in the app's model.
- **Durable** (passed at 21 days or more). Nobody scores before week 5. Good on every review moves it 20–45 %; most of
  the liar's passes are true, since FSRS-6's forgetting curve is flat and a card the learner saw recently is recalled
  often. Easy on new cards brings the 21-day intervals forward: week 8 scores like 116 minutes, every pass of it truly
  recalled, and from week 12 on the liar is back at 20. Clicking pays with a delay: thousands of new cards
  clicked in the first two weeks come due at 21 days and more in weeks 6–16.
- **Durable × closeness of true retention to 0.9** (1 − |TR − 0.9| / 0.1 over 4 weeks). It zeroes the liars who never
  press Again and leaves the calibrated clicker untouched (TR 0.90). It also punishes Easy on new cards for failing its
  long first intervals honestly (TR 0.77–0.84). Honest simulated learners sit at TR 0.87–0.89.

## Real users

`real.py`, section 9: answers passed 21 days or more after the card's previous review (elapsed days: the dataset has no
scheduled interval), per week since the user's first review, weeks with a review.

| weeks since first review | user-weeks | durable = 0 | p25 | median | p75 | p90 | durable / answers, median |
|---|---|---|---|---|---|---|---|
| all | 188,748 | 28.4 % | 0 | 21 | 101 | 264 | 0.092 |
| 1–4 | 5,813 | 97.5 % | 0 | 0 | 0 | 0 | 0 |
| 5–8 | 4,510 | 46.0 % | 0 | 1 | 13 | 44 | 0.003 |
| 9–26 | 17,245 | 30.1 % | 0 | 13 | 63 | 155 | 0.056 |
| 27–52 | 22,200 | 27.9 % | 0 | 21 | 88 | 218 | 0.087 |
| over 52 | 138,980 | 24.8 % | 1 | 28 | 121 | 303 | 0.122 |

Per user from week 9 on (1,988 users): the median week holds 8.5 durable cards (p75 42.5, p90 113); the median user has
31.8 % of their weeks at zero. These users study on a quarter of their days (`real-stats.md`, section 1), so many weeks
hold a single short session.

Section 10, the flags. A user fires persistently in half or more of their eligible weeks.

| indicator | fires when | user-weeks firing | users firing in any week | users firing persistently |
|---|---|---|---|---|
| true retention, last 4 weeks (30+ review-state answers) | ≥ 0.97 | 19.6 % | 68.9 % | 14.9 % |
| | ≥ 0.98 | 15.6 % | 61.6 % | 11.3 % |
| | = 1 | 6.4 % | 45.2 % | 4.3 % |
| Again on first answers of new cards (20+ new cards in the week) | = 0 | 24.1 % | 72.4 % | 22.5 % |
| | < 5 % | 35.7 % | 81.3 % | 35.5 % |
| median seconds an answer (30+ answers in the week) | < 1.5 s | 1.6 % | 21.4 % | 0.40 % |
| | < 2 s | 2.5 % | 28.1 % | 0.65 % |
| | < 3 s | 6.9 % | 45.0 % | 3.35 % |

Real true retention over 4 weeks spreads wide: p10 0.66, median 0.89, p90 0.99. The closeness factor above is 0 in
26.2 % of real user-weeks and under 0.5 in 65.2 %. The Again share on new cards' first answers: p25 0.4 %, median 18 %, p75
45 %. The median seconds an answer: p1 1.0, p5 2.6, p10 3.4, median 8.2.

## Why the pace line

- **True retention near 100 %** catches the liars who never press Again, and fires persistently on 11.3 % of real users
  at 0.98, who were scheduled mostly by SM-2 and never aimed at 0.9; Anki's leaderboard FAQ explains 100 % by a 99 %
  desired retention, filtered decks, easy cards first and suspended failures. The lie it catches buys 20–45 %, the effect of 4–9
  more honest minutes a day, and a liar who presses Again on a tenth escapes it. As a factor on the number it zeroes a
  quarter of real weeks.
- **Again on first answers of new cards** fires persistently on 22.5 % of real users at zero. It reads a habit (Good
  as "show me the next step") and decks of words the learner knew; Easy on new cards does not inflate the durable count
  for long anyway.
- **Pace** catches both clickers, the liars whose gain is large, every week, and fires persistently on 0.65 % of real
  users at 2 s. Mnemit logs it: `ReviewLogEntry.duration`, the milliseconds a card was on screen. A clicker slowed to
  2 s spends a fifth of the honest time on a review and a fifteenth on a new card and would still score above honest
  learners; the line then shows 2 s against a typical 8.

## What a server would add

- **Events stamped at review time.** Today the number comes from the deck's `reviews.jsonl`, a file the learner can
  edit: a script writes a thousand passes at 30 days in a second, and moving the device clock forward three weeks makes
  any card due at a "21-day interval". The month a liar must wait holds only when each answer reaches a server within
  minutes of being given and the server's clock measures the interval.
- **Plausibility across learners.** Pace, answers a day, new cards a day against the population (the first two weeks:
  p90 55 new cards a study day, `real-stats.md` section 5), and pass rate against the deck's desired retention: an
  FSRS schedule sends every card back at the desired R, so an honest learner's pass rate on time sits near it.
- **Fair company.** Durable counts grow with weeks since start (median 13 a week in weeks 9–26, 28 after a year): a
  server can rank a learner among learners of the same age.

## What a server cannot add

Every answer of the app is self-graded (`ReviewMode.revealed`; `typed` is legacy and records nothing new). Good on a
forgotten card at a human pace is the same event as an honest pass, and a learner whose real pass rate is high looks the
same as a liar. Checking a grade needs an answer the app compares with the card, typed or spoken. Words known before
the deck began also pass honestly: the count measures memory kept, learned here or earlier.

## Limits

- The liars' true memory is FSRS-6 with default parameters; its forgetting curve is flat, so the true columns flatter
  every liar.
- The real logs are Anki users, mostly scheduled by SM-2; how far Mnemit learners on FSRS spread in retention and pace
  is unmeasured.
- The real durable count uses elapsed days; `TrueRetention` uses the scheduled interval, which leaves out young cards
  that came back late after a break.

## Sources

- Anki Leaderboard (Shige's fork): https://shigeyukey.github.io/shige-addons-wiki/anki-leaderboard.html. Ranks by
  cards reviewed today, time today, streak, reviews in the past 31 days and retention; XP = days studied × (6 × time +
  2 × reviews × retention), a retention of 85 % or more counted as 100 %. Its cheating FAQ permits cheats outright:
  grading is the learner's own and can't be verified.
- `ring-design.md` (the ring and its closure), `real-stats.md` (the real logs), `Tools/ring-sim/cards.py` (the model).
