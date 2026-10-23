# The ring: what a day asks, how it moves, when it closes

The decision of 23.10.2026 (Mnemit 5.5) and the measurements behind each part of it. The rules as code: `DailyGoal`
(`daily-ring.md`); the screens: `learning-flow.md`. Sources: `ring-design-research.md` (adaptive daily goals, persistence,
workload), `goal-setting-research.md`, `learning-flow-research.md`, `decisions-evidence.md`. Measurements, all in
`Tools/ring-sim/`: `real.py` (statistics of 2,000 Anki users, `real-stats.md`), `sim.py` (rules for the day's time on minutes
alone, `ring-simulation.md`), `cards.py` (FSRS-6 cards under each rule: words in memory, backlog, the first two weeks).

The aim: a newcomer is drawn in over the first two weeks, and an Anki user finds the reviews at least as well kept as in Anki,
with no settings.

## The rule

1. **What the ring asks.** The cards of the day's FSRS plan that fit the day's time T: cards due, overdue included, most
   forgotten first, then new cards in the time left. Due cards beyond T stay in the plan; Catch Up goes on with them.
2. **New cards.** As many as T leaves after the plan's other cards, within each deck's limit.
3. **How T moves**, once per study day: × 1.075 after a ring closed on a goal that filled T; unchanged after a ring closed on a
   smaller plan (a deck's limit or an empty deck set the goal) and after a day without study; × 0.775 after an open ring.
4. **Start and range.** 2.5 minutes before any study; 2 minutes to an hour.
5. **Closure.** The cards done reach the goal; each answer recalled moves the ring by its share of a card (`decisions-evidence.md`
   §1).
6. **The streak** stays apart: the first 2 minutes of cards keep it, the next closed ring repairs one missed day
   (`decisions-evidence.md` §3).

Changed from 5.4: the start (4 minutes), the ceiling (30 minutes), the hold on a smaller plan (5.4 grew T on every closed ring),
and the bound that held today's new cards to what the next week could carry (removed).

## How load is managed elsewhere, and where the ring stands

The way to keep the load of spaced repetition in hand is settled; the ring uses it. What no tool does is learn the
budget from the learner's behaviour: everyone else asks for it.

| Lever | How it works | Source | In Mnemit |
|---|---|---|---|
| A review limit with new cards under it | When the day's review limit is reached no new card is shown (Anki's default: "New cards ignore review limit" off); with a backlog, stop introducing new cards, as they "can make the backlog worse" | [Anki Manual, Deck Options](https://docs.ankiweb.net/deck-options.html) | The ring: T is the limit in seconds, due cards come first, new cards take what is left |
| The retention target | The main lever on the load: above 90 % it climbs fast, above 97 % it can overwhelm; the manual's simulator ("Help Me Decide") draws a personal retention-workload graph and asks how many minutes a day one can really spend | same | Fixed per deck (0.9); the ring does not move it |
| Spreading the load | Anki's built-in load balancer (since 24.11) picks the due day inside the fuzz range by the load of each day; Easy Days lightens chosen weekdays; FSRS Helper adds flatten, postpone and advance | `rslib/src/scheduler/states/load_balancer.rs`; [Anki Forums, 2025](https://forums.ankiweb.net/t/force-load-balancing-with-lots-of-unbalanced-reviews/54894) | Fuzz only, no balancing (measured below) |
| New cards by a leading signal | New cards are released while the pool of young cards is under a cap | the add-on Limit New by Young (`ring-design-research.md` §3) | No |
| The reason for all of it | A queueing model of the Leitner system shows a sharp phase transition: once new items arrive faster than reviews can serve, learning collapses; a Mechanical Turk experiment confirmed it | Reddy, Labutov, Banerjee, Joachims, KDD 2016, [arXiv:1602.07032](https://arxiv.org/abs/1602.07032) | New cards stay under the time, as above |

Anki's load balancer, as its source code has it: only intervals up to 90 days are balanced, within the usual fuzz range; a
day with nothing due weighs 1, any other (1 / its cards)^2.15 × (1 / the interval)^3, times a sibling factor (a day that
holds a card of the same note weighs almost nothing) and the Easy Days factor; the day is drawn at random by weight with the
card's fuzz seed; only cards of the same preset count.

The FSRS simulation behind every number here agrees with an independent one. Noos's FSRS simulator (20 new cards a day for a
year, all due cards answered, FSRS-6 defaults, grades drawn from the Anki simulator's defaults) gives 133, 161, 204 and 308
answers a day at retention 80, 85, 90 and 95 %; the same routine in `cards.py`'s model gives 134, 161, 211 and 339, and the
cards remembered match within 0.5 % ([noosflashcards.com/resources/fsrs-simulator](https://noosflashcards.com/resources/fsrs-simulator)).

## The two learners

**A newcomer.** The first day asks 2.5 minutes, about five new words at the 30 s a new card costs before the learner's own pace
is known. Each closed ring asks 7.5 % more: 3.9 minutes on day 7 and 6.4 on day 14 when every ring closes. New cards fill what
the reviews leave, so the words of the first days come back as reviews and the day stays the size the learner shows. The first
open ring comes when T passes what the learner gives on a low day; after it the ring closes on about four days in five.
Measured on synthetic newcomers who stop at the ring (10 learner types without an imported collection, 40 seeds each): a
perfect first week, seven closed rings in the first seven study days, for 0.823 of them against 0.568 under 5.4; the first 14
days close 0.960 of rings against 0.900. On the logs of 854 real users taken as willingness: a perfect first week 0.415
against 0.295, the first 14 days 0.800 against 0.749.

**An Anki user** imports a collection with its history; the replay of the history runs the same rule, so T arrives near the
learner's usual plan. The ring holds the whole queue up to an hour. On the real logs 36.7 % of study days run over 30 minutes and
18.2 % over an hour; on a median day 31.9 % of users study over 30 minutes and 7.7 % over an hour. A veteran of an hour a day
(4,000 cards, stability around 15 days, history imported) who stops at the ring leaves 282.3 cards overdue on an average
day under the 30 minutes of 5.4 and 63.9 under an hour, and keeps 4745.5 words in memory against 4561.5. FSRS keeps its
schedule: due cards come first, most forgotten first, nothing is reviewed early, and How Today Works shows the plan, the time and
the parameters.

## The evidence for each part

| Part | Measured | Source |
|---|---|---|
| The day in seconds, on screen in cards | A new card's day costs 1.9 times an other card's at the median user (18.2 s against 9.2 s; means 29.9 s and 16.8 s), so a count of cards would be a different day on a day of new words | `real-stats.md` §3 |
| Due cards first, cut at T | Uncut, real users who stop at the ring keep 1.9 cards overdue a day instead of 4.6, and for eager ones the largest ring averages 124.4 minutes and the longest open run 9.8 days (cut: 21.4 and 3.6) | Anki manual: a review limit paces a backlog (`decisions-evidence.md` §5); returns after 4-30 missed days start at 0.87 of the usual minutes (`real-stats.md` §6) |
| New cards in the time left | The bound that looked a week ahead set the allowance on no study day of the newcomers or the real users, and on 0.3-0.7 % of a veteran's days | the Anki manual sizes new cards by the review load one can sustain; 8-10 reviews a day per daily new card at steady state (`ring-design-research.md` §3) |
| The closure tracker, × 1.075 / × 0.775 | The share of closed rings settles at ln(1/0.775) / (ln 1.075 + ln(1/0.775)) = 0.779 whatever the work: 0.775 on 1,921 real users (`ring-simulation.md`), 0.815 with cards; rules that read the size of the work stall for a learner who stops at the ring | adaptive goals beat fixed ones in the trials that compared them (`ring-design-research.md` §1) |
| Hold on a smaller plan | Under a deck limit of 10 new cards a day and a 10-day break, 0.928 of rings close with the hold and 0.882 without it, longest open runs 1.4 and 2.0 days | a closed ring on a plan smaller than T says nothing of T |
| Start 2.5 minutes | 77 % of the first week's study days of real Anki newcomers reach 2.5 minutes (3 min: 74.6 %, 4 min: 70.1 %, 2 min: 80.0 %): the share the tracker settles at | `real-stats.md` §5, 7,408 study days |
| 2 minutes to an hour | The hour holds the median day of 92 % of users; the heavy veteran above | `real-stats.md` §2 |

## The alternatives

All rows change one part of the chosen rule. S: the learner stops at the ring; E: the learner goes on to Catch Up and more new
cards; skip 0.3: an open ring makes the learner skip the next day with probability 0.3. "Newcomers" are the 10 synthetic learner
types without an imported collection, "real" the 854 users of the Anki logs; words are words in memory on day 120 (the sum of
recall probabilities); open run is the longest run of open rings, in study days; peak is the largest ring of the run, in
minutes; overdue is the cards past their due date on an average study day; all are means over learners.

### How T moves

| rule | newcomers S: closure | open run | words | words, skip 0.3 | real S: closure | words | newcomers E: closure |
|---|---|---|---|---|---|---|---|
| chosen: tracker 1.075 / 0.775 | 0.835 | 2.1 | 511.7 | 481.0 | 0.815 | 531.1 | 0.837 |
| tracker at closure 0.70 | 0.776 | 2.5 | 561.2 | 516.1 | 0.778 | 611.0 | 0.774 |
| tracker at closure 0.85 | 0.890 | 1.7 | 453.0 | 434.4 | 0.850 | 426.2 | 0.893 |
| tracker at closure 0.90 | 0.929 | 1.3 | 397.8 | 388.7 | 0.873 | 322.2 | 0.932 |
| tracker at closure 0.95 | 0.967 | 1.0 | 316.2 | 313.6 | 0.892 | 194.7 | 0.968 |
| Kaplan-Meier q 0.15, 21 days | 0.891 | 2.1 | 445.7 | 428.5 | 0.854 | 391.1 | 0.838 |
| closed share of the last 7 days (EF) | 0.830 | 2.9 | 512.2 | 482.1 | 0.814 | 521.0 | 0.831 |
| median of 7 study days (5.3) | 0.992 | 0.3 | 146.6 | 146.3 | 0.904 | 109.5 | 0.603 |
| log-mean of 14 days, ring cut at it (EF) | 0.992 | 0.3 | 145.9 | 145.6 | 0.904 | 109.2 | 0.610 |
| fixed 10 minutes | 0.621 | 7.7 | 608.7 | 543.2 | 0.671 | 502.6 | 0.624 |
| Anki: every card due + 20 new | 0.387 | 17.1 | 790.3 | 645.1 | 0.497 | 894.9 | 0.325 |

- **The closure target.** A harder ring buys words from a learner who stops at it and costs closed rings; an easier one the
  reverse. No source ties the share of met goals to persistence; the trials of adaptive goals met them on 33-58 % of days and still
  beat fixed goals, and a failed assigned goal lowered later motivation in two experiments (`ring-design-research.md`,
  `goal-setting-research.md` §1). 0.78 keeps the open rings to about one day in five and their runs to two days; the streak, kept
  by two minutes, carries the habit (`decisions-evidence.md` §3). The skip after an open ring does not change the order of the
  rules.
- **Kaplan-Meier** reads the size of the work with censoring: on cards it closes more and keeps fewer words than the tracker, and on
  minutes alone it trails the tracker on real users (`ring-simulation.md`). It needs a window and a test that tells a ring-stop from a
  lap.
- **The closed share of the last seven days** reacts a week late: the same closure and words, open runs of
  2.9 days against 2.1.
- **The median of seven study days, a log-mean of the work** and every rule that sets T from the work alone stall for a learner
  who stops at the ring: the work equals the ask, so the ask never grows (censoring).
- **A fixed ring or Anki's queue** asks the same of a five-minute learner and a twenty-minute one: rings stay open on 38 % of a
  newcomer's days (10 minutes) and on 61 % (Anki's queue), in runs of a week and more.

### What the ring holds

| ring | real S: closure | words | overdue | peak (min) | real E: closure | open run | peak (min) |
|---|---|---|---|---|---|---|---|
| chosen: due cards first, cut at T | 0.815 | 531.1 | 4.6 | 15.5 | 0.802 | 3.6 | 21.4 |
| every card due, never cut | 0.806 | 534.5 | 1.9 | 26.6 | 0.620 | 9.8 | 124.4 |
| every card due + X new, X sized for 30 days ahead, X at least 1 (EF) | 0.806 | 544.0 | 1.9 | 30.8 | 0.606 | 9.8 | 125.4 |
| cut at T, new cards sized for 30 days ahead | 0.888 | 267.3 | 0.9 | 8.2 | 0.813 | 3.4 | 20.9 |
| every card due, new cards up to the log-mean (EF) | 0.901 | 112.3 | 0.2 | 5.4 | 0.534 | 10.8 | 124.5 |
| the cards that hold words in memory (EF) | 0.982 | 18.5 | 0.7 | 0.7 | 0.824 | 3.0 | 26.4 |

- **Every card due, never cut.** Fewer cards wait overdue, and the ring after a break or after a run of "+10 new" is the whole
  backlog: rings of hours that stay open for a week and more. Returning learners give 0.87 of their usual minutes on the first day
  back, and only 21 % study five of the next seven days (`real-stats.md` §6): the cut lets the first day back close.
- **New cards sized for the next 30 days** (EF's first idea, reworked: every review a new card will bring over a month, at the
  steady intake, must fit the time) closes more rings and keeps 267.3 words on the real logs against 531.1: a higher closure
  target under another name. Uncut due cards on top add the peaks of the row above it. Its one new card a day while the due
  cards fill the time goes against the Anki manual's advice under a backlog and is left out.
- **The cards that hold words in memory** (EF's fourth idea: the ring closes when tomorrow's expected recall makes up for today's
  forgetting) is a ring of about one card for a newcomer, whose forgetting is near zero, and lets a veteran's backlog grow (529
  cards overdue a day for a 25-minute veteran with history, against 7.4): the learner who stops at it keeps 18.5 words where
  the chosen ring keeps 531.1. As a floor it has a meaning FSRS gives: the cards that keep memory where it was. Kept as a
  candidate for the streak step (`decisions-evidence.md` §3), outside this decision.

### The first two weeks

| start | newcomers S: perfect first week | first 14 days | words | real S: perfect first week | first 14 days | words | newcomer of 5 min: perfect first week |
|---|---|---|---|---|---|---|---|
| chosen: 2.5 minutes | 0.823 | 0.960 | 511.7 | 0.415 | 0.800 | 531.1 | 0.225 |
| 2 minutes | 0.895 | 0.980 | 501.7 | 0.487 | 0.821 | 518.8 | 0.500 |
| 3 minutes | 0.740 | 0.941 | 516.6 | 0.372 | 0.784 | 544.2 | 0.125 |
| 4 minutes (5.4) | 0.568 | 0.900 | 524.7 | 0.295 | 0.749 | 563.8 | 0.050 |
| 8 minutes | 0.165 | 0.771 | 539.9 | 0.151 | 0.646 | 609.7 | 0.000 |
| 4 minutes held for the first week | 0.708 | 0.922 | 514.2 | 0.336 | 0.737 | 549.7 | 0.125 |
| × 1.15 until the first open ring | 0.700 | 0.912 | 528.1 | 0.368 | 0.783 | 561.7 | 0.050 |

The start trades the first week against words: each half minute lower adds 4-9 points of perfect first weeks and costs 1-2.5 %
of words for a learner who stops at the ring, and nothing for one who goes on. 2.5 minutes is the start whose first-week closure
on real newcomers, 77 %, equals the share the tracker settles at, so the first week is as easy as every later week. Neither a
faster climb (× 1.15 until the first open ring, TCP's slow start: 0.700 perfect first weeks) nor four minutes held for a week
(0.708) reaches the first week of a lower start (0.823 at 2.5 minutes).

### Range, hold and the week ahead

| variant | heavy veteran S: overdue | words | closure | deck limit 10 + break, S: closure | open run | words |
|---|---|---|---|---|---|---|
| chosen | 63.9 | 4745.5 | 0.890 | 0.928 | 1.4 | 670.6 |
| 2 to 30 minutes (5.4) | 282.3 | 4561.5 | 0.962 | 0.928 | 1.4 | 670.6 |
| no hold (5.4) | 57.9 | 4745.2 | 0.880 | 0.882 | 2.0 | 744.2 |
| the next-week bound (5.4) | 61.4 | 4745.3 | 0.891 | 0.928 | 1.4 | 670.6 |
| Mnemit 5.4 as a whole | 275.0 | 4560.1 | 0.962 | 0.875 | 1.9 | 775.9 |

- **30 minutes** cut the queue of every third Anki user; an hour holds the median day of 92 % of them.
- **Without the hold** a ring closed under a deck limit grows T though the learner gave less than T: T climbs while the limit
  holds the ring under it, and the ring after a break asks the grown time (closure 0.882 against 0.928, open runs 2.0 against
  1.4). A learner who stops at the ring keeps more words that way (744 against 671), the same trade as a lower closure target,
  which is set above.
- **The next-week bound** set the allowance on under 1 % of a veteran's days and on none of anyone else's; the time already
  holds the reviews of earlier new cards.

## How it was measured

- **Data.** `open-spaced-repetition/anki-revlogs-10k`, users 1-2,000 (`fetch.py`, gated on Hugging Face), 144 million reviews.
  Daily minutes are the sum of review durations capped at 60 s (Anki's maximum answer time). `real.py` gives the statistics
  (`real-stats.md`). The first answer of a new card is Again for 22.5 % of new cards at the median user (p25 5.7 %, p75 40.7 %).
- **Minutes alone** (`sim.py`): 706 rules over 14 synthetic scenarios and 1,921 real users, `ring-simulation.md`.
- **Cards** (`cards.py`): FSRS-6 with the default parameters at retention 0.9, a learner with a willingness in minutes a day
  (lognormal around a level, sigma 0.4-0.9, 10-30 % of days skipped), 120 days, 40 seeds per synthetic type, prices of 30 s a new
  card and 10 s an other card (`DailyGoal`'s defaults), a deck of 5,000 words, a limit of 20 new cards a day. The day's plan, the
  cut at T, new cards in the time left, Catch Up for the eager learner, done cards and recall drawn from R as in the app. Real users
  enter with the minutes of their first 120 days as willingness (854 users with 120 days of log and a third of them studied).
  Runtime: about half an hour for one response over every rule on an idle Mac.
- **Reproduce**: `Tools/ring-sim/cards.py --real ~/Library/Caches/anki-revlogs-10k --resp S` (and `--resp E`, `--skip 0.3`).

## Limits

- The willingness of a learner is given and does not answer the ring, except through the skip after an open ring. Whether a
  harder ring makes people study more (the walking trials) or quit (Duolingo's highest goal tier) is not modelled; the closure
  target rests on the sources above.
- Real users are Anki users: their minutes stop at an empty queue, so they understate what they would give a ring, and they are
  people who kept Anki long enough to share a collection.
- One set of FSRS parameters, the default ones; a deck of one kind of card at fixed prices.
- Words in memory measure retention of what was admitted; they say nothing of how the learner felt about the day.

## What would reopen it

- Mnemit's own log, 60 study days or more: a closure share outside 0.7-0.85, or open runs longer than three days.
- A study that ties the share of met daily goals to persistence: set the closure target from it (`target(c)` in `cards.py` gives
  the factors of a closure c).
- Anki users who import without history (CSV) and stop at the ring: a veteran of 25 minutes then keeps 197.3 cards overdue a
  day for the first months while T climbs from 2.5 minutes; a start from the imported cards' due load would remove it.
