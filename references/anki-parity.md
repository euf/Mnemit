# Anki parity for Mnemit

Research note of 2026-10-21 for one user: an adult learning Greek, A1–A2 vocabulary on review, B1 on learning, daily on iPhone and Mac, new cards after every 1–2 lessons from a class notebook via script (`Tools/deck-from-tsv`), two decks, two directions per word, swipe grading on iPhone, arrows on Mac.

Mnemit state: version 0.10.5, commit 763366d, read from code (no GUI was run). The note was started on 6e153ca; the "Today counts" commit d9234d3 and the grade-button restyle 1dad0b2 landed meanwhile and are reflected below. Anki baseline: desktop 26.09.3 (GitHub releases, 2026-09-23), AnkiMobile and AnkiDroid manuals.

## 0. How to read this

- Effort: S = one layer, under a day. M = VocabCore plus one app, with tests, two to four days. L = file-format change or a new subsystem in both apps.
- Value is for the user profile above.
- Source tags `[S#]` point to §6. A claim about Anki without a tag, or marked UNVERIFIED, was not confirmed on a page opened for this note; §6 lists them.
- The Anki manual moved to a Mintlify site (`/manual/<page>`); the `.html` URLs below resolve to it.

## 1. Facts about Mnemit that shape the comparison

1. Limits count per session, not per day. `LearningOptions.cardsPerSession`, `newCardsPerSession`, `newProductionPerSession` (Packages/VocabCore/.../Model/Deck.swift). `StudySession.selectCards` does not know what was introduced earlier today, so "Continue" and every restart take a fresh quota of new cards.
2. Today counts exist since d9234d3. `StudySession.counts(for:at:calendar:)` runs the session's own selection and returns New / Learning / Review, session size and next due date (`StudyCounts`). `DueCardCounter` feeds the Mac toolbar, status bar and summary; iPhone `DeckView` shows three columns and "Study N" or "Done for today"; `StartScreen` rows show a counts line per deck, read from `deck.json` without opening the deck (`KnownDeckCounts`). `Deck.dueCount` still counts every unstudied card and no view uses it for the Study button. The counts expose fact 1: after a session of 30 new cards the deck screen shows 30 new again.
3. Steps are counts, not times. `Steps` and `Scheduler.review`: each Good adds one step, `due = now` while a card is (re)learning, `SessionQueue` brings an Again card back after at least about five other cards. One `steps` value serves learning and relearning.
4. Reviews recorded as `.revealed` gain one third of the stability FSRS adds (ADR 0004, "set, not measured"). That is every iPhone review and every Mac review in the default "Flashcards" mode (`Preferences.studyBy`, `SessionViewModel.makeStudySession`). `FSRSOptimizer` takes only `.typed` reviews as targets (`TrainingItem.items`), so the 400-review threshold counts only reviews typed on the Mac in "Typing" mode.
5. Two directions per word. `Card.note` and `Card.kind`; a production card waits until the recognition card's scheduled interval reaches `productionUnlockDays` (default 7), and unlocked new production cards come oldest learned word first; siblings are left out for the day when one was reviewed today or is already selected; learning cards are never left out (`StudySession.selectCards`, `NoteSelectionTests`).
6. Order inside a session: learning cards, then review cards by lowest recall probability (2 % buckets, random ties), then new cards, then a staged random rotation (`SessionQueue`: blocks of 25, rotation of 10).
7. Intervals are not on the buttons. `GradeReceipt` says what the grade did: the iPhone puts "in 4 days" on the card as it leaves (`DepartingCard`), the Mac shows "Good · in 4 days" with Undo for 3 seconds (`UndoChip`). Forgot is a full-width button; Hard, Good, Easy are three buttons in a row under the caption "Recalled", Good wider, and the button of the grade a swipe is about to give lights up (`GradeChoice`, `CardFlight.highlighted`).
8. iPhone: study, undo, suspend, and a statistics screen with the retention tables only (deck screen, More menu). No browse, card info, practice, resume. Mac: add, edit, list, search, inspector, statistics, options, practice of the session's mistakes.
9. `deck-from-tsv` stamps `Card.created = now` for the cards of each run, so a run is a lesson batch (the first sync gave all existing cards one date).
10. Absent everywhere: tags, flags, bury, leech handling, notifications, widgets, audio files and images, cloze, timebox, heatmap.

## 2. Feature table

| Anki feature | What it does, why learners use it | Mnemit today | Value | Effort |
|---|---|---|---|---|
| Deck list with New / Learn / Due | Desktop shows three numbers per deck for today, AnkiMobile two (due green, new blue), AnkiDroid three (new blue, learning red, review green). The day's workload is visible before opening a deck [S1][S15][S16] | yes since d9234d3. iPhone `StartScreen` rows carry `StudyCountsLine` (New, Learning, Review) read by `KnownDeckCounts`; Mac window per deck with the same counts in the status bar and `Study (N)` = session size. Per-session limits still make the counts jump back after a session (fact 1) | high | done |
| Daily limits | New cards/day, maximum reviews/day, per-deck, "Today only", new cards ignore review limit, limits start from top. Caps the day's load [S2] | partial. Per-session caps in `LearningOptions` (CLAUDE.md says so explicitly); the quota restarts with each session and shows as a full New count again. One `cardsPerSession` covers all cards: due first, new fill the rest, which matches Anki's default of the review limit also limiting new cards | high | S |
| Deck overview screen | Study Now, Custom Study, Options, Unbury, buried count in grey [S1][S5] | partial. iPhone `DeckView`: three count columns, total and suspended line, Study N / Done for today / next review. No buried count, no extra study buttons. Mac has no overview, the card list is the home view | medium | S (buried count, extra buttons) |
| Presets and subdecks | Shared options, one session over several decks [S2] | no. One deck is one file with its own options; no combined session. The two-deck split suits the user | low | M |
| Learning steps, graduating and easy interval | Steps like `1m 10m`; Hard repeats or averages steps. With FSRS the manual advises steps under one day [S2] | partial. `LearningOptions.steps` = number of Goods in the session (1–5), no minutes, FSRS sets the first interval; Hard keeps the step, Easy leaves learning | low | – |
| Relearning steps, minimum interval | Separate steps after a lapse [S2] | partial. Shared `steps`. A separate relearning count is a field in `LearningOptions` and one branch in `Scheduler.review` | low | S |
| FSRS | Free Spaced Repetition Scheduler; FSRS-6 since 25.07, fsrs-rs 6.6.2 in 26.09 [S2][S17] | yes. `FSRS.swift`, 21 parameters (FSRS-6); the optimizer is a port of fsrs-rs 6.6.2, the version Anki 26.09 ships | – | – |
| Desired retention | The main FSRS setting; per deck inside a preset since 25.09; manual advises staying under 97 % [S2][S17] | yes. `targetRecall` 70–97 % slider in `DeckOptionsView`, per deck | – | – |
| Optimizer | Button; needs "a few hundred" reviews; health check; optimize all presets; monthly is enough [S2] | partial. `ParametersSection` computes, compares log loss and RMSE, applies on save. Needs 400 typed reviews, which flashcard and iPhone reviews never supply (fact 4) | high | M |
| Simulator ("Help Me Decide"), compute minimum recommended retention | Workload against retention graph. CMRR: manual says removed as of 25.07; the 25.09 notes remove it from the help modal [S2][S17] | no | medium | L (skip CMRR) |
| Reschedule on change | Optional re-due after FSRS or retention change; not recommended on first switch [S2] | partial. New parameters replay stability and difficulty, due dates stay (`DeckChange.changingLearningOptions`); that equals Anki's default | – | – |
| Load balancer | Within the fuzz range prefers days with fewer reviews (24.11); 26.05 also spreads siblings [S17] | no. Seeded fuzz only (`Scheduler.fuzzed`, py-fsrs ranges) | low–medium | M |
| Easy days | Fewer reviews on chosen weekdays, via interval adjustment [S2] | no | low | M |
| Maximum interval | Cap on intervals [S2] | yes, 30–36500 days | – | – |
| Sibling burying | Separate switches for new, review, interday learning siblings; learning cards are never buried; burying happens when a card is answered [S1][S2] | yes, fixed rule: one card per note per study day, learning never left out, plus the production lock. No switches; the count of left-out cards is not shown | high | S (show count) |
| Suspend, bury, unbury (card or note) | Suspend until resumed; bury until tomorrow, "Unbury" on overview [S1] | partial. Suspend on iPhone and Mac (`Card.isSuspended`, merged by `suspensionChanged`), resume on Mac only. No bury. `SessionCommand.skip` exists internally and is not offered | medium | S (postpone to next session), M (bury today, persisted) |
| Flag and mark | Colour flags 1–7 shown in the session, searchable; "marked" tag; used to look up a card later [S1][S8][S9] | no | medium | M |
| Leeches | Lapse counter; at 8 the note is tagged and the card suspended; threshold and action configurable; warnings at every half threshold [S4] | no. `LearningState.lapses` counts Again in the review phase and `CardInspector` shows it | high | S–M |
| Reset, set due date, reposition | Browser actions [S6] | partial. Reset Learning State on Mac; no set due date, no reposition | low | S |
| New card gather, sort, insertion order | Six gather orders, five sort orders, reposition [S2] | partial. `NewCardOrder`: deck order or newest first by `Card.created`, ties in file order | medium | – |
| New/review mix, review sort order | New mixed, before or after reviews; eight sorts; with FSRS "ascending retrievability" is the one the release notes recommend for a backlog [S2][S17] | partial. Fixed: learning, reviews by lowest recall probability, new last. Equal to Anki's recommended backlog order; no choice | low | S (new-first toggle) |
| Day start, learn-ahead | 4 AM default; learn-ahead 20 min [S3] | partial. 4 AM fixed in `StudyCalendar`; learn-ahead is moot without time-based steps | low | S |
| Answer buttons with next interval | Interval above each button; can be hidden (desktop preference, AnkiMobile "Next Times") [S3][S15] | different. Hidden before the grade, shown after it, on the card as it leaves (iPhone) or in the receipt chip (Mac); the buttons are labelled with the grade name only | – | – |
| Undo | AnkiMobile Undo action, shake by default [S15]; AnkiDroid button and `z` [S16]; desktop reviewer UNVERIFIED | yes. Button in the bar, ⌘Z, Z, Esc, shake, ••• menu (Mac: chip for 3 s); restores the session position (`SessionDriver`) | – | – |
| Keyboard shortcuts | Space/Enter, 1–4, `s` overview, `i` info, `t` stats, `r`/F5 replay, `o` options [S1][S3][S7]; AnkiDroid also `e * - = @ ! z` [S16]; desktop keys for edit, mark, bury, suspend UNVERIFIED | partial. Space/Return, 1–4, arrows, Z/Esc/⌘Z, S speak, ⌘E, ⌘L; no mark, bury, suspend, info keys | low | S |
| Gestures and tap zones | AnkiMobile: 9 tap zones, 4 swipes, any action assignable, vertical swipe must start at the far screen edge. AnkiDroid: 4 swipes, double touch, 4 touch zones [S15][S16] | different. Fixed four-way swipe along the axes, with gaps that keep Forgot away from the yes grades, tint, flick, haptic at commit (`GradeSwipe`, `CardFlight`); tap reveals; nothing configurable | medium | – |
| Auto advance | Timed reveal and answer (23.12+) [S2] | no | low | S–M |
| Timebox | Periodic count of cards studied in N minutes [S3][S16] | no | low | S |
| On-screen timer, answer time | Stats only; no effect on scheduling [S2] | no (session duration only) | low | S |
| Card info, review history | Interval, ease, history; with FSRS stability, difficulty, retrievability; forgetting curve (24.11) [S7][S17] | partial. Mac `CardInspector` (phase, due, stability, difficulty, recall probability, reviews, lapses, last 50 grades) and `CardStateLine` in the Mac session. iPhone none | medium | M (iPhone) |
| Type-in-answer | `{{type:Field}}`, character diff, `nc` and `ci` variants; AnkiMobile can switch typing off [S10][S15] | partial, stronger on Mac. Typing mode: `ResponseChecker` with `/` alternatives, incomplete, almost-correct by length, diff highlight, suggested grade. iPhone none (ADR 0004 rejected it) | medium | – |
| TTS and audio | `{{tts}}` with OS voices, AnkiMobile 2.0.56+, enhanced voices from iOS settings; audio files autoplay by default, replay `r`; TTS autoplay UNVERIFIED [S2][S10][S15] | partial. `GreekSpeech`: best el-GR voice, speaker button, S key, head word only. No autoplay, no recorded audio, no record-own-voice | high | S (autoplay) |
| Images, media, image occlusion | Media in fields; AnkiMobile resizes to 1024 px; occlusion cards [S9][S15] | no. Text only; 24 Wordwall picture pairs stayed out (HANDOFF) | low–medium | L |
| Scratchpad, record own voice | Writing pad; temporary recording to compare pronunciation [S1][S15] | no | low | M |
| Browse and edit | Card/note table, configurable columns, sidebar, saved searches, bulk actions, find and replace, duplicates [S6] | partial. Mac `CardListView`: Question, Answer, Hint, Maturity, Due; status bar with today's counts; sort; accent-insensitive search (`CardSearchIndex`); inspector; edit sheet; bulk suspend, resume, reset, delete; add form. No note, kind, created, lapses columns. iPhone none | medium | S (columns), M (iPhone browse) |
| Search syntax | `is:due`, `is:buried`, `prop:lapses>3`, `added:7`, `introduced:1`, `rated:7:1`, `tag:re:lesson-(1[7-9]\|2[0-5])` [S8] | no. Plain substring over question, answer, hint | medium | M |
| Tags | Several per note, tree, searchable; the manual advises tags over many small decks [S9][S8] | no. `Card.note` is a key shared by siblings, not a label | high | M |
| Note types, templates, cloze, conditional generation | Fields, templates, cloze, cards generated when a field is non-empty [S9][S10] | partial. One fixed card (question, answer, hint) plus `note` and `kind`; no templates, no cloze | low | L |
| Two directions and unlock | "Basic (and reversed card)" or conditional generation; siblings buried; an automatic unlock after the first card matures was not found in the pages opened, add-ons UNVERIFIED [S10][S1] | yes, differentiator. `CardKind`, `productionUnlockDays`, `newProductionPerSession` | high | – |
| Import, update, scripting | Text import maps fields including tags; first-field match updates; GUID column; AnkiMobile URL scheme `addnote` for Shortcuts [S14][S15] | yes. `deck-from-tsv` (key note+kind, in-place edit, adopt, suspend-missing, backups); Mac "Import Cards…" for CSV. No tags column | high | – |
| Filtered decks, custom study | Increase today's limits, review forgotten (Again within N days), review ahead (early-review rescheduling), preview new, study by state or tag; Rebuild, Empty; rescheduling on or off [S5] | partial. Practice: a no-reschedule session over the session's mistakes (`Practice`), Mac summary only. No forgotten-today, study-ahead, limit increase, batch or tag study | high | S–M |
| Statistics graphs | Today, Future Due, Calendar heatmap, Reviews, Card Counts, Review Time, Intervals, Ease, Stability, Difficulty, Retrievability, Hourly, Answer Buttons [S7] | partial, Mac only. Tiles (cards, due now, new, suspended, mean recall probability, reviewed today with % recalled), stacked maturity history by day/week/month, 30-day forecast. No heatmap, answer buttons, time | medium | S–M |
| True retention table | Pass rate by period for young, mature (interval ≥ 21 d) and all; first review of each day per card; Hard/Good/Easy pass, Again fail; under FSRS expected near desired retention; renamed "retention rate" in 25.07.1 [S7][S13][S17] | yes. `TrueRetention` (VocabCore, `Statistics/`) replays each card's log to find the phase and interval of every review; `RetentionTables` in `Shared/Statistics` shows Today, Yesterday, 7, 30 and 365 days by young, mature and total, then by review mode and card kind, next to the target recall; Mac statistics view and iPhone statistics screen. A repeat on the same study day is not counted | – | done |
| Reminders | AnkiMobile: daily notification with the number of reviews waiting. AnkiDroid: notify above n due cards, "requires the widget to be enabled" [S15][S16] | no | medium–high | S–M |
| Widgets | AnkiDroid widget is named only in the notification text; AnkiMobile: none found in the nine manual pages opened, UNVERIFIED | no. Probably blocked by signing: the profile has one App ID and the install script signs with only `application-identifier`, `team-identifier`, `get-task-allow`, `keychain-access-groups` (inference from HANDOFF, not tested) | low | L |
| Sync | AnkiWeb; per-review merge; full-sync prompts for format changes; media sync [S11] | yes by other means. One package in iCloud Drive, `VersionMerger` merges versions and review logs | – | – |
| Backups | Automatic, default every 30 min, daily/weekly/monthly retention, manual `.colpkg` [S12] | partial. `.backups` (10 latest) written only by `deck-from-tsv`; iCloud Drive keeps versions | medium | S |

## 3. UI/UX comparison

### 3.1 Study screen

What Anki does well, from the manuals:
- One-key loop: Space/Enter reveals and answers Good, 1–4 choose a button [S1]. On a phone, tap anywhere reveals, and tap zones or swipes can grade [S15].
- Next times on the buttons with a switch to hide them [S3][S15].
- Flag, mark, bury, suspend, edit, card info, replay audio under one More menu, and a top bar that can be filled with any action [S1][S15].
- Live New / Learning / Review counters in the bottom bar [S15][S16].

What it does badly, with evidence level:
- Settings and discoverability. A teacher of Anki in r/Anki writes that newcomers "run for the hills" at the settings menu and most buttons have no tooltip; the same thread has replies calling it self-explanatory, so this is one opinion among several [S18]. A forum user made a mental map because learning, relearning, steps, intervals and ease confuse newcomers [S19].
- Steps against FSRS. The manual warns that steps of a day or more can make Hard show a longer interval than Good and advises short steps [S2].
- Four equal buttons invite "Hard when I forgot", which the manual says makes all intervals unreasonably high under FSRS [S2].
- AnkiMobile: a vertical swipe must start at the far left or right edge so it does not fight scrolling; the gesture lists of both mobile clients name no diagonal swipe [S15][S16].
- Counters that change as cards re-queue: UNVERIFIED as a complaint.

What Mnemit does differently:
- Bounded session with a visible finish line (`n / N` bar) instead of three live counters.
- Forgot is its own full-width button, Hard/Good/Easy a row under "Recalled"; the swipe maps to the same shape (← Forgot, → Good, ↑ Easy, ↓ Hard) with tint, haptic at the commit distance and a lit button for the grade about to be given.
- Interval is told after the grade, which removes the cue to choose a button by its interval.
- Mac typing mode with a suggested grade; flashcards on both platforms.

Recommendations:
1. iPhone toolbar: add the mistakes counter the Mac header already has (`session.mistakeIDs.count`). S.
2. A small state label on the card: New, Relearning, "Leech · 9 lapses". Mac has `CardStateLine`, iPhone has nothing. S.
3. ••• menu: Postpone to next session (existing `.skip`), Bury today, Flag, Card info; keep Undo and Suspend. S–M.
4. Optional auto-speak when the Greek side appears or when the answer is revealed; the voice code exists in `GreekSpeech`. S.
5. Keep the swipe along all four axes, with the gaps next to Forgot.

### 3.2 Deck overview

Anki: three counts for today, "Study Now", Custom Study on the same screen, buried siblings counted in grey, Unbury, Rebuild and Empty for filtered decks [S1][S5].

Mnemit `DeckView` (since d9234d3): New, Learning, Review as three coloured columns (blue, red, green as in Anki's deck list), a line with total and suspended cards, a large Study button that says "Study 60" or "Done for today", and "Next review" when nothing is due. The numbers come from the session's own selection, so limits and sibling burying are in them. The end-of-session screen offers Continue and Done.

Recommendations:
1. Add "Left out today: n" for cards that are due but buried (Anki shows the buried count in grey [S1]). `StudySession.counts` already derives the set for `nextDue`; expose the number. S.
2. Buttons under Study: "Study more (+N new)", "Practice newest batch", "Practice mistakes of today". Anki keeps its equivalents under Custom Study on this screen [S5]. With per-session limits "Study 60" returns after a session, so "Study more" would be a deliberate act once item 1 of the backlog lands.
3. End-of-session screen on iPhone: add Practice Mistakes, which exists on the Mac (`SessionSummaryView`).

### 3.3 Deck list

Anki: counts beside every deck; the colours need the manual to decode (AnkiDroid defines blue, red, green there) [S16]. Parent and subdeck limits interact in ways the manual spends several paragraphs on [S2].

Mnemit `StartScreen` (since d9234d3): each row shows the deck name and a line `New · Learning · Review`, refreshed at launch, when the app returns to the front and after a deck closes. At launch the app still reopens the last deck (`reopen()`), so with two decks used daily the list sits one back tap away.

Recommendations:
1. Launch on the deck list, or keep auto-open and add a deck switcher to the deck screen. S.
2. A check mark on a row when New, Learning and Review are all 0. S.
3. Start a session straight from the row (trailing button). S.

## 4. Prioritised backlog

Order is by value for this user against effort. "Today counts on deck list and overview" is done (d9234d3) and is not in the list.

1. **Daily new-card limit (S).** Count cards whose first log entry falls on today's study day and subtract it from the new quota in `StudySession.selection`; rename the option to "per day"; the end-of-session button becomes "Study more". Why: with the new counts a finished session shows 30 new cards again, and quitting and restarting or tapping Continue adds another 30 + 30 in one day.
2. **True retention table (done).** `TrueRetention` over `Card.log`: reviews of cards in the review phase on a later study day than the previous review, Hard/Good/Easy pass, Again fail, split by the scheduled interval (≥ 21 days mature, Anki's threshold [S13]), by review mode and by card kind. Why: it is the only feedback on the one-third damping and on the 90 % target, and nearly all of this user's reviews are revealed. Retention far above target means too many reviews; below it means lenient grading.
3. **Leeches (M).** `LearningOptions.leechThreshold` (default 8 as in Anki [S4], nil = off), derived from `LearningState.lapses`; on reaching it suspend through `DeckChange.settingSuspended` (works on iPhone) and mark it; "Leeches" filter and a lapses column on the Mac list; banner on iPhone after the grade. Why: look-alike Greek endings and confusable words are classic interference leeches, and an iPhone-only session has no other way to notice them.
4. **Lesson study without tags first, tags second (S, then M).** Step 1: "Practice newest batch" on both platforms, using `Practice(practicing:)` over cards with the latest `Card.created` (each `deck-from-tsv` run stamps one); `StudyModel` gains a practice start. No format change. Step 2: a `tags` column in the TSV (space-separated, as Anki's import [S14]), `Card.tags` in `DeckFile`, tag filter in the Mac list, "Practice tag". Why: after each 1–2 lessons the user wants to drill that lesson's words without touching the schedule.
5. **Let iPhone reviews feed FSRS (M).** Allow `.revealed` reviews as optimizer targets with a per-deck `stabilityGainShare` (1/3 default), or fit the share from the log (evaluate shares 1/3, 1/2, 2/3, 1 with `FSRSOptimizer.evaluate`). Why: today the optimizer and its 400-review gate cannot see this user's reviews at all. Needs weeks of data; do it after item 2 shows a trend. Tests against fsrs-rs reference values must stay green for typed-only input.
6. **Auto-speak Greek (S).** Setting: speak the question when it appears, or the answer when revealed, using `GreekSpeech`. Why: listening association for every card at no extra taps; Anki autoplays attached audio by default [S2].
7. **Daily reminder with the number due (S–M).** Local notification at a chosen time; schedule it when the app closes a deck, text from tomorrow's planned count (`StudySession.counts`). Why: a daily habit; AnkiMobile has this [S15]. A local notification needs user permission and no entitlement (UNVERIFIED: Apple documentation not opened).
8. **Flag for fixing and postpone (M).** `Card.isFlagged` with a changed-date, following the `isSuspended`/`suspensionChanged` merge pattern (#290); flag and "Postpone to next session" in the iPhone ••• menu; "Flagged" filter and export of flagged note keys on the Mac. Why: the iPhone cannot edit and the source of truth is the vocabulary TSV, so the fix loop needs a list of notes to correct.
9. **iPhone: Practice mistakes and a card info sheet (S–M).** Reuse `Practice` and the `CardInspector` content (state, due, stability, difficulty, lapses, last grades). Why: closes the iPhone gaps in §3.2 and supports leech triage on the phone.
10. **Deck screen follow-ups to the counts (S).** Left-out count, "Study more", launch behaviour and check mark on the deck list (§3.2, §3.3). Why: the counts now answer "how much today"; these answer "why this number" and "what else".

Next tier: backup of `reviews.jsonl` per day (S); study-ahead session (S–M); heatmap and streak from card logs (S–M); iPhone browse with search (M); relearning steps (S); load balancer (M); simulator for retention against workload (L).

Verdicts asked for explicitly:
- Leeches: build, item 3.
- Lesson tags and filtered study of the latest lesson: build in two steps, item 4; the batch proxy covers "latest lesson" today, tags are needed for "lesson N".
- True retention stats: build, item 2, before any change to the FSRS parameters.

Not worth building for this user: compute minimum recommended retention (Anki removed it), cloze and templates (the script produces the cards), image occlusion, widgets (signing), Easy days.

File-format note for items 3, 4, 8: new per-card fields go into `DeckFile` as additive keys. Older app versions drop unknown keys on save (CLAUDE.md, Conventions), so both apps are installed from the same commit before the new fields are written.

Setting to try with no code: `steps` = 1 on the A1–A2 review deck. The Anki manual says repeating a card several times in one day does not help long-term memory much and advises few steps [S2].

## 5. Unverified claims

- Anki desktop reviewer: Undo shortcut and menu (only the Browse-window Undo [S6] and the mobile clients [S15][S16] were read).
- Anki desktop shortcuts for edit, mark, bury, suspend (the list read is AnkiDroid's [S16]).
- Whether Anki autoplays `{{tts}}` fields; only audio files are documented as autoplay [S2].
- AnkiMobile widget (none found in the pages opened); AnkiDroid widget details.
- Any add-on that unlocks a reverse card after the first card matures.
- "Counters change as cards re-queue" as a user complaint.
- Local notifications need no entitlement; widgets blocked by the single-App-ID profile.

## 6. Sources (all opened 2026-10-21)

- [S1] https://docs.ankiweb.net/studying.html
- [S2] https://docs.ankiweb.net/deck-options.html
- [S3] https://docs.ankiweb.net/preferences.html
- [S4] https://docs.ankiweb.net/leeches.html
- [S5] https://docs.ankiweb.net/filtered-decks.html
- [S6] https://docs.ankiweb.net/browsing.html
- [S7] https://docs.ankiweb.net/stats.html
- [S8] https://docs.ankiweb.net/searching.html
- [S9] https://docs.ankiweb.net/editing.html
- [S10] https://docs.ankiweb.net/templates/fields.html and https://docs.ankiweb.net/templates/generation.html
- [S11] https://docs.ankiweb.net/syncing.html
- [S12] https://docs.ankiweb.net/backups.html
- [S13] https://docs.ankiweb.net/getting-started.html (mature = interval of 21 days or more)
- [S14] https://docs.ankiweb.net/importing/text-files.html
- [S15] AnkiMobile manual: https://docs.ankiweb.net/ankimobile/intro, /deck-list, /study-screen, /study-tools, /preferences, /tts, /url-schemes, /syncing, /more
- [S16] AnkiDroid manual: https://docs.ankidroid.org/
- [S17] Anki release notes: https://api.github.com/repos/ankitects/anki/releases (24.11 also via https://newreleases.io/project/github/ankitects/anki/release/24.11); tags 24.11, 25.02, 25.07, 25.07.1, 25.09, 26.05, 26.09
- [S18] https://www.reddit.com/r/Anki/comments/mc556m/why_is_everyone_saying_anki_has/ (read through its `.rss`)
- [S19] https://forums.ankiweb.net/t/deck-options-in-a-mental-map/15757 (read through Tavily extract)
