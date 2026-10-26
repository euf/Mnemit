# A new card's first showing is asked like any card, and its Forgot reads "Don't know"

Status: supersedes ADR 0006.

## Context

ADR 0006 made the first showing of a new word an introduction that records nothing, for decks
marked New words: the answer open, Next instead of the grades, the card asked as a question three
cards later. The reason was the red "Forgot" on first contact: of 251 grades in EF's logs of
21–25 October 2026, 30 % were Forgot, most of them first showings of B1 words that the learner had
never met.

`references/first-exposure-research.md` weighed that design against the others:

- **What FSRS does with the first grade (§2).** The first grade of a new card sets the initial
  stability S0 and difficulty D0, and it is no lapse. The FSRS defaults were fitted on Anki
  collections, where a word unknown at first sight is graded Again: D0 = 6.41 for Again encodes "not
  in memory at first sight". Anki-native, an unseen word learned in one exposure gets Again (S0 0.21
  d) and a same-day Good a minute later: S about 0.25 d, tomorrow. With an introduction the first
  grade is a Good a few cards after reading: S0 2.31 d, D0 2.11, review in about two days. S0(Good)
  was fitted on cold first reviews a learner recalled, mostly words known before, so it likely sets
  the first interval too long for a word seen minutes ago, until the deck's refit learns the
  introduced deck's own S0.
- **Learning science (§3).** The choice between a cold first question and a first introduction does
  not change how well the word is learned.
- **Verdict (§4).** The two differ in how the first contact feels and in whether the first grade
  means what FSRS's parameters assume. Asked cold, with the first Again shown as "Don't know", FSRS
  gets the data its defaults were fitted on, every deck works the same per card, and no deck setting
  and no extra showing is needed. The red word "Forgot" on a card that was never learned is what
  goes, with the label.

## Decision

- A new card is asked on its first showing like any card: question, Show Answer, the four grades.
  A study stream has no introduction; `LearningOptions.introducesNewCards` and the deck mark
  (Words in this deck: New words / Words I know) do not exist. A `deck.json` that still has the key
  reads, and saving it leaves the key out.
- The grade underneath is unchanged: ← and the left swipe give Again, the button keeps its place and
  its red. Only its name depends on the card: **Don't know** while the card has no learning state
  (`Card.isNew`), **Forgot** on every showing after the first. The rule is `Grade.buttonTitle(isNew:)`
  and is used by the grade button, the receipt chip and its VoiceOver announcement, the iPhone Card
  Detail history and the Mac inspector's history (the Again of a card's first log entry reads Don't
  know). The onboarding keeps teaching ← Forgot.
- A first Again puts the card into its learning step; it comes back in the same session and, being
  no longer new, its Again reads Forgot.
- How It Works says it in one sentence: a new card is asked the first time it comes up; if the
  learner has never seen the word, Don't know is the honest answer, and the card comes back in the
  session.

## Consequences

FSRS sees exactly the data Anki gives it: a first Again for a word nobody knew, then a Good or two.
The log holds a grade for every showing, each one a real attempt at retrieval or an honest "no". The
optimizer, the retention tables and the replay of a log into FSRS need no case for ungraded
showings. Every deck works alike, so an Anki veteran's habit of pressing Again on an unseen word
carries over, and a newcomer reads the button as an answer to the question instead of a failure.

A first Again is no lapse: `Scheduler` counts a lapse only in the review phase, so a deck's lapse
counts and leech threshold see no failure in a word that was never learned.

`DeckFile.currentVersion` stays. An older app version that reads a deck saved by this one finds no
`introducesNewCards` key and asks new cards at once, which is what this version does.
