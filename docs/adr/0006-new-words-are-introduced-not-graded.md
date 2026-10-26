# A new word's first showing is an introduction, not a review

Status: superseded by ADR 0007.

In a vocabulary deck the first showing of a word is the learner's first contact with it. Until Mnemit
7 that showing was a question: the card asked for a meaning the learner had never seen, the answer
opened on a tap, and the four grade buttons were there. EF's review logs of 21–25 October 2026 hold
251 grades, all revealed: 30 % Forgot, 8 % Hard, 60 % Good, 2 % Easy. Most of the Forgots are first
showings of B1 words the learner had never met. The first contact with a word ended on a red button,
and the log recorded a failed recall of a card that nobody could have recalled.

## Decision

A deck has a mark, `LearningOptions.introducesNewCards`, shown as **Words in this deck**: **New words**
or **Words I know**. In a deck marked New words, the first showing of a card with no learning state
in a study stream is an introduction (`Session.isIntroduction`):

- The answer is open, the card's corner says "New word", and nothing is graded. The learner moves on
  with Next, a tap or a swipe in any direction (on the Mac Space, Return, an arrow or a click).
- Moving on writes no log entry, sets no learning state and takes no step of the stream, so Undo
  goes back to the last graded card (`StudyStream.introduce(duration:)`).
- The card leaves the rotation for three other cards (`SessionQueue.introductionGap`) and then comes
  back as an ordinary question, or next when no other card is left. Its first grade sets the FSRS
  initial state, as the first grade of any new card does.
- The time the card was on screen as an introduction is added to the `ms` of that first review
  (`Session.introductionTime`).
- A stream that ends between the introduction and the question leaves the card new; the next stream
  introduces it again. Practices never introduce. A card in learning or in the review phase is never
  introduced.

A deck marked Words I know asks its new cards at once, as before. The mark is asked once, when a deck
is made (New Deck, New words to begin with) or when an Anki package makes one (preset to Words I know
when the package has review history), and it sits in Options. A deck file without the key reads as
Words I know.

## Options considered

- **Record Good for the introduction** (swipe right) **and Again for a swipe left**, the first plan
  of `references/quality-plan.md`. A Good that no retrieval earned gives the card the initial stability
  of a success and a first interval to match, for a word the learner has only read once. The
  optimizer learns from first reviews, and it would learn that first contact succeeds.
- **Record Again for the introduction.** Every first showing becomes a failure: the card starts with
  the highest difficulty and the shortest stability, and the buttons the learner sees at the first
  contact are the red one first.
- **Leave the first showing a question.** The grade buttons stay, 30 % of the grades stay Forgot, and
  the log keeps recording failures that were never attempts.
- **A learning step for the introduction.** It adds a step to a card that the learner has not tried
  to recall, and takes the card's first grade away from the question that tests it.

## Consequences

The review log, and everything computed from it, holds real retrieval attempts. The first grade of a
new card is the answer to a question the learner had a chance to answer, three cards after having
read it. The optimizer's training examples, the retention tables and the replay of a log into FSRS
see no grade for a showing that asked nothing. The pace keeps the time: the introduction's seconds
count in the price of a new card through the first review's `ms`, so the day's time and "≈ 2 min to
keep your streak" still pay for reading the word.

The introduction is no step: the ring does not move, the session's total and its count of cards
done stay as they are (the card is still to do), and the streak step does not count it. A new card
counts against the day's new-card allowance when its first grade is logged, as before.

`introducesNewCards` is a new key in `deck.json`, written only while on. `DeckFile.currentVersion`
stays: an older app version drops the key on save and asks new words at once. A merge settles the
mark with the other learning options (`Deck.learningOptionsChanged`).
