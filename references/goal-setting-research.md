# Goal-setting research for the daily ring

Question: is the proposed ring rule (base = median of minutes worked over the last 7 study days, laps included; +15 % probe after two closed days in a
row, none for a week after a failed probe; 70 % of base after a missed day) supported, and what is better. Research of 2026-10-23.

Confidence labels: measured (data in the source) / reported by several / single report / opinion. "Not read" marks a source whose body was
unavailable: the claim then rests on a search snippet, a title or a secondary summary. Unread primaries: Locke & Latham 2002 (PDF, certificate error),
Lally 2010 (Wiley and PDF, HTTP 403), Singh 2024 (MDPI, 403), Bandura & Schunk 1981, the AnkiWeb add-on pages (JavaScript only). Anki forum threads
were read through the Discourse `.json` endpoint.

## 1. Goal-setting research and the 85 % rule

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

## 2. Habit formation

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

## 3. Adaptive goals in products

- Duolingo: streak required the daily goal; learners with the highest daily-goal tier were the least likely to be on a streak (almost 40 % of those
  active two days in a row without a streak). After decoupling (streak = one lesson, daily goal shown separately) an A/B test gave +3.3 % Day-14
  retention and +19 % of new learners on a streak; fewer learners reached the daily goal. Reaching a 7-day streak made learners 2.4 times as likely to
  return next day. Source: https://blog.duolingo.com/improving-the-streak/ (2020). Confidence: single report (vendor, own experiment, correlation for
  the 2.4 figure).
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

## 4. FSRS and Anki community

- Desired retention is the main FSRS setting; default 90 %; above 90 % workload climbs fast, above 97 % it can overwhelm. Source:
  https://docs.ankiweb.net/deck-options.html (manual, current). Confidence: reported by several.
- The simulator estimates workload in reviews per day or minutes per day from new cards/day, maximum reviews/day, desired retention and the real
  memory states. The manual's own advice: ask how many minutes per day you can realistically spend, then pick the retention whose graph fits. Same
  source. Confidence: reported by several. The time constraint is the manual's framing.
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

## 5. Recall dynamics as a signal

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

## 6. Measuring time

- Anki caps the recorded time of one answer at "Maximum answer seconds" (default 60), on the assumption that a longer answer means distraction. An
  optional on-screen timer stops at the same cap. The Review Time graph sums per-card time like Review Count. Sources:
  https://docs.ankiweb.net/deck-options.html, https://docs.ankiweb.net/stats.html (current). Confidence: reported by several.
- The Anki docs do not say how the simulator turns reviews into minutes. FSRS cost papers (Ye et al., KDD 2022,
  https://dl.acm.org/doi/epdf/10.1145/3534678.3539081) were not read. Confidence: no source found.

## Implications for the ring rule

- KEEP the learned base from observed minutes. Apple and Garmin derive goals from past performance, the Anki simulator frames the limit as minutes per
  day. Change the estimator from round steps to the 7-study-day median, with a floor of 2 minutes. Sources: sections 3 and 4.
- KEEP due reviews as mandatory work and new cards as the filler. It matches the community recipe (review limit high new limit, new cards do not
  override the review limit) and the manual's backlog rule. Set the allowance to 0 while due reviews alone exceed the ring.
- KEEP the weekly cadence and the probe cooldown. Apple adjusts weekly, Beeminder locks easing for 7 days, deloads are common practice; the evidence
  is thin and none of it fixes 15 % or the one-week cooldown, so record the probe outcome and measure those two numbers on EF's logs instead of
  treating them as settled.
- CHANGE the stated target. Goal-setting theory prescribes goals few reach; Duolingo's data show the highest daily goal produced the fewest streaks.
  Aim at a closure rate of roughly 80-90 % of study days (the 85 % rule is only an analogy) and check it by replaying the rule on the review log
  before shipping.
- ADD a streak that a minimal action keeps (one round or any logged minute), separate from ring closure, if the streak now depends on a closed ring.
  The Duolingo A/B test supports it (+3.3 % Day-14 retention).
- KEEP the 70 % after a missed day, with a recovery to base the next day the learner works. One miss is harmless in Lally's data and failing an
  assigned goal lowers later motivation, so an easier next ring is reasonable; the size 70 % has no source. Easing without delay is acceptable because
  the system sets the goal; Beeminder's lock exists for self-set goals.
- ADD a cold start: until 7 study days exist the ring is the floor, and the first probe waits. Habits take weeks to months with a spread of 18 to 254
  days; the number of weeks is a design choice.
- ADD the time measure: sum per-card durations, each capped at about 60 s (Anki's cap), never wall-clock session time. A median over 7 days limits one
  odd day, and does not fix idle time inflating every card. Leave true retention out of the ring time; it belongs to the new-card allowance and to
  desired retention.
