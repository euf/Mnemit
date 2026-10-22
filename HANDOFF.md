# HANDOFF — Mnemit

## State

- Version 4.0 on `main`; the iPhone runs 4.0.0 (7ccc87e), signed until 29.10. What the app does and
  why: README, section "Design choices"; terms of the day, ring, streak and pace: `GLOSSARY.md`,
  section "Mnemit" (a card is never a review); screens of both apps: `references/flows.md`; FSRS
  research: `references/fsrs-research.md` and `references/fsrs-vs-sm17.md`. Brief sub-agents by
  `references/agent-lessons-rings.md`: one source, a ceiling, a stop rule, a test baseline.
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
`references/agent-lessons-rings.md`; the `agent-budget.py` hook stops an agent at 120 min / 40 M tokens.

1. **Showing media on the card** (core in 3.3: `Card.questionImage/Audio`, `answerImage/Audio`,
   `Deck.media.contents(of:)`, the `media/` folder in the package). To do: the image on its side of the
   card (iPhone stream, Card Detail, Mac); the deck's sound on the speaker button and, with auto-speech,
   instead of the synthesizer; browser rows and the edit sheet for sides with only an image or a sound
   (the row is empty now, and the edit sheet requires question text); prep2go's question template
   doesn't show the `Audio` field, so the answer has sound and the question doesn't. Own photos and
   recordings in Add Cards come later.
2. **Rewrite the git history in English.** Only the fork's commits (`git log --author=euf`); leave
   upstream's commits alone, including the German ones and those signed "Claude" from 10–15.10.
   `git-filter-repo` (`uv tool install --managed-python -p 3.12 git-filter-repo`); translate messages by
   meaning, no LLM trailers. Before: a fresh clone as a reserve; after: `git push --force-with-lease
   origin main`; fix the "iPhone runs" hash in State after the rewrite. Do it when there are no agent
   branches.
3. **Live check on the iPhone** (not seen on screen, only tests and snapshots):
   - 4.0: one Study stream over all active decks (the card from the deck whose next card is more
     urgent; Undo goes to the deck of the last step; rounds count all decks; "Done for today" when the
     plan has ended everywhere);
   - card motion: a done card flies into the ring with an interval label, "again today" goes under the
     stack, the next one rises from the stack, input doesn't wait for the flight; round end: the ring
     descends into the empty slot, lines one by one; Undo plays in reverse; the ↶ button in the bar;
     Reduce Motion; VoiceOver speaks the grade. Snapshots: `VocTrainTests/StudyScreenSnapshotTests`;
   - speech without stutter (speech window 0.3–2 s without main-thread work; `SpeechWindowStallTests`
     with `TEST_RUNNER_MNEMIT_PERF=1`): EF checks by ear;
   - deck overlaps: "Also in <deck>" and "Similar to …" in the import preview, Add Cards and Card
     Detail; words in memory count a word once;
   - pausing a deck (swipe, menu, Paused section), swipe zones and the miss counter in "How Today
     Works", prep2go import (75 cards, images and sound, examples in the answer), rounds and capacity,
     widget.
4. **The Mac suite on `main` hasn't been run** (the tests open windows). Known failures when the test
   app isn't in front: `CardListViewTests.firstClickIntoTableSelectsRow` and
   `focusedTableHandsFocusToNewTableWhenSorted`. Any other failure is new.
5. **`~/Documents/greek-lessons/vocab/merge.py` `key()`** gives the pairs "ο/η" and "ο" for one word
   (6 pairs in EF's decks): Mnemit links them through `WordKey`, the generator doesn't.
6. **Known behaviour, decide on complaint:**
   - after "Done for today" in all decks, Keep Going runs on the deck of the last card (its catch-up and
     review ahead), the other decks through a new Study;
   - pace from durations starts with 20 reviews with `ms` in a category; before that the median of the
     gaps between reviews, with no data 30 s for new, 10 s for the rest;
   - `AnkiImportTests.leavesNoTemporaryDatabaseBehind` sometimes fails (shared tmp); a rerun passes;
   - xcodebuild 27.1 sometimes hangs after the iOS run's summary; the summary in the log is right;
   - a backlog of a few cards with an empty plan for today asks for one a day;
   - the Mac Learning Options sheet overwrites a parameter fit that arrived while it was open.
7. Later: examples from Tatoeba; FSRS-7 once it ships in fsrs-rs; sibling spread and load balancing
   (store the chosen date in the log first); hiding siblings across decks once pairs exceed 1 %
   (`references/cross-deck-overlap.md`); a listening mode.
