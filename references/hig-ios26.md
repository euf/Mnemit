# HIG and iOS 26 / macOS 26 rules for a Mnemit summary screen

Read 2026-10-27. Bases: HIG = https://developer.apple.com/design/human-interface-guidelines/ . DOC = https://developer.apple.com/documentation/ . W219, W256, W278, W323, W356 = https://developer.apple.com/videos/play/wwdc2025/<number>/ (transcripts; 256 is "What's new in SwiftUI").
Tags: [verified] = text read on that Apple page or transcript (pages read through Apple's page-data JSON, same text as the web page). [secondary] = blog, observation of shipped apps, or memory.
Caveat 1: live HIG pages carry 2026 edits (Layout 9 Sep 2026; Scroll views, Sidebars, Tab bars, Search 8 Jun 2026). I used only text that also matches the WWDC25 sessions or is generic. Caveat 2: HIG has no "Navigation bars" or "Inspectors" page now. Nav-bar text moved into HIG/toolbars; inspector text is in HIG/panels, HIG/split-views, DOC/swiftui/view/inspector(ispresented:content:). WWDC25 "Elevate the design of your iPad app" (208) adds no rule for iPhone or Mac.

## 1. Liquid Glass: which layer, which API

| Rule (Do / Don't) | SwiftUI | Source |
|---|---|---|
| Do: glass is the functional layer for controls and navigation floating above content. Don't: glass on cards, list rows, tiles, figures, ring card; use standard materials or solid colours. Only exception: transient knobs of sliders and toggles. [verified] | none; leave content views plain | HIG/materials; W219 ("making [a table view] Liquid Glass would make it compete") |
| Don't stack glass on glass; things on top of glass use fills, transparency, vibrancy. [verified] | no `.glassEffect` inside a glass control | W219 |
| Do: custom glass only on the few most important functional elements, applied to the control itself, not its inner views. Several glass views go in one container (glass cannot sample other glass). Limit how many show at once. [verified] | `.glassEffect(.regular.interactive(), in: .capsule)`; `GlassEffectContainer(spacing:)` | DOC/swiftui/applying-liquid-glass-to-custom-views; W356; W323 |
| Do: regular variant. Don't: clear variant on a text-and-ring screen. Clear needs media-rich backgrounds, a dimming layer (about 35% dark if bright) and bold content above. [verified] | `.glassEffect(.regular)` (default) | HIG/materials; W219 |
| Do: tint only the primary action, colour on the glass background, not on the label. Don't tint several controls. [verified] | `.tint(.indigo)` with `.buttonStyle(.glassProminent)`; in a toolbar `.buttonStyle(.borderedProminent)` | HIG/color#Liquid-Glass-color; W219; W256 |
| Do: standard button styles instead of hand-made glass; 1 to 2 prominent buttons per view; hit region at least 44x44 pt; capsule is the iOS 26 default shape; extra-large size for the most prominent action. [verified] | `.buttonStyle(.glass)`, `.glassProminent`, `.controlSize(.extraLarge)`, `.buttonBorderShape(.capsule)` | HIG/buttons; W323 |
| Do: scroll edge effect under floating bars; not a solid or semi-opaque bar background. One per view, only when a scroll view sits behind floating UI, not decorative. Soft is default on iOS; hard mostly macOS and pinned headers. Don't mix or stack styles. [verified] | `.scrollEdgeEffectStyle(.soft, for: .bottom)`, `.scrollEdgeEffectHidden(_:for:)` | HIG/scroll-views; HIG/layout; W356; DOC/swiftui/scrolledgeeffectstyle |
| Do: custom bottom bar over a scroll view as a safe-area bar (insets the safe area and extends the edge effect). Don't: ZStack overlay with your own material or gradient. At rest, no content under the glass (reposition or inset). [verified] | `.safeAreaBar(edge: .bottom) { ... }`; `.contentMargins(.bottom, _, for: .scrollContent)` | DOC/swiftui/view/safeareabar(edge:alignment:spacing:content:)-9hwgb; W219 |
| Do: `backgroundExtensionEffect` only on one hero image that must run under a sidebar or inspector; it mirrors and blurs, clips, one use per screen. Don't: on cards or the ring. [verified] | `.backgroundExtensionEffect()` | DOC/swiftui/view/backgroundextensioneffect(); HIG/sidebars |
| Bottom primary action, iPhone, preferred: a bottom toolbar. "Study" is its own capsule (text label, tinted); search is a separate item (symbol); fixed space between. Search at the bottom when there is room (Mail, Notes); with other items it collapses to a button. Don't: put a screen-specific action in the tab-bar accessory (W356 checkout example). [verified] | `ToolbarItem(placement: .bottomBar)`; `ToolbarSpacer(.fixed, placement: .bottomBar)`; `DefaultToolbarItem(kind: .search, placement: .bottomBar)`; `.searchable`; `.searchToolbarBehavior(.minimize)` | HIG/search-fields; HIG/toolbars#Item-groupings; W323; W356; DOC/swiftui/defaulttoolbaritem |
| Floating custom button only if the toolbar cannot do it (for example a full-width Study): glass prominent, extra large, in the safe-area bar. Don't hand-draw a blurred capsule. [secondary: my reading of the docs above] | `.safeAreaBar` + `.buttonStyle(.glassProminent)` | as above |

## 2. Titles and toolbars

| Rule | SwiftUI | Source |
|---|---|---|
| Do: large title on the root screen; it shrinks to inline on scroll. Title under 15 characters; never the app name. [verified] | `.navigationTitle("Today")`, `.navigationBarTitleDisplayMode(.large)` | HIG/toolbars#Titles, #iOS |
| Do: date as subtitle. iOS shows it with the title in the bar; UIKit's large-title subtitle is drawn below the large title; macOS shows it in the title bar. Don't build a custom date header. [verified; SwiftUI-to-UIKit mapping secondary] | `.navigationSubtitle(Text(date, format: .dateTime.weekday(.wide).day().month()))` | DOC/swiftui/view/navigationsubtitle(_:); DOC/uikit/uinavigationitem/largesubtitle |
| Don't: custom bar backgrounds, borders, tinted controls. Hierarchy comes from layout and grouping. Use content to inform bar colour. [verified] | no `.toolbarBackground` fills; `.toolbarBackgroundVisibility` only if needed | HIG/toolbars; DOC/technologyoverviews/adopting-liquid-glass; W356 |
| Do: group items in glass capsules by function and frequency; at most 3 groups; keep text buttons apart from symbol buttons; primary action separate, tinted, trailing. One symbol per group; text only when no clear symbol. [verified] | `ToolbarItemGroup`, `ToolbarSpacer(.fixed/.flexible)`, `.sharedBackgroundVisibility(.hidden)` | HIG/toolbars; W323; W356 |
| Do: icons monochrome by default; an accessibility label on every icon; hide a whole toolbar item, not its inner view (empty capsule otherwise). [verified] | `Label(_, systemImage:)`, `.accessibilityLabel`; condition inside the toolbar builder | DOC/technologyoverviews/adopting-liquid-glass; W323 |

## 3. Content: lists, cards, corners, charts

| Rule | SwiftUI | Source |
|---|---|---|
| Do: text rows (decks with minutes) in a grouped list; iOS 26 rows are taller, sections have bigger radii, headers use title-style capitalisation (no all caps). [verified] | `List` + `Section("Decks")` + `.listStyle(.insetGrouped)`; `LabeledContent` | HIG/lists-and-tables; adopting-liquid-glass |
| Do: cards and tiles as solid platters: grouped colours, secondary for grouping inside the primary background. Fitness and Health do the same, glass only in bars [secondary: no Apple page states it; learnui.design/blog/ios-design-guidelines-templates.html says lists stay plain]. | `Color(.systemGroupedBackground)` behind, `Color(.secondarySystemGroupedBackground)` as card fill | HIG/color#iOS-iPadOS |
| Don't: box inside box; group with padding, alignment, negative space, or separators. [verified] | plain `VStack` + `Divider` inside one card | HIG/boxes; HIG/layout#Visual-hierarchy |
| Do: nested corners concentric: inner radius = outer radius minus padding. Don't hard-code 12/16/20 per card. Container sets the shape, children use `ConcentricRectangle`; minimum radius where the corner is far from the container. [verified] | `.containerShape(RoundedRectangle(cornerRadius: 24))`; `.background(fill, in: .rect(corners: .concentric(minimum: 12), isUniform: true))` | W356; DOC/swiftui/concentricrectangle; DOC/swiftui/shape/rect(corners:isuniform:) |
| Do: full-bleed background under bars and sidebars. [verified] | `.background(Color(.systemGroupedBackground))` on the scroll view | HIG/layout |
| Do: stats as tiles in a grid; at accessibility sizes stack to one column. Charts: a label per mark or group, critical numbers never behind interaction, shape or pattern besides colour. [verified] | `LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))])`; Swift Charts `.accessibilityLabel` | HIG/typography#Supporting-Dynamic-Type; HIG/charts |
| Section headers (custom cards): left-aligned, title case, one style on all screens; a tappable header is a `NavigationLink` with the system chevron. [secondary: judgement from Fitness and Health look] | `Text("Decks").font(.title3.bold())` | none |

## 4. Typography and colour for figures

- Text styles on iOS: Large Title 34, Title 1 28, Title 2 22, Title 3 20, Headline 17 semibold, Body 17, Callout 16, Subhead 15, Footnote 13, Caption 1 12, Caption 2 11. Minimum 11 pt. Avoid Ultralight, Thin, Light. [verified, HIG/typography]
- Do: figures in text-style fonts (`.font(.title.bold())`) so Dynamic Type scales them. Don't: `.system(size:)` without `@ScaledMetric`. Ring and flame icon scale too: `@ScaledMetric(relativeTo: .title) var ring = 96`. [verified, HIG/typography#Supporting-Dynamic-Type]
- Do: at large sizes restack (ring over figures), keep primary items on top, minimise truncation, do not scale every label (tab titles stay). `ViewThatFits`, `AnyLayout`, `@Environment(\.dynamicTypeSize)`. [verified, same page]
- macOS has no Dynamic Type. Fixed text styles: Large Title 26, Title 1 22, Title 2 17, Title 3 15, Headline 13 bold, Body 13, Callout 12, Subheadline 11, Footnote 10, Caption 10; minimum 10 pt. [verified, same page]
- SF Pro Rounded: HIG offers it "to coordinate text with the appearance of soft or rounded UI elements" and says to minimise typefaces. Pick one: all figure numerals rounded, nothing else (`.fontDesign(.rounded)`). Fitness uses rounded numerals [secondary, observation]. `.monospacedDigit()` for values that tick (minutes, countdown) so width stays put [verified, DOC/swiftui/font/monospaceddigit()]; `.contentTransition(.numericText())` [secondary].
- Colour is never the only signal: figure text, lap count as a number, flame glyph, checkmark for goal reached; read `@Environment(\.accessibilityDifferentiateWithoutColor)`. [verified, HIG/color#Inclusive-color; HIG/accessibility]
- Contrast: 4.5:1 for text up to 17 pt, 3:1 at 18 pt or bold. Custom colours need light, dark and Increase Contrast variants (asset catalog); prefer system colours (`Color.indigo`), never hard-code system RGB. Test Reduce Transparency, Increase Contrast, Reduce Motion with any glass. [verified, HIG/accessibility; HIG/color; adopting-liquid-glass]

## 5. Activity rings: how a ring-like element stays distinct (HIG/activity-rings, all [verified])

- Rules for Apple's rings: three rings only for Move, Exercise, Stand; never replicate or modify them; never show Move, Exercise, Stand progress in another ring-like element; black background; fixed colours Move RGB 250,17,79, Exercise 166,255,0, Stand 0,255,246; not in the app icon or marketing.
- "Differentiate other ring-like elements from Activity rings ... use padding, lines, or labels ... Color and scale can also help."
- Mnemit: one ring, indigo, no red, green, cyan or concentric trio; no black disc; a text label with unit beside it ("min", "words") so it is not read as Exercise minutes; do not place it beside HealthKit rings. Week row and calendar rings get the day number as text.
- Don't mirror a widget's look inside the app with non-interactive cards (HIG/widgets#Best-practices); keep the in-app ring a ring.

## 6. Widgets in iOS 26 (HIG/widgets; W278; DOC/widgetkit)

- Modes: full colour; accented (tinted or clear Home Screen on iOS 26, macOS Tahoe desktop and Notification Center, visionOS themes); vibrant (Lock Screen, StandBy night). Accented removes the background and puts glass (clear) or a tint behind. [verified]
- In accented mode the system treats views as template images: colour is ignored, only alpha counts; two groups (accent, primary) both white on iPhone and Mac; gradients and transparent content keep opacity and turn white. [verified, DOC/swiftui/view/widgetaccentable(_:); DOC/widgetkit/optimizing-your-widget-for-accented-rendering-mode-and-liquid-glass]
- Therefore the ring track and fill must differ by alpha and width, not hue (track about 0.25, fill 1.0); laps above 100% need a number ("2x") or a head cap; ring and figure `.widgetAccentable()`, rest primary. Full-colour art only when `widgetRenderingMode == .fullColor`; images `.widgetAccentedRenderingMode(.desaturated)`; `.fullColor` only for media artwork. [verified, W278]
- Background goes in `.containerBackground(for: .widget) { ... }` so the system can remove it; `showsWidgetContainerBackground` to detect; `containerBackgroundRemovable(false)` drops the widget from StandBy and the iPad Lock Screen. [verified, DOC/widgetkit/displaying-the-right-widget-background]
- Margins 16 pt (11 tight), text 11 pt or larger, system font and SF Symbols, Dynamic Type Large to AX5, corners from `ContainerRelativeShape`, no colour-only meaning, no rasterised text. Vibrant: opaque greys, not white opacities; Always On: `isLuminanceReduced`. [verified, HIG/widgets]
- Mac: iPhone widgets on a Mac desktop keep iOS font metrics, native Mac widgets use macOS metrics, check both. [verified, DOC/widgetkit/preparing-widgets-for-additional-contexts-and-appearances] HIG table lists Mac accented as unsupported while W278 says clear and tinted apply on macOS Tahoe: test on the Mac.

## 7. macOS 26 (HIG/sidebars, HIG/windows, HIG/toolbars, HIG/layout, HIG/designing-for-macos, W356, W323)

- Sidebar is inset glass, content flows behind; toolbar items are glass groups; title and subtitle sit in the title bar, no large title. Use `NavigationSplitView`, no custom sidebar background; at most two levels; do not hide the sidebar by default. [verified]
- Don't put critical actions or info at the bottom of a window or sidebar (windows get moved off-screen). So no bottom Study bar on the Mac: toolbar primary action, or a button in the page. Every toolbar item also exists as a menu command. [verified]
- Prominent action: HIG says trailing side, one only; DOC for `.primaryAction` says leading edge on macOS. Conflict, test both. [verified, not resolved]
- Search at the toolbar's trailing side (`.searchable`). Controls: Mini, Small, Medium keep rounded rectangles, Large is capsule, X-Large exists (`.controlSize(.extraLarge)` for Study in content). [verified]
- Summary in a window: wide canvas, more content in fewer levels; two columns (ring and figures left, decks right) with `ViewThatFits` or `Grid`; keep a readable max width; set window min and max size; hard scroll edge style under pinned headers. [verified: designing-for-macos, windows; column layout is my reading]
- Inspector: trailing column for details of the current selection, becomes a sheet when compact; toolbar button on the trailing edge. `.inspector(isPresented:)`, `InspectorCommands`. Fits card details, not Statistics navigation. [verified, DOC; fit is my reading]

## 8. For Mnemit's Today, Progress, deck and Statistics screens

1. Content on solid grouped fills; no `.glassEffect` on ring card, rows, tiles, medals. [verified, HIG/materials]
2. Glass only in bars and the Study and search controls; one prominent tinted control per screen. [verified, W219]
3. iPhone Today: large title "Today", `navigationSubtitle` for the date, no custom header. [verified, HIG/toolbars; DOC]
4. Study: `ToolbarItem(.bottomBar)` prominent, `ToolbarSpacer(.fixed)`, `DefaultToolbarItem(kind: .search)`; not in a tab accessory. [verified, HIG/search-fields; W323; W356]
5. Any custom bottom bar: `safeAreaBar(edge: .bottom)`; content never rests under it. [verified, DOC; W219]
6. Decks with minutes: `List` insetGrouped; no nested cards; stats tiles in an adaptive grid. [verified, HIG/lists-and-tables; HIG/boxes]
7. Card corners via `containerShape` + concentric rectangle, not fixed radii. [verified, W356; DOC]
8. All text on text styles; ring and icons on `@ScaledMetric`; restack at AX sizes; rounded numerals all or none; `monospacedDigit` on ticking values. [verified, HIG/typography; rounded choice secondary]
9. Colour never alone: numbers for laps, glyphs for streak and goal; 4.5:1 text contrast; Increase Contrast variants for indigo. [verified, HIG/accessibility]
10. Ring stays one indigo ring with a unit label; no Move, Exercise, Stand colours or triple rings. [verified, HIG/activity-rings]
11. Widget: alpha-based ring, `widgetAccentable`, `containerBackground(for: .widget)`, 16 pt margins, text at least 11 pt; check clear and tinted on iPhone and Mac. [verified, HIG/widgets; DOC/widgetkit]
12. Mac: sidebar plus toolbar, title and subtitle in the title bar, Study in toolbar, nothing critical at the window bottom, two-column Today. [verified, HIG/windows; HIG/sidebars; column layout secondary]
13. Medals: solid badge art. Apple's Landmarks sample puts glass on badges for morphing, which conflicts with rule 1; skip unless a morph is wanted. [verified, DOC/swiftui/landmarks-building-an-app-with-liquid-glass; decision mine]
14. `UIDesignRequiresCompatibility` in Info.plist opts out of the new look; not a plan. [verified, adopting-liquid-glass]
