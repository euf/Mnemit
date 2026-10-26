# Sustained overshoot: a rule for T when the learner goes on past the ring every day

Measured 26.10.2026 with `Tools/ring-sim/overshoot.py` on the card-level model of `cards.py`. Context: `references/ring-design.md`, `references/daily-ring.md`.

The ring stays in cards: done cards over the goal, the plan's cards that fit the day's time T (minutes). A learner who goes on past the ring every
day sees laps every day, so Double and Triple ring mean nothing to them, and the staircase's T trails what they sustain. ring-design.md rejected
quantile rules (censoring: a learner who stops at the ring never grows T) and raising T to one Push On day. Can a rule read sustained overshoot,
which only a learner who goes on can show, and lift T for that learner alone?

## Method

- Model as in `cards.py`: FSRS-6 cards, 5,000 words, 30 s a new card, 10 s another card, 20 new cards a day, 120 days; the app's staircase (x1.15 after
  the second closed ring in a row that filled T, x0.775 after an open one, 2.5 min at the start, 2 to 60 min). 300 synthetic learners (the 10 non-veteran
  types of `cards.py`, 30 seeds) and 854 real Anki users (minutes of their first 120 days as willingness, `real-stats.md`).
- Four responses: S stops at the ring; E goes on every day (Catch Up, then new cards); M goes on on 30 % of days at random; R goes on in stretches (a
  two-state chain that keeps its state with probability 0.9, stretches of 10 days on average).
- The ring in cards: laps = cards done / goal cards (the plan's reviews that fit T plus its new cards); Double at 2, Triple at 3; closure = goal reached.
- The rule reads minutes (work = cards done at their prices). A day is a hit when its work >= f x that day's T. When at least m of the last n study days
  are hits, T = max(staircase T, the 25th percentile of the minutes of the hit days), at most 60 min. B takes the percentile over all n days of the
  window, C also limits the jump to x1.5 of the day's T, D also waits for the 8th study day. f in 1.3, 1.5, 2; m of n in 2 of 3, 3 of 4, 4 of 5.
  38 rules; the rows below decide; A is the literal reading of the brief.
- Reproduce: `overshoot.py --real ~/Library/Caches/anki-revlogs-10k --resp E` (S, M, R alike; `--rules 'substring;substring'`; 20 rules take 20-25 minutes);
  `--ef <folder of .mnemit decks>` replays EF's log; `--selftest`. Seeds: learners 307, cards 308.

## Results

Go-on learners (E). Their work is the same under every rule, so their words are too (1,032 synthetic, 1,883 real). First week = share of perfect first weeks.

| rule | E synthetic: closure | Double | Triple | first week | E real: closure | Double | Triple | T on day 14 (min) |
|---|---|---|---|---|---|---|---|---|
| baseline: the staircase | 0.853 | 0.257 | 0.098 | 0.870 | 0.813 | 0.497 | 0.347 | 4.8 |
| A  1.5x, 3 of 4, q25 of the hit days | 0.697 | 0.118 | 0.040 | 0.167 | 0.650 | 0.170 | 0.080 | 11.0 |
| B  1.5x, 3 of 4, q25 of all 4 days | 0.728 | 0.129 | 0.043 | 0.187 | 0.671 | 0.186 | 0.089 | 10.2 |
| B  1.3x, 2 of 3, q25 of all 3 days | 0.665 | 0.091 | 0.030 | 0.093 | 0.628 | 0.145 | 0.063 | 11.7 |
| C  B 1.5x, 3 of 4, jump <= x1.5 | 0.741 | 0.139 | 0.047 | 0.437 | 0.688 | 0.216 | 0.110 | 9.9 |
| D  1.5x, 3 of 4, jump <= x1.5, from day 8 | 0.752 | 0.162 | 0.062 | 0.870 | 0.700 | 0.249 | 0.139 | 9.4 |
| D  1.5x, 3 of 4, no jump limit, from day 8 | 0.741 | 0.155 | 0.060 | 0.870 | 0.683 | 0.219 | 0.120 | 10.3 |
| D  2x, 3 of 4, jump <= x1.5, from day 8 | 0.789 | 0.186 | 0.069 | 0.870 | 0.721 | 0.268 | 0.149 | 8.7 |

Mixed learners (M, R) carry the guard rails; words in brackets against the baseline. Learners who stop at the ring (S, run on the first 20 rules): the baseline's row under every rule
(closure 0.852 synthetic and 0.825 real, longest open run 1.98 and 3.45 days, first week 0.870 and 0.426, words 496.6 and 506.4), since a stopper's work never
exceeds the goal's cost, which never exceeds T, so no day is a hit (`--selftest` asserts it).

| rule | M synthetic: closure | longest open run | words | M real: closure | longest open run | words | R synthetic: closure | longest open run | words | R real: closure | longest open run | words |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| baseline: the staircase | 0.852 | 1.95 | 678 | 0.819 | 3.51 | 1062 | 0.853 | 1.94 | 775 | 0.817 | 3.55 | 1328 |
| A  1.5x, 3 of 4, q25 of the hit days | 0.833 | 2.14 | 690 (+1.7 %) | 0.786 | 3.84 | 1130 (+6.4 %) | 0.772 | 2.96 | 795 (+2.5 %) | 0.720 | 4.49 | 1406 (+5.9 %) |
| B  1.5x, 3 of 4, q25 of all 4 days | 0.840 | 2.02 | 686 (+1.2 %) | 0.795 | 3.71 | 1120 (+5.4 %) | 0.788 | 2.65 | 792 (+2.1 %) | 0.735 | 4.27 | 1400 (+5.4 %) |
| B  1.3x, 2 of 3, q25 of all 3 days | 0.810 | 2.37 | 703 (+3.6 %) | 0.761 | 4.03 | 1176 (+10.8 %) | 0.748 | 2.99 | 802 (+3.4 %) | 0.705 | 4.57 | 1416 (+6.6 %) |
| C  B 1.5x, 3 of 4, jump <= x1.5 | 0.843 | 2.01 | 686 (+1.1 %) | 0.804 | 3.64 | 1098 (+3.4 %) | 0.797 | 2.54 | 790 (+1.9 %) | 0.749 | 4.16 | 1392 (+4.8 %) |
| D  1.5x, 3 of 4, jump <= x1.5, from day 8 | 0.844 | 2.01 | 684 (+0.9 %) | 0.806 | 3.63 | 1096 (+3.2 %) | 0.804 | 2.47 | 788 (+1.7 %) | 0.756 | 4.12 | 1386 (+4.3 %) |
| D  1.5x, 3 of 4, no jump limit, from day 8 | 0.842 | 2.02 | 684 (+0.9 %) | 0.797 | 3.70 | 1115 (+5.0 %) | 0.796 | 2.56 | 790 (+1.9 %) | 0.742 | 4.24 | 1394 (+4.9 %) |
| D  2x, 3 of 4, jump <= x1.5, from day 8 | 0.848 | 2.00 | 681 (+0.5 %) | 0.808 | 3.60 | 1092 (+2.8 %) | 0.822 | 2.27 | 784 (+1.1 %) | 0.766 | 4.01 | 1381 (+4.0 %) |

- The baseline gives a go-on learner Double on 25.7 % (synthetic) and 49.7 % (real) of study days and Triple on 9.8 % and 34.7 %; T is 4.8 minutes on day 14
  for learners of about 10.
- D lifts T to 9.4 minutes by day 14 and cuts Double to 16.2 % and 24.9 %, Triple to 6.2 % and 13.9 %. It keeps the perfect first weeks (0.870, 0.424); A to C
  lower them (0.09 to 0.67 synthetic) because their jump falls in the first week.
- D costs: closure of go-on learners 0.853 to 0.752 (synthetic) and 0.813 to 0.700 (real), the low end of the 0.70-0.85 band. Stretch learners (R) lose 0.049 and
  0.061 and have longest open runs 0.53 and 0.57 days longer: after a stretch the ring sits at the stretch's level and x0.775 a day brings it down. Learners who
  go on on a third of days (M) lose 0.008 and 0.013 (runs +0.06 and +0.12 days). Their words rise 0.9 % and 3.2 % (R: 1.7 % and 4.3 %), as a bigger ring asks more on the
  days they stop at it.
- Closure and laps trade against each other. Synthetic go-on learners reach Double 20 % at closure 0.81 (D, 2x, 4 of 5: 0.812 and 0.202) and 16 % at 0.75; real users sit at 0.25 for
  closure 0.70 and at 0.145 for 0.628 (B 1.3x 2 of 3, first week 0.14). No row gives real users Double 10-20 % at closure 0.70 or more.
- A sets T too high: its days were picked for passing 1.5 x T, so their lower quartile sits above the learner's own. B recovers 0.03 of closure; D's jump limit adds 0.011 (synthetic) and 0.017
  (real) to closure and 0.007 and 0.030 to Double.
- EF's log: 309 answers on six days (21-26.10), minutes 4.5, 24.5, 6.0, 2.9, 3.5, 2.2. The model's staircase asks 2.5, 2.5, 2.9, 2.9, 3.3, 3.3 minutes (laps 1.8, 9.8, 1.5, 2.8,
  1.0, 0.7). D cannot act before the 8th study day; B and C lift T to 4.3-5.2 minutes on day 4 and his next two days (3.5, 2.2 minutes) fall under it. One 24.5-minute day among
  ordinary ones is no sustained overshoot, and six days settle nothing. The goals the app showed him depend on its plan, which the log does not hold.

## Verdict

Adopt D, the constants as flags: work >= 1.5 x T on 3 of the last 4 study days, from the 8th study day on, then T = max(staircase T, the 25th percentile of the minutes of those 4
days), at most x1.5 of the day's T and 60 minutes. Learners who stop at the ring are untouched (closure, open runs, first week, words identical), the first week is kept, words rise
for mixed learners, and Double and Triple for go-on learners fall by 37 % (synthetic) and 50-60 % (real).

It misses the target on real go-on users (Double 24.9 % against 10-20 %), costs stretch learners 0.05-0.06 of closure and up to 0.6 days of open run, and leaves go-on learners' closure
at the band's low edge. Rollback is the constants. 2x with 3 of 4 halves the stretch cost (closure -0.031 and -0.051, open run +0.33 and +0.46 days) for Double 18.6 % and 26.8 %.
Limits: the model's day has no memory from one day to the next; real users' minutes are what Anki's queue allowed; EF's own log is too short to test a rule. After 60 study days of a go-on
learner, check D on the app's own log (ring-design.md, "What would reopen it").
