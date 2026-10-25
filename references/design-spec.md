# Mnemit design spec: home, deck screen, study stream, accent, Mac

Visual spec of 2026-10-21 for one user (iPhone 13 mini on iOS 27, dark mode; Mac on macOS 27). Read from code: `StartScreen`, `DeckView`, `StudyCountsView`, `StudyView`, `GradeChoice`, `Presentation`, `CardFlight`, Mac `DocumentView`, `SessionView`, `WelcomeView`, `AppCommands`, `DailyProgress.swift` (`DailyGoal`, `DailyRing`, `Streak`, `DailyProgress.evaluate(_:at:calendar:)` over all decks) and `StudyStream.swift`. What the screens show and do: `screens.md`. No GUI was run for this spec.

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
| 8 | Mac: the deck window's toolbar gets the ring chip and a Study button, prominent while the deck has cards due, else Push On (§6.2); the Today window (`WelcomeWindow`, `TodayWindowContent`) is the Mac's Today. Settings stay in the app menu. | A document window shows one deck, so the decks of Today live in the Today window. | Remove the chip. |

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
│                                  ( … )│ nav bar 44: ellipsis menu (trailing)
│ Today                                 │ large title 34 bold, system
│ ┌───────────────────────────────────┐ │ insetGrouped section, margin 16
│ │  ╭─────╮   87 cards left          │ │ title2 semibold, monospaced digits
│ │  │  ◔  │   14 of 101 cards        │ │ subheadline, secondary; the flame over the streak's days in the ring
│ │  ╰─────╯                          │ │ ring 72, line 10, round caps
│ │  ≈ 28 words in memory · +15 today │ │ subheadline, secondary, the width of the row
│ └───────────────────────────────────┘ │
│  DECKS                                │ system section header
│ ┌───────────────────────────────────┐ │
│ │ Greek B1                    27  › │ │ body | body, monospaced | chevron.forward, footnote semibold, tertiary
│ │ 20 new · 4 learning · 3 review    │ │ subheadline, secondary, monospaced digits
│ │ ───────────────────────────────── │ │
│ │ Greek A1–A2                 60  › │ │
│ │ 30 new · 0 learning · 30 review   │ │
│ └───────────────────────────────────┘ │
│                                       │
│ ╭───────────────────────────────────╮ │ safeAreaBar(.bottom)
│ │               Study               │ │ .glassProminent, .large, side margin 16
│ ╰───────────────────────────────────╯ │ 8 above the home indicator zone
└───────────────────────────────────────┘ safe area bottom 34
```

Vertical budget on the 13 mini: 50 + 44 + about 52 (large title) + summary 88 + header 35 + two rows 130 = about 400 of 812. Four more decks fit above the button.

### 2.3 Components

| Element | SwiftUI | Style and values |
|---|---|---|
| Container | `NavigationStack` > `List` | `.listStyle(.insetGrouped)`; no custom row insets, no custom backgrounds; margins come from the list (16). |
| Title | `.navigationTitle("Today")` | Large, automatic. German `Heute` already in the catalog. |
| Toolbar | `ToolbarItemGroup(.primaryAction)` | Trailing: `Menu("Add", systemImage: "plus")` and `Menu("More", systemImage: "ellipsis")` (their items: `screens.md`, Today). No info button: How Today Works is the last row of the Progress screen. The HIG prefers symbols without borders in toolbars [H:toolbars]: `ellipsis` without the circle. |
| Summary | `Section { SummaryRow }` | Ring 72 (`@ScaledMetric(relativeTo: .title2)`), gap 16, row `.padding(.vertical, 8)`. Lines: `.title2.weight(.semibold)` / `.subheadline` secondary beside the ring, the words line `.subheadline` under the ring row. One `.monospacedDigit()` on the text column. `.accessibilityElement(children: .combine)`. |
| Ring | `ProgressRing` | A Fitness-style ring, drawing and sources in §5.7: line 15 % of the diameter, gradient along the stroke from a lighter tint of the accent to the accent, round caps, dim track, full at the goal and full after it (`DailyRing.fraction` is capped at 1). In the middle the streak: `flame.fill` over the days (bold rounded number, no caption), the days alone below a diameter of 44 pt, nothing at 0 days; §5.7. The owner asked for Fitness quality on 22.10.2026; [H:activity-rings] advises against imitating the Activity rings, the ring here follows the owner. |
| Section header | `Section("Decks")` | System. |
| Deck row | `Button` with an `HStack` | `.buttonStyle(.plain)`, `contentShape(Rectangle())`, pushes the deck screen. Name `.body`; subtitle `.subheadline` secondary, `.monospacedDigit()`; total `.body`, `.monospacedDigit()`, trailing; then `chevron.forward`, `.footnote.weight(.semibold)`, tertiary, hidden from accessibility (drawn by hand: the row is a button, not a `NavigationLink`). Until the deck is read the subtitle is a redacted placeholder of the line it will have, so the row does not grow. A paused deck: name and subtitle `Paused` in secondary, no counts. |
| Zero due | same row | Trailing `checkmark` in secondary, subtitle `Next review <relative>` from `Format.due`. |
| Swipe | `.swipeActions`, `.contextMenu` | Pause Deck (Resume Deck in the Paused section); Remove from List for decks outside the folder. |
| Primary action | `.safeAreaBar(edge: .bottom)` | `Button` full width, its label named by `DayAction`: `Study` with `.buttonStyle(.glassProminent)` while the ring is open, `Catch Up` with `.glass` once the ring is closed and the plan has cards left, `Push On` with `.glass` once the plan is done, with `More reviews in the days ahead` in `.footnote` secondary under it. `.controlSize(.large)`, `.padding(.horizontal, 16)`, `.padding(.bottom, 8)`. System height, no fixed frame, no icon, no count in the label. The scroll edge effect comes from `safeAreaBar`; no background under it [H:layout]. |
| Accessibility | | Study button `accessibilityValue("\(due) cards left")`. |

### 2.4 States

| State | Summary row | Button |
|---|---|---|
| Before the first round | `≈ 2 min to keep your streak` (title2, two lines where it does not fit), `3 of 30 cards`, a grey flame over `12` in the ring, `≈ 28 words in memory` | `Study`, `.glassProminent` |
| After the streak step | `16 cards left · ≈ 4 min` (the time drops under the line where it does not fit), `14 of 30 cards`, the flame in `Color.streak`, `≈ 28 words in memory · +15 today` on one line under the ring row, as wide as the row (beside the ring a 375 pt screen leaves too little: the gain fell under the words); at a large type size the one text wraps, the gain is never stacked as a line of its own; a milestone passed today replaces the words line with `50 words in memory!`, semibold, with a `sparkles` glyph in the accent | `Study`, `.glassProminent` |
| Rounds done, cards left | `Ring closed`, `31 cards today · 6 left`, the lit flame, words | `Catch Up`, `.glass` |
| Rounds not known yet | `87 cards left · ≈ 7 min`, no second line until the ring is evaluated | `Study`, `.glassProminent` |
| Nothing due, cards done today | full ring, `All done`, `N cards today`, the flame | `Push On`, `.glass`, with `More reviews in the days ahead` under it; opens the stream with ten new cards at once |
| Nothing due, no cards done today | track only, `Nothing due`, `Next review <relative date>`, no `x of y` line | `Push On`, `.glass` |
| No decks | `ContentUnavailableView`; title `No Decks`; `New Deck` (`.glassProminent`, large) and `Use iCloud Drive Folder` (`.glass`, large), at most 320 pt wide, the AnkiWeb link under them; Open Deck… is in the `…` menu | – |
| First frame | Last counts and ring from `UserDefaults` | enabled when the cached total is above 0 |
| Deck unreadable (iCloud) | row without counts | row stays tappable; the stream cover shows the existing failure view |
| Accessibility sizes (`isAccessibilitySize`) | ring above the text (`AnyLayout` switch) | unchanged |

The ring and every line beside it count cards; reviews do not enter. The goal, the done cards, the cards left, the headline (`RoundStatus`), the minutes and the pace are defined in `daily-ring.md`; what the lines say is in `screens.md`, Today. In the small widget the headline sits under the ring (56 pt) and takes two lines where it does not fit.

### 2.5 Budget

A tap on Study sets one state value and presents the stream cover in the next frame; `OpenDeck` loads behind a `ProgressView` inside the cover (target 8 ms median, 16 ms ceiling to first presented frame [G §6]). The first Today frame reads cached counts and the cached ring from `UserDefaults`; file reads stay on `Task.detached` as in `KnownDeckCounts`. The ring needs the review logs of both decks (`DeckActivity`); compute off the main actor and cache per study day.

## 3. iPhone deck screen

Pushed onto Today's stack from a deck row; what it shows and does: `screens.md`, Deck screen.

### 3.1 Wireframe

```
┌───────────────────────────────────────┐
│ ‹ Today       Greek B1             (…)│ inline title; back; ellipsis menu
│  TODAY                                │
│ ┌───────────────────────────────────┐ │
│ │    20          4          3       │ │ title2 semibold, monospaced; 0 in secondary
│ │   New      Learning     Review    │ │ footnote, secondary
│ └───────────────────────────────────┘ │
│  What today's plan takes from this    │ footer, footnote
│  deck.                                │
│ ┌───────────────────────────────────┐ │
│ │ ▤ Cards                     2 236 │ │ LabeledContent, monospaced digits
│ │ + Add Cards                       │ │
│ │ ⤓ Import Cards…                   │ │
│ │ ◎ Shared Decks on AnkiWeb         │ │
│ └───────────────────────────────────┘ │
│  PRACTICE                             │
│ ┌───────────────────────────────────┐ │
│ │ ▶ Practice Newest Words           │ │ rectangle.stack.badge.play
│ │ ↻ Practice Today's Mistakes       │ │ only when mistakes exist
│ └───────────────────────────────────┘ │
│ ┌───────────────────────────────────┐ │
│ │ ▥ Statistics                    › │ │ NavigationLink to StatisticsScreen
│ │ ⚙ Options                       › │ │
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
| Toolbar | `ToolbarItem(.primaryAction)` | `Menu("More", systemImage: "ellipsis")` (items: `screens.md`). |
| Counts | `CountsRow` inside a `Section` | Three equal columns, value `.title2.weight(.semibold)` + `.monospacedDigit()`, label `.footnote` secondary, gap 2, `.padding(.vertical, 4)`. At accessibility sizes the columns stack with left alignment. No colours. |
| Totals | `LabeledContent("Cards", value:, format: .number)` | Section `.monospacedDigit()`. |
| Rows | `Button` and `NavigationLink` with `RowLabel(title:symbol:)` | Practice rows use `StudyStream(practicingNewestWordsIn:)` and `StudyStream(practicingMistakesIn:)`; a row that has no cards is hidden. Statistics: `chart.bar`, existing `StatisticsScreen`. |
| Study | `.safeAreaBar(edge: .bottom)` | `StudyButton` titled `Study This Deck` while the deck has cards in today's plan, else `Push On` with `More reviews in the days ahead` under it: ten new cards of this deck at once. |
| Loading | counts at once from `KnownDeckCounts`; totals, retention after `OpenDeck` loads | – |

## 4. Study stream screen

### 4.1 Wireframe (portrait, 13 mini, answer shown)

```
┌───────────────────────────────────────┐
│ ✕          ◔  ≈ 4 min         ↶  (…) │ nav 44: close | principal: ring 30 + subheadline | undo | ellipsis
│ ┌───────────────────────────────────┐ │
│ │                                   │ │ card: margin 16, inner padding 24, radius 22,
│ │         ο Άγγλος    [spk]         │ │   secondarySystemBackground
│ │ ───────────────────────────────── │ │ divider at a fixed height
│ │       англичанин · Englishman     │ │ title2, regular
│ │       Ο Τζον είναι Άγγλος.        │ │ body, secondary
│ │                                   │ │
│ └───────────────────────────────────┘ │ card is about 500 high on the 13 mini
│    ╰───────────────────────────────╯    │ the cards waiting in the round: up to 4 blank edges, 6 pt apart
│ ╭───────────────────────────────────╮ │
│ │            ✕ Forgot               │ │ 50, Grade.again.color
│ ╰───────────────────────────────────╯ │
│               Recalled                │ footnote, secondary; 12 above, 4 below
│ ╭────────╮ ╭──────────╮ ╭────────╮    │ 50 high; gaps 12; widths 98 / 123 / 98
│ │  Hard  │ │   Good   │ │  Easy  │    │
│ ╰────────╯ ╰──────────╯ ╰────────╯    │
└───────────────────────────────────────┘ 12 bottom padding above the safe area; 8 under the bar; 12 + 24 for the edges between card and buttons
```

Width: 343 inside the 16 pt margins; (343 − 2 × 12) / 3.25 = 98.2, so Hard 98, Good 123, Easy 98.

### 4.2 Header

What the header shows: `screens.md`, Study.

- Leading: `Button(role: .close)` (xmark). It replaces the `chevron.backward` End Session button; the stream has no session to end, every grade is saved. The HIG asks for the standard Close symbol and no text label [H:toolbars].
- Principal: `StreamRing` (a `ProgressRing`, 30 pt, `@ScaledMetric(relativeTo: .subheadline)` up to 44) + the figures, `.subheadline`, `.monospacedDigit()`, spacing 8, `.accessibilityElement(children: .combine)`. The ring is empty in the middle and stays full once the goal is reached. A practice shows the word `Practice` as the principal text, without the ring.
- Trailing: an icon button `arrow.uturn.backward` (Undo) left of `Menu("More", systemImage: "ellipsis")`; there is no chip under the bar: its room goes to the card.
- The ring is where the cards go (`study-screen.md`, Motion): its frame is reported to `StudyMotion.ringHome` (global coordinates, nothing fixed), it steps and glows when a card is done, and it is empty of everything else but the figures beside it.
- The streak is not in the header. The goal-met moment is the ring that closes as the last card leaves and bursts at the rest of the plan.

### 4.2a Rests

The stream's rests (titles, figures and buttons: `screens.md`, Study) are one `StreamRestView`: the same ring (96 pt) over the title, the figures in secondary under it, the buttons 24 pt below, as wide as the card (iPhone 400 pt at most, Mac 320). The first button of a rest is `.borderedProminent` and the default action (Keep Going; Done); the others are `.bordered`; Push On carries `More reviews in the days ahead` under it in footnote secondary. The rings of the last seven days (`WeekRings`) are 20 pt each, weekday initials under them, today last and bold.

The motion into and out of a rest (`RingTraveler`, `SlotOutline`, the staggered lines, Reduce Motion): `study-screen.md`, Motion.

### 4.3 Grade area

| Part | Spec |
|---|---|
| Container | One fixed-height container for both stages, so the card keeps its height and the divider with the question stays where it is when the answer opens. The grade rows stay in the layout at all times (`opacity`, `allowsHitTesting`, `accessibilityHidden` as `face` does for the answer) and Show Answer lies over them (an overlay, so it has their size). |
| Show Answer | `Button`, `.buttonStyle(.borderedProminent)`, `.controlSize(.large)`, full width, accent fill, the whole rectangle of the grade block (Forgot's top to the bottom of the row), corner radius 14 like the grade buttons. |
| Forgot | Full width, height `@ScaledMetric(relativeTo: .body) var height = 50`, `Label("Forgot", systemImage: "xmark")`, `.font(.body.weight(.semibold))`, fill `Grade.again.color`, white label. |
| Caption | `Text("Recalled")`, `.footnote`, secondary. 12 above (after Forgot), 4 below. |
| Hard / Good / Easy | `WeightedRow(weights: [1, 1.25, 1], spacing: 12)`, same height as Forgot, fills `Grade.hard/good/easy.color`, white labels. `minimumScaleFactor(0.7)` goes away; at `isAccessibilitySize` the four buttons stack, full width, gap 12. |
| Spacing | 12 between bezeled controls [H:accessibility]. Hard taken for Forgot is the costly slip for FSRS (comment in `GradeChoice`); the caption with its 12 + 4 keeps the two rows about 32 apart. The scale of the study screens is `Spacing`: 4, 8, 12, 16, 24. |
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

**Raised surfaces.** A graphic drawn in a sheet, a selection mark or a row symbol, is `Color.appAccentOnRaised`: the accent itself on a screen and in light; in dark at the elevated level (`UITraitCollection.userInterfaceLevel`), the accent lightened in its hue (241°, saturation held): `#706FDC` with 3.32 on `#2C2C2E`, and with Increase Contrast `#7B79EA` with 3.31 on `#363638`. The colour is a `UIColor` provider that reads the level of the view it is drawn in, so one value serves a screen and a sheet. In sheets today: the selection marks of Add Cards and of the import preview, and the row symbols of the Anki destination sheet. The ring, the flame, the maturity ramp and the study stream are on screens; the stream and the onboarding are full-screen covers, which are not raised, so they take the accent. Card Detail and How Today Works draw no accent graphic. The fill of a prominent button stays the accent: its white label asks 4.5, which the lighter ones do not give (4.20 and 3.64), and a button is named by its label, so its fill needs no 3:1 of its own.

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

- **Forgot red** (`Grade.again`, `#CE0E1A` light, `#C4111A` dark) has a luminance ratio of 1.00 (light) and 1.08 (dark) against the accent and an OKLCH lightness within 0.01 of the accent's (0.54 and 0.52). The hues are 27° (red) and 278° (accent), 109° apart; chroma is 0.215 and 0.205 against 0.191; ΔE is 33.0 and 32.2. Hue is the separator. Forgot always carries `xmark` and its word, and the accent never means "wrong". On the stream screen the accent is a 30-pt ring (`StreamRing`, §5.7) and the Show Answer button, which the grade buttons replace.
- **Greens** (`Grade.hard` `#63736D` light and `#5E6D67` dark, `Grade.good` `#467B69` and `#437464`, `Grade.easy` `#0D8265` and `#0C7B60`) lie at OKLCH hue 170°, 107° to 109° from the accent. The luminance ratio to the accent is 1.04 to 1.18 and ΔE 19.9 to 24.6, so Hard, Good and Easy rely on hue and chroma (Hard 0.02, Good 0.06, Easy 0.10 against 0.191); the grade buttons are labelled, and the accent is never next to them as a peer.
- **Maturity ramp** is one hue, the accent's indigo (OKLCH 278°, `Presentation.swift`): memory reads in the colour of the ring, apart from the grades' red and greens. Lightness 0.86 → 0.40 in light mode and 0.42 → 0.85 in dark, adjacent steps 10–13.5 ΔE2000 apart; New stays grey. Evidence: `ring-design.md`, "The maturity ramp in one hue".
- **Card face** stays `secondarySystemBackground`. `CardFlight.textColor` records contrast numbers for the grade tint measured on a neutral face (Hard text 2.3 to 2.9 on a light card); a tinted face would move all of them. The icon's cards (`#E4E3FA`, `#F8F7FF`) are not reused in the UI.

### 5.3 New / Learning / Review

Neutral, decided in §1. Number `.primary`, 0 in `.secondary`; label `.secondary`; same weight in every column; no symbols. The words carry the meaning, so nothing depends on colour [H:accessibility]. The order New, Learning, Review stays, as in Anki.

### 5.4 Role table

| Role | Colour | Where |
|---|---|---|
| Action, progress | `AccentColor` | §5.1 list |
| Text | `.primary`, `.secondary`, `.tertiary` | everything else |
| Counts | neutral | Today row, deck screen, Mac |
| Grades | `Grade.color`, unchanged | grade buttons, swipe tint, review history |
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

The owner asked on 22.10.2026 for rings in the manner of the Fitness rings, taken from open-source rings and without a dependency. The drawing is `Shared/Support/ActivityRing.swift`: [MKRingProgressView](https://github.com/maxkonovalov/MKRingProgressView) by Max Konovalov (MIT) transcribed line for line — `RingProgressLayer.drawContent(in:)` as `RingDrawing.draw`, `GradientGenerator` as it is — inside a SwiftUI `Canvas` (`withCGContext`), so the same drawing runs on iOS, macOS and in the widget. The order is MK's: a backdrop circle in the start colour at 15 %; for progress past one lap a solid arc in the start colour, then the context rotated so the gradient arc ends at the head; the end circle in the start colour with a shadow (`w/3` blur, offset `w/10` along the way the ring runs, opacity 1) clipped to the ring; the gradient arc on top, a conic gradient image clipped to the stroked arc. `ProgressRing` hands the drawing at most 1 (`DailyRing.fraction` is capped at 1 as well), so a ring is full at the goal and stays full. Options: MK's defaults, except `hidesRingForZeroProgress` on (an empty ring shows only the backdrop) and the gradient image at the display's scale. `UIBezierPath(arcCenter:…, clockwise: true)` became `CGMutablePath.addArc(…, clockwise: false)`; colours resolved from SwiftUI are converted to device RGB before the generator reads their components. The gradient image depends on size and colours only, so the last one is cached while a ring animates.

**Colour.** Head: the accent. Tail: the accent mixed with 25 % white in device RGB. `AccentContrastTests.ringGradientHoldsItsContrastInEveryAppearance` reads both ends from the pixels of a view in each appearance and holds the tail to 3:1 on the four surfaces and to 1.3:1 against the accent, in light, dark and both increased-contrast variants. The test reads pixels because `Color.accentColor` is the asset's accent only inside a view: `UIColor(Color.accentColor)` gives the system blue. Line width 15 % of the diameter, at least 3 pt.

The tail and its WCAG ratios, computed from the 8-bit values (surfaces as in §5.1):

| Appearance | Tail | Against the accent (1.3 or more) | On surface (3.0 or more) |
|---|---|---|---|
| Light | `#8280E0` | 1.64 | 3.44 on white, 3.08 on `#F2F2F7` |
| Light, Increase Contrast | `#6867BA` | 1.95 | 4.96 on white, 4.17 on `#EBEBF0` |
| Dark | `#8280E0` | 1.64 | 6.11 on black, 4.95 on `#1C1C1E`; raised 4.06 on `#2C2C2E` |
| Dark, Increase Contrast | `#8C8AEC` | 1.55 | 6.96 on black, 5.14 on `#242426`; raised 4.00 on `#363638` |

Every tail ratio meets the test's thresholds; the lowest on a surface is 3.08 (light, on `#F2F2F7`). A third of white instead of a quarter gives 2.62 there (`#908EE4`).

**Middle.** `RingCenter` (`.none` or `.streak(days:isLit:)`, built by `RingCenter(_ progress:)`): the streak as `flame.fill` over the days, nothing at 0 days. The days are a bold rounded number, 30 % of the diameter with the flame (the flame 23 %, semibold), 38 % alone; from a diameter of 44 pt the flame shows, below it the number alone. The flame is lit in `Color.streak` when `DailyProgress.isStreakLit` (= `streakKeptToday && !isStreakAtRisk`), `.secondary` otherwise. Orange is the one hue that means the habit: red is Forgot, the greens are recalled, indigo is the ring and the accent. `Color.streak` is `#E05A00` in light (3.7:1 on white, 3.3:1 on the light grouped grey) and `#FF9F0A` in dark (8:1 on the dark raised grey), above the 3:1 a glyph needs. The study bar's `StreamRing` and the Mac session header (`DailyRingView(progress:, showsStreak: false)`) are empty in the middle.

| Place | Ring | Middle |
|---|---|---|
| Today (`SummaryRow`) | 72 pt, `@ScaledMetric(relativeTo: .title2)`, at most 96 (the Mac's Today window 80 pt) | flame over the days |
| Rest screen (`StreamRestView`) | 96 pt | flame over the days |
| Widget, small and medium | 56 or 64 pt, 76 pt | flame over the days |
| Study bar (`StreamRing`) | 30 pt, `@ScaledMetric(relativeTo: .subheadline)`, at most 44 | empty |
| Mac toolbar chip (`RingChip`) | 22 pt | empty; the flame and the days stand beside the ring |
| Mac session header (`DailyRingView`) | 28 pt | empty |

VoiceOver: `DailyRingView` reads "Day streak: 5 days" as its label while the middle shows the streak, "Daily Goal" while it is empty, and "14 / 36" as its value. `DailyRingView` has no popover and is no button. `ProgressRing` is otherwise hidden from accessibility, as the text beside it says the figures; the study bar's ring sits in the combined element with the figures.

Pictures: `VocTrainTests/RingTests.swift` (`TEST_RUNNER_STUDY_SHOTS_DIR`) writes `ring-1-today`, `ring-2-study-bar`, `ring-3-chip`, `ring-4-rest` in light and dark at 0, 40, 100, 160 and 230 % of the goal, and `ring-5-edges` at 5, 95, 100, 105, 150, 200 and 300 %; `MacVocTrainNgTests/RingSnapshotMacTests.swift` writes the Mac chip and the session ring.

## 6. Mac

### 6.1 Hierarchy

Level 0 Today (all decks; on the Mac the Today window, `TodayWindowContent`, which stays open beside the deck windows) → level 1 the deck (the iPhone's deck screen; on the Mac the deck document window with Cards, Statistics, Learning Options).

### 6.2 Deck window toolbar and session header

Toolbar order, left to right: segmented `Cards | Statistics` (principal) · ring chip · **Study** (`.borderedProminent`; **Push On** once the deck has no cards due) · fixed space · Add Lesson Words · Learning Options.

- Ring chip (`RingChip`): `ProgressRing(diameter: 22)`, empty in the middle, with the flame (`flame.fill`, lit in `Color.streak`) and the days beside it; `.help` holds the figures ("≈ 2 min to keep your streak · 14 of 20 cards · 12-day streak · ≈ 28 words in memory"), `.sharedBackgroundVisibility(.hidden)` (an indicator takes no button background). It counts every deck of the Mnemit folder, the open ones as their documents have them.
- Study: `Button("Study")` (`StartStudyButton`: Study while the deck has cards in today's plan, else Push On, ten new cards at once) without count and without the `graduationcap` label. `ToolbarSpacer(.fixed)` between it and the symbol buttons: a text button next to symbol buttons reads as one control [H:toolbars]. The menu command Study ▸ Study (⌘L) is the toolbar item's menu twin [H:toolbars].
- Session header (`SessionView.header`): `DailyRingView(progress:, showsStreak: false)`, empty in the middle as the iPhone's study bar is, with the iPhone bar's figures beside it ("≈ 4 min" while the goal is open, "36 cards today" once it is met), the mistakes counter and Edit Card…; Done ends the session.
- Spacing: `GradeChoice` gap 12 on Mac too; height stays 38 (HIG default Mac control 28, minimum 20 [H:accessibility]).
- Settings: the `Settings` scene and ⌘, stay; no settings button in the toolbar [H:settings]. A daily-goal setting, if one is added, becomes a pane there.
- Status bar (`CardListView.StatusBar`) keeps its Today counts line, neutral.

## 7. Checks, sources

### 7.1 Check matrix (on the 13 mini simulator or device; Mac with `vqa`)

| Screen | States |
|---|---|
| Today | due, nothing due with reviews, nothing due without reviews, no decks, cached first frame, one deck unreadable; light, dark, Increase Contrast, Reduce Transparency; Large, xxxLarge, AX3; landscape |
| Deck screen | counts with zeros, paused, practice rows present and absent, AX3 |
| Stream | question, revealed, grade area height equal in both stages, 4-line question, 135-character answer, AX1 and AX3, landscape |
| Contrast | gate test table, all four appearances |
| Mac | deck window toolbar at the minimum window width 720 (items must not overflow by default [H:toolbars]), Graphite and Multicolor accent |

### 7.2 UNVERIFIED

- All rendering: glass prominent button label colour and height, `safeAreaBar` with a `List`, principal toolbar ring, press feedback of a `.plain` button in a list row, concentric card corners. iOS 27 behaviour: the installed SDK is 26.2 (Xcode 26.3).
- Fitness and Reminders layouts (ring left, metrics right, counts trailing in My Lists) are from memory; only the facts in [A:fitness] were read.
- `.buttonStyle(.borderedProminent)` giving the prominent glass look in toolbars (the HIG names the `.prominent` style, the API mapping is from memory).
- Deck window toolbar overflow at width 720 with the new items.
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
- Code: `/Users/eugene/Code/Mnemit/VocTrain/Views/StartScreen.swift`, `DeckView.swift`, `StudyCountsView.swift`, `VocTrain/Session/StudyView.swift`, `Shared/Session/GradeChoice.swift`, `Shared/Session/CardFlight.swift`, `Shared/Support/Presentation.swift`, `MacVocTrainNg/Views/DocumentView.swift`, `Session/SessionView.swift`, `Welcome/WelcomeView.swift`, `App/AppCommands.swift`; card data `~/Documents/greek-lessons/vocab/cards-a1a2.tsv`, `cards-b1.tsv`.
