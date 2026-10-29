# HANDOFF — Mnemit

## State

- Version 9.0.x on `main` (`VERSION`): the product model of `references/product-model.md` (9.0). Past days are written down
  when they end (the progress ledger, `<deck folder>/.mnemit-progress/<device>.jsonl`, one record per day, merged by day,
  raised only by late answers), so pausing or deleting a deck or a card never changes a past day. A deleted card keeps its
  answers as a retired card (deck format version 6). A deck edited while open (the other device, `deck-from-tsv`, which now
  writes through `NSFileCoordinator`) changes in place, and an undo of a grade survives the reread on both apps. A leech
  (8 lapses, again every half threshold) stops on "Keeps slipping" with Edit, Set Aside or Keep It and Continue; the deck
  chooses Keep (default) or Suspend; a Leeches filter; the Mac's card table has Lapses, Stability, Difficulty and Recall.
  Every card has two answer buttons, Forgot and Good (Don't know and Know on a first showing); what can be given is what the
  screen shows (a swipe up or down springs back, 2 and 4 do nothing); the setting "Hard and Easy Buttons" adds Hard and
  Easy as buttons, swipes and keys together. The greens rise in chroma from Hard (sage) to
  Easy (vivid jade). Today is one card in the screens' grammar (Fitness Summary through the iOS 26 rules, `hig-ios26.md`):
  the ring on the left, Day streak, the next moment with ≈ minutes and Words learned on the right, the week under them, the
  date as the subtitle; Progress, a deck and Statistics use the same cards and tiles. The introduction teaches a new word's
  first showing; the long texts are shorter in all four languages. Medal toasts stand where they cover nothing.
- Both devices run 9.0.38 (c9c236a), the iPhone signed until 03.11. The Mac was seen live on 27.10 (vqa, on 9.0.28): Today, Progress, a deck's page and its
  columns, Preferences, a stream on a copy of Greek B1 (two buttons, key 2 for Hard, the receipt), `deck-from-tsv` run twice
  on the open copy (no alert, 2314 → 2316 cards, the stream went on) and an undo after the reread; the ledger wrote
  21–25.10. Since then only Forgot and Good can be given in two-button mode (tested in the Mac test host, not yet by hand);
  the iPhone is not yet seen live. Both apps must stay on 9.0: a Mac or
  iPhone 9.0 that saves a deck writes format 6, which an 8.x app rejects.
- Decisions of 27.10 and their evidence: `references/product-model.md` §5, §9 ("The grammar of the screens"), §11;
  `references/grades-research.md` and `Tools/grades/` (two buttons), `Tools/ring-sim/leeches.md` and
  `references/leech-research.md` (leeches), `references/today-layout-research.md` and `references/hig-ios26.md` (Today).
  The code's rules: `references/daily-ring.md`; the package and the ledger: `references/deck-package.md`; the learner's
  paths: `references/learning-flow.md`; terms: `GLOSSARY.md`; screens: `references/screens.md`; look: `design-spec.md`.
- New cards: the learner's unit is the word (a note with its cards). The ring's allowance says how many new cards the day
  takes, one queue over all decks that aren't paused says which (new words newest addition first, opened Meaning → Word
  cards alternating with them one for one, `references/scheduling.md`); a Meaning → Word card opens at a 7-day interval
  (`StudySession.unlockDays`). The one deck option for new cards is New cards/day, Anki's name (“—” by default, the ring decides): that many
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

1. **9.0 on the iPhone, to verify live:** the Today card at 375 pt on the 13 mini and at AX5 (ring and figures side by
   side, the ring over them at large sizes, the date under the title), the medium and small widgets and the tinted and
   clear Home Screen (only simulated so far: the ring's track by opacity, laps as "2×"), the two answer buttons and the
   setting, the leech moment (it needs a card at 8 lapses), the introduction's first showing, Progress tiles, the deck's
   Today card with Study This Deck in the bottom bar, the toast over the large title and in the gap above the buttons, and
   a second device file in `.mnemit-progress` once the iPhone has seen a day end. From 8.0, still unseen on the iPhone:
   Study These Now, the rests, the reminders and the icon's "1". Xcode's Apple ID was lost once (24.10): `ios-renew` then
   fails with "No Accounts" until EF signs in again in Xcode ▸ Settings ▸ Apple Accounts.
2. **The Mac, still to see live:** a cold launch with a deck from Finder, ⌘Q with a stream running, a Dock click after ⌘W,
   the New Deck sheet, the cheat sheet, Catch Up in the menu, the search over all decks, a sidebar row's Pause, the month's
   sheet, a medal toast in the header. Seen on 27.10: at a 1000 pt window the card table's four new columns sit past the
   right edge (the Kind column takes the room); once, right after a file merge, the Z key did nothing until a click (not
   reproduced); Delete Deck of a deck in `/private/tmp` does nothing (no Trash there).
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
