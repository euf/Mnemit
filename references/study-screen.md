# The Study screen on the iPhone: layout, motion, speech, swipe

`StudyView`. The stream's logic: `references/scheduling.md`; the visual spec:
`references/design-spec.md` §4.7.

## Layout

- All spacing comes from the `Spacing` scale in `Shared/Support/Presentation.swift` (4, 8, 12, 16,
  24 pt): 16 at the sides, 8 under the bar, 12 between the card and the buttons (plus the stack's room,
  3 × 6 pt, always) and under the buttons, 24 inside the card.
- Show Answer lies as an overlay on the grade block and takes its rectangle, so the card keeps its
  height when the answer opens.
- A touch on the card reveals the answer (`touch`: `DragGesture(minimumDistance: 0)` through
  `simultaneousGesture`). A touch that starts on a speaker belongs to the button: speakers
  (`SpeakButton`) report their frames into `SpeakerPlaces`, and the card's gesture lets such touches
  through (no answer, no swipe, no info sheet).
- The speaker next to the word (`SpokenWord`) takes the word's font and sits on its first baseline.
- No undo chip on the iPhone: Undo is the `arrow.uturn.backward` button left of the ⋯ menu
  (`StudyModel.canUndo`, the same condition as the menu item) and shake; the chip's room went to the
  card. `UndoChip` remains only on the Mac.

## Motion

- Every graded card leaves past the edge of the screen (`StudyMotion`, `StudyMotionViews`, `RingBurst`). The
  grade applies at once. The card goes on as a separate one (`Departure`, `DepartingCard`, a layer above the
  bar) from the pose it was released in, along `GradeSwipe.exit` until it is off the screen, while the next
  one is already on top and takes touches. Nothing is written on it.
- The receipt decides what follows (`GradeReceipt.destination`). Done (`.days`, no leech): the deepest edge of
  the stack fades and the stack moves up a step, the ring in the bar steps, bumps (`ringBump`) and bursts
  (`RingBurst`, `StudyMotion.barBurstAt`), and `GradeReceipt.flightLabel` ("tomorrow", "in 8 days") replaces
  the figures beside the ring for 1.5 s, cross-faded. Back today (`.learning`): once the card is off the
  screen, a blank sheet (`Sheet`) comes in by the same edge and slides under the stack to its deepest edge,
  which it becomes; until then the stack lacks that edge (`StudyMotion.edges(cardsBehind:)`).
- Each grade steps the ring by `GradeReceipt.gain` at once (`StudyMotion.shown`, ahead of the digits until
  the figures change and no card is leaving); gain 0 (Forgot) moves nothing, a card back today steps it
  without bump or burst. The figures: "≈ 4 min" while the goal is open, "36 cards today" once met.
  VoiceOver gets the interval as an announcement (`GradeReceipt.announcement`).
- Finger velocity (`DragGesture.Value.velocity`) enters each axis's spring (`PathCurves`); a button or
  key uses ease-in.
- The stack (`CardStack`): the edges of a book's pages, hairline outlines (1 pt, the card's corner radius,
  separator colour, fainter with depth) under the card's bottom edge, each 3 pt lower and 2 pt narrower per
  side than the one above, up to five by `StudyModel.cardsBehind` (`SessionDriver.cardsLeftInRound`, from
  `RoundGuide`). The next card rises from the first edge's pose; its words fade in over 0.15 s.
- Undo plays it backwards (`StudyModel.undoReturn`, `undoReceipt`): the card comes in from the edge it left
  by, answer shown (`returnedByUndo`), silent; the ring takes back the grade's gain; a card that had gone
  under the stack takes its deepest edge with it for a moment.
- At a round's end, as the last card goes past the edge, the ring descends from the bar into the card's
  empty place (`RingTraveler`, `ringPlace` on `StreamRestView`), bursts on arrival, and the rest lines come in
  one by one, 0.1 s apart. Keep Going sends the ring back up and deals the stack again.
- The burst (`RingBurst`: swell 1.0 → 1.12 → 1.0 and 12 grains over 0.8 s) also plays for a words-in-
  memory milestone on Today, once per milestone (`MilestoneCelebration`).
- Reduce Motion: the card fades in place over 0.6 s, the ring steps without swelling, the
  rest screen cross-fades, no grains.
- The stream takes the day's rounds from the ring's progress also after opening
  (`StudyModel.adoptRounds`: the ring is computed later than the stream; a boundary already passed is not
  taken back).
- State frames: `VocTrainTests/StudyScreenSnapshotTests` (the path is the environment variable
  `TEST_RUNNER_STUDY_SHOTS_DIR` of the xcodebuild process; as an argument it doesn't arrive). Pixel
  measurements: `SpeakerAlignmentTests` and `PixelBitmap`.

## Speech window

- A card with a Greek question speaks `GreekSpeech.settleDelay` (0.4 s) after appearing; a Greek answer
  `revealDelay` (0.25 s) after being shown. A word takes about a second, and while it plays or is being
  prepared, the main thread and the CPU belong to the voice.
- Whatever can wait waits for `GreekSpeech.whenQuiet()` (`isBusy`: a card waiting or an utterance in
  flight, from the synthesizer's `didFinish`/`didCancel`; no longer than `quietLimit`, 4 s): the ring
  computation after a review (`DailyRingModel.refresh`), saving (`SaveScheduler`), the widget snapshot
  (`WidgetSync`) and, on the Mac, the undo chip leaving (`UndoChip`).
- New work after a review either joins this list or holds the main thread under 16 ms.
- Card, ring and stack flights are layer transforms drawn once; the main thread keeps one modifier per
  frame.
- Off the main thread: encoding the deck on save (`DeckFileDocument` hands a snapshot out of
  `contents(forType:)`, `writeContents` writes it) and writing the widget snapshot to the keychain.
- `AVSpeechSynthesizer` is touched only when an own utterance is in flight: its `isSpeaking` and
  `stopSpeaking` wait for the process's speech thread.
- `cardAppeared` arrives once per card: `questionNumber` grows by one with each move
  (`everyMoveToACardCountsOnce`); in the measurement that is the asks column.
- The ring gradient (`GradientGenerator`) is computed once per size and colours and keeps four images:
  the bar's small ring and the rest screen's big one sit side by side.
- Measurement: `SpeechWindowStallTests`. A copy of a deck from iCloud Drive, a 5 ms timer on the main
  queue, windows 0.3–2.0 s after a review and 0.25–0.9 s after revealing the answer, budget 16 ms;
  `TEST_RUNNER_MNEMIT_PERF=1` (`report` doesn't fail; `TEST_RUNNER_STALL_REPORT` is the report file).
  `StallTrace` names the work that ran during a stall. The simulator is faster than an iPhone 13 mini,
  Release is closer to the device than Debug, and the synthesizer's own sound is invisible to the
  measurement.

## Swipe

- `GradeSwipe`, `CardFlight`: four directions, the same as the arrows on the Mac: ← Forgot, → Good,
  ↑ Easy, ↓ Hard.
- Sectors: a dial of 15° sectors with zero at the top, clockwise (EF's diagram), compass degrees: Easy
  330°…45°, Good 45°…135°, Hard 135°…210°, gap 210°…240°, Forgot 240°…300°, gap 300°…330°.
- The vertical sectors are wider and reach toward the NE–SW diagonal: for a right-handed one-thumb user
  the vertical and the diagonal are fastest, the horizontal slowest and most precise (Trudeau et al.,
  Human Factors, 2012). Forgot stays 60°, Good an even 90°.
- Reference directions: Easy 15° (up and to the right), Good 90°, Hard 165° (down and to the right),
  Forgot 270°.
- The code measures the finger's angle counterclockwise from east, screen y up (math degrees = 90 −
  compass): `goodReach` 45, `easyEnd` 120, `forgotStart` 150, `forgotEnd` 210, `hardStart` 240 (Good
  −45°…45°, Easy 45°…120°, Forgot 150°…210°, Hard 240°…315°); references `easyReference` 75,
  `goodReference` 0, `hardReference` 285, `forgotReference` 180; `exitDistance` 640. Every boundary and
  reference is a named constant; `GradeSwipeTests` names the compass ranges.
- Gaps give no grade: no tint, no button highlight, the card travels `gapTravel` (half) of the finger's
  path, and release brings it back, even past the threshold and with a flick. There are no gaps between
  Good, Easy and Hard.
- The card follows the normalized mean of the finger's unit direction and the grade's reference
  direction, at the finger's distance (`GradeSwipe.pull`): a finger straight up pulls it 7.5° right of
  up; a finger straight left leaves it due west. An Easy card moves between 7.5° left and 30° right of
  up, Hard the same downward, Good to the right.
- On a change of zone or gap a short spring smooths it (`CardFlight.glide`, 300 ms).
- Threshold 100 pt, dead zone 20 pt, flick 30 pt of travel and 300 pt of prediction; the exit follows
  the reference direction.
- The onboarding hint plays a finger step along the grade's reference direction
  (`GradeSwipe.reference(of:)`) through `CardFlight.drag`.
- `SwipeTally` (`Shared/Session`, `@MainActor`, in process memory) counts per study day the swipes that
  reached the threshold or a flick, and of them those that ended in a gap (`GradeSwipe.endedInGap`). The
  Study screen releases a swipe through `SwipeTally.shared.released(translation:predictedEnd:)` instead of
  `GradeSwipe.released`, which returns the same grade; "How Today Works" shows the Swipes section "N of
  M today".
