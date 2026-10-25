# Mnemit 7: the quality plan

Audit of 6.1.5 on 26.10.2026, under EF's full autonomy: every decision below is taken, with its reason and,
where it is not a plain revert, its rollback. Nothing here is built yet. Order of work: §9.

## 1. Evidence

- iPhone: the snapshot gallery of 6.1.5 on the iPhone 17 simulator, 305 frames, light and dark, text sizes up
  to AX5 (`HomeSnapshotTests`, `ScreenGallerySnapshotTests`, `StudyScreenSnapshotTests`, `BrowserSnapshotTests`,
  `DeckEditingSnapshotTests`, `ImportPreviewSnapshotTests`, `WidgetShotsTests`, `RingSnapshotTests`,
  `OnboardingSnapshotTests`). The device was not in reach.
- Mac: 16 frames of `TodayWindowSnapshotTests`, `SessionSnapshotMacTests`, `RingSnapshotMacTests`, and
  `~/Applications/Mnemit.app` live over EF's two decks (Overview, Cards, Statistics).
- EF's logs (`reviews.jsonl` of both decks): 251 grades on 4 study days (21–25.10), all `revealed`: no typed
  review, no practice. Forgot 30 %, Hard 8 %, Good 60 %, Easy 2 %.
- Code: the string catalog (663 keys, 21 referenced nowhere), the Mac window plumbing (`WelcomeRequest`),
  `DeckStatistics`, `PreferencesView`, `SettingsView`.

## 2. Who it is for

| Portrait | Device and rhythm | Jobs | What decides whether they stay |
|---|---|---|---|
| **Course learner** (EF) | iPhone 13 mini, 2–10 min several times a day; the Mac at the desk after a lesson | keep the streak at no cost; get a lesson's 20 words in within a minute; not forget them before the next class | one tap to study; the streak seen at a glance; adding words on either device |
| **Newcomer** | iPhone only, no decks, no Anki | learn the gesture, get first words in, close the first ring on day 1 | the first two minutes; never an empty screen without a next step |
| **Anki migrant** | Mac and iPhone, 20–60 min a day, years of history | import with history, trust the schedule, review fast by keyboard, tidy cards | import fidelity, numbers that agree, a real Mac app |

The scenarios every change is measured against:

| # | Scenario | Target |
|---|---|---|
| S1 | Daily: widget, notification or launch → first card | 1 tap, nothing to read |
| S2 | After a lesson: add 20 words | under 60 s on either device, one sheet |
| S3 | Mid-stream: fix a wrong card | 2 actions, without leaving the stream |
| S4 | Back after two missed days | sees at once what the streak lost and what to do |
| S5 | Desk session on the Mac | ⌘L from anywhere, keys only, one window |
| S6 | First launch with nothing | the first card asked within 2 minutes |
| S7 | Import from Anki | the history arrives; the counts match Anki's |

## 3. Verdict: what is wrong, in order of harm

1. **The Mac is another app.** The iPhone is one stack under Today. The Mac has five kinds of window (Today, one
   per deck, Progress, How Today Works, AnkiWeb) and studies all decks inside the window of one deck, titled with
   that deck's file name ("Greek B1.mnemit") while it asks cards of the other. Today's Study and Pause open the
   window of every deck they touch (`WelcomeRequest.requestStudy` → `DeckFolder.open`), and a preference
   reopens deck windows at launch, so the Mac often starts on a deck.
2. **Today says one number three times and keeps the streak small.** "20 cards left · ≈ 5 min", "10 of 30
   cards", the ring, and per deck "4 new · 10 review" beside "14". The streak is the middle of a 72 pt ring: a
   flame whose kept and not-kept states differ only in grey against orange.
3. **Numbers disagree.** One deck, one minute: Statistics "Due Now 2,229" (`Deck.dueCount` counts new cards),
   Cards "Due 14", Overview "2 learning · 12 review"; Statistics "New 2,293" (suspended included), the filter
   "New 2,215". The circular widget puts the cards left in the middle of its ring, where every other ring has the
   streak.
4. **Text explains the interface.** A footer under nearly every block ("What today's plan takes from this
   deck.", "Practice doesn't change when cards come back", "More reviews in the days ahead", "Recalled", "Space
   or ↩"); jargon on screen (Push On, Word Key, Stability, Difficulty, Reviewed Today); the language in labels
   ("Translation → Greek"); stale text: Settings says the reminder lists the cards due per deck and the badge is
   the total due, both untrue since 6.0; onboarding says decks come from the Mac.
5. **Upstream's leftovers.** Typing mode, the damping of revealed reviews and retention by review mode exist on
   the Mac only and were never used (0 typed of 251); Import MacVocTrain 1 Document; the reopen-decks
   preference; the Practice section on both deck screens (0 practice reviews); 21 strings in four languages that
   no code uses.

Kept as they are: FSRS and the ring's rules, the swipe sectors and what the grade colours mean, the 04:00 day,
Study and Catch Up, no bundled content, the Personal Team's limits (no iCloud container, no App Group on the
Mac).

## 4. The model on one page

On screen there are seven nouns, **Today, Deck, Card, Word, Ring, Streak, Words in memory**, and three verbs,
**Study, Catch Up, Learn 10 New Words**. Plan, round, review, stability, word key and FSRS live in How It Works,
Options and the Details of a card.

Rules every surface keeps:

1. The middle of every ring is the streak: the flame and its days. The ring is the day's goal. No other number
   goes in the middle.
2. The streak's state is shape and colour: `flame` outlined in secondary grey until the day's streak step is
   done, `flame.fill` in `Color.streak` after; at risk (the day after a missed one) the outline turns
   `Color.streak`. Colour is never the only sign.
3. One definition per count (§4.1), taken from the same function on every screen.
4. Cards are the work, words the gain: the ring and the decks count cards, the gain line counts words.
5. One action per state, named by what it does: Study (ring open), Catch Up (ring closed, plan has cards left),
   Learn 10 New Words (plan done).
6. No label names a language: "Word → Meaning", "Meaning → Word".

### 4.1 Counts

| On screen | Definition | Source |
|---|---|---|
| cards left (Today, deck rows, sidebar badges, widget) | cards of today's plan not done yet, over the active decks or one deck | `StudyCounts.total` |
| Due (filter, Statistics) | due now, not new, not suspended | `CardFilter.due` |
| New (filter, Statistics) | new, not suspended | `CardFilter.new` |
| Suspended (filter, Statistics) | suspended | `CardFilter.suspended` |
| words in memory | the sum of recall over learned recognition cards | `DailyProgress` |

`DeckStatistics.Summary` takes Due and New from `Deck.filterCounts(at:)`; the tile Reviewed Today goes.

## 5. Screens

Each item: what changes, where, why.

### 5.1 Today (iPhone) and the Today page (Mac)

13 mini, 375 × 812, ring open:

```
┌─────────────────────────────────────┐
│ Today                       (+) (⋯) │ large title; + Add Cards, Import…, New Deck, Shared Decks on AnkiWeb
│                                     │
│             ╭──────────╮            │ ring 168 pt, line 18: the day's goal
│             │    🔥    │            │ flame 28 pt, rule 2
│             │    12    │            │ streak days: .largeTitle bold, monospaced digits
│             │day streak│            │ caption, secondary
│             ╰──────────╯            │
│        20 cards left · ≈ 5 min      │ title3 semibold, centred
│   412 words in memory · +15 today   │ subheadline, secondary
│                                     │
│  M   T   W   T   F   S   S       ›  │ the week: 7 rings of 22 pt, today last; the row pushes Progress
│                                     │
│  DECKS                              │
│  Greek A1–A2                  14  › │ one line: name and cards left, ✓ when none
│  Greek B1                      6  › │
│                                     │
│ [          Study          ]  ( 🔍 ) │ the day's action; search minimised beside it
└─────────────────────────────────────┘
```

- **The hero.** The ring grows from 72 to 168 pt and is centred; the streak's number is large, with "day
  streak" under it. The streak is the habit EF asked to see more of, the ring is the day's one goal, and the
  screen had 300 pt of empty grey under two decks.
- **One headline, one gain line.** Headlines by state: "≈ 2 min to keep your streak", "20 cards left · ≈ 5
  min", "Ring closed · 3 left", "All done", "Nothing due · next tomorrow"; at risk "Close the ring to save your
  12-day streak". They go: "10 of 30 cards" (the ring draws it), "Yesterday …" (the week shows it), the "≈"
  before the words (an estimate shown as a count, as Fitness shows calories).
- **The week.** `WeekRings`, drawn today on the Ring closed rest, comes to Today: closed rings full, a missed day
  an empty track, today's ring live. It is the streak's second sign and the visible way into Progress; the whole
  hero opens Progress too.
- **Deck rows** lose their subtitle: "4 new · 10 review" repeats the 14 beside it. A done deck shows ✓ without
  "Next review tomorrow". Paused decks keep their section.
- **The bottom bar.** `searchToolbarBehavior(.minimize)` makes Search All Cards a button beside Study: two bars
  stacked at the bottom took the thumb's zone twice, and search is a weekly action where Study is a daily one.
- **Push On becomes Learn 10 New Words**, without its footnote: the label says what happens, and the footnote
  was a warning attached to a reward.
- **Mac:** the same view is the detail of the sidebar's Today (§5.13), ring 200 pt, with the Study button under
  the hero and in the toolbar (⌘L). The sidebar holds the decks, so the page has no deck list. Going with the
  Today window: the five blue links (they are menu items, §5.13), the header "Decks in “Mnemit”" (the folder is
  named only in Settings), Recent Decks, the welcome icon and version.

### 5.2 The stream (both)

- The header's ring gets the flame in its middle, outlined until the streak step and filled the moment the step
  is done, with the ring's existing bump. The streak's moment happens in the stream; today only the rest after
  it shows it.
- "Recalled" over Hard, Good and Easy goes: red is no, green is yes, and onboarding teaches it.
- Hard is a grey-green that reads as a disabled button. It becomes the light end of the green ramp, at 4.5:1 or
  more against its label (the validator of `design-spec.md` §5.5).
- Mac: each grade button carries its key as a glyph, ← Forgot, ↓ Hard, → Good, ↑ Easy, the directions of the
  iPhone's swipes; "Space or ↩" becomes a keycap inside Show Answer. The typing bar ("Previous: … ⌘Z to
  undo") goes with typing (§7).
- One menu on both: Edit Card, Card Info, Suspend Card, Pronounce Automatically (a toggle). Leaving: the close
  button on the iPhone, Done (⌘.) on the Mac; Esc and Z stay Undo (EF, 22.10).
- **New words are introduced.** In a deck marked **New words**, a new card's first showing has its answer open
  and "New word" in the chip; a swipe right moves on (Good), left keeps it in learning (Forgot). A deck marked
  **Words I know** asks as it does now. The mark is asked once when a deck is made or imported (§5.6) and sits in
  Options. 30 % of EF's grades are Forgot, mostly first showings of B1 words never seen before: a red Forgot as the
  first contact with a word punishes learning it. HANDOFF Open 6 named it from the persona reviews of 23.10.

### 5.3 Rests (both)

- Streak kept: the title is the streak, "12-day streak", with the filled flame large; today the title is
  "Streak kept" and the days are a small line under it. Keep Going, Done for Now.
- Ring closed: the week, the medal, one gain line; Done, then Catch Up or Learn 10 New Words.
- Gallery gap: no frame shows a rest with its buttons (they come last in `reveal`). `StudyScreenSnapshotTests`
  takes the frames after the reveal ends, and the Mac's `planEnd()`, which today shows a card, takes the rest it
  is named after.

### 5.4 A deck (iPhone screen, Mac sidebar item)

- iPhone: a one-line header, "14 cards today", "✓ Done · next review tomorrow" or "Paused"; rows Cards (count),
  Statistics, Options; Study This Deck at the bottom (Learn 10 New Words once nothing is left). Toolbar: + (Add
  Cards, Import Cards…), ⋯ (Practice Newest Words, Practice Today's Mistakes, Rename…, Pause Deck, Export…,
  Delete Deck). They go: the counts block and its footer, Shared Decks on AnkiWeb (finding other decks has no
  place inside a deck), the Practice section and its footer (0 practice reviews; the menu keeps both streams one
  tap away).
- Mac: no Overview page. A deck in the sidebar shows **Cards | Statistics** (segmented, in the toolbar), a strip
  above the table with "14 cards today" and Study This Deck, and Learning Options in the toolbar (⌘;). Overview
  repeated the toolbar's Study and the segments' Cards and Statistics as iOS rows with chevrons.
- The deck's name without its extension in every title.

### 5.5 Cards, Card Detail, Edit Card

- Card Detail (iPhone) and the inspector (Mac): the sides, the direction ("Word → Meaning" with a link to the
  sibling), and **Memory** as one line in the ladder's colour: "Young · next review in 3 days". Stability,
  difficulty, recall now and the word key go under a disclosure **Details**: the learner reads where the word
  stands, the Anki migrant has the figures one tap away.
- The Kind column and every label of direction: Word → Meaning, Meaning → Word.
- Mac: the add form above the table goes (adding is the sheet of §5.6), and so does the status line "Today: 2
  learning · 12 review" (the strip above the table says it).
- The answer's placeholder loses "(alternatives separated by /)" with typing.

### 5.6 Add Cards, New Deck, Import, AnkiWeb

- One Add Cards sheet on both, One Card | From a List. On the Mac it replaces Add Lesson Words and keeps its
  shortcut ⇧⌘L, opening on the mode used last.
- New Deck asks the name and **New words / Words I know**, then opens Add Cards, as it does now. An Anki import
  that makes a deck asks the same, preset to Words I know when the package has review history.
- Shared Decks on AnkiWeb: Today's + menu, the empty state, the Mac's File menu. Not on deck screens.

### 5.7 Progress, Medals, the month, How It Works

- Progress opens with the streak hero as on Today (the same view, larger), then the four totals, the calendar
  with **streak runs joined** (a band behind consecutive kept days), the medals, the memory ladder. The 13-week
  grid shows rings and not the streak, which is what people count.
- How Today Works becomes **How It Works**, with a first section "Today" in three plain sentences over the
  tables (HANDOFF Open 5). On the Mac a sheet from Progress, without a window.
- On the Mac, Progress is the sidebar item, without a window.

### 5.8 Statistics (both, per deck)

- Tiles by §4.1: Cards, Due, New, Suspended, Recall now. Reviewed Today goes (a review never shows on screen).
- Retention: one table, Young, Mature and Total over Today to the last 365 days. "By review mode and card kind"
  goes with typing.
- The same sections on both; the Mac adds its charts.

### 5.9 Options

- New cards per day: one stepper whose last step is Unlimited; today a stepper and a toggle set one value.
- One sentence per footer. The long ones (target recall, unlock, leech, FSRS parameters) keep their detail in
  How It Works.
- "Translation → Greek" becomes "Meaning → Word cards"; the damping of revealed reviews goes (§7).
- New: **Words in this deck: New words / Words I know** (§5.2).

### 5.10 Settings (iPhone) and Settings (Mac, ⌘,)

The same sections on both: **Pronounce Automatically**; **Mnemit Folder** (the folder, Change…); Reminder (the
iPhone: toggle and time); Show Introduction (the iPhone); the version. The reminder's footer goes, it was untrue.
The Mac loses Study by, Continue automatically and Reopen decks.

### 5.11 First launch

- iPhone onboarding keeps its order. "One stack a day" keeps three lines (the ring, the streak, the words). "Decks
  you create in Mnemit on the Mac appear here once they sync" becomes "Decks in this folder appear here."
- With an empty folder the newcomer lands on Today's empty state, which gets the hero ring above New Deck, Use
  iCloud Drive Folder and AnkiWeb, empty and captioned "Start your streak": the first screen already shows the
  reward.
- Mac first run: an empty sidebar and the same empty state in the detail; the first stream shows the key glyphs
  (§5.2).

### 5.12 Widgets, reminders, the badge

- Circular: the ring with the flame and the streak, as every ring (rule 1); the cards left go. It shows 17 in one
  state and 31 with a flame in another, in the same place.
- Medium: the headline and the week, where "≈ 28 words in memory" was.
- New: the **inline** accessory over the lock screen's clock, "🔥 12 · 20 cards left".
- Reminders: a second notification at 21:00 on a day the streak is at stake and not kept yet, withdrawn once the
  streak step is done, in the first one's words ("Keep your 12-day streak · ≈ 2 min"). No setting: Daily Reminder
  off turns both off.
- The badge stays: the cards to the ring.

### 5.13 The Mac: one window

```
┌ Sidebar ─────────────┬ Detail ──────────────────────────────────────────┐
│ ◎ Today          20  │ toolbar:                           [Study ⌘L]    │
│ ◔ Progress           │                                                  │
│ DECKS                │                ring 200, the streak              │
│ ▤ Greek A1–A2    14  │             20 cards left · ≈ 5 min              │
│ ▤ Greek B1        6  │        412 words in memory · +15 today           │
│ PAUSED               │              M  T  W  T  F  S  S                 │
│ ▤ Greek B2           │                                                  │
│ (+)                  │                                                  │
└──────────────────────┴──────────────────────────────────────────────────┘
```

- One `Window` scene with `NavigationSplitView`: the sidebar holds Today, Progress, Decks (badges: cards left)
  and Paused; the detail follows the selection. The stream takes the whole window (the sidebar collapses and
  comes back on Done). Launch lands on Today.
- Decks open without windows, as on the iPhone: `OpenDeck`, `PushedDecks` and `StudyRun` move to `Shared` over a
  `DeckFileDocument` that is a `UIDocument` on the iPhone and an `NSDocument` without window controllers on the
  Mac; `VersionMerger` and the undo stay as they are. They go: `DocumentGroup`, `DocumentWindow`,
  `WelcomeWindow` with `WelcomeRequest` and its notifications, `ProgressWindow`, `HowTodayWorksWindow`,
  `DeckOverviewView`, the reopen-decks preference.
- Why: the HIG sets document apps (files a person handles one at a time) apart from library apps (Photos, Music,
  Notes: one window, a sidebar of collections), and a folder of decks the app keeps is a library. The Mac then
  has the iPhone's model one to one: Today, decks, a deck's cards.
- A `.mnemit` opened from Finder is selected in the sidebar; one outside the folder sits under Other Decks until
  the app quits.
- Menus. File: New Deck ⌘N, Open Deck… ⌘O, Import Cards… ⇧⌘I, Shared Decks on AnkiWeb…, Export Deck…, Show in
  Finder. Study: the day's action ⌘L (Study, Catch Up or Learn 10 New Words), Study This Deck ⌥⌘L, Add Cards…
  ⇧⌘L, Practice Newest Words, Practice Today's Mistakes, Pause Deck, Learning Options… ⌘;. View: Today ⌘1,
  Progress ⌘2, Cards ⌘3, Statistics ⌘4, Show Inspector ⌥⌘I. Help: Keyboard Shortcuts.
- Rollback: the tag `pre-single-window` on `main` before the change.

## 6. Text

| Where | Now | Then |
|---|---|---|
| Deck (both) | What today's plan takes from this deck. | — |
| Deck (both) | Practice doesn't change when cards come back | — (practice is in the menu) |
| Today, deck, rests (both) | More reviews in the days ahead | — |
| Today, deck, rests, toolbar help | Push On | Learn 10 New Words |
| Today | 10 of 30 cards · Yesterday's ring closed · 14 cards · Yesterday: 9 of 12 cards | — |
| Today, deck rows | 4 new · 10 review · Next review tomorrow | — |
| Today, widget | ≈ 412 words in memory | 412 words in memory |
| Stream | Recalled | — |
| Mac stream | Space or ↩ | a keycap in Show Answer |
| Mac Today | Decks in “Mnemit” | Decks (sidebar) |
| Settings, iPhone | The reminder tells you how many cards are due in each deck. The number on the app icon is the total due today. | — |
| Onboarding, sync | Decks you create in Mnemit on the Mac appear here once they sync. | Decks in this folder appear here. |
| Card Detail, Options, table | Greek → translation · Translation → Greek | Word → Meaning · Meaning → Word |
| Mac Settings | Speak Greek automatically, its footer, Press ⌥⌘Q to do the opposite once. | Pronounce Automatically |
| Statistics | Reviewed Today | — |
| Progress, menus | How Today Works | How It Works |
| Options | four footers of 2–3 lines | one sentence each |
| Catalog | 21 keys no code uses | deleted |

## 7. Removals

| What | Evidence | Note |
|---|---|---|
| Typing mode (Mac): Study by, Continue automatically, the typed answer, the Previous bar, "alternatives separated by /" | 0 typed reviews of 251; the iPhone never had it | `mode` stays in the log format, so typed reviews of upstream decks still read |
| The damping of revealed reviews (Options, ADR 0004) | ADR 0005: the fork counts revealed reviews fully | ADR 0004 marked superseded |
| Retention by review mode | it splits typed from revealed | |
| Import MacVocTrain 1 Document (menu, `LegacyImport.swift`, `LegacyImporter`) | upstream's pre-release format | |
| The reopen-decks preference, the Today, Progress and How Today Works windows, `DeckOverviewView`, `WelcomeRequest` | one window, §5.13 | tag `pre-single-window` |
| The Practice section on deck screens | 0 practice reviews | the menus keep both streams |
| Shared Decks on AnkiWeb on deck screens | finding decks belongs to Today and New Deck | |
| 21 catalog keys | no reference in code | |

Kept on purpose: reading `.voctrain`, since `.backups` holds `Greek B1-20261021-181958.voctrain`.

## 8. Art direction

- Type: text styles only. The ring's numerals `.largeTitle` bold with monospaced digits; the headline `title3`
  semibold; nothing smaller than `footnote` but the week's initials (`caption2`).
- Colour roles as they are (indigo accent, red no, greens yes, orange streak, the indigo ladder); Hard's tint
  (§5.2); the flame's outline and fill (rule 2).
- Space: 24 pt between the hero's parts; lists keep the system insets.
- Mac: the toolbar and sidebar of macOS 26; no rows with chevrons drawn by hand.
- Symbols: the Mac's sidebar `rectangle.stack` for a deck, `pause.circle` for a paused one; iPhone rows stay
  without symbols.
- Motion as it is; the flame filling at the streak step reuses `RingBurst`.

## 9. Order of work

| Phase | Content | Size | Done when |
|---|---|---|---|
| 1. Truth | §4.1 counts; Settings footer; circular widget; deck titles without extension; the 21 keys; the onboarding line | small | Statistics, filters and Today agree on one deck; widget frames |
| 2. Today and the streak | hero, week, headlines, deck rows, minimised search, the flame's states in rings, header and widgets, Learn 10 New Words, the rests' titles | medium | Home and Study galleries, AX5, dark |
| 3. Text and leftovers | §6, §7 | medium | the catalog check in four languages; the Mac builds without typing |
| 4. Deck, card, adding | §5.4–5.9, introducing new words | medium | Browser and DeckEditing galleries |
| 5. The Mac's one window | §5.13 | large | the Mac gallery rebuilt for the shell; a live `vqa` pass |
| 6. Widgets and reminders | §5.12 | small | widget gallery; the 21:00 notification on the simulator |
| 7. Devices | `ios-renew --force`, `Scripts/install-mac.sh`, EF's list | — | HANDOFF updated |

Phases 1–4 change the iPhone and `Shared` and come first; phase 5 touches `MacVocTrainNg/` and the move of
`OpenDeck` into `Shared`.

## 10. Checks

- The snapshot galleries are the review surface of every phase. Each phase adds the frames it changes before the
  change, with the expected picture written first, and the frames missing today: the rests after their reveal,
  the Mac's plan end, the Mac shell's sidebar states, the inline widget.
- Mac: a live `vqa` pass over Today, a deck's Cards and Statistics, the stream by keys (← ↓ → ↑, Space, Z, ⌘.)
  and Settings, with a negative control (a broken key mapping has to fail it).
- iPhone 13 mini: HANDOFF Open 1, the hero at 375 pt, the minimised search, the flame's moment in the stream, the
  21:00 notification.
- Counts: one test per row of §4.1 that the screens agree on one deck.

## 11. Documents that change with the code

`screens.md`, `design-spec.md` (§2 Today, §6 Mac), `learning-flow.md` (its screens; the thin ladder under the
words on Today and "+N climbed today" on the rest are described there and were never built, so they leave the
text), `study-screen.md`, `GLOSSARY.md` (Learn 10 New Words, Word → Meaning, How It Works, New words / Words I
know), `HANDOFF.md`, the topics of `CLAUDE.md`.
