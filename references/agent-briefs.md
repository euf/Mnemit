# Briefing sub-agents: costs and lessons

Two parts: the cost structure every sub-agent shares, and the review of one agent's run that lost most of its time. Each part ends in rules for
the brief.

## Part 1. Where sub-agents' tokens go

Measured on 22.10.2026 over the transcripts of the 77 sub-agents of one session (the Mnemit 1.4 → 3.2
work), each model call counted once by message id. This part covers the cost structure all agents share; Part 2 covers one agent's wasted time.

### Numbers

| | Value |
|---|---|
| Sub-agents | 77 |
| Model calls | 7,020, about 90 per agent |
| Context tokens processed | 1.87 billion, 24 M per agent on average, up to ~90 M |
| Context at an agent's first call | 76 k on average |
| Context at an agent's last call | 314 k on average, up to 607 k |
| Mean context per call | 228 k |
| Tool results over 6,000 characters | 960; `cat` of whole files 3.5 M characters, `sed -n` ranges 1.9 M, logs and other `cd …` commands 1.4 M |

Every call re-sends the whole context. An agent that reads a 25 k-character Swift file at call 10 pays
for it again at each of the 80 calls after, so the cost grows with calls × context, not with what
the agent produces (output tokens are under 1 % of the total).

### What makes the context

1. **Baseline, ~76 k before any work:** the system prompt and tools, the global `CLAUDE.md`
   (~17 k tokens), `MEMORY.md` (~9 k), and this repository's `CLAUDE.md` (~27 k at the measurement, with the
   fork's details as 75 KB of dense Russian that every agent loaded whatever its task; ~3 k as the short index it is now).
2. **Whole files read to explore,** the largest growth: `cat` of `SessionDriver.swift`,
   `StartScreen.swift`, `StudyView.swift`, `DailyProgress.swift`, `Card.swift` plus neighbours,
   several per call, 20–30 k characters each, kept in context to the end.
3. **Long ranges and logs:** `sed -n 200,664p` of test files, full test output.
4. **Many calls:** about 90 per agent. Each exploratory read, small edit and single-test rerun is a
   call that re-reads everything before it.

### Rules for briefs

- **Read narrowly.** `grep -n` for the symbol, then `sed -n a,bp` of at most ~80 lines around it;
  never `cat` a whole source file over ~200 lines, never several at once. Name the files and
  symbols in the brief so the agent doesn't have to look.
- **Keep logs out of context.** Test runs go to a log file; read only `grep -E "Test run with|error:|recorded an issue"`.
- **Batch the work.** Plan the edits, then apply them in few calls: one Python script that makes
  all edits of a file, not one Edit call per line.
- **Size the agent to the task.** A one-file change doesn't need its own agent: the 76 k baseline
  and the exploration cost more than doing it in the parent with known line numbers. Mechanical
  passes (terminology, docs) suit haiku.
- **Shrink the baseline.** This repository's `CLAUDE.md` is a short index; the details live in
  topic files under `references/`, and agents read the topic they work on.
- **Restart instead of growing.** An agent past ~250 k context with work left should write its
  state to a scratch file and report; a fresh agent continues from the file.

## Part 2. Run review: Fitness-style rings

Review of one coding-agent run (agent `afa0ca1d878f2a4ad`, worktree `agent-afa0ca1d878f2a4ad`,
branch `worktree-agent-afa0ca1d878f2a4ad`, 21-22.10.2026). Sources: its full transcript and
`git log -p d59b3ca..HEAD`. Times are UTC; the machine's clock is UTC+3.

### Numbers of the run

| | Stint 1 | Stint 2 | Whole run |
|---|---|---|---|
| Window | 20:50-21:33 | 23:05-00:14 | 20:50-00:14 (3 h 25 min wall) |
| Active time | 44 min | 69 min | 113 min |
| Tool calls | 216 | 122 | 338 |
| xcodebuild test runs | 17 | 19 | 36 (2 of them Mac) |

The figures in the task (about 70 minutes, 122 calls, 544k tokens) describe stint 2 only. A usage
limit stopped the agent at 21:33:46 ("[Request interrupted by user]"); the coordinator restarted it
at 23:05 with "nothing is committed yet". The 544k figure matches the agent's last context size
(540k). Context was 78k at the start, 240k at the first test run, 471k when the Wolf message
arrived. Over 260 turns that is about 90M cached-read tokens.

Final diff: 16 files, +819 / -143. Ring drawing and centre label: `ActivityRing.swift` 129 lines plus
`ProgressRing.swift` 118 lines, against a 35-line `ProgressRing.swift` before. New test code: 394
lines. Also 80 lines of strings, 63 changed lines in design-spec, 34 lines of notices.

### Timeline

| # | Window | Calls | What it did |
|---|---|---|---|
| 1 | 20:50-20:55 | 29 | Read the ring code, `CLAUDE.md`, design-spec; fetched sources of four repos (MKRingProgressView, HarshilShah/ActivityRings, DandyLyons and etaletovic ActivityRings). |
| 2 | 20:55-21:00 | 28 | Wrote everything in one pass: custom `RingGraphic` (gradient arc, two cap circles, masked head shadow), colours, `RingCenter`, `DailyRingView`, `StreamRing`, Mac chip, 80 lines of strings by script, `RingTests`, a gradient contrast test, a Mac snapshot test. |
| 3 | 21:00-21:12 | 138 | First compile and test loop: 12 xcodebuild runs, 38 Monitor calls, 11 PNG reads. Compile errors, contrast-test rewrites, five xcodebuild runs stacked on one derived-data path and killed (exit 143). |
| 4 | 21:12-21:23 | 13 | Mac suite and an iOS run at the same time. The iOS run died after a 683 s bootstrap; Mac PNG writes failed in the sandbox. One 9.4 min blocked wait. The rerun alone passed in 1 min. |
| 5 | 21:23-21:33 | 8 | First full iOS suite (10 min, hit the 590 s tool timeout): 7 issues in OpenDeck and PhoneEditing file-merge tests. Usage limit. |
| - | 21:33-23:05 | - | Dead time, not agent work. |
| 6 | 23:05-23:25 | 27 | Shrank its StudyView and TodayScreen edits (main had changed both), reran the file-merge suites alone (pass), reran the full suite twice, built a baseline copy with `git archive HEAD` and ran it. Concluded the failures were pre-existing. |
| 7 | 23:25-23:34 | 8 | The owner adds WolfActivityRing as a third reference; the agent reads it and adds an edge-case snapshot sheet. That xcodebuild blocked 6 min. The message "you're overengineering" arrived when it returned. |
| 8 | 23:34-23:41 | 40 | The port: licence check, `ActivityRing.swift`, swap into `ProgressRing`, delete `RingGraphic` and `dailyRingTrack`, three render-and-look iterations (47-97 s each), design-spec rewrite, notices. |
| 9 | 23:41-00:12 | 26 | Full suite fails again with 7 issues. Bisected with `-skip-testing`, found its own contrast test, rewrote it, loosened one flaky animation assertion, 118 of 118 green. 31 min, two of them 10 min blocks. |
| 10 | 00:12-00:14 | 21 | Mac suite (only the 6 known failures), copied Mac PNGs out of the sandbox container, lint, three commits, report. |

### Where the time went

**Waiting on xcodebuild.** 85 of 113 active minutes sit in gaps of more than 45 s between tool
calls (one of them, 3.9 min at 20:51, is the agent's own design reasoning). Five gaps are 9.4-9.9
min each (21:12, 21:23, 23:12, 23:46, 23:57), together 49 min or 43 % of the run. The test runs
inside the last four lasted 52-59 s; in the first one the tests never started. The same ring-only
command took 47-97 s on a quiet machine (23:35-23:40) and 6.3 min at 23:27. Four tool calls hit the
590 s timeout.

**Polling.** 100 of 260 tool-bearing turns were poll-only (38 Monitor calls, `tail` and `grep` on
logs, `ps`, `pgrep`). They re-read 36M of the 93M context tokens. Twenty-one of the Monitors were
`sleep N; echo done` timers; at 21:10 the agent misread them as returning at once and polled more.
Three used `pgrep -f "derivedDataPath build/DD-rings "`, which matches the monitor's own command
line, so they never ended (found at 21:11).

**The file-merge failures (about 61 min, 54 % of the run: 10.5 + 20 + 31).** `OpenDeckTests` and
`PhoneEditingTests` (`aStudySessionGoesOnWhenTheFileChanges`,
`anEditAndTheOtherDevicesChangeAreMerged`, ...) time out after 23-30 s, only in the full suite. The
agent first read them as flakiness under load (they pass alone, 23:08), then as pre-existing because
the baseline copy also showed `aCardReviewedAfterItsDeletionOnTheOtherDeviceStays` failing (23:25).
The counts differed: baseline 1 issue, with its tests 7. The bisect at 23:43-23:57 settled it: skip
`RingSnapshotTests` still 7, skip that and `AccentContrastTests` 1. The cause was the window-based
contrast test (eight windows, `makeKeyAndVisible`, 400 ms sleep each) starving the file-presenter
tests while the suites run in parallel. Rewritten to four windows it went green. The starvation is
the agent's hypothesis; the skip-bisect and the rewrite are the evidence.

**The contrast test (8 min and 8 xcodebuild runs in stint 1, 21:01-21:10, plus the 31 min above).**
The tail colour is `Color.accentColor.mix(with: .white, by: 0.25)`; the test needed 3:1 on four
surfaces in four appearances. The agent concluded that `UIColor(Color.accentColor)` resolves to
system blue outside a view, so the test renders swatches in a hosting window and reads pixels.
Failures on the way: `colorSchemeContrast` is get-only (compile error); a Python slice duplicated
half the file (`git checkout`); the first swatch reads returned the window background (150 ms wait,
8x8 window); then 40x40; then 96x96, where the safe area moved the swatch off the sampled point;
the final version scans for the swatch's bounding box. Result: 85 lines in `AccentContrastTests`.

**Mac sandbox.** `RingSnapshotMacTests` failed with "You don’t have permission to save" (4 of the 10
Mac issues; the other 6 are the known ones). The PNGs land in
`~/Library/Containers/com.euf.mnemit/Data/tmp`.

**Custom drawing built and deleted.** `RingGraphic` (about 90 lines: arc layers, cap circles, masked
head shadow with tangent offset) plus `dailyRingTrack(isDark:)` and the tail-lightening constants,
tuned over 20:57-21:23 (tail tint 0.13 to 0.25, shadow strength, track opacity). Deleted at 23:35.
`ActivityRing.swift` took its place with more lines (129, about 20 of them licence header). The
port was only partly "as is": at 160 % Wolf's stretched gradient washed out, so the agent added a
closed tip-coloured first lap under the overlay arc (the two-layer structure of its own design),
made the view `Animatable` and limited the shadow to progress above 1.

**Reading sources.** About 5 min and 29 calls in phase 1, four repos for a brief that named two.
The brief was wrong about one: it described HarshilShah/ActivityRings as SwiftUI with an
`AngularGradient`; the agent's note at 20:50 says the repo "is actually built with SpriteKit", so it
went looking for a SwiftUI repo that fits the description. Tool-result text over the whole run is
376k characters plus 25 PNGs, so reading was a minor cost.

**Loaded machine.** The evidence is indirect; the agent never ran `uptime`, and its own process
counts (21 at 21:08, 9 at 00:11) include its wrapper shells. Run 2 logged "683.784 elapsed --
Testing started completed" and then "Early unexpected exit, operation never finished
bootstrapping", with the agent's own Mac suite building next to it. At 20:59 the coordinator wrote
that someone else had launched the Fitness app in the live-check simulator, so other sessions
were using simulators. The same commands ran in 47-97 s (ring-only) and 1-2 min (full suite: 23:41,
00:09, 00:11) when nothing else got in the way.

### What in the brief invited the complexity

| Brief text | Effect |
|---|---|
| "drawn the way these two libraries draw them" and "reimplement the technique in our own code" | Two sources of different kinds (a Core Graphics layer, and SpriteKit described as SwiftUI) merged into one own design. A provenance section with links, written at 21:02-21:04 and rewritten at 23:40. |
| "Apple Fitness quality", "so the overlap reads like Fitness", "iterate until they look like Fitness rings" | Open-ended and no reference image. The real Fitness app was off limits, so the agent judged from memory. Shadow strength, tail tint, track opacity and line width were tuned across several runs. |
| "dark mode and high-contrast variants must keep the existing AccentContrastTests passing, and update them if the ring colour becomes a gradient" | A new 3:1-on-four-surfaces test for a computed gradient end, which forced window rendering and pixel sampling. That test caused the 6 extra failures. |
| "Snapshot PNGs of the rings at 0, 0.4, 1.0, 1.6 and 2.3 progress, light and dark, in the three sizes" plus "Open the PNGs with Read" | Five iOS sheets and two Mac sheets, each its own window with a 400 ms wait, copying the pattern of `StudyScreenSnapshotTests`. 25 PNG reads. With the simulator off limits, the only visual feedback was a full xcodebuild per look. |
| The two full-suite commands and "6 known Mac failures being fixed elsewhere; add no new ones" | Full suites at 1-10 min per run. The known-failure list covered Mac only; the iOS file-merge failures had to be triaged with a baseline the agent built itself. |
| Centre label, "days" caption, Dynamic Type, VoiceOver, German strings and widget API stability, all in one task | Real scope, bundled with the drawing: `RingCenter` enum, plural keys, `speaksCenter`, `merge-xcstrings`, `check-localizations`. The drawing itself was a small part. |
| No budget, stop rule or definition of done; nothing about machine load; nothing saying unrelated failures are out of scope | Nothing told the agent to stop chasing the file-merge failures or to cap fix runs. |
| Mid-run messages: a Fitness-launch accusation (20:59, not the agent), the third reference (23:25), "you're overengineering" (23:33) | The owner had a preferred library by 23:25. The custom drawing, written at 20:57, was discarded at 23:35. |

### Cheapest path in hindsight

1. Brief: port WolfActivityRing into `Shared/Support/ActivityRing.swift` and keep its header (the
   repo has no LICENSE file; the permission notice sits in the source file; add the
   `THIRD_PARTY_NOTICES.md` and Credits entries the repo's `CLAUDE.md` requires). Measured cost of
   this step in the run: 7 min, 40 calls, three runs of about a minute (phase 8).
2. Wire it into `DailyRingView`, `StreamRing` and the Mac chip (about 20 lines) and add the
   `RingCenter` label with its strings. One pure unit test for the label text, no windows.
3. One snapshot test per appearance (one window holding a row of the five fractions), run with
   `-only-testing`. A Mac snapshot only when the sandbox path is known.
4. Check the tail colour by arithmetic on `UIColor(named:)` with traits, or leave
   `AccentContrastTests` as it was. No pixel scan.
5. Start the full iOS suite on the base commit in the background first and keep its issue count;
   run the full suite once at the end.
6. Design-spec: five lines, written last.

Estimate: 35-50 calls, 4-6 xcodebuild runs, 25-30 min on a quiet machine and about 45 min on a
loaded one, against 338 calls and 113 min. Only step 1 is measured.

### Lessons for briefs

1. Name one source and one deliverable ("port this file as is, keep its notice") and check the
   source before sending: URL description, language, licence. Attach a reference image for any
   "looks like X" target, because the agent cannot open X.
2. Give a scope cap and a stop rule: files touched, test lines, three render iterations, and "if a
   test needs more than three fix runs, drop it and report".
3. Hand over a baseline for every scheme: the known failing and flaky tests, or an instruction to
   run the full suite on the base commit first, in the background, and to compare issue counts.
   Call a failure pre-existing only when the base commit shows the same count; a pass in isolation
   proves nothing.
4. Fix the inner loop: `-only-testing` for the new tests, the full suite once at the end, one
   xcodebuild or simulator run at a time. Record the pid at launch and kill only that pid; never
   `pkill -f` or `pgrep -f` with a pattern that also appears in the agent's own command.
5. Say that the Mac is shared and loaded: the same command took 47 s to 11 min. Run it once in
   the background with output to a log and wait for the one completion notice; no poll loops and
   no `sleep` monitors (100 poll-only turns re-read 36M context tokens). When a run takes three
   times its quiet-machine time, check load (`uptime`, other xcodebuild and Simulator processes)
   and report instead of retrying.
6. Treat window-based tests as expensive and contagious: use the fewest windows (eight produced 6
   extra failures in the file-merge tests, four did not), and run the full suite right after
   adding the first such test.
   Prefer arithmetic checks over pixel sampling.
7. Require a commit after each green step and write provenance notes and docs last. The agent kept
   3.4 h (wall time) of work uncommitted through a usage-limit stop and two redirects, and wrote
   the design-spec section twice.
8. Put repo traps in the brief or the repo docs: the sandboxed Mac test host cannot write to the
   worktree (PNGs land in `~/Library/Containers/com.euf.mnemit/Data/tmp`), and redirect targets
   such as `build/` must exist first. Split drawing, centre label with strings, and tests into
   separate agents when they do not depend on each other.

## Part 3. Parallel fix agents

What carried the audit of 30.10.2026 (`audit-2026-10-30.md`): fifteen fixing agents in five waves, each in its own worktree.

- **One package per agent, files disjoint.** A package names its findings by section of the audit's files and the files it
  may touch; whatever lies in another package's files goes into the report, not into an edit.
- **One xcodebuild at a time:** agents call `Scripts/xcb.sh <log> <xcodebuild args>`, which waits for a lock and prints
  only the summary lines. Without it parallel runs time each other out and fight over the simulator.
- **The String Catalog is written once.** Every agent appends its strings to a TSV (key, en, de, ru, el, the key it
  replaces); the coordinator applies them in one pass that keeps the catalog's key order. Edits of the catalog by
  several branches conflict on every merge.
- **Merging:** `VERSION` conflicts on every merge (each worktree's commits bump it): take main's. Two packages can each
  compile and still break together (a local `day` shadowing a new property of the same type) and parallel tests can race
  on a global (`NewCardAllowances.today` with another test's day): run the full suites on main after each wave.
- **Budget:** an agent wraps up at about 120 calls; it writes its state and next steps to a file, and a fresh agent in a
  fresh worktree from main continues from it.
