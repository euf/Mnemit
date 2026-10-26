# Leeches: how tools treat them, what helps (research, 2026-10-27)
V = [verified: read on the page]. S = [secondary: blog/forum/memory]. Anki manual source: github.com/ankitects/anki-manual (src/leeches.md); code: github.com/ankitects/anki (rslib).

## 1. Anki and FSRS
- Counter: each Again on a review-mode card adds one lapse. Default threshold 8, editable in deck options (Lapses). At the threshold the note gets tag `leech` and a pop-up appears ("Card was a leech"). V docs.ankiweb.net/leeches.html; rslib/src/scheduler/states/review.rs; ftl/core/studying.ftl
- Repeat warnings: at the threshold and every ceil(T/2) lapses after it (8, 12, 16 ...). V review.rs `leech_threshold_met`; manual
- Actions: Tag Only (tag + pop-up) or Suspend Card (also hides the card until unsuspended by hand). V ftl/core/deck-config.ftl
- Default action: the manual says Anki suspends; main-branch code defaults to Tag Only (rslib deckconfig/mod.rs, schema11.rs). Which release changed it was not found. V both
- The tag sits on the note (siblings carry it); suspend hits the card only. V rslib scheduler/answering/mod.rs. No leech-specific view in the manual: use `tag:leech` or `prop:lapses>3`. V searching.md
- Manual advice, three ways: Edit (reformulate, add a mnemonic, add cards for related ideas, 20 rules); Delete (if unimportant, or leave suspended as reference); Wait (interference such as disappoint/disappear: suspend one until the other is solid). V leeches.md
- Bjornstad's six steps (basis of the manual and of RemNote's page): obvious flaw, add context or a card that tells the confusable pair apart ("all three cards may become easy"), right question, delete if non-critical, wait, mnemonic. Unchanged return re-flags after 4 more lapses. V controlaltbackspace.org/leech
- Weak spots of the lapse count (users): lapses never decay, so an old mature card reaches 8 eventually; users press Hard instead of Again to dodge the flag. S forums.ankiweb.net/t/39707. FSRS maintainer L.M.Sherlock uses threshold 4. S forums.ankiweb.net/t/26591
- FSRS does not change the check: it counts lapses only and never reads stability, difficulty or retrievability. V review.rs
- Difficulty is no leech signal: relative, capped at 100% (many cards sit there), while lapses have no cap. L.M.Sherlock, Feb 2024. S forums.ankiweb.net/t/40740
- Arithmetic, no source: at desired retention 90% an average card lapses once in ten reviews, so a fixed lapse count flags long-lived cards sooner than short-lived ones.
- Proposed FSRS detector (Expertium, Mar 2025): a leech is a card failed more often than FSRS predicted. Take each review's predicted R, compute the Poisson-binomial probability of this few successes, flag below ~1% (2-3 reviews can suffice). Two thresholds (flag low, unflag higher) stop flip-flopping. Needs R at each past review; ignores same-day reviews. Prototype outside Anki: github.com/rbrownwsws/leechkit (tag `maybe-leech`, red flag). V thread read (forums.ankiweb.net/t/56887, via .json)
- Status: not in Anki; a participant wrote in Apr 2025 that nobody was working on it. Critique: it misses time sinks whose stability grows slowly but is predicted well (68 reviews, stability 30 d, p 0.21-0.44). Other ideas: lapse-to-review ratio (t/40851), expiring lapses ("Forgiving Leech" add-on, t/39707). V/S
- Net: lapse count is still what ships; the FSRS detector is a forum proposal.

## 2. SuperMemo
- A leech is an ill-formulated item, defined by user criteria: lapses at or above a limit AND interval below a limit (example: 5+ lapses, interval up to 60 days). Once an item is remembered past some interval it stops being a leech regardless of lapses. "Semi-leech" = one lapse away. V super-memory.com/help/leech.htm
- Options: None; Wizard (recommended); Auto-forget (item goes to the end of the pending queue); Auto-postpone (reset parameters, schedule after a long break; warned it can loop forever). V same page
- Leech Alert wizard buttons: Continue, Show answer (default), Postpone, Edit, Forget, Dismiss, Delete, Reschedule, Lapses graph. For less important leeches, order of effort: delete/dismiss, forget, postpone, reschedule. Edit is "most efficient" but needs experience. Warning that Esc becomes a habit. V
- Wozniak: leeches mostly come from breaking the 20 rules. Rule 11 "Combat interference": interference is "probably the single greatest cause of forgetting" in an experienced user's collection; it cannot be foreseen, so detect and eliminate. Tools: minimum information, examples, context cues, vivid or personal imagery. V super-memory.com/articles/20rules.htm (his experience, not a trial)
- Break claim: 50-100 days off may clear a Nigeria/Niger confusion; no study cited. Leeches can be exported to a phone for a leech-only session. V

## 3. Consumer apps (what the learner sees)
- Duolingo: Practice tab, "Mistakes" session reviews earlier mistakes; free for all since Feb 2026. No leech concept or removal on the pages read; in-lesson re-asking not checked. V blog.duolingo.com/guide-to-duolingo-practice-hub
- Memrise: "Difficult Words" mode, words missed one or more times; a lightning-bolt mark can be set or removed in any session; separate practice session. "Mark as known" stops an item appearing. V memrisebeta.zendesk.com (article 4629328871953); S FAQ snippet
- WaniKani: no official leech concept; Recent Mistakes widget and Extra Study cover 24 h only. Community: Item Inspector score = incorrect / max(streak, 0.5)^1.5; Leech Trainer quizzes 10 leeches, each 3 times, with look-alike kanji, retired after 3 right. Items are never removed. S wanilog.com/guides/wanikani-leeches; V forum thread 36978
- Bunpro: a miss creates a "ghost" review, same sentence back in 4 h; forum says 4 right in a row clear it; setting "Minimal" ghosts only after two misses. "Troubled grammar" list in profile; learner may drop a point from the queue. V community.bunpro.jp FAQ 876; S threads 54932, 104805
- Clozemaster: any wrong answer sets a sentence to 0% mastered (ladder 1/10/30/180 days). No leech concept in the FAQ. V clozemaster.com/faq
- Quizlet: Progress (Plus) groups terms Not studied / Still learning / Mastered; learner can star "Still learning" and drill only those; Learn can make you retype missed answers. V help.quizlet.com 360048803491, 360030986971
- RemNote: warning after 4 relearn-forget events (editable), interrupts the queue with Disable / Ignore / Edit Later. Page claims the hardest 5-10% of cards take 50% of study time, no data given. V help.remnote.com article 7183408
- Mochi: no leech feature in the docs index or five review pages read; binary Remembered/Forgot, optional FSRS. V (negative) mochi.cards/docs

## 4. Learning science
- Cause, interference: related words learned together are learned slower than unrelated ones (Tinkham 1993; Waring 1997 replication, Japanese learners). V academia.edu copy of Waring 1997. It concerns first learning, not repair.
- Retrieval itself can suppress related items: practising some category members impaired unpracticed relatives on a delayed test (Anderson, Bjork & Bjork 1994). V abstract (doi 10.1037/0278-7393.20.5.1063). Inference: drilling one half of a confusable pair may hurt the other.
- Cause, poor encoding: missing prerequisite (halbkugelig/Kugel), oversized card. S Bjornstad; V Wozniak.
- Answer after an error: correct answer after a wrong response raised 1-week retention by 494% (Luganda-English pairs); feedback after right answers changed little. V Pashler et al. 2005, doi 10.1037/0278-7393.31.1.3
- Retrieval with feedback: testing vs restudy g = 0.50 overall; studies with feedback g = 0.73, without g = 0.39. V Rowland 2014 PDF read (doi 10.1037/a0037559)
- A failed guess before the answer still beats read-only study (Kornell, Hays & Bjork 2009); confident errors are the most likely to be corrected by feedback (Butterfield & Metcalfe 2001). V abstracts
- Keyword mnemonic: 72% vs 46% correct, Russian vocabulary (Atkinson & Raugh 1975). V doi 10.1037/0278-7393.1.2.126. Dunlosky et al. 2013 rate it low utility: slow to build, benefit vanished on delayed-only tests, no better than practice testing in one head-to-head; promising for keyword-friendly words. V PDF read
- Same review: practice testing and distributed practice high utility; elaborative interrogation and self-explanation moderate. V
- Side-by-side contrast: mixing confusable categories improves discrimination; spacing that breaks the juxtaposition hurts (Birnbaum et al. 2013, birds and butterflies). V abstract. For word pairs this is inference; no test found comparing side-by-side repair with waiting.
- Relearning: practise to 3 correct recalls, then relearn 3 times at wide spacing; relearning cost little extra practice (533 students, concepts, not vocabulary). V Rawson & Dunlosky 2011, doi 10.1037/a0023956
- Gaps: no controlled study found of delete, wait or break as leech remedies (claims above are practitioners'; the "300%" for dropping the hardest 10% is a SuperMemo theory-page figure, which Bjornstad says may not transfer); none comparing lapse-threshold detectors by outcome.

## 5. Comparison
| Tool | Signal | Threshold | Action | What the learner sees |
|---|---|---|---|---|
| Anki | review lapses | 8 (editable); warns again every 4 | Tag Only (code default) or Suspend | pop-up "Card was a leech", tag `leech`; suspended card leaves the queue |
| SuperMemo | lapses and interval; optional semi-leech | user-set (example 5 lapses, <=60 d) | None / Wizard / Auto-forget / Auto-postpone | Leech Alert dialog with Edit, Postpone, Forget, Delete; auto modes act without asking |
| RemNote | relearn-forget count | 4 (editable) | learner picks: Disable, Ignore, Edit Later | queue interrupted by a warning with three buttons |
| Memrise | any miss | 1 | none; item stays, mark with lightning bolt | "Difficult Words" mode to practise them |

## Options for a vocabulary app (no recommendation)
Signal choices: lapse count (A-C below; no FSRS history needed); lapses plus interval (SuperMemo; spares mature cards that slip once); FSRS probability (experimental; needs R at every past review).
- A. Anki-shaped. Lapse counter, default 8 and editable, repeat at +ceil(T/2); action Tag Only or Suspend; `leech` tag; a Leeches filter; pop-up. (b) every expectation met. (a) Tag Only keeps the card in rotation; with Suspend the pop-up and a visible list are the only trace, so it can vanish unless that list is surfaced. Cost: cumulative-lapse flaw above.
- B. Stays, with help. Same counter and tag; the item stays in rotation and gets support: answer plus example sentence right after a miss, a pair card for its confusable item, a mnemonic note field, a prompt Edit / Pause / Keep. Evidence: strongest for feedback and retrieval; contrast is inference; mnemonics help short-term. (a) nothing vanishes. (b) threshold, tag and filter present; Suspend is one more choice in the prompt.
- C. Park with a return date. SuperMemo Postpone/Forget analogue: flagged item leaves the queue for N days or until its confusable partner is learned, sits in a "Parked" list with a return date and one-tap return, and the app says so when it happens. (a) visible and reversible. (b) works like Suspend with auto-unsuspend. Risk: SuperMemo warns that auto-postpone can loop forever; no study shows breaks cure interference.
