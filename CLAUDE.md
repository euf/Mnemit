# Mnemit

Fork of `Fluch-IT-Consulting/MacVocTrainNg` for one job: EF learning Greek (A2–B1) on the Mac and
the iPhone. A vocabulary trainer in SwiftUI, Swift 6, macOS 26+, with an iPhone app (iOS 26+) and a
widget. `origin` is `euf/Mnemit`, `upstream` the original. State, iPhone signing, open work:
`HANDOFF.md`.

The project's language is English: code, comments, docs, commits, base UI strings. German UI strings
come from the String Catalog (Conventions). EF speaks Russian; `GLOSSARY.md` gives the Russian word
for each term.

## Fork rules

- Mnemit (mnem- for memory, + it: "remember it") is every name a person or the system sees:
  `Mnemit.app` on the Mac and iPhone, bundle id `com.euf.mnemit` (`.ios`, `.tests`,
  `.ios.widget`), repository, directory, iCloud Drive folder, About. Upstream's internal names stay
  on purpose, so merges don't turn into handwork: the project `MacVocTrainNg.xcodeproj`, schemes and
  targets `MacVocTrainNg` and `VocTrain`, source directories, modules `MacVocTrain`/`VocTrain`
  (`PRODUCT_MODULE_NAME`), the `format` key inside `deck.json` (`de.fluch-it-consulting.voctrain.deck`).
- Commit to `main` and push without asking. A change useful upstream goes on its own branch as a pull
  request to upstream, under upstream's rules.
- Upstream: `git fetch upstream && git merge upstream/main`. Expect conflicts in `project.pbxproj`
  (product names and bundle ids), in strings with the app's name, and in the docs translated here
  (`CLAUDE.md`, `GLOSSARY.md`, `docs/adr/`).
- Mac: `Scripts/install-mac.sh` → `~/Applications/Mnemit.app`, signed by `euf-sign` with the build's
  entitlements.
- iPhone: `~/dotfiles/ios-renew --force`: Personal Team, app and widget; details in `HANDOFF.md`.
- Version: `VERSION`; the pre-commit hook bumps the patch. After a clone:
  `ln -sf ~/dotfiles/claude/version-hook .git/hooks/pre-commit`.

## Topics

Read the file for the area you work on.

- `references/deck-package.md`: the `.mnemit` package and legacy `.voctrain`, editing and merging on
  two devices, deck file operations, card media files.
- `references/scheduling.md`: today's counts and daily limits, a new card's first showing, reviews, leeches,
  the automatic FSRS refit, the day's stack (Study) and Learn 10 New Words, practices, the newest batch.
- `references/learning-flow.md`: the learner's day: its rules, the journey (one day's paths, Learn 10 New Words, a
  newcomer's first days, a return, an Anki user, several decks), the model, horizons, medals.
- `references/daily-ring.md`: how the code computes the day: plan, goal, rounds, day's time, new-card
  allowance, done cards, ring, pace, backlog, streak, caches, words in memory, "How It Works".
- `references/ring-design.md`: why the day is what it is: the rule, every alternative measured, the
  other decisions of the day with their evidence. Sources: `references/day-model-research.md`;
  measurements: `Tools/ring-sim/` (`cards.py`, `minutes.md`, `real-stats.md`).
- `references/import-export.md`: `deck-from-tsv`, production cards, Anki import (core and screens),
  the deck site browser, CSV/TSV, lesson words, the word key.
- `references/screens.md`: every screen of both apps, what it shows and does.
- `references/study-screen.md`: the iPhone Study screen: layout, motion, speech window, swipe sectors.
- Visual spec: `references/design-spec.md`.
- `references/quality-plan.md`: the audit of 6.1.5 and the plan of 7.0: the model, every screen of both apps,
  the Mac's one window, the order of work.
- Research and verdicts: `references/first-exposure-research.md` (a new card's first showing: other apps,
  FSRS, learning science), `references/fsrs-research.md`, `references/fsrs-vs-sm17.md`,
  `references/production-cards-research.md`, `references/cross-deck-overlap.md`,
  `references/anki-parity.md`, `references/deck-formats-and-sources.md`.
- Briefing sub-agents: `references/agent-briefs.md`.
- Domain: `GLOSSARY.md` (terms, English with German UI words and Russian equivalents) and `docs/adr/`
  (decisions).

## Commands

The active developer dir may be the Command Line Tools; prefix with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` if needed.

- Core tests: `cd Packages/VocabCore && swift test`
- App build + all tests: `xcodebuild -project MacVocTrainNg.xcodeproj -scheme MacVocTrainNg test`
- iPhone app build + tests: `xcodebuild -project MacVocTrainNg.xcodeproj -scheme VocTrain -destination 'platform=iOS Simulator,name=iPhone 17' test`
- Lint: `xcrun swift-format lint --strict -r MacVocTrainNg MacVocTrainNgTests VocTrain VocTrainTests Shared Packages/VocabCore/Sources Packages/VocabCore/Tests Packages/VocabCore/Package.swift Tools`
  (config in `.swift-format`); `format -i` instead of `lint --strict` fixes the layout.
  Name the paths: `build/` and `.build/` contain generated Swift files.
- Translations: `swift Tools/check-localizations.swift` after the builds of both apps
  with `-derivedDataPath build/DerivedData`.
- CI: `.github/workflows/ci.yml`; its header comment lists what the job `test` checks.
- Signing: `Config/Signing.xcconfig` signs ad hoc, `Config/Signing-iOS.xcconfig` signs
  the iPhone app automatically; the untracked `Config/Signing.local.xcconfig` sets the
  team for both. No team ID in tracked files.

## Architecture

- `Packages/VocabCore`: all domain logic, no UI imports. Value types, `Sendable`.
  `Scheduler` applies a `Grade` to a `Card` (FSRS-6 in `FSRS.swift`, ported from py-fsrs);
  `SessionMode` runs a `StudySession` or a `Practice` and records reviews, each over
  a shared `Session` that only tracks card IDs and order.
- `Shared/Document/VocabularyDocument.swift`: the document of both apps. `OpenDeck`
  (`Shared/Document/`) holds it open over the file document: a UIDocument on the iPhone, the headless
  NSDocument `DeckFileDocument` (`MacVocTrainNg/Document/`) on the Mac. The methods
  that edit cards and options (`add`, `editText`, `editCard`, `setNote`, `setKind`, `delete`,
  `resetLearningState`, `updateLearningOptions`, `setSuspended`, the imports) are the
  same on both, in `Shared/Document/VocabularyDocument+Editing.swift`, with the same undo
  action names (#297). Every change must go through its `@MainActor` methods: they register undo, which is also how the file document counts a change as unsaved. They register
  with the document's own `undoManager`, attached with `attachUndoManager(_:)` by `OpenDeck` on both apps before
  it shows the document (the file document's own manager, so NSDocument or UIDocument counts and autosaves
  the changes), in tests by the test; callers don't pass one. The Mac's `UndoRouter` (`MacVocTrainNg/Shell/`)
  answers Edit ▸ Undo with the manager of the deck the window shows. Until a manager is attached the document is only read:
  whatever changes it checks `isReadyToEdit` first (#305). Don't mutate `deck` elsewhere. Underneath, cards and learning
  options change only through `Deck.apply(_:at:calendar:)`: it returns the inverse change
  and keeps `progress` and `contentModified` in step. `VocabCore` builds each `DeckChange`; a card's learning state and
  log can't be set from outside it (tests reach the full `Card.init` via `@testable`).
  Outside it there is only the empty `Deck()`; the full `Deck.init`, also via
  `@testable`, throws on duplicate card IDs and clamps the learning options.
- Reviews are undoable: the document applies the change `SessionMode.grade` returns and
  runs the restore of the `Session`, an opaque `UndoCompanion`, in the same undo action,
  after the card. The document knows no sessions.
- The file document (`DeckFileDocument`: a headless NSDocument on the Mac, a UIDocument on the iPhone) reads
  a deck again on its own when another device changes the file; `OpenDeck` merges what it read into the
  document it holds, which the views keep.
  `VersionMerger` (in `Shared/`, used by both apps) outlives it and merges what the
  file lacks and the versions iCloud Drive keeps in conflict, through
  `VocabularyDocument.merge(_:)`. File presenter callbacks must not ask the document
  synchronously: during another process's write, both would wait for each other. The
  iPhone app lets go of the file in the background. Both apps edit cards, so a merge
  (`DeckChange.merging`, rules in its doc comment) settles each part on its own: cards are
  joined, a card's texts and media by `Card.contentChanged`, the options by
  `Deck.learningOptionsChanged`, a deletion by `Deck.deletedCards` against the latest
  change of the card, reviews are joined and never dropped for a deletion that is earlier.
  The media files of both versions are joined by name, as a file never changes under its name.
- The Xcode project uses synchronized folders: new files in `MacVocTrainNg/` or
  `MacVocTrainNgTests/` are picked up automatically, likewise in `VocTrain/` (the
  iPhone app) and `VocTrainTests/`.
  `Shared/`, compiled into both apps, holds what the Mac app shares with the iPhone
  app (#254): the document and what it needs, and the one String Catalog. Code moves
  there only when the iPhone app uses it and it needs no AppKit; `VocabCore` stays the
  place for domain logic.

## Conventions

- New user-facing strings: add the German translation to
  `Shared/Resources/Localizable.xcstrings`, which both apps share (Xcode may not run to
  sync it), in state `translated`; a string whose wording depends on a count needs
  plural forms in both `en` and `de`. The CI fails on a key missing from the catalog or without German.
- Code ported from another project: add its license to `THIRD_PARTY_NOTICES.md` and
  `MacVocTrainNg/Resources/Credits.html` (the About window).
- Chart/status colours live in `Shared/Support/Presentation.swift`; the maturity ramp is a
  validated one-hue ordinal ramp, keep it that way.
- A deck is a package (`deck.json`, `reviews.jsonl` and a folder `media/` of files named by
  their content, see `DeckFile` and `DeckMedia`); its keys are the glossary terms. Only the private records in `DeckFile` know its keys; domain types
  are not `Codable`. Versions 1 and 2 predate the first release and are no longer read.
  Missing keys decode with defaults, so newer app versions read older decks. Older app
  versions read newer decks of the same version too, but drop unknown keys and files
  on save. So a new field (in `deck.json` or `reviews.jsonl`) or file in the package
  comes without a bump of `DeckFile.currentVersion` only if losing it that way is
  acceptable; otherwise, and for incompatible changes, bump it: older app versions
  then reject the deck: version 5 added the media keys of a card and the folder `media/`, which an
  older app version would drop on save. The review log is encoded incrementally by `ReviewLogEncoder`:
  logs may only grow at the end or be replaced as a whole.
  A line of `reviews.jsonl` has the keys `card`, `date`, `grade` and, when set, `mode` and `ms`
  (the milliseconds the card was on screen, `ReviewLogEntry.duration`); an older app version
  drops `ms` on save, which costs the pace its measured time and nothing else.
