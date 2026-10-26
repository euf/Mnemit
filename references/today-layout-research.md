# Today layout: ring against streak (Apple Fitness, Duolingo, habit apps)

Researched 2026-10-27. Tags: [V] verified, read on the page. [S] secondary: blog, teardown, forum, or my memory (marked "memory").
Not found: pixel sizes of any ring, StandBy and inline Fitness widgets, Duolingo widget size families. Pages for those were gated or silent.

## 1. Apple Fitness (iPhone Summary, Watch, widgets)

- Summary is one dashboard: the Activity summary shows today's rings and opens a history view; workouts, trends and the top three awards sit under it. [V] https://www.macstories.net/stories/the-new-fitness-app-in-ios-14/ (iOS 14, layout kept since). Ring card is first on screen [S: memory, matches the section order there].
- Numbers: HIG lets an app show current and goal values per ring, as labels in the ring's colour. [V] https://developer.apple.com/design/human-interface-guidelines/activity-rings. On the Watch, the Activity app opens on the three rings; totals come after turning the Digital Crown. [V] https://support.apple.com/guide/watch/track-daily-activity-apd3bf6d85a6/watchos. On the iPhone card the values sit beside the rings [S: memory].
- Overlap: an overlapping ring means the goal was exceeded; tapping the rings opens that day's detail and a date picker. [V] https://support.apple.com/guide/iphone/see-your-activity-summary-iph4c34a8a95/ios
- Streak: no streak counter appears in any page read. Streaks live in Awards: awards cover personal records, streaks and milestones. [V] Watch page above. Summary shows three awards (MacStories). The "Move streak" number is hidden in Awards [S: memory; a Reddit thread asks how to see it, https://www.reddit.com/r/AppleWatch/comments/byw32o/question_how_do_you_see_move_streak_and_is_there/, unread, 429].
- Pause and rest: Pause Rings for up to 90 days keeps the award streak; goals can differ per weekday. [V] https://support.apple.com/guide/iphone/adjust-your-activity-ring-goals-iph9a08e004e/ios and https://support.apple.com/guide/iphone/get-started-with-fitness-ipha5dddb411/ios. There is no rest-day tile.
- iOS 26: new Workout tab; Summary keeps a Sessions card. [V] https://lifehacker.com/health/ios-26-gives-the-iphone-a-real-fitness-app. No source describes a streak on Summary.
- Time to close: watchOS 26 Workout Buddy speaks it. Apple's example: "18 minutes away from closing your Exercise ring". [V] https://www.apple.com/newsroom/2025/06/watchos-26-delivers-more-personalized-ways-to-stay-active-and-connected. It is a spoken line, not a label on the ring.
- HIG rules a Mnemit ring must respect: Activity rings carry only Move/Exercise/Stand; other ring-like elements need padding, lines, labels or colour to stay distinct. [V] HIG link above.
- Widgets: Fitness has five (two Activity, two Workout, one Training Load). Small Activity = the three rings; medium adds the size and timing of activity. [S] https://www.slashgear.com/2042594/iphone-widgets-more-useful-than-you-think. Lock Screen (iOS 16): circular = rings; rectangular = Move, Exercise, Stand figures and distance to goal. [V] https://www.macrumors.com/how-to/display-activity-rings-iphone-lock-screen/ (square vs rectangle also at makeuseof, [S]). No Fitness widget shows a streak.

## 2. Duolingo (home, states, widget, experiments)

- Home body is the learning path; the Quests tab (chest icon) holds Quests. [V] https://blog.duolingo.com/new-duolingo-home-screen-design/ (2022). Top bar of home: flame with the streak [V] https://blog.duolingo.com/how-streaks-keep-duolingo-learners-committed-to-their-language-goals/ (2017), heart [V] 2022 page; gems [S: memory].
- The flame opens a menu: Streak Challenge sits in it. [V] https://blog.duolingo.com/tips-for-maintaining-streak/. The daily XP goal is not on the home body; it is edited under Profile settings. [S] https://www.hardreset.info/devices/apps/apps-duolingo/edit-daily-goal/. Older apps used "Edit goal" via the flame. [S] https://duolingo.fandom.com/wiki/Daily_Goal
- Hierarchy on home: path (rank 1), flame count in the bar (small, always there), goal progress absent. The flame is large only on the post-lesson streak screen: full-screen flame, counter ticks up. [S] https://duolingo.deconstructoroffun.com/mechanics/streaks
- States: grey flame and number before the day's lesson, burst to orange on the first lesson. [S] https://60fps.design/shots/duolingo-2-day-streak-animation. Calendar: blue days = freeze, bright orange = perfect week. [S] https://www.reddit.com/r/duolingo/comments/185as2y/what_do_the_different_colors_mean/. Perfect Streak (no freeze used) = yellow halo on the flame, weekly bar turns continuous. [S] deconstructoroffun page. Freezes apply silently; free cap two. [S] same page. The frozen flame colour in the top bar: not verified.
- Widget (2023 post, designers' own words): after tests they kept only two facts, the streak length and whether today's lesson is done; no stats, no goal progress. Duo's mood changes through the day. Widget users retain better even after controlling for commitment. [V] https://blog.duolingo.com/widget-feature/. Home and iOS Lock Screen exist [S] https://duolingo.fandom.com/wiki/Streak. Size families: not verified.
- Streak split (Nov 2020): before, the streak needed the daily goal; "intense" goal users were least likely to hold a streak (almost 40% of learners active two days running without a streak had that goal). Split = one lesson keeps the streak, goal progress shown apart. A/B: day-14 retention +3.3%, daily actives +1%, learners on a streak +10.5% in 20 days (+19% new learners), all relative; fewer learners reached the goal. A year later over half of daily learners had a 7+ day streak, up from about a third. [V] https://blog.duolingo.com/improving-the-streak/. Same page: streak of 7 = 2.4x likelier to return next day.
- Freeze and amulet: two equipped freezes raised daily actives +0.38% (relative). [V] https://blog.duolingo.com/how-duolingo-streak-builds-habit/. Weekend Amulet (2017): +4% back a week later, 5% fewer lost streaks. [V] 2017 page. Milestone screen: Mnemit's notes already cite day-7 retention +1.7% (ring-design.md).

## 3. Other apps, one line each

- Headspace: run streak counts meditation sessions; screen placement not verified. Its own article says the streak is not about the number. [V] https://help.headspace.com/hc/en-us/articles/215730567-How-does-the-run-streak-feature-work and https://www.headspace.com/articles/building-a-meditation-practice
- Calm: streak sits in the Dashboard (upper right), not in the Home body. [V] https://support.calm.com/hc/en-us/articles/115002473827-How-to-View-Your-Meditation-Stats-History-and-Streak-in-Calm
- Streaks: one streak per task, widgets show tasks, streaks and charts; ring around each task icon [S: memory]. [V] https://streaks.app/
- Finch: Home = pet plus Daily Goals list; streak info is on the pet's profile; any open of the app counts; Pause Mode freezes it. [V] https://help.finchcare.com/hc/en-us/articles/37780000231309-Exploring-the-Finch-Home-Page and .../37780736136205-Understanding-Streaks
- Brilliant: count on the home page; 3 problems or one concept extends it; iOS widget shows streak status plus prompts. [V] https://brilliant.org/help/features/what-is-a-streak/
- Speak: streak on Home, Profile calendar, post-first-lesson screen; icons for active, not yet extended, not yet extended with 2 hours left. [V] https://help.speak.com/en/articles/11645358-streak-101-how-streaks-work-how-to-keep-them
- Babbel: flame with count top right; two free freezes a week; one medium widget with streak and reminder. [V] https://support.babbel.com/hc/en-us/articles/17020978582162-Streak and .../36299516418962-Babbel-widget
- Busuu: blue flame with count; streak shield. [V] https://help.busuu.com/hc/en-us/articles/16497935071633-What-s-a-streak
- None of the apps read pairs a daily ring with a streak on one surface. Possible exception: Streaks (ring per task plus streak, memory, unverified).

## 4. Synthesis

| App | Rank 1 | Rank 2 | Streak shown as | Minutes / what's next | Widgets |
|---|---|---|---|---|---|
| Apple Fitness | Activity rings card | workouts, trends, 3 awards | no counter; award streak in Awards | none on screen; Workout Buddy says minutes to close | rings (small, circular); stats (medium, rectangular); no streak |
| Duolingo | learning path | flame count in top bar; Quests tab | flame + number, grey/orange/blue/halo states | the path's next circle; no minutes | streak count + done-today, Duo mood; no goal |
| Brilliant | content | streak count on home | count on home | prompts in widget | streak status + prompts |
| Babbel | content | flame + count top right | flame + count | reminder in widget | medium: streak + reminder |
| Speak | lessons | streak on Home | icon with 3 risk states, "2 hours left" | time left to lose streak | not read |
| Calm | Daily Calm content | Dashboard link | Dashboard only | none | not read |
| Finch | pet + goals list | streak in pet profile | profile entry | goals list | not read |
| Mnemit today | ring, large, no number | sentence with flame, days, minutes | flame + days inside the sentence | the sentence ("≈ 2 min ...") | ring + sentence; lock ring + minutes; inline flame + days + minutes (product-model.md) |

Pattern: each surface elects one hero. Apple's widgets elect the ring, Duolingo's widget elects the flame; neither shows both at equal weight. Minutes-to-next exists as copy (Workout Buddy, Speak's "2 hours left", Mnemit's sentence), never as a ring label.

## 5. Three layouts for Mnemit (options and evidence, no pick)

Already true in Mnemit: the streak is decoupled from the ring (first 120 s keep it; ring-design.md, "The streak step"), which is the Duolingo split.

A. Ring and flame side by side as equals.
- For: two mechanics with two thresholds (the split argues they are different things); HIG allows labelled values next to a ring.
- Against: no surveyed app weights both equally; Apple omits the streak from the ring card; Duolingo keeps the flame small on home.

B. Ring primary; flame, days and minutes as one compact line under it (today's layout).
- For: Apple Fitness (ring is the hero, streak is off the first screen); Duolingo's flame as a small constant element; time-to-close as a short line (Apple's Workout Buddy copy); Calm and Finch keep the streak off the home body (Dashboard, pet profile).
- Against: Duolingo's data says the streak is the strongest retention lever (2.4x next-day, widget users retain better); here the flame is the smallest thing on screen.

C. Flame primary; ring small.
- For: Duolingo widget (flame + done-today only), Brilliant, Babbel, Busuu and Speak lead with streak and carry no ring; after the split fewer learners hit the goal, so the goal element mattered less; a lower bar mattered more than volume early on.
- Against: none of those apps shows a ring at all, so no app tests "small ring"; Duolingo's home hero is still the path, not the flame, and the large flame appears only after a lesson and in the widget.

Surface split seen in the sources: dashboard (Apple Summary, Duolingo home) = content or ring first, flame small; glance surfaces (Duolingo widget, Brilliant, Babbel) = flame first, one fact; Apple's glance surface = ring first.
