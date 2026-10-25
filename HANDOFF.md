# HANDOFF — Mnemit

## State

- Version 6.0 on `main`; the iPhone runs 6.0 (ea8a95d), signed until 01.11; the Mac app 6.0 from `main`. The day's model (one ring that stays full at the goal, the streak as a flame, the
  stack that ends with the plan, Study / Catch Up / Push On, partial credit, the streak step, two rests, medals, the
  Progress screen on both apps, the Mac's Today window)
  and the user's paths through a day, a newcomer's first week included, are `references/learning-flow.md`; the
  ring's size (seconds, a staircase on closed and open rings) is `references/daily-ring.md`; why the ring is what it is, every alternative measured on synthetic learners
  and the logs of 2,000 Anki users, and the other decisions of the day with their evidence: `references/ring-design.md`;
  sources: `references/day-model-research.md`, `speech-stutter-research.md`. Terms: `GLOSSARY.md`, section "Mnemit" (a card is never a review).
  Screens: `references/screens.md`. Brief sub-agents by `references/agent-briefs.md`.
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

In order of importance to EF. Brief sub-agents by `references/agent-briefs.md`.

1. **6.0 on the iPhone, to check on the device:** the flame in Today's ring and in the widgets, Push On from Today, a
   reminder that names the streak, the icon's number. Xcode's Apple ID was lost once (24.10): `ios-renew` then
   fails with "No Accounts" until EF signs in again in Xcode ▸ Settings ▸ Apple Accounts.
2. **The Mac's Today and Progress windows on the live screen.** They were checked from offscreen frames only
   (`TodayWindowSnapshotTests`, `SessionSnapshotMacTests`; the screen was locked): look at them with `vqa`,
   Study from Today opening the deck and starting its stream, and the window staying open beside a deck.
3. **Progress must not depend on the decks in the list.** The ring, the streak and the medals are worked
   out from the logs of the active decks: deleting or pausing a deck, or deleting a card, rewrites past
   days. Plan: a progress ledger in the deck folder, one line per study day (done, goal, kept, closed),
   frozen at the day's change, merged by day across devices, filled from the logs on first run; past days
   read from it, today from the logs.
4. **Share Deck**: a clean `.mnemit` copy (cards and media, no states, no log, no fitted parameters) from
   the deck's menu on both apps; sending the package today sends one's history.
5. **How Today Works → "Under the Hood"**: it is the last row of Progress on both apps; still open: a short "Today"
   section in plain words on top, the tables folded.
6. **From the reviews of three personas (23.10: Anki veteran, newcomer, no-decks learner)**: a new
   word's first showing as an introduction, not a red Forgot (New Deck now goes straight on to Add Cards);
   FSRS figures (RMSE, log loss) for Anki users; Anki import fidelity (cloze,
   several media per side) and an export back with history.
7. **Decisions to revisit by evidence** (`references/ring-design.md`, "What would reopen it" and "Other
   decisions of the day and their evidence"; four to measure on EF's own log):
   - The day's time: at 60 study days count the closed rings in the Progress calendar: a share outside
     0.7-0.85 reopens it.
   - Two rests a day: Forgot rate and `ms` by minute in streams of 15+ minutes against 1 - R; add a skippable
     rest at the minute where either climbs.
   - The backlog spread: ascending against descending retrievability in the open-spaced-repetition
     sort-order simulator with EF's fitted parameters, at the first backlog over 100 cards.
   - Production cards: the Forgot share of the first two production reviews; over 25 % lifts the
     7-day gate to 14, at or below 10 % under a gate of 14 or more lowers it; wait for 100 reviews.
8. **The Mac suite** ran on 24.10 with the screen locked: 194 tests, one failure,
   `CardListViewTests.firstClickIntoTableSelectsRow`, which fails whenever the test app isn't in front (so may
   `focusedTableHandsFocusToNewTableWhenSorted`). Run it once on the unlocked screen.
9. **Known behaviour, decide on complaint:** pace starts from defaults until 20 timed reviews; a deck with
   nothing in today's plan doesn't open with Study, so the plan-end rest's Push On can't take its new cards (Push On
   from Today opens every active deck); xcodebuild 27.1 sometimes hangs
   after the iOS summary (the summary is right); the Mac Learning Options sheet overwrites a fit that
   arrived while it was open; the iPhone 17 Pro simulator is often the FicTypeApp session's, use another.
10. **Dictionary**: `merge.py` now merges `ο/η` with `ο`/`η` like `WordKey`; the decks still hold the
   duplicate cards of 11 words, which `deck-from-tsv --suspend-missing` would park.
11. Later: examples from Tatoeba; FSRS-7 once it ships in fsrs-rs; sibling spread and load balancing
   (store the chosen date in the log first); hiding siblings across decks once pairs exceed 1 %
   (`references/cross-deck-overlap.md`); a listening mode.

## Next for the ring

Drafts from 23.10, not approved by EF; the decisions and everything measured are in `references/ring-design.md`.

1. **Plain-language texts** (EF asked for them "по-человечески"): the ring is "the cards due so you don't forget them, as
   many as fit your usual time; if time is left, new words fill it"; two modes of Catch Up: a rare day (7-10 % of study
   days, 5-30 cards: "more than usual is due today: 12 more cards wait in Catch Up") and a lasting backlog (veterans,
   hundreds of cards: "480 cards have piled up; the ring takes the most forgotten first; at this pace about 3 weeks").
2. **The ring's size as progress** on the Progress screen ("Your ring: 12 min a day. You started at 2.5"): any adaptive
   rule fixes the closure share, the size is what differs between people.
3. **Forecast** in How Today Works: what the current intake of new words costs in a month and a year (as Anki's simulator
   and Noos do).
4. **Push On rings without new words**: a learner who pushes on one day in three has no new word in the ring on 46 % of
   study days (the reviews of earlier Push On cards fill the time); new words then come only through Push On. Watch it in
   Mnemit's own log before changing anything.
