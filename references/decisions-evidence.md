# Decisions of the day's model against the evidence

Ten choices of `learning-flow.md`, `daily-ring.md` and the README ("Design choices") checked against the
literature, FSRS and Anki community practice, and product reports (23.10.2026). Read first, not repeated:
`goal-setting-research.md`, `learning-flow-research.md`, `fsrs-research.md`, `production-cards-research.md`.

Confidence: measured (experiment, simulation, logged data), reported by several, single report, opinion.
"Snippet" is a source seen only as a search result; "not read" returned no text.

## 1. Partial credit on the ring

Decision: a card on its way counts recalled answers today / (those + steps still needed), never taken
back; done = FSRS sent the card to another day.

- Customers of a real coffee-card programme buy faster the nearer they are to the free coffee, and a
  12-stamp card handed out with two stamps already on it is finished faster than a plain 10-stamp card.
  Kivetz, Urminsky & Zheng, J. Marketing Research 2006,
  https://home.uchicago.edu/ourminsky/Goal-Gradient_Illusionary_Goal_Progress.pdf. Measured.
- Anki manual on FSRS: repeating a card several times in one day adds little to long-term memory, so keep
  few steps, all under a day. https://docs.ankiweb.net/deck-options.html. Opinion of the maintainers.
- No product read credits unfinished cards (`learning-flow-research.md`); the formula is Mnemit's own.
  No source found for "never taken back".

**Keep.** Progress toward a goal moves effort in the measured studies, and the credit is capped at one
card per card, so the ring cannot outgrow the work. The manual's point about same-day repeats concerns
memory; the ring shows effort and counts as done only what FSRS sent away.

## 2. The day's time

Decision: an exponentially weighted average of the seconds worked, 0.3 of the way up and 0.2 down, a day
counting for at most twice what it asked, clamped to 2-30 minutes, 4 minutes before any work; nothing else
changes it.

- `goal-setting-research.md` ("Implications for the ring rule") finds the learned base sound, the probe
  size, the 14 days and the 70 % unsourced. Opinion.
- The +10 % step is the running "10 % rule". Its one randomised trial (GRONORUN, 532 novice runners): a
  13-week programme raising volume by 10 % a week against a standard 8-week one gave the same injury rate,
  20.8 % against 20.3 % (P = .90), and the same compliance, 66.4 % against 64.5 % of the sessions done.
  Buist et al., Am J Sports Med 2008;36(1):33–39, doi 10.1177/0363546507307505, read from the PDF. Measured,
  other domain: a slower climb neither protected nor kept people at it, so the 10 % carries no evidence of
  its own.
- Duolingo: the highest daily-goal tier produced the fewest streaks
  (https://blog.duolingo.com/improving-the-streak/, via `learning-flow-research.md`). Measured (company).
- Lally 2010: one missed day moved automaticity by under half a point, repeated misses untested
  (`goal-setting-research.md` §2). Single study.
- No source found for the two weights, the cap of twice, the 2-30 minute clamp or the 4 minutes.

**Removed.** The probe (+10 % after three closed rings, with its 14-day rest) and the 70 % after a miss
went for lack of evidence: the one trial of a 10 % climb (Buist 2008) found no gain in injuries or
compliance, and one missed day is harmless (Lally 2010). A missed day stays out of the average, as it
has no work. The numbers that remain, 0.3 and 0.2, the cap of twice, 2-30 minutes and 4 minutes, are choices, not findings:
check them on EF's log by replaying `DailyGoal.nextTime` over `reviews.jsonl` with other weights, caps and
clamps, and look at the share of study days with a closed ring (target 80-90 %). Change a number only when another
variant beats it by 5 points of closure rate on at least 60 study days (our threshold).

The average is the one of training-load monitoring (Williams et al., Br J Sports Med 2017, "Better way to determine the acute:chronic workload ratio?") and of the Banister impulse-response model; measured in other domains. The asymmetry and the cap are ours: growth comes from the learner, one short day shouldn't shrink the ring, one marathon day shouldn't triple it.

## 3. The streak step

Decision: the first 120 s of the day's cards keep the streak; one missed day is repaired by closing the
next day's ring; two missed days end it.

- Separating the streak (one lesson) from the daily goal: day-14 retention +3.3 %, daily actives +1 %,
  learners on a streak +10.5 % in 20 days (+19 % new learners), fewer learners reached the goal.
  https://blog.duolingo.com/improving-the-streak/ (via `learning-flow-research.md`, Duolingo item 7).
  Measured (company A/B).
- A screen after the streak extends, bigger on milestone days: day-7 retention +1.7 % for new learners.
  https://blog.duolingo.com/how-duolingo-streak-builds-habit/. Measured (company A/B).
- Up to two equipped Streak Freezes: daily actives +0.38 %; the slack study behind them
  (https://www.sciencedirect.com/science/article/abs/pii/S0749597818304187) is a single report. Lally
  2010 (section 2): one miss is harmless.
- No source found for 120 s, for repair by a closed ring (a Freeze is bought beforehand and covers one
  day), or for streak anxiety.

**Keep.** The part with measurements, a streak kept by a minimal action apart from the goal, is in.
The 120 s is one constant (`DailyGoal.streakSeconds`) and the one-day repair one rule (`Streak.evaluate`).
Check on the log: the share of study days that kept the streak and left the ring open. Under 5 % makes
the step a formality, over 40 % makes it do the ring's job (our thresholds); adjust the one constant.

## 4. Two rests a day at most

Decision: rests after the streak step and at the closed ring, otherwise one continuous stream.

- Meta-analysis of micro-breaks, 22 samples, N = 2335: vigor d = .36, fatigue d = .35, overall
  performance d = .16 (p = .116, not significant), performance gains only on low-demand tasks, larger
  with longer breaks. Albulescu et al., PLOS ONE 2022, https://pmc.ncbi.nlm.nih.gov/articles/PMC9432722/.
  Measured, workplace tasks.
- Within-session decline of flashcard accuracy by session length: no source found.

**Measure.** Breaks help how people feel and show no effect on demanding tasks; no study covers a
flashcard stream. Measurement: for streams of at least 15 minutes (gaps under 5 minutes between
reviews), bucket reviews by minute in the stream (0-5, 5-10, 10-15, 15+) and compare the Forgot rate
with 1 - R at review time (from `Scheduler.replaying`) and the median `ms`. If Forgot exceeds the
prediction by 5 points, or `ms` grows 20 %, past some minute, add a skippable rest at that minute (our
thresholds). Otherwise the stream stays as it is.

## 5. The backlog spread

Decision: overdue cards are part of the plan like any card due, most forgotten first; the day's time cuts the goal.

- Anki manual: with a backlog stop new cards; for a large one sort by ascending retrievability, the
  most forgotten first. https://docs.ankiweb.net/deck-options.html. Opinion of the maintainers.
- Anki Forums: a filtered catch-up deck with a daily allowance, sorted by descending retrievability,
  "the most efficient sort order". https://forums.ankiweb.net/t/adressing-backlog/43842. Single report.
- FSRS developers' simulations (`review-sort-order-comparison`): descending retrievability keeps retention
  level even when the backlog is never cleared and gives the highest average retention (94.9 % quoted).
  https://forums.ankiweb.net/t/improving-sort-orders/50081 and
  https://forums.ankiweb.net/t/which-is-the-most-recommended-display-order-for-fsrs/65483. Measured in
  simulation; the notebook was not read.
- The second thread cites an FSRS-6 efficiency chart that puts ascending retrievability first. Single
  report; chart not read.
- FSRS: the lower R at a successful review, the larger the stability gain.
  https://expertium.github.io/Algorithm.html (takeaway four). Measured (fitted on review data).
- A contributor holds that the order barely matters when the backlog lives much shorter than the
  stability of its cards. Opinion. Nothing found on seven days.

**Measure**, low priority. The sources split by objective: retention favours the least forgotten first,
efficiency the most forgotten first. Seven days is short against the stability of most cards.
Measurement, at the first backlog above 100 cards: run the notebook of
`open-spaced-repetition/review-sort-order-comparison` with EF's fitted parameters and retention target,
backlogs of 100 and 300 cards spread over 7 days, ascending against descending R; compare mean recall on
day 7 and reviews needed to day 30. Switch only if one wins both by over 2 points (our threshold).

The spread over seven days was removed: the time cap already paces the backlog. The order, most forgotten
first, stays to measure.

## 6. Production cards after a 7-day interval

Decision: meaning → Greek cards unlock when the recognition card's interval reaches 7 days; separate
new-card limits.

- `production-cards-research.md` holds the findings and the verdict: the delay itself is untested,
  production is the harder direction and receptive study buys little of it, a first spaced review passed
  is the point Nation's and Terai's argument is about. Confidence low, as that file says.
- New in this run: nothing read. A search for a staged-against-simultaneous experiment returned a 2026
  paper on spacing by word-knowledge type (https://journals.sagepub.com/doi/10.1177/13621688261449449),
  unread. Separate limits per direction need no source; Anki limits per deck the same way.

**Measure.** Protocol from `production-cards-research.md` §3: the share of Forgot on production cards'
first two review-phase reviews against FSRS's expected 10 %. Over 25 % on a deck gated at 7: raise to 14.
At or below 10 % on a deck gated at 14 or more: lower to 7 or 0. Wait for 100 first reviews of
production cards; at 10 % the standard error of the share is 3 points.

## 7. One stream across all decks

Decision: the next card comes from the deck whose next card is most urgent.

- Meta-analysis of interleaving, 59 studies: g = 0.42 overall, 0.67 for paintings, 0.34 for mathematics,
  texts ambiguous, blocking ahead for words (g = -0.39); stronger when categories look alike. Brunmair &
  Richter, Psychological Bulletin 2019, accepted manuscript at
  https://www.psychologie.uni-wuerzburg.de/fileadmin/06020400/2019/Brunmair_Richter_in_press__2019_META-ANALYSIS_OF_INTERLEAVED_LEARNING.pdf.
  Measured. The tasks are induction of categories, not recall of pairs under a spaced schedule.
- No study found of cross-deck order in a spaced-repetition app.

**Keep.** Ordering by urgency serves the scheduler: a card whose R is falling does not wait for a deck
switch. The words result concerns studying categorised words in blocks; it neither supports mixing nor
argues against it. If a mixed stream confuses EF, the trial is a per-deck "stay in this deck" switch.

## 8. Medals and the monthly recap

Decision: streak milestones, laps, big days, comeback, perfect week, first ring; a monthly recap screen.

- Meta-analysis of gamification in learning: g = .49 cognitive (k = 19), .36 motivational (k = 16), .25
  behavioural (k = 9); motivational and behavioural effects less stable in high-rigour studies. Sailer &
  Homner, Educ. Psychol. Rev. 2020, https://link.springer.com/article/10.1007/s10648-019-09498-w. Measured.
- Points, levels and leaderboards raised performance and left intrinsic motivation, autonomy and
  competence unchanged; the authors read them as progress indicators. Mekler et al., Gamification '13,
  https://researchprofiles.ku.dk/en/publications/do-points-levels-and-leaderboards-harm-intrinsic-motivation-an-em/.
  Single report (online task).
- Streak milestone screen: day-7 retention +1.7 % (Duolingo, section 3). Measured (company).
- Overjustification: Deci, Koestner & Ryan 1999, Psychological Bulletin 125(6):627–668,
  https://psycnet.apa.org/doi/10.1037/0033-2909.125.6.627, 128 studies. Expected rewards undermine free-choice
  intrinsic motivation: engagement-contingent d = −0.40, completion-contingent −0.36, performance-contingent
  −0.28. Unexpected tangible rewards: d = 0.01 (9 studies, ns); task-noncontingent: d = −0.14 (ns). Positive
  feedback enhances it: d = 0.33 free choice, 0.31 self-reported interest. Symbolic awards count as tangible
  (the "Good Player Award" of Lepper, Greene & Nisbett 1973). Tangible rewards harm children more than
  college students. Measured (meta-analysis), read from the PDF.
- No source found for the tier numbers, or for a recap screen.

**Change (small).** A medal is a symbolic reward; it stays on the safe side of Deci, Koestner & Ryan when
it comes unexpected and reads as feedback on what was done. So: the next medal shows as a grey silhouette
with its name and no progress count ("12 of 14 days" turned it into an expected reward for completing a
task); medal texts name the achievement ("Two rings in a day", "Saved your streak after a missed day"), never
a price to pay. Done in 5.3.6. The tiers themselves remain a choice; revisit if EF turns celebrations off.

## 9. Grading: one "no", three "yes", swipes, no intervals on the buttons

Decision: Forgot, Hard, Good, Easy; swipes with dead zones; the interval shows only after the grade.

- `fsrs-research.md` §1: FSRS predicts slightly better for users of Again and Good; the costliest slip
  is Hard on a forgotten card. Reported by several (FSRS authors, tutorial, forum).
- Anki manual: pressing Hard when the card was forgotten makes all intervals unreasonably high.
  https://docs.ankiweb.net/deck-options.html. Hard counts as a success (a multiplier w15 below 1), Easy
  carries w16 between 1 and 6: https://expertium.github.io/Algorithm.html. Documented in the algorithm.
- Intervals on the buttons: a language teacher reports students pick the button from the shown interval,
  misjudge, and choose unstably; proposal to hide times or default to two buttons.
  https://forums.ankiweb.net/t/hide-time-until-next-review-by-default/45772. Single report, no data.
- Sector angles and dead zones: no source found; `design-spec.md` §4.7 holds the design measurements.

**Keep.** The layout follows the consistent-grading finding and the manual's Hard warning. Cheap check
after a refit: the fitted w15 and w16 against defaults, and the lapse rate on the review after a Hard,
which should sit well under the Forgot rate (near it means Hard serves as a second "no").

## 10. The maturity ramp in one hue

Decision: ordered classes in the accent's indigo, New in grey.

- Colour maps should be perceptually ordered (lightness rising evenly, so order reads without a key) and
  readable under colour-vision deficiency, 0.5 % of women and 8 % of men; rainbow maps fail both.
  Crameri et al., Nature Communications 2020, https://www.nature.com/articles/s41467-020-19160-7.
  Single report (review article with computed metrics).
- In the repo: OKLCH hue 278, lightness 0.86 to 0.40, adjacent steps 10-13.5 ΔE2000 apart, New outside
  the ramp (`Presentation.swift`); steps are also named in words ("Maturing"), so colour is not the only
  carrier. `design-spec.md` (the "Maturity ramp" bullet) still describes the earlier blue ramp.
- ColorBrewer's guidance on sequential schemes for ordered data: not found in this run.

**Keep.** One hue ordered by lightness is what the colour literature gives for ordered classes, and the
step spacing is already measured.

## Summary

| Decision | Verdict | Action |
|---|---|---|
| 1 Partial credit | keep | none |
| 2 The day's time | measure | replay the weights, the cap and the clamp on EF's log |
| 3 Streak step | keep | optional check of streak-only days (5-40 % band) |
| 4 Two rests | measure | Forgot rate and `ms` by minute in streams of 15+ min |
| 5 Backlog spread | measure | simulate ascending against descending R at the first backlog over 100 cards |
| 6 Production cards | measure | Forgot share on first two production reviews, 100 reviews minimum |
| 7 One stream | keep | none |
| 8 Medals | change (small) | the next medal without a progress count; texts as feedback, not a price |
| 9 Grading | keep | after a refit, compare w15 and w16 and the lapse rate after Hard |
| 10 Maturity ramp | keep | none |
