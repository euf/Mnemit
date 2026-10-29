# New cards come from the ring's allowance and one queue; New cards/day is the only deck option

Status: accepted.

## Context

EF could not tell what decided the day's new cards. Five things did:

1. the ring's allowance, the day's time less the reviews (`DailyGoal.newCardsAllowed`);
2. the deck's New per day (`newCardsPerSession`);
3. the deck's Meaning → Word New per day (`newProductionPerSession`);
4. Unlock after N days (`productionUnlockDays`), which decided when a Meaning → Word card could be taken at all;
5. the split of the allowance between decks in proportion to the decks' limits (`DailyGoal.split`).

On top of them the deck had Cards per session (`cardsPerSession`), the size of a stream's segment, which cut nothing
and read like a limit. The learner could not say why a deck gave 12 new cards on one day and 20 on another, or which
cards they were. The Anki veteran knew one of the five, New cards/day, and found it under another name.

The learner's unit is the word: a note (`Card.note`) with one card or a pair, Word → Meaning and Meaning → Word. The
options counted the cards of each direction apart.

## Decision

- **The unit is the word.** A note with its cards; a card without a note is a word with one card. A pair is Word →
  Meaning (`CardKind.recognition`) and Meaning → Word (`CardKind.production`, an internal name; the screens say
  Meaning → Word).
- **How many.** The ring's allowance, for every deck without New cards/day.
- **Which.** One queue over all decks that aren't paused. New words come newest addition first (`Card.created`: a later
  study day first; within a day as added, then deck order; `StudySession.newestAdditionFirst`). A word's Meaning → Word
  card opens when its Word → Meaning card is in the review phase with an interval of 7 days or more
  (`StudySession.unlockDays`, a constant). Opened Meaning → Word cards, the oldest learned word first, alternate with
  the new words one for one (`StudySession.alternatingUnlocked`).
- **Each deck's share.** The allowance is split over the decks without New cards/day from that one queue:
  `DailyGoal.split(_:overQueues:)` over each deck's `DailyGoal.NewQueue`, kept as
  `DeckActivity.History.newQueueToday`. Within a deck its own cards alternate the same way.
- **New cards/day** (`newCardsPerSession`, Anki's name, in Daily Limits; “—” by default, the ring decides) is the one deck option for new
  cards. A deck that sets it takes exactly that many new cards a day, of both directions, as in Anki: outside the
  allowance, and without reducing what the other decks get. A deck with it gets its own queue's count.
- **Gone options:** Meaning → Word New per day, Unlock after N days and Cards per session (a stream's segment is the
  constant `StudySession.segmentSize`, 100). New card order was already gone. A `deck.json` that holds the keys reads,
  and the next save leaves them out. `deck-from-tsv` keeps `--new-per-session`, which sets New cards/day, and drops
  `--new-production-per-session` and `--unlock-days`.
- **Beyond the day.** Learn 10 New Words goes beyond the allowance and New cards/day. Study These Now goes beyond
  New cards/day and counts against the allowance.
- **The rule behind it.** An Anki veteran gets the settings and mechanics they know, under Anki's names; the ring, the
  streak and the rest are cosmetics on top. A newcomer gets reasonable defaults: the machinery works without being
  noticed and asks for no attention. Mnemit's own knobs that Anki doesn't have are constants.

## Consequences

The Newcomer sets nothing: the ring decides how many new words come. The Course learner's lesson words go first the day
they are added, because the newest addition heads the queue, and the ring decides how many. The Anki veteran's history
comes in with the new cards in Anki's new-card order, and New cards/day does what it does in Anki.

The learner can say what decides the day's new cards: the allowance for a deck without the option, the option's number
for a deck with it. Which cards come is one order over all decks.

A Meaning → Word card of a word waits for its Word → Meaning card in every deck, with no way to hold it back or let it
through early. `references/ring-design.md` keeps the measure that would move the 7: the Forgot share of the first two
Meaning → Word reviews.

`DeckFile.currentVersion` stays. An older app that reads a deck saved by this one finds none of `cardsPerSession`,
`newProductionPerSession` and `productionUnlockDays` and uses their defaults.

## Later

The deck options screens took Anki's names, so an Anki veteran finds each setting where they expect it: Desired retention,
Leech threshold, Leech action (Keep Card, Suspend Card), Maximum interval, Learning steps, Optimize. The option
"Spread out intervals" went; `fuzzing` stays in the model, on. Maximum reviews/day joined New cards/day under Daily
Limits (`LearningOptions.maximumReviewsPerDay`, “—” by default): at most that many review-phase cards a study day, the
reviews already made today counted, the due ones beyond it waiting for the next days, the most urgent first. It touches
neither the new cards nor the cards in learning. Every option row has a "?" button with a popover of plain words for
a newcomer, and Restore Defaults puts the options back to their defaults, keeping the FSRS parameters and the pause.
