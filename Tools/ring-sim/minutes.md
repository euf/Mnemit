# Ring simulation: rules for the day's time, on minutes alone

The day's time T is the minutes the ring asks. This file reports what `sim.py` measured on minutes alone in the 5.3 and 5.4
versions: families of rules for learning T from the work a learner did, no cards, no FSRS. The rule in force, which also weighs
cards, memory and the first weeks, is in `references/ring-design.md`. The tool is `Tools/ring-sim/sim.py` (`--selftest`,
`--detail`, `--real <folder>`; the grid of 706 rules takes 15 s, with 2,000 real users about a minute). Every number below comes
from it: 200 seeds per scenario, rng seed 307; a second run with seed 308 reproduces the top rules within 0.005 in closure and
capture. The simulation keeps the start and range of 5.4 (4 minutes, 2-30); `cards.py` measures the 2.5 minutes and the hour of
the rule in force.

## Result

- Feasible families by synthetic capture: Kaplan-Meier censored quantile (q 0.15, 21 study days: closure 0.805, lowest cell 0.709,
  capture 0.668, lag 15.8 days), the closure tracker (q 0.25, k 0.3, the 1.075 / 0.775 of 5.4: closure 0.801, lowest cell 0.778,
  capture 0.660, lag 8.5), the asymmetric EWMA with a probe (capture 0.642), AIMD (0.633). The median of the last 7 study days, the
  app's rule of 5.3, is infeasible: closure 0.721, lowest cell 0.452.
- Real users, 1,921 of the 2,000 Anki users with 60 study days or more (section "Real data"): the tracker closes 0.775 of days and
  takes the larger share of their minutes (capture 0.296 against 0.270 for Kaplan-Meier).
- Kaplan-Meier leads the tracker on synthetic capture by 0.008, below what the model resolves, and trails it on real users; the
  tracker reads only closed or open, needs no window and no ring-stop test. The 5.5 decision (`references/ring-design.md`, which holds the
  rule in force) took the tracker.

## Question and criterion

Question: which rule sets T from the work done, so that the ring closes on 80-90 % of study days and still asks as much as the
learner would give.

- Closure of a day: work >= T. Mean closure over the 14 scenarios must lie in 0.8-0.9 (real users would be a 15th entry).
- Every selected cell (scenario and response) must stay at 0.7 or above. This is stricter than "no scenario below 0.7" at the
  scenario level, and it decides several families.
- Among the feasible rules the highest mean capture wins.
- Lag: days after the step (day 30) until the seed-mean T is within 10 % of the same rule's end level under the eager response;
  60 if never. Flips: open/closed changes per 30 study days. At closure p, independent days flip 2p(1-p)*30 times: 9.6 at p = 0.8,
  7.9 at 0.845, 5.4 at 0.9.

## Model

Each study day the app asks T minutes: 4 on the first day, real-valued, clamped to 2-30. The learner has a willingness W_t that day.

- S, stops at the ring: works min(W, T). Closed when W >= T; the log then shows work = T.
- E, eager: works W, laps included. Closed when W >= T.
- M, mixed: eager on a random 30 % of days. Reported, kept out of the selection.

W_t = L_t * exp(sigma * z), z standard normal, independent across days and seeds, the same draws for every rule and response. A
missed day (W = 0) is dropped from the series: no rule changes T on a day without work, so nothing is lost.

Censoring. On a ring-stop day the log holds one fact, W >= T. A rule fed only with the work (median, mean, EWMA with
W' = min(work, c*T)) sees work <= T on those days and can never lift T off its start. The grid's probe u counts a ring-stop day as
T*(1+u). The tracker and AIMD read the closed/open flag; Kaplan-Meier and the Kalman filter treat a ring-stop as a censored
observation. An eager day shows W exactly, so the E response is uncensored. The S-versus-E split in every table below measures
what censoring costs a rule.

Capture. Mean over seeds of sum(min(W, T)) / sum(W): the minutes the ring asked and got, against the true willingness, which the
simulation knows, so a rule that underestimates because of censoring is charged. For S cells it equals sum(work)/sum(W); for E
cells that ratio is 1 for every rule, so the ring's own minutes are counted.

## Scenarios (90 days; 14 scenarios, 27 selected cells, each also with the M cell; the two step scenarios are added for the lag)

| scenario | median willingness L_t (min) | sigma | responses |
|---|---|---|---|
| steady 5, 10, 20; weekdays only (weekends 0) | constant 5, 10, 20; 10 | 0.25 | S, E |
| vacation; sick week | 10 with days 40-49 zero; days 40-46 at 3 | 0.25 | S, E |
| increase; decline | 5 to 15; 15 to 6, over 30 days, then flat | 0.25 | S, E |
| erratic; eager learner | 10; 12 | 0.60; 0.35 | S, E; E |
| newcomer; alternating shifts | 5 to 12 over 14 days; 20 and 5 on alternate days | 0.25 | S, E |
| step up; step down | 6 to 14; 14 to 6 at day 30 | 0.25 | S, E |

## A perfect rule as the ceiling

An oracle that knows L_t and sigma and sets T to the true q-quantile of that day's willingness (clamped 2-30):

| q | closure | lowest cell | capture |
|---|---|---|---|
| 0.10 | 0.900 | 0.897 | 0.667 |
| 0.15 | 0.850 | 0.846 | 0.707 |
| 0.20 | 0.799 | 0.795 | 0.740 |

At closure 0.8 the ceiling is 0.74 because the noise itself caps what a ring below the 20th percentile can ask. The erratic
scenarios sit near 0.46 and the alternating ones near 0.34 for Kaplan-Meier. Kaplan-Meier reaches 0.668 at closure 0.805, 90 % of
the ceiling at that closure; the tracker reaches 89 %.

## The rule families

Each section gives why the family was a candidate, the numbers, where it fails or wins, and what censoring did to it. "Lowest
cell" is the lowest closure of any selected cell, with the cell named.

### Median of the last k study days (the rule of 5.3)

Why a candidate: it was the rule in the app (5.3), with k = 7. Apple's activity goal and Garmin's Auto Goal also take past work as the
base (`references/day-model-research.md`, Part 2 §3), and a median ignores a single lap day. Grid: k 5, 7, 10, 14; shrink s 1, 0.9, 0.8, 0.7 (T = s *
median); probe u 0, 0.1, 0.2.

The rule of 5.3 (k 7, s 1, u 0): closure 0.721, lowest cell 0.452 (decline, E), capture 0.618, lag 33.0, flips 9.3. By response:

| response | closure | capture |
|---|---|---|
| S | 0.965 | 0.383 |
| E | 0.509 | 0.822 |
| M | 0.790 | 0.637 |

Where it fails. On E cells a median of one's own work is the level that half the days fall under, so the ring closes on about half
the days (0.51); the decline scenario is worst (0.41-0.45) because the window still holds the old high days. On S cells the rule
cannot leave the start: closure 0.96-1.0, capture 0.20-0.39. Shrinking and probing move these two failures in opposite
directions (k 14 shown; k 7, 10 behave alike):

| s | u | S closure | S capture | E closure | E capture | closure | capture |
|---|---|---|---|---|---|---|---|
| 1 | 0 | 0.964 | 0.387 | 0.511 | 0.832 | 0.721 | 0.625 |
| 0.9 | 0 | 0.998 | 0.221 | 0.637 | 0.781 | 0.804 | 0.521 |
| 0.8 | 0 | 0.999 | 0.203 | 0.756 | 0.717 | 0.868 | 0.478 |
| 0.7 | 0 | 0.999 | 0.201 | 0.853 | 0.642 | 0.920 | 0.437 |
| 1 | 0.2 | 0.606 | 0.754 | 0.511 | 0.832 | 0.555 | 0.796 |
| 0.9 | 0.2 | 0.831 | 0.583 | 0.637 | 0.781 | 0.726 | 0.688 |
| 0.8 | 0.2 | 0.992 | 0.283 | 0.756 | 0.717 | 0.865 | 0.515 |

Eager learners need s near 0.7 for a closure of 0.85. Ring-stoppers climb only when s(1+u) > 1, which at s 0.7 asks u > 0.43,
outside the grid. A second test with u up to 1.0 and s 0.6-0.8 (200 more rules, median and mean) found 51 in band and none
feasible: the best in-band rules reach capture 0.63-0.668 and fail on the alternating scenario (E closure 0.50). No pair (s, u) fits
both responses, and no pair fits the alternating and the steady scenarios at once, because the closure of a statistic of the
work depends on sigma and on the scenario, and the rule has no way to see the closure it produces.

Lag and flips. The lag of 35.8 days (k 14, s 0.7) averages the two ring-stopper step cells, where T never reaches the eager learner's level
(the 60-day cap), with the two eager cells at 11 and 12 days. Flips run 3.9 to 9.1: few at high closure, which is no merit.

Verdict: no feasible rule in 48. Censoring explains the S cells; the E cells fail because the median is not tied to a closure target.

### Mean of the last k study days

Why a candidate: the other obvious smoothing statistic; it uses the size of a lap day, which the median discards. Grid as for the
median.

At k 14, s 1, u 0: closure 0.700, lowest cell 0.36 (decline, E), capture 0.633, lag 36.5, flips 8.8. S: 0.972 / 0.377. E: 0.466 /
0.856. The mean of right-skewed work lies above its median, so the E closure is 0.47 where the median gives 0.51. With s 0.7 the
rule reads closure 0.907, capture 0.450, lowest cell 0.50 (alternating, E). With a probe of 0.5-0.7 and s 0.7-0.75 the mean reaches
closure 0.802 and capture 0.668 (k 14, s 0.7, u 0.7; k 10, s 0.75, u 0.5, lag 20.2), the same capture as Kaplan-Meier, and
fails the floor at 0.50 on alternating. Censoring works as for the median: S capture 0.20-0.38 unless a large probe is added.

Verdict: no feasible rule in 48. If the floor were 0.5, the mean with a large probe would tie Kaplan-Meier on capture; the floor is
the brief's.

### EWMA, symmetric

Why a candidate: one number of state, no window, cheap to compute from the previous day. The cap c limits the pull of a lap day:
W' = min(work, c*T). Grid: a 0.1-0.5, c 1.5, 2, 3, u 0, 0.1, 0.2 (45 rules).

No rule reaches the band. The highest closure is 0.776 (a 0.1, c 1.5): S 0.969 / 0.382, E 0.608 / 0.753, lowest cell 0.51 (decline,
E), lag 41.8, flips 7.6. Raising c lowers closure (c 2: 0.746), because the cap on upward moves is what pushes T below the mean.
Raising a speeds the rule (a 0.2: lag 36.2) and lowers closure (0.745). A symmetric update settles near the mean of min(work, cT),
so an eager learner's ring closes on 55-61 % of days. Censoring freezes S cells at the start, as for the median; the probe u did not
bring any symmetric rule into the band.

Verdict: loses on closure, the same failure as the mean.

### EWMA, asymmetric

Why a candidate: a larger step down than up makes T settle at a low expectile of the work instead of its mean, the direction the
closure target needs; it keeps the one-number state. The expectile weight is a_up / (a_up + a_down): 0.2 for 0.1 / 0.4. Grid: a_up
0.1-0.6, a_down 0.05-0.4, c 1.5, 2, 3, u 0, 0.1, 0.2 (432 rules).

20 rules lie in the band, 3 are feasible. The probe decides:

| u | best in-band rule | S closure | S capture | E closure | E capture | closure | capture | lowest cell |
|---|---|---|---|---|---|---|---|---|
| 0 | 0.1 / 0.3, c 3 | 0.977 | 0.371 | 0.658 | 0.756 | 0.806 | 0.577 | 0.52 alternating E |
| 0.1 | 0.1 / 0.4, c 3 | 0.932 | 0.493 | 0.691 | 0.739 | 0.803 | 0.624 | 0.53 alternating E |
| 0.2 | 0.1 / 0.4, c 1.5 | 0.854 | 0.593 | 0.758 | 0.685 | 0.803 | 0.642 | 0.70 steady 5 E |

Without a probe the in-band rules reach the band by averaging two failures: S cells at 0.98 with T stuck near the start, E cells at
0.66. The one feasible rule inside the brief's own grid (0.1 / 0.4, c 1.5, u 0) is of that kind: closure 0.861, lowest cell 0.701,
capture 0.537, lag 37.0, flips 6.4, with S 0.979 / 0.367 and E 0.758 / 0.685. The probe lets ring-stoppers climb and lifts the same
rule to capture 0.642 (lag 20.2, flips 9.1). It remains response-dependent (S 0.854 against E 0.758): the expectile of a lognormal
sits at a closure that depends on sigma, and the lowest cells are steady 5 and alternating.

Verdict: feasible and third; censoring costs it 0.10 of capture when the probe is missing.

### Closure tracker (Robbins-Monro quantile tracking)

Why a candidate: it steers the quantity the ring is judged by. Each day multiplies T up or down by a fixed factor, so the
equilibrium closure is set by q whatever the distribution of W. It reads only closed or open, and a ring-stop day is simply
closed; the censoring does no harm. The state is yesterday's T. The form in the brief (closed: T *= 1 + k(1-q), open: T *= 1 - kq)
has equilibrium closure q: it gave 0.275 for q 0.2, k 0.3. The grid uses closed: T *= 1 + kq, open: T *= 1 - k(1-q), whose
equilibrium closure is 1-q. Grid: q 0.10, 0.15, 0.20, 0.25 (0.25 added: the criterion pushes closure to 0.8, which q 0.20 does not
reach), k 0.05, 0.1, 0.2, 0.3 (16 rules).

9 rules are feasible. S and E agree to 0.003 in every rule: q 0.25, k 0.3 gives S 0.801 / 0.661 and E 0.801 / 0.660. The
response does not matter to it. Closure sits 0.03-0.05 above 1-q (k 0.3: q 0.1 gives 0.928, 0.15 gives 0.887, 0.20 gives 0.845,
0.25 gives 0.801) because the first weeks, while T climbs from 4 minutes, are all closed days. The gain k trades speed for noise:

| q | k | closure | lowest cell | capture | lag | flips/30 d |
|---|---|---|---|---|---|---|
| 0.25 | 0.05 | 0.892 | 0.76 | 0.542 | 25.5 | 5.1 |
| 0.25 | 0.10 | 0.834 | 0.76 | 0.621 | 24.0 | 7.9 |
| 0.25 | 0.20 | 0.805 | 0.77 | 0.656 | 12.5 | 9.8 |
| 0.25 | 0.30 | 0.801 | 0.78 | 0.660 | 8.5 | 10.6 |
| 0.20 | 0.30 | 0.845 | 0.82 | 0.628 | 10.0 | 8.5 |
| 0.15 | 0.30 | 0.887 | 0.87 | 0.588 | 12.5 | 6.3 |

The slow gains are still climbing at day 90, which costs capture. A check outside the grid: k 0.4 gives 0.804 / 0.653 (lag 6.5), k 0.5
gives 0.810 / 0.641 (lag 6.0), so 0.3 is the peak; q 0.26 gives closure 0.792, below the band. The lowest cell is steady 5 (0.78),
which fits: the 4-minute start already sits near the target there, so the closed-day climb adds nothing. Flips of 10.6 are one above chance.

Verdict: feasible, second by 0.008 of capture. Lag 8.5 (step up 11 days, step down 6), lowest cell 0.778. It is the family
least exposed to the model's weakest assumption, the test that tells a ring-stop from a lap.

### Kaplan-Meier censored quantile

Why a candidate: the standard estimator for right-censored data, and a ring-stop day is exactly that: the willingness is at least
T. Open days and laps are exact observations; the rule sets T at the q-quantile of the estimated distribution of W over the last
k days. When the curve never reaches q, the quantile lies above everything seen, and T = 1.1 * the largest value in the window.
Grid: q 0.10, 0.15, 0.20, 0.25 (0.25 added with the tracker), k 7, 14, 21 (12 rules).

4 rules are feasible. Without censored days the estimate is an order statistic: T is the ceil(q*k)-th lowest of the last k days,
and the next day lies above it with probability 1 - m/(k+1). For q 0.15, k 21 that is the 4th lowest of 21 (expected closure 0.82,
measured 0.805). This is why closure moves in steps of about 0.04 between neighbouring (q, k), and why q 0.20 and 0.25 are the same
rule at k 7. All 12 rules:

| q | k | S closure | S capture | E closure | E capture | closure | lowest cell | capture | lag | flips/30 d |
|---|---|---|---|---|---|---|---|---|---|---|
| 0.10 | 7 | 0.859 | 0.620 | 0.866 | 0.627 | 0.862 | 0.83 | 0.623 | 6.5 | 7.1 |
| 0.10 | 14 | 0.833 | 0.645 | 0.857 | 0.640 | 0.846 | 0.79 | 0.641 | 11.0 | 7.7 |
| 0.10 | 21 | 0.838 | 0.640 | 0.853 | 0.639 | 0.847 | 0.77 | 0.638 | 16.0 | 7.5 |
| 0.15 | 7 | 0.752 | 0.695 | 0.752 | 0.710 | 0.752 | 0.71 | 0.703 | 7.0 | 11.4 |
| 0.15 | 14 | 0.784 | 0.678 | 0.798 | 0.684 | 0.791 | 0.72 | 0.680 | 11.2 | 9.8 |
| 0.15 | 21 | 0.797 | 0.668 | 0.812 | 0.670 | 0.805 | 0.71 | 0.668 | 15.8 | 9.1 |
| 0.20 | 7 | 0.738 | 0.703 | 0.748 | 0.713 | 0.743 | 0.70 | 0.708 | 6.8 | 11.7 |
| 0.20 | 14 | 0.766 | 0.689 | 0.792 | 0.688 | 0.780 | 0.71 | 0.688 | 10.8 | 10.2 |
| 0.20 | 21 | 0.757 | 0.693 | 0.769 | 0.697 | 0.763 | 0.65 | 0.695 | 15.8 | 10.5 |
| 0.25 | 7 | 0.738 | 0.703 | 0.748 | 0.713 | 0.743 | 0.70 | 0.708 | 6.8 | 11.7 |
| 0.25 | 14 | 0.717 | 0.715 | 0.734 | 0.721 | 0.726 | 0.64 | 0.718 | 11.0 | 11.8 |
| 0.25 | 21 | 0.717 | 0.714 | 0.729 | 0.720 | 0.724 | 0.60 | 0.717 | 15.8 | 11.7 |

Censoring is handled: S and E differ by 0.015 in closure and 0.002 in capture for q 0.15, k 21. The rule is late exactly where
willingness falls: its lowest cells are the decline and step-down scenarios (E 0.709 and 0.745), because the 21-day window still
holds old high values; a shorter window lags less (11 days at k 14, 7 at k 7) and flips more. A ring-stopper's T climbs by 10 % a day
while the window shows no open day (4 to 15 minutes in 14 days); an eager learner's T jumps to the work seen on the first days.

Verdict: highest capture among the feasible rules, 0.668.

### AIMD (additive increase, multiplicative decrease)

Why a candidate: the rule behind TCP congestion control; probe up slowly on success, back off fast on failure; it reads only
closed or open, so censoring does no harm. Grid: x 0.25, 0.5, 1 minute, m 0.7, 0.8, 0.9 (9 rules).

2 rules are feasible; the best is x 0.5, m 0.7: closure 0.836, lowest cell 0.742, capture 0.633, lag 7.0, flips 9.3. S and E agree
to 0.003. It has the shortest lags of any family (4.0 for x 1, m 0.7; 7-15 days elsewhere). It fails on scale: an additive step is
a fixed share of T only at one level. The lowest cell is steady 5 in all nine rules, because 0.5 minute is 10 % of a 5-minute ring
and 2.5 % of a 20-minute one. With x 0.25, m 0.9 the closure is 0.798 and capture 0.662, but steady 5 closes on 0.66 of days. The
aggressive settings flip 14-17 times per 30 days against 9.6 by chance: the ring opens and closes more than random.

Verdict: feasible, fourth family; a proportional step is the closure tracker.

### Kalman filter on log-minutes

Why a candidate: a model-based filter weighs each day by its reliability: observation noise R against the level's drift Q, and it
reacts fast when evidence is strong. A ring-stop day enters as a censored observation (Tobit update: the observation is "at least log
T", and the level moves by the expected excess through the inverse Mills ratio). The offset d turns the level into a low quantile:
T = exp(level - d). Grid: Q 0.005-0.1, R 0.06, 0.15, 0.3, d 0.1-0.4, ring-stop as Tobit or skipped (96 rules).

32 rules lie in the band, none is feasible. The best in-band rule by capture (Tobit, Q 0.02, R 0.06, d 0.3) gives closure 0.805, capture
0.671, higher than Kaplan-Meier, lag 6.0, flips 10.5, with S 0.802 / 0.670 and E 0.811 / 0.672: the Tobit update neutralises
censoring. It fails the floor in two cells: alternating E closes on 0.51 of days, erratic E on 0.67. A fixed offset is a quantile only
for one spread of the day-to-day noise; the alternating series has a log standard deviation near 0.7 and the erratic one 0.6,
against 0.25 elsewhere. A larger d protects those cells at a cost elsewhere: the best lowest cell in the band is 0.541 (Q 0.005, R 0.3,
d 0.4: closure 0.804, capture 0.666, lag 38.5). Skipping the ring-stop days gives the median's pathology: S 0.987 / 0.348 for the best
in-band skip rule, capture 0.577 overall. An online estimate of the spread (adaptive d) would remove the failure; it was not tried.

Verdict: infeasible on the floor, with the best lag and a capture equal to Kaplan-Meier's. With the floor at 0.5 it would rank first.

## Best of each family

| family | rules | in band | feasible | best rule | closure | lowest cell | capture | lag | flips/30 d |
|---|---|---|---|---|---|---|---|---|---|
| Kaplan-Meier | 12 | 4 | 4 | q 0.15, k 21 | 0.805 | 0.709 | 0.668 | 15.8 | 9.1 |
| closure tracker | 16 | 9 | 9 | q 0.25, k 0.3 | 0.801 | 0.778 | 0.660 | 8.5 | 10.6 |
| EWMA asymmetric | 432 | 20 | 3 | 0.1 / 0.4, c 1.5, u 0.2 | 0.803 | 0.701 | 0.642 | 20.2 | 9.1 |
| AIMD | 9 | 2 | 2 | x 0.5, m 0.7 | 0.836 | 0.742 | 0.633 | 7.0 | 9.3 |
| Kalman (infeasible) | 96 | 32 | 0 | Tobit, Q 0.02, R 0.06, d 0.3 | 0.805 | 0.508 | 0.671 | 6.0 | 10.5 |
| mean (infeasible) | 48 | 12 | 0 | k 14, s 0.8, u 0.2 | 0.847 | 0.498 | 0.530 | 36.5 | 6.6 |
| median (infeasible) | 48 | 15 | 0 | k 14, s 0.9, u 0 | 0.804 | 0.501 | 0.521 | 35.8 | 7.6 |
| EWMA symmetric (infeasible) | 45 | 0 | 0 | a 0.1, c 1.5, u 0 | 0.776 | 0.509 | 0.581 | 41.8 | 7.6 |

For an infeasible family the row is its best in-band rule by capture, or the closest to the band when none is in band.

## The two top rules

### Kaplan-Meier, the best synthetic capture

Kaplan-Meier censored quantile, q = 0.15, last 21 study days, T clamped 2-30 minutes, start 4 minutes. It has the highest capture of
the 18 feasible rules (0.668) and the closure of a closure-driven rule in every cell: S 0.797 and E 0.812 overall, 0.709-0.882 across
cells. By scenario:

| scenario | closure S | closure E | capture S | capture E |
|---|---|---|---|---|
| steady 5 | 0.787 | 0.813 | 0.752 | 0.741 |
| steady 10 | 0.801 | 0.815 | 0.739 | 0.744 |
| steady 20 | 0.818 | 0.815 | 0.700 | 0.743 |
| weekdays only | 0.808 | 0.817 | 0.733 | 0.743 |
| vacation 10 d | 0.803 | 0.819 | 0.735 | 0.738 |
| sick week 3 min | 0.807 | 0.801 | 0.623 | 0.651 |
| increase 5-15 | 0.827 | 0.882 | 0.724 | 0.674 |
| decline 15-6 | 0.733 | 0.709 | 0.729 | 0.787 |
| erratic | 0.806 | 0.811 | 0.458 | 0.456 |
| eager learner | - | 0.812 | - | 0.655 |
| newcomer 5-12 | 0.812 | 0.863 | 0.737 | 0.690 |
| alternating 20/5 | 0.798 | 0.810 | 0.345 | 0.340 |
| step up 6-14 | 0.820 | 0.857 | 0.692 | 0.655 |
| step down 14-6 | 0.746 | 0.745 | 0.719 | 0.757 |

Lag after the step at day 30: step up 16 days (S) and 19 (E), step down 14 and 14. Flips run 5.9-12.1 per 30 days (chance at closure
0.8: 9.6). The M cells (eager on 30 % of days) give closure 0.804 and capture 0.671 overall, the same as S and E.

### The closure tracker, the rule of 5.4

The closure tracker, q 0.25, k 0.3 (capture 0.660), trails Kaplan-Meier by 0.008 of synthetic capture, 1.2 %, below what the model
resolves. In its favour: lag 8.5 against 15.8, lowest cell 0.778 against 0.709, a higher capture on real users (0.296 against 0.270),
one multiplication per day, no window, no ring-stop test. Both recover 89-90 % of the oracle's capture at their own closure. The third rule, the asymmetric EWMA with probe (capture 0.642), has a lag of 20.2 and a lowest cell of
0.701, on the floor. AIMD (0.633) fails on scale, and the Kalman filter (0.671) on the floor.

### Sensitivity around the optimum

| rule | closure | lowest cell | capture | lag | flips/30 d | feasible |
|---|---|---|---|---|---|---|
| q 0.15, k 21 | 0.805 | 0.709 | 0.668 | 15.8 | 9.1 | yes |
| q 0.10, k 21 | 0.847 | 0.767 | 0.638 | 16.0 | 7.5 | yes |
| q 0.15, k 14 | 0.791 | 0.718 | 0.680 | 11.2 | 9.8 | no |
| q 0.15, k 7 | 0.752 | 0.705 | 0.703 | 7.0 | 11.4 | no |
| q 0.20, k 21 | 0.763 | 0.652 | 0.695 | 15.8 | 10.5 | no |
| q 0.10, k 14 | 0.846 | 0.793 | 0.641 | 11.0 | 7.7 | yes |

The optimum sits on the lower edge of the band: capture rises as closure falls, and every neighbour that gains capture leaves the
band. Closure moves by about 0.04 and capture by about 0.03 per step of q. The shorter window k 14 at q 0.15 misses the band by
0.009. If a real log shows closure under 0.8, q 0.10 gives 0.847 and 0.638 and keeps every cell at 0.767 or above.

Start value of T, Kaplan-Meier: T0 of 2, 4, 8, 12 minutes gives closure 0.814, 0.805, 0.797, 0.793 and capture 0.651, 0.668, 0.679,
0.682. Minutes alone cannot see what the start does to a newcomer's first week; `references/ring-design.md` measures it with cards.

## Real data

`open-spaced-repetition/anki-revlogs-10k` (Hugging Face, gated: an account accepts the conditions and its read token sits in
`~/.cache/huggingface/token`). `Tools/ring-sim/fetch.py N` downloads users 1..N into `~/Library/Caches/anki-revlogs-10k`, eight at
a time, resuming a cut run; 2,000 users take 2.4 GB. `--real` takes each user with 60 or more study days, daily minutes = the sum of
review durations capped at 60 s, the first 90 study days, S response. 1,921 users qualify; the median of their first-week minutes is
10.4. Statistics of the same users: `Tools/ring-sim/real.py`, output in `Tools/ring-sim/real-stats.md`.

| rule | closure, mean over users | user at p10 | capture |
|---|---|---|---|
| tracker q 0.25, k 0.3 (1.075 / 0.775) | 0.775 | 0.678 | 0.296 |
| tracker q 0.25, k 0.2 | 0.781 | 0.678 | 0.276 |
| Kaplan-Meier q 0.15, 21 days | 0.791 | 0.700 | 0.270 |
| AIMD x 0.5, m 0.7 | 0.784 | 0.644 | 0.281 |
| Kalman, Tobit, Q 0.005, R 0.3, d 0.4 | 0.810 | 0.700 | 0.232 |
| asymmetric EWMA 0.1 / 0.4, c 1.5, u 0.2 | 0.847 | 0.711 | 0.166 |
| median of 14 days × 0.7 | 0.876 | 0.744 | 0.106 |

The tracker's closure on real users, 0.775, is its equilibrium: closed days move log T up by ln 1.075 and open days down by
ln(1/0.775), so the share of closed days settles at ln(1/0.775) / (ln 1.075 + ln(1/0.775)) = 0.779 whatever the work. Its synthetic
0.801 is that plus the climb of the first weeks, when every ring closes. Real days vary far more than the synthetic ones (log
standard deviation of a user's daily minutes: median 1.34, against 0.25 in most scenarios) and come in runs (lag-1 autocorrelation
0.37); the rules that read the size of the work lose most there. Capture is low for every rule because a third of these users
work over 30 minutes a day, above the clamp of this simulation.

What the real series cannot say: Anki users stop when their queue is empty, so their minutes are bounded by the queue and
understate what they would give a ring.

## Limits of the model

- Willingness is a given. W does not react to T: no discouragement after an open ring, no boredom from a ring that always closes at the
  minimum. The band 0.8-0.9 is the brief's target; the simulation does not show that it is the right closure for retention.
- Days are independent. Real days come in runs, which favours the faster rules and shortens the best window.
- Noise is lognormal with one sigma per scenario. Real daily time has heavier tails and more zeros than 14 scenarios show.
- The ring in the app is cards at the day's prices. A ring-stopper's work lands within one card of T, below it when the goal rounds
  down. The simulation takes exactly T; a rule that tells a ring-stop from a lap (Kaplan-Meier) needs a tolerance for it.
- T and the new-card allowance are coupled in the app (the day's time bounds new cards); a change of T moves the load. Not modeled
  here; `Tools/ring-sim/cards.py` models it (`references/ring-design.md`).
- Capture counts minutes asked of a willing learner. It is no learning outcome, and more minutes are not better by themselves.
- The hold-out reruns the same 14 scenarios on fresh seeds; it tests noise, not the choice of scenarios. The optimum lies on the band
  edge, so a different mix of scenarios can move it by one grid step.

## What this model leaves open

- A closure measured on a real log over 60 study days outside 0.7-0.85 would move the closure target (`target(c)` in `cards.py` gives the
  two factors of a closure c); the condition for the rule in force is in `references/ring-design.md`, "What would reopen it".
- Evidence that willingness reacts to T (missed days after open rings) would call for a higher closure target.
- If lag mattered more, a variance-adaptive Kalman filter (lag 6.0, tied on capture, untested beyond the grid) is the candidate.
- A scenario that the 14 miss, such as a learner who works in bursts every few days, if a real log shows one.

## The rule in force

`references/ring-design.md` holds it (`DailyGoal.nextTime(after:)`), with the alternatives measured on cards, in the first two weeks and on
real users. As the tracker measured here does, the staircase reads the ring's closed or open, with whether the goal filled T.
