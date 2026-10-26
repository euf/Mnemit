# A new card's first showing: research and verdict

How spaced-repetition systems treat the first exposure of a new card, what FSRS does with the first grade, and what the
learning-science evidence says about asking before showing. Researched 26.10.2026 for the question "why not read a first
Forgot as Don't know and a first Good as Know?". Mnemit's current design is ADR 0006 (an introduction that records nothing);
the verdict at the end weighs it against the alternatives.

## 1. Two schools

| System | First exposure | What is recorded | First grade's effect | Source |
|---|---|---|---|---|
| Anki, SM-2 | The front, then learning steps (default 1m 10m) | The first press is an ordinary graded review | Again restarts the steps, Good moves a step; then a fixed graduating interval | [manual, Learning Steps](https://docs.ankiweb.net/deck-options.html) |
| Anki, FSRS 4.5–6 | The same screen and steps; no free introduction | The first press is graded and picks S0 and D0 | FSRS-5/6 feed later same-day presses through the short-term formula (w17–w19); 4.5 ignored them | [py-fsrs](https://github.com/open-spaced-repetition/py-fsrs/blob/main/fsrs/scheduler.py), [Expertium](https://expertium.github.io/Algorithm.html), [forum](https://forums.ankiweb.net/t/about-fsrs-algorithms-first-rating/50055) |
| Mnemosyne | Shown and graded at once | The initial grade counts as a repetition | Grades 0–1 keep the card in the acquisition phase until a 2+; grades 2–5 start at 1/3/4/7 days | [scheduler source](https://github.com/mnemosyne-proj/mnemosyne/blob/master/mnemosyne/libmnemosyne/schedulers/SM2_mnemosyne.py), [archived help](https://web.archive.org/web/2024/https://mnemosyne-proj.org/help/getting-started.php) |
| SuperMemo 17/18 | The item is memorized; the first repetition comes after a startup interval (~4 days) | Creation is no graded repetition (the FSRS benchmark drops SM-17's first record for this reason) | Every item starts with one default difficulty and one first forgetting curve | [Startup interval](https://supermemo.guru/wiki/Startup_interval), [First forgetting curve](https://supermemo.guru/wiki/First_forgetting_curve), [fsrs-vs-sm17](https://github.com/open-spaced-repetition/fsrs-vs-sm17) |
| WaniKani | A lesson presents the item, a lesson quiz follows | Finishing the lesson makes it Apprentice 1 | The first review comes 4 h later; the quiz result is not an SRS input (inferred) | [SRS stages](https://knowledge.wanikani.com/wanikani/srs-stages/) |
| Duolingo | The lesson repeats the words until a short-term model calls them learned | Words enter the long-term model only after the lesson | Half-life regression starts after the lesson | [Settles & Meeder 2016, §2](https://research.duolingo.com/papers/settles.acl16.pdf) |

Mnemit's introduction sits between them: it presents first, as SuperMemo, WaniKani and Duolingo do, and asks the first
graded question minutes later in the same stream, as Anki's learning step does.

Anki's forum regulars advise grading a never-seen foreign word Again on its first showing, and not changing that habit
for FSRS ([thread](https://forums.ankiweb.net/t/question-about-handling-new-cards/45436)). A user who never pressed Again or
Hard on new cards got fitted S0 of 0.01 d (Again) and 70 d (Easy): first ratings without failures leave the fit without data
([thread](https://forums.ankiweb.net/t/fsrs-button-strategy-for-new-cards-good-or-again/57340)). Anki has no built-in
ungraded introduction; the add-on "Batch Learning" cycles through new cards before grading
([listing](https://ankiweb.net/shared/info/1163408394)).

## 2. What FSRS does with the first grade

The first grade of a new card is no lapse (Mnemit counts a lapse only in the review phase, `Scheduler`); it sets the initial
stability S0 and difficulty D0. FSRS-6 defaults (`FSRS.swift`; EF's decks use them until the refit at 400 reviews):

| First grade | S0, days | D0 |
|---|---|---|
| Again | 0.21 | 6.41 |
| Hard | 1.29 | 5.11 |
| Good | 2.31 | 2.11 |
| Easy | 8.30 | 1.00 |

After it, Good leaves difficulty unchanged (ΔD = −w6·(G−3)), mean reversion is w7 = 0.001 per review, and each success grows
stability in proportion to (11 − D). The defaults were fitted on Anki collections, where a word unknown at first sight is
graded Again (inferred from the advice above): D0 = 6.41 for Again encodes "not in memory at first sight", and a per-deck
refit adjusts it.

One unseen word, learned in one exposure, on two paths:

| Path | First graded event | State after | Next review |
|---|---|---|---|
| Anki-native: asked cold, Again, then Good a minute later | Again (S0 0.21 d), then a same-day Good: S = 0.21·e^(w17·(0+w18))·0.21^(−w19) ≈ 0.25 d | S ≈ 0.25 d, D 6.41 | tomorrow |
| Mnemit introduction: shown, then Good a few cards later | Good as the first grade | S 2.31 d, D 2.11 | in about 2 days |

S0(Good) = 2.31 d was fitted on cold first reviews a learner recalled, mostly words known before. Applied to a word seen
minutes ago, it likely sets the first interval too long until the deck's refit learns the introduced deck's own S0
(inferred; to measure on B1's first reviews after introductions: their recall against the predicted 90 %).

## 3. Learning science: asking before showing

- Kornell, Hays & Bjork (2009): guessing before feedback beat reading for weakly related pairs, and the gain held at 24 h
  (via the review in [Journal of Cognition](https://journalofcognition.org/articles/10.5334/joc.455)).
- Grimaldi & Karpicke (2012): guessing helped only semantically related pairs, not unrelated ones; a delay between guess
  and feedback removed the gain ([Memory & Cognition](https://link.springer.com/article/10.3758/s13421-011-0174-0)).
- Seabrooke et al. (2020): for unrelated pairs, no gain in cued recall, a gain in recognition
  ([Psychonomic Bulletin & Review](https://link.springer.com/article/10.3758/s13423-020-01810-y)).
- Potts & Shanks (2014), the one direct test on novel words (Basque for non-speakers, 0.2 % correct guesses): generating
  beat reading (d = .28) on an immediate multiple-choice test; recall and delays untested; learners judged generating the
  weaker method ([UCL](https://discovery.ucl.ac.uk/id/eprint/1399515/)).
- Memory & Cognition 2025 (abstract): pretest, post-test and copy-test-copy all beat errorless copying and did not differ
  from each other ([link](https://link.springer.com/article/10.3758/s13421-025-01813-x)).
- No meta-analysis yet (a PROSPERO protocol, CRD420251172591).

For a foreign word the learner cannot know, asking first and showing first come out about even; the gains of pretesting
need related pairs, recognition tests or immediate feedback.

## 4. Verdict

The choice between a cold first question and a first introduction does not change how well the word is learned (§3). It
changes two things: how the first contact feels, and whether the first grade means what FSRS's parameters assume (§2).

- **Asked cold, the first Forgot shown as "Don't know"** (neutral colour, same Again underneath): FSRS gets exactly the data
  its defaults were fitted on, every deck works the same, per card, without a deck setting or an extra showing. The red
  "Forgot" on first contact, the reason for ADR 0006, goes with the label.
- **Introduction, no record** (ADR 0006, current): no failure on first contact; the first grade becomes a short-term recall
  that the default S0 overrates until the deck's refit; one extra showing per word; a deck setting.
- **Introduction recorded as Again**: keeps the answer-first showing and gives FSRS the Anki-native data (§2's first path),
  at the cost of a grade the learner didn't press, justified only by the deck's mark New words.

Recommended: the first option, for every deck. Not built yet; the decision is EF's (26.10).

Not confirmed: whether WaniKani's lesson quiz is formally outside the SRS, SuperMemo 18's startup rules beyond the guru
pages, Anki's shipped FSRS-6 S0 values (the table uses py-fsrs's), RemNote, Mochi, Quizlet and Lingvist; Kornell et al.
2009 read through a review only.
