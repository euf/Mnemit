# Desired retention at a fixed day's time

The ring fixes the minutes of a day, so the retention target (`LearningOptions.targetRecall`) decides how many new words
fit in them. Which target keeps the most words in memory? Measured on 2026-11-07 with `cards.py --retention` on the FSRS-6
default weights, which all four of EF's decks still had on that date.

## Result

At the same minutes, a lower target keeps more words in memory, for every learner tried and at both horizons. Words in
memory after 365 days, against a target of 0.90:

| Target | 5 min, stops at the ring | 5 min, goes on | 10 min, stops at the ring | 10 min, goes on | 5 min, stops, lapses cost no time |
|---|---|---|---|---|---|
| 0.70 | +28.2 % | +29.9 % | +25.6 % | +24.6 % ¹ | |
| 0.75 | +22.8 % | +24.3 % | +21.3 % | +24.6 % | |
| 0.80 | +18.5 % | +19.6 % | +18.1 % | +20.2 % | +30.8 % |
| 0.85 | +11.0 % | +11.2 % | +10.5 % | +12.6 % | +18.2 % |
| 0.95 | −23.7 % | −23.3 % | −23.6 % | −22.7 % | −27.7 % |

¹ The deck of 5,000 words runs out (4,982 introduced). After 180 days the gains are within 4 points of these.

The gain flattens below 0.80: from 0.90 to 0.80 it is 18.5 % (5 minutes, stops at the ring), from 0.80 to 0.70 another
8 %. The price shows in what the learner meets: at 0.70, 30 % of reviews fail and 80 % of the words met are in memory; at
0.80, 20 % and 89 %; at 0.90, 11 % and 95 %.

The main run, 5 minutes a day, 365 days (S: stops at the ring; E: goes on past it, catching up and then taking new cards):

| Learner | Target | Words in memory | New words | Minutes a study day | Reviews a study day | Recalled | Rings closed |
|---|---|---|---|---|---|---|---|
| S | 0.70 | 899 ± 7 | 1,119 | 3.1 | 9.0 | 0.697 | 0.78 |
| S | 0.75 | 861 ± 7 | 984 | 3.1 | 10.5 | 0.745 | 0.78 |
| S | 0.80 | 831 ± 7 | 930 | 3.1 | 11.3 | 0.795 | 0.78 |
| S | 0.85 | 778 ± 6 | 838 | 3.1 | 12.6 | 0.845 | 0.78 |
| S | 0.90 | 701 ± 6 | 736 | 3.1 | 14.4 | 0.891 | 0.78 |
| S | 0.95 | 535 ± 4 | 549 | 3.0 | 16.8 | 0.939 | 0.78 |
| E | 0.70 | 2,092 ± 15 | 2,605 | 7.0 | 20.8 | 0.698 | 0.78 |
| E | 0.75 | 2,001 ± 14 | 2,287 | 7.1 | 24.0 | 0.745 | 0.78 |
| E | 0.80 | 1,925 ± 14 | 2,154 | 6.9 | 25.9 | 0.794 | 0.78 |
| E | 0.85 | 1,791 ± 12 | 1,932 | 6.8 | 29.0 | 0.841 | 0.78 |
| E | 0.90 | 1,610 ± 12 | 1,693 | 6.7 | 32.4 | 0.889 | 0.78 |
| E | 0.95 | 1,235 ± 12 | 1,270 | 6.5 | 37.6 | 0.935 | 0.78 |

## Model

- `run()` with the rule in force (the first entry of `RULES`). A card is due when its R falls to the target (`ivl`); at
  0.90 the interval is S as before, and every other mode of `cards.py` prints the same output byte for byte as before the
  change (checked on `--rules chosen --seeds 4 --days 90`).
- The learner: willingness lognormal around 5 or 10 minutes (sigma 0.6), a day skipped with a chance of 7 %. EF's log from
  22 Oct to 4 Nov 2026 gives a median of 4.9 minutes and 13 study days of 14.
- Prices from the `ms` of EF's log: a recalled review 7.8 s (167 reviews), a forgotten one 29.0 s with its re-showings that
  day (44), a new card's first day 16.8 s (74): `--prices 17 8 --fail 21`. A forgotten review's extra time comes out of the
  new cards' share of the day. Priced at nothing (last column of the first table), lapses make the gain of 0.80 over 0.90
  30.8 % instead of 18.5 %.
- Memory: the FSRS-6 weights both schedule the cards and decide whether they are recalled, so the model is taken as exact.
  40 learners; every target runs on the same learners and draws (rng 311 and 308); ± is the standard error of the mean.
- Words in memory: the sum of R over the introduced cards on the last day, as SSP-MMC-FSRS counts "memorized cards".

## Limits

- EF's memory is weaker than the default weights: on reviews of later days he recalled 78.5 % (219 reviews to 4 Nov) at a
  target of 0.90, so his schedule already runs at about 0.80 in the model's terms. Lowering the target on default weights
  would push his real recall further down. Rerun on the fitted weights after the first automatic fit (400 usable reviews,
  about 19 Nov 2026 at his pace); one fit covers all decks of the folder, so any of them gives the weights:

  ```
  Tools/ring-sim/cards.py --retention 5 --prices 17 8 --fail 21 --params "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Mnemit/Greek B1.mnemit"
  ```

- Not modelled: leeches (8 lapses by default), how it feels to fail one review in five or in three, and whether a word at
  R 0.7 is usable in speech (it counts as 0.7 of a word here).
- A new card's first day is two Good steps, as in the rest of `cards.py`; FSRS-6 makes no same-day predictions.
- The deck holds 5,000 words with a ceiling of 20 new cards a day.

## Reading for Mnemit

Keep 0.90 while the decks run on default weights. After the first fit, rerun on the fitted weights; if the shape holds, a
target of 0.80 keeps about 18 % more words in memory after a year at the same minutes, with recall on reviews close to what
EF has now. Below 0.80 the gain is about 8 % more, with one review in three or four failing.
