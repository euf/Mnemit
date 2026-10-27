# The Study screen on the iPhone: layout, motion, speech, swipe

`StudyView`. What the screen shows and does (header, rests, undo): `references/screens.md`, "Study
(the stream)"; the stream's logic: `references/scheduling.md`; the visual spec of the header, the grade
area and the card's type: `references/design-spec.md` §4.

## Layout

- All spacing comes from the `Spacing` scale in `Shared/Support/Presentation.swift` (4, 8, 12, 16,
  24 pt): 16 at the sides, 8 under the bar, 12 between the card and the buttons (plus the stack's room,
  4 × 8 pt, always) and under the buttons, 24 inside the card.
- Show Answer lies as an overlay on the grade block and takes its rectangle, so the card keeps its
  height when the answer opens. The block is two wide buttons side by side, Forgot (red) and Good (green), each as
  tall as two rows of buttons (2 × 50 pt and a 12 pt gap, scaled with the text); the setting "Hard and Easy Buttons"
  lays a later showing out as Forgot on a row of its own and Hard, Good and Easy in one row under it, Good wider
  (see "The answer buttons"). No caption stands between the rows. The three greens are one hue whose chroma rises
  from Hard (a dull sage) through Good (a soft mint) to Easy (a vivid jade), their lightness rising a little with
  it; each label is the lightest dark tint of the hue that reaches 7:1 (`Grade.swatch`, `GradeSwatch`; the values and
  their contrast: `design-spec.md` §5.2, `GradeContrastTests`).
- A touch on the card reveals the answer (`touch`: `DragGesture(minimumDistance: 0)` through
  `simultaneousGesture`). A touch that starts on a speaker belongs to the button: speakers
  (`SpeakButton`) report their frames into `SpeakerPlaces`, and the card's gesture lets such touches
  through (no answer, no swipe, no info sheet).
- The speaker next to the word (`SpokenWord`) takes the word's font and sits on its first baseline.
- No undo chip on the iPhone: Undo is the `arrow.uturn.backward` button left of the ⋯ menu
  (`StudyModel.canUndo`, the same condition as the menu item) and shake; the chip's room went to the
  card. `UndoChip` remains only on the Mac.

## The answer buttons

- Every showing has two buttons, **Forgot** (←, red) and **Good** (→, green); on a first showing (`Card.isNew`) they
  are named **Don't know** and **Know** (`Grade.buttonTitle(isNew:)`), in the same place and colours. The grades
  underneath are Again and Good. The receipt chip and its VoiceOver announcement use the same names
  (`GradeReceipt.isNew`). A first showing is asked like any card: question, Show Answer, the buttons, the same swipes
  and the same motion; a later showing reads Forgot (`scheduling.md`, "A new card's first showing").
- `GradeChoice.buttonGrades(isNew:showsFourButtons:)` is the one rule: `[again, good]`, or all four when the setting
  Hard and Easy Buttons is on (`@AppStorage("ShowsFourAnswerButtons")`, `GradeChoice.showsFourButtonsKey`, off by
  default, Settings) and the card is not new. A first showing stays two with the setting on.
- With the four: Forgot full width, under it Hard, Good and Easy in a `WeightedRow(weights: [1, 1.25, 1])`, Good
  wider. At the accessibility text sizes the buttons stack: Forgot over Good, or Forgot over Hard, Good and Easy, one under the other.
- iPhone landscape (`isCompact`, 44 pt): `GradeChoice(part: .forgot)` and `part: .recalled` stand in one row, Forgot
  beside Good (or beside Hard, Good and Easy).
- Swipes give all four grades whatever the buttons are: ← Forgot, → Good, ↑ Easy, ↓ Hard. A swipe toward a grade with
  no button lights nothing: `GradeChoice.lit` drops a `CardFlight.highlighted` grade that has no button, so the
  buttons stay as they are; the card's tint, the haptic and the receipt say the grade.

## The leech moment

- After the Forgot that brings a card to a leech moment (`scheduling.md`, "Leech") the stream stops before the next
  card (`SessionDriver.leechMoment`, `StudyModel.leechMoment`). `LeechMomentView` takes the card area's place
  (`StudyView.leechLayer`): the title "Keeps slipping", the card's question and answer revealed on `Color.cardSurface`
  (radius 22, 12 % hairline, 200 to 340 pt tall, full width), then **Continue** (`.borderedProminent`, large) over
  **Edit** and **Set Aside** (`.bordered`). When the review already suspended the card (the deck's leech action
  Suspend), the last button is **Keep It**, which resumes it. The Mac has the same view with the keys Return, E and S
  (`screens.md`).
- Continue goes on to the next card, or to the rest when the leech was the round's last card. Edit opens the edit
  sheet and goes on once it is saved. Set Aside and Keep It are one undoable step each, and go on.
- The bar stays; in its menu Undo works and the card's Edit, Info and Suspend are disabled while the moment shows.
  Undo takes back the grade, the moment and any suspension in one step. VoiceOver reads the title, the question, the
  answer, then the three actions, and is told the screen changed.
- No receipt says "leech, suspended"; the moment replaces it.

## Motion

- Every graded card leaves past the edge of the screen (`StudyMotion`, `StudyMotionViews`, `RingBurst`).
  The grade applies at once. The card goes on as a separate one (`Departure`, `DepartingCard`, a layer
  above the bar) from the pose it was released in, along `GradeSwipe.exit` until it is off the screen,
  while the next one is already on top and takes the next touch: nothing waits for a flight. Nothing is
  written on the departing card.
- The receipt decides what follows (`GradeReceipt.destination`):

  | Receipt | Destination | Once the card is off the screen |
  |---|---|---|
  | interval `.days(n)`, not a leech | ring | the deepest edge of the stack fades and the stack moves up a step; the ring in the bar steps, bumps (`ringBump`) and bursts (`RingBurst`, `StudyMotion.barBurstAt`); the interval shows beside it |
  | interval `.learning` (Forgot, a learning step) | stack | a blank sheet (`Sheet`) comes in by the edge the card left by and slides under the stack to its deepest edge, which it becomes; until then the stack lacks that edge (`StudyMotion.edges(cardsBehind:)`) |
  | no interval (practice), or a card the review suspended (the deck's leech action Suspend) | away | nothing |

  The ring's frame comes from the header (`onGeometryChange` in global coordinates,
  `StudyMotion.ringHome`), the card's place from the card (`cardSlot`); nothing is a constant of the
  screen.
- Each grade steps the ring in the bar at once by `GradeReceipt.gain` (the part of a card the grade
  added, 0 to 1), ahead of the figures, which wait for the card that speaks (`StudyMotion.shown`,
  caught up when the figures change and no card is leaving). Gain 0 (Forgot) moves nothing. The ring is
  empty inside (`StreamRing`) and goes on over itself past the goal, up to three laps
  (`DailyRingFigure.fraction`). The streak stands beside it (`StreakCount`: "🔥 12", the flame alone at 0 days; the
  flame is an outline until today's streak step is done, `flame.fill` in `Color.streak` from the moment it is),
  then the minutes to the next moment ("≈ 2 min"). The ring does not bump
  at the streak step: the burst is on the large flame in the title of the Streak kept rest, as the title
  comes in (`StreamRestView`, `flameBurstAt`). A medal bumps and bursts the ring as a card landing in it does
  (`StudyMotion.celebrate()`, called as the medal's toast shows). A done card
  also bumps the ring (scale 1.0 to 1.15 and back with a soft glow in the accent, `ringBump`, 0.12 s up
  and 0.18 s down) and plays a small `RingBurst` round it; a card back today steps it quietly, without
  bump or burst. No haptic accompanies the ring.
- The interval beside the ring: for a done card the text beside the ring shows
  `GradeReceipt.flightLabel` for 1.5 s, cross-faded, then its figures again: "tomorrow" for 1 day,
  `Format.interval` for the rest ("in 8 days", "in 3 months"). VoiceOver is told the same, since the text
  is gone in a moment: "Good, in 8 days", posted as an `AccessibilityNotification.Announcement`
  (`GradeReceipt.announcement`).
- Velocity: a swipe's flight starts with the finger's release velocity (`DragGesture.Value.velocity`).
  Each axis is a spring (`PathCurves`, `interpolatingSpring`, 0.45 s, no bounce) whose initial velocity
  is the finger's on that axis as a share of the distance left, so the card does not stop where it is
  let go and goes on along its grade's direction (an axis with no distance left, or no velocity, eases).
  A button or a key has none: x eases in and out, y eases in, 0.45 s. The card keeps turning the way it
  went. The flight is four numbers (across, down, smaller, faded), each by its own curve, so Undo can
  play it backwards and a test can freeze any instant.
- The stack (`CardStack`, `StackPose`, `Shared/Session/CardStackEdges.swift`): the edges of a book's pages, up to four (`StackPose.maxEdges`)
  by `StudyModel.cardsBehind`: the cards the round still asks less the one on top, those that come back
  today included (`SessionDriver.cardsLeftInRound`, from `RoundGuide`); none when 0 are left, without
  rounds, and in practice. An edge is a blank page of the card's shape (corner radius 22) under the
  card's bottom edge, its surface a shade darker than the card (0.035 × the level of the primary colour, so
  darker with depth; lighter in dark mode), a 1 pt hairline in the opaque separator colour, fainter with
  depth (1 − 0.18 per level beyond the first) and a soft shadow (black at 10 %, radius 3, 2 pt down).
  Each lies 8 pt lower and 7 pt narrower on each side than the one above (`StackPose.step`, `side`). The
  room under the card, 4 × 8 pt (`StackPose.reserve`), is always reserved, so the card keeps its size.
  The Mac draws the same pose with `StackEdges`. When the card on top leaves, the next one rises into its place
  from the pose of the first edge (a spring of 0.3 s, bounce 0.15) while its words fade in over 0.15 s.
  An edge that is lost or gained fades over 0.25 s while the stack moves up; the returning sheet
  becomes the edge it gains. When a round begins the edges spread out from under the top card, each
  0.05 s after the one above (a spring of 0.4 s, bounce 0.2).
- Undo plays it backwards (`StudyModel.undoReturn` says where the last step sent its card and whether
  the stream rests; `undoReceipt` says which grade it was): the card comes in from the edge it left by
  to the top, answer shown (`returnedByUndo`), ready to be graded again, silent; the ring takes back the
  grade's gain; a card that had gone under the stack takes its deepest edge with it for a moment. Across
  the end of a round the ring goes back up to the bar first, then the card returns. After a step that
  gave no grade (a suspension) the card rises in from the stack.
- At a round's end, as the last card goes past the edge, the ring in the bar comes down into the rest's
  ring place (`RingTraveler`, `ringPlace` on `StreamRestView`, 0.55 s: `StudyMotion`'s `travel`, a spring
  with a little bounce: 0.1 coming down, 0.05 going back up) at the rest's size (96 pt) as one motion and bursts on arrival. The place of the
  last card stays as an empty slot, a faint rounded outline (`SlotOutline`, 10 % of the primary colour);
  the rest screen holds only the ring's place, the ring itself is the one that travelled. Then the
  title, each line and the buttons come in one after the other, 0.1 s apart, each with a fade and a
  6 pt lift (`StreamRestView` with `staggers`). Keep Going, Catch Up and Push On take the ring back up
  (the lines fade, the stream moves on, and 0.3 s later the cards are dealt, the stack spreading out
  from under the top card edge by edge), so the card area is back while the ring is still on its way.
- The burst (`RingBurst`: the ring swells 1.0 → 1.12 → 1.0 in 0.4 s, and 12 specks of the accent,
  2.5 to 4 pt, fly out from the ring's edge by a third to two thirds of its diameter and fade by
  0.8 s; a `Canvas` in a `TimelineView`, drawn from the elapsed time alone) also plays for a
  words-in-memory milestone on Today, once per milestone (`MilestoneCelebration`): the glyph of the
  milestone line bursts the first time the line shows for it.
- Reduce Motion: no flight; the card stays where it is and fades out over 0.6 s, the ring steps without the bump, the swell or the glow, the stack count changes, the next
  card comes without rising, Undo's card is simply there, the rest cross-fades in and out with its own
  ring (the lines come in together, nothing travels), no grains.
- The stream takes the day's rounds from the ring's progress also after opening
  (`StudyModel.adoptRounds`: the ring is computed later than the stream; a boundary already passed is
  not taken back).
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

- A card is swiped once its answer shows (`GradeSwipe`, `CardFlight`, `StudyView.touch`). Four
  directions, one per grade, whether the buttons are two or four, the same as the arrows on the Mac: ← Forgot,
  → Good, ↑ Easy, ↓ Hard (`Grade.arrow`, `Grade.arrowSymbol`).
- Sectors: a dial of 15° sectors with zero at the top, clockwise (EF's diagram), compass degrees: Easy
  330°…45°, Good 45°…135°, Hard 135°…210°, gap 210°…240°, Forgot 240°…300°, gap 300°…330°.
- The vertical sectors are wider and reach toward the NE–SW diagonal: for a right-handed one-thumb user
  the vertical and the diagonal are fastest, the horizontal slowest and most precise (Trudeau et al.,
  Human Factors, 2012). Forgot stays 60°, Good an even 90°.
- Reference directions (the middle of each sector, where a finger that means the grade goes): Easy 15°
  (up and to the right), Good 90°, Hard 165° (down and to the right), Forgot 270°. Target directions
  (where the card is pulled and flies off to): Good 90°, Forgot 270°, Easy 60° and Hard 120°, that is
  30° above and below due east (`GradeSwipe.yesTilt`), so Easy and Hard fly toward Good's green side.
- The code measures the finger's angle counterclockwise from east, screen y up (math degrees = 90 −
  compass): `goodReach` 45, `easyEnd` 120, `forgotStart` 150, `forgotEnd` 210, `hardStart` 240 (Good
  −45°…45°, Easy 45°…120°, Forgot 150°…210°, Hard 240°…360 − `goodReach` = 315°); references
  `easyReference` 75, `goodReference` 0, `hardReference` 285, `forgotReference` 180; targets
  `easyTarget` 30 (`yesTilt`), `hardTarget` 330, Good's and Forgot's the same as their references;
  `exitDistance` 640. Every boundary, reference and target is a named constant of `GradeSwipe`, to be
  tuned there; `GradeSwipeTests`
  names the compass ranges.
- Forgot is the only "no", and Easy given for a forgotten card is the costly slip, so Forgot has a gap
  on each side (210°…240° and 300°…330°). Between two "yes" grades (right and up, right and down) there
  is no gap: a misread there is cheap.
- Gaps give no grade: no tint, no button highlight, no commit. The card travels `gapTravel` (half) of
  the finger's path, so it reads as "not a choice", and release brings it back, even past the commit
  distance and with a flick; a flick also has to start in a zone and end in one.
- The card follows the normalized mean of the finger's unit direction and the grade's target
  direction, at the finger's distance, from the dead zone on (`GradeSwipe.pull`): a finger straight up
  pulls it 30° right of up; a finger straight down 30° right of down; a finger straight left leaves
  it due west. An Easy card moves between 15° right of up (the far edge of the sector) and 52.5° right
  of up (the near edge), Hard the same downward, Good to the right. No sector lies more than 90° from
  its target, so the mean is always defined. Rotation and pivot are computed from the card's own offset.
  Tint, the lit button (when the grade has one) and the commit follow the recognized grade. Under the dead zone the card goes
  with the finger one to one.
- The tint (`Grade.tint`) covers the card at most 70 % and never changes the text colour. In light mode it
  is the grade's fill. In dark mode each green has its own darker tint (Hard 0x566F64, Good 0x40725E, Easy 0x1D7759,
  all L .51 to .52) and Again takes 0xD22727, a step below its fill: white text needs a ground darker than about
  L .5 on both card faces. The lit button's ring is `Grade.ring`: the grade's fill, except in light mode, where each
  green takes a deeper colour of its own hue that holds 3:1 on the light grey (Hard 0x729183, Good 0x56957B, Easy
  0x2A9C76; Again's red holds 4.3:1). The grade buttons show no "Recalled" caption.
- When the finger crosses into another zone or a gap, the card's way jumps; for 300 ms after a crossing
  a short interactive spring smooths it (`CardFlight.glide`: response 0.12 s, damping 0.85); the rest of
  the swipe is one to one.
- Commit distance 100 pt, dead zone 20 pt, flick 30 pt of travel and 300 pt of prediction
  (`GradeSwipe.commitDistance`, `deadZone`, `flickMinimum`, `flickReach`); the exit follows the
  target direction of the grade, 640 pt (`GradeSwipe.exit`); on the Mac the arrow keys and the buttons
  fly the card the same way (`CardFlight.fly`).
- One haptic per grade (`CardFlight.gradeFeedback`): a swipe feels it when it reaches the commit
  distance of a grade, so letting go now grades, and again only if it reaches another grade's; the card
  that flies on letting go adds none. A button, a key or a flick, which never reach the commit distance,
  feel it when the card flies. A gap has no haptic.
- The onboarding hint plays a finger step along the grade's reference direction
  (`GradeSwipe.reference(of:)`) through `CardFlight.drag`, so the card shows the way a real swipe would
  move it (Easy: the finger at compass 15°, the card at 37.5°, between the finger and the target at 60°). The order of the practice: `screens.md`, "First launch".
- `SwipeTally` (`Shared/Session`, `@MainActor`, in process memory) counts per study day the swipes that
  reached the commit distance or a flick, and of them those that sprang back from a gap
  (`GradeSwipe.endedInGap`). The Study screen releases a swipe through
  `SwipeTally.shared.released(translation:predictedEnd:)` instead of `GradeSwipe.released`, which
  returns the same grade; the Swipes section of How Today Works shows the count (`screens.md`).
