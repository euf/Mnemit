# HANDOFF — Mnemit

## State

- Version 5.5 on `main`; the iPhone runs 5.5.0 (838a7ce), signed until 30.10. The day's model (one ring, the
  stack, partial credit, the streak step, two rests, medals, the Progress screen) is
  `references/learning-flow.md`; the ring's size (seconds, a tracker of the closed rings) is
  `references/daily-ring.md`; why the ring is what it is, every alternative measured on synthetic learners
  and the logs of 2,000 Anki users: `references/ring-design.md`; why the rest:
  `references/learning-flow-research.md`, `goal-setting-research.md`, `speech-stutter-research.md`. Terms: `GLOSSARY.md`, section "Mnemit" (a card is never a review).
  Screens: `references/flows.md`, `references/screens.md`. Brief sub-agents by
  `references/agent-lessons-rings.md` and `agent-token-costs.md`.
- Speech: words are rendered ahead and played from memory (`GreekSpeech`, `SpeechLog` writes
  `Library/Caches/speech.log`, read off the iPhone with `devicectl device copy from`); EF heard no stutter.
- Strings in en, de, ru, el; `Tools/check-localizations.swift` requires all four.
- Mac: `~/Applications/Mnemit.app`, `com.euf.mnemit`, installed by `Scripts/install-mac.sh`.
- iPhone 13 mini (UDID `00008110-000411010C68401E`): Mnemit `com.euf.mnemit.ios` with the widget
  `com.euf.mnemit.ios.widget`, installed by `~/dotfiles/ios-renew --force` (see "iPhone signing").
  On the iPhone EF studies, edits cards and decks, and adds words after a lesson.
- Decks in `iCloud Drive/Mnemit/`, both built by `Tools/deck-from-tsv` from the dictionary
  `~/Documents/greek-lessons/vocab/` (`merge.py` → `greek-vocab.tsv`, `cards.py` → `cards-*.tsv`):
  - `Greek A1–A2.mnemit`, review of the familiar: 1629 words, 3258 cards (recognition and translation
    into Greek), 30 + 30 new per day, production not locked, deck order.
  - `Greek B1.mnemit`, learning: 1118 words, 2236 cards, 20 new recognition + 7 production per day,
    production unlocks after 21 days, new cards newest first. 78 old cards of the first deck are
    frozen (their words went to A1–A2), 131 adopted with their progress.
  A recognition question is the Greek form; the answer is Russian · English and an example. A
  translation question is Russian, the hint the part of speech and English, the answer the Greek form
  and an example. There is never Greek in a hint. Copies before every write:
  `iCloud Drive/Mnemit/.backups`.
- Deck format: the `.mnemit` package (type `com.euf.mnemit.deck`). `.voctrain` decks open, are listed
  in the folder and are saved in place under their own name; the apps rename nothing, and a deck is
  renamed by hand in iCloud Drive.
- Sync: one package file in iCloud Drive, both apps open it in place. Upstream's `VersionMerger` merges
  conflicting versions. No CloudKit and no iCloud entitlement needed.

## iPhone signing

Free Personal Team `2NS3PB4YC9` (Apple ID in Xcode → Settings → Accounts); build and install by
`~/dotfiles/ios-renew` from its line in `~/.config/ios-renew/apps`:
`/Users/eugene/Code/Mnemit MacVocTrainNg.xcodeproj VocTrain VocTrain/Mnemit.entitlements`.
The script builds `main` from its own worktree, Xcode issues 7-day profiles to the app and the widget,
and launchd `com.eugene.ios-renew` renews them every night. App and widget share one entitlements file
with `keychain-access-groups = $(AppIdentifierPrefix)com.euf.mnemit.shared`: through that keychain item
the app hands the widget the day's snapshot. The free team has no iCloud container and no Push, so the
deck folder is chosen in the file picker. Team limits: 3 apps per device (now FicTypeApp and Mnemit),
10 App IDs a week.

## Open

In order of importance to EF. Brief sub-agents by `references/agent-token-costs.md` and
`references/agent-lessons-rings.md`.

1. **Progress must not depend on the decks in the list.** The ring, the streak and the medals are worked
   out from the logs of the active decks: deleting or pausing a deck, or deleting a card, rewrites past
   days. Plan: a progress ledger in the deck folder, one line per study day (done, goal, kept, closed),
   frozen at the day's change, merged by day across devices, filled from the logs on first run; past days
   read from it, today from the logs.
2. **Share Deck**: a clean `.mnemit` copy (cards and media, no states, no log, no fitted parameters) from
   the deck's menu on both apps; sending the package today sends one's history.
3. **How Today Works → "Under the Hood"**: a short "Today" section in plain words on top, the tables folded.
4. **From the reviews of three personas (23.10: Anki veteran, newcomer, no-decks learner)**: a new
   word's first showing as an introduction, not a red Forgot; an empty Today whose first button is "Add
   Words" and makes a deck; FSRS figures (RMSE, log loss) for Anki users; Anki import fidelity (cloze,
   several media per side) and an export back with history.
5. **Decisions to revisit by evidence** (`references/decisions-evidence.md`, 23.10: ten checked; medals
   changed in 5.3.6 after Deci, Koestner & Ryan 1999, the next medal shows no progress count; four to
   measure on EF's own log):
   - The day's time (§2): settled by measurement (`references/ring-design.md`). At 60 study days count the
     closed rings in the Progress calendar: a share outside 0.7-0.85 reopens it.
   - Rests (§4): Forgot rate and `ms` by minute in streams of 15+ minutes against 1 - R; add a skippable
     rest at the minute where either climbs.
   - Backlog order (§5): ascending against descending retrievability in the open-spaced-repetition
     sort-order simulator with EF's fitted parameters, at the first backlog over 100 cards.
   - Production cards (§6): the Forgot share of the first two production reviews; over 25 % lifts the
     7-day gate to 14, at or below 10 % under a gate of 14 or more lowers it; wait for 100 reviews.
6. **Rewrite the git history in English.** Only the fork's commits (`git log --author=euf`, 112 with
   Russian messages); upstream's stay. `git-filter-repo` with a commit callback mapping hash → message;
   a fresh clone as a reserve; `git push --force-with-lease origin main`; then fix the hash in State. Do it
   when no agent branches exist (`git branch | grep worktree-agent` empty).
7. **The Mac suite on `main` hasn't been run** (the tests open windows; `~/.claude/ui-blocked` was up).
   Known failures when the test app isn't in front: `CardListViewTests.firstClickIntoTableSelectsRow` and
   `focusedTableHandsFocusToNewTableWhenSorted`.
8. **Known behaviour, decide on complaint:** after "Done for today" in all decks, Keep Going runs on the
   deck of the last card; pace starts from defaults until 20 timed reviews; xcodebuild 27.1 sometimes hangs
   after the iOS summary (the summary is right); the Mac Learning Options sheet overwrites a fit that
   arrived while it was open; the iPhone 17 Pro simulator is often the FicTypeApp session's, use another.
9. **Dictionary**: `merge.py` now merges `ο/η` with `ο`/`η` like `WordKey`; the decks still hold the
   duplicate cards of 11 words, which `deck-from-tsv --suspend-missing` would park.
10. Later: examples from Tatoeba; FSRS-7 once it ships in fsrs-rs; sibling spread and load balancing
   (store the chosen date in the log first); hiding siblings across decks once pairs exceed 1 %
   (`references/cross-deck-overlap.md`); a listening mode.

## In progress (23.10, session "Дизайн логики кольца")

Decided with EF, measured in `Tools/ring-sim/cards.py` (2,000 Anki users, `--real ~/Library/Caches/anki-revlogs-10k`),
not yet in the app:

1. **Size rule: Levitt's transformed staircase instead of the tracker.** Two closed rings in a row (that filled the time)
   → T × 1.15; an open ring → T × 0.775 and the run restarts; a ring closed on a smaller plan doesn't count (hold). It
   converges to √(ln(1/0.775) / (ln 1.15 + ln(1/0.775))) = 0.804 closed rings. Against the tracker (×1.075 / ×0.775, 0.779):
   the ring changes size on half as many days (50 % against 90 %), closure +1.5-2 points, perfect first week +1.5 (a
   5-minute newcomer +10: 0.375 against 0.275), words −4 % for a learner who stops at the ring, equal for one who goes on;
   same miss depth and open runs. Code: `DailyGoal.nextTime(after:)` reads the run of closed filled days; tests in
   `RingRuleTests`; docs `daily-ring.md`, `learning-flow.md`, `ring-design.md`, `GLOSSARY.md`, How Today Works footer.
2. **Replace "+10 new" with "Go on".** FSRS (the plan) decides: after the ring, Catch Up while the plan has due cards,
   then more of the day's stream; flows: 0 → streak kept → ring closed → Catch Up → stack empty, or 0 → streak kept →
   ring closed → stack empty. Open question to settle before coding: what "Go on" serves once the plan is empty (FSRS has
   nothing due; only new cards remain, sized by whom). Rethink the user flow and a newcomer's first week with a new deck.
3. **Plain-language texts** (EF asked "по-человечески"; draft, not yet approved): the ring is "the cards due so you don't
   forget them, as many as fit your usual time; if time is left, new words fill it"; two modes of Catch Up: a rare day
   (7-10 % of study days, 5-30 cards: "more than usual is due today: 12 more cards wait in Catch Up") and a lasting
   backlog (veterans, hundreds of cards: "480 cards have piled up; the ring takes the most forgotten first; at this pace
   about 3 weeks"). Russian Catch Up is «Наверстать» (done, 406fb7f).
4. **Show the ring's size as progress** on the Progress screen ("Your ring: 12 min a day. You started at 2.5"): the
   closure share is fixed by any adaptive rule, the size is what differs between people.
5. **Forecast** in How Today Works: what the current intake of new words costs in a month and a year (as Anki's
   simulator and Noos do).

Measured and rejected (write into `ring-design.md` "The alternatives"): Anki's load balancer (fuzz + weights from
`load_balancer.rs`: no-new days 9.8 → 8.7 %, nothing else moves; the time cap already cuts peaks); one new card a day
first in the queue (only correlational evidence: real logs, days without new cards are followed by a 7+ day gap 5.2 %
against 3.0 %; patch kept at the session's scratchpad `one-new-card-first.patch`); intake smoothing (1.25-2× the recent
average: Catch Up −1.5 points, words −5…−16 %); a "kept up with FSRS" counter (depends on retention and intake, punishes
learners who add more); PEST steps (words +9-17 %, perfect first week 0.69 against 0.83); a QUEST-like Bayesian rule
(first week 0.14, oversized rings for eager learners); the FSRS queue + N new by recent rings (closure 0.66-0.75, first
week ≤ 0.44, a veteran's first ring 543 min); staircases of 3-7 rings (closure ↑, words −17…−67 %). `cards.py --noos`
reproduces Noos's FSRS simulator within 0-4 % at retention 80-90 %.
