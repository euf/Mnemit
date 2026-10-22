# FSRS vs SM-17/18, and what the newer FSRS benchmark adds

Research for Mnemit, 22.10.2026. **[S]** from the cited source as read, **[I]** our inference,
**[U]** not confirmed. Repo: <https://github.com/open-spaced-repetition/fsrs-vs-sm17>
(README read from `main` on 22.10.2026; "README Ln" = line number in that file).

## 1. What the repo is, and when it was last touched

- A comparison of FSRS versions against SuperMemo's SM-16 and SM-17 predictions, by
  L-M-Sherlock (FSRS author; he is the assignee of the data-sharing issue template). **[S]**
- Last commit to `main`: 2026-04-17 (`bf05a10`, README table-header fix). Last content change:
  2026-04-15 (`4273628`, revised MOVING-AVG report). Last data added: 2026-01-04 (Kubo2, #91,
  makes 19 collections). Last metric added: UM+ on 2025-11-27 (#89). **[S]** `git log` via the GitHub API.
  The repo's `updated_at` of 2026-09-28 is metadata, not a content change.
- The README links only SuperMemo pages (the Universal Metric article on supermemo.guru, a
  supermemopedia page on R(SM17) naming; the latter returned 403 and was not read). It links no
  Expertium article and no forum post. **[S]** README Ln 25, 9.
- No FSRS-7 row, no SM-18 row. FSRS-7 appears nowhere in the repo (grep over README, research/,
  *.py). **[S]**

## 2. Method

- Data: each contributor exports `SM16-v-SM17.csv` from SuperMemo 18
  (`sm18/systems/{collection}/stats/`) and posts it by GitHub issue; the private `Title` column is
  removed. **[S]** README Ln 9, `.github/ISSUE_TEMPLATE/data_share.md`.
- Prediction of SM-17 = the `R (SM17)` value SuperMemo logged at each repetition. **[S]** README Ln 9.
  SM-18 is not scored separately: the file holds R(SM16) and R(SM17) only, and SuperMemo's own
  description says SM-18 differs from SM-17 mainly in the way difficulty is computed.
  **[S]** <https://supermemo.guru/wiki/Algorithm_SM-18>.
- Size: 19 collections, 687,662 repetitions (evaluated rows). **[S]** README Ln 50-52.
  Per-collection size, reconstructed from the Git LFS pointer sizes of `raw/*.csv` (one row is
  about 171 bytes; the weighted means below reproduce the README's 0.367/0.411/0.432): from about
  150 rows to about 206,000, median about 8,900. **[I]**
- Alignment with SuperMemo's workflow: the first record of every card is dropped (SuperMemo's
  first interval runs from card creation, Anki's from the first review); SuperMemo grades 0, 1, 2
  map to Again, and 3, 4, 5 to Hard, Good, Easy. **[S]** README Ln 7-8. Rows with interval <= 0 are
  dropped (`script.py` L309) and `Used interval` is whole days (checked on the smallest
  collection), so same-day repetitions are neither input nor target. **[S]**/**[I]**
- FSRS side: an online-learning FSRS, so it has no knowledge of future reviews "as SM-17 does".
  Every 64 reviews it trains on the most recent up to 8,192 reviews, weights `0.25 + 0.75 * x^3`
  (older to newer), Adam lr 8e-3, batch 512. A card's next-review probability is computed right
  after its previous review is processed. **[S]** README Ln 10, `script.py` L367-371, L387-421.
- Metrics: Log Loss, RMSE (bins), AUC, SuperMemo's Universal Metric (UM), and UM+ (binning by
  disagreement between two algorithms, added by the repo). **[S]** README Ln 15-46, 89-111.

## 3. Results (19 collections, 687,662 repetitions)

All numbers **[S]** from the README unless marked.

1. Log loss, weighted by repetitions (Ln 119-131): FSRS-6 **0.367±0.040**, MOVING-AVG 0.378,
   FSRS-4.5 0.385, FSRS-6 default parameters 0.411, SM-16 0.417, **SM-17 0.432±0.084**, FSRS v3 0.458.
2. Log loss, per user (Ln 135-147): MOVING-AVG 0.401 and FSRS-6 **0.401±0.058** (tie), FSRS-6
   default 0.429, FSRS-4.5 0.430, SM-16 0.460, **SM-17 0.480±0.087**.
3. RMSE (bins), weighted / per user: FSRS-6 0.048 / 0.081; SM-17 0.066 / 0.089.
   AUC, weighted / per user: FSRS-6 0.662 / 0.635; SM-17 0.606 / 0.607.
4. Universal Metric, average over referees, lower is better (Ln 56-68): FSRS-6 **0.0287**,
   MOVING-AVG 0.0426, **SM-17 0.0435**, FSRS-4.5 0.0496, FSRS-5 0.0508, SM-16 0.0547, AVG 0.0598,
   FSRS v4 0.0617, FSRS v3 0.0681, FSRS-6 default 0.0820 (ADVERSARIAL 0.0011 is the gaming demo).
5. UM+ (Ln 91-103): FSRS-6 0.0399 (max) / 0.0331 (avg); SM-17 0.1113 / 0.1018, eighth of eleven.
6. Superiority on log loss (Ln 155, `plots/Superiority-19-collections.png`): FSRS-6 beats SM-17 in
   **84.2 %** of collections (16 of 19; the README text says 83.3 %, which is stale against the
   figure and against the per-user JSON in `result/`). FSRS-6 with default parameters beats
   SM-17 in 78.9 % (15 of 19). Wilcoxon r = 0.78 for FSRS-6 vs SM-17 (large), 0.53 for FSRS-6
   default vs SM-17 (large). **[S]** `plots/Wilcoxon-19-collections.png`.

## 4. Caveats, as the authors state them

- "The results are based on the data from a small group of people. It may be different from the
  result of other SuperMemo users." README Ln 11.
- The Universal Metric is reimplemented from SuperMemo's documentation; SuperMemo has not
  released its evaluation code, so 100 % fidelity is not guaranteed (Ln 27). In cross-comparison
  it can be gamed by a model that sees the others' predictions (Ln 29-36).
- Weighted averages show the "best case" with plenty of data; unweighted ones the "average case"
  (Ln 149-151). The Wilcoxon test ignores how many reviews each collection has (Ln 179).
- `research/moving_avg_investigation.md` (2026-04-15): a one-parameter online calibrator
  (MOVING-AVG) ties FSRS-6 on per-user log loss because the stream is high-prior (overall success
  0.8698) and an oracle per-user constant already scores 0.4027, only 0.001-0.002 behind. The
  bootstrap CI of FSRS-6 minus MOVING-AVG (weighted log loss) is [-0.0255, +0.0170], so rankings
  between close neighbours on 19 users are "descriptive, not settled". A constant 0.87 predictor
  gets UM 0.0609, better than FSRS v4, v3 and FSRS-6 default: a metric-design warning.
  MOVING-AVG wins early (first 200 reviews: 0.3834 vs FSRS-6 0.4045) and loses late (last half of
  each stream: 0.4011 vs 0.3901). A logit mix `0.65*FSRS-6 + 0.35*MOVING-AVG`, tuned on the first
  half, scores 0.3817 on the second half against 0.3897 for FSRS-6 alone. The note says this
  does not prove MOVING-AVG is a better scheduler, and the benchmark measures prediction, not
  the quality of the intervals an algorithm would choose.
- `research/sm17_serial_dependence_averaging_levels.md`: some collections have weak within-day
  time resolution, so "previous review" order inside a day is partly arbitrary.
- Not stated by the authors, **[I]**: the SuperMemo reviews were scheduled by SM-17, so FSRS is
  scored on intervals chosen by its competitor; FSRS gets online replay training on every 64
  reviews while SM-17 is a closed implementation read from a log; the maintainer is the FSRS author.

## 5. Per-collection pattern (computed from `result/*.json` and LFS sizes) **[I]**

| Evaluated rows | Collections | FSRS-6 < SM-17 (log loss) | Default FSRS-6 < SM-17 | Median gain, fitted over default |
|---|---|---|---|---|
| up to 1.5k | 4 | 2 of 4 | 2 of 4 | 0.004 (mixed sign) |
| 1.5k to 10.5k | 8 | 8 of 8 | 7 of 8 | 0.014 |
| 30k and above | 7 | 6 of 7 | 6 of 7 | 0.026 |

SM-17 wins in three collections: about 370 rows, about 1,070 rows, and one of about 78,000 rows
(where default FSRS-6 is also far worse than fitted, 0.467 vs 0.281, so that user's data differs
from the default prior). Four users is a thin base; the table is a hint, not a result.

## 6. What the newer benchmark adds (srs-benchmark, README read 22.10.2026)

Source: <https://github.com/open-spaced-repetition/srs-benchmark> (10,000 Anki users, ~727 M
reviews; README last changed 2026-09-18; FSRS-7 added 2026-03-11, re-benchmarked 2026-08-29).
It does not contain SM-17 (it points to fsrs-vs-sm15 and fsrs-vs-sm17). **[S]**

| Model, no same-day reviews scored | Params | Log loss | RMSE (bins) | AUC |
|---|---|---|---|---|
| FSRS-7 recency | 34 | 0.3370 | 0.0593 | 0.7220 |
| FSRS-7 | 34 | 0.3401 | 0.0634 | 0.7167 |
| FSRS-rs (FSRS-6 + recency, what Mnemit ports) | 21 | 0.3443 | 0.0635 | 0.7074 |
| FSRS-6 | 21 | 0.3460 | 0.0653 | 0.7034 |
| FSRS-7 deck (parameters per deck) | 34 | 0.3489 | 0.0719 | 0.7104 |
| FSRS-7 default parameters | 0 | 0.3620 | 0.0910 | 0.7029 |
| MOVING-AVG | 0 | 0.3369 | 0.0592 | 0.7001 |

- FSRS-7 recency beats FSRS-6 recency on log loss for 82.7 % of the 9,999 collections
  (`plots/Superiority-small-9999-collections.png`). **[S]**
- Scoring same-day reviews too: FSRS-6 0.3842, FSRS-7 0.3206, FSRS-7 recency 0.3177. **[S]**
  FSRS-7 is the only version meant for fractional intervals and realistic same-day recall.
- "FSRS-7 preset" equals user-level (0.3401); "deck" is worse by 0.0088. **[S]** The Anki manual
  advises separate presets only for decks that "vary wildly in subjective difficulty", and
  re-optimizing "once every month". **[S]** <https://docs.ankiweb.net/deck-options.html>.
- Mnemit already has the recency weights (`0.25 + 0.75 * x^3`, `FSRSOptimizer.recencyWeighted`)
  and trains on reviews of later study days only. **[S]** code read.

## 7. FSRS-7 availability and size of the change **[S]** unless marked

- `fsrs-rs`: latest release v6.6.2 (crates.io 2026-08-29) has no FSRS-7 files. FSRS-7 is on `main`
  only (`model_v7.rs`, `training_v7.rs`, `analytic_v7.rs`; `Cargo.toml` still says 6.6.2); on
  2026-09-18 `main` made FSRS-7 the default for empty parameters, and on 2026-09-28/30 training was
  re-aligned with srs-benchmark and parameter pre-training removed. The target is still moving.
- `py-fsrs` v6.3.2 (2026-08-09): no FSRS-7. `ts-fsrs` stable 5.4.2 is FSRS-6; 6.0.0-beta.15
  (npm `beta`) and `@open-spaced-repetition/binding` 0.5.0 carry FSRS-7 and its optimizer.
- Anki: on 2026-06-05 a forum moderator wrote that FSRS-7 was not released and had no PR in the
  Anki repo. State after that date not checked. **[U]**
- Model: 34 weights instead of 21; three-part state (slow stability, fast stability, difficulty);
  recall is a state-weighted mixture of two power curves; the next interval has no closed form
  (Newton in log time with a bisection fallback); elapsed time is fractional days; no separate
  same-day formula; FSRS-3 to 6 weights and states cannot be converted, so states are rebuilt by
  replaying each card's log. Training starts from default weights (no S0 pre-training), 9 epochs,
  lr 0.0118, Adam betas (0.70, 0.98), an L2 pull toward the defaults. Learning steps stay a
  scheduling policy outside the model. ts-fsrs docs `guide/model/fsrs-7.mdx`; `srs-benchmark/models/fsrs_v7.py`.
- Size of the Rust reference: FSRS-7 core is about 105 KB (`model_v7` 12.7, `analytic_v7` 55.7,
  `training_v7` 28.0, clipper/init/inference about 9) plus about 160 KB of SIMD kernels; the FSRS-6
  `analytic.rs` at v6.6.2 is 31 KB. Gradients go through a 35-parameter dual-number engine.
- Mnemit side **[I]**: `ReviewLogEntry.date` is a full `Date`, so fractional elapsed days and
  same-day reviews can be rebuilt from existing logs without a log migration. Parameters
  (`FSRSParameters.count == 21`), `FSRS.swift` (169 lines), `FSRSGradient.swift` (351),
  `TrainingItem` (whole study days, same-day reviews excluded) and the interval solver all change.
  Rough cost: 1,500-2,500 new Swift lines plus reference vectors from an unreleased `main`;
  one to two weeks of focused work, with the golden-vector tests as the long pole.

## 8. What it means for Mnemit **[I]**

**SM-17/18-like algorithm.** No. SuperMemo's algorithm is closed and described only in prose and
matrices; fitted FSRS-6 beats it in 16 of 19 collections and default FSRS-6 in 15 of 19, on
data scheduled by SM-17 itself. The only transferable idea is MOVING-AVG: a one-parameter
recent-retention calibrator helps in the first few hundred reviews and as a mix with FSRS later.
Evidence is one in-sample mix on 19 users with an unidentified mechanism; Mnemit gains nothing
measurable from it before it has a held-out check on the learner's own log.

**Newer FSRS.** FSRS-7 with recency is the only FSRS variant that is ahead of FSRS-6 with
recency by a clear margin (0.0073 log loss against FSRS-rs, 2.1 %, better for 82.7 % of users),
and the only version that models same-day reviews, which Mnemit's learning steps produce. It is
not yet a stable port target (section 7).

**When FSRS is worse or better than SM-17.** Better with 1.5k or more reviews and when fitted;
roughly even with default parameters below about 1.5k reviews; SM-17's RMSE (bins) stays close
(0.089 vs 0.081 per user) while its AUC is lower (0.607 vs 0.635). Nothing in the repo tests
same-day reviews, desired retention other than SuperMemo's own, or vocabulary-only collections.

**Settings.**
- Few reviews: default FSRS-6 parameters already beat SM-17 in 15 of 19; fitting below about 1.5k
  reviews gains a median 0.004 log loss. Mnemit's 400-review minimum for offering the optimizer
  starts fitting where the gain is still within noise, so keep the new parameters only when they
  score better on a time-split holdout (`FSRSOptimizer.Evaluation` already gives log loss and RMSE).
- Per deck or pooled: srs-benchmark shows per-deck parameters losing 0.0088 log loss to one
  parameter set per user (FSRS-7; no FSRS-6 deck row). For two Greek decks of the same learner,
  about 2,750 cards each, a pooled fit is the default to test first; per-deck only if the holdout
  says so. Recognition and production behave differently, but that is a per-card-kind question the
  benchmark does not answer.
- Refit cadence: no ablation in either repo. The SM-17 comparison refits online every 64 reviews;
  the Anki manual says once a month is enough. A refit after the first 400 and 1,500 reviews, then
  monthly or every few thousand reviews, fits both.
- Desired retention 90 % sits near the benchmark's own mean success rate (0.87); the repo says
  nothing about 70-97 %.

## 9. Verdict

1. Keep FSRS-6; drop SM-17/18 as a candidate (16 of 19 and 15 of 19 collections against it).
2. Do not port FSRS-7 yet: unreleased in fsrs-rs, beta in ts-fsrs, about one to two weeks of work;
   recheck when `fsrs` on crates.io ships `model_v7` (the gain to expect is about 0.007 log loss).
3. One cheap change now: score per-deck against pooled parameters on the learner's holdout and
   keep the better; refit by the cadence above.
