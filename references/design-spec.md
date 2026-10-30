# Mnemit design spec: home, deck screen, study stream, accent, Mac

Visual spec for one user (iPhone 13 mini on iOS 27, dark mode; Mac on macOS 27), written on 2026-10-21 and kept to the code of 9.0. Read from code: `TodayScreen`, `TodayCard`, `DeckScreen`, `DeckTodayCard`, `StudyView`, `GradeChoice`, `Presentation`, `Figures`, `CardFlight`, `MedalToasts`, `LeechMomentView`, Mac `ShellView`, `TodayPage`, `DeckPage`, `SessionView`, `AppCommands`, `DailyProgress.swift` (`DailyGoal`, `DailyRing`, `Streak`, `DailyProgress.evaluate(_:at:calendar:)` over all decks) and `StudyStream.swift`. What the screens show and do: `screens.md`; the entities and the day they draw: `product-model.md`. No GUI was run for this spec.

## 0. How to read this

- `[H:slug]` is a Human Interface Guidelines page, opened on 2026-10-21 through the HIG's own data feed (`https://developer.apple.com/tutorials/data/design/human-interface-guidelines/<slug>.json`); the page URL is `https://developer.apple.com/design/human-interface-guidelines/<slug>`. `oc` cannot render these pages (JavaScript only), the JSON can be read with curl. Other tags are in §7.
- UNVERIFIED marks a claim whose source was not opened, or a behaviour that only a screen can show. §7 lists all of them.
- The Swift blocks in this file were typechecked against `iPhoneSimulator26.2.sdk` and `MacOSX26.2.sdk` (swiftc 6.2.4, `-swift-version 6`) (the grade area and card type blocks of §4.5, the contrast helper of §5.5). Typechecked means the API exists and compiles; it does not mean the screen looks right.
- Sizes are points. Device: iPhone 13 mini is 375 x 812 pt, portrait safe area top 50 / bottom 34, landscape sides 50 / bottom 21, width class compact [U:loaf].

## 1. Verdicts

| # | Decision | Reason | Rollback |
|---|---|---|---|
| 1 | Launch lands on **Today**. The app no longer reopens the last deck. | Study is one tap from launch. | Re-enable `reopen()`. |
| 2 | The primary button **Study** runs one stream over all decks that have cards due; each card comes from the deck whose next card is most urgent (`screens.md`, Study). A tap on a deck row opens that deck's screen; Study This Deck there runs the stream over that deck only. | The ring and the streak are one value over all decks (`DailyProgress.evaluate` takes `[DeckActivity]`), so one button must be able to finish them. The user studies two decks daily. | `StudyScope.all` falls back to the last studied deck (`knownDecks.last`), label unchanged. |
| 3 | A deck row is a button with a `chevron.forward` drawn by hand and pushes the **deck screen** (`DeckRoute`, `PushedDecks`). No info button, no context menu for details. | The row drills down, and the HIG gives the disclosure indicator that job [H:lists-and-tables]; the deck has to be opened before the push, so the chevron cannot come from a `NavigationLink`. A context menu is hidden [H:context-menus]. | – |
| 4 | New / Learning / Review are **neutral**: label and number in the primary label colour, a count of 0 left out. | Blue/red/green reuse the meanings of Forgot (red), Good (green) and the maturity ramp (the accent's indigo); the HIG asks for one colour per meaning [H:color]. The owner dislikes the coloured counts. | `StudyCount.color` stays in git history. |
| 5 | One accent, **system indigo** `#5856D6` in light and dark; Increase Contrast `#3634A3` (light) and `#6563E6` (dark). | Red means Forgot and the greens mean recalled, so the accent is neither; green reads as Excel and terracotta as Claude (owner, 21.10.2026). The icon tile is indigo too. Numbers in §5. | Change the values in the three `AccentColor.colorset` files (iPhone, Mac, widget). |
| 6 | Raise the deployment targets to **iOS 26 / macOS 26**. | Only the owner's devices run the app: iOS 27, macOS 27, built with Xcode 27.1. `safeAreaBar`, `.glassProminent`, `Button(role: .close)`, `ToolbarSpacer` need 26. | Keep 17 / 14, wrap five call sites in `#available` with `.safeAreaInset` and `.borderedProminent`. |
| 7 | Large title **Today**. The app name appears nowhere on the screen. | The HIG advises against naming a window after the app and asks for titles under 15 characters; large titles are the iOS pattern [H:toolbars]. | `.navigationBarTitleDisplayMode(.inline)`. |
| 8 | Mac: one window of a sidebar and pages (§6). Today, Progress and the decks sit in the sidebar; a deck's page has the deck's Today card with Study This Deck (Learn 10 New Words once nothing is left) in a strip, and a toolbar of Cards \| Statistics, Add Cards, Learning Options and the same button. Settings stay in the app menu. | The Mac's day covers every deck, so one window shows the day and the decks together. | The tag `pre-single-window` holds the document-window app. |

## 2. iPhone home (Today)

### 2.1 Flow

Launch → Today. Tap **Study** (one tap) → the study stream covers the screen at once and shows the first card. No summary screen in between. A tap on a deck row pushes the deck screen.

Rejected: auto-start of the stream at launch. The learner would not see what is due, and the HIG asks launch to restore the previous position [H:launching]. Rejected: a tab bar. There is one section; a tab bar is for navigation and Study is an action [H:tab-bars].

### 2.2 Wireframe (375 x 812)

```
┌───────────────────────────────────────┐
│ 9:41                                  │ status area 50
│                            ( + )( … ) │ nav bar 44: plus and ellipsis menus (trailing)
│ Today                                 │ large title 34 bold, system
│ Tuesday, October 27                   │ navigation subtitle: the date of the study day
│ ┌───────────────────────────────────┐ │ the Today card (`TodayCard`), the list's first section: padding 20 / 16, one button to Progress
│ │ ╭──────╮  Day streak              │ │ ring 112 left (a picture, no number in it); right three figures,
│ │ │      │  🔥 12                    │ │   each a label (subheadline) over a value (title2, rounded, semibold):
│ │ │      │  To keep your streak     │ │   the streak's days in orange,
│ │ │      │  ≈ 2 min                 │ │   the minutes in the accent
│ │ │      │  Words learned           │ │
│ │ ╰──────╯  412  +12 today          │ │
│ │ ───────────────────────────────── │ │ Divider
│ │    M  T  W  T  F  S  S         ›  │ │ the week's rings, 22 pt; chevron at the row's end
│ └───────────────────────────────────┘ │
│ DECKS                                 │ system section header
│ ┌───────────────────────────────────┐ │
│ │ Greek B1               ≈ 4 min ›  │ │ body | body, monospaced, secondary | chevron.forward, footnote semibold, tertiary
│ │ ───────────────────────────────── │ │
│ │ Greek A1–A2                  ✓ ›  │ │
│ └───────────────────────────────────┘ │
│ ╭──────────────────────────╮ ╭─────╮  │ bottom bar: Study (.borderedProminent) and the minimised search
│ │          Study           │ │  ⌕  │  │
│ ╰──────────────────────────╯ ╰─────╯  │
└───────────────────────────────────────┘ safe area bottom 34
```

Vertical budget on the 13 mini (an estimate, not measured): 50 + 44 + about 52 (large title) + the Today card about 270 + header 35 + two rows 90 = about 540 of 812. The list scrolls where decks outgrow the rest.

### 2.3 Components

| Element | SwiftUI | Style and values |
|---|---|---|
| Container | `NavigationStack` > `List` | `.listStyle(.insetGrouped)`; the Today card's row has zero insets (`.listRowInsets(EdgeInsets())`) and pads itself; the other margins come from the list (16). |
| Title | `.navigationTitle("Today")`, `.navigationSubtitle` | Large, automatic. German `Heute` already in the catalog. The subtitle is the date of the study day, "Tuesday, October 27" (`todaySubtitle`); before 04:00 it still shows the day before. |
| Toolbar | `ToolbarItemGroup(.primaryAction)` | Trailing: `Menu("Add", systemImage: "plus")` and `Menu("More", systemImage: "ellipsis")` (their items: `screens.md`, Today). No info button: How It Works is the last row of the Progress screen. The HIG prefers symbols without borders in toolbars [H:toolbars]: `ellipsis` without the circle. |
| Today card | `TodayCard` in the list's first `Section` | A `VStack` (spacing 16, padding 20 horizontal and 16 vertical): the ring and its figures, a `Divider`, the week. A `Button` behind the content (`.buttonStyle(.plain)`) pushes Progress, so VoiceOver reads the ring and each figure on its own. Until every deck is read and the ring is evaluated (`isDayReady`) the figures are redacted placeholders (12 days, 2 min, 412 words). The Mac's page draws the same card on `Color.tileGround` (§6.2). |
| Ring | `HeroRing` over `ProgressRing` | 112 pt on `@ScaledMetric(relativeTo: .title)`, line 18/168 of its diameter; the drawing and sources in §5.7. A picture: the arc of the cards done against today's goal and its laps, nothing in the middle at any size or text size. The owner asked for Fitness quality on 22.10.2026; [H:activity-rings] advises against imitating the Activity rings, the ring here follows the owner. VoiceOver reads "Daily Goal" and its percent. |
| Figures | `TodayFigures`: three `Figure`s, spacing 10 | Each a label (`.subheadline`) over a value (`.title2`, rounded, semibold, `.monospacedDigit()`); a unit would follow smaller and in capitals, a caption in `.footnote` secondary (`Figure`, §2.6). **Day streak**: the flame by its state (`StreakFlame`) and the days in `Color.streak`; at 0 days the outline flame and "0" in secondary. **The next moment** (`NextStep.moment`): the label names the moment, the value is its minutes in `Color.appAccent` ("≈ 2 min", "< 1 min"; non-breaking); the labels are in §2.4. **Words learned**: the words and, on a day that added some, "+12 today" as the caption; shown from 0. |
| Layout | `ViewThatFits` | The ring and the figures side by side at their own width (`fixedSize` horizontally, so a wide card centres the pair), spacing 20; where they do not fit, at the larger text sizes, the ring over the figures. |
| Week | `WeekRings` | Seven rings of 22 pt, spacing 10, a past day with nothing done a thin outline in `Color.inactiveMark` (`MissedDayMark`, 3:1) and not an empty track, weekday initials in `.caption2`, today last and bold. The chevron `chevron.forward` (footnote semibold, tertiary) ends the row; an invisible one at its start keeps the rings centred. |
| Section header | `Section("Decks")` | System. |
| Deck row | `Button` with an `HStack` | `.buttonStyle(.plain)`, `contentShape(Rectangle())`, pushes the deck screen. Name `.body`; what the deck's plan leaves of today at the day's pace, "≈ 4 min" (`DeckRow`, `DeckMinutes`: backlog included, "< 1 min" under a minute), `.body`, `.monospacedDigit()`, secondary, trailing, or a `checkmark` in secondary when nothing is left; then `chevron.forward`. No subtitle. Until the deck is read the time is a redacted placeholder. A paused deck sits in the section "Paused": name in secondary, no time. |
| Swipe | `.swipeActions`, `.contextMenu` | Pause Deck (Resume Deck in the Paused section); Remove from List for decks outside the folder. |
| Bottom bar | `.searchable` + `.searchToolbarBehavior(.minimize)`, `ToolbarItem(.bottomBar)`, `DefaultToolbarItem(kind: .search)` | One bar holds the day's button and the minimised Search All Cards. The button is `.borderedProminent`, labelled by `DayAction`: `Study` in the accent while the ring is open, `Catch Up` once the ring is closed and the plan has cards left, `Learn 10 New Words` once the plan is done, the last two tinted `.secondary`. No footnote under it. Its width is the bar's less 80 pt, at least 180 (`containerRelativeFrame`): 211 of the bar's 291 pt at 375 pt, room for "Learn 10 New Words" in one line. |
| Accessibility | | Study button `accessibilityValue("\(due) cards left")`. The card: the ring says "Daily Goal" and its percent; the Day streak figure "12-day streak, kept today" ("not kept yet", "at risk": `NextStep.streakSpoken`); the other figures read as label and value. |

### 2.4 States

| State | Figures | Button |
|---|---|---|
| Before the streak step | Day streak: outline flame and "12"; "To keep your streak" over "≈ 2 min" | `Study` |
| After the streak step, ring open | Day streak: filled flame; "To close the ring" over "≈ 5 min" | `Study` |
| Ring closed, cards left | "Reviews left" over "≈ 12 min" | `Catch Up` |
| Plan done, or nothing due | "Today" over "All done" | `Learn 10 New Words`; opens the stream with ten new cards at once |
| The day after a missed day, ring open | the flame an orange outline with an exclamation mark; "To save your streak" over "≈ 6 min" | `Study` |
| No streak | Day streak: outline flame and "0" in secondary; "To start your streak" over "≈ 2 min" | `Study` |
| Rounds not known yet | "Next" over the moment's name: "Keep your streak", "Close the ring", "Save your streak", "Start your streak" or "Catch Up" | `Study` |
| Decks not read yet | placeholders, redacted, until every deck and the ring are in (`isDayReady`) | `Study` |
| No decks | `EmptyTodayCard`: the empty ring and "Add the words you are learning." (`.title3.weight(.semibold)`) on `Color.tileGround` (radius 26), then `New Deck` (`.borderedProminent`, large), `Shared Decks` (`.bordered`, large) and `Use iCloud Drive Folder` as a small text button; Open Deck… is in the `…` menu; no glass | – |
| Deck unreadable (iCloud) | row without its time | row stays tappable; the stream cover shows the existing failure view |
| Accessibility sizes (`isAccessibilitySize`) | the ring keeps its scaled size and stands over the figures, which wrap; the list scrolls | unchanged |

The ring counts cards and the moment figure counts minutes, which translate cards at the learner's own pace; reviews do not enter. The goal, the done cards, the minutes to the streak step, to the ring and of the reviews after it (`DailyProgress.minutesToStreak`, `.minutesToRing`, `.minutesOfDueAfterRing`) and the pace are defined in `daily-ring.md`; what the figures say is in `screens.md`, Today. The small widget has the ring (56 pt) beside the streak figure and the sentence (`NextStep`) under them, two lines at most; the medium widget is the card without its week (§5.7).

### 2.5 Budget

A tap on Study sets one state value and presents the stream cover in the next frame; `OpenDeck` loads behind a `ProgressView` inside the cover (target 8 ms median, 16 ms ceiling to first presented frame [G §6]). The first Today frame reads cached counts and the cached ring from `UserDefaults`; file reads stay on `Task.detached` as in `KnownDeckCounts`. The ring needs the review logs of both decks (`DeckActivity`); compute off the main actor and cache per study day.

### 2.6 The screens' grammar

The owner's references of 27.10.2026 are Apple's Fitness Summary and the Activity app: the Activity Rings card with the ring on the left and its figures on the right, tiles two to a row, a row of small rings for the week, a calendar of rings. Mnemit takes that grammar through the iOS 26 and macOS 26 rules (`hig-ios26.md`), not Fitness's look. The product model names the rules ("The grammar of the screens"); the values are here.

- **Content is solid, controls are glass.** Cards, rows, tiles, the ring and the figures sit on the grouped fills (`secondarySystemGroupedBackground` on the grouped background). Liquid Glass is only for the bars and the controls that float over content: Study and search in the iPhone's bottom toolbar, the toolbar groups. Buttons inside content are bordered (`.borderedProminent`, `.bordered`).
- **A screen** is a large title (iPhone) over grouped sections. Today's date is the navigation subtitle. A section is one card under its title (the list's own section header, title case), a chevron marks a row that opens more, no box stands in a box (tiles stand on the page, not in a card), and corners are concentric with their container.
- **A hero card** holds the ring on the left and its figures on the right (`TodayCard`, §2.3). Each figure is a label over a value (`Figure`): the value in rounded numerals and its entity's colour, the ring's indigo (`Color.appAccent`) for minutes and the streak's orange (`Color.streak`) for days, the primary colour for the rest; a unit follows the value or the label says it. At accessibility sizes the ring stands over the figures.
- **Tiles** (`FigureTile`): a label, a large value, at most one `.footnote` line under it, on `Color.tileGround`, padding 14, radius 14. Two to a row in an adaptive grid (minimum 150 pt, spacing 12 = `Spacing.gap`), one column at accessibility sizes.
- **Days** are small rings with their letters (`WeekRings`, 22 pt) and the calendar of rings on Progress.
- **The ring** is one indigo ring with laps, never Apple's three colours or three rings. Colour never says anything alone: the flame's shape, a check and numbers say it too. In a tinted widget the track and the arc differ by opacity and a lap shows as a number (§5.7).
- **The Mac** has no large title: the title and the date sit in the window's title bar; Study is in the toolbar and in the page; nothing the learner needs stands at the window's bottom edge.
- **Type.** No `.tracking` or `.kerning` stands in the sources (grep). SF Pro tracks −0.43 pt at 17 pt and +0.40 at 34; SF Pro Rounded tracks +0.37 at 17 and +0.51 at 13 [H:typography]. Values take a text style with the rounded design; whether SwiftUI re-tracks text scaled by `minimumScaleFactor` is UNVERIFIED (§7.2).

`Shared/Support/Figures.swift` holds the parts. `Figure` has two sizes: `regular` (label `.subheadline`, value `.title2` rounded semibold, unit `.callout`, caption `.footnote`) and `compact` for widgets (`.caption`, `.headline`, `.caption`, `.caption2`; a one-line label). `Color.tileGround` is `secondarySystemGroupedBackground` on iOS and `quaternarySystemFill` on macOS.

Where the parts stand:

- **Progress** (`ProgressScreen`) is a `Form` in `.formStyle(.grouped)`: the streak card (§5.7), the four tiles (Days studied, Rings closed, Words learned, Your ring) with zero row insets and a clear row background on iOS, on macOS the four figures sharing the grouped card; the calendar of rings; Medals with Show All; Memory; a last section with How It Works and the footer "What's behind the ring."
- **Statistics** (`SummaryTiles`): Cards, Due, New, Suspended (once a card is) and Recall Now as tiles; on the iPhone `StatisticsScreen` is a grouped list of the tiles and a section Retention.
- **A deck's Today card** (`DeckTodayCard`, §3.2) is the first section of the deck screen and the strip of the Mac's deck page.

## 3. iPhone deck screen

Pushed onto Today's stack from a deck row; what it shows and does: `screens.md`, Deck screen.

### 3.1 Wireframe

```
┌───────────────────────────────────────┐
│ ‹ Today       Greek B1         (+)(…) │ inline title; back; plus and ellipsis menus
│ ┌───────────────────────────────────┐ │ the deck's Today card (`DeckTodayCard`), the first section
│ │ Today        Due   New   Learning │ │ label (subheadline) over value (title2, rounded, semibold)
│ │ ≈ 4 min      14    6     2        │ │ the time in the accent, the counts in the primary colour
│ └───────────────────────────────────┘ │
│ ┌───────────────────────────────────┐ │
│ │ ▤ Cards                    2 236  │ │ LabeledContent, monospaced digits
│ │ ▥ Statistics                   ›  │ │ NavigationLink to StatisticsScreen
│ │ ⚙ Options                      ›  │ │ NavigationLink to DeckOptionsScreen
│ └───────────────────────────────────┘ │
│ ╭───────────────────────────────────╮ │ bottom bar: ToolbarItem(.bottomBar)
│ │          Study This Deck          │ │ .borderedProminent
│ ╰───────────────────────────────────╯ │
└───────────────────────────────────────┘
```

### 3.2 Components

| Element | SwiftUI | Values |
|---|---|---|
| Container | `List` in the stack | `.listStyle(.insetGrouped)`, `.navigationBarTitleDisplayMode(.inline)`. |
| Today card | `DeckTodayCard` in the first `Section` | "Today" over the time of what today's plan leaves in the deck, "≈ 4 min" in `Color.appAccent` (backlog included), and beside it Due, New and Learning as figures in the primary colour; a count of 0 is left out, as on the deck's row. A deck with nothing left: "Today" over a check and "Done", and "Next review tomorrow" (`.footnote`, secondary; "Done" alone without a next date). A paused deck: "Today" over "Paused" (wins over the counts). Layout (`ViewThatFits`): the time beside the counts; else the counts in a row under the time; else one column, at accessibility sizes. One element for VoiceOver, the words of `DeckHeadline`. No card before the counts are read, or for a deck with no cards. |
| Toolbar | `ToolbarItem(.primaryAction)` twice | `Menu("Add", systemImage: "plus")`: Add Cards, Import Cards… (wait for `isReadyToEdit`). `Menu("More", systemImage: "ellipsis")`: Practice Newest Words and Practice Today's Mistakes (`DeckPractice`; grey with nothing to practise), a divider, Rename…, Pause Deck or Resume Deck, Export…, Delete Deck. |
| Rows | `NavigationLink` with `RowLabel(title:symbol:)` | Cards with its count (`rectangle.stack`), Statistics (`chart.bar`), Options (`slider.horizontal.3`). |
| Study | `ToolbarItem(.bottomBar)` in `DeckScreen` | `.borderedProminent`: **Study This Deck** in the accent while the deck has cards in today's plan, else **Learn 10 New Words** in grey (`.secondary`): ten new cards of this deck at once. Width the bar's less 64 pt, at least 180 (`containerRelativeFrame`); disabled for a deck without cards or one that cannot be edited yet; `accessibilityValue("\(due) cards left")`. |
| Loading | the counts at once from `KnownDeckCounts`; the rest after `OpenDeck` loads | – |

## 4. Study stream screen

### 4.1 Wireframe (portrait, 13 mini, answer shown)

```
┌───────────────────────────────────────┐
│ ✕  ◔ ≈ 4 min                   ↶  (…)  │ nav 44: close, ring 30, minutes, subheadline from the leading edge | undo | ellipsis
│ ┌───────────────────────────────────┐ │
│ │                                   │ │ card: margin 16, inner padding 24, radius 22,
│ │         ο Άγγλος    [spk]         │ │   secondarySystemBackground
│ │ ───────────────────────────────── │ │ divider at a fixed height
│ │       англичанин · Englishman     │ │ title2, regular
│ │       Ο Τζον είναι Άγγλος.        │ │ body, secondary
│ │                                   │ │
│ └───────────────────────────────────┘ │ card is about 500 high on the 13 mini
│    ╰───────────────────────────────╯    │ the cards waiting in the round: up to 4 blank edges, 8 pt apart, 7 pt narrower a side
│ ╭────────────────╮ ╭────────────────╮ │
│ │    ✕ Forgot    │ │     ✓ Good     │ │ two buttons, gap 12, 165 x 112; Forgot red, Good green
│ ╰────────────────╯ ╰────────────────╯ │
└───────────────────────────────────────┘ 12 bottom padding above the safe area; 8 under the bar; 12 + 32 for the edges between card and buttons
```

Width: 343 inside the 16 pt margins; each of the two buttons is (343 − 12) / 2 = 165.5 wide and 2 × 50 + 12 = 112 high. With the setting Hard and Easy Buttons a later showing has Forgot at 343 over a row of (343 − 2 × 12) / 3.25 = 98.2, so Hard 98, Good 123, Easy 98, each 50 high.

### 4.2 Header

What the header shows: `screens.md`, Study.

- Leading: `Button(role: .close)` (xmark). It replaces the `chevron.backward` End Session button; the stream has no session to end, every grade is saved. The HIG asks for the standard Close symbol and no text label [H:toolbars].
- Leading, right after the close button (`.topBarLeading`, no shared background): `StreamRing` (a `ProgressRing`, 30 pt, `@ScaledMetric(relativeTo: .subheadline)` up to 44), and the minutes to the next moment ("≈ 4 min", `.subheadline`, `.monospacedDigit()`; none once all is done), spacing 8, one combined element for VoiceOver. The ring is empty inside and goes on over itself past the goal, up to three laps. The flame is an outline until today's streak step is done, filled in the streak's orange from then on, an outline with an exclamation mark at risk. For 1.5 s after a done card the interval it was given ("in 8 days", after a `repeat` glyph) takes the place of the minutes. A practice shows the word `Practice` as the principal text, without the ring.
- Trailing: an icon button `arrow.uturn.backward` (Undo) left of `Menu("More", systemImage: "ellipsis")`; nothing hangs under the bar: its room goes to the card.
- The ring is where the cards go (`study-screen.md`, Motion): its frame is reported to `StudyMotion.ringHome` (global coordinates, nothing fixed), it steps and glows when a card is done, and the figures stand beside it.
- No streak in the bar: a flame beside the ring draws the eye from the cards filling it; the rests show it. The goal-met moment is the ring that closes as the last card leaves and bursts at the rest of the plan.

### 4.2a Rests

The stream's rests (titles, figures and buttons: `screens.md`, Study) are one `StreamRestView`: the same ring (96 pt, a picture) and the streak chip under it (`StreakLine`: the flame and "12-day streak"), over the title (on the Streak kept rest, whose title is the streak, nothing under the ring: the days with the filled flame beside them), the lines in secondary under it (the price line of the sentence, the words learned, the week), the buttons 24 pt below, as wide as the card (iPhone 400 pt at most, Mac 320). The first button of a rest is `.borderedProminent` and the default action (Keep Going; Done); the others are `.bordered` on the Mac and on the iPhone `SecondaryActionStyle` (the accent on a wash and a hairline of it, never grey, which reads as disabled); Learn 10 New Words carries no footnote. The rings of the last seven days (`WeekRings`) are 22 pt each, weekday initials under them, today last and bold.

The motion into and out of a rest (`RingTraveler`, `SlotOutline`, the staggered lines, Reduce Motion): `study-screen.md`, Motion.

### 4.3 Grade area

| Part | Spec |
|---|---|
| Container | One fixed-height container for both stages, so the card keeps its height and the divider with the question stays where it is when the answer opens. The grade buttons stay in the layout at all times (`opacity`, `allowsHitTesting`, `accessibilityHidden` as `face` does for the answer) and Show Answer lies over their top (an overlay). |
| Show Answer | `Button`, `.buttonStyle(.plain)` with an accent fill, full width, `@ScaledMetric(relativeTo: .body) var showAnswerHeight = 50` up to `GradeChoice.tallest`, its label no larger than `GradeChoice.largestText`, corner radius 14 like the grade buttons. The room under it stays empty until the answer shows. |
| Two buttons | Every showing: **Forgot** (`Label("Forgot", systemImage: "xmark")`, `Grade.again.color`, white label) and **Good** (`Label("Good", systemImage: "checkmark")`, `Grade.good.color`, `Grade.onColor`), `.font(.body.weight(.semibold))`, side by side with a gap of 12, each half the width and as tall as the two rows of the four (`2 × height + 12`; 112 at the default size). On a card's first showing (`Card.isNew`) they are named **Don't know** and **Know** (`Grade.buttonTitle(isNew:)`); the grades under them are Again and Good. `GradeChoice.buttonGrades(isNew:showsFourButtons:)` is the one rule. |
| Hard and Easy Buttons | The setting `ShowsFourAnswerButtons` (default off; iPhone Settings and Mac Preferences): a card on a later showing has Forgot full width over `WeightedRow(weights: [1, 1.25, 1], spacing: 12)` of Hard, Good and Easy, each `height` high, fills `Grade.hard/good/easy.color`, labels `Grade.onColor`: white on Forgot, a dark tint of the green on the greens (`GradeSwatch`; §5.2). No caption stands over the row. A first showing stays two. |
| Height | `@ScaledMetric(relativeTo: .body) var height = 50` on the iPhone, up to `GradeChoice.tallest` = 64, 44 in landscape, 38 on the Mac. |
| Accessibility sizes | At `isAccessibilitySize` the buttons stack, full width, gap 12: Forgot over Good, or Forgot over Hard, Good and Easy; their labels follow the text size up to AX3 (`GradeChoice.largestText`). |
| Swipes and keys | Only the grades of the buttons: with two buttons the swipes left (Forgot, compass 210°–330°) and right (Good, 30°–150°), up and down spring back and count as gap misses, and on the Mac ← or 1 and → or 3; with "Hard and Easy Buttons" on, later showings take the four sectors of §4.6 and the keys 1 to 4 (`GradeSwipe.grade(atAngle:among:)`, `GradeChoice.buttonGrades`). |
| Spacing | 12 between bezeled controls [H:accessibility]. Hard taken for Forgot is the costly slip for FSRS (comment in `GradeChoice`); with four buttons the 12 between the rows keeps them apart, Forgot alone above the three "yes" grades. The scale of the study screens is `Spacing`: 4, 8, 12, 16, 24. |
| Corner radius | 14 (Mac 10). |
| Press state | `Pressable` (opacity 0.6) stays; the HIG requires a press state on custom buttons [H:buttons]. |
| Landscape (`verticalSizeClass == .compact`) | One row: Forgot (170) beside Good (`part: .forgot` and `.recalled`), or beside Hard, Good and Easy with the setting; gap 12, height 44. The progress leaves the row for the nav bar. |

The grade buttons, two or four, are one choice control; the HIG limit of one or two prominent buttons per view [H:buttons] applies to action buttons.

### 4.4 Card typography

Corpus (`cards-a1a2.tsv`, `cards-b1.tsv`, 5 494 cards): question length p95 24 and 27 characters, max 48; answer first line p95 42 and 48, max 87; example p95 42 and 52, max 86; 1 818 of 3 258 and 2 184 of 2 236 answers carry an example after `\n`.

| Role | iPhone | Mac |
|---|---|---|
| Greek text as question (recognition) or as answer head (production) | `.largeTitle.weight(.semibold)` 34/41 at the default size | `.system(size: 32, weight: .semibold)` |
| Other question (production, Russian) | `.title.weight(.semibold)` 28/34 | `.system(size: 26, weight: .semibold)` |
| Other answer head (Russian · English) | `.title2` 22/28, regular | `.title` (22 on macOS) |
| Example (second line of the answer) | `.body` 17/22, secondary | `.title3` (15 on macOS), secondary |
| Hint | `.title3` 20/25, secondary | `.title3` (15), secondary |
| Card state line (optional) | `.footnote` secondary: `Greek B1 · New` | `CardStateLine` |

Each role has one size, so a long answer does not shrink the card's text, and a short one does not grow it. The card's text follows the text size up to AX3 (`GradeChoice.largestText`), like the buttons; `minimumScaleFactor(CardFace.smallestScale)` (0.5) stays only as a valve; the card cannot scroll, as its text is one bitmap while it moves (`FlightCard`), so the room comes from the buttons (`GradeChoice.tallest`) and the question leaves `badgeClearance` under the corner's badge at every size. A gloss ("отвечать · to answer") is one line when it fits, else its two halves (`String.glossHalves`) one under the other without the dot. The answer is split at the first `\n`; Greek is detected by script (`0x0370...0x03FF`, `0x1F00...0x1FFF`); `GreekSpeech.canSpeak` would also require an installed voice.

Mac note: macOS has no Dynamic Type; its built-in styles are Large Title 26, Title 1 22, Title 2 17, Title 3 15, Body 13 [H:typography]. Keep explicit sizes for the card there, as `SessionView` does. The Mac "other question" uses 26, so Greek at 32 stays the largest.

Worst case on the 13 mini at the default size (estimate, measure in the simulator): question 4 lines at 41 = 164 + hint 25 above the divider; gloss 4 lines at 28 = 112 + example 3 lines at 22 = 66 below it. Each half of the card has about 200.

Dynamic Type sizes from [H:typography] for the styles used (iPhone, points):

| Style | Large (default) | xxxLarge | AX1 | AX5 |
|---|---|---|---|---|
| Large Title | 34 | 40 | 44 | 60 |
| Title 1 | 28 | 34 | 38 | 58 |
| Title 2 | 22 | 28 | 34 | 56 |
| Title 3 | 20 | 26 | 31 | 55 |
| Body | 17 | 23 | 28 | 53 |
| Subhead | 15 | 21 | 25 | 49 |
| Footnote | 13 | 19 | 23 | 44 |

Behaviour: up to xxxLarge the layout is as drawn (estimate: with the setting Hard and Easy Buttons, Hard at 23 pt is about 52 wide in a 98 button). From AX1 the grade buttons stack and the Today card's ring moves above its figures. The card is not capped; its text may reach the 0.6 scale floor at AX3 and above.

### 4.5 Code (typechecked)

```swift
/// Grade rows stay in the layout so the card keeps its height; Show Answer is laid over their top.
struct GradeArea<Show: View, Rows: View>: View {
    var isRevealed: Bool
    @ViewBuilder var show: Show
    @ViewBuilder var rows: Rows

    var body: some View {
        rows
            .opacity(isRevealed ? 1 : 0)
            .allowsHitTesting(isRevealed)
            .accessibilityHidden(!isRevealed)
            .overlay(alignment: .top) { if !isRevealed { show } }
            .frame(maxWidth: .infinity)
    }
}

enum CardFont {
    static func question(isGreek: Bool) -> Font { isGreek ? .largeTitle.weight(.semibold) : .title.weight(.semibold) }
    static func answerHead(isGreek: Bool) -> Font { isGreek ? .largeTitle.weight(.semibold) : .title2 }
    static var hint: Font { .title3 }
    static var example: Font { .body }
}

func isGreek(_ text: String) -> Bool {
    text.unicodeScalars.contains { (0x0370...0x03FF).contains($0.value) || (0x1F00...0x1FFF).contains($0.value) }
}

struct AnswerText: View {
    var answer: String
    var body: some View {
        let parts = answer.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
        VStack(spacing: 12) {
            if let head = parts.first {
                Text(head).font(CardFont.answerHead(isGreek: isGreek(String(head))))
            }
            if parts.count > 1 {
                Text(parts[1]).font(CardFont.example).foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
    }
}
```

### 4.6 Swipe grading and motion

The sectors, the pull of the card, the haptics, the flight, the stack, the ring's step and burst, Undo's reverse flight and Reduce Motion are in `study-screen.md`, Swipe and Motion.

### 4.7 Medal toasts

`MedalToasts` and `MedalToastPlace` (`Shared/Session/MedalToasts.swift`): one medal at a time; a toast stays 2.5 s and the next follows 0.4 s after it. It slides in from its edge and fades in (Reduce Motion: a fade), a success haptic plays as it comes and VoiceOver hears the medal's title. The regular toast is a capsule of `.regularMaterial`: the medal's disc (36 pt), the title (`.subheadline.weight(.semibold)`) and what it took (`.footnote`, secondary). The compact toast is one line, the disc (24 pt) and the title, 32 pt tall. A toast never stands over the ring, the card or a button; the compact one has 12 pt clear of the card and of the buttons (`Spacing.section` between the card and the buttons).

| Place | Where | Toast | Motion |
|---|---|---|---|
| `.title`: iPhone Today | a zero-height inset at the bottom edge of the bar, large title included: under the bar's buttons, over the large title | regular | from the top |
| `.gap`: iPhone stream | in the gap between the card and the answer's buttons, over the stack's edges only; its middle `Spacing.gap / 2` below the card's room | compact | scale from 0.9 and fade |
| `.header`: Mac stream | the middle of the header's row, between the figures and the buttons | compact | scale from 0.9 and fade |
| `.inset`: Mac Today | a bottom safe-area inset under the Study button; the content gives up that room while the toast stands | regular | from the bottom |

### 4.8 Leech moment

`LeechMomentView` (`Shared/Session/LeechMomentView.swift`, shown by `SessionDriver.leechMoment`) stops the stream after the Forgot that makes a card a leech, before the next card; when and what it does: `screens.md`, Study. It is centred on the stream's ground: the title "Keeps slipping" (`.title2.weight(.semibold)`, centred, a header for VoiceOver) and under it a `.subheadline` secondary sentence, the card revealed (`CardFace` on `Color.cardSurface`, radius 22, a hairline of the primary colour at 12 %; Mac 560 pt wide and 200 to 320 tall, iPhone full width and 200 to 340 tall) and under it the actions: **Continue** (`.borderedProminent`, large; the Mac's default action with a ↩ keycap) over **Edit** and **Suspend Card** side by side (`SecondaryActionStyle` on the iPhone, `.bordered` on the Mac, large; Mac keycaps E and S; one under the other on the iPhone when a long title leaves no width). **Keep Card** takes Suspend Card's place when the review already suspended the card. A sentence under the title counts the lapses and names the choice. The actions are at most 440 pt wide on the Mac and 400 on the iPhone. VoiceOver reads the title, the question, the answer, then the three actions.

### 4.9 Introduction

`OnboardingView` runs six steps (`OnboardingStep`): welcome, the first showing, the swipes, the day, sync and the reminder; it shows once at the first launch and again from Settings.

- **A New Word** (`FirstShowingView`) is a card's first showing as the stream draws it. The title "A New Word" (`.title.bold()`) with Skip; a sample card ("a janela", "the window") on a stack of three sheets; Show Answer, then the two wide buttons Don't know and Know in the place Show Answer had, of one height with Continue, which takes their place once one is pressed. Don't know slides the card out to the left and under the stack, with the line "It comes back after a few cards."; Know slides it out to the right, with "It comes back once more before you're done." Both lines are in the layout, one unseen, so nothing moves. Once the card is under the stack only the stack's edges show; Reduce Motion fades the card into the stack. Nothing is graded or recorded.
- **The swipes** (`GesturePracticeView`): two sample cards, a swipe left (Forgot) and a swipe right (Good).
- **One stack a day** (`DayStep`): a stack of cards and a 72 pt ring that fills to 0.7, then four rows, each with a symbol: "Mnemit lays out a few minutes' worth of cards every day." (`rectangle.stack`), "Recall a card and the ring moves." (`circle.circle`), "Two minutes keep your streak. Close the ring and the day is done." (`flame.fill`), "Words climb from New to Mastered as they stick." (`chart.bar.fill`); Continue (`.borderedProminent`, large).

## 5. Accent and colour roles

### 5.1 Accent: system indigo

Icon colours, sampled from `icon_1024x1024.png`: tile top `#6C6AE4`, middle `#5A58D3`, bottom `#4846C2`, left card `#E4E3FA`, right card `#F8F7FF`. Dark icon: tile `#2C2B6E` to `#161546`, cards `#B4B2EC` and `#DAD9FA`.

The accent is `AccentColor.colorset`, the same four colours in the iPhone (`VocTrain/Resources`), Mac (`MacVocTrainNg/Resources`) and widget (`MnemitWidget`) asset catalogs. Contrast is the WCAG 2.x ratio of relative luminances of the 8-bit sRGB values, two decimals:

| Appearance | Value | White label on it | On surface |
|---|---|---|---|
| Light | `#5856D6` | 5.65 | 5.65 on white, 5.06 on `#F2F2F7` |
| Light, Increase Contrast | `#3634A3` | 9.65 | 9.65 on white, 8.12 on `#EBEBF0` |
| Dark | `#5856D6` (the light value) | 5.65 | 3.72 on black, 3.01 on `#1C1C1E`; raised 2.47 on `#2C2C2E` |
| Dark, Increase Contrast | `#6563E6` | 4.69 | 4.48 on black, 3.31 on `#242426`; raised 2.57 on `#363638` |

Surfaces, as `AccentContrastTests` resolves them on iOS 26: in light white is `systemBackground` and `secondarySystemGroupedBackground`, `#F2F2F7` (`#EBEBF0` with Increase Contrast) is `systemGroupedBackground` and `secondarySystemBackground`; in dark black is `systemBackground` and `systemGroupedBackground`, `#1C1C1E` (`#242426` with Increase Contrast) is `secondarySystemGroupedBackground` and `secondarySystemBackground`. A sheet raises them one step (`userInterfaceLevel` elevated): in dark `systemBackground` and `systemGroupedBackground` become `#1C1C1E` (`#242426`), `secondarySystemGroupedBackground` and `secondarySystemBackground` become `#2C2C2E` (`#363638`); light does not change. The tests print the table.

Against the gate thresholds of §5.5: white on the accent is AA for text (4.5 or more) in all four rows, lowest 4.69 (dark, Increase Contrast). The accent holds 3.0 or more on the four gate surfaces in all four rows, lowest 3.01 (dark, on `#1C1C1E`). On the raised surfaces of a sheet it is under 3.0 in dark (2.47 on `#2C2C2E`) and in dark Increase Contrast (2.57 on `#363638`): a graphic there takes the lighter accent below.

System blue for comparison: light `#007AFF` 4.02 with white and 3.60 on `#F2F2F7`; dark `#0A84FF` 3.65 with white, 5.76 on black, 4.66 on `#1C1C1E`, 3.82 on `#2C2C2E`. Indigo is higher on the label in both appearances and on light surfaces (5.06 against 3.60 on `#F2F2F7`); it is lower on dark surfaces (3.01 against 4.66 on `#1C1C1E`).

A single colour cannot give 4.5:1 for a white label (luminance at most 0.183) and 4.5:1 as text on `#1C1C1E` (at least 0.228). Indigo has luminance 0.136 (light and dark), so its label is 5.65 and its contrast as text on `#1C1C1E` is 3.01. In light the same value reaches 4.5 as text (5.65 on white, 5.06 on `#F2F2F7`); in dark it does not (3.72 on black). Small text takes `Color.appAccentText`: the accent itself in light, in dark the lighter indigo `#8A88F0` (6.9 on black, 5.6 on `#1C1C1E`, 4.9 on `#262629`, 4.55 on a sheet's `#2C2C2E`; `#A3A1F7` with Increase Contrast, 5.2 on `#363638`), the tint of the iPhone (`appTint()`), so every label, link and control draws it; the fill of a prominent button is the accent itself (`.tint(Color.appAccent)`) under a white label. The accent is a button fill (label 4.5 or more), a ring, a glyph, the large minutes figure (3.0 or more, WCAG non-text and large text) [H:accessibility]. The Increase Contrast variants move the accent away from the surface it sits on, darker on light (`#3634A3`, 8.12 on `#EBEBF0`) and lighter on dark (`#6563E6`, 3.31 on `#242426`), as [H:color] advises for increased-contrast variants; the dark one lowers the white label from 5.65 to 4.69, still above 4.5.

**Raised surfaces.** A graphic drawn in a sheet, a selection mark or a row symbol, is `Color.appAccentOnRaised`: the accent itself on a screen and in light; in dark at the elevated level (`UITraitCollection.userInterfaceLevel`), the accent lightened in its hue (241°, saturation held): `#706FDC` with 3.32 on `#2C2C2E`, and with Increase Contrast `#7B79EA` with 3.31 on `#363638`. The colour is a `UIColor` provider that reads the level of the view it is drawn in, so one value serves a screen and a sheet. In sheets today: the selection marks of Add Cards and of the import preview, and the row symbols of the Anki destination sheet. The ring, the flame, the maturity ramp and the study stream are on screens; the stream and the onboarding are full-screen covers, which are not raised, so they take the accent. Card Detail and How It Works draw no accent graphic. The fill of a prominent button stays the accent: its white label asks 4.5, which the lighter ones do not give (4.20 and 3.64), and a button is named by its label, so its fill needs no 3:1 of its own.

Roles of the accent: prominent button fill (Study, Show Answer, Study This Deck), ring, the minutes figure of the Today card and of a deck's card (large text, held to the 3:1 of a glyph), `info.circle`, selection, the glow of the ring when a card is done and the specks of the burst (`study-screen.md`, Motion). Text in the accent is `Color.appAccentText`. The ring's track is the accent at 0.15 in light and 0.40 in dark (1.5:1 on the card, a circle one finds). Nothing else: no resting backgrounds, no card face.

In code the accent is `Color.appAccent`, and `Color.appAccentOnRaised` for a graphic that may sit in a sheet (`Shared/Support/Presentation.swift`): on the iPhone and in the widget the named asset `Color("AccentColor")` (in a widget `Color.accentColor` is the system tint), on the Mac `Color.accentColor`, so the system accent setting applies (§5.6). `Color.dailyRing` is `appAccent`; `Color.dailyRingTail` is the tail of the ring's gradient (§5.7).

`AccentColor.colorset` (the build setting `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor` is set):

```json
{
  "colors" : [
    { "idiom" : "universal",
      "color" : { "color-space" : "srgb", "components" : { "red" : "0x58", "green" : "0x56", "blue" : "0xD6", "alpha" : "1.000" } } },
    { "idiom" : "universal",
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "color" : { "color-space" : "srgb", "components" : { "red" : "0x58", "green" : "0x56", "blue" : "0xD6", "alpha" : "1.000" } } },
    { "idiom" : "universal",
      "appearances" : [ { "appearance" : "contrast", "value" : "high" } ],
      "color" : { "color-space" : "srgb", "components" : { "red" : "0x36", "green" : "0x34", "blue" : "0xA3", "alpha" : "1.000" } } },
    { "idiom" : "universal",
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" }, { "appearance" : "contrast", "value" : "high" } ],
      "color" : { "color-space" : "srgb", "components" : { "red" : "0x65", "green" : "0x63", "blue" : "0xE6", "alpha" : "1.000" } } }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

### 5.2 Neighbours of the accent

Hues and chroma are OKLCH; ΔE is 100 times the distance in OKLab; ratios are WCAG luminance ratios against the accent `#5856D6` (L 0.53, C 0.191, hue 278°). Neighbour colours are the ones in `Presentation.swift`.

- **Forgot red** (`Grade.again`, `#DC292A` light, `#D72828` dark; the table below) is OKLCH L 0.58 and 0.57 at chroma 0.213 and 0.209, hue 27°, 109° from the accent's 278°. Against the accent the luminance ratio is 1.18 (light) and 1.14 (dark), the lightness differs by 0.05 and 0.04, the chroma is 0.191 for the accent, ΔE is 33.2 and 32.8. Hue is the separator. Forgot always carries `xmark` and its word, and the accent never means "wrong". Its label is white at 4.8:1 and 5.0:1 (the lightness was lowered in steps of 0.01 until white held 4.5:1). On the stream screen the accent is a 30-pt ring (`StreamRing`, §5.7) and the Show Answer button, which the grade buttons replace.
- **Greens** (`Grade.hard`, `.good`, `.easy`; values in the table below) lie at OKLCH hue 166°, 112° from the accent. Chroma tells them apart in the order of the meaning: Hard is a dull sage, Good a soft mint, Easy a vivid jade (owner, 27.10.2026), and lightness rises a little with it. In light mode L is .74, .79 and .84 at 32, 60 and 90 % of the most chroma sRGB has at that lightness and hue; in dark mode L is .62, .69 and .76 at the same shares, so Easy glows on black and Hard does not. A reader without colour tells them apart by lightness too (ΔE of Hard to Good 7.1 in light and 8.6 in dark, of Good to Easy 7.6 and 8.8), and the title is on every button. The label is the lightest dark tint of the hue (chroma .04) that reaches 7:1, near black if none does. The accent is never next to the greens as a peer. Excel's greens lie at hue 152° to 157° and Office's at 135° to 143°; 166° sits next to the 170° the owner accepted. `GradeContrastTests` checks every pair by arithmetic on the hex values.
- **Swipe tint** (`Grade.tint`, at most 70 % over the card; the text keeps its colour): in light mode the tint is the grade's fill. In dark mode white text needs a ground darker than about L .5 on both card faces (`#1C1C1E`, `#2C2C2E`), so each green takes a tint of its own at its own chroma share (Hard `#566F64`, Good `#40725E`, Easy `#1D7759`, all L .51 to .52) and Again takes `#D22727`. Primary text on the four tints holds 5.5:1 or more in light and 7.1:1 or more in dark, the secondary text 4.3:1 and 4.7:1. The ring round a grade button (`Grade.ring`, shown only on a grade that has a button) is the grade's fill, except in light mode, where each green takes a deeper colour of its own hue and chroma share that reaches 3:1 on the screen's grey (`#F2F2F7`: Hard 3.09, Good 3.15, Easy 3.08; Again's red holds 4.28); in dark mode the fills hold 3.4:1 or more on `#1C1C1E`.
- **Maturity ramp** is one hue, the accent's indigo (OKLCH 278°, `Presentation.swift`): memory reads in the colour of the ring, apart from the grades' red and greens. Lightness 0.86 → 0.40 in light mode and 0.48 → 0.88 in dark, adjacent steps 10–13.5 ΔE2000 apart; New stays grey. Evidence: `ring-design.md`, "The maturity ramp in one hue".
- **Card face** stays `secondarySystemBackground`. The tint numbers above are measured on a neutral face; a tinted face would move all of them. The icon's cards (`#E4E3FA`, `#F8F7FF`) are not reused in the UI.

The four grades as `Grade.swatch` holds them, light mode / dark mode (OKLCH L, C; contrast of the label on the fill):

| Grade | Fill | L, C | Label (contrast) | Tint in dark | Ring in light |
|---|---|---|---|---|---|
| Forgot | `#DC292A` / `#D72828` | .58, .213 / .57, .209 | white 4.8 / 5.0 | `#D22727` | `#DC292A` |
| Hard | `#8EB5A4` / `#6F8E80` | .74, .049 / .62, .041 | `#09251B` 7.2 / `#000904` 5.6 | `#566F64` | `#729183` |
| Good | `#79CFAC` / `#64AD8F` | .79, .098 / .69, .087 | `#183429` 7.3 / `#00170D` 7.0 | `#40725E` | `#56957B` |
| Easy | `#43EAB3` / `#39CD9C` | .84, .156 / .76, .142 | `#183429` 8.7 / `#132F24` 7.1 | `#1D7759` | `#2A9C76` |

### 5.3 New / Learning / Review

Neutral, decided in §1. Each count is a figure of the deck's Today card or a tile: label and number in `.primary`, a count of 0 left out; same weight in every column; no symbols. The words carry the meaning, so nothing depends on colour [H:accessibility]. The order New, Learning, Review stays, as in Anki.

### 5.4 Role table

| Role | Colour | Where |
|---|---|---|
| Action, progress | `AccentColor` | §5.1 list |
| Text | `.primary`, `.secondary`, `.tertiary` | everything else |
| Counts | neutral | the deck's Today card, deck rows, Statistics tiles, Mac |
| Grades | `Grade.color` (fill), `Grade.onColor` (label), `Grade.tint`, `Grade.ring` | grade buttons, swipe tint, review history |
| Maturity | indigo ramp, hue 278 | statistics, Progress, the ladder |
| Streak | `Color.streak`, orange `#E05A00` (light), `#FF9F0A` (dark) | the lit flame and the days: the Day streak figure of the Today card and the small widget, `StreakLine` on the rests, the Progress screen's streak card; the flame is a grey (`.secondary`) outline while the streak is not kept today and an orange outline with an exclamation mark at risk; the days are secondary at 0 |
| Destructive | system red | Remove from List |

### 5.5 Gate test (spec)

`AccentContrastTests` in `VocTrainTests`: for appearance in light, dark, light + high contrast, dark + high contrast resolve `UIColor(named: "AccentColor")` and the surfaces `systemBackground`, `systemGroupedBackground`, `secondarySystemGroupedBackground`, `secondarySystemBackground` with `UITraitCollection`; compute WCAG relative luminance; print the table; fail below 4.5 for the white label and below 3.0 for every surface. Same on the Mac with `NSAppearance` pinned (`performAsCurrentDrawingAppearance`) [G §12]. Resolve system colours at run time; do not hard-code them. The same four surfaces resolved at the elevated level (`#2C2C2E` and `#363638` for the grouped rows in dark) are held by `theRaisedAccentHoldsItsContrastOnRaisedSurfaces` to 3.0 for `Color.appAccentOnRaised`, which also prints what the plain accent has there (2.47 and 2.57); `theRaisedAccentShowsInASheetAndNotInAFullScreenCover` presents a sheet and a full-screen cover and reads the colour each shows from its pixels.

```swift
func relativeLuminance(_ r: Double, _ g: Double, _ b: Double) -> Double {
    func lin(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
}

func contrast(_ a: Double, _ b: Double) -> Double {
    (max(a, b) + 0.05) / (min(a, b) + 0.05)
}
```

### 5.6 Mac accent

On macOS `AccentColor` applies only when the system accent is Multicolor, and selection and sidebar icons follow the user's choice [G §12][H:sidebars]. The owner's Graphite accent turned the ring, Study and Show Answer grey (25.10.2026), and the Mac looked unlike the iPhone. So `Color.appAccent` is the named `AccentColor` on the Mac too, and every Mac window takes it as its tint (`brandTint()`): the ring, the prominent buttons and the links are the iPhone's indigo; the selection of a table row still follows the system. Rollback: drop `.brandTint()` from the window roots and make `appAccent` `Color.accentColor` on the Mac.

### 5.7 Rings: drawing, middle, sources

The owner asked on 22.10.2026 for rings in the manner of the Fitness rings, taken from open-source rings and without a dependency. The drawing is `Shared/Support/ActivityRing.swift`: [MKRingProgressView](https://github.com/maxkonovalov/MKRingProgressView) by Max Konovalov (MIT) transcribed line for line — `RingProgressLayer.drawContent(in:)` as `RingDrawing.draw`, `GradientGenerator` as it is — inside a SwiftUI `Canvas` (`withCGContext`), so the same drawing runs on iOS, macOS and in the widget. The order is MK's: a backdrop circle in the start colour at 15 %; for progress past one lap a solid arc in the start colour, then the context rotated so the gradient arc ends at the head; the end circle in the start colour with a shadow (`w/3` blur, offset `w/10` along the way the ring runs, opacity 1) clipped to the ring; the gradient arc on top, a conic gradient image clipped to the stroked arc. `ProgressRing` hands the drawing at most 3 (`ProgressRing.maxLaps`; `DailyRing.fraction` itself stays capped at 1 and says whether the goal is met), so a ring is full at the goal and goes on over itself past it. Options: MK's defaults, except `hidesRingForZeroProgress` on (an empty ring shows only the backdrop) and the gradient image at the display's scale. `UIBezierPath(arcCenter:…, clockwise: true)` became `CGMutablePath.addArc(…, clockwise: false)`; colours resolved from SwiftUI are converted to device RGB before the generator reads their components. The gradient image depends on size and colours only, so the last one is cached while a ring animates.

**Laps.** Every ring draws done over goal, and past 1 the second lap goes over the first with the head's shadow, as the Fitness rings do; the drawn value stops at 3 (`ProgressRing.maxLaps`). Today, the rests, the stream's rings and the week rings take it from `DailyRingFigure.fraction` and `DailyProgress.weekRings`, the Progress calendar from `DayRecord.ringShare`. The widget's week draws the share of each day's goal from `WidgetSnapshot.weekRings`.

**Colour.** Head: the accent. Tail: the accent mixed with 25 % white in device RGB. `AccentContrastTests.ringGradientHoldsItsContrastInEveryAppearance` reads both ends from the pixels of a view in each appearance and holds the tail to 3:1 on the four surfaces and to 1.3:1 against the accent, in light, dark and both increased-contrast variants. The test reads pixels because `Color.accentColor` is the asset's accent only inside a view: `UIColor(Color.accentColor)` gives the system blue. Line width 15 % of the diameter, at least 3 pt.

The tail and its WCAG ratios, computed from the 8-bit values (surfaces as in §5.1):

| Appearance | Tail | Against the accent (1.3 or more) | On surface (3.0 or more) |
|---|---|---|---|
| Light | `#8280E0` | 1.64 | 3.44 on white, 3.08 on `#F2F2F7` |
| Light, Increase Contrast | `#6867BA` | 1.95 | 4.96 on white, 4.17 on `#EBEBF0` |
| Dark | `#8280E0` | 1.64 | 6.11 on black, 4.95 on `#1C1C1E`; raised 4.06 on `#2C2C2E` |
| Dark, Increase Contrast | `#8C8AEC` | 1.55 | 6.96 on black, 5.14 on `#242426`; raised 4.00 on `#363638` |

Every tail ratio meets the test's thresholds; the lowest on a surface is 3.08 (light, on `#F2F2F7`). A third of white instead of a quarter gives 2.62 there (`#908EE4`).

**Middle.** A ring holds nothing, at any size: it is a picture of the cards done against the goal and its laps (a tinted widget's lap number is the one exception, below). The state of the streak is `StreakState` (`DailyProgress.streakState`): `open`, today's streak step not done; `kept`, done; `atRisk`, the day after a missed one until the ring closes. `StreakFlame(state:)` draws the flame everywhere, outside the ring: a grey `flame` outline when open, `flame.fill` in `Color.streak` when kept, a `flame` outline in `Color.streak` followed by an `exclamationmark` when at risk, so the state survives a monochrome rendering. Orange is the one hue that means the habit: red is Forgot, the greens are recalled, indigo is the ring and the accent. `Color.streak` is `#E05A00` in light (3.7:1 on white, 3.3:1 on the light grouped grey) and `#FF9F0A` in dark (8:1 on the dark raised grey), above the 3:1 a glyph needs. The streak is the Day streak figure on the Today card and in the small widget (the flame and the days in `Color.streak`; at 0 days the outline flame and "0" in secondary), the `StreakLine` chip ("12-day streak") on the rests and in the rectangular widget, and the streak card at the top of Progress: "Day streak" in `.subheadline` over the flame (0.7 of the days' size, about 34 pt) and the days at 48 pt bold rounded (`@ScaledMetric(relativeTo: .largeTitle)`), and "Best: 21" in `.footnote` only when the best run is longer than the current one; at 0 days the outline flame and "Start your streak" in `.title3.weight(.semibold)`. The study bar and the Mac session header put the ring and the minutes in a row, left, right after the close button, with no streak, so the ring does not move when the text beside it changes its width; the burst of the streak step is on the large flame of the Streak kept rest's title.

| Place | Ring | Middle |
|---|---|---|
| Today (`TodayCard`; the Mac's Today page the same, on `tileGround`) | 112 pt | none; the figures beside it |
| Progress (`ProgressScreen`) | none: the streak card | none |
| Rest screen (`StreamRestView`) | 96 pt | none; the streak chip under it |
| Widget, small, medium and rectangular | 56, 96 and 44 pt | none (a tinted widget: the lap number, below); the circular widget is the system gauge with the minutes or a `checkmark` |
| Study bar (`StreamRing`) | 30 pt, `@ScaledMetric(relativeTo: .subheadline)`, at most 44 | empty |
| Mac session header | 28 pt | empty |
| Week rings (`WeekRings`) | 22 pt | empty |

VoiceOver: the Today card is a button behind its content, so the ring and each figure read on their own: the ring says "Daily Goal" and its share, the Day streak figure "12-day streak, kept today" ("not kept yet", "at risk"). `DailyRingView` reads "Daily Goal" and its share as its value, has no popover and is no button. `ProgressRing` is otherwise hidden from accessibility, as the text beside it says the figures; the study bar's flame reads the streak's state, and the bar's ring, flame and minutes are one combined element.

**Tinted and clear widgets.** In a tinted, clear or vibrant rendering (`widgetRenderingMode` is not full colour) the system keeps one tone and the opacity. The ring is flat (`ProgressRing.isFlat`): one colour, the track at 0.25 against the arc at 1.0, no shadow at the head, which would turn into a light halo. A lap past the goal is a number in the ring's middle, "2×" (`DailyRingFigure.laps`; `.caption.bold()` from 56 pt, else `.caption2.bold()`). The ring, the figures' values and a flame that is not an outline are `widgetAccentable`, so the state survives the tint by shape and tone. Not verified on a device or in the real system tint (§7.2).

Pictures: `VocTrainTests/RingTests.swift` (`TEST_RUNNER_STUDY_SHOTS_DIR`) writes `ring-1-today`, `ring-2-study-bar`, `ring-3-chip`, `ring-4-rest` in light and dark at 0, 40, 100, 160 and 230 % of the goal, and `ring-5-edges` at 5, 95, 100, 105, 150, 200 and 300 %; `MacVocTrainNgTests/RingSnapshotMacTests.swift` writes the Mac chip and the session ring.

## 6. Mac

### 6.1 Hierarchy

Level 0 is Today and Progress in the sidebar, which cover every deck; level 1 is a deck's page (the iPhone's deck screen), chosen in the same sidebar under Decks, Paused or Other Decks. The Mac has one window, so no level has a second one; the stream takes that window whole, sidebar away, until Done.

### 6.2 Window, toolbar and stream header

- Window: a `NavigationSplitView` with `.listStyle(.sidebar)`, the sidebar 200 to 320 pt wide (240 ideal), the window at least 760 x 520 pt, titled by the page. Sidebar symbols: Today `circle.circle`, Progress `chart.bar.xaxis`, a deck `rectangle.stack`, a paused deck `pause.circle`. The badge (`SidebarBadge`) is the plan left at the day's pace, "≈ 4 min", or a check once nothing is left, neutral like the counts everywhere; Today's badge prices the plan of the decks of the day as one, and a paused deck, a deck not read and any row before the ring is worked out have none. The (+) menu (`plus`, borderless) sits under the list.
- Toolbar by page: Today has the day's button at the right (`.borderedProminent`, accent for Study, grey for Catch Up and Learn 10 New Words) and the search field. A deck's page has the segmented `Cards | Statistics` (principal), Add Cards (`text.badge.plus`) and Learning Options (`slider.horizontal.3`), then after a fixed spacer the deck's button (`.borderedProminent`: Study This Deck in the accent, Learn 10 New Words in grey), and on Cards the Details button (`sidebar.trailing`, the inspector); the table carries its own search field.
- Strip (`DeckPage.strip`): under the toolbar of a deck, the deck's Today card (`DeckTodayCard`, §3.2: "Today" over "≈ 4 min" in the accent, Due, New and Learning as figures, "Done" with a check and "Next review tomorrow", "Paused") at the left and one `.borderedProminent` large button at the right: **Study This Deck** in the accent while the plan has cards left in the deck, else **Learn 10 New Words** in grey, ten new cards at once. The same button is last in the toolbar. ⌘L is the day's action from any page and ⌥⌘L the deck's.
- Session header (`SessionView.header`): `ProgressRing` at 28 pt, empty inside as the iPhone's study bar is, then the minutes to the next moment of the day as the iPhone bar says them (`NextStep`: "≈ 4 min"; none once all is done), left right after Done, Undo and the More menu; Done ends the stream and brings the sidebar back. A medal's toast stands in the middle of the row (§4.7). The stack under the card is the cards left to the next moment, after the ring too (Catch Up, Learn 10 New Words, Study These Now), and the rests are the iPhone's `StreamRestView`.
- Today (`TodayPageContent`): the iPhone's Today card (`TodayCard`, §2.3) on `Color.tileGround` (radius 16), 560 pt wide at most and centred, as a button to Progress; the day's button under it (`.borderedProminent`, extra large, the default action) and in the toolbar. No large title: the title bar holds "Today" and the date. A medal's toast stands under the button (§4.7). Without a deck: `EmptyTodayCard`, New Deck (`.borderedProminent`), Shared Decks (`.bordered`) and Use iCloud Drive Folder as a footnote-size link.
- Answer buttons (`GradeChoice`, §4.3): Forgot (← or 1) and Good (→ or 3), each with its arrow keycap and 38 pt high; Don't know and Know on a card's first showing. Return and Space mean Good (Know on a first showing). ↓ or 2 give Hard and ↑ or 4 give Easy with or without buttons for them; the preference "Hard and Easy Buttons" adds the buttons. The cheat sheet (`?`) names the grades while such a card is on screen: "Show the answer, then grade Know", "Grade: ← Don't know, → Know, ↑ Easy, ↓ Hard"; on later showings "Good" and "← Forgot, → Good, ↑ Easy, ↓ Hard".
- Study These Now: a button between Add and Done in the Add Cards sheet once cards are added (Done stays the default), and beside Import in the preview of a table of 1 to 50 cards imported into an empty deck. It adds what is typed or checked, closes the sheet and the stream of that deck starts with the added cards first.
- Spacing: `GradeChoice` gap 12 on Mac too; height stays 38 (HIG default Mac control 28, minimum 20 [H:accessibility]).
- Settings (`PreferencesView`, the `Settings` scene and ⌘,): Pronounce Automatically, Hard and Easy Buttons (footer "Adds Hard and Easy: buttons, and keys 2 and 4.") and Mnemit Folder; no settings button in the toolbar [H:settings].
- Status bar (`CardListView.StatusBar`): the number of cards, "N cards", or "M of N cards" while filtered; the counts of the day are in the filter strip above.
- Card table (`CardListView`): Question, Answer, Hint, Kind, Maturity, Due, Lapses, Stability, Difficulty ("5.2 / 10") and Recall. Lapses, Stability, Difficulty and Recall can be hidden from the header's menu (`customizationID`) and are empty for a card with no memory, a new card.

## 7. Checks, sources

### 7.1 Check matrix (on the 13 mini simulator or device; Mac with `vqa`)

| Screen | States |
|---|---|
| Today | every state of §2.4, cached first frame, one deck unreadable; light, dark, Increase Contrast, Reduce Transparency; Large, xxxLarge, AX3; landscape |
| Deck screen | counts with zeros, paused, practice rows present and absent, AX3 |
| Stream | question, revealed, grade area height equal in both stages, two and four answer buttons, 4-line question, 135-character answer, AX1 and AX3, landscape, the leech moment, a medal toast |
| Contrast | gate test table, all four appearances |
| Widgets | small, medium and rectangular; full colour and tinted, with a ring past its goal |
| Mac | the window at its minimum 760 x 520 (a deck page's toolbar with the inspector open, the shortcuts sheet; items must not overflow by default [H:toolbars]), Today, a deck and Progress in light and dark, Graphite and Multicolor accent |

### 7.2 UNVERIFIED

- All rendering: glass prominent button label colour and height, `safeAreaBar` with a `List`, principal toolbar ring, press feedback of a `.plain` button in a list row, concentric card corners. iOS 27 behaviour: the installed SDK is 27.1 (Xcode 27.1).
- Fitness and Reminders layouts (ring left, metrics right, counts trailing in My Lists) are from memory; only the facts in [A:fitness] were read.
- `.buttonStyle(.borderedProminent)` giving the prominent glass look in toolbars (the HIG names the `.prominent` style, the API mapping is from memory).
- A deck page's toolbar overflow at the window's minimum width 760 with the inspector open.
- That `minimumScaleFactor` does not re-track text.
- The tinted and clear widgets in the real system tint: the flat ring, the lap number and `widgetAccentable` were not looked at on a device.

### 7.3 Sources (opened 2026-10-21)

- [H:layout] https://developer.apple.com/design/human-interface-guidelines/layout
- [H:typography] https://developer.apple.com/design/human-interface-guidelines/typography (iOS size tables and SF Pro / SF Pro Rounded tracking tables read from the JSON feed)
- [H:buttons] https://developer.apple.com/design/human-interface-guidelines/buttons
- [H:lists-and-tables] https://developer.apple.com/design/human-interface-guidelines/lists-and-tables
- [H:color] https://developer.apple.com/design/human-interface-guidelines/color
- [H:toolbars] https://developer.apple.com/design/human-interface-guidelines/toolbars
- [H:tab-bars] https://developer.apple.com/design/human-interface-guidelines/tab-bars
- [H:sidebars] https://developer.apple.com/design/human-interface-guidelines/sidebars
- [H:activity-rings] https://developer.apple.com/design/human-interface-guidelines/activity-rings
- [H:accessibility] https://developer.apple.com/design/human-interface-guidelines/accessibility
- [H:sheets] https://developer.apple.com/design/human-interface-guidelines/sheets
- [H:context-menus] https://developer.apple.com/design/human-interface-guidelines/context-menus
- [H:launching] https://developer.apple.com/design/human-interface-guidelines/launching
- [H:windows] https://developer.apple.com/design/human-interface-guidelines/windows
- [H:settings] https://developer.apple.com/design/human-interface-guidelines/settings
- [H:materials], [H:dark-mode], [H:split-views], [H:progress-indicators], [H:gauges]: read, cited only for background (Liquid Glass stays out of the content layer; dark backgrounds use the system elevated set).
- [A:fitness] https://support.apple.com/guide/iphone/see-your-activity-summary-iph4c34a8a95/ios and https://support.apple.com/guide/iphone/get-started-with-fitness-ipha5dddb411/ios
- [U:loaf] https://useyourloaf.com/blog/iphone-13-screen-sizes/ (third party, not Apple)
- [U:nilcoalescing] https://nilcoalescing.com/blog/MultipleButtonsInListRows/
- [G] `~/Code/GUI-APPS.md` §6 (8 / 16 ms budget), §11 (right-aligned numbers, tabular digits), §12 (contrast gate, system accent on macOS)
- Code: `/Users/eugene/Code/Mnemit/VocTrain/Views/StartScreen.swift`, `TodayScreen.swift`, `VocTrain/Decks/DeckScreen.swift`, `VocTrain/Session/StudyView.swift`, `Shared/Session/TodaySummary.swift`, `DeckTodayCard.swift`, `GradeChoice.swift`, `CardFlight.swift`, `MedalToasts.swift`, `LeechMomentView.swift`, `Shared/Support/Figures.swift`, `Shared/Support/Presentation.swift`, `MacVocTrainNg/Shell/ShellView.swift`, `Shell/DeckPage.swift`, `Shell/TodayPage.swift`, `Views/Session/SessionView.swift`, `App/AppCommands.swift`; card data `~/Documents/greek-lessons/vocab/cards-a1a2.tsv`, `cards-b1.tsv`.
