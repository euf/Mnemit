# Where sub-agents' tokens go

Measured on 22.10.2026 over the transcripts of the 77 sub-agents of one session (the Mnemit 1.4 → 3.2
work), each model call counted once by message id. Companion to `agent-lessons-rings.md`, which
covers one agent's wasted time; this covers the cost structure all agents share.

## Numbers

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

## What makes the context

1. **Baseline, ~76 k before any work:** the system prompt and tools, the global `CLAUDE.md`
   (~17 k tokens), `MEMORY.md` (~9 k), and this repository's `CLAUDE.md` (~27 k at the measurement, when it held the
   fork's details as 75 KB of dense Russian that every agent loaded whatever its task; now ~3 k).
2. **Whole files read to explore,** the largest growth: `cat` of `SessionDriver.swift`,
   `StartScreen.swift`, `StudyView.swift`, `DailyProgress.swift`, `Card.swift` plus neighbours,
   several per call, 20–30 k characters each, kept in context to the end.
3. **Long ranges and logs:** `sed -n 200,664p` of test files, full test output.
4. **Many calls:** about 90 per agent. Each exploratory read, small edit and single-test rerun is a
   call that re-reads everything before it.

## Rules for briefs (and what changed)

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
