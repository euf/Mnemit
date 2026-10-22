# Revealed reviews bring a third of the stability gain

On the Mac the learner types the answer; on the iPhone they reveal it and grade themself. Both
reviews land in the same review log. FSRS knows only the grade, not the review mode, and counts every
Good the same. Revealing imprints less than typing, though, and after revealing one tends to grade
oneself too well. After revealed reviews the intervals would therefore be too long; only a later
lapse on the Mac corrected that (#268).

## Decision

A revealed review in which the card is recalled (Hard, Good, Easy) keeps a third of the stability
FSRS adds: `S' = S + (S_FSRS − S) / 3`. If stability drops, FSRS's value applies. Again counts in
full: whoever didn't know the answer didn't know it. FSRS computes difficulty and initial stability
unchanged.

The share is `ReviewMode.stabilityGainShare`. It applies when grading, when recomputing from the
review log (merge, new weights) and in the optimizer. The optimizer doesn't take revealed reviews as
training examples, because their grade is too optimistic; in the history of later examples they count
damped.

The third is set, not measured. The review log stores the review mode, so the share can be checked
against one's own data later.

## Options considered

- **Change nothing.** FSRS corrects itself through later mistakes, but only at the price of more
  forgetting.
- **Revealed reviews don't change the schedule**, like the practice of mistakes on the Mac. Then
  studying on the go wouldn't count at all.
- **Count Good as Hard.** Simple, but Hard raises the card's difficulty for good.
- **Type on the iPhone too.** Contradicts the iPhone app's purpose of quick study in between.

## Consequences

No new file format: the review mode is already in `reviews.jsonl`. Existing cards take on the damping
as soon as their review log is recomputed. Older app versions compute without damping; if a device
with an older version merges, its result applies until a newer version recomputes the review log.

## In the fork

Mnemit replaces the fixed third with the option `revealedRecallWeight` (1/3 to 1, default 1) and lets
the optimizer learn from revealed reviews: ADR 0005.
