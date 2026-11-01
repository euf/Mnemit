# Which number learners compare

Measured 31 Oct and 1 Nov 2026, for a screenshot learners can brag with now and maybe a server later. The ring is no basis:
its closure tracker drives every learner to about 78 % closed rings (`ring-design.md`). Measurements, all in
`Tools/ring-sim/`: `cards.py --compete --days 168 --seeds 40 --sched fuzz` (honest learners against liars, FSRS-6) and
`real.py`, sections 9–11 of `real-stats.md` (2,000 Anki users, 144 million answers).

## The recommendation

**The number: words right this week.** The different cards the learner answered right (Hard, Good or Easy) in the last
7 days, new or reviewed, each counted once. On screen: "412 words right this week". A card that comes back three times in
the week counts once; a card answered only Again doesn't count.

**The plausibility line: the week's median seconds an answer**, printed beside the number and marked under 2 s.

- It works from the first day. Real users have zero in 2.6 % of their first weeks and in 1 % of all weeks with a review.
- It ranks learners by their time, and a newcomer's minute is worth almost a veteran's. Real users get 1.7 words right
  a minute in week 1, 2.0 in weeks 2–4 and 2.5–2.6 from week 9 on. In the simulation, from week 12 on, the median week holds
  110–121 words at 5 minutes a day, 451–482 at 20 and 1,360–1,460 at 60.
- Lying about grades buys nothing. Good on every review, whatever the learner recalled, scores like 19–21 honest
  minutes a day for 20 spent, Easy on every new card like 22–27: a forgotten card ends the day right after its relearning
  step anyway, and a card counts once a week however often it comes back.
- Clicking at 1.5 s an answer scores like 250–330 honest minutes a day in weeks 1–4; the pace line shows it every week.
- It counts words worked on, and FSRS decides which old words come back: Mnemit has no review ahead, and a Practice
  writes nothing to the review log. How much the learner keeps is not in it.

## The other numbers measured

| number | what it counts | real zero share, week 1 | real words a minute, week 1 → after a year | lie at a human pace, as honest minutes for 20 | why not |
|---|---|---|---|---|---|
| words right this week | cards answered right, each once | 2.6 % | 1.7 → 2.6 | 22–27 | the pick |
| words learned this week | new cards, the gain of Words learned | 0 % | 1.9 → 0.36 | 22–33 | a veteran's time goes to reviews: a minute of theirs earns a fifth of a newcomer's |
| words remembered this week | cards passed on review, each once | 44.5 % | 0.11 → 1.65 | 19–23 | a newcomer has almost no reviews in the first week |
| cards held three weeks | reviews passed at an interval of 21 days or more | 97.5 % in weeks 1–4 | 0 → 0.12 per answer | 24–116 | zero for a month, and the rule takes a paragraph to explain |
| answers | every answer | 0 % | | | an Again loop alone makes volume without bound |
| sum of R gained | words in memory, the app's estimate | | | 23–34 | falls in a week of decay; a model's number nobody can check |

The lie column takes the stronger of Good on every review and Easy on every new card in each of weeks 1, 4, 8, 12, 16 and
24; Easy on new cards scores like 116 minutes on the three-week count in week 8, as it brings the long intervals forward. Cards held three
weeks counts the same as `TrueRetention`, period `last7Days`, mature reviews passed; its real share is per answer, as the
dataset has no minutes per card.

## The liars in the simulation

`compete()` in `cards.py`: honest learners of 5, 10, 20, 30, 45 and 60 minutes a day and five liars of 20, 40 of each, 168
days. Each spends the day's minutes (lognormal, sigma 0.5, 15 % of days skipped) on every card due, most forgotten first,
then on new cards from a deck of 10,000; Mnemit's fuzz sets the due dates, 30 s a new card and 10 s a review for the honest.
Each card has two memories: the app's, FSRS-6 on the buttons pressed, which schedules the card; and the true one, FSRS-6 on
what the learner recalled. An honest button is the truth. The liars:

- **Easy on every new card**, reviews answered honestly.
- **Good on every review**, whatever the learner recalled; a forgotten card gets no relearning step.
- **Click for volume**: 1.5 s an answer, Good on everything. A new card is a glance (Again's stability, no steps), and a
  clicked review is no retrieval: the true memory takes the post-lapse stability, as on seeing the answer.
- **Click, Again on a tenth**: the same clicker pressing Again on a random 10 % of reviews and 22 % of new cards, the
  honest shares.
- **Skim**: 5 s a new card, a glance pressed Good; reviews at the honest 10 s, all Good.

Each cell is the liar's median count of words right in the week, given as the honest minutes a day whose median scores
the same: the honest peer is 20.

| liar, 20 min a day | wk 1 | wk 4 | wk 8 | wk 12 | wk 16 | wk 24 |
|---|---|---|---|---|---|---|
| Easy on every new card | 27 | 22 | 25 | 22 | 22 | 23 |
| Good on every review | 20 | 20 | 19 | 21 | 20 | 20 |
| click, Good | 332 | 250 | 16 | 85 | 1.5 | 0 |
| click, Again on a tenth | 266 | 227 | 102 | 82 | 59 | 26 |
| skim | 92 | 59 | 53 | 45 | 45 | 41 |

The clicker runs through the 10,000-word deck in its second week and from then on gets only the cards that come due. The
skimmer scores like 41–92 honest minutes, and nothing in the log tells it apart from a learner who knew those words: its
median answer takes 5–10 s, where a quarter of real user-weeks sit under 5 s.

Honest words right a minute rise from 1.5 in week 1 to 3.3–3.8 from week 12 on in the simulation, more than among real
users (1.7 to 2.6): the model prices every review at 10 s, the hard ones too.

## Real users

`real.py`, section 11: per week since the user's first review, weeks with a review. Words right counts the cards with a
passing answer in any state (learning steps included); words learned the first answers of new cards; words remembered
the cards passed in the review state.

| weeks since first review | user-weeks | minutes, median | right = 0 | right, median | right a minute | learned a minute | remembered a minute |
|---|---|---|---|---|---|---|---|
| all | 188,748 | 69.5 | 1.0 % | 179 | 2.54 | 0.41 | 1.61 |
| 1 | 2,000 | 29.5 | 2.6 % | 44 | 1.68 | 1.90 | 0.11 |
| 2–4 | 3,813 | 62.9 | 0.7 % | 123 | 2.01 | 0.86 | 1.05 |
| 5–8 | 4,510 | 70.9 | 1.1 % | 160 | 2.28 | 0.69 | 1.37 |
| 9–26 | 17,245 | 66.3 | 1.0 % | 166 | 2.47 | 0.51 | 1.63 |
| 27–52 | 22,200 | 66.7 | 1.1 % | 171 | 2.55 | 0.45 | 1.67 |
| over 52 | 138,980 | 71.3 | 1.0 % | 189 | 2.59 | 0.36 | 1.65 |

Section 10, the flags. A user fires persistently in half or more of their eligible weeks.

| indicator | fires when | user-weeks firing | users firing in any week | users firing persistently |
|---|---|---|---|---|
| true retention, last 4 weeks (30+ review-state answers) | ≥ 0.98 | 15.6 % | 61.6 % | 11.3 % |
| Again on first answers of new cards (20+ new cards in the week) | = 0 | 24.1 % | 72.4 % | 22.5 % |
| median seconds an answer (30+ answers in the week) | < 1.5 s | 1.6 % | 21.4 % | 0.40 % |
| | < 2 s | 2.5 % | 28.1 % | 0.65 % |
| | < 3 s | 6.9 % | 45.0 % | 3.35 % |

The median seconds an answer across real user-weeks: p1 1.0, p5 2.6, p10 3.4, p25 5.0, median 8.2.

## Why the pace line

- **Pace** catches both clickers, the only liars whose gain is large, every week, and fires persistently on 0.65 % of
  real users at 2 s. Mnemit logs it: `ReviewLogEntry.duration`, the milliseconds a card was on screen.
- **True retention near 100 %** and **no Again on new cards** read lies that buy nothing on this number, and fire
  persistently on 11.3 % and 22.5 % of real users, who were scheduled mostly by SM-2 or knew the words.

## What a server would add

- **Events stamped at review time.** Today the number comes from the deck's `reviews.jsonl`, a file the learner can
  edit: a script writes a thousand right answers in a second. The count holds only when each answer reaches a server
  within minutes of being given.
- **Plausibility across learners.** Pace, answers a day and new cards a day against the population (the first two weeks:
  p90 55 new cards a study day, `real-stats.md` section 5).

## What a server cannot add

Every answer of the app is self-graded (`ReviewMode.revealed`; `typed` is legacy and records nothing new). A skimmer who
glances at a new card for 5 s and presses Good is the same event as a learner who knew the word. Checking a grade needs an
answer the app compares with the card, typed or spoken.

## Limits

- The liars' true memory is FSRS-6 with default parameters, and the model prices answers at a flat 30 s and 10 s.
- The real logs are Anki users, mostly scheduled by SM-2; how far Mnemit learners on FSRS spread in pace is unmeasured.
- Real words right include passes on learning steps: a new card answered Again, then Good ten minutes later, counts.

## Sources

- Anki Leaderboard (Shige's fork): https://shigeyukey.github.io/shige-addons-wiki/anki-leaderboard.html. Ranks by
  cards reviewed today, time today, streak, reviews in the past 31 days and retention; XP = days studied × (6 × time +
  2 × reviews × retention), a retention of 85 % or more counted as 100 %. Its cheating FAQ permits cheats outright:
  grading is the learner's own and can't be verified.
- `ring-design.md` (the ring and its closure), `real-stats.md` (the real logs), `Tools/ring-sim/cards.py` (the model).
