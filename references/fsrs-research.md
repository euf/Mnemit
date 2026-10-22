# FSRS: grading, FSRS vs SM-2, what other FSRS apps do

Research for Mnemit, 21–22.10.2026. Confidence: **[S]** from the cited source as read,
**[I]** our inference, **[U]** found only in secondary sources, not confirmed.

## 1. Two buttons or four

- FSRS predicts recall slightly better for users who mostly press Again and Good than for
  users who use all four buttons. **[S]** FSRS tutorial in
  [fsrs4anki](https://github.com/open-spaced-repetition/fsrs4anki/blob/main/docs/tutorial.md);
  Expertium (FSRS developer), [Pass/Fail Grading as Default, #120](https://forums.ankiweb.net/t/pass-fail-grading-as-default/34147/120).
- Why: they grade more consistently; inconsistent use of Hard and Easy is what hurts. Expertium
  also notes that FSRS's difficulty (D) was designed with four buttons in mind and in theory
  suits two buttons poorly, "but the data says FSRS works well anyway". **[S]** same thread and
  [Add setting to remove "easy" and "hard" button](https://forums.ankiweb.net/t/add-setting-to-remove-easy-and-hard-button/61787).
- The costliest slip is Hard when the card was forgotten: FSRS reads Hard as "recalled with
  effort" and still grows the interval. **[S]** fsrs4anki tutorial.
- With default FSRS-6 parameters a new card's first intervals are about: Forgot — same day,
  Hard — 1 day, Good — 2 days, Easy — 8 days. Easy on first sight is what moves familiar
  words out of the queue. **[S]** default parameters as computed by `VocabCore`.

**In Mnemit:** four grades; Forgot (red, ←) is set apart from the three "recalled" grades
(greens: ↓ Hard, → Good, ↑ Easy). The swipe sectors leave dead zones between ← and ↑/↓
(`GradeSwipe`, `references/design-spec.md` §4.7), so the costly slip needs a deliberate gesture.

## 2. FSRS vs SM-2

- Benchmark of 10 000 Anki users, ~727 million reviews (time-series split, log loss, RMSE
  (bins), AUC). **[S]** [srs-benchmark](https://github.com/open-spaced-repetition/srs-benchmark).
- FSRS-6 with recency weighting has lower log loss than Anki's SM-2 for 99.6 % of users. The
  author's caveat: SM-2 was not designed to predict recall probability; an interval-to-
  probability converter was added for the comparison, "there is no way to have a truly fair,
  no caveats, comparison". **[S]** Expertium, [Benchmark](https://expertium.github.io/Benchmark.html).
- Anki's manual: FSRS "can help you remember more material in the same amount of time"; long
  learning steps were popular under SM-2 because repeated failures cut a card's ease ("ease
  hell"), which FSRS does not suffer from. **[S]** [Anki manual, Deck options → FSRS](https://docs.ankiweb.net/deck-options.html).
- "20–30 % fewer reviews at the same retention" appears in third-party blogs (studyglen,
  imprimo, kachika, diane.app), attributed to Anki or Expertium. Not found in the FSRS
  repositories or the Anki manual. **[U]**

**In Mnemit:** FSRS-6, with the optimizer (`Compute from Review Log`, from 400 answers).

## 3. awesome-fsrs: what other apps do, against Mnemit

Source: [awesome-fsrs](https://github.com/open-spaced-repetition/awesome-fsrs) (read 22.10.2026),
app entries as their authors describe them. **[S]** for what the list says, **[I]** for fit.

Already in Mnemit (no work):

| Practice | Apps in the list | Mnemit |
|---|---|---|
| Fuzz seeded per review event, so replaying a log on another device gives the same due dates | StudyDaily | `Scheduler.random(forReviewOf:at:)` |
| Implementation checked against reference vectors | CuaderNote, Word2Sentence, Discito | `FSRSTests` (py-fsrs), `OptimizerTests` (fsrs-rs 6.6.2) |
| Lowest recall probability first in a backlog (Anki's "ascending retrievability") | Anki | `StudySession.Urgency.review(recallBucket:)` |
| Separate FSRS state for the production direction | Japanese Learning | recognition and production cards, production unlocked later |
| Sibling burying | Jolito, Anki | `StudySession`, per note |
| `.apkg` import with review history | Avorio, Loudwalk, Discito, Jolito | `AnkiImport`, history replayed |
| Undo, daily new-card limits | Japanese Learning | yes |

Adopt (decided 22.10.2026):

1. **Automatic re-optimization, kept only when it fits better.** Verbamor refits each learner's
   FSRS-6 parameters from their history once there are enough reviews, and keeps the new
   ones only if they fit better. **[I]** A learner who never opens Options would keep default
   parameters forever. Built: `ParameterRefit` (`references/scheduling.md`): fits at 400 and 1,500
   reviews, then every 30 days or 1,000 reviews; kept when the log loss on the newest 20 % of
   the log, which the fit did not train on, is lower at all (as Anki keeps fitted parameters only
   when they beat the current ones; the holdout guards against overfitting).
2. **Anki preset parameters and desired retention on `.apkg` import.** Loudwalk and StudyDaily
   read each Anki deck preset's FSRS parameters and desired retention; Avorio fits parameters
   to the imported log. **[I]** Without this an imported deck is replayed under Mnemit's
   defaults and its due dates shift from what Anki showed. **In Mnemit:** a new deck takes the
   preset most imported cards use (`AnkiImport.learningOptions(applyingTo:)`, 17- and 19-value sets
   extended as Anki does, see `deck-formats-and-sources.md` §1.5); an existing deck keeps its options.

Later, with the reason:

3. **Disperse siblings / load balancing / Easy Days / Postpone / Advance** (Anki's FSRS Helper
   add-on). **[I]** All of them choose a due date from the state of other cards. Mnemit
   recomputes due dates by replaying each card's log when two devices merge, so the chosen
   date would have to be stored in the log first, or the two devices diverge.
4. **Workload estimate for the target recall** (the graph in Anki's manual; fsrs-rs simulator).
   **[I]** Useful when choosing 85 % vs 90 %; needs a simulator port.
5. **Listening mode**, audio first with the text hidden (Japanese Learning). **[I]** Greek TTS
   is already there; a mode on top of it.

Not for Mnemit: AI card generation, spoken answers graded by speech recognition, starter
decks of ready content (Verbamor, BrioVocab), next-interval labels on the buttons (StudyDaily,
Dushed; the owner rejected them on 21.10.2026 as read literally).
