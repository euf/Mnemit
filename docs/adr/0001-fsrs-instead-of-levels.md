# FSRS instead of levels

MacVocTrain NG schedules reviews with FSRS-6 instead of the levels of MacVocTrain 1. Every card has
a learning state with stability and difficulty; its interval is the number of study days until its
recall probability falls to the target recall. The memory model is ported from py-fsrs, the
reference implementation of open-spaced-repetition.

## Options considered

**Keep the levels.** A level fixes the next interval: 0.7 days at level 1, 22 days at level 12, then
3.52 days more per level. That is easy to understand, and MacVocTrain 1 documents could be taken over
without translation. Against it:

- All cards on one level get the same interval, up to a spread of ±10 %, however hard they are for
  the learner.
- From level 12 the intervals grow only linearly; an interval over 100 days comes only from level 35.
  Cards that have long been firm therefore come up very often.
- A wrong response resets any card to level 0, even one the learner has known for months.
- Levels know no recall probability: a target recall can't be set, and whether a review came early
  or late changes nothing about the next interval.

**SM-2, as Anki used to.** Every card has its own factor by which its interval grows. That fixes the
first two points. Against it:

- SM-2 knows no recall probability either, and so no target recall.
- The factor drops with every lapse and every Hard but rises only with Easy. A card that was hard
  once therefore comes up more often than it needs to, for good.
- In the open-spaced-repetition benchmark FSRS predicts recall probability much more accurately than
  SM-2; Anki has offered FSRS itself since version 23.10.

**FSRS-6 (chosen).** FSRS estimates stability, difficulty and recall probability for every card and
learns from all four grades. The interval follows from the target recall the learner sets per deck.
FSRS works with the time that actually passed since the last review, and a lapse lowers stability
without setting it to zero. The model's 21 weights can be fitted to the learner's memory.

## Ported from py-fsrs

Only the memory model is taken over (`FSRS.swift`): how stability and difficulty change with each
grade, plus the default weights. That is a few formulas; a test compares them with py-fsrs's
reference values. The flow around the model, that is phases, steps and due dates, is the
`Scheduler`'s own, because here the app departs from py-fsrs: a step is a Good within the session,
not a waiting time, and intervals count in study days. The memory model is enough for that, and
`VocabCore` needs no dependency.

## What the app gives up

- **Transparency.** From the level the learner could read the next interval. Stability and
  difficulty are a model's estimates; maturity therefore sums up stability in a few grades.
- **Grading by the app.** MacVocTrain 1 decided itself whether a response was known; the learner
  could only accept a wrong response anyway. FSRS needs one of four grades. The check result suggests
  one, but only the learner knows whether Hard or Good fits.
- **An easy way back.** Learning state and progress rest on stability; the daily snapshots count
  cards by their stability. Another method would have to translate them, as the import translates
  the levels today.
- **Own weights, for now.** At first the app computed only with open-spaced-repetition's default
  weights. The review log records every review with its time and grade, so the weights can later be
  fitted to the learner. Done by [ADR 0002](0002-optimizer-as-swift-port.md): since then the app can
  compute the weights from a deck's review log; every deck starts with the default weights.

## Import from MacVocTrain 1

The import (`LegacyImporter`) translates each level so that the card is due exactly when MacVocTrain
1 would have asked it:

- Cards never asked become new cards.
- Level 0 means "not known": the card goes into Relearning and is due at once, with stability and
  difficulty as after a first Again. It counts one review.
- From level 1 the card goes into the review phase. Its stability is its level's interval including
  the ±10 % spread MacVocTrain 1 stored per card; it is due that interval after its last review.
  Difficulty is unknown and starts neutral at 5. The level counts as its number of reviews.
- The import clamps values from damaged documents so the deck can be saved, opened and studied. The
  interval including the spread is at most the longest interval of the new deck's learning options
  (36,500 days); the `Scheduler` never plans longer either. At most the level that reaches this
  interval counts as the number of reviews. A last review after the import, before 2001 or without a
  finite time counts as made at the import: MacVocTrain 1 wrote its documents with
  `NSKeyedArchiver`, which exists only since Mac OS X 10.2.
- The daily counters per level become the progress: each level counts in the daily snapshot with the
  stability of its interval, without spread. In MacVocTrain 1 level 0 counted new cards and cards after
  a wrong response together; the import therefore splits the counter by estimate. At most as many cards
  count as new as were never asked at the import, the rest as shaky. A card never asked at the import
  was never asked on any earlier day it existed either: on the last old day the split is exact, so it
  makes no jump on the import day. On days before these cards were created, cards after a wrong response
  count as new instead.
- The app builds the import day's daily snapshot from the cards themselves. Cards from level 1 count
  there with their spread. If the spread pushes a card's stability over one of the daily snapshot's
  boundaries (1, 2, 4, 8 … days), the card counts in a different range on the import day than on the
  last old day, and at 4, 16, 64 and 256 days with a different maturity too: a card on level 10 (15.5
  days) with +5 % counts as Young on the last old day and as Maturing on the import day.

Stability is the number of days until recall probability falls to 90 %. The import therefore assumes
the learner still knew a card at its MacVocTrain 1 date with about 90 %. Where that isn't so, the first
reviews correct stability and difficulty.
