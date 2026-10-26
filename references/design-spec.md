# Mnemit design spec: home, deck screen, study stream, accent, Mac

Visual spec of 2026-10-21 for one user (iPhone 13 mini on iOS 27, dark mode; Mac on macOS 27). Read from code: `StartScreen`, `DeckView`, `StudyCountsView`, `StudyView`, `GradeChoice`, `Presentation`, `CardFlight`, Mac `ShellView`, `SessionView`, `AppCommands`, `DailyProgress.swift` (`DailyGoal`, `DailyRing`, `Streak`, `DailyProgress.evaluate(_:at:calendar:)` over all decks) and `StudyStream.swift`. What the screens show and do: `screens.md`. No GUI was run for this spec.

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
| 4 | New / Learning / Review are **neutral**: number in primary label colour (0 in secondary), label in secondary. | Blue/red/green reuse the meanings of Forgot (red), Good (green) and the maturity ramp (the accent's indigo); the HIG asks for one colour per meaning [H:color]. The owner dislikes the coloured counts. | `StudyCount.color` stays in git history. |
| 5 | One accent, **system indigo** `#5856D6` in light and dark; Increase Contrast `#3634A3` (light) and `#6563E6` (dark). | Red means Forgot and the greens mean recalled, so the accent is neither; green reads as Excel and terracotta as Claude (owner, 21.10.2026). The icon tile is indigo too. Numbers in §5. | Change the values in the three `AccentColor.colorset` files (iPhone, Mac, widget). |
| 6 | Raise the deployment targets to **iOS 26 / macOS 26**. | Only the owner's devices run the app: iOS 27, macOS 27, built with Xcode 26.3. `safeAreaBar`, `.glassProminent`, `Button(role: .close)`, `ToolbarSpacer` need 26. | Keep 17 / 14, wrap five call sites in `#available` with `.safeAreaInset` and `.borderedProminent`. |
| 7 | Large title **Today**. The app name appears nowhere on the screen. | The HIG advises against naming a window after the app and asks for titles under 15 characters; large titles are the iOS pattern [H:toolbars]. | `.navigationBarTitleDisplayMode(.inline)`. |
| 8 | Mac: one window of a sidebar and pages (§6). Today, Progress and the decks sit in the sidebar; a deck's page has the strip with Study This Deck (Learn 10 New Words once nothing is left) and a toolbar of Cards \| Statistics, Add Cards and Learning Options. Settings stay in the app menu. | The Mac's day covers every deck, so one window shows the day and the decks together. | The tag `pre-single-window` holds the document-window app. |

### Diagnosis of the current screens

| Owner remark | Cause in code |
|---|---|
| Two taps | `StartScreen` pushes `DeckScreen` (and `reopen()` pushes it at launch); the Study button is on that second screen. |
| Huge "Mnemit" title | `.navigationTitle(Text(verbatim: "Mnemit"))` in a large-title stack. |
| Hand-made deck card, big rounded box | `DeckView` section 1 is a `VStack` with `StudyCountsColumns` (34 pt numerals, `design: .rounded`, `minimumScaleFactor(0.6)`) and a footnote; section 2 is a clear row with `listRowInsets(EdgeInsets())` that makes `.borderedProminent` + `.controlSize(.large)` run edge to edge. |
| Coloured counts, mixed weights | `StudyCountsLine`: semibold coloured number, regular secondary label, `subheadline`, 12 pt between pairs. The line sits under a `Label` with a symbol, so it starts under the symbol, one indent left of the name (derived from code, not seen on screen). |
| Kerning | No `.tracking` or `.kerning` anywhere in the sources (grep). SF Pro tracks −0.43 pt at 17 pt and +0.40 at 34; SF Pro Rounded tracks +0.37 at 17 and +0.51 at 13 [H:typography]. The count column puts 34 pt rounded numerals over 13 pt SF Pro labels, and `minimumScaleFactor` shrinks glyphs cut for 34 pt. Whether SwiftUI re-tracks scaled text is UNVERIFIED. Fix by construction: text styles only, no `.rounded`, no `minimumScaleFactor` on numerals. |
| Accent | `AccentColor.colorset` holds system indigo in all three catalogs (iPhone, Mac, widget): `#5856D6` in light and dark, `#3634A3` (light) and `#6563E6` (dark) with Increase Contrast (§5.1); counts are neutral; `.tint(.primary)` on the deck row keeps the accent off the text of a `Button`; Forgot is red, the ramp is the accent's indigo. |

## 2. iPhone home (Today)

### 2.1 Flow

Launch → Today. Tap **Study** (one tap) → the study stream covers the screen at once and shows the first card. No summary screen in between. A tap on a deck row pushes the deck screen.

Rejected: auto-start of the stream at launch. The learner would not see what is due, and the HIG asks launch to restore the previous position [H:launching]. Rejected: a tab bar. There is one section; a tab bar is for navigation and Study is an action [H:tab-bars].

### 2.2 Wireframe (375 x 812)

```
┌───────────────────────────────────────┐
│ 9:41                                  │ status area 50
│                              ( + )( … )│ nav bar 44: plus and ellipsis menus (trailing)
│ Today                                 │ large title 34 bold, system
│             ╭─────────╮               │
│             │   12    │               │ hero ring 168, line 18, round caps; the cards left, bold rounded
│             │cards left│              │ caption, secondary
│             ╰─────────╯               │
│ 🔥 ≈ 2 min to keep your 12-day streak │ streak chip: flame and sentence, subheadline semibold, rounded plate
│  ≈ 5 min · 412 words in memory …      │ gain line, subheadline secondary: ≈ 5 min · 412 words in memory · +15 today
│       M  T  W  T  F  S  S         ›   │ the week's rings, 22 pt; chevron at the row's end
│  DECKS                                │ system section header
│ ┌───────────────────────────────────┐ │
│ │ Greek B1                    27  › │ │ body | body, monospaced | chevron.forward, footnote semibold, tertiary
│ │ ───────────────────────────────── │ │
│ │ Greek A1–A2                 60  › │ │
│ └───────────────────────────────────┘ │
│ ╭──────────────────────────╮ ╭─────╮  │ bottom bar: Study (.borderedProminent) and the minimised search
│ │          Study           │ │  ⌕  │  │
│ ╰──────────────────────────╯ ╰─────╯  │
└───────────────────────────────────────┘ safe area bottom 34
```

Vertical budget on the 13 mini: 50 + 44 + about 52 (large title) + hero about 330 + header 35 + two rows 90 = about 600 of 812. The list scrolls where decks outgrow the rest.

### 2.3 Components

| Element | SwiftUI | Style and values |
|---|---|---|
| Container | `NavigationStack` > `List` | `.listStyle(.insetGrouped)`; no custom row insets; the hero's row is clear with no separator; margins come from the list (16). |
| Title | `.navigationTitle("Today")` | Large, automatic. German `Heute` already in the catalog. |
| Toolbar | `ToolbarItemGroup(.primaryAction)` | Trailing: `Menu("Add", systemImage: "plus")` and `Menu("More", systemImage: "ellipsis")` (their items: `screens.md`, Today). No info button: How It Works is the last row of the Progress screen. The HIG prefers symbols without borders in toolbars [H:toolbars]: `ellipsis` without the circle. |
| Hero | `TodayHero` in a `Button` (`.buttonStyle(.plain)`) | One element for VoiceOver (`.accessibilityElement(children: .combine)`); 24 pt between the parts: ring, the two text lines, the week; `.padding(.vertical, 8)`; a tap pushes Progress. |
| Ring | `HeroRing` over `ProgressRing` | 168 pt, line 18 (a tenth of the size), the drawing and sources in §5.7. In the middle the cards left (`RingCenter.cardsLeft`): the figure at 0.32 of the diameter, bold rounded, and "cards left" under it in secondary (the plural phrase "%lld cards left (caption)" minus its number); a `checkmark` in the accent once the ring is closed. The middle scales with the ring, not with the text size. The owner asked for Fitness quality on 22.10.2026; [H:activity-rings] advises against imitating the Activity rings, the ring here follows the owner. |
| Streak chip | `StreakChip` | Under the ring: the flame (`StreakFlame`, three states) and one sentence, `.subheadline.semibold`, on a rounded plate (`Color.streak` at 14 % when kept or at risk, secondary at 12 % when open). The sentence by state: kept "12-day streak", open "≈ 2 min to keep your 12-day streak", at risk "Close the ring to save your 12-day streak", 0 days "Start your streak · ≈ 2 min". One element for VoiceOver. |
| Gain line | `MemoryLine`, led by `TodayLead` | `.subheadline` secondary, `.monospacedDigit()`, centred, wraps at large sizes: "≈ 5 min · 412 words in memory · +15 today", the lead being the time that closes the ring while it is open, "3 left" once it is closed, "Nothing due · next tomorrow" on a day without cards; a milestone passed today replaces it with "50 words in memory!", semibold, with a `sparkles` glyph in the accent. The same text, without the lead, on the rests. The states are in §2.4. |
| Week | `WeekRings` | Seven rings of 22 pt, weekday initials, today last; the chevron `chevron.forward` (footnote semibold, tertiary) at the trailing end of the row. |
| Section header | `Section("Decks")` | System. |
| Deck row | `Button` with an `HStack` | `.buttonStyle(.plain)`, `contentShape(Rectangle())`, pushes the deck screen. Name `.body`; the cards of today's plan left in the deck, `.body`, `.monospacedDigit()`, trailing, or a `checkmark` in secondary when none; then `chevron.forward`. No subtitle. Until the deck is read the number is a redacted placeholder. A paused deck sits in the section "Paused": name in secondary, no counts. |
| Swipe | `.swipeActions`, `.contextMenu` | Pause Deck (Resume Deck in the Paused section); Remove from List for decks outside the folder. |
| Bottom bar | `.searchable` + `.searchToolbarBehavior(.minimize)`, `ToolbarItem(.bottomBar)`, `DefaultToolbarItem(kind: .search)` | One bar holds the day's button and the minimised Search All Cards. The button is `.borderedProminent`, labelled by `DayAction`: `Study` in the accent while the ring is open, `Catch Up` once the ring is closed and the plan has cards left, `Learn 10 New Words` once the plan is done, the last two tinted `.secondary`. No footnote under it. Its width is the bar's less 140 pt, at least 120 (`containerRelativeFrame`). |
| Accessibility | | Study button `accessibilityValue("\(due) cards left")`. The hero is one element: the ring reads "12 cards left" or "Ring closed", the chip "12-day streak, kept today" / "not kept yet" / its sentence at risk. |

### 2.4 States

| State | Hero | Button |
|---|---|---|
| Before the streak step | ring `16`, chip `≈ 2 min to keep your 12-day streak`, gain line leads `≈ 5 min` | `Study` |
| After the streak step, ring open | ring `16`, chip `12-day streak`, lead `≈ 4 min` | `Study` |
| Ring closed, cards left | ring a `checkmark`, chip `12-day streak`, lead `6 left` | `Catch Up` |
| Plan done, cards done today | ring a `checkmark`, no lead | `Learn 10 New Words`; opens the stream with ten new cards at once |
| Nothing due, nothing done today | ring a `checkmark`, lead `Nothing due · next tomorrow` | `Learn 10 New Words` |
| The day after a missed day, ring open | chip `Close the ring to save your 12-day streak`, the flame an orange outline with an exclamation mark | `Study` |
| No streak | chip `Start your streak · ≈ 2 min`, the flame an outline | `Study` |
| Rounds not known yet | ring `87`, chip `12-day streak` without its time | `Study` |
| Decks not read yet | placeholders, redacted, until every deck and the ring are in (`isDayReady`) | `Study` |
| No decks | the empty hero ring, one line of explanation, `New Deck` (`.glassProminent`, large) and `Use iCloud Drive Folder` (`.glass`, large), at most 320 pt wide, the AnkiWeb link under them; Open Deck… is in the `…` menu | – |
| Deck unreadable (iCloud) | row without counts | row stays tappable; the stream cover shows the existing failure view |
| Accessibility sizes (`isAccessibilitySize`) | the ring keeps its size, the chip's sentence and the gain line wrap and the list scrolls; at AX5 the hero keeps its order | unchanged |

The ring and every line beside it count cards; reviews do not enter. The goal, the done cards, the cards left, the minutes to the streak step (`RoundStatus`), the minutes and the pace are defined in `daily-ring.md`; what the lines say is in `screens.md`, Today. In the small widget the headline sits under the ring (64 pt, 56 pt with a time line, 48 pt at risk) and takes two lines where it does not fit; at risk it is the line Today shows, up to three lines in the subheadline font.

### 2.5 Budget

A tap on Study sets one state value and presents the stream cover in the next frame; `OpenDeck` loads behind a `ProgressView` inside the cover (target 8 ms median, 16 ms ceiling to first presented frame [G §6]). The first Today frame reads cached counts and the cached ring from `UserDefaults`; file reads stay on `Task.detached` as in `KnownDeckCounts`. The ring needs the review logs of both decks (`DeckActivity`); compute off the main actor and cache per study day.

## 3. iPhone deck screen

Pushed onto Today's stack from a deck row; what it shows and does: `screens.md`, Deck screen.

### 3.1 Wireframe

```
┌───────────────────────────────────────┐
│ ‹ Today       Greek B1         (+)(…) │ inline title; back; plus and ellipsis menus
│  14 cards today                       │ title3 semibold on the screen's background
│ ┌───────────────────────────────────┐ │
│ │ ▤ Cards                     2 236 │ │ LabeledContent, monospaced digits
│ │ ▥ Statistics                    › │ │ NavigationLink to StatisticsScreen
│ │ ⚙ Options                       › │ │ NavigationLink to DeckOptionsScreen
│ └───────────────────────────────────┘ │
│ ╭───────────────────────────────────╮ │ safeAreaBar(.bottom)
│ │          Study This Deck          │ │ StudyButton
│ ╰───────────────────────────────────╯ │
└───────────────────────────────────────┘
```

### 3.2 Components

| Element | SwiftUI | Values |
|---|---|---|
| Container | `List` in the stack | `.listStyle(.insetGrouped)`, `.navigationBarTitleDisplayMode(.inline)`. |
| Headline | `DeckHeadline` in a clear row | One line, `.title3.weight(.semibold)`: "14 cards today" (the plan's cards, `StudyCounts.total`), a check and "Done · next review tomorrow" ("Done" without a next date), "Paused" (wins over the counts). No headline before the counts are read, or for a deck with no cards. |
| Toolbar | `ToolbarItem(.primaryAction)` twice | `Menu("Add", systemImage: "plus")`: Add Cards, Import Cards… (wait for `isReadyToEdit`). `Menu("More", systemImage: "ellipsis")`: Practice Newest Words and Practice Today's Mistakes (`DeckPractice`; grey with nothing to practise), a divider, Rename…, Pause Deck or Resume Deck, Export…, Delete Deck. |
| Rows | `NavigationLink` with `RowLabel(title:symbol:)` | Cards with its count (`rectangle.stack`), Statistics (`chart.bar`), Options (`slider.horizontal.3`). |
| Study | `.safeAreaBar(edge: .bottom)` | `StudyButton` titled `Study This Deck` while the deck has cards in today's plan, else `Learn 10 New Words`: ten new cards of this deck at once. |
| Loading | the counts at once from `KnownDeckCounts`; the rest after `OpenDeck` loads | – |

## 4. Study stream screen

### 4.1 Wireframe (portrait, 13 mini, answer shown)

```
┌───────────────────────────────────────┐
│ ✕  ◔ 🔥 ≈ 4 min               ↶  (…)  │ nav 44: close, ring 30, flame, subheadline from the leading edge | undo | ellipsis
│ ┌───────────────────────────────────┐ │
│ │                                   │ │ card: margin 16, inner padding 24, radius 22,
│ │         ο Άγγλος    [spk]         │ │   secondarySystemBackground
│ │ ───────────────────────────────── │ │ divider at a fixed height
│ │       англичанин · Englishman     │ │ title2, regular
│ │       Ο Τζον είναι Άγγλος.        │ │ body, secondary
│ │                                   │ │
│ └───────────────────────────────────┘ │ card is about 500 high on the 13 mini
│    ╰───────────────────────────────╯    │ the cards waiting in the round: up to 4 blank edges, 8 pt apart, 7 pt narrower a side
│ ╭───────────────────────────────────╮ │
│ │            ✕ Forgot               │ │ 50, Grade.again.color
│ ╰───────────────────────────────────╯ │
│ ╭────────╮ ╭──────────╮ ╭────────╮    │ 50 high; gaps 12; widths 98 / 123 / 98
│ │  Hard  │ │   Good   │ │  Easy  │    │
│ ╰────────╯ ╰──────────╯ ╰────────╯    │
└───────────────────────────────────────┘ 12 bottom padding above the safe area; 8 under the bar; 12 + 32 for the edges between card and buttons
```

Width: 343 inside the 16 pt margins; (343 − 2 × 12) / 3.25 = 98.2, so Hard 98, Good 123, Easy 98.

### 4.2 Header

What the header shows: `screens.md`, Study.

- Leading: `Button(role: .close)` (xmark). It replaces the `chevron.backward` End Session button; the stream has no session to end, every grade is saved. The HIG asks for the standard Close symbol and no text label [H:toolbars].
- Leading, right after the close button (`.topBarLeading`, no shared background): `StreamRing` (a `ProgressRing`, 30 pt, `@ScaledMetric(relativeTo: .subheadline)` up to 44) + the figures, `.subheadline`, `.monospacedDigit()`, spacing 8, `.accessibilityElement(children: .combine)`. The ring is empty inside. Beside it the streak's flame by its state (`StreakFlame`, `.body.semibold`): an outline until today's streak step is done, filled in the streak's orange from then on. Past the goal it goes on over itself, up to three laps. A practice shows the word `Practice` as the principal text, without the ring.
- Trailing: an icon button `arrow.uturn.backward` (Undo) left of `Menu("More", systemImage: "ellipsis")`; there is no chip under the bar: its room goes to the card.
- The ring is where the cards go (`study-screen.md`, Motion): its frame is reported to `StudyMotion.ringHome` (global coordinates, nothing fixed), it steps and glows when a card is done, and the figures stand beside it.
- The streak is the flame beside the ring and no figure of its own. The goal-met moment is the ring that closes as the last card leaves and bursts at the rest of the plan.

### 4.2a Rests

The stream's rests (titles, figures and buttons: `screens.md`, Study) are one `StreamRestView`: the same ring (96 pt, the cards left or a check in it) and the streak chip under it, over the title (on the Streak kept rest, whose title is the streak, no chip: the streak's days with the filled flame beside them), the figures in secondary under it, the buttons 24 pt below, as wide as the card (iPhone 400 pt at most, Mac 320). The first button of a rest is `.borderedProminent` and the default action (Keep Going; Done); the others are `.bordered`; Learn 10 New Words carries no footnote. The rings of the last seven days (`WeekRings`) are 20 pt each, weekday initials under them, today last and bold.

The motion into and out of a rest (`RingTraveler`, `SlotOutline`, the staggered lines, Reduce Motion): `study-screen.md`, Motion.

### 4.3 Grade area

| Part | Spec |
|---|---|
| Container | One fixed-height container for both stages, so the card keeps its height and the divider with the question stays where it is when the answer opens. The grade rows stay in the layout at all times (`opacity`, `allowsHitTesting`, `accessibilityHidden` as `face` does for the answer) and Show Answer lies over them (an overlay, so it has their size). |
| Show Answer | `Button`, `.buttonStyle(.borderedProminent)`, `.controlSize(.large)`, full width, accent fill, the whole rectangle of the grade block (Forgot's top to the bottom of the row), corner radius 14 like the grade buttons. |
| Forgot | Full width, height `@ScaledMetric(relativeTo: .body) var height = 50`, `Label("Forgot", systemImage: "xmark")`, `.font(.body.weight(.semibold))`, fill `Grade.again.color`, white label. |
| Don't know | On a card's first showing (`Card.isNew`) the Forgot button reads "Don't know" (`GradeChoice.isNew`, `Grade.buttonTitle(isNew:)`): the same grade (Again), place, size, fill, key and swipe; only the label changes. |
| Hard / Good / Easy | `WeightedRow(weights: [1, 1.25, 1], spacing: 12)`, same height as Forgot, fills `Grade.hard/good/easy.color`, labels `Grade.onColor`: white on Forgot, a dark green on Hard and Good, near black on Easy (`GradeSwatch`; §5.2). No caption stands over the row. `minimumScaleFactor(0.7)` goes away; at `isAccessibilitySize` the four buttons stack, full width, gap 12. |
| Spacing | 12 between bezeled controls [H:accessibility]. Hard taken for Forgot is the costly slip for FSRS (comment in `GradeChoice`); the 12 between the rows keeps them apart, Forgot alone above the three "yes" grades. The scale of the study screens is `Spacing`: 4, 8, 12, 16, 24. |
| Corner radius | 14. |
| Press state | `Pressable` (opacity 0.6) stays; the HIG requires a press state on custom buttons [H:buttons]. |
| Landscape (`verticalSizeClass == .compact`) | One row: Forgot (170) + Hard/Good/Easy, gap 12, height 44. The progress leaves the row for the nav bar. |

Four coloured grade buttons are one choice control; the HIG limit of one or two prominent buttons per view [H:buttons] applies to action buttons.

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

Each role has one size, so a long answer does not shrink the card's text, and a short one does not grow it. `minimumScaleFactor(0.6)` stays only as a valve for the largest Dynamic Type sizes. The answer is split at the first `\n`; Greek is detected by script (`0x0370...0x03FF`, `0x1F00...0x1FFF`); `GreekSpeech.canSpeak` would also require an installed voice.

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

Behaviour: up to xxxLarge the layout is as drawn (estimate: Hard at 23 pt is about 52 wide in a 98 button). From AX1 the grade buttons stack and the summary ring moves above its text. The card is not capped; its text may reach the 0.6 scale floor at AX3 and above.

### 4.5 Code (typechecked)

```swift
/// Grade rows stay in the layout so the card keeps its height; Show Answer is laid over them and fills their rectangle.
struct GradeArea<Show: View, Rows: View>: View {
    var isRevealed: Bool
    @ViewBuilder var show: Show
    @ViewBuilder var rows: Rows

    var body: some View {
        rows
            .opacity(isRevealed ? 1 : 0)
            .allowsHitTesting(isRevealed)
            .accessibilityHidden(!isRevealed)
            .overlay { if !isRevealed { show } }
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

A single colour cannot give 4.5:1 for a white label (luminance at most 0.183) and 4.5:1 as text on `#1C1C1E` (at least 0.228). Indigo has luminance 0.136 (light and dark), so its label is 5.65 and its contrast as text on `#1C1C1E` is 3.01. In light the same value reaches 4.5 as text (5.65 on white, 5.06 on `#F2F2F7`); in dark it does not (3.72 on black). The accent is never small text in either appearance. It is a button fill (label 4.5 or more), a ring, a flame, a glyph (3.0 or more, WCAG non-text) [H:accessibility]. The Increase Contrast variants move the accent away from the surface it sits on, darker on light (`#3634A3`, 8.12 on `#EBEBF0`) and lighter on dark (`#6563E6`, 3.31 on `#242426`), as [H:color] advises for increased-contrast variants; the dark one lowers the white label from 5.65 to 4.69, still above 4.5.

**Raised surfaces.** A graphic drawn in a sheet, a selection mark or a row symbol, is `Color.appAccentOnRaised`: the accent itself on a screen and in light; in dark at the elevated level (`UITraitCollection.userInterfaceLevel`), the accent lightened in its hue (241°, saturation held): `#706FDC` with 3.32 on `#2C2C2E`, and with Increase Contrast `#7B79EA` with 3.31 on `#363638`. The colour is a `UIColor` provider that reads the level of the view it is drawn in, so one value serves a screen and a sheet. In sheets today: the selection marks of Add Cards and of the import preview, and the row symbols of the Anki destination sheet. The ring, the flame, the maturity ramp and the study stream are on screens; the stream and the onboarding are full-screen covers, which are not raised, so they take the accent. Card Detail and How It Works draw no accent graphic. The fill of a prominent button stays the accent: its white label asks 4.5, which the lighter ones do not give (4.20 and 3.64), and a button is named by its label, so its fill needs no 3:1 of its own.

Roles of the accent: prominent button fill (Study, Show Answer, Study This Deck), ring, flame when the goal is met, `info.circle`, selection, the glow of the ring when a card is done and the specks of the burst (`study-screen.md`, Motion). Nothing else: no text, no resting backgrounds, no card face.

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

- **Forgot red** (`Grade.again`, `#DC292A` light, `#D72828` dark) is OKLCH L 0.58 and 0.57 at chroma 0.213 and 0.209, hue 27°, 109° from the accent's 278°. Against the accent the luminance ratio is 1.18 (light) and 1.14 (dark), the lightness differs by 0.05 and 0.04, the chroma is 0.191 for the accent, ΔE is 33.2 and 32.8. Hue is the separator. Forgot always carries `xmark` and its word, and the accent never means "wrong". Its label is white at 4.8:1 and 5.0:1 (the lightness was lowered in steps of 0.01 until white held 4.5:1). On the stream screen the accent is a 30-pt ring (`StreamRing`, §5.7) and the Show Answer button, which the grade buttons replace.
- **Greens** (`Grade.hard` `#98FDD4` light and `#6FF0C0` dark, `Grade.good` `#3EDCA7` and `#59C59D`, `Grade.easy` `#299C76` and `#3B886B`) lie at OKLCH hue 166°, 112° from the accent. Lightness tells them apart: in light mode Hard L 0.92, Good 0.80, Easy 0.62, in dark mode 0.87, 0.75, 0.57; the chroma is 90 % of the sRGB maximum at that lightness in light mode and 75 % in dark mode (at 90 % Hard glows on black). Labels: `#183429` on Hard and Good (11.1:1 and 7.7:1), `#000904` on Easy (5.9:1) in light mode; `#183429` on Hard (9.5:1), `#0E2A1F` on Good (7.2:1), `#000904` on Easy (4.7:1) in dark mode. Hard to Good is ΔE 12.6 (12.2 in dark), Good to Easy 18.4 (18.1): lightness carries the order, which a red-green deficiency leaves, and the title is on every button all the same. The accent is never next to the greens as a peer. Excel's greens lie at hue 152° to 157° and Office's at 135° to 143°; 166° sits next to the 170° the owner accepted. Easy in light mode is 3.6 ΔE from Excel's `#21A366` and in dark mode 7.2 from `#107C41`; if Easy reads as Office, all three greens move up in hue (the comment of `Grade.color` names the rule). `GradeContrastTests` checks every pair by arithmetic on the hex values.
- **Swipe tint** (`Grade.tint`, at most 70 % over the card; the text keeps its colour): in light mode the tint is the grade's fill. In dark mode the greens' fills are too light for white text on the card, which needs a ground darker than about L 0.5 on both card faces (`#1C1C1E`, `#2C2C2E`): Hard, Good and Easy share `#32745B` (L 0.51, chroma 0.079, the 75 % share) and Again takes `#D22727`. Primary text on the four tints holds 5.5:1 or more in light and 7.1:1 or more in dark, the secondary text 4.3:1 and 4.7:1. The ring round a grade button (`Grade.ring`) is the grade's fill, except in light mode, where Hard, Good and Easy take `#299C76`, the lightest green that reaches 3:1 on the screen's grey (3.08:1; Again's red holds 4.3:1); in dark mode the fills hold 3.4:1 or more on `#1C1C1E`.
- **Maturity ramp** is one hue, the accent's indigo (OKLCH 278°, `Presentation.swift`): memory reads in the colour of the ring, apart from the grades' red and greens. Lightness 0.86 → 0.40 in light mode and 0.42 → 0.85 in dark, adjacent steps 10–13.5 ΔE2000 apart; New stays grey. Evidence: `ring-design.md`, "The maturity ramp in one hue".
- **Card face** stays `secondarySystemBackground`. The tint numbers above are measured on a neutral face; a tinted face would move all of them. The icon's cards (`#E4E3FA`, `#F8F7FF`) are not reused in the UI.

### 5.3 New / Learning / Review

Neutral, decided in §1. Number `.primary`, 0 in `.secondary`; label `.secondary`; same weight in every column; no symbols. The words carry the meaning, so nothing depends on colour [H:accessibility]. The order New, Learning, Review stays, as in Anki.

### 5.4 Role table

| Role | Colour | Where |
|---|---|---|
| Action, progress | `AccentColor` | §5.1 list |
| Text | `.primary`, `.secondary`, `.tertiary` | everything else |
| Counts | neutral | Today row, deck screen, Mac |
| Grades | `Grade.color` (fill), `Grade.onColor` (label), `Grade.tint`, `Grade.ring` | grade buttons, swipe tint, review history |
| Maturity | indigo ramp, hue 278 | statistics, Progress, the ladder |
| Streak | `Color.streak`, orange `#E05A00` (light), `#FF9F0A` (dark) | the lit flame: Today, the rests, the widget, the Mac, the Progress screen's large streak; grey (`.secondary`) while the streak is not kept today or is at risk |
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

**Laps.** Every ring draws done over goal, and past 1 the second lap goes over the first with the head's shadow, as the Fitness rings do; the drawn value stops at 3 (`ProgressRing.maxLaps`). Today, the rests, the stream's rings and the week rings take it from `DailyRingFigure.fraction` and `DailyProgress.weekRings`, the Progress calendar from `DayRecord.ringShare`. The middle still counts the cards left until the goal, then it is the `checkmark`. The widget's week keeps closed or not.

**Colour.** Head: the accent. Tail: the accent mixed with 25 % white in device RGB. `AccentContrastTests.ringGradientHoldsItsContrastInEveryAppearance` reads both ends from the pixels of a view in each appearance and holds the tail to 3:1 on the four surfaces and to 1.3:1 against the accent, in light, dark and both increased-contrast variants. The test reads pixels because `Color.accentColor` is the asset's accent only inside a view: `UIColor(Color.accentColor)` gives the system blue. Line width 15 % of the diameter, at least 3 pt.

The tail and its WCAG ratios, computed from the 8-bit values (surfaces as in §5.1):

| Appearance | Tail | Against the accent (1.3 or more) | On surface (3.0 or more) |
|---|---|---|---|
| Light | `#8280E0` | 1.64 | 3.44 on white, 3.08 on `#F2F2F7` |
| Light, Increase Contrast | `#6867BA` | 1.95 | 4.96 on white, 4.17 on `#EBEBF0` |
| Dark | `#8280E0` | 1.64 | 6.11 on black, 4.95 on `#1C1C1E`; raised 4.06 on `#2C2C2E` |
| Dark, Increase Contrast | `#8C8AEC` | 1.55 | 6.96 on black, 5.14 on `#242426`; raised 4.00 on `#363638` |

Every tail ratio meets the test's thresholds; the lowest on a surface is 3.08 (light, on `#F2F2F7`). A third of white instead of a quarter gives 2.62 there (`#908EE4`).

**Middle.** The ring holds its own quantity: `RingCenter` is `.cardsLeft(n)`, the cards that close the ring (`DailyProgress.cardsToClose`: the plan's cards left, at most the goal less the done), `.done`, a `checkmark` once the ring is closed, or `.none` before the first evaluation. The size of the ring decides how much shows (`RingCenter.shown(at:)`): the figure from 56 pt (0.4 of the diameter, bold rounded, `monospacedDigit`, scaled down to 0.5), the caption "cards left" from 88 pt (figure 0.32, caption 0.085 of the diameter, at least 10 pt), the `checkmark` (0.36 of the diameter, in `Color.dailyRing`) from 56 pt, and nothing below 56 pt: the rings of the bars and of the week are empty inside. No flame and no days in a ring at any size. The state of the streak is `StreakState` (`DailyProgress.streakState`): `open`, today's streak step not done; `kept`, done; `atRisk`, the day after a missed one until the ring closes. `StreakFlame(state:)` draws the flame everywhere, outside the ring: a grey `flame` outline when open, `flame.fill` in `Color.streak` when kept, a `flame` outline in `Color.streak` followed by an `exclamationmark` when at risk, so the state survives a monochrome rendering. Orange is the one hue that means the habit: red is Forgot, the greens are recalled, indigo is the ring and the accent. `Color.streak` is `#E05A00` in light (3.7:1 on white, 3.3:1 on the light grouped grey) and `#FF9F0A` in dark (8:1 on the dark raised grey), above the 3:1 a glyph needs. The streak is the `StreakChip` (Ring table above) on Today and the rests, and the statistic at the top of Progress: the flame at 34 pt, the days at 56 pt bold rounded, "day streak" in `.subheadline`, and "Best: 21" in `.footnote` only when the best run is longer than the current one. The study bar and the Mac session header put the ring, the flame (`.body.semibold`) and the figures in a row, left, right after the close button, so the ring does not move when the text beside it changes its width; the burst of the streak step is on the large flame of the Streak kept rest's title.

| Place | Ring | Middle |
|---|---|---|
| Today (`TodayHero`) | 168 pt (the Mac's Today page 200 pt) | cards left with its caption, or `checkmark` |
| Progress (`ProgressScreen`) | none: the streak statistic | none |
| Rest screen (`StreamRestView`) | 96 pt | cards left with its caption, or `checkmark`; the chip under the ring |
| Widget, small and medium | 64, 56 or 48 pt, 60 pt | the cards left, or `checkmark` |
| Study bar (`StreamRing`) | 30 pt, `@ScaledMetric(relativeTo: .subheadline)`, at most 44 | empty |
| Mac session header | 28 pt | empty |
| Week rings (`WeekRings`) | 22 pt | empty |

VoiceOver: the Today hero is one element: the ring reads "12 cards left" or "Ring closed", the chip its sentence with the state ("12-day streak, kept today", "not kept yet"), then the gain line and the week. `DailyRingView` reads "Daily Goal", or the middle where one shows, and "14 / 36" as its value. `DailyRingView` has no popover and is no button. `ProgressRing` is otherwise hidden from accessibility, as the text beside it says the figures; the study bar's flame reads the streak's state, and the bar's ring, flame and figures are one combined element.

Pictures: `VocTrainTests/RingTests.swift` (`TEST_RUNNER_STUDY_SHOTS_DIR`) writes `ring-1-today`, `ring-2-study-bar`, `ring-3-chip`, `ring-4-rest` in light and dark at 0, 40, 100, 160 and 230 % of the goal, and `ring-5-edges` at 5, 95, 100, 105, 150, 200 and 300 %; `MacVocTrainNgTests/RingSnapshotMacTests.swift` writes the Mac chip and the session ring.

## 6. Mac

### 6.1 Hierarchy

Level 0 is Today and Progress in the sidebar, which cover every deck; level 1 is a deck's page (the iPhone's deck screen), chosen in the same sidebar under Decks, Paused or Other Decks. The Mac has one window, so no level has a second one; the stream takes that window whole, sidebar away, until Done.

### 6.2 Window, toolbar and stream header

- Window: a `NavigationSplitView` with `.listStyle(.sidebar)`, the sidebar 200 to 320 pt wide (240 ideal), the window at least 760 x 520 pt, titled by the page. Sidebar symbols: Today `circle.circle`, Progress `chart.bar.xaxis`, a deck `rectangle.stack`, a paused deck `pause.circle`. The badge is the cards left of today's plan, neutral like the counts everywhere. The (+) menu (`plus`, borderless) sits under the list.
- Toolbar by page: Today has the day's button at the right (`.borderedProminent`, accent for Study, grey for Catch Up and Learn 10 New Words) and the search field. A deck's page has the segmented `Cards | Statistics` (principal), Add Cards (`text.badge.plus`) and Learning Options (`slider.horizontal.3`), and on Cards the Details button (`sidebar.trailing`, the inspector); the table carries its own search field. The window has no ring chip and no Study button in the toolbar of a deck.
- Strip (`DeckPageContent.strip`): under the toolbar of a deck, the headline (`.title3.weight(.semibold)`: "14 cards today", a check and "Done · next review tomorrow", "Paused") at the left and one `.borderedProminent` large button at the right: **Study This Deck** in the accent while the plan has cards left in the deck, else **Learn 10 New Words** in grey, ten new cards at once. ⌘L is the day's action from any page and ⌥⌘L the deck's; neither is the twin of a toolbar item [H:toolbars].
- Session header (`SessionView.header`): `ProgressRing` at 28 pt, empty inside as the iPhone's study bar is, then the flame and the iPhone bar's figures, left right after Done ("≈ 4 min" while the goal is open, "36 cards today" once it is met), Undo and the More menu; Done ends the stream and brings the sidebar back.
- Spacing: `GradeChoice` gap 12 on Mac too; height stays 38 (HIG default Mac control 28, minimum 20 [H:accessibility]).
- Settings: the `Settings` scene and ⌘, stay; no settings button in the toolbar [H:settings]. A daily-goal setting, if one is added, becomes a pane there.
- Status bar (`CardListView.StatusBar`): the number of cards, "N cards", or "M of N cards" while filtered; the counts of the day are in the filter strip above.

## 7. Checks, sources

### 7.1 Check matrix (on the 13 mini simulator or device; Mac with `vqa`)

| Screen | States |
|---|---|
| Today | due, nothing due with reviews, nothing due without reviews, no decks, cached first frame, one deck unreadable; light, dark, Increase Contrast, Reduce Transparency; Large, xxxLarge, AX3; landscape |
| Deck screen | counts with zeros, paused, practice rows present and absent, AX3 |
| Stream | question, revealed, grade area height equal in both stages, 4-line question, 135-character answer, AX1 and AX3, landscape |
| Contrast | gate test table, all four appearances |
| Mac | the window at its minimum 760 x 520 (a deck page's toolbar with the inspector open, the shortcuts sheet; items must not overflow by default [H:toolbars]), Today, a deck and Progress in light and dark, Graphite and Multicolor accent |

### 7.2 UNVERIFIED

- All rendering: glass prominent button label colour and height, `safeAreaBar` with a `List`, principal toolbar ring, press feedback of a `.plain` button in a list row, concentric card corners. iOS 27 behaviour: the installed SDK is 26.2 (Xcode 26.3).
- Fitness and Reminders layouts (ring left, metrics right, counts trailing in My Lists) are from memory; only the facts in [A:fitness] were read.
- `.buttonStyle(.borderedProminent)` giving the prominent glass look in toolbars (the HIG names the `.prominent` style, the API mapping is from memory).
- A deck page's toolbar overflow at the window's minimum width 760 with the inspector open.
- That `minimumScaleFactor` does not re-track text.

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
- Code: `/Users/eugene/Code/Mnemit/VocTrain/Views/StartScreen.swift`, `DeckView.swift`, `StudyCountsView.swift`, `VocTrain/Session/StudyView.swift`, `Shared/Session/GradeChoice.swift`, `Shared/Session/CardFlight.swift`, `Shared/Support/Presentation.swift`, `MacVocTrainNg/Shell/ShellView.swift`, `Shell/DeckPage.swift`, `Views/Session/SessionView.swift`, `App/AppCommands.swift`; card data `~/Documents/greek-lessons/vocab/cards-a1a2.tsv`, `cards-b1.tsv`.
