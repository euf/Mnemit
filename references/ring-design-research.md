# Evidence for the ring design: adaptive daily goals, goal success and persistence, SRS workload, app defaults

Collected 2026-10-23 for three open choices: how the ring time T changes from day to day, what share of days the ring should close, and how many new
cards to admit. This file gathers sources and does not decide. It adds to `goal-setting-research.md`, `learning-flow-research.md` and
`decisions-evidence.md`; Duolingo's streak A/B, Lally 2010, Locke & Latham, the 85 % rule, Buist 2008, Deci 1999, Beeminder, Apple and Garmin auto
goals, Kivetz goal gradient and the Anki backlog advice are there and are not repeated.

Confidence labels: measured (data in a source that was opened) / reported by several / single report / opinion. "Not read" marks a source of which
only a search snippet or a title was seen. "Derived here" marks arithmetic done for this note. Abstracts of papers were read through PubMed
(E-utilities) and Semantic Scholar; full texts through Europe PMC, PMC efetch and `pdftotext` on the fetched copy of the PDF.

## 1. Adaptive daily goals in behaviour-change trials

All trials below are walking or activity trials. No trial of a learning task with an adaptive daily goal was found.

- Adams et al. 2013, PLoS One, N = 20 inactive overweight adults, 6 months, adaptive (AI) vs static 10,000 steps/day (SI). Rule: after a 10-day
  baseline, the goal for day d is the 60th percentile of the steps of the last 9 days (a moving window; the newest day replaces the oldest; missing days
  are skipped so the window always holds 9 valid days). Each goal is announced as good for one day only. AI got $1 per met goal (points, gift card per 5
  points); a missed goal cost nothing and no message criticised it. SI got incentives for uploading data. Results: AI +2,728 steps/day from baseline,
  SI +1,598; difference 1,130 (Cohen's d = 0.74). Goal met on 58.2 % of days in AI (range 36.1-91.0 %) against 22.5 % in SI (range 1.8-66.1 %);
  the algorithm nominally gives 40 %. After a day on which the goal was met, the next day's steps were equal or higher on 41.1 % of days in AI and
  23.5 % in SI. Step data were complete on 93.5 % of 180 days. Dropout by arm: not stated in the parts read. The incentive differed between arms, so
  the rule and the contingent reward are confounded.
  https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0082901. Confidence: measured (small N, one lab).
- Adams et al. 2017, BMC Public Health (not an AJPM paper), 2 x 2 factorial, N = 96, 4 months: adaptive vs static goals, immediate vs delayed reward.
  Same rule: 60th percentile of the last 9 valid days, rounded up to the next multiple of 25 steps, valid for one day. Static: 10,000 steps, 5 days of 7.
  Both groups rose 2,389 steps/day on average. Static rose more at the start (2,630 vs 2,149, difference 482, p = .095) and decayed faster during the
  intervention (-18.3 vs -7.7 steps/day per day, p < .001); the static curve crossed below the adaptive one. Immediate reward beat delayed (+2,762 vs
  +2,016, p = .009). Dropout and share of goals met: not read. https://link.springer.com/article/10.1186/s12889-017-4197-8. Confidence: measured.
- Adams et al. 2022, Am J Prev Med 62(2):e57-e68 (WalkIT Arizona), N = 512, one year, 133,876 accelerometer days, MVPA bouts of at least 3 minutes.
  Adaptive rule: 60th percentile of the last 9 valid observations of MVPA minutes (example in the paper: 5, 5, 6, 9, 11, 12, 15, 15, 17 gives 12);
  adaptive goals ranged 3-60 min/day; static goal 30 min/day. A day with any MVPA bout: odds ratio against baseline 2.34 (adaptive) vs 1.66 (static),
  p < .001. Mean MVPA minutes did not differ significantly between goal groups. The trajectories differed: adaptive fell steeply for about 8 months then
  turned up, static fell monotonically; the authors read this as adaptive goals countering intervention fatigue. Immediate reward +16.54 min/day vs
  delayed +9.91. Average wear compliance 70 %; dropout and goal-met share by arm: not found in the text read. Abstract
  https://pubmed.ncbi.nlm.nih.gov/35000693/; full text PMC8820277 (read via efetch). Confidence: measured.
- Walkadoo trial (MeYou Health), JMIR 2016;18(2):e34, N = 265 workers, 6 weeks, program vs no treatment (not vs a static goal). Rule: 9-day moving window,
  a percentile range slightly above the 50th, and the exact goal drawn at random inside the range so that difficulty varies from day to day. Result:
  +970 steps/day over control (p < .001). In the low-to-somewhat-active stratum the first-listed arm (control, by the table's order) fell 1,286 steps/day
  and the second (treatment) 110 (p = .004). Share of goals met and dropout: not found. https://pubmed.ncbi.nlm.nih.gov/26860434/ (full text PMC4764789).
  Confidence: measured; vendor-authored.
- Zhou et al. 2018, JMIR mHealth uHealth 6(1):e28 (CalFit), N = 64 randomised after a 1-week run-in (34 intervention, 30 control), 10 weeks, adaptive
  vs fixed 10,000. Rule: a machine-learning model of each person's steps and past goals (behavioural analytics algorithm), refitted weekly, picks the
  goal expected to maximise future steps; the run-in used dynamically rising goals. Change from run-in to week 10: -390 steps (intervention) vs -1,350
  (control), net 960 (95 % CI 90-1,830, p = .03); both fell because the run-in already had an intervention. Share of goals met, by week 2 to week 10:
  intervention 0.49, 0.41, 0.44, 0.34, 0.33, 0.37, 0.34, 0.36, 0.34; control 0.34, 0.34, 0.29, 0.28, 0.25, 0.29, 0.23, 0.21, 0.19. Run-in week:
  0.71 and 0.74. Net difference in the fall of the met share 0.15 (95 % CI 0.02-0.25). Adaptive goals averaged below 10,000. Dropout by arm: not found in
  the parts read. https://mhealth.jmir.org/2018/1/e28/ (read via Europe PMC XML). Confidence: measured.
- Korinek et al. 2018, J Behav Med (Just Walk), N = 20, 14 weeks, one arm. Goals were pseudo-random (a multisine signal) between the participant's
  baseline median and 2.5 times that median, with 100-500 points ($0.20-$1.00) per goal, to identify each person's response. It is an identification
  experiment, with no feedback from performance to goal. Steps +2,650 from baseline to the end (t = 8.25); the quadratic term puts an inflection
  near the midpoint (t2 = -247); app satisfaction high and the abstract says participants enjoyed receiving variable goals each day. Goal-met share:
  not read. https://pubmed.ncbi.nlm.nih.gov/28918547/. Confidence: measured (uncontrolled).
- Phatak et al. 2018, J Biomed Inform (same Just Walk data, N = 20): person-specific ARX models picked different predictors of steps for most people;
  a pooled multilevel model would have picked the same predictors for 5 of 20, a mismatch for 75 %. https://pubmed.ncbi.nlm.nih.gov/29409750/.
  Confidence: measured, small N.
- Control-systems loop (Hekler, Rivera, Martín): no published outcome trial of a closed-loop goal controller was found. The 2023 protocol
  "Project JustWalk JITAI" (system-ID study) exists, title only: https://pubmed.ncbi.nlm.nih.gov/37751237/. Confidence: not read.
- Patel et al. 2021, JAMA Cardiology (ENGAGE), N = 500 lower-income adults at cardiovascular risk, 24 weeks: four gamification arms that vary how the
  daily step goal is set (self-chosen or assigned) and introduced (immediately or gradually) against attention control. Only self-chosen goals started
  immediately beat control: +1,384 steps/day in the maintenance period (95 % CI 805-1,963), +1,391 at 8-week follow-up. The gradual ramp-up arms had no
  consistent gain. Goal levels and goal-met shares: not read. https://pubmed.ncbi.nlm.nih.gov/34468691/. Confidence: measured (abstract read).
- Ignite pilot, Obes Sci Pract 2026, N = 32, 10 weeks, digital weight-loss programme with an easier or harder goal in four domains (calories, steps,
  eating window, red zone). 94 % retention (30 of 32). The harder calorie goal gave 2.3 kg more loss (95 % CI 0.6-4.1); no main effect for the other
  goals, steps included. https://pubmed.ncbi.nlm.nih.gov/42473633/. Confidence: single report (pilot).
- Mohammadi et al. 2020, JMIR mHealth uHealth: a neural network predicting an "achievable" weekly step target from the previous 7 days plus personal
  factors; 20 of 30 participants used, mean absolute error 1,545 steps/day over 8 weeks. It predicts targets and reports no behaviour outcome.
  https://pubmed.ncbi.nlm.nih.gov/32897235/. Confidence: single report.

Summary table of the rules and the share of days with a met goal:

| Trial | Goal rule | Days with goal met | Effect on behaviour | Dropout or adherence |
|---|---|---|---|---|
| Adams 2013 (N 20) | 60th percentile of last 9 days | 58.2 % (nominal 40 %); static 22.5 % | +1,130 steps/day vs static | not stated; 93.5 % of days with data |
| Adams 2017 (N 96) | same, rounded up to 25 | not read | static higher early, adaptive decays at 0.42 of the static rate (derived) | not read |
| Adams 2022 (N 512) | same on MVPA minutes, 3-60 min | not read | any-MVPA day OR 2.34 vs 1.66; mean minutes equal | wear compliance 70 % overall |
| Walkadoo (N 265) | percentile slightly above 50th, random draw | not read | +970 steps/day vs no treatment | not read |
| Zhou 2018 (N 64) | ML on steps and goals, weekly | 0.49 falling to 0.34; control 0.34 to 0.19 | net +960 steps/day vs fixed 10,000 | not found |
| Korinek 2018 (N 20) | random between median and 2.5 x median | not read | +2,650 steps/day, uncontrolled | not read |

- A percentile rule on independent days closes the goal on (100 - percentile) % of days: 60th gives 40 %, a goal met on about 80 % of days sits at the
  20th-22nd percentile of recent work. Derived here. Observed shares in the trials (33-58 %) run above the nominal 40 % because behaviour moves with
  the reward. The trials above report no goal-met share near 80 %. Confidence: derived.

## 2. Goal success rate and persistence

- Silverman & Barasch, J Consumer Research 49(6), 2023, seven studies. Core result: the same past behaviour shown as an intact logged streak raises
  later engagement and shown as a broken streak lowers it; the effect depends on how the log shows the history. It is larger when people blame
  themselves for the break, and smaller when the break can be repaired. Numbers read in the accepted manuscript:
  - Study 1 (field): a university 30-day challenge of 7,000+ steps/day, steps synced from trackers, the app showed the streak. Logistic model, controlling
    each person's overall hit rate: intact streak (3+ days) vs broken streak b = 0.38 (Z = 11.27, p < .001); broken streak alone b = -1.01
    (Z = -14.94); intact alone b = 0.25. N of the field sample: not read.
  - Study 3 (N = 602, online, a vocabulary task framed like a language app): with an intact streak, 92.5 % continued when the log showed it and
    64.9 % when it did not (OR 6.6); with a broken streak, 45.2 % when the log showed it and 60.9 % when it did not (OR 0.53).
  - Study 7 (repair): 93.1 % continued after an intact streak, 68.7 % after a broken one, 85.2 % after a broken streak that could be repaired
    (OR 2.63 repairable vs broken). Repair left a gap to the intact case.
  https://doi.org/10.1093/jcr/ucac029; manuscript https://udspace.udel.edu/server/api/core/bitstreams/7e3e3b64-8bf2-4527-ac93-94a160358165/content.
  Confidence: measured (field plus online experiments with hypothetical or low-stakes choices).
- The author says in an interview that people in their data switched to a new language after a broken streak instead of rebuilding one in the same
  language. https://www.colorado.edu/business/news/2023/04/20/research-streaks-marketing-tech-barasch. Confidence: single report (interview).
- Sharif & Shu 2019, Organizational Behavior and Human Decision Processes: one field and four lab studies; a failed subgoal lowers commitment to the
  whole goal and can end it; framing the same goal with an "emergency reserve" (slack) raised perceived progress, commitment and persistence after the
  failure, at equal objective difficulty. Numbers not read (abstract only). https://doi.org/10.1016/j.obhdp.2019.01.004. Confidence: measured.
- Cochran & Tesser 1996, the "what-the-hell" effect (goal proximity, goal framing, and performance after a violation): primary text not read
  (PsycNet and Taylor & Francis pages gave no body). A 2026 summary attributes to it that goals about acquiring something (a skill, practice) gain
  from short-term milestones, and goals about restraint gain from long-term framing. https://psycnet.apa.org/record/1996-97873-004,
  https://more.efpsa.org/rpblog/2026/02/01/the-what-the-hell-effect-how-small-slip-ups-spiral-out-of-control/. Confidence: opinion (secondary), primary not
  read.
- Persistence under hard vs adaptive goals, from section 1: static 10,000 steps decayed at 18.3 steps/day per day against 7.7 for the adaptive goal
  (Adams 2017); the static MVPA goal declined monotonically for a year and the adaptive group's curve turned up near month 8 (Adams 2022); the met share
  fell from 0.49 to 0.34 under the adaptive rule and from 0.34 to 0.19 under the fixed one (Zhou). Confidence: measured; no study varied the goal-met
  share on purpose, so none shows that a given share causes persistence.
- Duolingo: no publication on daily goals on research.duolingo.com (entries read: 2019-2021, none on goals or streaks; the one on notifications is a
  bandit for timing). Third-party guides give the XP tiers as Basic 1, Casual 10, Regular 20, Serious 30, Intense 50 (the same page also lists ranges 1-10,
  15-20, 30-50, 50+). Default tier and the share of learners per tier: not found. https://research.duolingo.com/,
  https://duolingoguides.com/how-to-change-daily-goals-on-duolingo/. Confidence: single report (non-official).
- Wearable abandonment and goal attainment: titles only, not read: "Abandonment of personal quantification: A review and empirical study"
  (https://www.sciencedirect.com/science/article/pii/S0747563219303127), "Fitness Tracker Abandonment: The Role of User Diversity"
  (https://www.researchgate.net/publication/344272085). No source with goal-attainment rate against continued wear was found. Confidence: not read.

## 3. Spaced-repetition workload

- Anki Manual, Deck Options (https://docs.ankiweb.net/deck-options.html, read 23.10.2026). New Cards/Day: new material is
  repeated several times before the gaps grow, so 20 new cards a day bring roughly 200 reviews a day, and reviews come
  down by introducing fewer new cards. New Cards Ignore Review Limit (off by default): the review limit also stops new
  cards; with overdue reviews stop new cards until caught up, as more of them make the backlog worse. A Short Guide:
  desired retention is the most important FSRS setting; 90 % is the default and a good balance, above 90 % the workload
  rises very quickly, above 97 % it can be overwhelming. The simulator estimates workload in reviews or in minutes a day
  from new cards a day and the review cap. Confidence: maintainers' documentation.
- FSRS's "Three-Day Journey" (https://github.com/open-spaced-repetition/awesome-fsrs/wiki/Spaced-Repetition-Algorithm:-A-Three%E2%80%90Day-Journey-from-Novice-to-Expert):
  the number of reviews and the time per review are the cost of memory; scheduling is optimised either for as much
  material as possible to reach a target stability within a cost constraint, or for given material at minimal cost
  (SSP-MMC); its simulator takes the days to a deadline and a daily learning time and stops a day's cards when the time
  is used. Stability gains most from a review at low recall, so reviewing early wastes effort. Confidence: FSRS author's
  tutorial.
- srs-benchmark (https://github.com/open-spaced-repetition/srs-benchmark, README read 23.10.2026): algorithms are compared
  by log loss and RMSE over bins (calibration of the predicted recall) and AUC (telling recall from lapse); FSRS-6 without
  same-day reviews: log loss 0.346, RMSE(bins) 0.065, AUC 0.703, behind FSRS-7 and the neural models. Confidence: measured.
- SuperMemo's universal metric (https://supermemo.guru/wiki/Universal_metric_for_cross-comparison_of_spaced_repetition_algorithms):
  the root mean square over retrievability classes of predicted against actual recall, computed from recorded histories
  so algorithms can be scored on each other's data; on 700,000 repetitions SM-20 0.04, SM-17 1.1, FSRS 16.43 optimised,
  SM-2 35.3, with SM-17 as the frame of reference. Confidence: measured by an interested party.
- None of the four measures knowledge gained per minute of study; the cost of the student is the open question in the
  SuperMemo page and the constraint in the FSRS tutorial.
- Anki defaults are 20 new cards and 200 reviews per day, read from the source (`new_per_day: 20`, `reviews_per_day: 200`).
  https://github.com/ankitects/anki/blob/main/rslib/src/deckconfig/mod.rs. Confidence: measured. The manual sections on New Cards/Day and Maximum
  Reviews/Day state the ratio (20 new a day means about 200 reviews a day), the purpose of the review cap (smoothing peaks and protecting a return after
  a week off) and the warning about beginners who learn hundreds of new cards early and then drown in reviews; they give no reason for the two default
  numbers (https://docs.ankiweb.net/deck-options.html; confidence: reported by several). A 2026 article by an app vendor (disclosed) says the same:
  the number is in the code, not in the manual (https://piccard.app/blog/how-many-new-anki-cards-per-day/, single report).
- Forum answer to a beginner asking whether 20 was set for a reason: keep the defaults at first because new cards pile up reviews; expect 8-10 times the
  daily new cards in reviews; set the review cap to unlimited so that no due card is missed.
  https://forums.ankiweb.net/t/how-many-cards-should-i-be-studying-a-day-is-this-a-personal-preference-or-did-anki-set-the-daily-limit-to-20-cards-for-good-reason/49634
  (2024). Confidence: single report (two community members, no maintainer).
- Limit New by Young (add-on): a cap on the number of young cards in a deck. New cards are released as the young pool falls below the cap, so new cards
  arrive at about the rate older ones mature and no manual tuning is needed; variants cap by estimated daily review load or by cards due soon, and
  rules combine per deck. The author's usage rule: review limit 9999, load limit X equal to the reviews wanted per day, new limit whatever is comfortable.
  https://github.com/lune-stone/anki-addon-limit-new-by-young,
  https://www.reddit.com/r/Anki/comments/1dlvapi/how_to_not_be_overwhelmed_by_reviews_using_an/. Confidence: single report (author's documentation, no data).
  The AnkiWeb page needs JavaScript: not read.
- Whether backlogs make users quit: no measured attrition data found. Opinions conflict. In the 2025 thread on raising the default desired retention
  to 95 %, one contributor holds that many people quit Anki because they cannot keep up or clear a backlog and wishes for an A/B test; the proposer holds
  that too-long intervals make people quit before they see benefits. Neither gives data. https://forums.ankiweb.net/t/58273. Confidence: opinion.
- Survey of first-year medical students, Cureus 17(10):e95674, 2025, one school, about 84 respondents (69 = 82.1 %): 82.1 % found Anki overwhelming to some
  degree, 67.9 % felt anxious, 68.3 % felt frustrated when they did not finish daily reviews, 95.1 % felt accomplished when they did; 75 % never or rarely
  kept up reviews from earlier modules; a higher average daily card count correlated with perceived success (r = 0.330). Only five non-users, so reasons for
  stopping are not reported. https://doi.org/10.7759/cureus.95674. Confidence: measured (single-school survey, self-report).
- FSRS workload with simulators: a vendor page states the simulation uses default FSRS-6 parameters, assumes study every day and no review cap, and
  that load climbs fast in the first months, flattens as old cards reach long intervals, and falls fast when new cards stop; fitted parameters usually
  predict a lighter load than the defaults. https://noosflashcards.com/resources/fsrs-simulator. Confidence: single report (vendor, no numbers
  extracted). No published curve of reviews per new card at retention 0.9 was found; the usable numbers are the steady-state ratios here and in
  `goal-setting-research.md` section 4.
- SuperMemo: workload is framed by time. Knowledge acquisition rate is items memorised per year per minute of daily study, 30-1,000 depending on
  material, forgetting index and stage, most users 100-400; 20 minutes a day at 500 gives 10,000 items a year. https://supermemo.guru/wiki/Knowledge_acquisition_rate.
  Confidence: single report (author's glossary). The Mercy tool reschedules outstanding repetitions to a user-set maximum per day, warns that every use
  adds hours of work for the same material, and its first version, which sorted for least retention loss, left abusers with piles of hard items that kept
  coming back. https://www.supermemo.com/en/blog/mercy. Confidence: single report. The Workload help page describes the display only and gives no guidance
  (https://www.super-memory.com/archive/help15/workload.htm).
- WaniKani: the official settings page lists a lesson batch size (default 5, range 3-10) and "Maximum Recommended Daily Lessons" (0-100); no default
  daily number was found. https://knowledge.wanikani.com/wanikani/app-settings/. Confidence: reported by several (documentation read).
  Forum arithmetic: each lesson books 8 reviews at perfect accuracy, so reviews per day = lessons x (8 + 3 x failure rate), 15 lessons a day with 10 %
  failures about 125; 20-25 lessons a day gives 200-250 reviews a day for months, and a broken routine then meets a very high review count that is
  "daunting"; 15 a day is the pace quoted most often. https://community.wanikani.com/t/maximum-recommended-daily-lessons/70827,
  https://community.wanikani.com/t/are-15-lessons-a-day-enough/66385. A third-party guide gives 10 lessons a day and a stop when the Apprentice count
  passes 100 as the best-documented moderate pace, and 80-110 reviews a day at 10 lessons. https://wanilog.com/guides/lessons-per-day.
  Confidence: single report (forum) and single report (guide).

## 4. Default daily goals in learning apps

- Busuu: the study plan asks for a daily time of 5 to 30 minutes; the help page recommends at least 10 minutes a day; goal options vary with the
  course level. Updated July 2026. https://help.busuu.com/hc/en-us/articles/16097312171153-What-s-a-Study-Plan-How-do-I-make-one.
  Confidence: single report (vendor documentation). Distribution of chosen values: not found.
- Lingvist: the goal used to be 100 cards a day. The company moved to sets of 50 cards with a weekly target of four study days, stating that its
  research showed smaller sets lead to faster progress; no data given. The help page says 50 words a day, 4 times a week works best in the company's
  observations, and advises at least 50 cards at least every other day.
  https://lingvist.com/blog/fewer-cards-per-day-faster-learning/,
  https://lingvist.com/help/how-should-i-learn-with-lingvist-and-why-does-it-work/. Confidence: single report (vendor claims, no data).
- Memrise: a streak grows on days the daily goal is hit by learning or reviewing words; the goal is points based; the tiers and default were not
  reachable (the linked article returned 404). https://memrise.zendesk.com/hc/en-us/articles/360015973598-What-are-Streaks-and-how-do-they-work.
  Confidence: single report.
- Duolingo tiers: see section 2. Quizlet, Brainscape and Clozemaster goal mechanics are in `learning-flow-research.md`; nothing new was found on their
  defaults.
- Published distribution of chosen goals or adherence by tier, for any app: not found. The Duolingo 2020 result that the highest tier had the fewest
  streaks is already in `goal-setting-research.md`.

## 5. Not found or not read

- Dropout or adherence by arm in the Adams trials, Zhou, Walkadoo (full texts were searched for the words, no figure found; Adams 2017 and 2022 not
  searched in full).
- Closed-loop control-systems goal trials (Hekler, Rivera, Martín) with outcomes.
- Any trial that varies the goal-met share on purpose, and any trial of an adaptive daily goal for a learning or memory task.
- Primary text of Cochran & Tesser 1996; goal levels in ENGAGE; the N of Silverman & Barasch Study 1.
- Reviews per new card over time at retention 0.9 as a published curve; measured attrition caused by review backlogs.
- Duolingo's default daily goal and the share of learners per tier; adherence by tier for any app.

## What this means for the ring

- No trial used a goal met on about 80 % of days. Adaptive rules ran at a nominal 40 % and reached 33-58 %; static goals reached 19-34 % (section 1,
  table). The closure tracker (x1.075 closed, x0.775 open) settles where the share of closed rings p satisfies p ln 1.075 = (1 - p) ln(1/0.775),
  which is 78 % (derived here) and equals the 22nd percentile of recent daily work. Its closure share lies outside the tested range, on the easier
  side; no source says whether an easier ring helps or harms persistence.
- Adaptive goals beat static ones in the controlled trials that compared them: +1,130 steps/day (N 20), net +960 (N 64), any-MVPA-day OR 2.34 vs 1.66
  (N 512). In the N 96 trial static led at first (p = .095) and lost through faster decay (items Adams 2017, 2022, Zhou). Adapting T is supported
  in direction; the effect sizes come from walking, not from learning.
- Every trial rule used the size of recent work (a percentile of 9 days, or a model of steps and goals). None used only a closed/open bit as the tracker
  does, so the factors 1.075 and 0.775 have no trial behind them, as `decisions-evidence.md` §2 already says. The percentile relation makes a replay
  on EF's log easy: compare the tracker with a rolling 20th-25th percentile of daily time on the share of closed rings.
- The trials gave one goal per day, announced as valid for that day, with no penalty or critical message after a miss (Adams 2013, 2017, 2022). The
  ring's no-settings design and its neutral wording after an open ring match that practice.
- Streak and ring: an intact streak raised next-day engagement and a broken one lowered it, with 93 % vs 69 % continuing in the repair experiment and
  85 % when repair was possible (Silverman & Barasch); slack framing after a failed subgoal kept commitment (Sharif & Shu). A one-day repair and a
  streak kept by a minimal action fit these results; the ring's own misses carry the weaker evidence of the two (what-the-hell effect: primary not read).
- The persistence evidence concerns decay of the effect, and the adaptive goal decayed slower than a high fixed goal in two trials (Adams 2017, 2022).
  No source links a closure share to continued use, so the share of study days with a closed ring and the days to the next study session after an open
  ring are the numbers to log and compare on Mnemit's own data.
- New-card allowance: steady-state reviews per daily new card are 8-10 in the Anki manual (10), the forum (8-10) and WaniKani (8-11 with misses). An
  allowance of n a day adds about 8-10 x n reviews a day after the first months, so n can be sized as the minutes of T left after due reviews, divided by
  seconds per review and by about 10; Limit New by Young and the manual's rule to stop new cards under a backlog work the same way (section 3).
- Backlog is the open risk: opinions conflict and no attrition data exists. A student survey (N about 84) shows 82 % finding Anki overwhelming at times
  and 75 % not keeping up old reviews, with no information on quitting. App defaults elsewhere are short fixed commitments: 5-30 minutes with 10
  recommended (Busuu), 50 cards on four days a week (Lingvist), 10-50 XP tiers (Duolingo). The 2-30 minute clamp lies in that band; its lower
  and upper values have no source of their own.
