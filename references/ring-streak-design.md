# Ring and streak: what other apps put inside a ring, and a model for Mnemit

Research of 26.10.2026 for the owner's three remarks: the middle of the widget ring (flame plus days) is overloaded;
the Mac shows the big ring on Today and on Progress at different sizes; the entities of the ring and the streak may
want a rethink. Facts first (§1), the user's model and where the design confuses it (§2), options (§3), verdict (§4).
The rules as built: `quality-plan.md` §4, `daily-ring.md` (Done card, Streak), `design-spec.md` §5.7.

## 1. References

(M) = from memory of the app's screen; the page cited gives the rule or the numbers, not the layout. Not covered
for lack of budget: Apple's Battery and Screen Time widgets, Calm.

| Product | What the ring means | What is inside | Where the streak or number lives | Source |
|---|---|---|---|---|
| Apple Activity rings | Move, Exercise, Stand: today's progress to three goals | Nothing (M); the element is three rings and a black ground | Labels and values beside the rings in the ring's colour. Streaks are awards: "Longest Move Streak" in the Awards tab, not on the rings. Pause Rings keeps the streak | [HIG activity rings](https://developer.apple.com/design/human-interface-guidelines/activity-rings), [Apple Watch support](https://support.apple.com/guide/watch/track-daily-activity-apd3bf6d85a6/watchos), [Cult of Mac](https://www.cultofmac.com/how-to/apple-watch-activity-rings) |
| Apple Activity complication, iPhone Fitness | The same rings, small | Nothing (M) | Numbers in a text row beside them (M); the watch face offers rings as a complication to read "at a glance" | [Close Your Rings](https://www.apple.com/watch/close-your-rings/), [Fitness summary](https://support.apple.com/guide/iphone/see-your-activity-summary-iph4c34a8a95/ios) |
| WidgetKit gauges (`accessoryCircular`, complication circular) | A closed gauge is a value as a percentage of a whole | One item: the closed-gauge layouts come as "text" or "image", never both | The widget family is "a very limited amount of information"; a streak needs another family or a text line | [HIG complications](https://developer.apple.com/design/human-interface-guidelines/complications), [HIG widgets](https://developer.apple.com/design/human-interface-guidelines/widgets), [WWDC22 10051](https://developer.apple.com/videos/play/wwdc2022/10051/) |
| Lock Screen rendering | Any widget | Vibrant mode "desaturates text, images, and gauges": colour does not survive | State must be a shape or a word | [HIG widgets](https://developer.apple.com/design/human-interface-guidelines/widgets) |
| Duolingo | No ring. A daily goal (lessons or XP) is a separate progress element; the streak is a flame | Flame and the day count; the widget adds the owl | Flame plus number, on every surface including the widget. Since 2019 one lesson extends the streak, the daily goal is separate | [Duolingo blog](https://blog.duolingo.com/improving-the-streak), [widget teardown](https://duolingo.deconstructoroffun.com/mechanics/streaks) |
| Streaks (Crunchy Bagel) | Per task, a circle around the task's icon fills with the day's count (M) | The task's icon, not a number (M) | The streak count sits outside the circle (M). As of Streaks 6 its widgets cannot complete a task | [streaks.app](https://streaks.app/), [MacStories](https://www.macstories.net/reviews/streaks-6-brings-habit-tracking-to-your-home-screen-with-extensively-customizable-widgets/) |
| Headspace | No goal ring; a "run streak" of days | A number | A small count; Headspace calls it encouragement, "not about the number"; two sessions 8 h apart count as two days | [Headspace article](https://www.headspace.com/articles/building-a-meditation-practice), [help](https://help.headspace.com/hc/en-us/articles/215730567-How-does-the-run-streak-feature-work) |
| GitHub | A grid of days, no ring | Nothing | The streak counter was removed from profiles in May 2016; the grid stayed | [freeCodeCamp](https://www.freecodecamp.org/news/dont-break-the-chain-why-github-s-streaks-will-be-sorely-missed-by-many-4fff90bc2a38/) |
| Oura, Whoop, Garmin | A score from 0 to 100 (Garmin Body Battery 5 to 100; Whoop in green, yellow, red bands) | The score itself (M): the number is the quantity the ring draws | There is no streak; the score is the only number | [Oura Readiness](https://support.ouraring.com/hc/en-us/articles/360025589793-Readiness-Score), [scales compared](https://www.sensai.fit/blog/garmin-body-battery-vs-whoop-recovery-vs-oura-readiness-how-calculated-2026) |

What the table shows:

1. A ring either has nothing inside (Activity) or holds the ring's own quantity (scores, gauges). No product puts a
   second quantity in it. Mnemit's ring draws cards and its middle holds days.
2. A streak is its own object in every product that has one: a flame and a number (Duolingo), an award (Apple), a
   text count (Headspace), or gone (GitHub). It is never the middle of the day's progress ring.
3. Duolingo's streak had required the daily goal and was decoupled in 2019: the streak asks one lesson, the goal is
   shown apart. Learners on a 7+ day streak rose by over 40 % and Day 14 retention by 3.3 %; the blog also
   records "fewer learners were actually reaching their daily goals". Mnemit's streak step under the ring
   is the same split; the data supports the rule and says the ring then closes less often.
4. HIG on Activity rings: "Differentiate other ring-like elements from Activity rings." Mnemit's single indigo
   ring with a gradient head is already distinct; the design spec records this advice and the owner's choice.

## 2. The model, and where the design confuses it

The entities a learner can hold, in the words the screens use:

| Entity | One sentence | Unit | Lives in |
|---|---|---|---|
| Daily goal (the ring) | Today's cards; fills during the day, full at the goal | cards | Today, rest, stream header, widgets |
| Streak | Days in a row on which the first round was done | days | one place per surface |
| Streak step | The first ~2 minutes of today's plan; never shown as a number | minutes | the title "≈ 2 min to keep your streak" |
| Words in memory | The gain; the ring's cards are the work | words | the gain line, Progress |
| Week rings, medals | History of rings; milestones | days | Today, Progress |

Confusions the current design invites (frames of 23 to 26.10):

1. **The flame and the ring look like one meter.** The flame sits inside the ring, so a learner reads the ring as
   the streak's progress bar. The flame lights at the streak step (e.g. 5 of 20 cards), while the ring is still a
   quarter full. Two thresholds, one picture, and the lit flame reads as "ring done".
2. **The ring has two bars.** On a normal day the title says "≈ 3 min to keep your streak" (the step). On the day after a
   missed one it says "Close the ring to save your 7-day streak" (the whole goal). The same ring is asked for
   different amounts on different days, with no sign of which.
3. **Two units in one glyph.** The ring is cards, the number in it is days, the line below is cards again ("20 cards left").
   The eye reads the big number as the ring's value.
4. **At risk differs from open by colour only** (grey outline against orange outline). Lock Screen vibrant and tinted
   modes desaturate, so on `accessoryCircular` the two are the same glyph. Rule 2 of §4 in `quality-plan.md` says colour is
   never the only sign; this pair breaks it.
5. **Size.** In the circular Lock Screen widget the ring, a flame and a digit share one small circle. The frames
   show a small flame over a digit, and at risk a thin pale-orange outline.
6. **Progress repeats Today.** The Progress hero is the same ring at 220 pt with today's fraction, though the page is
   about history; its number (659) is repeated in "Longest streak 659 days" under it. On the Mac, Today (200 pt) and
   Progress (220 pt) are neighbours in the sidebar, so the same object appears twice at two sizes.
7. **One glyph, three sizes of middle.** Today and Progress: flame over days over "day streak"; rest and widget: flame over days;
   study bar (30 pt): the flame alone; Mac session header (28 pt): empty. The same ring means a different thing at each size.
8. **Week rings hide the rule.** A day with the step done and the ring half open counts toward the streak and looks unfinished.

## 3. Options

Common to all three: one `DayRing` component with one middle rule by size, not per screen; the big ring appears
once in the app, on Today (iPhone 168 pt, Mac 200 pt, both the same component); Progress opens with the streak
as a statistic (flame, days, "day streak"; "Best" appears only when it differs from the current run), then rings
closed, days studied, cards done, the 13 weeks; the week rings and the 28-pt header ring have no middle. The
streak step keeps its title; FSRS, the staircase and the streak rules do not change.

| Surface | A. Empty ring, streak chip beside (Fitness) | B. Ring holds its own number, streak chip outside (scores) | C. B plus a step tick on the ring |
|---|---|---|---|
| Today hero, iPhone 168 pt | Empty middle. Under the ring: chip flame + days, then "20 cards left · ≈ 5 min" | Middle: cards left, large, with "cards left" in caption; at the goal a `checkmark`. Under the ring: chip flame + "12 day streak" or "≈ 2 min to keep your streak", then "≈ 5 min · 28 words in memory" | As B; a tick at the step's fraction on the ring; passing it lights the chip's flame |
| Today hero, Mac 200 pt | Same as iPhone, scaled | Same as iPhone, scaled | Same |
| Progress, iPhone and Mac | No ring; streak statistic as in Common | Same | Same |
| Stream header 28 pt, study bar 30 pt, Mac header | Ring only, on both platforms (the study bar's flame goes) | Ring only; cards left stays in the figures beside it | Ring only, no tick at this size |
| Rest screen 96 pt | Ring empty, flame chip under it | Ring with the cards left or `checkmark`; chip under it | Ring with tick; chip under it |
| Week rings | Unchanged; the step-kept day gets a dot under the ring | Same | The tick repeats on the day's ring at 28 pt and above only |
| `accessoryCircular` | Gauge ring only (the system gauge look), tap opens Today | Gauge ring with the cards-left digit, the `Gauge` `currentValueLabel`; closed: `checkmark`. No flame | As B |
| `accessoryRectangular` | Gauge ring left; right: "8 cards left · ≈ 2 min", flame + days | Ring with digit left; right: flame + days, "≈ 2 min" | As B |
| `accessoryInline` | "flame 7 · 8 left" (as now) | Same; at risk adds `exclamationmark` | Same |
| `systemSmall` | Ring (empty) top; flame + days and "8 cards left" below | Ring with digit; below the streak chip and "≈ 2 min" | As B |
| `systemMedium` | Ring left; "8 cards left · ≈ 2 min", week rings, Study | Ring with digit left; streak chip, "≈ 2 min", week rings, Study | As B |
| Flame states | Three states as now | Three states in shape: outline (open), `flame.fill` (kept), outline with `exclamationmark` (at risk); colour as now | As B, tick marks the open to kept change |
| Cost | Low: delete the middle, add a chip | Medium: new middle, chip component, widget layouts | High: a drawn tick, tests, no reference to follow |

Option notes.

- **A** is the nearest to Fitness and the cheapest. A 168-pt ring with an empty middle leaves the hero without a
  number, and `accessoryCircular` becomes a bare arc with nothing to read.
- **B** keeps a number in the ring, the one Oura, Whoop and the WidgetKit gauge keep, and it is the ring's own unit.
  The streak becomes the chip, which is where Duolingo and Apple put it.
- **C** answers confusion 1 most directly and has no precedent among the references; at 28 pt the tick does not
  show, so it holds on Today and rest only, and the "same everywhere" rule gets an exception.

## 4. Recommendation

Option B with the common rules.

1. The ring and its number are one quantity, cards, at every size where a number fits (hero, rest, `accessoryCircular`,
   `systemSmall` and `systemMedium`); where it does not fit (28 and 30 pt, week rings) the ring is empty inside. The size decides how much of the
   middle shows; the subject stays cards. This removes confusions 1, 3, 5 and 7 and gives
   the widget the shape the system's own gauges have.
2. The streak is a chip: flame, days, caption "day streak". It sits outside the ring on every surface and carries the
   step's title before the step ("≈ 2 min to keep your streak"). The two bars of confusion 2 are then two
   sentences in the chip's place: the step on a normal day, "Close the ring to save your 12-day streak" after a miss.
3. At risk becomes a shape (`exclamationmark` on the outline), so vibrant and tinted widgets keep it (confusion 4).
4. Progress loses its hero ring and opens with the streak statistic; the Mac keeps one big ring (confusion 6).
   The week rings stay, and the day with the step done and the ring open is marked by a dot (confusion 8).
5. Reasons: it follows the pattern all references share (§1, points 1 and 2); Duolingo's split of streak and goal
   is already Mnemit's rule, and the chip shows it; the work is layout and one component, with no change to
   `DailyProgress`, the streak rule or the staircase. The rule to revise is `quality-plan.md` §4 rule 1 ("the
   middle of every ring is the streak"), and `design-spec.md` §5.7 with its table of middles.
6. What to check on the frames before building: the digit in `accessoryCircular` with a closed ring (`checkmark`),
   the chip at `systemSmall` in light, dark, tinted and vibrant, and the at-risk `exclamationmark` at 12 pt.
