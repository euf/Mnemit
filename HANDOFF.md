# HANDOFF — Mnemit

## State

- Version 7.2.x on `main`: the Mac is one window (a sidebar of Today, Progress and the decks; the stream
  takes the window), a new card is asked like any card and its first Forgot reads Don't know, every review counts in full, neither app asks for
  a typed answer, and the widgets and reminders follow the day (the flame's three states, the week, the inline
  accessory, a 21:00 streak reminder). The iPhone and the Mac run 7.2.0 (75ff961), the iPhone signed until
  02.11. The day's model (one ring that holds the cards left and goes on over itself past the goal, up to three laps,
  the streak as a chip outside the ring, the stack that ends with the plan, Study / Catch Up / Learn 10 New Words, partial credit, the streak step, two
  rests, medals, the Progress screen on both apps)
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
  - `Greek B1.mnemit`, learning: 2314 cards,
    20 new recognition + 7 production per day,
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

The plan of 7.0–7.1 is `references/quality-plan.md`.

1. **7.2 and 7.3 on the iPhone, to verify live:** the search minimised beside Study, the Don't know label (a new
   card's first showing), the 21:00 streak reminder, the stack of cards in the stream (step 8, side 7);
   the number in Today's ring (the cards left, a check once the ring is closed), the streak chip under it (its four
   sentences, the flame's three states, the exclamation mark at risk), laps on the week's rings (a day worked past
   its goal draws a second and a third lap, every past day its own share), the stream's header at the leading edge
   (close, ring, flame and time, the ring not moving when the text changes), the new greens (Hard, Good and Easy told
   apart by lightness, light and dark, and the card's tint in dark mode), the 30° flight (Easy and Hard fly toward
   Good's side);
   and from 6.1 the flame in the widgets, Learn 10 New Words from Today, a reminder that
   names the streak, the icon's number, "Yesterday's ring closed" before the day's first card, and reviews from
   the Mac arriving while Today stays open (it reads the decks every minute). Xcode's Apple ID was lost once
   (24.10): `ios-renew` then fails with "No Accounts" until EF signs in again in Xcode ▸ Settings ▸ Apple Accounts.
2. **The Mac's one window, to see live:** seen on 26.10 (vqa): one window on Today, the badges, ⌘1/⌘2/⌘4, a deck's
   Cards and Statistics, Learning Options ⌘;, a deck opened from Finder under Other Decks, the stream by Space, →
   and Z, Done ⌘. bringing the sidebar back. Still to see: a cold launch with a deck from Finder, ⌘Q with a stream
   running (an AppleScript quit was once answered "User cancelled" (-128) after a long QA session; a fresh
   launch then quit cleanly), a Dock click after ⌘W, the Open Deck… panel and the New Deck sheet, the cheat sheet, Catch Up in the
   menu (it needs a closed ring), Edit ▸ Undo on a deck's page, dark mode, Today's Study mixing the decks, the
   search over all decks and a hit selecting its card, a sidebar row's menu (Pause), the medal toasts and the
   month's sheet.
3. **Progress must not depend on the decks in the list.** The ring, the streak and the medals are worked
   out from the logs of the active decks: deleting or pausing a deck, or deleting a card, rewrites past
   days. Plan: a progress ledger in the deck folder, one line per study day (done, goal, kept, closed),
   frozen at the day's change, merged by day across devices, filled from the logs on first run; past days
   read from it, today from the logs.
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
7. **The Mac suite** ran on 26.10: 231 tests, one failure, `CardListViewTests.firstClickIntoTableSelectsRow`, which
   fails whenever the test app isn't in front (so may `focusedTableHandsFocusToNewTableWhenSorted`, by turns). Run
   it once on the unlocked screen.
8. **Known behaviour, decide on complaint:** pace starts from defaults until 20 timed reviews; a deck with
   nothing in today's plan doesn't open with Study, so the plan-end rest's Learn 10 New Words can't take its new cards (Learn 10 New Words
   from Today opens every active deck); xcodebuild 27.1 sometimes hangs
   after the iOS summary (the summary is right); the Mac Learning Options sheet overwrites a fit that
   arrived while it was open; the iPhone 17 Pro simulator is often the FicTypeApp session's, use another. At 375 pt with "30 cards today" the stream's header has no room for the Undo button, which then lives in the "More" menu only. The Mac's `UndoRouter` puts itself back in the window's responder chain after every window update, so watch for undo trouble there. A canvas crash of `ActivityRing` was seen once in a Mac window test during a card flight (phase 3a).
9. **Dictionary**: `merge.py` now merges `ο/η` with `ο`/`η` like `WordKey`; the decks still hold the
   duplicate cards of 11 words, which `deck-from-tsv --suspend-missing` would park.
10. Later: examples from Tatoeba; FSRS-7 once it ships in fsrs-rs; sibling spread and load balancing
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
3. **Forecast** in How It Works: what the current intake of new words costs in a month and a year (as Anki's simulator
   and Noos do).
4. **Rings without new words**: a learner who runs Learn 10 New Words one day in three has no new word in the ring
   on 46 % of study days (the reviews of earlier Learn 10 New Words cards fill the time); new words then come only
   through Learn 10 New Words. Watch it in Mnemit's own log before changing anything.
