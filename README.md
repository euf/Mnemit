# Mnemit

Flashcards with FSRS for iPhone and Mac. Decks are files in iCloud Drive: no account, no
server, no in-app purchases. A personal fork of
[MacVocTrain NG](https://github.com/Fluch-IT-Consulting/MacVocTrainNg) by Martin Fluch,
built to learn Greek vocabulary; nothing in the app is tied to Greek.

## Design choices

What Mnemit does differently from Anki and most FSRS apps, and why. Sources and measurements
are in [`references/`](references/).

### Grading

- **One "no", three "yes".** Forgot is red and set apart; Hard, Good and Easy are three greens
  under "Recalled". FSRS works as well or better with consistent grading as with four
  free choices, and its costliest input is Hard on a forgotten card, which still grows the
  interval ([`fsrs-research.md`](references/fsrs-research.md) §1).
- **Swipes with dead zones.** ← Forgot, → Good, ↑ Easy, ↓ Hard. The recognised sectors are
  asymmetric: Good −55°…55°, Easy 55°…120°, Forgot 150°…210°, Hard 240°…305°, and nothing
  between the "no" and the "yes" sectors (120°…150°, 210°…240°): a swipe there springs back
  however far or fast it goes. The card does not follow the raw finger: it moves halfway
  between the finger and the grade's target (E, NE, W, SE), so every "yes" leans right and
  Forgot goes straight left. On the Mac the same arrows, Space to reveal, 1–4 as in Anki.
- **One gesture.** Touching the card shows the answer; the same swipe grades it.
- **One haptic per grade.** A swipe is felt once, when letting go would grade; the card that
  flies off after it is silent. A button, a key or a flick are felt once, as the card flies.
- **Progress you can see.** When a grade sends the card to another day, the screen behind it
  pulses briefly in the accent; a card that comes back today gets no pulse.
- **No intervals on the buttons.** "4 d" under a button reads as a promise and pulls the
  choice; the interval is shown after grading, in the undo chip.
- **Undo everywhere.** The chip after each grade, a shake on the iPhone, Z or Esc on the
  Mac; undo runs through the whole study stream, not only the last card.

### Studying

- **No sessions.** Study is one stream: the day's plan (cards in learning, then review cards
  with the lowest recall probability first, then new cards within the day's limits). When the
  plan is done the stream rests ("Done for today") and offers catch-up on the backlog, review
  ahead, practice that does not touch the schedule, and "+10 new" with the extra cards a day it
  adds next week.
- **Rounds, streak, ring and words in memory.** The day is cut into rounds of two minutes of
  work at your own pace, and Today shows the next small goal: "≈ 2 min to keep your streak"
  before the first round, "Round 2 of 4 · ≈ 2 min" after it, "Ring closed" after the last. The
  streak is kept once the first round is done. Study rests at the end of each round but the
  last, says how long the next one takes and how many words the day has added to your memory,
  and offers Next Round or Done for Now. How many rounds a day holds, its capacity, comes from
  your review logs: two on the first day, one more when the ring was closed on each of the two
  days before, one fewer after a day that ended with the ring open. New cards are admitted up
  to the time the capacity leaves after the day's reviews, so a break does not turn into a wall
  of work.
- **The ring counts cards.** A ring in the manner of Apple Fitness fills to the daily goal: the
  cards of the day's plan as FSRS set it when the day began that fit the day's rounds, the
  review cards due, overdue ones included, and the new cards the capacity admits. A card is done
  once its last review of the day left it due on a later day, so a review card graded Hard,
  Good or Easy is done at once, a new card after its learning steps, and a card graded Forgot
  when it is through relearning. A card counts once, however many reviews it took. Today says
  "12 of 24 cards · 12 left", which add up. Each review records how long its
  card was on screen while the app was in front. New cards and all other cards are priced apart:
  the typical time of a review (a lognormal mean from the median and the spread of the recorded
  times, so a card left open while away barely moves it) times the reviews a done card of that
  kind took over the last week; the reviews of cards begun and left open at the end of a day are
  in neither count. Older logs without times are priced from the pauses between reviews, by their
  median, so a break does not count; until there is enough data, 30 seconds a new card and 10 any
  other. The daily goal does not move during the day:
  cards added later and "+10 new" fill laps, as do catch-up and review ahead. The ring keeps
  going round after the goal; during study its centre shows ×2, ×3 for the laps, elsewhere the
  streak in days. A missed day is repaired when the next day closes its ring, the first round
  is not enough then; two missed days in a row end the streak. Everything is computed
  from the review logs; nothing extra is stored. A study day starts at 4:00.
- **Words in memory.** "≈ 28 words in memory · +15 today" is the number of words you would
  recall right now: FSRS's probability of recall added up over the recognition cards you have
  studied, one card a word. It grows when you learn, falls over days without reviews, and
  cannot be inflated by counting more cards. The number is rounded down, and the day's gain is
  against the number at 4:00. A milestone (50, 100, 250, 500, 1,000 and on) is announced on the day it is passed.
- **A backlog does not pile up on one day.** After an import or a break, the review cards
  that were already due before today ask a seventh of themselves, rounded up, of a day, the
  most forgotten first: 1,500 overdue cards add about 215 to the day's own cards, and the
  count shown is the plan, never the whole backlog. A backlog is never asked for less than a
  normal day asks, so one missed day is made up the next day: five overdue cards beside
  thirty due today are thirty-five. Today says "+1,320 to catch up this week" under the
  plan. "Keep Going" after "Done for today" works through the rest, the catch-up; those cards are
  due, so their reviews are ordinary ones and the cards done fill the laps. The size of a study session
  in the deck options is the size of one segment of the stream and does not cut the plan.
- **Two directions per word, one after the other.** Each word has a recognition card
  (Greek → meaning) and a production card (meaning → Greek). Production cards unlock only
  after the recognition card has an interval of 21 days, have their own daily limit, and
  siblings are buried for the day so one card does not answer the other.
- **Difficult cards** (leeches) after 8 lapses, as a filter in the browser.

### Scheduling

- **FSRS-6, fitted per deck, without a button.** Each deck starts with the default
  parameters, or with the FSRS settings of the Anki preset it was imported from. The
  optimizer (a Swift port of fsrs-rs 6.6.2, checked against it and against py-fsrs reference
  values) fits them in the background at 400 reviews, again at 1,500, then every 30 days or
  1,000 reviews. It trains on the older 80 % of the log; the new parameters replace the
  current ones only if they predict the newest 20 %, which it did not see, better. Fitted
  FSRS-6 beats
  Anki's SM-2 for 99.6 % of users and SuperMemo's SM-17 in 16 of 19 collections; FSRS-7 is
  ahead of FSRS-6 by a small margin and comes in when fsrs-rs releases it
  ([`fsrs-vs-sm17.md`](references/fsrs-vs-sm17.md)).
- **Same dates on every device.** Fuzz is seeded by the card and the moment of the review,
  so replaying a review log on the iPhone and on the Mac gives the same due dates. This is
  why features that pick a due date from other cards (load balancing, Easy Days,
  dispersing siblings) wait until the chosen date can be stored in the log.

### Storage and sync

- **A deck is a package of text files, not a database.** `Deck.mnemit` holds `deck.json`
  (cards and their state) and `reviews.jsonl` (one line per review, with its time on screen, only ever appended).
  iCloud Drive syncs it like any document; only the changed pieces upload. A SQLite file
  in a sync folder is what Anki's own manual warns against
  ([`deck-formats-and-sources.md`](references/deck-formats-and-sources.md)).
- **Merging per card, never losing a review.** When two devices edit offline, the review
  logs are joined, the later edit of a card wins, a deletion wins only if it is later than
  every change on the other device, and options keep the later change. A randomized test
  plays 200 histories on two devices and checks that both sides converge.
- **Old `.voctrain` decks** from MacVocTrain NG open and save in place.

### Import and export

- **Anki packages with their history.** `.apkg` in all three layouts (including the
  zstd-compressed current one) is read without Anki; review history is replayed through
  Mnemit's FSRS. HTML is reduced to text; images, sounds and cloze cards are counted and
  left out. On the iPhone "Open in Mnemit" works from Files, Safari and Mail; on the Mac an
  `.apkg` opened from the Finder becomes a new deck.
- **CSV/TSV that Anki reads as it is.** Exports start with Anki's `#separator`, `#html` and
  `#columns` lines and carry the word key and the card kind; imports accept them back.
- **Ready-made decks come from AnkiWeb.** Mnemit ships no content: the good shared decks
  are licensed for personal study and cannot be bundled. "Shared Decks on AnkiWeb" opens
  AnkiWeb (and MintDeck) in a plain web view inside the app; a deck the learner downloads
  there goes straight into the import, links to other sites open in Safari. Nothing is
  injected into the pages or read from them.

### Look

- **One accent, semantic colours.** Indigo `#5856D6` for the app and its widget (red means
  "no" and the greens mean "yes", so the accent is neither); counts are neutral. On the Mac the
  system accent setting applies.
- **Rings drawn as Fitness draws them.** The drawing is MKRingProgressView's Core Graphics
  code transcribed into a SwiftUI `Canvas`: gradient to the head, solid laps underneath, the
  head's shadow on the ring it overlaps.
- **An introduction that teaches the swipes.** Four practice cards in four languages, one
  per direction, before anything about folders; then where to keep the decks (iCloud Drive
  or this iPhone only).

### Constraints that shaped the above

- Mnemit is signed with a free Apple ID team. Such a team gets no iCloud container, so the
  app cannot create its own iCloud folder: the learner picks one once. The home-screen
  widget gets its numbers from the app through a shared keychain item, since App Groups
  are not relied on for free teams.

## Platforms

- **iPhone** (iOS 26): study, browse and edit cards, add words after a lesson (one card or
  a pasted `word = translation` list), decks, options, import and export, reminders, widget.
- **Mac** (macOS 26): the same plus the card table with filters and inspector, statistics,
  the optimizer, study by typing.

## Build and test

Xcode 27; the project is `MacVocTrainNg.xcodeproj` (schemes `MacVocTrainNg` for the Mac,
`VocTrain` for the iPhone).

```bash
cd Packages/VocabCore && swift test
```

```bash
xcodebuild test -project MacVocTrainNg.xcodeproj -scheme MacVocTrainNg
```

```bash
xcodebuild test -project MacVocTrainNg.xcodeproj -scheme VocTrain -destination 'platform=iOS Simulator,name=iPhone 17'
```

- Mac install: `Scripts/install-mac.sh` builds a Release into `~/Applications/Mnemit.app`.
- iPhone install: the free-team build and nightly re-signing are described in
  [`HANDOFF.md`](HANDOFF.md).
- Updating a deck from a word list without losing progress: `Tools/deck-from-tsv`.

## Documentation

- [`references/flows.md`](references/flows.md): the screens and flows on both platforms.
- [`references/design-spec.md`](references/design-spec.md): layout, colour, type, swipe
  sectors, rings.
- [`references/fsrs-research.md`](references/fsrs-research.md),
  [`references/fsrs-vs-sm17.md`](references/fsrs-vs-sm17.md): grading and algorithm research.
- [`references/deck-formats-and-sources.md`](references/deck-formats-and-sources.md):
  `.apkg` and other formats, deck sources.
- [`docs/adr/`](docs/adr/): architecture decisions inherited from MacVocTrain NG and made
  in the fork.

## Credits and licence

MIT, see [`LICENSE`](LICENSE). Based on MacVocTrain NG by Martin Fluch (MIT). Includes code
ported from MKRingProgressView by Max Konovalov (MIT) and uses zstd by Meta (BSD); notices in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md). FSRS is by
[open-spaced-repetition](https://github.com/open-spaced-repetition).
