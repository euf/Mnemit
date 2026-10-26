# Grades: two (Forgot / Good) or four (Forgot / Hard / Good / Easy)
Facts added to `references/fsrs-research.md` §1 (not repeated), 27.10.2026. Scripts: `Tools/grades/` (`grades.py`, `fsrs-sim/`,
`ef_grades.py`; EF's logs are read from copies of the decks' `reviews.jsonl`). Tags: [measured] by the scripts, [verified] read on the page, [secondary] snippet.

## 1. Grade use in 2000 real Anki logs [measured, `grades.py`]
Data: `anki-revlogs-10k`, first 2000 users, 74.6 M review-state rows (state 2), state 4 dropped. Users with >= 300 review rows: 1979.

| Share of review-state ratings, over users | p25 | median | p75 |
|---|---|---|---|
| Hard | 3.7 % | 12.0 % | 27.5 % |
| Easy | 0.5 % | 3.3 % | 14.9 % |
| Hard + Easy | 9.2 % | 26.4 % | 49.4 % |

- Effectively two-button (Hard + Easy < 5 %): 338 users = 17.1 % (< 1 %: 7.4 %). 5-10 %: 9.9 %. 10-25 %: 21.3 %. >= 25 %: 51.7 %.
- First rating of a new card, pooled: Again 25.4 %, Hard 7.8 %, Good 49.6 %, Easy 17.1 %. Review state: 13.8 / 21.3 / 56.0 / 9.0 %.
- Recall (rating > 1) in review state: two-button users 83.7 % pooled, user median 88.1 %; four-button users (H+E >= 10 %) 87.1 % pooled, median 87.1 %.
  By previous gap the pooled two-button recall is 3 points lower up to 60 days and equal at 181 d+ (81.5 vs 81.9 %). Pooled and median point in opposite
  directions, and each user sets their own desired retention, so the level says little about grading.
- Hard after a long gap: the Hard share of reviews is 16.1 % after a 1-day gap, 21-24 % after 2-180 days, 19.3 % after 181+ days. It does not rise with the gap.
- Next review after a grade, against Good in the same cells (previous-gap bin x next-gap bin), per-user median difference in recall:
  Hard -5.1 points (p25 -9.0, p75 -1.9), Again -14.7, Easy +3.7. After gaps >= 21 days: Hard -3.5, Again -15.2. Pooled: Hard 89.0 % vs Good 89.6 %.
  If every Hard-minus-Good gap came from forgotten cards pressed as Hard, 5.1 / 14.7 = about 35 % of Hard presses (23 % after gaps >= 21 days) would be disguised
  forgets. That is a ceiling: a genuinely weaker memory lowers the next recall as well. [inference from the measured numbers]

## 2. What Easy and Hard change in a year [measured, `Tools/grades/fsrs-sim/`]
Tool deviation: this Mac has no Rust toolchain (`which cargo` empty, no `~/.cargo`), so the crate was not run. The sim compiles the app's own
`FSRS.swift` (FSRS-6 default weights) unmodified, with Scheduler's rules (2 steps, interval = round(S / factor x (0.9^(1/decay) - 1)), target 0.9, no fuzz,
card reviewed on its due day). The first intervals match §1 (Hard 1 d, Good 2 d, Easy 8 d). A same-day Good does not raise S (increase < 1, floored at 1), so
two steps cost a second showing and no stability. Recall probability p is fixed per attempt and does not fall with the interval: the sim shows the
schedule's response to a grade, an upper bound on what Easy saves. 20 000 runs per random row. Hard keeps a learning step, so the Hard policy presses Hard in the
review phase only (Hard on every recall of a new card never leaves learning).

| Word | Grading | Showings in 365 d | Lapses | Review days |
|---|---|---|---|---|
| Familiar, p = 1 | Good always | 6.0 | 0 | 0 (x2), 2, 13, 59, 222 |
| | Easy on first showing, then Good | 4.0 | 0 | 0, 8, 47, 200 |
| | Easy always | 3.0 | 0 | 0, 8, 74 |
| Familiar, p = 0.95 | Good / Easy first / Easy always | 8.4 / 5.7 / 3.6 | 0.28 / 0.21 / 0.12 | |
| Hard word, p = 1 | Good always | 6.0 | 0 | 0 (x2), 2, 13, 59, 222 |
| | Hard on first showing, then Good | 8.0 | 0 | 0, 1, 6, 23, 74, 209 |
| | Hard on every review-phase recall | 9.0 | 0 | 0, 2, 10, 29, 65, 122, 203, 310 |
| Hard word, p = 0.85 | Good / Hard first / Hard always | 26.1 / 33.9 / 75.1 | 2.56 / 3.30 / 7.85 | |

- Cost of a wrong Easy: a word whose real stability is a Good's (2.3 d), shown after the Easy interval (8 d), is recalled with 80 % instead of 90 %.
  A wrong Hard (1 d interval) is recalled with 95 %. [measured]

## 3. EF's own grades, 21-26.10.2026 [measured, `ef_grades.py`, copies of both `reviews.jsonl`]
| | n | Forgot | Hard | Good | Easy | Hard+Easy |
|---|---|---|---|---|---|---|
| Both decks, all | 323 | 26 % | 7 % (24) | 64 % | 2 % (8) | 9.9 % |
| First showing (60 cards) | 60 | 52 % | 5 % (3) | 37 % | 7 % (4) | 11.7 % |
| Later reviews | 263 | 20 % | 8 % (21) | 71 % | 2 % (4) | 9.5 % |
| Later, gap > 1 day / within a day | 64 / 199 | 16 / 21 % | 5 / 9 % | 77 / 69 % | 3 / 1 % | 7.8 / 10.1 % |

- 18 of 24 Hard presses came within a day of the previous showing (learning steps). Median time on screen: Good 4.7 s (155), Forgot 8.3 s (45), Hard 11.3 s (17),
  Easy 10.4 s (3). 9.9 % is near Anki's p25 (9.2 %). The log does not record swipe or button, nor which app version showed the first-showing buttons. Sample is small.

## 4. Web, newer than the 21.10 sources
- srs-benchmark README (last commit 24.10.2026) has the flag `--two_buttons` "Treat Hard and Easy as Good" and no result table for it. It scores binary recall;
  the newest model is FSRS-7 (34 parameters, fractional intervals); Mnemit runs FSRS-6. [verified] https://github.com/open-spaced-repetition/srs-benchmark
- 4-button-benchmark: predicts the distribution of all four grades, with FSRS-7. Its design assumes Hard becomes likelier as R falls and Easy likelier as R rises. The
  results table is an empty template. [verified] https://github.com/open-spaced-repetition/4-button-benchmark
- Expertium's benchmark page: grades are binarised only to compute the loss; FSRS still tells Hard, Good and Easy apart. [verified] https://expertium.github.io/Benchmark.html
- Anki forum, 04.07.2026: a helper quotes the FAQ, "FSRS may even be more accurate if you only use Again and Good", and a moderator names the trade: more varied data
  against grading consistently with less effort. [verified] https://forums.ankiweb.net/t/does-using-all-4-answer-buttons-make-fsrs-more-accurate/70312
- Anki releases through 26.09.3 (23.09.2026): none of the 30 latest notes mention hiding Hard or Easy (only "easy days", 25.07); the two-button route is the add-on
  "Pass/Fail 2" [verified via GitHub API; add-on: secondary, page is JS-only] https://ankiweb.net/shared/info/876946123
- Mochi keeps binary Forgot / Remembered with FSRS; a feature request about 1 Oct 2026 asks for an optional four-button mode, one user agrees. [verified]
  https://forum.mochi.cards/posts/483/optional-four-button-grading-for-fsrs-again-hard-good-easy

## 5. Persona table (from sections 1-3 only)
| Persona | What two grades cost | What four grades cost |
|---|---|---|
| Newcomer | A familiar word cannot leave the queue early: +2 showings a year if Easy is lost after the first showing (6 vs 4), +3 without Easy at all (6 vs 3); at p = 0.95 5.7 and 3.6 vs 8.4. Anki users give Easy to 17 % of first ratings, EF to 7 %. | Hard and Easy are two more decisions: 17 % of Anki users avoid them. A wrong Easy returns the word at 80 % recall. A Hard on a forgotten card still grows the interval: at most about 35 % of Hard presses. No data on confusion. |
| Course learner, phone | Swipe set shrinks to <- and ->. EF's Hard + Easy are 9.9 % of grades, so 90 % of his gestures stay. The Easy saving above is lost. | Two more gestures. EF's Hard takes 11.3 s against 4.7 s for Good and mostly occurs in same-day repeats (18 of 24). |
| Anki veteran | Median veteran uses Hard + Easy on 26 % of reviews (Hard 12 %, Easy 3 %); 52 % of users are above 25 %. Those grades vanish for them. 17 % of Anki users already work without them, with a similar median recall (88.1 vs 87.1 %). | The Anki habit carries over unchanged. Hard keeps its signal: next recall 5 points below Good, 15 below Again. |

## 6. Options and their evidence
- **A. Four grades everywhere (today).** Keeps the Easy saving (3 vs 6 showings per familiar word per year) and shorter intervals for effortful words (8-9 vs 6
  at p = 1). srs-benchmark and Expertium feed all four to FSRS. Risks: 17 % of Anki users avoid Hard and Easy; a wrong Easy gives 80 % recall at the first
  return; up to about 35 % of Hard presses may be disguised forgets.
- **B. Two grades only (Forgot / Good).** Matches Mochi and the Anki FAQ line; 17 % of Anki users already work this way, with no clear recall difference. Costs: the
  Easy saving (+3 showings per familiar word per year at p = 1, +4.8 at p = 0.95) and the Hard signal (a third of the way to Again). `--two_buttons` exists, no result.
- **C. Two visible buttons, Hard and Easy as swipes up and down, a setting shows four.** The first-showing layout extended to all reviews. EF's Hard + Easy are 9.9 %
  of grades, Anki's p25 user 9.2 %: a quarter of users lose little; the median Anki user (26 %) needs the setting. The Easy saving stays for those who swipe; first-showing
  Easy shares (7 % EF, 17 % Anki) suggest how many would. No data on how often a hidden swipe is found.
