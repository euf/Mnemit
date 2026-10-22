# In the fork, revealed reviews count in full

Mnemit studies with flashcards by default: on the iPhone the learner always reveals the answer, on
the Mac they do in "Flashcards" mode, the default. Nearly every review of the fork is therefore a
revealed one (`ReviewMode.revealed`). ADR 0004 damps them to a third of the stability gain, and the
optimizer (ADR 0002) takes only typed reviews as training examples. Both hit nearly all reviews here:

- The optimizer practically doesn't see the learner's reviews. The threshold of 400 training
  examples counts only reviews made on the Mac in "Typing" mode.
- Every Good lengthens the interval by only a third of what FSRS intends. At the same target the
  cards come more often than the model considers necessary.

Anki doesn't know the difference. There all reviews are self-graded, FSRS is trained on those grades,
and the target recall describes exactly those grades. The fork takes that over.

## Decision

An option per deck, `LearningOptions.revealedRecallWeight`, from 1/3 to 1, set to 1 by default in the
fork. It replaces the fixed factor of ADR 0004: a revealed review that recalls the card (Hard, Good,
Easy) keeps this share of the stability FSRS adds: `S' = S + (S_FSRS − S) · weight`. At 1 FSRS
computes unchanged. Again, a card's first review and difficulty stay untouched, as in ADR 0004.

The weight applies wherever ADR 0004 applies the factor: when grading (`Scheduler.memory`), when
recomputing from the review log (merge, new weights) and in the optimizer's model (`FSRSGradient`,
`FSRSOptimizer.evaluate`).

A second option, `LearningOptions.optimizeFromRevealed`, `true` by default: the optimizer takes
revealed reviews as training examples. Switched off, only typed reviews are targets, as before;
revealed ones then count only in the history of later examples.

Both options are on the Mac under "Learning Options", the weight under "Advanced", the switch next to
computing the parameters. The options get no new file format; see Consequences.

## Rolling back

In Learning Options set the weight to 0.33 and switch off "Learn from revealed reviews". The weight
snaps to exactly 1/3 at 0.33 (`revealedRecallWeightRange`), and both options together give the
behaviour of ADR 0004 and ADR 0002. On saving, the app recomputes stability and difficulty of every
card with a complete review log; due dates stay. The same recomputation runs when merging with a
version saved with a different weight.

## Options considered

- **Keep the damping to a third.** The number is set, not measured (ADR 0004). Under Anki's
  conditions it has no grounds, since there is no review mode there, and for this learner it slows
  down nearly every review.
- **Estimate the weight from the review log.** With `FSRSOptimizer.evaluate`, weights such as 1/3,
  1/2, 2/3 and 1 could be compared on one's own data. That needs weeks of data and a statistic of the
  actual rate (backlog in `references/anki-parity.md`, item 2). The option makes this comparison
  possible without demanding it now.
- **Allow a weight below 1/3 too.** Below a third a Good barely lengthens intervals at all; then it
  would be better not to schedule revealed reviews at all.
- **Only `optimizeFromRevealed`, without a weight.** The optimizer would then learn from reviews
  whose model assumes a different stability than the scheduler applies.

## Consequences

No new file format: both options are new keys in `deck.json`. Where they are missing, the fork's
defaults apply, that is weight 1 and the optimizer with revealed reviews. Older app versions drop the
keys on save, damp with their fixed third and train on typed reviews until a newer version writes the
document again; both devices therefore run from the same state.

Existing cards carry the stability computed with a third until their review log is recomputed (new
parameters or a new weight on saving the options, a merge with another version). New reviews compute
with the options' weight at once. The optimizer always runs through the review log with the options'
weight.

At weight 1 the optimizer computes like fsrs-rs: the tests against the reference values
(`Tools/fsrs-reference`) run unchanged, because their reviews are typed.
