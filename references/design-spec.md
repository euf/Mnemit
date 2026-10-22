# Mnemit design spec: home, deck details, study stream, accent, Mac

Spec of 2026-10-21 for one user (iPhone 13 mini on iOS 27, dark mode; Mac on macOS 27). Read from code: `StartScreen`, `DeckView`, `StudyCountsView`, `StudyView`, `GradeChoice`, `Presentation`, `CardFlight`, Mac `DocumentView`, `SessionView`, `WelcomeView`, `AppCommands`. Read from the stream agent's worktree (`.claude/worktrees/agent-aa4d062d083bbd42b`, uncommitted): `DailyProgress.swift` (`DailyGoal`, `DailyRing`, `Streak`, `DailyProgress.evaluate(_:at:calendar:)` over all decks) and `StudyStream.swift` (per deck: `plan`, `rest`, `reviewAhead`, practice). No GUI was run for this spec.

## 0. How to read this

- `[H:slug]` is a Human Interface Guidelines page, opened on 2026-10-21 through the HIG's own data feed (`https://developer.apple.com/tutorials/data/design/human-interface-guidelines/<slug>.json`); the page URL is `https://developer.apple.com/design/human-interface-guidelines/<slug>`. `oc` cannot render these pages (JavaScript only), the JSON can be read with curl. Other tags are in §7.
- UNVERIFIED marks a claim whose source was not opened, or a behaviour that only a screen can show. §7 lists all of them.
- Every Swift block in this file was typechecked against `iPhoneSimulator26.2.sdk` and `MacOSX26.2.sdk` (swiftc 6.2.4, `-swift-version 6`) with stubs for the model types (`StudyCounts`, `DailyRing`, `Streak`, `DailyProgress`, `KnownDeck`, `StudyScope`). Typechecked means the API exists and compiles; it does not mean the screen looks right.
- Sizes are points. Device: iPhone 13 mini is 375 x 812 pt, portrait safe area top 50 / bottom 34, landscape sides 50 / bottom 21, width class compact [U:loaf].

## 1. Verdicts

| # | Decision | Reason | Rollback |
|---|---|---|---|
| 1 | Launch lands on **Today**. The app no longer reopens the last deck. | Study is one tap from launch. | Re-enable `reopen()`. |
| 2 | The primary button **Study** runs all decks that have cards due, one deck stream after the other: last studied deck first, then list order. A tap on a deck row studies that deck only. | The ring and the streak are one value over all decks (`DailyProgress.evaluate` takes `[DeckActivity]`), so one button must be able to finish them. The user studies two decks daily. | `StudyScope.all` falls back to the last studied deck (`knownDecks.last`), label unchanged. |
| 3 | Deck details open from a trailing `info.circle` button as a **sheet**. No chevron, no context menu. | A tap on the row starts studying, so a chevron would promise navigation the row does not do. The HIG gives the info button the job of revealing more about a row's content and the disclosure indicator the job of drilling down [H:lists-and-tables]. A context menu is hidden and would repeat the button [H:context-menus]. | – |
| 4 | New / Learning / Review are **neutral**: number in primary label colour (0 in secondary), label in secondary. | Blue/red/green reuse the meanings of Forgot (red), Good (green) and the maturity ramp (blue); the HIG asks for one colour per meaning [H:color]. The owner dislikes the coloured counts. | `StudyCount.color` stays in git history. |
| 5 | One accent, **system indigo** `#5856D6` in light and dark; Increase Contrast `#3634A3` (light) and `#6563E6` (dark). | Red means Forgot and the greens mean recalled, so the accent is neither; green reads as Excel and terracotta as Claude (owner, 21.10.2026). The icon tile is indigo too. Numbers in §5. | Change the values in the three `AccentColor.colorset` files (iPhone, Mac, widget). |
| 6 | Raise the deployment targets to **iOS 26 / macOS 26**. | Only the owner's devices run the app: iOS 27, macOS 27, built with Xcode 26.3. `safeAreaBar`, `.glassProminent`, `Button(role: .close)`, `ToolbarSpacer` need 26. | Keep 17 / 14, wrap five call sites in `#available` with `.safeAreaInset` and `.borderedProminent`. |
| 7 | Large title **Today**. The app name appears nowhere on the screen. | The HIG advises against naming a window after the app and asks for titles under 15 characters; large titles are the iOS pattern [H:toolbars]. | `.navigationBarTitleDisplayMode(.inline)`. |
| 8 | Mac: toolbar gets the ring chip and a prominent Study (phase A); a **Today window with a sidebar of decks** replaces the Welcome window (phase B). Settings stay in the app menu. | A document window shows one deck, so a deck sidebar can only live in a window of its own. | Phase A alone is complete. |

### Diagnosis of the current screens

| Owner remark | Cause in code |
|---|---|
| Two taps | `StartScreen` pushes `DeckScreen` (and `reopen()` pushes it at launch); the Study button is on that second screen. |
| Huge "Mnemit" title | `.navigationTitle(Text(verbatim: "Mnemit"))` in a large-title stack. |
| Hand-made deck card, big rounded box | `DeckView` section 1 is a `VStack` with `StudyCountsColumns` (34 pt numerals, `design: .rounded`, `minimumScaleFactor(0.6)`) and a footnote; section 2 is a clear row with `listRowInsets(EdgeInsets())` that makes `.borderedProminent` + `.controlSize(.large)` run edge to edge. |
| Coloured counts, mixed weights | `StudyCountsLine`: semibold coloured number, regular secondary label, `subheadline`, 12 pt between pairs. The line sits under a `Label` with a symbol, so it starts under the symbol, one indent left of the name (derived from code, not seen on screen). |
| Kerning | No `.tracking` or `.kerning` anywhere in the sources (grep). SF Pro tracks −0.43 pt at 17 pt and +0.40 at 34; SF Pro Rounded tracks +0.37 at 17 and +0.51 at 13 [H:typography]. The count column puts 34 pt rounded numerals over 13 pt SF Pro labels, and `minimumScaleFactor` shrinks glyphs cut for 34 pt. Whether SwiftUI re-tracks scaled text is UNVERIFIED. Fix by construction: text styles only, no `.rounded`, no `minimumScaleFactor` on numerals. |
| Accent | `AccentColor.colorset` holds system indigo in all three catalogs (iPhone, Mac, widget): `#5856D6` in light and dark, `#3634A3` (light) and `#6563E6` (dark) with Increase Contrast (§5.1); counts are neutral; `.tint(.primary)` on the deck row keeps the accent off the text of a `Button`; Forgot is red, the ramp is blue. |

## 2. iPhone home (Today)

### 2.1 Flow

Launch → Today. Tap **Study** (one tap) or a deck row (one tap) → the study stream covers the screen at once and shows the first card. No summary screen in between. A tap on `info.circle` opens deck details as a sheet.

Rejected: auto-start of the stream at launch. The learner would not see what is due, and the HIG asks launch to restore the previous position [H:launching]. Rejected: a tab bar. There is one section; a tab bar is for navigation and Study is an action [H:tab-bars].

### 2.2 Wireframe (375 x 812)

```
┌───────────────────────────────────────┐
│ 9:41                                  │ status area 50
│                                  ( … )│ nav bar 44: ellipsis menu (trailing)
│ Today                                 │ large title 34 bold, system
│ ┌───────────────────────────────────┐ │ insetGrouped section, margin 16
│ │  ╭─────╮   87 cards left           │ │ title2 semibold, monospaced digits
│ │  │  ◔  │   14 of 101 cards         │ │ subheadline, secondary
│ │  ╰─────╯   [flame] 12-day streak   │ │ subheadline; flame = accent when goal met
│ └───────────────────────────────────┘ │ ring 72, line 10, round caps
│  DECKS                                │ system section header
│ ┌───────────────────────────────────┐ │
│ │ Greek B1                    27  ⓘ │ │ body | body, monospaced | info.circle, 44 x 44
│ │ 20 new · 4 learning · 3 review    │ │ subheadline, secondary, monospaced digits
│ │ ───────────────────────────────── │ │
│ │ Greek A1–A2                 60  ⓘ │ │
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
| Toolbar | one `ToolbarItem(.primaryAction)` | `Menu("More", systemImage: "ellipsis")`: Choose Mnemit Folder…, Open Deck…, Settings. The HIG prefers symbols without borders in toolbars [H:toolbars]: `ellipsis` without the circle. "Show Introduction" leaves the menu; Settings has it. |
| Summary | `Section { SummaryRow }` | Ring 72 (`@ScaledMetric(relativeTo: .title2)`), gap 16, row `.padding(.vertical, 8)`. Lines: `.title2.weight(.semibold)` / `.subheadline` secondary / `.subheadline` secondary. One `.monospacedDigit()` on the text column. `.accessibilityElement(children: .combine)`. |
| Ring | `ProgressRing` | A Fitness-style ring, drawing and sources in §5.7: line 15 % of the diameter, gradient along the stroke from a lighter tint of the accent to the accent, round caps, dim track, laps past 100 % on top of a full ring with a shadow at the head. In the middle the streak in days (bold rounded number, the word "days" under it from 56 pt), nothing at 0 days. The owner asked for Fitness quality on 22.10.2026; [H:activity-rings] advises against imitating the Activity rings, the ring here follows the owner. |
| Streak line | `Label` | `flame.fill`; accent when today's goal is met, secondary when it is not yet met. Hidden at 0 days. Text colour stays secondary. |
| Section header | `Section("Decks")` | System. |
| Deck row | `HStack` with two buttons | Button 1 (name block, trailing total) `.buttonStyle(.plain)`, `contentShape(Rectangle())`, starts the deck. Button 2 `info.circle`, `.imageScale(.large)`, `frame(minWidth: 44, minHeight: 44)`, `.buttonStyle(.borderless)`, opens details. Both need an explicit non-automatic style, otherwise a tap anywhere fires both [U:nilcoalescing]. Name `.body`; subtitle `.subheadline` secondary. Total `.body`, `.monospacedDigit()`, trailing. |
| Zero due | same row | Trailing `checkmark` in secondary, subtitle `Next review <relative>` from `Format.due`. |
| Swipe | `.swipeActions` | Keep Remove from List for decks outside the folder. |
| Primary action | `.safeAreaBar(edge: .bottom)` | `Button` label `Text("Study")` full width, `.buttonStyle(.glassProminent)`, `.controlSize(.large)`, `.padding(.horizontal, 16)`, `.padding(.bottom, 8)`. System height, no fixed frame, no icon, no count in the label. The scroll edge effect comes from `safeAreaBar`; no background under it [H:layout]. |
| Accessibility | | Study button `accessibilityValue("\(due) today")`. |

### 2.4 States

| State | Summary row | Button |
|---|---|---|
| Before the first round | `≈ 2 min to keep your streak` (title2, two lines where it does not fit), `3 of 30 cards · 27 left`, `12-day streak` (grey flame), `≈ 28 words in memory`; with catch-up `+1,320 to catch up this week` | `Study`, `.glassProminent` |
| After the streak step | `16 cards left · ≈ 4 min` (the time drops under the line where it does not fit), `14 of 30 cards · 16 left`, `12-day streak · kept today` (flame in the accent), `≈ 28 words in memory · +15 today` on one line under the ring row, as wide as the row (beside the ring a 375 pt screen leaves too little: the gain fell under the words); at a large type size the one text wraps, the gain is never stacked as a line of its own; a milestone passed today replaces the words line with `50 words in memory!`, semibold, with a `sparkles` glyph in the accent | `Study`, `.glassProminent` |
| Rounds done, cards left | `Ring closed`, `31 of 30 cards · 6 left`, streak kept, words | `Study`, `.glassProminent` |
| Rounds not known yet | `87 cards left · ≈ 7 min`, no second line until the ring is evaluated | `Study`, `.glassProminent` |
| Nothing due, cards done today | ring full with checkmark, `All done`, `N cards today`, streak | `Keep Going`, `.glass` (not prominent), opens the stream at `rest`, which offers keep going and new cards |
| Nothing due, no cards done today | track only, `Nothing due`, `Next review <relative date>`, no `x of y` line | `Keep Going`, `.glass` |
| No decks | `ContentUnavailableView` as now; title `No Decks`; prominent `Choose Mnemit Folder…`, plain `Open Deck…` | – |
| First frame | Last counts and ring from `UserDefaults` | enabled when the cached total is above 0 |
| Deck unreadable (iCloud) | row without counts | row stays tappable; the stream cover shows the existing failure view |
| Accessibility sizes (`isAccessibilitySize`) | ring above the text (`AnyLayout` switch) | unchanged |

The ring and every line beside it count cards; reviews do not enter. The daily goal is the number of cards in the day's plan when the day began (`StudyCounts.total` of that plan, `DeckActivity.plan(onDayOf:calendar:)`), fixed for the day: cards added later raise nothing. A card is done once its last review of the day left it due on a later day, so that FSRS let it go (`DeckActivity.done(onDayOf:calendar:)`): a review card graded Hard, Good or Easy at once, a new card after its last learning step, a card graded Forgot only after it leaves relearning. It counts once, however many reviews it took. The ring also shows the cards on their way as parts of a card (`DailyRing.underway`, `Card.credit`): every answer recalled moves it, Forgot moves nothing. Cards done beyond the goal, in catch-up and "+10 new", fill the laps. "N cards left" is the cards of the plan not done yet (`StudyCounts.total` now), so goal, done and left are one unit. The "nothing done, nothing due" case has a goal of 0 (`DailyGoal.goal(done: 0, owed: 0, plan: 0)`), which counts as met, so the ring is a track and the row hides the goal. A day that began with an empty plan and then got cards (a first deck filled in the afternoon) takes the plan as it stands, `done + owed`, so its ring has a goal instead of laps. The count is the plan (`StudyCounts.total`), its share of the backlog included (`DailyGoal.backlogShare(of:onTime:)`: a seventh of it, but at least what a normal day asks), never the whole backlog; the cards beyond the share are the catch-up, `StudyCounts.catchUp`, shown as a secondary line on Today, in the deck rows and on the rest screen. The headline of Today is the day's next goal (`RoundStatus`, `Shared/Session/DayLines.swift`): "≈ 2 min to keep your streak" before the first round, then the cards left with their time, "Ring closed" after the last (rounds never show by number, `learning-flow.md`); the minutes of a round are `DayRounds.minutes(ofRound:)` at the pace the day began with, and the second line is "M of K cards · N left". The small widget says the same in its place (the title under the ring, 56 pt, two lines where it does not fit), the medium widget adds "≈ 28 words in memory", the rectangular lock-screen widget puts the headline in its first line, and the Mac ring chip gives the headline, the cards, the streak and the words in its help text. Where the rounds are not known yet, and in a widget snapshot of an older app, "N cards left" carries "· ≈ 7 min" after it (the time drops under the line where it does not fit); the minutes are `DailyGoal.minutesLeft(newCards:otherCards:pace:)`: the cards left that were new when the day began (`StudyCounts.newAtDayStart`, a new card started today and still in its steps included) at the new-card price, the others at the other price; the pace `DailyGoal.pace(days:newDone:otherDone:)` is seconds per done card of each kind: the typical seconds a review takes (the mean of the lognormal that the durations of the reviews of the last seven study days and today follow, from the median and the interquartile range of their logarithms; a duration is how long the card was on screen with the app active, and a kind with under 20 of them takes the gaps between its reviews instead, each gap going to the card of the later review, and their median stands for the typical seconds, so that a break among the gaps does not count) times the reviews each done card of that kind took, counting the reviews of the cards that were done on the day of the review and no others; a kind with under 20 such times or under 10 done cards takes 30 s a new card and 10 s any other card; "< 1 min" under a minute, and no line without cards left. The widget forecast holds only card counts per hour, so its snapshot keeps one price, the time left now over the cards left now.

### 2.5 Scope of Study

Study on Today opens every active deck with `total > 0` and runs one stream over them (`StudyModel` with a `SessionDriver` per deck): each card comes from the deck whose next card is most urgent (a card in learning, then the review with the lowest recall probability, then a new card from the deck that has given the fewest), so a round always does the day's most urgent work whatever deck it is in. The grade goes to the card's deck; Card Info and Undo follow the card. The plan's rest comes when no deck has plan cards left. Leaving anywhere loses nothing, every grade is saved.

### 2.6 Code (typechecked)

```swift
import SwiftUI

/// Drawn by `ActivityRing` in `Shared/Support/ActivityRing.swift`, with the middle from `ProgressRing.swift` (§5.7); the stub gives the blocks below their type.
struct ProgressRing: View {
    var fraction: Double
    var diameter: CGFloat
    var body: some View { EmptyView() }
}

struct TodayScreen: View {
    var decks: [KnownDeck]
    var counts: [URL: StudyCounts]
    var progress: DailyProgress?
    var now: Date
    var study: (StudyScope) -> Void
    var showDetails: (KnownDeck) -> Void

    private var due: Int { decks.reduce(0) { $0 + (counts[$1.url]?.total ?? 0) } }

    var body: some View {
        List {
            Section {
                SummaryRow(due: due, progress: progress, nextDue: counts.values.compactMap(\.nextDue).min(), now: now)
            }
            Section("Decks") {
                ForEach(decks) { deck in
                    DeckRow(name: deck.name, counts: counts[deck.url], now: now,
                            start: { study(.deck(deck.url)) }, details: { showDetails(deck) })
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("More", systemImage: "ellipsis") { Button("Settings", systemImage: "gearshape") {} }
            }
        }
        .safeAreaBar(edge: .bottom) {
            StudyButton(due: due) { study(.all) }
        }
    }
}

struct StudyButton: View {
    var due: Int
    var action: () -> Void

    var body: some View {
        let label = Button(action: action) {
            Text(due > 0 ? "Study" : "Keep Going").frame(maxWidth: .infinity)
        }
        Group {
            if due > 0 {
                label.buttonStyle(.glassProminent)
            } else {
                label.buttonStyle(.glass)
            }
        }
        .controlSize(.large)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

struct SummaryRow: View {
    var due: Int
    var progress: DailyProgress?
    var nextDue: Date?
    var now: Date
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title2) private var diameter = 72

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 16))
        layout {
            ProgressRing(fraction: progress?.ring.fraction ?? 0, diameter: diameter)
            VStack(alignment: .leading, spacing: 2) {
                Text(due > 0 ? "\(due) due" : "All done")
                    .font(.title2.weight(.semibold))
                if let ring = progress?.ring {
                    Text("\(ring.done) of \(ring.goal) cards")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let streak = progress?.streak, streak.days > 0 {
                    Label {
                        Text("\(streak.days)-day streak")
                    } icon: {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(progress?.ring.isGoalMet == true ? Color.accentColor : Color.secondary)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .monospacedDigit()
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

struct DeckRow: View {
    var name: String
    var counts: StudyCounts?
    var now: Date
    var start: () -> Void
    var details: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: start) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                        if let counts {
                            Text(counts.total > 0
                                 ? "\(counts.new) new · \(counts.learning) learning · \(counts.review) review"
                                 : "Next review tomorrow")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    Spacer(minLength: 0)
                    if let counts {
                        if counts.total > 0 {
                            Text(counts.total, format: .number).monospacedDigit()
                        } else {
                            Image(systemName: "checkmark").foregroundStyle(.secondary)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button(action: details) {
                Image(systemName: "info.circle")
                    .imageScale(.large)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("Deck Details"))
        }
    }
}
```

In the real row the "Next review tomorrow" string comes from `Format.due(counts.nextDue, now: now)`; the stub shows the shape only.

### 2.7 Remove

- `StartScreen`: `.navigationTitle(Text(verbatim: "Mnemit"))`; `reopen()`, `hasReopened` and the `knownDecks.last` auto-open; `.navigationDestination(item: $deck)` push and `DeckScreen`'s `.navigationTitle`/inline mode (the deck opens in a full-screen cover or a sheet); the `Label(known.name, systemImage: "rectangle.stack")` row, `StudyCountsLine`, `.tint(.primary)`; `Menu` symbol `ellipsis.circle` and its "Show Introduction" item; the Settings sheet's text `Button("Done")` (use `Button(role: .close)`).
- `StudyCountsView.swift` goes entirely: `StudyCountsLine`, `StudyCountsColumns`, the `StudyCount` enum with its colours, `design: .rounded`, `minimumScaleFactor(0.6)`. `CountsRow` (§3.3) replaces it and needs no enum.
- `DeckView`: the whole study `Section` with `listRowBackground(Color.clear)` and `listRowInsets(EdgeInsets())`, the `Label("Study \(n)", systemImage: "graduationcap")` button, the `More` menu with one item.

### 2.8 Budget

A tap on a row sets one state value and presents the stream cover in the next frame; `OpenDeck` loads behind a `ProgressView` inside the cover (target 8 ms median, 16 ms ceiling to first presented frame [G §6]). The first Today frame reads cached counts and the cached ring from `UserDefaults`; file reads stay on `Task.detached` as in `KnownDeckCounts`. The ring needs the review logs of both decks (`DeckActivity`); compute off the main actor and cache per study day.

## 3. iPhone deck details

### 3.1 Wireframe (sheet, detents medium and large, grabber)

```
┌───────────────────────────────────────┐
│ ✕           Greek B1        [ Study ] │ inline title; close = Button(role: .close); prominent primary
│  TODAY                                │
│ ┌───────────────────────────────────┐ │
│ │    20          4          3       │ │ title2 semibold, monospaced; 0 in secondary
│ │   New      Learning     Review    │ │ footnote, secondary
│ └───────────────────────────────────┘ │
│  What today's plan takes from this    │ footer, footnote
│  deck.                                │
│ ┌───────────────────────────────────┐ │
│ │ Cards                       2 236 │ │ LabeledContent, monospaced digits
│ │ Suspended                      78 │ │ only when above 0
│ └───────────────────────────────────┘ │
│  PRACTICE                             │
│ ┌───────────────────────────────────┐ │
│ │ ▶ Practice Newest Words           │ │ rectangle.stack.badge.play
│ │ ↻ Practice Today's Mistakes       │ │ only when mistakes exist
│ └───────────────────────────────────┘ │
│ ┌───────────────────────────────────┐ │
│ │ ▥ Retention                     › │ │ NavigationLink to StatisticsScreen
│ └───────────────────────────────────┘ │
└───────────────────────────────────────┘
```

### 3.2 Components

| Element | SwiftUI | Values |
|---|---|---|
| Sheet | `.sheet(item:)` with `NavigationStack` | `.presentationDetents([.medium, .large])`, `.presentationDragIndicator(.visible)` (resizable sheets carry a grabber [H:sheets]). |
| Toolbar | `.cancellationAction` / `.primaryAction` | `Button(role: .close)`; `Button("Study")` prominent. One prominent button in the view [H:buttons]. |
| Counts | `CountsRow` inside a `Section` | Three equal columns, value `.title2.weight(.semibold)` + `.monospacedDigit()`, label `.footnote` secondary, gap 2, `.padding(.vertical, 4)`. At accessibility sizes the columns stack with left alignment. No colours. |
| Totals | `LabeledContent("Cards", value:, format: .number)` | Section `.monospacedDigit()`. Next review row when nothing is due. |
| Practice | `Button(_, systemImage:)` rows | Uses `StudyStream(practicingNewestWordsIn:)` and `StudyStream(practicingMistakesIn:)`; hide a row that has no cards. |
| Statistics | `NavigationLink` + `Label(_, systemImage: "chart.bar")` | Existing `StatisticsScreen`. |
| Loading | counts at once from `KnownDeckCounts`; totals, retention after `OpenDeck` loads | – |

### 3.3 Code (typechecked)

```swift
struct DeckDetails: View {
    var name: String
    var counts: StudyCounts
    var total: Int
    var suspended: Int
    var start: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    CountsRow(counts: counts)
                } header: {
                    Text("Today")
                } footer: {
                    Text("What today's plan takes from this deck.")
                }
                Section {
                    LabeledContent("Cards", value: total, format: .number)
                    if suspended > 0 { LabeledContent("Suspended", value: suspended, format: .number) }
                }
                .monospacedDigit()
                Section("Practice") {
                    Button("Practice Newest Words", systemImage: "rectangle.stack.badge.play") {}
                }
                Section {
                    NavigationLink { Text("Retention") } label: { Label("Retention", systemImage: "chart.bar") }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(role: .close) { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Study", action: start).buttonStyle(.glassProminent) }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct CountsRow: View {
    var counts: StudyCounts
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 0))
        layout {
            cell("New", counts.new)
            cell("Learning", counts.learning)
            cell("Review", counts.review)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func cell(_ title: LocalizedStringKey, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text(value, format: .number)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(value > 0 ? .primary : .secondary)
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
```

### 3.4 Remove

`DeckView` and `DeckScreen` as screens (their notices, `EmptyDeckNotice` and the merge `Notice` move into the sheet's list); `StudyCountsColumns`; the totals footnote `Text("Total cards … · Suspended …")` (becomes two `LabeledContent` rows); the footer `Next review …` under the Study button; `fullScreenCover(item: $study)` moves to Today.

## 4. Study stream screen

### 4.1 Wireframe (portrait, 13 mini, answer shown)

```
┌───────────────────────────────────────┐
│ ✕          ◔  ≈ 4 min         ↶  (…) │ nav 44: close | principal: ring 30 + subheadline | undo | ellipsis
│ ┌───────────────────────────────────┐ │
│ │                                   │ │ card: margin 16, inner padding 24, radius 22,
│ │         ο Άγγλος    [spk]         │ │   secondarySystemBackground (unchanged)
│ │ ───────────────────────────────── │ │ divider at a fixed height
│ │       англичанин · Englishman     │ │ title2, regular
│ │       Ο Τζον είναι Άγγλος.        │ │ body, secondary
│ │                                   │ │
│ └───────────────────────────────────┘ │ card is about 500 high on the 13 mini
│    ╰───────────────────────────────╯    │ the cards waiting in the round: up to 3 blank edges, 6 pt apart
│ ╭───────────────────────────────────╮ │
│ │            ✕ Forgot               │ │ 50, Grade.again.color
│ ╰───────────────────────────────────╯ │
│               Recalled                │ footnote, secondary; 12 above, 4 below
│ ╭────────╮ ╭──────────╮ ╭────────╮    │ 50 high; gaps 12; widths 98 / 123 / 98
│ │  Hard  │ │   Good   │ │  Easy  │    │
│ ╰────────╯ ╰──────────╯ ╰────────╯    │
└───────────────────────────────────────┘ 12 bottom padding above the safe area; 8 under the bar; 12 + 18 for the edges between card and buttons
```

Width: 343 inside the 16 pt margins; (343 − 2 × 12) / 3.25 = 98.2, so Hard 98, Good 123, Easy 98.

### 4.2 Header

- Leading: `Button(role: .close)` (xmark). It replaces the `chevron.backward` End Session button; the stream has no session to end, every grade is saved. The HIG asks for the standard Close symbol and no text label [H:toolbars].
- Principal: `StreamRing` (a `ProgressRing`, 30 pt, `@ScaledMetric(relativeTo: .subheadline)` up to 44) + `Text("≈ 4 min")` (the time to the goal; for 1.5 s after a done card its interval, "in 8 days", cross-faded), `.subheadline`, `.monospacedDigit()`, spacing 8, `.accessibilityElement(children: .combine)` with the lap as its value ("Lap 2"). The ring is empty in the middle during the first lap, shows "×2" once the goal is reached, "×3" after the second lap. Goal met: `26 cards today`. This replaces both the 120-pt linear bar with `n / N` and the landscape `rowProgress`.
- Trailing: an icon button `arrow.uturn.backward` (Undo), enabled by the same condition as Undo in the menu (`StudyModel.canUndo`: the stream has a review or a suspension to take back), left of `Menu("More", systemImage: "ellipsis")` with Undo, Card Info, Suspend Card, Speak toggle. A shake undoes too. There is no chip under the bar: its room goes to the card.
- The ring is where the cards go (§4.7): its frame is reported to `StudyMotion.ringHome` (global coordinates, nothing fixed), it steps and glows when a card is done, and it is empty of everything else but the figures beside it.
- The streak is not in the header. The goal-met moment is the ring that closes as the last card leaves and bursts at the rest of the plan (§4.7).
- Practice stages show the word `Practice` as the principal text, without the ring.

### 4.2a Rests

The stream stops in three places, one `StreamRestView`, the same ring (96 pt) over the title, the figures in secondary under it, the buttons 24 pt below, as wide as the card (iPhone 400 pt at most, Mac 320). The model is in `learning-flow.md`.

| Rest | Title | Figures | Buttons |
|---|---|---|---|
| End of the first round (once a day, inside the plan) | `Streak kept` | the streak with a flame in the accent, `+4 words in memory today` when the day has added any, `12 cards left · ≈ 4 min` | **Keep Going** `.borderedProminent`, default action; **Done for Now** `.bordered` |
| The ring closed (the end of the last round while the plan has cards beyond it, or the end of the plan) | `Ring closed`, or `Done for today` when the plan ran out with the ring open | `10 cards · 22 answers`, share recalled, `+N words in memory today` or the milestone in the accent, the streak, the rings of the last seven days (`WeekRings`, 20 pt each, weekday initials under them, today last and bold), catch-up or next review | one prominent way on: **Catch Up** when due cards are left, else **+10 new** with its cost, else **Practice** `.bordered`; **Done** |
| End of a practice | `Practice complete` | cards, share recalled | **Done** |

The streak's rest has no card on screen, so nothing is spoken and nothing is graded; Undo in the bar takes back the review that ended the round. `StudyStream.restsAtEveryRound` brings back a rest after every round but the last.

On the iPhone the rest is reached by the ring's way (§4.7). The place of the last card stays as an empty slot, a faint rounded outline (`SlotOutline`, 10 % of the primary colour); the ring in the bar, once the card has left past the edge, comes down into the rest's ring place at the rest's size (96 pt) as one motion (`RingTraveler`, 0.55 s, a spring with a little bounce), the burst plays on arrival, and then the title, each line and the buttons come in one after the other, 0.1 s apart, each with a fade and a 6 pt lift (`StreamRestView` with `staggers`). The rest screen holds only the ring's place (`ringPlace`); the ring itself is the one that travelled. Keep Going, Catch Up and "+10 new" take the ring back up (the lines fade, the stream moves on, and 0.3 s later the cards are dealt, the stack spreading out from under the top card edge by edge), so the card area is back while the ring is still on its way. With Reduce Motion the rest crossfades in and out with its own ring, the lines come in together, and nothing travels or bursts.

### 4.3 Grade area

| Part | Spec |
|---|---|
| Container | One fixed-height container for both stages. Today `actions` is a 44-pt Show Answer button before the reveal and about 133 pt of grades after it, so the card shrinks by about 80 pt at the reveal and the divider with the question moves up by about 40 pt (derived from `cardArea` and `face`; not seen on screen). Keep the grade rows in the layout at all times (`opacity`, `allowsHitTesting`, `accessibilityHidden` as `face` does for the answer) and lay Show Answer over them (an overlay, so it has their size). |
| Show Answer | `Button`, `.buttonStyle(.borderedProminent)`, `.controlSize(.large)`, full width, accent fill, the whole rectangle of the grade block (Forgot's top to the bottom of the row), corner radius 14 like the grade buttons. |
| Forgot | Full width, height `@ScaledMetric(relativeTo: .body) var height = 50` (52 today), `Label("Forgot", systemImage: "xmark")`, `.font(.body.weight(.semibold))`, fill `Grade.again.color`, white label. |
| Caption | `Text("Recalled")`, `.footnote`, secondary. 12 above (after Forgot), 4 below. |
| Hard / Good / Easy | `WeightedRow(weights: [1, 1.25, 1], spacing: 12)`, same height as Forgot, fills `Grade.hard/good/easy.color`, white labels. `minimumScaleFactor(0.7)` goes away; at `isAccessibilitySize` the four buttons stack, full width, gap 12. |
| Spacing | 12 between bezeled controls [H:accessibility]; today 8 and 4. Hard taken for Forgot is the costly slip for FSRS (comment in `GradeChoice`); the caption with its 12 + 4 keeps the two rows about 32 apart. The scale of the study screens is `Spacing`: 4, 8, 12, 16, 24. |
| Corner radius | 14 (as now). |
| Press state | `Pressable` (opacity 0.6) stays; the HIG requires a press state on custom buttons [H:buttons]. |
| Landscape (`verticalSizeClass == .compact`) | One row: Forgot (170) + Hard/Good/Easy, gap 12, height 44. The progress leaves the row for the nav bar. |

Four coloured grade buttons are one choice control; the HIG limit of one or two prominent buttons per view [H:buttons] applies to action buttons.

### 4.4 Card typography

Corpus (`cards-a1a2.tsv`, `cards-b1.tsv`, 5 494 cards): question length p95 24 and 27 characters, max 48; answer first line p95 42 and 48, max 87; example p95 42 and 52, max 86; 1 818 of 3 258 and 2 184 of 2 236 answers carry an example after `\n`.

| Role | iPhone | Mac |
|---|---|---|
| Greek text as question (recognition) or as answer head (production) | `.largeTitle.weight(.semibold)` 34/41 at the default size | `.system(size: 32, weight: .semibold)` as now |
| Other question (production, Russian) | `.title.weight(.semibold)` 28/34 | `.system(size: 26, weight: .semibold)` |
| Other answer head (Russian · English) | `.title2` 22/28, regular | `.title` (22 on macOS) |
| Example (second line of the answer) | `.body` 17/22, secondary | `.title3` (15 on macOS), secondary |
| Hint | `.title3` 20/25, secondary | `.title3` (15), secondary |
| Card state line (optional) | `.footnote` secondary: `Greek B1 · New` | `CardStateLine` as now |

Today the whole answer, example included, is `.largeTitle` regular, and the face applies `minimumScaleFactor(0.5)` to everything, so a 135-character answer renders at roughly half size (estimate) while a short one stays at 34. The size varies from card to card. The split above keeps each role at one size. `minimumScaleFactor(0.6)` stays only as a valve for the largest Dynamic Type sizes. The answer is split at the first `\n`; Greek is detected by script (`0x0370...0x03FF`, `0x1F00...0x1FFF`); `GreekSpeech.canSpeak` would also require an installed voice.

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
struct StreamToolbar: ToolbarContent {
    var ring: DailyRing
    var close: () -> Void
    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) { Button(role: .close, action: close) }
        ToolbarItem(placement: .principal) {
            HStack(spacing: 8) {
                ProgressRing(fraction: ring.fraction, diameter: 22)
                Text("\(ring.done) of \(ring.goal) cards").font(.subheadline).monospacedDigit()
            }
            .accessibilityElement(children: .combine)
        }
        ToolbarItem(placement: .primaryAction) {
            Menu("More", systemImage: "ellipsis") { Button("Undo", systemImage: "arrow.uturn.backward") {} }
        }
    }
}

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

### 4.6 Remove

`StudyView`: the `End Session` button with `chevron.backward`; the `ellipsis.circle` symbol of the More menu (also in `DeckView`); `progress` (the VStack with the 120-pt `ProgressView`); `rowProgress`; the `Color.clear` placeholder of `buttonRow`; `.font(.largeTitle)` on the whole answer; the single `minimumScaleFactor(0.5)` on the face; the 44-pt `frame(minHeight: 44)` on Show Answer; `.padding(.top, 16)` on `actions` (the container owns the spacing). `GradeChoice`: spacings 4 / 6 / 8, `minimumScaleFactor(0.7)`, the separate `height` values 52 / 44 (one `@ScaledMetric` and a landscape value).

### 4.7 Swipe grading

The card is swiped once its answer shows (`GradeSwipe`, `CardFlight`, `StudyView.touch`). Four directions, one per grade, the same as the arrow keys on the Mac: ← Forgot, → Good, ↑ Easy, ↓ Hard (`Grade.arrow`, `Grade.arrowSymbol`). The sectors are drawn on a clock face, 0 at the top, clockwise (compass degrees). For a right-handed thumb the vertical and the diagonal from the lower left to the upper right are the fast directions and the horizontal the slowest but most precise (Trudeau et al., Human Factors 2012), so Easy and Hard are wide and reach toward that diagonal, Forgot stays 60° and Good is a clean 90°. The code reads the finger's direction as an angle counter-clockwise from east with the screen's y turned up (math = 90 − compass). Every boundary and every reference direction is a constant of `GradeSwipe`, to be tuned there:

| Sector | Compass | Angle in the code | Constants | Grade | Reference, compass (code) |
|---|---|---|---|---|---|
| Up | 330° to 45° | 45° to 120° | `goodReach` = 45, `easyEnd` = 120 | Easy | 15° (`easyReference` = 75) |
| Right | 45° to 135° | -45° to 45° | `goodReach` | Good | 90° (`goodReference` = 0) |
| Down | 135° to 210° | 240° to 315° | `hardStart` = 240, 360 - `goodReach` | Hard | 165° (`hardReference` = 285) |
| Gap | 210° to 240° | 210° to 240° | `forgotEnd` = 210, `hardStart` | none | none |
| Left | 240° to 300° | 150° to 210° | `forgotStart` = 150, `forgotEnd` | Forgot | 270° (`forgotReference` = 180) |
| Gap | 300° to 330° | 120° to 150° | `easyEnd`, `forgotStart` | none | none |

Forgot is the only "no", and Easy given for a forgotten card is the costly slip, so Forgot has a gap on each side. Between two "yes" grades (right and up, right and down) there is no gap: a misread there is cheap. Commit distance 100 pt, dead zone 20 pt, flick (30 pt moved, 300 pt predicted) are `GradeSwipe.commitDistance`, `deadZone`, `flickMinimum`, `flickReach`.

- **In a gap** the swipe gives no grade: no tint, no lit button, no commit. The card follows the finger at `gapTravel` = half the travel, so it reads as "not a choice". Letting go springs it back, past the commit distance or on a flick; a flick also has to start in a zone and end in one. One haptic per grade (`CardFlight.gradeFeedback`): a swipe feels it when it reaches the commit distance of a grade, so letting go now grades, and again only if it reaches another grade's; the card that flies on letting go adds none. A button, a key or a flick, which never reach the commit distance, feel it when the card flies. A gap has no haptic.
- **Visual pull.** From the dead zone on, the card moves along the normalized average of the finger's unit direction and the reference direction of the recognized grade, at the finger's distance (`GradeSwipe.pull`). References, compass: Easy 15° (right of up), Good 90°, Hard 165° (right of down), Forgot 270° (west). A finger straight up moves the card 7.5° to the right of up, straight down 7.5° to the right of down, straight left stays at west. Easy's card goes between 7.5° left of up (the far edge of the sector) and 30° right of up (the near edge), Hard's the same below, Good goes right, Forgot's reference is due west. No sector lies more than 45° from its reference, so the average is always defined. Rotation and pivot are computed from the card's own offset. Tint, the lit button and the commit follow the recognized grade. Under the dead zone the card goes with the finger one to one.
- **Easing.** When the finger crosses into another zone or a gap, the card's way jumps. For 300 ms after a crossing the card eases with an interactive spring (response 0.12 s, damping 0.85, `CardFlight.glide`); the rest of the swipe is one to one.
- **Fly-off** goes along the reference direction of the grade, 640 pt (`GradeSwipe.exit`, `exitDistance`).
- **Onboarding** asks for ← Forgot, ↑ Easy, ↓ Hard, → Good in that order (`SwipePractice.order`). The idle hint plays the finger's step along the grade's reference direction through `CardFlight.drag`, so the card shows the way a real swipe would move it (Easy at compass 15°).
- **Gap misses.** A swipe that sprang back from a gap, past the commit distance or as a flick (`GradeSwipe.endedInGap`), and every swipe that reached the commit distance or flicked, are counted per study day by `SwipeTally` (in memory, per process; the study screen lets go of a swipe through `SwipeTally.shared.released`, which gives the grade `GradeSwipe.released` gives). "How Today Works" shows them in its Swipes section: "Swipes that sprang back from a gap: N of M today", with the sectors in compass degrees in the footer.
- **Where the card goes.** A grade is applied at once, and the card that was graded leaves past the edge of the screen as a card of its own (`Departure`, `DepartingCard`, drawn above the bar) from the pose it was let go in, with nothing written on it, while the next card is already on top and takes the next touch: nothing waits for a flight. What follows comes from the receipt (`GradeReceipt.destination`):

  | Receipt | Destination | Once the card is off the screen |
  |---|---|---|
  | interval `.days(n)`, not a leech | ring | the deepest edge of the stack fades and the stack moves up a step; the ring in the bar steps, bumps and bursts; the interval shows beside it |
  | interval `.learning` (Forgot, a learning step) | stack | a blank sheet comes in by the edge the card left by and slides under the stack to its deepest edge, which it becomes |
  | no interval (practice) or a leech | away | nothing |

  The ring's frame comes from the header (`onGeometryChange` in global coordinates, `StudyMotion.ringHome`), the card's place from the card (`cardSlot`); nothing is a constant of the screen.
- **Velocity.** A swipe's flight starts with the finger's release velocity (`DragGesture.Value.velocity`): each axis is a spring (`interpolatingSpring`, 0.45 s, no bounce) whose initial velocity is the finger's on that axis as a share of the distance left, so the card does not stop where it is let go and goes on along its grade's direction (an axis with no distance left, or no velocity, eases). A button or a key has none: x eases in and out, y eases in, 0.45 s (`PathCurves`). The card keeps turning the way it went. The flight is the same four numbers (across, down, smaller, faded), each by its own curve, so Undo can play it backwards and a test can freeze any instant.
- **The ring steps.** Each grade steps the ring in the bar at once by its gain (`GradeReceipt.gain`: the part of a card the grade added, 0 to 1), ahead of the figures, which wait for the card that speaks (`StudyMotion.shown`, caught up when the figures change and no card is leaving). A done card also bumps it (scale 1.0 to 1.15 and back with a soft glow in the accent, `ringBump`, 0.12 s up and 0.18 s down) and plays a small `RingBurst` round it; a card back today steps it quietly, Forgot moves nothing. No haptic.
- **The interval beside the ring.** For a done card the text beside the ring shows `GradeReceipt.flightLabel` for 1.5 s, cross-faded, then its figures again: "tomorrow" for 1 day, `Format.interval` for the rest ("in 8 days", "in 3 months"). The figures are "≈ 4 min" while the goal is open and "36 cards today" once met. VoiceOver is told the same, since the text is gone in a moment: "Good, in 8 days", posted as an `AccessibilityNotification.Announcement` (`GradeReceipt.announcement`).
- **The stack.** The cards of the current round that wait behind the one asked (`StudyModel.cardsBehind`: the cards the round still asks less the one on top, those that come back today included) show under the card as the edges of a book's pages (`CardStack`): up to 5 hairline outlines (1 pt, the card's corner radius, the separator colour, fainter with depth), each 3 pt lower and 2 pt narrower on each side than the one above, in the room reserved under the card (5 × 3 pt, always, so the card keeps its size); none when 0 are left, without rounds, and in practice. When the card on top leaves, the next one rises into its place from the pose of the first edge (a spring of 0.3 s, 2 pt in on each side, 3 pt lower) while its words fade in over 0.15 s. Losing an edge fades it while the stack moves up; the returning sheet becomes the edge it gains. When a round begins the edges spread out from under the top card one after the other.
- **Undo is the same motion backwards.** `StudyModel.undoReturn` says where the last step sent its card and whether the stream rests, `undoReceipt` which grade it was. The card comes in from the edge it left by to the top, with its answer showing (`returnedByUndo`), ready to be graded again, and nothing is spoken; the ring takes back the grade's gain, and a card that went under the stack takes its deepest edge with it for a moment. Across the end of a round the ring goes back up to the bar first, then the card returns. After a step that gave no grade (a suspension) the card rises in from the stack.
- **Round end.** The ring comes down to the rest and the rest's lines come in (§4.2a); after the last round the ring comes down as the card goes past the edge, closes and bursts on arrival. The burst (`RingBurst`) is the ring swelling 1.0, 1.12, 1.0 in 0.4 s and 12 specks of the accent, 2.5 to 4 pt, flying out from the ring's edge by a third to two thirds of its diameter and fading in 0.8 s (a `Canvas` in a `TimelineView`, drawn from the elapsed time alone). The glyph of the words-in-memory milestone line on Today bursts once, the first time the line shows for a milestone (`MilestoneCelebration`).
- **Reduce Motion.** No flight: the card stays where it is and fades out over 0.6 s, the ring steps without the bump or the glow, the stack count changes, the next card comes without rising, Undo's card is simply there, the rest crossfades without the ring's way, and there are no particles and no swell.
- **One haptic per grade, unchanged.** The grade's haptic is felt as before, once, and nothing is felt as the ring steps.
- **Heavy work.** The flights are transforms of cards that are drawn once: a view modifier per frame and nothing else on the main thread. The grade's own work is what it was, and the work that waits for the voice still waits (`GreekSpeech.whenQuiet()`), so the window of 0.3 to 2 s after a grade holds none of it.
- **Onboarding** asks for ← Forgot, ↑ Easy, ↓ Hard, → Good in that order (`SwipePractice.order`). The idle hint plays the finger's step along the sector's axis through `CardFlight.drag`, so the card shows the way a real swipe would move it (Easy at 67.5°).

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

Roles of the accent: prominent button fill (Study, Show Answer, Study in the details sheet), ring, flame when the goal is met, `info.circle`, selection, the glow of the ring when a card is done and the specks of the burst (§4.7). Nothing else: no text, no resting backgrounds, no card face.

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
- **Maturity ramp** stays blue (`Presentation.swift`, CLAUDE.md asks to keep it). Its hues are 253° to 257°, 20° to 26° from the accent: it is the accent's nearest neighbour. The closest pairs are `#5856D6` with the ramp's `#2A78D6` (ΔE 8.8, ratio 1.28), `#3634A3` with `#104281` (ΔE 7.6, ratio 1.03) and `#6563E6` with `#2A78D6` (ΔE 7.9, ratio 1.06). Chart colours are data colours and differ from the interactive accent, which keeps accent = "tap or progress".
- **Card face** stays `secondarySystemBackground`. `CardFlight.textColor` records contrast numbers for the grade tint measured on a neutral face (Hard text 2.3 to 2.9 on a light card); a tinted face would move all of them. The icon's cards (`#E4E3FA`, `#F8F7FF`) are not reused in the UI.

### 5.3 New / Learning / Review

Neutral, decided in §1. Number `.primary`, 0 in `.secondary`; label `.secondary`; same weight in every column; no symbols. The words carry the meaning, so nothing depends on colour [H:accessibility]. The order New, Learning, Review stays, as in Anki.

### 5.4 Role table

| Role | Colour | Where |
|---|---|---|
| Action, progress | `AccentColor` | §5.1 list |
| Text | `.primary`, `.secondary`, `.tertiary` | everything else |
| Counts | neutral | Today row, details, Mac |
| Grades | `Grade.color`, unchanged | grade buttons, swipe tint, review history |
| Maturity | blue ramp, unchanged | statistics |
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

On macOS `AccentColor` applies only when the system accent is Multicolor, and selection and sidebar icons follow the user's choice [G §12][H:sidebars]. No `.tint(...)` override on the Mac. Ring and prominent buttons use `Color.accentColor` and `.borderedProminent`, so a Graphite machine shows them gray by the owner's choice.

### 5.7 Rings: drawing, middle, sources

The owner asked on 22.10.2026 for rings in the manner of the Fitness rings, taken from open-source rings and without a dependency. The drawing is `Shared/Support/ActivityRing.swift`: [MKRingProgressView](https://github.com/maxkonovalov/MKRingProgressView) by Max Konovalov (MIT) transcribed line for line — `RingProgressLayer.drawContent(in:)` as `RingDrawing.draw`, `GradientGenerator` as it is — inside a SwiftUI `Canvas` (`withCGContext`), so the same drawing runs on iOS, macOS and in the widget. The order is MK's: a backdrop circle in the start colour at 15 %; past one lap a solid arc in the start colour, then the context rotated so the gradient arc ends at the head; the end circle in the start colour with a shadow (`w/3` blur, offset `w/10` along the way the ring runs, opacity 1) clipped to the ring; the gradient arc on top, a conic gradient image clipped to the stroked arc. Options: MK's defaults, except `hidesRingForZeroProgress` on (an empty ring shows only the backdrop) and the gradient image at the display's scale. `UIBezierPath(arcCenter:…, clockwise: true)` became `CGMutablePath.addArc(…, clockwise: false)`; colours resolved from SwiftUI are converted to device RGB before the generator reads their components. The gradient image depends on size and colours only, so the last one is cached while a ring animates.

**Colour.** Head: the accent. Tail: the accent mixed with 25 % white in device RGB. `AccentContrastTests.ringGradientHoldsItsContrastInEveryAppearance` reads both ends from the pixels of a view in each appearance and holds the tail to 3:1 on the four surfaces and to 1.3:1 against the accent, in light, dark and both increased-contrast variants. The test reads pixels because `Color.accentColor` is the asset's accent only inside a view: `UIColor(Color.accentColor)` gives the system blue. Line width 15 % of the diameter, at least 3 pt.

The tail and its WCAG ratios, computed from the 8-bit values (surfaces as in §5.1):

| Appearance | Tail | Against the accent (1.3 or more) | On surface (3.0 or more) |
|---|---|---|---|
| Light | `#8280E0` | 1.64 | 3.44 on white, 3.08 on `#F2F2F7` |
| Light, Increase Contrast | `#6867BA` | 1.95 | 4.96 on white, 4.17 on `#EBEBF0` |
| Dark | `#8280E0` | 1.64 | 6.11 on black, 4.95 on `#1C1C1E`; raised 4.06 on `#2C2C2E` |
| Dark, Increase Contrast | `#8C8AEC` | 1.55 | 6.96 on black, 5.14 on `#242426`; raised 4.00 on `#363638` |

Every tail ratio meets the test's thresholds; the lowest on a surface is 3.08 (light, on `#F2F2F7`). A third of white instead of a quarter gives 2.62 there (`#908EE4`).

**Middle.** Outside the stream, the streak in days: bold rounded number, 34 % of the diameter, and the word "days" (9 pt at least, 14 %) under it from a diameter of 56 pt; nothing at 0 days. Inside the stream (`StreamRing`, the Mac session's `DailyRingView(inStream: true)`): empty in the first lap, "×2" once the goal is reached (`DailyRing.laps` is 1), "×3" after the second lap. The lap shown is `laps + 1`. The pure choice is `RingCenter(_:inStream:)`.

| Place | Ring | Middle |
|---|---|---|
| Today (`SummaryRow`) | 72 pt, `@ScaledMetric(relativeTo: .title2)`, at most 96 | streak and "days" |
| Rest screen (`StreamRestView`) | 96 pt | streak and "days" |
| Study bar (`StreamRing`) | 30 pt, `@ScaledMetric(relativeTo: .subheadline)`, at most 44; inner width 21 pt holds "×2" at 11 pt (three characters shrink to 0.5) | lap |
| Mac toolbar chip (`RingChip`) | 24 pt | streak, number only |
| Mac session header (`DailyRingView`) | 28 pt, a button with a popover | lap |

VoiceOver: `DailyRingView` reads "Day streak: 5 days" or "Lap 2" as its label and "14 / 36" as its value, "Daily Goal" while the middle is empty; in the study bar `StreamRing` passes `speaksCenter: true`, so "Lap 2" joins "14 of 36" in the bar's combined element. `ProgressRing` is otherwise hidden from accessibility, as the text beside it says the figures. The popover shows "Goal reached" with a check mark and "Lap ×N" from the second lap.

Pictures: `VocTrainTests/RingTests.swift` (`TEST_RUNNER_STUDY_SHOTS_DIR`) writes `ring-1-today`, `ring-2-study-bar`, `ring-3-chip`, `ring-4-rest` in light and dark at 0, 40, 100, 160 and 230 % of the goal, and `ring-5-edges` at 5, 95, 100, 105, 150, 200 and 300 %; `MacVocTrainNgTests/RingSnapshotMacTests.swift` writes the Mac chip and the session ring.

## 6. Mac

### 6.1 Hierarchy

Level 0 Today (all decks) → level 1 deck (details) → level 2 the deck document window (Cards, Statistics, Learning Options). iPhone shows the same levels as Today → details sheet → statistics.

### 6.2 Phase A: deck window (document window, small change)

Toolbar order, left to right: segmented `Cards | Statistics` (principal, as now) · ring chip · **Study** (`.borderedProminent`) · fixed space · Add Lesson Words · Learning Options.

- Ring chip: `ProgressRing(diameter: 24)` with the streak in the middle (number only, 24 pt is too small for the word) + `Text("14/36")` monospaced, `.help("14 of 36 cards · 12-day streak")`, `.sharedBackgroundVisibility(.hidden)` (an indicator takes no button background).
- Study: `Button("Study")` without count and without the `graduationcap` label. `ToolbarSpacer(.fixed)` between it and the symbol buttons: a text button next to symbol buttons reads as one control [H:toolbars]. The menu command Study ▸ Start Session (⌘L) exists, so the toolbar item has its menu twin [H:toolbars]; rename the item `Start Studying`.
- Session header (`SessionView.header`): replace the 320-pt `ProgressView` and `n / N` with `DailyRingView(progress:, inStream: true)`, the lap in the middle as on the iPhone; keep the mistakes counter and Edit Card…; End Session becomes Done.
- Spacing: `GradeChoice` gap 12 on Mac too; height stays 38 (HIG default Mac control 28, minimum 20 [H:accessibility]).
- Settings: the `Settings` scene and ⌘, stay; no settings button in the toolbar [H:settings]. A daily-goal setting, if one is added, becomes a pane there.
- Status bar (`CardListView.StatusBar`) keeps its Today counts line, neutral, as now.

### 6.3 Phase B: Today window

Replaces the Welcome window (`WelcomeWindow`, `WelcomeView`); opens at launch when no document opens, Window ▸ Today (⌘0), Dock click with no window. Single-instance SwiftUI `Window("Today", id: "today")`.

```
┌──────────────────────────────────────────────────────────────────┐
│ ● ● ●  ◫       Today                     ◔ 14/101    [ Study ]   │ title Today, subtitle 14 of 101 cards
├────────────────┬─────────────────────────────────────────────────┤
│ (o) Today      │ ┌ Form, .grouped ───────────────────────────┐   │
│                │ │ ╭──╮ 87 cards left                        │   │
│ Decks          │ │ │◔ │ 14 of 101 cards [flame] 12-day streak │   │
│ ▤ Greek A1–A2 60│ └───────────────────────────────────────────┘   │
│ ▤ Greek B1    27│ ┌ Decks ────────────────────────────────────┐   │
│                │ │ Greek A1–A2  30 new · 0 learning · 30 review│   │
│                │ │ Greek B1     20 new · 4 learning · 3 review │   │
└────────────────┴─────────────────────────────────────────────────┘
```

| Element | SwiftUI |
|---|---|
| Layout | `NavigationSplitView`; sidebar `List(selection:)`, `.listStyle(.sidebar)`, `.navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)` |
| Sidebar rows | `Label("Today", systemImage: "sun.max")`; section `Decks` with `Label(name, systemImage: "rectangle.stack")` + `.badge(total)`. Icons keep the system accent. At most two levels; no controls at the bottom of the sidebar [H:sidebars]. |
| Detail, Today | `Form` with `.formStyle(.grouped)`: summary and per-deck rows, same strings as the iPhone |
| Detail, deck | the iPhone `DeckDetails` content (counts row, totals, practice, retention) plus `Open Deck`, which opens the document window |
| Toolbar | ring chip, `ToolbarSpacer(.fixed)`, `Study` `.borderedProminent` (studies the selected deck; with Today selected it starts the first deck of the queue in §2.5, and the rest screen offers the next one) |
| Study | opens the deck window and starts the stream there: the stream needs the document and its undo manager, which the deck window's view attaches. Same one-shot request as `WelcomeRequest.takeImportCards()`. |
| Panes | the sidebar can be hidden; View ▸ Show/Hide Sidebar. The window title is the selection, never the app name [H:toolbars]. |

The window has no bottom bar; nothing critical sits at its bottom edge [H:windows][H:sidebars].

### 6.4 Code (typechecked, macOS)

```swift
enum HomeSelection: Hashable { case today, deck(URL) }

struct MacHome: View {
    var decks: [KnownDeck]
    var counts: [URL: StudyCounts]
    var ring: DailyRing
    @State private var selection: HomeSelection? = .today

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Today", systemImage: "sun.max").tag(HomeSelection.today)
                Section("Decks") {
                    ForEach(decks) { deck in
                        Label(deck.name, systemImage: "rectangle.stack")
                            .badge(counts[deck.url]?.total ?? 0)
                            .tag(HomeSelection.deck(deck.url))
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            Form {
                Section("Today") { Text("summary") }
            }
            .formStyle(.grouped)
            .navigationTitle("Today")
            .navigationSubtitle("\(ring.done) of \(ring.goal) cards")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 6) {
                    ProgressRing(fraction: ring.fraction, diameter: 16)
                    Text("\(ring.done)/\(ring.goal)").monospacedDigit()
                }
                .help("14 of 36 cards")
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) {
                Button("Study") {}
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
```

### 6.5 Remove (Mac)

`DocumentView`: `StartStudyButton`'s `Label("Study (\(count))", systemImage: "graduationcap")`. `SessionView.header`: `ProgressView(...).frame(maxWidth: 320)` and `n / N`. Welcome window: the 30-pt bold "Mnemit" title and the icon block on the left, `Remember a little every day`, the large prominent `Open Mnemit Folder…` (the folder choice moves to File ▸ and the empty state of the Today window), `DeckRow`'s `.fontWeight(.semibold)` and tinted `rectangle.stack` icons.

## 7. Build order, strings, checks, sources

### 7.1 Order

1. `AccentColor.colorset` in the iPhone, Mac and widget targets, remove `StudyCount.color` (S).
2. `ProgressRing`, `SummaryRow`, `DeckRow`, `TodayScreen`, launch change, deployment targets (M). Needs `DailyProgress` from the stream agent.
3. `DeckDetails` sheet (S).
4. Stream header, grade area, card fonts (S–M). Needs the stream view model.
5. Mac phase A (S), phase B (M).

Dependencies on the stream agent: `DailyProgress`, `DailyRing`, `Streak`; a `StudyScope` with a deck queue; a `Next: <deck>` action on the `rest` screen; `StudyStream` practice initialisers for the details sheet.

### 7.2 New strings (Shared/Resources/Localizable.xcstrings, German in state `translated`)

`Today` and `Study` exist (`Heute`, `Lernen`). New: `Decks`, `Keep Going`, `All done`, `Nothing due`, `+%lld to catch up this week`, `Catch Up`, `%lld of %lld cards`, `%lld cards left`, `%lld cards today`, `%lld-day streak` (plural), `Deck Details`, `Practice Newest Words`, `Practice Today's Mistakes`, `What today's plan takes from this deck.`, `Next: %@`, `Goal reached`, `No Decks`, `Open Deck`.

### 7.3 Check matrix (on the 13 mini simulator or device; Mac with `vqa`)

| Screen | States |
|---|---|
| Today | due, nothing due with reviews, nothing due without reviews, no decks, cached first frame, one deck unreadable; light, dark, Increase Contrast, Reduce Transparency; Large, xxxLarge, AX3; landscape |
| Details | medium and large detent, counts with zeros, suspended 0 and above 0, AX3 |
| Stream | question, revealed, grade area height equal in both stages, 4-line question, 135-character answer, AX1 and AX3, landscape |
| Contrast | gate test table, all four appearances |
| Mac | phase A toolbar at the minimum window width 720 (items must not overflow by default [H:toolbars]), Graphite and Multicolor accent |

### 7.4 UNVERIFIED

- All rendering: glass prominent button label colour and height, `safeAreaBar` with a `List`, principal toolbar ring, press feedback of a `.plain` button in a list row, concentric card corners. iOS 27 behaviour: the installed SDK is 26.2 (Xcode 26.3).
- Fitness and Reminders layouts (ring left, metrics right, counts trailing in My Lists) are from memory; only the facts in [A:fitness] were read.
- `.buttonStyle(.borderedProminent)` giving the prominent glass look in toolbars (the HIG names the `.prominent` style, the API mapping is from memory).
- Deck window toolbar overflow at width 720 with the new items.
- That `minimumScaleFactor` does not re-track text.

### 7.5 Sources (opened 2026-10-21)

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
