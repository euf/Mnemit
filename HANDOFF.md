# HANDOFF — Mnemit

## State

- Version 11.0 on `main` (`VERSION`): the audit of 10.1.2 and its fixes, `references/audit-2026-10-30.md` (what was found,
  what changed, the decisions with their rollback, what stays open). Deck format 7 (a review taken back is a note
  `"undone":true`); the memory model is fitted on the reviews of all decks together; "Keep Going" is the moment after the
  ring; option menus instead of steppers; dark-mode text in a lighter accent.
- The product model of `references/product-model.md` (9.0). Past days are written down
  when they end (the progress ledger, `<deck folder>/.mnemit-progress/<device>.jsonl`, one record per day, merged by day,
  raised only by late answers), so pausing or deleting a deck or a card never changes a past day. A deleted card keeps its
  answers as a retired card (deck format version 6). A deck edited while open (the other device, `deck-from-tsv`, which now
  writes through `NSFileCoordinator`) changes in place, and an undo of a grade survives the reread on both apps. A leech
  (8 lapses, again every half threshold) stops on "Keeps slipping" with Edit, Set Aside or Keep It and Continue; the deck
  chooses Keep Card (default) or Suspend Card; a Leeches filter; the Mac's card table has Lapses, Stability, Difficulty and Recall.
  Every card has two answer buttons, Forgot and Good (Don't know and Know on a first showing); what can be given is what the
  screen shows (a swipe up or down springs back, 2 and 4 do nothing); the setting "Hard and Easy Buttons" adds Hard and
  Easy as buttons, swipes and keys together. The greens rise in chroma from Hard (sage) to
  Easy (vivid jade). Today is one card in the screens' grammar (Fitness Summary through the iOS 26 rules, `hig-ios26.md`):
  the ring on the left, Day streak, the next moment with ≈ minutes and Words learned on the right, the week under them, the
  date as the subtitle; Progress, a deck and Statistics use the same cards and tiles. The introduction teaches a new word's
  first showing; the long texts are shorter in all four languages. Medal toasts stand where they cover nothing.
- Deck options (both apps) use Anki's names (Desired retention, Leech threshold, Leech action, Maximum interval, Learning steps, Optimize), a "?" popover on each row and Restore Defaults; new option Maximum reviews/day (`maximumReviewsPerDay`, a cap on the day's review cards, `references/scheduling.md`); "Spread out intervals" is gone, `fuzzing` stays on.
- Both devices run 11.0 since 30.10 (Mac 11.0.2 e19dee3, iPhone 11.0.1 3e0b74b, signed until 06.11). A Mac or iPhone
  11.0 that saves a deck writes format 7, which a 10.x app rejects: both stay on 11.0, and `deck-from-tsv` runs from
  source (`swift run`). The decks as they were before: `iCloud Drive/Mnemit/.backups/pre-11.0-20261030-0441`. The Mac was
  seen live on 30.10 on EF's decks without grading: Today, a deck's page and table, the options sheet and its "?" popover
  (whole text), Usable reviews 140 / 400 over all decks, Add Cards; the Mac's ledger rebuilt 21–25.10 from the logs
  (22.10: 52 cards, 161 reviews, was 70 and 211). The iPhone 11.0 is not yet seen live.
- Decisions of 27.10 and their evidence: `references/product-model.md` §5, §9 ("The grammar of the screens"), §11;
  `references/grades-research.md` and `Tools/grades/` (two buttons), `Tools/ring-sim/leeches.md` and
  `references/leech-research.md` (leeches), `references/today-layout-research.md` and `references/hig-ios26.md` (Today).
  The code's rules: `references/daily-ring.md`; the package and the ledger: `references/deck-package.md`; the learner's
  paths: `references/learning-flow.md`; terms: `GLOSSARY.md`; screens: `references/screens.md`; look: `design-spec.md`.
- New cards: the learner's unit is the word (a note with its cards). The ring's allowance says how many new cards the day
  takes, one queue over all decks that aren't paused says which (new words newest addition first, opened Meaning → Word
  cards alternating with them one for one, `references/scheduling.md`); a Meaning → Word card opens at a 7-day interval
  (`StudySession.unlockDays`). The one deck option for new cards is New cards/day, Anki's name (Auto by default, the ring decides): that many
  a day, outside the allowance. ADR 0008; `references/product-model.md` §5 and §10.
- Speech: words are rendered ahead and played from memory (`GreekSpeech`, `SpeechLog` writes
  `Library/Caches/speech.log`, read off the iPhone with `devicectl device copy from`); EF heard no stutter.
- Strings in en, de, ru, el; `Tools/check-localizations.swift` requires all four.
- Mac: `~/Applications/Mnemit.app`, `com.euf.mnemit`, installed by `Scripts/install-mac.sh`.
- iPhone 13 mini (UDID `00008110-000411010C68401E`): Mnemit `com.euf.mnemit.ios` with the widget
  `com.euf.mnemit.ios.widget`, installed by `~/dotfiles/ios-renew --force` (see "iPhone signing").
  On the iPhone EF studies, edits cards and decks, and adds words after a lesson.
- Decks in `iCloud Drive/Mnemit/`, both built by `Tools/deck-from-tsv` from the dictionary
  `~/Documents/greek-lessons/vocab/` (`merge.py` → `greek-vocab.tsv`, `cards.py` → `cards-*.tsv`):
  - `Greek A1–A2.mnemit`, review of the familiar: 1629 words, 3258 cards (Word → Meaning and Meaning → Word),
    New cards/day —; paused by EF.
  - `Greek B1.mnemit`, learning: 2394 cards, New cards/day — (cleared 29.10 with `deck-from-tsv --new-per-session none`):
    the deck takes its share of the allowance. Meaning → Word cards open at an interval of 7 days.
    78 old cards of the first deck are frozen (their words went to A1–A2), 131 adopted with their progress.
  The words of a lesson are a file of their own, `src-b1-LNN.tsv` in the order of the lesson's table; `merge.py`
  keeps the order of the sources, `curated.tsv` holds the checked Russian, English and examples. On 29.10 every card not started was renewed (`deck-from-tsv --renew`):
  lesson 6 first, then the zodiac topic, the rest in the order of the sources.
  - `Greek Grammar.mnemit`: sentence cards for the grammar tables, a form per sentence, from
    `src-grammar-<topic>.tsv` (`cards.py` → `cards-grammar.tsv`). First topic: δικός μου.
  A recognition question is the Greek form; the answer is Russian, English only where it helps, and an example.
  A translation question is Russian (a clarification in brackets tells synonyms apart), the hint the part of
  speech and English if there is any, the answer the Greek form and an example. There is never Greek in a
  question or a hint. Copies before every write:
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

In order of importance to EF. Brief sub-agents by `references/agent-briefs.md`.

The plan of 7.0–7.1 is `references/quality-plan.md`.

1. **11.0 on the iPhone, to verify live** (`references/audit-2026-10-30.md` §5): in Russian and dark at 375 pt, the "?"
   popovers and the option menus, "Ring closed" with Keep Going and no outline of the last card, Add Cards in list mode,
   the study card at AX5, the leech moment, the toolbar's "+" and "…" on Today, the widget the morning after a break, a
   reminder tap from a cold start, the lost-folder card; the iPhone's ledger file rebuilt with `"rule":1` after its first
   day ends. Xcode's Apple ID was lost once (24.10): `ios-renew` then fails with "No Accounts" until EF signs in again in
   Xcode ▸ Settings ▸ Apple Accounts.
2. **The Mac, still to see live:** a stream (only on a deck whose grades may count: the ring and ledger take every open
   deck), a cold launch with a deck from Finder, ⌘Q with a stream running, a Dock click after ⌘W, Try Again on a failed
   deck, the streak-ended line, a sheet's default button. Seen on 27.10: at a 1000 pt window the card table's four new
   columns sit past the right edge; Delete Deck of a deck in `/private/tmp` does nothing (no Trash there).
3. **Answer buttons and leeches, to watch:** whether EF turns "Hard and Easy Buttons" on (Easy's shorter path for the
   familiar A1–A2 words is only there); the first leech moments and whether Edit is used.
4. **Share Deck**: a clean `.mnemit` copy (cards and media, no states, no log, no fitted parameters) from
   the deck's menu on both apps; sending the package today sends one's history.
5. **From the reviews of three personas (23.10: Anki veteran, newcomer, no-decks learner)**: FSRS figures
   (RMSE, log loss) for Anki users; Anki import fidelity (cloze, several media per side) and an export back
   with history.
6. **Decisions to revisit by evidence** (`references/ring-design.md`, "What would reopen it" and "Other
   decisions of the day and their evidence"; four to measure on EF's own log):
   - The day's time: at 60 study days count the closed rings in the Progress calendar: a share outside
     0.7-0.85 reopens it.
   - Two rests a day: Forgot rate and `ms` by minute in streams of 15+ minutes against 1 - R; add a skippable
     rest at the minute where either climbs.
   - The backlog spread: ascending against descending retrievability in the open-spaced-repetition
     sort-order simulator with EF's fitted parameters, at the first backlog over 100 cards.
   - Production cards: the Forgot share of the first two production reviews; over 25 % lifts the
     7-day gate to 14, at or below 10 % under a gate of 14 or more lowers it; wait for 100 reviews.
7. **Known behaviour, decide on complaint:** pace starts from defaults until 20 timed reviews; a deck with
   nothing in today's plan doesn't open with Study, so the plan-end rest's Learn 10 New Words can't take its new cards (Learn 10 New Words
   from Today opens every active deck); xcodebuild 27.1 sometimes hangs
   after the iOS summary (the summary is right); the Mac Learning Options sheet overwrites a fit that
   arrived while it was open; the iPhone 17 Pro simulator is often the FicTypeApp session's, use another. `AnkiImportTests.leavesNoTemporaryDatabaseBehind` fails when another test run shares `/tmp` at the same time; alone it passes. In a Swift Testing `-only-testing` filter a test name needs its parentheses (`.../name()`), or xcodebuild runs nothing and still prints TEST SUCCEEDED. The Mac's `UndoRouter` puts itself back in the window's responder chain after every window update; its observer is removed when it leaves (the test host crashed twice on 27.10 before that). A canvas crash of `ActivityRing` was seen once in a Mac window test during a card flight (phase 3a).
8. **Dictionary**: `merge.py` now merges `ο/η` with `ο`/`η` like `WordKey`; the decks still hold the
   duplicate cards of 11 words, which `deck-from-tsv --suspend-missing` would park.
9. Later: examples from Tatoeba; FSRS-7 once it ships in fsrs-rs; sibling spread and load balancing
   (store the chosen date in the log first); hiding siblings across decks once pairs exceed 1 %
   (`references/cross-deck-overlap.md`); a listening mode.

## Next for the ring

Drafts from 23.10, not approved by EF; the decisions and everything measured are in `references/ring-design.md`.

1. **A lasting backlog in plain words** (EF asked for plain-language texts "по-человечески"): veterans with hundreds of due cards
   see "≈ 45 min of reviews left" after the ring; the longer text ("480 cards have piled up; the ring takes the most forgotten
   first; at this pace about 3 weeks") is not built.
2. **Forecast** in How It Works: what the current intake of new words costs in a month and a year (as Anki's simulator
   and Noos do).
3. **Rings without new words**: a learner who runs Learn 10 New Words one day in three has no new word in the ring
   on 46 % of study days (the reviews of earlier Learn 10 New Words cards fill the time); new words then come only
   through Learn 10 New Words. Watch it in Mnemit's own log before changing anything.
