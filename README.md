# Mnemit

Flashcards with FSRS for iPhone and Mac. Decks are files in iCloud Drive: no account, no
server, no in-app purchases. A personal fork of
[MacVocTrain NG](https://github.com/Fluch-IT-Consulting/MacVocTrainNg) by Martin Fluch,
built to learn Greek vocabulary; nothing in the app is tied to Greek.

## Design choices

What Mnemit does differently from Anki and most FSRS apps, and why. Sources and measurements
are in [`references/`](references/).

### Grading

- **One "no", one "yes", and two more on request.** Two wide buttons, Forgot (red) and Good (green), ask what a learner can
  tell: did the word come. FSRS works as well or better with consistent grading as with four free choices, and its costliest
  input is Hard on a forgotten card, which still grows the interval
  ([`fsrs-research.md`](references/fsrs-research.md) §1). Hard and Easy are a swipe or a key away, and the setting "Hard and
  Easy Buttons" gives them buttons: Forgot on a row of its own, Hard, Good and Easy under it, three greens whose chroma rises
  from a dull sage to a vivid jade.
- **A new card's first showing is asked.** A word never seen is asked like any card: question,
  Show Answer, then two wide buttons, Don't know and Know (Again and Good underneath; the swipes left and right give only these two); later showings have the same two, named Forgot and Good ([`docs/adr/0007-first-showing-is-asked-as-dont-know.md`](docs/adr/0007-first-showing-is-asked-as-dont-know.md)).
- **Swipes with dead zones.** ← Forgot, → Good, ↑ Easy, ↓ Hard. The recognised sectors follow a
  clock face, 0 at the top, clockwise: Easy 330°…45°, Good 45°…135°, Hard 135°…210°, Forgot
  240°…300°, and nothing in the two gaps between the "no" and the "yes" sectors (210°…240°,
  300°…330°): a swipe there springs back however far or fast it goes. The vertical sectors are
  wide, as a right-handed thumb is fastest up, down and on the diagonal. The card does not follow
  the raw finger: it moves halfway between the finger and the grade's target direction (Easy
  60°, Good 90°, Hard 120°, Forgot 270°: Easy and Hard 30° above and below due east), so a finger straight up moves it 30° to the right
  of up, a finger straight down 30° to the right of down, and Forgot goes straight left. On the Mac the same arrows, Space to reveal, 1–4 as in Anki.
- **One gesture.** Touching the card shows the answer; the same swipe grades it.
- **One haptic per grade.** A swipe is felt once, when letting go would grade; the card that
  flies off after it is silent, and so is its landing in the ring. A button, a key or a flick
  are felt once, as the card flies.
- **Progress you can see.** Every graded card leaves past the edge of the screen. A card that goes
  to another day takes a sheet off the stack, the small ring in the bar steps, glows and bursts, and
  "in 8 days" shows beside it; a card that comes back today returns as a blank sheet under the
  stack. The card under it rises into place and can be swiped at once, while the first still
  leaves. At the end of a round the ring comes down into the empty place of the card, bursts, and
  the lines of the rest come in under it; a medal arrives as a toast. With
  Reduce Motion the card fades in place and nothing travels or bursts.
- **No intervals on the buttons.** "4 d" under a button reads as a promise and pulls the
  choice; the interval shows beside the ring after grading.
- **Undo everywhere.** The undo button next to the menu, a shake on the iPhone, Z or Esc on the
  Mac; undo runs through the whole study stream, not only the last card. On the iPhone it plays
  the grade backwards: the card comes out of the ring or up from under the stack, with its
  answer showing, ready to be graded again.

### Studying

- **No sessions, one stream over all decks.** Study is one stream over every active deck: the day's
  plan (cards in learning, then review cards with the lowest recall probability first, then new
  cards within the day's limits, taken from the decks in turn), each card from the deck whose next
  card is most urgent and graded into that deck. Study This Deck runs it over one deck. When
  the ring is closed the stack rests ("Ring closed") and offers Catch Up while the plan has cards
  left; once the plan is done it offers Learn 10 New Words, ten new cards from the decks, mixed, whose
  reviews make the next days harder. A card is never reviewed before it is due: an early review gains FSRS
  little, and more work is a new card.
- **One ring a day, up to three moments.** The product model, the one description of what Mnemit is for and what every screen
  shows, is [`product-model.md`](references/product-model.md); the learner's paths through a day are in
  [`learning-flow.md`](references/learning-flow.md). Today is one card: the ring, a picture with no number in it, and beside it
  three figures, the Day streak, the next moment with its minutes ("To keep your streak", "≈ 2 min") and the words learned, with
  the week of rings under them. The button under it names
  what comes next: Study while the ring is open, Catch Up once it is closed and the plan has cards left, Learn 10 New Words
  once the plan is done. The streak is kept after the first ≈ 2 minutes, where Study rests once ("Streak kept": Keep Going or
  Done for Now); the next rest is the closed ring ("Ring closed"), then, after Catch Up, "All done". Study These Now, in Add
  Cards, studies the cards just added first. Inside, the day has a time in minutes of work at your own pace, learned from your
  review logs (`daily-ring.md`): two and a half minutes on the first day, then more after rings you close, less after one
  left open, and, for a learner who goes well past the ring on most days, what they really do; between two minutes and an
  hour; a day without study changes nothing. New cards are admitted up to the time it leaves after the day's reviews, so a
  break does not turn into a wall of work.
- **The ring counts cards, and every answer recalled moves it.** A ring in the manner of Apple
  Fitness fills to the daily goal: the
  cards of the day's plan as FSRS set it when the day began that fit the day's time, the
  review cards due, overdue ones included, and the new cards the day's time admits. A card is done
  once its last review of the day left it due on a later day, so a review card graded Hard,
  Good or Easy is done at once, a new card after its learning steps, and a card graded Forgot
  when it is through relearning. A card counts once, however many reviews it took. Done and left add up to the plan. The ring also shows the cards on their way: an
  answer recalled moves its card by the answers recalled today over those plus the steps still
  needed, so a new word is half a card after its first Good; Forgot moves nothing, and nothing
  is taken back (`Card.credit`). Each review records how long its
  card was on screen while the app was in front. New cards and all other cards are priced apart:
  the typical time of a review (a lognormal mean from the median and the spread of the recorded
  times, so a card left open while away barely moves it) times the reviews a done card of that
  kind took over the last week; the reviews of cards begun and left open at the end of a day are
  in neither count. Older logs without times are priced from the pauses between reviews, by their
  median, so a break does not count; until there is enough data, 30 seconds a new card and 10 any
  other. The daily goal does not move during the day:
  cards added later, Study These Now, Learn 10 New Words and Catch Up count as cards done beyond it. The ring is
  full at the goal and goes on over itself past it, up to three laps. The flame stands in the Day streak figure: filled once the day keeps the streak, an orange outline with an exclamation mark the day after a missed one, a grey outline otherwise; no ring holds a number. A missed day is repaired when the next day closes its ring, the streak step
  is not enough then; two missed days in a row end the streak. Today is computed from the review
  logs; a day that is over is kept as a progress record, one file per device in the deck folder (`.mnemit-progress/`), and a
  record only rises, so deleting a card or a deck cannot take a past day's ring back. A study day starts at 4:00.
- **Words learned.** "412 words learned · +12 today" counts whole words whose Word → Meaning card has left learning: it
  grows when you learn, loses a word on a lapse until it is relearned, and cannot be inflated by counting more cards (a word
  held twice counts once). Medals mark 10, 50, 100, 250, 500, 1,000 and every 1,000. The sum of FSRS's recall probabilities over
  the recognition cards, "words in memory", is in Progress and How It Works for those who look.
- **The day's time paces a backlog.** After an import or a break, every card due is in today's
  plan, overdue ones included, the most forgotten first. The goal is the cards of the plan that
  fit the day's time: 1,500 overdue cards with a six-minute day give a goal of about 36 at 10
  seconds a card, and the rest wait in the plan. When the ring closes, "Catch Up" goes on with
  them; those cards are due, so their reviews are ordinary ones and the cards done count beyond the goal.
  The size of a study session in the deck options is the size of one segment of the stream and does not cut the plan.
- **Two directions per word, production one spaced review behind.** Each word has a
  recognition card (Greek → meaning) and a production card (meaning → Greek). Production is the
  harder direction (about half the recall of recognition after two weeks in the one experiment
  that measured both), recognition study yields little of it, and adding it does not lower
  recognition. A word's production card therefore unlocks once its recognition card has an
  interval of 7 days, which on the default parameters is after the first spaced review passed
  (the lock is a deck option; 0 turns it off for words already known). Production cards have
  their own daily limit and come oldest learned word first (by the first review of the
  recognition card), whatever the new-card order; siblings are buried for the day so one card
  does not answer the other. No study compares introducing the second direction later with introducing it together;
  the numbers and sources are in [references/production-cards-research.md](references/production-cards-research.md).
- **Pause a deck.** A deck can be paused, from its row on Today (swipe or long press), from the menu of
  its screen, or on the Mac in Study ▸ Pause Deck. A paused deck takes no part in the day: not in the
  plan, the goal, the rounds, the new cards the day admits (they go to the other decks), the streak,
  the words learned, the widget, the reminders or Study. Today lists it
  under "Paused", with no counts. It stays open: you can browse it, add cards and study it with Study
  This Deck, and what you review there fills the ring only through the cards of the other decks.
  When you resume it, its overdue reviews are due like any other and come back into the plan.
- **A word that keeps slipping.** A card forgotten 8 times (a deck option, 0 turns it off), and again at every half of that,
  stops the stack right after the Forgot: "Keeps slipping" keeps the answer on screen with Edit, Set Aside and Continue. The
  deck's action decides what Continue leaves: Keep, the default, leaves the card in rotation; Suspend suspends it, and the
  moment offers Keep It instead of Set Aside. A Leeches filter in the card browser lists these cards.
- **Greek spoken from memory.** A card's Greek word is rendered into a buffer as the card comes up
  and played from memory, so the voice never stutters on a busy phone; where the deck has a
  recording for the side, the recording plays instead
  ([`speech-stutter-research.md`](references/speech-stutter-research.md)).

### Scheduling

- **The day's time sets the new cards.** Under FSRS a learner chooses two things: the target recall
  and how many new cards to take in. Reviews follow from them: FSRS brings a card back when its
  predicted recall falls to the target, and the benchmarks judge a scheduler by how well that
  prediction matches what happens (srs-benchmark: log loss and RMSE over bins, FSRS-6 at 0.065;
  SuperMemo's universal metric does the same per class of recall). So a day's reviews are the
  cost of what was learned before, and new cards are the only free input. Each one is a debt:
  Anki's manual expects about 200 reviews a day from 20 new cards a day, and ten new cards bring
  13 reviews in the next three days and 43 over two months (`Tools/ring-sim/cards.py --echo`).
  Anki fixes the input, 20 new cards a day, and the time comes out of it; the manual then asks
  the learner to cut new cards when reviews pile up, to stop them during a backlog, and offers a
  simulator that asks how many minutes a day one can really give. The scheduling literature
  poses the problem the other way round: as much material as possible within a cost constraint
  (the SSP-MMC formulation in FSRS's "Three-Day Journey"). Mnemit takes that form. The
  constraint is the day's time, learned from the rings, with no setting; the reviews due take it
  first, most forgotten first; new cards fill what is left. Intake then follows capacity: as the
  reviews of earlier cards grow, fewer new cards fit, and when the learner gives more time, more
  fit. The queue cannot run away, since intake is what the reviews leave (Reddy et al. 2016:
  a review queue fed faster than it is served grows without bound), and a break is paced by the
  time instead of becoming a wall. The target recall stays at 0.9, the value Anki's guide calls
  a good balance, and only the time adapts. Learn 10 New Words is the one way past the
  time: ten new cards at once, whose reviews fill the next days. Sources and measurements: [`ring-design.md`](references/ring-design.md),
  [`day-model-research.md`](references/day-model-research.md), Part 1 §3.
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
  (cards and their state), `reviews.jsonl` (one line per review, with its time on screen, only ever appended)
  and, for cards with pictures or sounds, a `media/` folder of the files, each named by its content (the
  first 16 hex characters of its SHA-256) so identical media are stored once and a file never changes.
  iCloud Drive syncs it like any document; only the changed pieces upload, and a save clones the media that
  are in the package already instead of writing them again. A SQLite file
  in a sync folder is what Anki's own manual warns against
  ([`deck-formats-and-sources.md`](references/deck-formats-and-sources.md)).
- **Merging per card, never losing a review.** When two devices edit offline, the review
  logs are joined, the later edit of a card wins (its texts and its media), a deletion wins only
  if it is later than every change on the other device, options keep the later change and the media
  files of both devices are kept. A randomized test
  plays 200 histories on two devices and checks that both sides converge.
- **Old `.voctrain` decks** from MacVocTrain NG open and save in place.

### Import and export

- **Anki packages with their history.** `.apkg` and `.colpkg` in all three layouts (including the
  zstd-compressed current one) is read without Anki; review history is replayed through
  Mnemit's FSRS. HTML is reduced to text; the first image and the first sound of each side
  come along as the card's media, a back takes the meaning and then the example sentence, and cloze
  cards are counted and left out. The preview names the images, sounds and megabytes the package brings. On the iPhone "Open in Mnemit" works from Files, Safari and Mail; on the Mac an
  `.apkg` opened from the Finder becomes a new deck.
- **CSV/TSV that Anki reads as it is.** Exports start with Anki's `#separator`, `#html` and
  `#columns` lines and carry the word key and the card kind; imports accept them back. Media are
  not part of a table and stay out of it.
- **No MacVocTrain 1 import.** Cards come in through Add Cards, `deck-from-tsv`, CSV/TSV files and
  Anki packages; Mnemit reads no MacVocTrain 1 documents.
- **Ready-made decks come from AnkiWeb.** Mnemit ships no content: the good shared decks
  are licensed for personal study and cannot be bundled. "Shared Decks on AnkiWeb" opens
  AnkiWeb (and MintDeck) in a plain web view inside the app; a deck the learner downloads
  there goes straight into the import, links to other sites open in Safari. Nothing is
  injected into the pages or read from them.
- **One word in two decks.** Decks are separate files and nothing is merged. A word is
  recognised across all decks by its key: dictionary form, case, endings (`-η, -ο`),
  alternatives after a slash and the article, with `ο/η` matching `ο`; accents stay, so πώς and
  πως are two words. Adding or importing a word another deck holds leaves it unticked and names
  the deck; a match that differs only in accents (άπλος, απλός) stays ticked with a notice.
  Glosses are shown and never compared. Each copy keeps its own FSRS state, as in Anki, and one
  review does not move the other copy. Suspend parks the extra copy, and "words learned"
  counts a word once. Burying across decks waits until the overlap is measured; the sources, the
  measurement on the Greek decks and the build rules are in
  [`cross-deck-overlap.md`](references/cross-deck-overlap.md).

### Look

- **One accent, semantic colours.** Indigo `#5856D6` for the app and its widget (red means
  "no", the greens mean "yes" and orange means the streak, so the accent is none of them); counts are neutral. On the Mac the
  system accent setting applies.
- **Rings drawn as Fitness draws them.** The drawing is MKRingProgressView's Core Graphics
  code transcribed into a SwiftUI `Canvas`: gradient to the head, the head's shadow clipped to
  the ring, a dim track.
- **An introduction that teaches the day.** A new word is asked as any card is: Don't know or Know, and it comes back in
  the same sitting. Four practice cards in four languages, one per direction, teach the swipes; four lines say what a day is;
  then where to keep the decks (iCloud Drive or this iPhone only) and the reminder.
- **One grammar for the screens.** Content is solid and controls are glass: cards, rows, tiles and the ring sit on the grouped
  fills, and Liquid Glass is only the bars and the buttons that float over them. Today's card holds the ring on the left and its
  figures on the right, each a label over a rounded value in the colour of what it counts
  ([`design-spec.md`](references/design-spec.md)).

### Constraints that shaped the above

- Mnemit is signed with a free Apple ID team. Such a team gets no iCloud container, so the
  app cannot create its own iCloud folder: the learner picks one once. The
  widget gets its numbers from the app through a shared keychain item, since App Groups
  are not relied on for free teams.

## Platforms

- **iPhone** (iOS 26): study, browse and edit cards, add words after a lesson (one card or
  a pasted `word = translation` list), decks, options, import and export, reminders, and a widget
  (the ring, the streak and the next moment, on the home screen and the lock screen).
- **Mac** (macOS 26): one window. Its sidebar lists Today, Progress and the decks of the Mnemit folder, each
  deck with "≈ 4 min" or a check (the minutes left of its plan); Today holds the Today card
  (the ring with the Day streak, the next moment, the words learned and the week) over all of them with the same button as the
  iPhone (Study, Catch Up or Learn 10 New Words); a deck's page opens with the deck's own card ("≈ 4 min" with Due, New and
  Learning) and Study This Deck, then either the card table (filters, inspector, multi-select, keyboard) or its statistics.
  Study is by keys and buttons, and neither app has a typed answer: the two buttons are Forgot and Good (← or 1, → or 3),
  named Don't know and Know on a card's first showing, Hard and Easy are ↓ ↑ or 2 4 (and buttons with "Hard and Easy Buttons"
  in Preferences), and the cheat sheet (?) names
  the keys of the card on screen. Study These Now sits in the Add Cards sheet, and after importing a table into
  an empty deck, and studies the added cards first. The Mac has no reminders and no widget.
- **How It Works** (the last row of the Progress screen, a sheet on both apps): the numbers
  and rules under the ring, read-only: the plan, the day's time, pace, streak, words in memory and each deck's FSRS settings.

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

- [`references/product-model.md`](references/product-model.md): what Mnemit is for and what every screen shows;
  [`references/learning-flow.md`](references/learning-flow.md): the learner's paths through a day;
  [`references/ring-design.md`](references/ring-design.md): why, with every alternative measured;
  [`references/daily-ring.md`](references/daily-ring.md): how the code computes it.
- [`references/screens.md`](references/screens.md): every screen on both platforms.
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
