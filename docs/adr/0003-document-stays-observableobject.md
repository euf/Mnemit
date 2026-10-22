# The document stays an ObservableObject

`VocabularyDocument` is an `ObservableObject`, although the view models and `DueCardCounter` use
`@Observable`. Whoever wants to hear about the deck takes one of two channels: views observe the
document with `@ObservedObject` and get `objectWillChange` **before** every change. All other
observers, today `SessionViewModel` and `DueCardCounter`, listen to `deckDidChange`, which sends
**after** every change, when `deck` holds the new state. The rule is in `VocabularyDocument`'s
documentation (#83).

## Options considered

**Observation throughout.** The deck would live in an `@Observable` model owned by the document.
Views and view models would observe that model, and Combine would go. Against it:

- The two moments remain. SwiftUI needs the notice before the change, `SessionViewModel` needs the
  state after it: it checks whether the card being asked still exists. That comes from the observers,
  not from the mechanism.
- Up to macOS 14, Observation notifies only before and only once (`withObservationTracking`). A
  continuous channel after the change (`Observations`) exists only from macOS 26. For observers
  outside views the model would therefore need its own list of callbacks, a rebuilt
  `PassthroughSubject`. Two mechanisms would remain.
- `ReferenceFileDocument` requires `ObservableObject`. The document would stay one, just without
  notices of its own: one more layer between view and deck.
- Observation wouldn't get finer. The model would have a single property `deck`; every change would
  reach everyone who reads the deck, as today.

**Two channels in the document (chosen).** The document notifies through `objectWillChange` and
`deckDidChange`; the rule above sets which observer takes which. That costs Combine and Observation
side by side but needs no mechanism of its own and no extra layer.

## When to decide again

When the deployment target reaches macOS 26: then `Observations` provides the channel after the
change, and an `@Observable` model would work without callbacks of its own. Until then, an
architecture review that objects to the two channels is to be pointed to this ADR.
