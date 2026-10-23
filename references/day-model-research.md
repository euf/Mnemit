# Day-model research: adaptive goals, goal setting and habits, how comparable products structure a day

The sources behind the day model of Mnemit (ring, time, streak, rests, medals), collected on 22-23.10.2026. The file gathers sources and decides nothing:
the rule in force and the measurements that chose it are in `ring-design.md`, whose last section holds the evidence for the day's other decisions.
Three parts, each with its own way of sourcing: Part 1 trials and workload data, Part 2 goal-setting and habit research with FSRS and Anki practice, Part 3
a product-by-product reading.

Confidence labels in Parts 1 and 2: measured (data in a source that was opened) / reported by several / single report / opinion. "Not read" marks a source
of which only a search snippet, a title or a secondary summary was seen. "Derived here" marks arithmetic done for these notes. Part 3 tags each line by
origin, as its introduction says.

## Part 1. Adaptive goals, goal success and workload

Collected 2026-10-23 on three questions: how the ring time T changes from day to day, what share of days the ring should close, and how many new
cards to admit. This part gathers sources and does not decide; it adds to Parts 2 and 3 and to the last section of `ring-design.md`.
Duolingo's streak A/B, Lally 2010, Locke & Latham, the 85 % rule, Buist 2008, Deci 1999, Beeminder, Apple and Garmin auto goals, Kivetz goal gradient and
the Anki backlog advice are in those and are not repeated here. Abstracts of papers were read through PubMed (E-utilities) and Semantic Scholar; full texts through
Europe PMC, PMC efetch and `pdftotext` on the fetched copy of the PDF.

### 1. Adaptive daily goals in behaviour-change trials

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

### 2. Goal success rate and persistence

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
- Persistence under hard vs adaptive goals, from §1: static 10,000 steps decayed at 18.3 steps/day per day against 7.7 for the adaptive goal
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

### 3. Spaced-repetition workload

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
  Part 2 §4.
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

### 4. Default daily goals in learning apps

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
- Duolingo tiers: see §2. Quizlet, Brainscape and Clozemaster goal mechanics are in Part 3; nothing new was found on their
  defaults.
- Published distribution of chosen goals or adherence by tier, for any app: not found. The Duolingo 2020 result that the highest tier had the fewest
  streaks is in Part 3 (Duolingo, item 7).

### 5. Not found or not read

- Dropout or adherence by arm in the Adams trials, Zhou, Walkadoo (full texts were searched for the words, no figure found; Adams 2017 and 2022 not
  searched in full).
- Closed-loop control-systems goal trials (Hekler, Rivera, Martín) with outcomes.
- Any trial that varies the goal-met share on purpose, and any trial of an adaptive daily goal for a learning or memory task.
- Primary text of Cochran & Tesser 1996; goal levels in ENGAGE; the N of Silverman & Barasch Study 1.
- Reviews per new card over time at retention 0.9 as a published curve; measured attrition caused by review backlogs.
- Duolingo's default daily goal and the share of learners per tier; adherence by tier for any app.

### What this means for the ring

- No trial used a goal met on about 80 % of days. Adaptive rules ran at a nominal 40 % and reached 33-58 %; static goals reached 19-34 % (§1,
  table). The ring's staircase (x1.15 after the second ring in a row closed on a goal that filled T, x0.775 after an open ring) settles where the
  share of closed rings p satisfies p² ln 1.15 = (1 − p²) ln(1/0.775), which is 80 % (`ring-design.md`) and sits at about the 20th percentile of recent
  daily work. Its closure share lies outside the tested range, on the easier side; no source says whether an easier ring helps or harms persistence.
- Adaptive goals beat static ones in the controlled trials that compared them: +1,130 steps/day (N 20), net +960 (N 64), any-MVPA-day OR 2.34 vs 1.66
  (N 512). In the N 96 trial static led at first (p = .095) and lost through faster decay (items Adams 2017, 2022, Zhou). Adapting T is supported
  in direction; the effect sizes come from walking, not from learning.
- Every trial rule used the size of recent work (a percentile of 9 days, or a model of steps and goals). None used only a closed/open bit as the staircase
  does, so the factors 1.15 and 0.775 have no trial behind them. The percentile relation ties a rolling percentile of daily time to a closure share;
  `ring-design.md`, "The step of T (5.6) and the rules tried on 23.10", measures quantile rules of the work against the staircase.
- The trials gave one goal per day, announced as valid for that day, with no penalty or critical message after a miss (Adams 2013, 2017, 2022). The
  ring's no-settings design and its neutral wording after an open ring match that practice.
- Streak and ring: an intact streak raised next-day engagement and a broken one lowered it, with 93 % vs 69 % continuing in the repair experiment and
  85 % when repair was possible (Silverman & Barasch); slack framing after a failed subgoal kept commitment (Sharif & Shu). A one-day repair and a
  streak kept by a minimal action fit these results; the ring's own misses carry the weaker evidence of the two (what-the-hell effect: primary not read).
- The persistence evidence concerns decay of the effect, and the adaptive goal decayed slower than a high fixed goal in two trials (Adams 2017, 2022).
  No source links a closure share to continued use, so the share of study days with a closed ring and the days to the next study session after an open
  ring are the numbers to log and compare on Mnemit's own data.
- New-card allowance: steady-state reviews per daily new card are 8-10 in the Anki manual (10), the forum (8-10) and WaniKani (8-11 with misses). An
  allowance of n a day adds about 8-10 x n reviews a day after the first months; the ring sizes n as the time T leaves after the due reviews, divided by the
  price of a new card, so the reviews of earlier new cards already hold their share of T. Limit New by Young and the manual's rule to stop new cards under
  a backlog work the same way (§3).
- Backlog is the open risk: opinions conflict and no attrition data exists. A student survey (N about 84) shows 82 % finding Anki overwhelming at times
  and 75 % not keeping up old reviews, with no information on quitting. App defaults elsewhere are short fixed commitments: 5-30 minutes with 10
  recommended (Busuu), 50 cards on four days a week (Lingvist), 10-50 XP tiers (Duolingo). The range of 2 minutes to an hour reaches above that band; its
  values come from the logs of Anki users (`ring-design.md`, "The evidence for each part").

## Part 2. Goal setting and habits

Research of 2026-10-23 for the daily ring rule: goal-setting research and the 85 % rule, habit formation, adaptive goals in products, FSRS and Anki
community practice, recall dynamics as a signal, measuring time. Unread primaries: Locke & Latham 2002 (PDF, certificate error), Lally 2010 (Wiley and PDF,
HTTP 403), Singh 2024 (MDPI, 403), Bandura & Schunk 1981, the AnkiWeb add-on pages (JavaScript only). Anki forum threads were read through the Discourse
`.json` endpoint.

### 1. Goal-setting research and the 85 % rule

- Specific, high goals beat vague or easy ones in over 1,000 studies; Locke & Latham 2002 and 2006 are the citations. Source:
  https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2021.704790/full (2021, a secondary account). Confidence: reported by
  several.
- The theory optimises one bounded task: Locke & Latham 1990 advised a lab goal that only about 10 % of subjects can reach. Nothing in it addresses a
  recurring daily goal or adherence. Same source and year. Confidence: reported by several.
- Failing a high, specific, assigned goal lowered affect, self-esteem and later motivation in two experiments (N=185 with fictitious feedback; N=86
  with task difficulty, task choice OR 13.9). In experiment 1 the omnibus test on motivation was not significant (p=0.10); the failed-vs-attained
  contrast was. Same source, 2021. Confidence: single report (one-shot tasks, online volunteers, goals assigned).
- The authors propose learning-goal framing (mastery, not an external standard) as a remedy; untested there. Same source, 2021. Confidence: opinion.
- Proximal sub-goals: Bandura & Schunk 1981 gave children weak in subtraction session-by-session sub-goals, one distal goal, or none; the standard
  citation says proximal goals did best. Source: https://www.simplypsychology.org/social-cognitive-theory.html (secondary, snippet cut off).
  Confidence: single report, not read. Latham & Seijts 1999 (proximal vs distal on a moderately complex task) is listed in the Frontiers references,
  title only.
- Self-set vs assigned: no direct test for daily practice found. One summary reports goal specificity, participation and commitment as significant
  among 108 bank managers (Aunurrafiq 2015). Source: https://wsu.pressbooks.pub/theoreticalmodelsforteachingandresearch/chapter/goal-setting-theory.
  Confidence: single report. Mnemit's goal is system-set and the learner does not take part in it.
- 85 % rule: for gradient-descent learners on binary tasks the optimal training error is 15.87 %, accuracy about 85 %. Tested on a perceptron and a
  two-layer network (MNIST), not on people. The authors say it matches staircase procedures built for 80-85 % accuracy and relates to desirable
  difficulty, the region of proximal learning and flow; batch training and more than two categories are open. Source:
  https://www.nature.com/articles/s41467-019-12552-4 (2019). Confidence: measured for machines, opinion as a statement about human motivation.
- Mapping to the ring: the rule is about the error rate per trial. A ring closed on 85 % of days is an analogy with no source behind it. FSRS's
  default desired retention (90 %) is the item-level quantity the rule describes. Confidence: opinion (this note's reading).

### 2. Habit formation

- Lally 2010: median 66 days to reach 95 % of a fitted automaticity plateau, range 18-254, among the 39 participants (of 82 with enough data) whose
  curves fitted; the study ran 84 days, later estimates are extrapolated. Exercise 91 days vs eating 65 and drinking 59, difference not significant
  (p=0.328). Source: https://www.thebehavioralscientist.com/articles/how-long-to-form-a-habit (secondary; paper https://doi.org/10.1002/ejsp.674 not
  read). Confidence: measured.
- One missed opportunity changed automaticity by less than half a point and scores recovered quickly. The study did not test repeated misses or long
  breaks. Compliance correlated with model fit (r=0.34). Same source. Confidence: measured, single study.
- Meta-analysis, 20 studies, 2,601 adults: medians 59-66 days, means 106-154 days (four studies); most studies high risk of bias (11). Sources:
  https://pubmed.ncbi.nlm.nih.gov/39685110/ (snippet), https://www.news-medical.net/news/20250128/How-long-does-it-take-to-form-a-healthy-habit.aspx
  (2024). Confidence: reported by several.
- Tiny Habits (Fogg): behaviour needs motivation, ability and a prompt; shrink the behaviour, anchor it to an existing routine. No trial found. A
  practitioner summary itself says shrinking wastes motivation in high-motivation launch periods. Source:
  https://goalsandprogress.com/tiny-habits-fogg-behavior-model-explained/ (2026). Confidence: opinion.
- Reading for the first weeks: habit growth takes about two to three months with a spread from 18 to 254 days, so the goal should stay at a minimum
  dose that closes almost every day for the first weeks. A single miss is cheap; a series is untested. Confidence: this note's inference from the
  items above.

### 3. Adaptive goals in products

- Duolingo's streak and daily-goal test: Part 3, Duolingo, item 7.
- Apple Activity: every Monday the Watch reports the previous week and suggests goals from previous performance; the user accepts or edits. Source:
  https://support.apple.com/guide/watch/adjust-your-activity-ring-goals-apd29b30023c/watchos (vendor documentation, text taken from a search snippet;
  the page body did not render). Algorithm unpublished. Confidence: single report.
- Apple suggestions can ratchet: a third-party guide warns that accepting every upward suggestion can push the goal above what is sustainable. Source:
  https://lifestack.ai/blog/apple-watch-move-goal (2026). Confidence: opinion.
- Garmin Auto Goal: the step goal is generated from previous activity levels; steps past the goal keep counting. Source:
  https://www8.garmin.com/manuals/webhelp/vivofit4/EN-US/GUID-3C2177B2-5BAE-4324-B709-8148220584D6.html (vendor manual, undated). Confidence: single
  report.
- Beeminder: a goal cannot be made easier sooner than 7 days from today (rate changes, breaks, quitting, lowering the stake); the rationale is
  hyperbolic discounting, with a grocery-delivery study and, by the page's own words, some guesswork behind the 7. Source:
  https://help.beeminder.com/article/45-what-is-the-akrasia-horizon (undated). Confidence: opinion (design rationale). It guards a self-set goal
  against the user; a system-set goal needs no such lock.
- Deloads: a within-subject trial (19 untrained men, 8 weeks, deload at midpoint and end vs continuous) exists; its results were not read. The paper
  says deloads are standard practice and cites earlier work that short training breaks do not harm long-run hypertrophy. Source:
  https://www.nature.com/articles/s41598-026-40612-5 (2026). A 2024 one-week-deload RCT sits at https://pmc.ncbi.nlm.nih.gov/articles/PMC10809978/
  (title only). Confidence: single report. No source read on progressive-overload rules.

### 4. FSRS and Anki community

- The simulator estimates workload in reviews per day or minutes per day from new cards/day, maximum reviews/day, desired retention and the real
  memory states. The manual's own advice: ask how many minutes per day you can realistically spend, then pick the retention whose graph fits. Source:
  https://docs.ankiweb.net/deck-options.html (manual, current). Confidence: reported by several. The time constraint is the manual's framing.
- Compute Minimum Recommended Retention picks the retention that learns the most material per unit time; going below it costs more time through
  forgetting. The manual marks it "<25.07" (retired afterwards). Same source. Confidence: reported by several.
- By default the review limit also caps new cards. With a backlog, stop adding new cards until caught up; adding more makes the backlog worse. Easy
  Days shifts due dates off chosen weekdays after the interval is computed; setting every day to Reduced equals all Normal; not retroactive. Same
  source. Confidence: reported by several.
- Fixed new cards/day cannot hold the load constant: with growing intervals reviews/day grow roughly logarithmically. To keep total daily load flat,
  set a review limit, leave new/day high, switch "New cards ignore review limit" off. A second user reports the same recipe stabilises within days and
  warns against cutting the review limit sharply. One user reports a stable 10 new + 100 reviews with a fixed limit. Sources:
  https://forums.ankiweb.net/t/how-many-new-cards-can-be-studied-every-day-while-the-workload-stays-the-same-long-term/69218 (2026),
  https://forums.ankiweb.net/t/how-to-judge-how-many-new-cards-i-should-be-adding-each-week/66159 (2025). Confidence: reported by several (community;
  derivation without data). This is Mnemit's ring.
- Rule of thumb: a new card produces about 7 to 10 reviews over its life; 20 new/day gives about 200 reviews/day at steady state. Sources: the 2025
  thread above, https://studycardsai.com/blog/anki-settings-guide (2026, "about 7 per month"). Confidence: opinion (no data shown).
- Time-based daily goals: Anki has none. A 2022 reply names only a timebox notification (Preferences > Scheduling). Add-ons exist: "Time Budget: study
  minutes per day, not new cards per day" (https://ankiweb.net/shared/info/270735584, title only) and "Limit New by Young" (stabilises load by
  young-card count; named in the 2025 thread). Source:
  https://forums.ankiweb.net/t/is-there-any-add-on-that-replaces-the-review-card-limit-with-a-time-limit/21521 (2022). Confidence: single report.
- FSRS Helper bundles Postpone, Advance, Load Balance and Easy Days (https://ankiweb.net/shared/info/759844606, title only). Confidence: single
  report. No source found on adapting new-card intake to learned available time.

### 5. Recall dynamics as a signal

- Desired retention is the recall rate of cards when due; average retrievability over the whole collection is higher (about 94.7 % at 90 %); true
  retention is what the history shows. Source: https://expertium.github.io/Retention.html (undated). Confidence: reported by several.
- A true retention below the desired one is handled in the community by re-optimising parameters (FSRS-6 is more accurate), raising desired retention
  in 1 % steps (one user: setting 94 % for a true 90 %, load barely changed) and checking study habits (pressing Again without relearning; resetting
  leeches to new corrupts the history). Sources: https://forums.ankiweb.net/t/true-retention-is-a-lot-lower-than-desired-retention/64178 (2025),
  https://forums.ankiweb.net/t/anki-retention-rate-not-matching-desired-retention/69356 (2026). Confidence: single report each. Rescheduling after a
  change creates a backlog.
- No source links a true-retention shortfall to shrinking new-card intake or the daily time. The levers named are desired retention, parameters and
  the backlog rule. Confidence: no source found.
- Workload spikes from new cards arrive late; one user calls it treacherous. Sources: the 2026 thread above, manual backlog advice. Confidence: single
  report.

### 6. Measuring time

- Anki caps the recorded time of one answer at "Maximum answer seconds" (default 60), on the assumption that a longer answer means distraction. An
  optional on-screen timer stops at the same cap. The Review Time graph sums per-card time like Review Count. Sources:
  https://docs.ankiweb.net/deck-options.html, https://docs.ankiweb.net/stats.html (current). Confidence: reported by several.
- The Anki docs do not say how the simulator turns reviews into minutes. FSRS cost papers (Ye et al., KDD 2022,
  https://dl.acm.org/doi/epdf/10.1145/3534678.3539081) were not read. Confidence: no source found.

### Implications for the ring rule

- The time is learned from the learner's own work. Apple and Garmin derive goals from past performance, the Anki simulator frames the limit as minutes per
  day (§3 and §4). The ring learns T from closed and open rings (`ring-design.md`, "The rule").
- Due reviews are mandatory work and new cards the filler. It matches the community recipe (review limit high new limit, new cards do not override the
  review limit) and the manual's backlog rule. New cards take what T leaves, and none while due reviews alone fill the ring.
- No source fixes the size or the pace of a step. Apple adjusts weekly, Beeminder locks easing for 7 days, deloads are common practice; the evidence is
  thin, and the step of 15 % and the one change per study day are measured on logs and synthetic learners in `ring-design.md` instead of taken from a source.
- The target is a closure share near 0.8 of study days (`ring-design.md`). Goal-setting theory prescribes goals few reach; Duolingo's data show the highest
  daily goal produced the fewest streaks; the 85 % rule is only an analogy.
- The streak is kept by a minimal action, the first 2 minutes of cards, apart from ring closure. The Duolingo A/B test supports it (+3.3 % Day-14
  retention).
- An open ring lowers T to 0.775 times; a day without study leaves it as it is. One miss is harmless in Lally's data and failing an assigned goal lowers
  later motivation, so an easier next ring is reasonable; the size 0.775 has no source. Easing without delay is acceptable because the system sets the
  goal; Beeminder's lock exists for self-set goals.
- Habits take weeks to months with a spread of 18 to 254 days; the first weeks ask the start of 2.5 minutes, measured in `ring-design.md`, "The first two
  weeks".
- The time measure sums per-card durations, never wall-clock session time (`daily-ring.md`, "Pace"); Anki caps one answer at 60 s, and the logs of Anki
  users in `ring-design.md` use that cap. True retention stays out of the ring time: the retention target is a deck setting that the ring does not move.

## Part 3. How comparable products structure a day

Evidence for the daily flow (sessions, rounds, grades, goals, ring, streak); the conclusions are in `learning-flow.md`. Collected 2026-10-22 from the
companies' own pages where reachable. Tags: [own] company-published data or doc, [doc] product documentation, [report] single user or forum report,
[secondary] summary or opinion, [inference] drawn here from the cited text. "No source found" means the pages read do not say; the feature may exist.
Duolingo's help center is JavaScript-only and could not be read; Quizlet's Learn round length, Apple's monthly challenges and Clozemaster's daily-goal page
were not reachable.

### Duolingo

1. Session unit
   - Unit is the lesson. Until at least 2020 the daily goal counted lessons, and the streak counted consecutive days with a completed lesson. [own] https://blog.duolingo.com/improving-the-streak/
   - After a streak extends, a dedicated screen animates it, with a bigger animation on milestone days; for brand-new learners it raised day-7 retention by 1.7% (relative). [own] https://blog.duolingo.com/how-duolingo-streak-builds-habit/
   - A "quick review" of a gilded (completed) path node counts toward the streak while earning little XP. [own] https://blog.duolingo.com/tips-for-maintaining-streak/
   - Lesson length and end-screen contents beyond the streak screen: no source found.
2. Daily goal
   - Every learner has a daily goal with tiers; "intense" was the top tier in 2019/2020. Who sets it is not stated in the post. [own] https://blog.duolingo.com/improving-the-streak/
   - A PM interview summary says streaks were first tied to XP and that confused users; one lesson a day became the rule. [secondary] https://www.lennysnewsletter.com/p/behind-the-product-duolingo-streaks
   - Current XP tier values and any automatic adaptation of the goal: no source found.
3. Streak rules
   - Keeper: one lesson per day. Goal and streak were separated by A/B test (see item 7). [own] https://blog.duolingo.com/improving-the-streak/
   - Streak Freeze covers one missed day; it must be equipped before the miss; the freeze fills the missing day. [own] https://blog.duolingo.com/protecting-streaks-from-site-issues/
   - Up to two Freezes can be equipped at once. [own] https://blog.duolingo.com/how-duolingo-streak-builds-habit/
   - Streak Challenge: wager gems on a 7, 14 or 30 day streak; Freezes are not allowed in it. [own] https://blog.duolingo.com/tips-for-maintaining-streak/
   - Repair after Duolingo outages is done server-side by freezing the affected day for affected learners. [own] https://blog.duolingo.com/protecting-streaks-from-site-issues/
   - A learner-facing repair purchase and rest-day rules beyond Freezes: no source found.
4. Rewards per horizon
   - Answer: XP exists (leaderboards rank XP gains and illegitimate XP is monitored). [own] https://blog.duolingo.com/duolingo-leagues-leaderboards/
   - Session: streak screen and milestone animation (above).
   - Day: streak extension.
   - Week: leagues restart every Sunday in the learner's time zone; matching by similar study habits and time zone, across all courses; 10 leagues (5 at the 2018 test); top 10 of the Diamond league can enter a three-phase Diamond Tournament in some weeks; opt-out is by making the profile non-public. [own] https://blog.duolingo.com/duolingo-leagues-leaderboards/
   - Week: Friends Quests, weekly shared goals with a randomly paired friend. [own] https://blog.duolingo.com/tips-for-maintaining-streak/
   - Month: no source found.
5. After the daily goal
   - No source describes a push to continue. XP earned beyond the goal feeds the weekly league ranking [inference from the leagues page]. After separating goal from streak, fewer learners reached the goal. [own] https://blog.duolingo.com/improving-the-streak/
6. Backlog and missed days
   - No source found on a due-review queue. The path offers optional quick reviews on gilded nodes (above). A missed day is covered only by a pre-equipped Freeze.
7. Criticism and experiments (company data)
   - Learners at a 7-day streak were 2.4 times as likely to return the next day as learners without a streak (correlation, own data). [own] https://blog.duolingo.com/improving-the-streak/
   - Learners with the "intense" goal were the least likely to hold a streak: almost 40% of those active two days running without a streak had that tier. [own] same page
   - A/B test, goal and streak separated versus combined: day-14 retention +3.3%, daily actives +1%, share of daily learners on a streak +10.5% in 20 days, +19% among new learners (all relative). Fewer learners reached the goal. Duolingo's stated reading: lowering the barrier to a daily habit matters more than volume early on. A year later just over half of daily learners had a 7+ day streak versus about a third. [own] same page
   - Losing a streak can be demotivating; Freezes are justified with a University of Pennsylvania and UCLA study on goal "slack" (https://www.sciencedirect.com/science/article/abs/pii/S0749597818304187). Equipping up to two Freezes raised relative daily actives by 0.38%. [own] https://blog.duolingo.com/how-duolingo-streak-builds-habit/
   - The group PM for retention reports 600+ streak experiments and that the first seven days are the most fragile for retention. [secondary] https://www.lennysnewsletter.com/p/behind-the-product-duolingo-streaks
   - Independent research on streak anxiety: none found.

### Apple Fitness / Activity rings (Watch and iPhone)

1. Session unit
   - The unit is the day; rings reset daily. Workouts are separate and not read here. The iPhone Fitness app shows rings, trends, workouts, awards; an overlapping ring marks a goal exceeded. [doc] https://support.apple.com/guide/iphone/see-your-activity-summary-iph4c34a8a95/ios
   - End-of-day screen and ring-close celebration: no source found.
2. Daily goal
   - The user sets goals on the Watch (Change Goals), can override for today only, or set a different goal per weekday (Schedule). [doc] https://support.apple.com/en-ca/guide/watch/apd29b30023c/watchos
   - Adaptation: every Monday the Watch reports last week and suggests next week's goals from past performance; the user confirms. [doc] same page
3. Streak rules
   - Pause rings: Activity app, tap the rings, Pause Rings, pick a duration or a custom one; up to 90 days without breaking the award streak; Resume Rings or Edit Pause at any time. [doc] same page
   - Introduced with watchOS 11 / iOS 18 per search-result titles (not opened): https://www.macobserver.com/apple-watch/pause-activity-rings-streak/
   - Repair of a broken streak: no source found.
4. Rewards per horizon
   - Day: ring closing and overlap (above). Week: Monday summary and goal suggestion. Awards area in Fitness for longer horizons. [doc] iPhone page above.
   - Monthly challenge details and badge list: no primary source read (secondary titles only: https://www.macworld.com/article/231140/how-to-get-all-of-the-apple-watch-activity-challenge-badges.html).
5. After the daily goal
   - The ring overlaps to show excess; no source read describes a push for more.
6. Backlog and missed days
   - No queue. Apple's wording ties the pause to the award streak, which implies a missed day without a pause breaks it [inference].
7. Criticism and research
   - Apple's own research page covers the hourly stand-reminder nudge (Nazaret and Sapiro, NeurIPS 2022 workshop), not ring closing: https://machinelearning.apple.com/research/large-scale-observational
   - Research or company data on ring-streak anxiety: none found. Opinion on the pause feature exists (macobserver link above) and was not read.

### Anki (with FSRS)

1. Session unit
   - Study the selected deck until the day's new, learning and due cards are exhausted or the limits are hit; no fixed session length. Four buttons (Again, Hard, Good, Easy), each shows its next interval; using only Again and Good is allowed. [doc] https://docs.ankiweb.net/studying.html
   - End: congratulations screen. When the review limit hid cards it says so and suggests raising the limit. [doc] https://docs.ankiweb.net/deck-options.html
   - The new day starts at 4 AM by default so late-night study does not pull in two days of cards. [doc] https://docs.ankiweb.net/preferences.html
2. Daily goal
   - No goal. Two caps per preset: New cards/day and Maximum reviews/day, set by the user. Missing a day does not enlarge the next day's limits. [doc] https://docs.ankiweb.net/deck-options.html
   - Adaptation: none. Workload follows from desired retention, new cards and history (FSRS guidance below).
3. Streak rules
   - No streak in the manual pages read; add-ons not checked.
   - Easy Days: per weekday Minimum, Reduced or Normal; intervals are nudged by a small amount; all days Reduced gives the same workload as all Normal; not retroactive. [doc] https://docs.ankiweb.net/deck-options.html
4. Rewards per horizon: none found in the manual.
5. After the limit
   - Anki stops showing cards for the day. By default the review limit also blocks new cards; an option lets new cards ignore it. [doc] https://docs.ankiweb.net/deck-options.html
6. Backlog and missed days
   - Default order serves the longest-waiting first; the delay is factored into the next interval, so returning after a break needs no restart. Manual: with a backlog, new cards' reviews wait behind it. [doc] https://docs.ankiweb.net/studying.html
   - Manual advice: stop introducing new cards until the backlog is cleared; the review cap protects a return after a week off. [doc] https://docs.ankiweb.net/deck-options.html
   - Sort orders: "Due date, then random" recommended when up to date or with a small backlog; with a large backlog, relative overdueness under SM-2, replaced under FSRS by ascending retrievability. [doc] same page
   - 24.11 release: load balancing picks, within the fuzz range, days with fewer reviews; Easy Days; sorting by retrievability, which simulations showed better for a backlog and "likely to become the default". The note says "descending", the manual "ascending"; direction not verified here. [own] https://newreleases.io/project/github/ankitects/anki/release/24.11
   - FSRS Helper add-on: Postpone, Advance, Schedule a Break, Flatten future due cards, Easy Days, load balancing. [doc] https://github.com/open-spaced-repetition/fsrs4anki-helper/blob/main/README.md
   - FSRS maintainer on a huge backlog (Jan 2024): uncapped reviews are fine if no new cards are introduced; sort by relative overdueness. [report, maintainer] https://github.com/open-spaced-repetition/fsrs4anki/issues/585
7. Criticism
   - "Ease hell": under SM-2, repeated lapses after graduation cut a card's ease; the manual says FSRS does not have the problem and advises (re)learning steps under a day. [doc] https://docs.ankiweb.net/deck-options.html
   - Pile-ups: 20 new cards a day means about 200 reviews a day; more than one user studied hundreds of new cards early and was overwhelmed. [doc] same page
   - Pressing Hard instead of Again after a failed recall breaks FSRS, which reads Hard as a success. [doc] same page

### FSRS guidance (Anki manual, open-spaced-repetition wiki)

- Mandatory work is due reviews; new cards are the only input the learner controls. Each new card adds repeats until intervals grow, so a new-card rate sets the review rate days later. [doc] https://docs.ankiweb.net/deck-options.html
- New cards per day: manual gives about 10 reviews per day per daily new card (20 new, about 200 reviews). The fix for overload is fewer new cards until the review burden falls. Same page.
- Desired retention is the main setting; default 90%; above 90% workload grows fast; above 97% it can overwhelm; the manual suggests asking how many reviews or minutes per day are realistic, then reading the simulator graph. Same page.
- Simulator inputs: days, extra new cards, new/day, max reviews/day, max interval; it uses the real memory states of the cards and the FSRS parameters. A "minimum recommended retention" tool is labelled for versions before 25.07. Same page.
- Parameters are not hand-tuned; the lever is desired retention. FSRS needs 20-30% fewer reviews than SM-2 (wiki wording continues past what was read). [doc] https://github.com/open-spaced-repetition/awesome-fsrs/wiki/ABC-of-FSRS
- Changing retention or parameters can reschedule due dates; default is not to reschedule, so workload stays put. [doc] https://docs.ankiweb.net/deck-options.html
- Backlog: see Anki item 6; tools are sort by retrievability, no new cards, a review cap, Postpone and Schedule a Break.
- Easy Days and load balancing spread future due dates; they do not remove workload. [doc] same page

### Brainscape

1. Session unit
   - Reveal the answer, rate confidence 1-5; the rating sets the next appearance (roughly: 1 a few minutes, 2 ten-plus minutes, 3 a few hours, 4 a few days, 5 weeks to months). [doc] https://brainscape.zendesk.com/hc/en-us/articles/13103043051149-How-Does-Brainscape-s-Spaced-Repetition-Algorithm-Work
   - A checkpoint screen shows Cards Overdue and New Cards Left. [doc] https://brainscape.zendesk.com/hc/en-us/articles/49524433459853-Brainscape-s-New-Algorithm-Customization-Overdue-Cards-Feature
   - Session length rule: no source found.
2. Daily goal
   - No in-app goal found. The Academy gives a planner: target = Time Left (Brainscape's estimate to 100% mastery) divided by days until the test; pad by 20-50%. [own] https://www.brainscape.com/academy/how-much-should-students-study-in-brainscape-each-day/
3. Streak rules
   - Day-streak reminders on mobile (Jan 2026 article): a notification only when the streak is in danger. A "revive your streak" feature is linked, not read. [doc] https://brainscape.zendesk.com/hc/en-us/articles/19832796175757-Study-streaks-reminders-on-the-mobile-app-Reminder-notifications
4. Rewards per horizon: none read.
5. After the goal: no source found.
6. Backlog
   - Cards Overdue (Oct 2026): cards whose recommended interval has passed; free for all, mobile first. Pro users pick an interval profile: Cram, Default, Long-Term Learning (fewer overdue cards), Custom. [doc] https://brainscape.zendesk.com/hc/en-us/articles/49524433459853-Brainscape-s-New-Algorithm-Customization-Overdue-Cards-Feature
7. Criticism: none found.

### Quizlet (Learn mode and spaced repetition)

1. Session unit
   - Learn: the learner picks a goal for the session, question types and grading strictness; the path is personalized by familiarity. Free accounts get a limited number of rounds per set. [doc] https://help.quizlet.com/hc/en-us/articles/360030986971-Studying-with-Learn and https://help.quizlet.com/hc/en-us/articles/40011154960653-Studying-with-Answer-Streaks
   - Round length and end screen: no source found.
   - Flashcards with spaced repetition: review until no more are due; then browsing continues normally. [doc] https://help.quizlet.com/hc/en-us/articles/48324742264077-Studying-with-Spaced-Repetition
2. Daily goal
   - "New cards per day" is a user setting in spaced repetition; a daily reminder at 10 a.m. local time when cards are due. Web only. [doc] same page
3. Streak rules
   - Answer Streak in Learn: starts after five correct first-try answers in a row; switching question type resets it; marking an answer "I was correct" keeps it. [doc] https://help.quizlet.com/hc/en-us/articles/40011154960653-Studying-with-Answer-Streaks
   - Day streak, freezes, repair: no source found.
4. Rewards per horizon: answer level only (the visible streak).
5. After the goal: browsing remains available after the daily review (above).
6. Backlog: no source found. Grades: Repeat (minutes), Hard (soon), Okay (about a day), Easy (four days or more).
7. Criticism: none read (a Reddit thread titled "learn mode changed???" appeared in search, unread).

### Clozemaster

1. Session unit
   - Sentence-by-sentence play; each sentence climbs 0, 25, 50, 75, 100% Mastered with waits of same day, next day, 10 days, 30 days, 180 days; four correct answers over increasing gaps reach 100%; Pro can edit intervals. [doc] https://docs.clozemaster.com/article/37-how-do-i-master-something
2. Daily goal
   - Measured in points; the streak is consecutive days on which the points goal was reached; "Days played" is a separate total. [report] https://forum.clozemaster.com/t/daily-goal-streak-missing/67329 (a poster restating Clozemaster's definition; a December 2025 update moved where it is shown)
   - Adaptation: no source found.
3. Streak rules: as above; freezes and repair: no source found.
4. Rewards per horizon
   - Per answer: (4 points multiple choice, 8 points typed) times (% Mastered divided by 25); half with a hint or an early review; 0 when wrong; Favorites always 2. Whether % Mastered is taken before or after the answer is not stated in the part read. [doc] https://docs.clozemaster.com/article/103-how-do-points-work
   - Early review is allowed and penalized [inference from the halving rule].
   - Week and month rewards: no source found.
5. After the goal: no source found.
6. Backlog: no source found; interval settings page exists (https://docs.clozemaster.com/article/40-how-do-i-change-review-interval-settings), unread.
7. Criticism: an independent review (https://heklin.com/clozemaster-review-the-honest-verdict) and Reddit threads on lost long streaks appeared in search, unread.

### Comparison

| Product | Session unit | Daily goal measure | Streak keeper | After-goal behaviour | Backlog handling |
|---|---|---|---|---|---|
| Duolingo | Lesson | Lessons/XP tier, user-chosen; separate from streak | One lesson; Freeze (max 2 equipped) | XP feeds weekly league; no push found | None found; optional quick review |
| Apple rings | The day (no session) | Ring goals, user-set, per weekday, Monday suggestion | Daily ring closing; award streak survives a pause up to 90 days | Ring overlaps; no push found | None; pause beforehand |
| Anki + FSRS | Open-ended pass over due + new | None; caps on new/day and max reviews/day | None in manual | Stops; congratulations screen | Sort by retrievability, no new cards, cap, Postpone, Easy Days, load balancing |
| Brainscape | Confidence-rated pass; checkpoint screen | None in app; Academy planner | Reminder only; revive feature unread | No source found | Cards Overdue; interval profiles |
| Quizlet | Learn session with goal; rounds; SRS pass until none due | New cards/day (SRS) | Answer Streak (in-session) | Browse freely after daily review | No source found |
| Clozemaster | Sentence play | Points | Days reaching the points goal | No source found | No source found |

### Patterns

- Duolingo, the one product with published tests, split streak from goal: one lesson keeps the streak, the goal is tracked apart; retention and streak share rose, goal completions fell.
- Slack mechanics exist where streaks exist: Freeze (up to two) and pause (up to 90 days). Anki, Quizlet and Clozemaster pages show none.
- Spaced-repetition tools cap the day with user-set numbers (new cards/day, max reviews/day); Anki's manual puts the review cost near 10 reviews per daily new card.
- Backlog is first-class only in the SRS tools (Anki and FSRS: ordering, no new cards, cap, postpone; Brainscape: Cards Overdue); Duolingo and Apple describe none.
- The week layer is social or review-based in the non-SRS products (leagues, friend quests, Monday summary); no SRS page read has one.
- No page read describes a push to continue after the goal; Anki ends the day, Quizlet opens browsing, Apple shows overlap, Duolingo feeds XP into the league.
