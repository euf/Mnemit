# The optimizer as a Swift port of fsrs-rs

The app computes the 21 weights of FSRS-6 from a deck's review log itself. The optimizer is ported
from fsrs-rs, version 6.6.2, the last release that knows only FSRS-6. It lives in
`VocabCore/Optimization` and, like the memory model, needs no dependency.

## Options considered

**Bind fsrs-rs.** fsrs-rs is the optimizer Anki uses too; the weights would come straight from the
reference. Against it:

- The crate has no C interface. The standalone C bindings (`fsrs-rs-c`) are stuck at version 5.2,
  and there are no Swift bindings. The app would need its own C wrapper with a header.
- The build would need a Rust toolchain and a universal library for arm64 and x86_64, and `VocabCore`
  would lose its freedom from dependencies.
- fsrs-rs's `main` is moving to FSRS-7 and changing FSRS-6's hyperparameters along the way. The app
  would have to pin a version and maintain it itself.

**Swift port (chosen).** Since version 6 fsrs-rs computes the gradients by hand (`analytic.rs`)
instead of with an automatic differentiation framework. The port therefore needs only arithmetic:
build training examples, drop outliers, pretrain the initial stabilities, then Adam with cosine
annealing, an L2 term toward the start values and fixed bounds per weight. That is a few hundred
lines. The amounts are small: a deck with a few thousand reviews is computed in a fraction of a
second.

## Fidelity to the original

All hyperparameters of 6.6.2 are taken over: 5 epochs, batches of 512, learning rate 0.04, Adam with
β = (0.9, 0.999), at most 256 reviews per example, weighting of newer reviews, and the bounds per
weight. Departures:

- **Double instead of single precision.** fsrs-rs computes the forward pass in `f32`; the port uses
  `Double` throughout.
- **Its own random generator.** fsrs-rs shuffles the batch order with `StdRng`, the port with
  `SeededRandom`. With more than 512 examples the weights therefore differ slightly. A test compares
  both on a made-up data set: with a single batch to a few digits, with batches of 512 by the quality
  of the prediction. `Tools/fsrs-reference` produces the reference values.
- **Study days instead of calendar days.** The intervals of the training examples count in study
  days, as everywhere in the app. fsrs-rs also works with a day change the caller sets; Anki, like the
  app, uses 4 am.
- **Steps are reviews on the same day.** The number of steps enters the bounds of w17 and w18 as
  `num_relearning_steps`.

## Which reviews count

A training example is every typed review that took place on a later study day than the previous
review of the same card, together with all reviews before it (see ADR 0004; in the fork revealed
reviews count as training examples too, ADR 0005). Reviews on the same day enter only as history.
Cards from MacVocTrain 1 lack the review log before the import; they don't count. A complete review
log is recognised by having as many entries as the learning state counts reviews.

The app offers the computation only from 400 training examples. fsrs-rs itself trains from 64
examples and below that fits only the initial stabilities; open-spaced-repetition's recommendation,
though, is a few hundred reviews.

## What happens on accepting

The app shows log loss and RMSE of the old and the new weights on the same training examples and
accepts only if the new ones predict better. With the new weights it recomputes stability and
difficulty of every card with a complete review log from that log. Due dates stay as they are; the
new intervals apply from the next review. The same happens on a reset to the default weights.
