# Deck formats and deck sources for Mnemit

Research note of 2026-10-21. Question: which import/export formats and which ready-made deck sources Mnemit should support. Native format: package `X.mnemit` (`deck.json` + append-only `reviews.jsonl`), synced as files through iCloud Drive. Greek A2–B1 learner, Mac and iPhone.

Every URL below was opened on 2026-10-21 unless the line says otherwise. Source dates are the date printed on the source, the release or commit date, or "undated".

Confidence markers:

- [H] stated in a primary source opened for this note.
- [S] secondary source: blog, vendor page, forum post, third-party README.
- [I] my inference from the cited sources.
- [U] not verified.

Existing code that bears on this: CSV/TSV read and write already exist (`Packages/VocabCore/Sources/VocabCore/Exchange/DelimitedText.swift`, `CardImporter.swift`; question, answer, optional hint columns). `Import/LegacyImporter.swift` reads MacVocTrain 1 files. A `reviews.jsonl` line carries `card` (UUID), `date` (Int), `grade`, optional `mode` (`ReviewLogEncoder.swift`).

## 1. Anki packages (.apkg, .colpkg)

### 1.1 Archive layouts

An `.apkg` or `.colpkg` is a ZIP. Three layouts exist; the `meta` entry (protobuf `PackageMetadata`, one field `version`) tells them apart [H]: https://github.com/ankitects/anki/blob/main/proto/anki/import_export.proto (last commit 2025-07-07), https://github.com/ankitects/anki/blob/main/rslib/src/import_export/package/meta.rs (main; last change to the file 2023-06-12).

| Layout | Collection entry | DB schema | `meta` | Media map entry `media` | Compression |
|---|---|---|---|---|---|
| Legacy 1 | `collection.anki2` | 11 | absent | JSON object, index to filename | zip deflate |
| Legacy 2 | `collection.anki21` (+ dummy `collection.anki2`) | 11 | protobuf, version 2 | JSON object | zip deflate |
| Latest | `collection.anki21b` (+ dummy `collection.anki2`) | 18 | protobuf, version 3 | protobuf `MediaEntries` (name, size, sha1) | zstd on the DB, the media map and each media file |

- Reader rule in rslib: no `meta` and `collection.anki21` present means Legacy 2; no `meta` and no `anki21` means Legacy 1; `meta` version unknown means "too new" error [H]: meta.rs above.
- The legacy media map is a JSON hash with gaps possible; the latest map is a repeated `MediaEntry {name, size, sha1}` and the zip entry name is the position index [H]: https://github.com/ankitects/anki/blob/main/rslib/src/import_export/package/media.rs and import_export.proto.
- Media files are numbered entries `0`, `1`, … at the archive root; no subdirectories [S]: https://eikowagenknecht.com/posts/understanding-the-anki-apkg-format (2025-07-03, updated 2025-07-09).
- Legacy 2 and Latest packages both carry a dummy `collection.anki2` holding one placeholder note that asks for a newer Anki. A reader that falls back to `collection.anki2` reads that placeholder as the deck [S]: same Eiko post; https://github.com/ImGajeed76/ankipack/blob/main/docs/explanation/apkg-format.md (applies to Anki 26.08; repo pushed 2026-09-08).
- An empty media set still needs a `media` entry holding a valid zstd frame of an empty `MediaEntries`; a zero-length entry makes Anki's import fail [S]: ankipack doc above.
- A package holds at most 65,532 media files (zip 16-bit entry count) [S]: ankipack doc above.
- Apple's Compression framework lists Brotli, LZ4, LZ4_RAW, LZBITMAP, LZFSE, LZMA, LZMESH, LZRAVEN and ZLIB; zstd is absent, so reading Latest needs a zstd decoder dependency [H]: https://developer.apple.com/tutorials/data/documentation/compression/compression_algorithm.json (live JSON, 2026-10-21).

### 1.2 Which Anki version introduced what

| Fact | Version, date | Source |
|---|---|---|
| Collection export (.colpkg) in the new format, option to target 2.1.50+ with faster IO and compressed media; backups unreadable by older Anki | 2.1.50, 2022-04-09 | https://github.com/ankitects/anki/releases/tag/2.1.50 [H] |
| New apkg import/export code (undo, faster, optional drop of older-client support), behind a feature flag, off by default | 2.1.52, 2022-05-13 | https://github.com/ankitects/anki/releases/tag/2.1.52 [H] |
| New import/export code is the default | 2.1.55, 2022-12-16 | https://github.com/ankitects/anki/releases/tag/2.1.55 [H] |
| `.apkg` exports default to the new format; `.apkg` import can merge changed note types and can skip scheduling | 23.10, 2023-10-31 | https://github.com/ankitects/anki/releases/tag/23.10 [H] |
| Text-file headers (`#separator`, `#html`, …) | 2.1.54+ | https://docs.ankiweb.net/importing/text-files.html (undated; the page says 2.1.54+) [H] |
| Current release | 26.09.3, 2026-09-23 | https://github.com/ankitects/anki/releases [H] |

- Legacy 1 came with Anki 2.0 (2012); Legacy 2 with Anki 2.1 (2018) [S]: Eiko post above. The 2.1.x point release that first wrote `collection.anki21` was not pinned down [U].
- Old shared decks on AnkiWeb are still Legacy 1 files [S]: Eiko post above.

### 1.3 The "support older versions" export

- The current manual still lists "Support older Anki versions (slower/larger files)" for both `.colpkg` and `.apkg` export. Checked means a legacy file readable by older clients; unchecked means the modern file, faster, with compressed media, unreadable by older Anki [H]: https://docs.ankiweb.net/exporting.html (undated, Mintlify-hosted manual).
- In code the option is `ExportAnkiPackageOptions.legacy`, and `legacy` selects `Meta::new_legacy()`, which is Legacy 2 (`collection.anki21`, schema 11, JSON config) [H]: import_export.proto, meta.rs, https://github.com/ankitects/anki/blob/main/rslib/src/import_export/package/apkg/export.rs.
- Anki 26.09 removed the Python `anki.importing` and `anki.exporting` modules; the Rust importer and exporter remain [H]: https://github.com/ankitects/anki/releases/tag/26.09 (2026-09-14).
- Exporting "Notes in Plain Text" writes tab-separated fields with HTML embedded and carries no scheduling [H]: https://docs.ankiweb.net/exporting.html.
- Scheduling and review history are written only when "Include scheduling information" is on; when off, Anki treats the deck as shared content and strips scheduling, and the `.colpkg` always carries scheduling [H]: same manual page.

### 1.4 Tables a reader needs (schema 11 and 18 share them)

The schema-14, 15, 17 and 18 upgrade scripts create or change `deck_config`, `config`, `tags`, `fields`, `templates`, `notetypes`, `decks` and `graves`; none of them touches `notes`, `cards` or `revlog` [H for the scripts, I for the conclusion]: https://github.com/ankitects/anki/tree/main/rslib/src/storage/upgrades. Schema 11 definition: https://github.com/ankitects/anki/blob/main/rslib/src/storage/schema11.sql.

- `notes`: `id, guid, mid, mod, usn, tags, flds, sfld, csum, flags, data`. Fields are in `flds`, separated by the `0x1f` unit-separator character [H for the columns; the separator is [U] here, standard knowledge].
- `cards`: `id, nid, did, ord, mod, usn, type, queue, due, ivl, factor, reps, lapses, left, odue, odid, flags, data`. `due` for review cards is days since the collection's creation (`col.crt`); for learning cards epoch seconds; for new cards a position. `type` 0 new, 1 learning, 2 review, 3 relearning; `queue` -3, -2 buried, -1 suspended [S, read from the AnkiDroid wiki]: https://github.com/ankidroid/Anki-Android/wiki/Database-Structure (undated wiki, mentions FSRS so edited after 2023).
- `revlog`: `id, cid, usn, ease, ivl, lastIvl, factor, time, type` [H]: schema11.sql. Semantics from rslib `RevlogEntry` [H]: https://github.com/ankitects/anki/blob/main/rslib/src/revlog/mod.rs
  - `id` is the review timestamp in epoch milliseconds; `cid` the card id.
  - `ease` is the button pressed, 1 to 4 (0 for manual rescheduling).
  - `ivl` and `lastIvl`: positive means days, negative means seconds.
  - `factor` is the ease in permille; with FSRS on it holds the difficulty normalised to 100–1100 (0 stays distinguishable from SM-2 learning).
  - `time` is the answer time in milliseconds.
  - `type`: 0 Learning, 1 Review, 2 Relearning, 3 Filtered (cram/early), 4 Manual, 5 Rescheduled.
- Entries to skip when replaying a history: `type` 4 with `factor` 0 is a reset; `type` 3 with `factor` 0 is cramming with rescheduling off; `has_rating()` is `ease > 0` [H]: revlog/mod.rs.
- In schema 18 the deck configs, note types, decks and tags sit in separate tables with protobuf BLOB columns; in schema 11 they are JSON on the single `col` row [H]: schema11.sql, upgrade scripts; [S]: ankipack doc.

### 1.5 Where FSRS state lives

- Per-card memory state is in the JSON text column `cards.data`: `s` stability (rounded to 4 places), `d` difficulty (3), `dr` desired retention override (2), `decay` (3), `lrt` last review time (epoch seconds), `pos` original new-card position, `cd` custom-data string. The memory state exists only when both `s` and `d` are present [H]: https://github.com/ankitects/anki/blob/main/rslib/src/storage/card/data.rs
- FSRS parameters are not on the card. They sit in the deck config protobuf (`deck_config.config`): `fsrs_params_4`, `fsrs_params_5`, `fsrs_params_6` (repeated float), `desired_retention`, `historical_retention` [H]: https://github.com/ankitects/anki/blob/main/proto/anki/deck_config.proto
- Keys and meaning are not documented in the manual; the source above is the specification [I].
- Where a preset sits in each schema (read 22.10.2026, rslib and proto at `main`; Anki main depends on fsrs-rs 6.6.2) [H]:
  - Schema 11: `col.dconf` is a JSON object, preset id to config. The FSRS keys are `fsrsWeights` (the FSRS-4.5 list, `fsrs_params_4`), `fsrsParams5`, `fsrsParams6` and `desiredRetention`; a deck's `conf` names its preset. https://github.com/ankitects/anki/blob/main/rslib/src/deckconfig/schema11.rs (`DeckConfSchema11`).
  - Schema 18: table `deck_config(id, name, mtime_secs, usn, config)`, `config` a `DeckConfig.Config` message with `fsrs_params_4 = 3`, `fsrs_params_5 = 5`, `fsrs_params_6 = 6` (`repeated float`, packed) and `desired_retention = 37` (`float`). A deck's `decks.kind` is a `Deck.KindContainer`: field 1 is the normal deck, whose field 1 is `config_id`. https://github.com/ankitects/anki/blob/main/proto/anki/deck_config.proto and decks.proto.
  - Which list Anki uses: the first non-empty of `fsrs_params_6`, `_5`, `_4`. https://github.com/ankitects/anki/blob/main/rslib/src/deckconfig/mod.rs (`DeckConfig::fsrs_params`).
  - Older sets are filled up when read, in `check_and_fill_parameters_fsrs6` (fsrs-rs 6.6.2, `src/model.rs` `check_and_fill_parameters`; `src/model_v6.rs` on main): 19 values get `[0.0, 0.5]` appended (w19 and the FSRS-5 fixed decay as w20); 17 values (FSRS-4.5) become `w4 = w4 + 2 * w5`, `w5 = ln(3 * w5 + 1) / 3`, `w6 = w6 + 0.5`, then `[0.0, 0.0, 0.0, 0.5]` appended; any other length except 0 (defaults) and 21 is an error. `FSRS::new` then clips every value into its range (`clip_parameters` in `parameter_clipper.rs`), the ranges `FSRSParameters.ranges` copies except one: v6.6.2 passes `enable_short_term` false, so w19 keeps its 0 there (main passes true: floor 0.01), while Mnemit's floor is 0.01 and a deck file with w19 = 0 is refused. A 17 or 19 set therefore gets w19 = 0.01 in Mnemit: a factor S^-0.01 on the stability after a same-day review, no more [I]. https://github.com/open-spaced-repetition/fsrs-rs/blob/v6.6.2/src/model.rs
  - A deck can override the preset's retention (`Deck.Normal.desired_retention`, schema 11 `desiredRetention` in the deck as a whole percent) and a card its own (`dr` in `cards.data`); Mnemit reads neither.

### 1.6 Importing history into another FSRS scheduler

- The revlog holds what FSRS replay needs: a timestamp, the rating 1–4, the card id, and the review type [H]: revlog/mod.rs.
- FSRS Rust crate: optimiser input is `FSRSItem { reviews: [FSRSReview { rating, delta_t }] }`; `memory_state(item, starting_state)` recomputes a memory state from a history; `memory_state_from_sm2(ease, interval, retention)` seeds a state from SM-2 data. Repo pushed 2026-10-09, BSD-3-Clause [H]: https://github.com/open-spaced-repetition/fsrs-rs (README; the repo mentions FSRS-6 and FSRS-7 selected by parameter count).
- py-fsrs: `Optimizer(review_logs)`, `Scheduler.reschedule_card(card, review_logs)` rebuilds a card from its logs; results differ slightly from Anki's for the same logs because implementations and versions differ. MIT, pushed 2026-08-09 [H]: https://github.com/open-spaced-repetition/py-fsrs
- A replay under Mnemit's own parameters gives states unequal to Anki's stored `s` and `d`; Anki's stored values correspond to the deck's own FSRS version and parameter set [I].
- A real-world check that this is practical: awesome-fsrs lists several apps (Avorio, Discito, Loudwalk, StudyDaily, Revu and others) that describe `.apkg`/`.colpkg` import with scheduling state or review history. These are vendor self-descriptions [S]: https://github.com/open-spaced-repetition/awesome-fsrs (CC0, pushed 2026-10-21).
- Mochi imports `.apkg` with review history [H]: https://mochi.cards/docs/import-and-export/importing/. RemNote imports Anki flashcards with review history [H]: https://help.remnote.com/en/articles/6330674-notes-on-remnote-importers (dated 2026-09-14).
- Mapping to Mnemit [I]: one revlog row with `ease > 0` and `type` in 0, 1, 2, 3 (with `factor` > 0) becomes one `reviews.jsonl` line: card UUID from the imported card, `date` from `id`, `grade` from `ease` (1 Again, 2 Hard, 3 Good, 4 Easy for the v3 scheduler; learning cards of the old v1 scheduler used 1–3), `mode` `revealed`. Anki card to note to `Card.note`/`kind` needs a rule for reverse cards (`cards.ord`).

### 1.7 Libraries and the minimal read subset

| Library | Role | Latest activity, licence | Notes |
|---|---|---|---|
| `ankitects/anki` rslib | reference reader and writer | pushed 2026-10-21, AGPL-3.0-or-later | Crate `anki` has `publish = false`; the 0.0.1 on crates.io is a 2019 placeholder. Embedding it in an iOS app makes the app AGPL [H]: https://github.com/ankitects/anki (README License section), https://github.com/ankitects/anki/blob/main/rslib/Cargo.toml, https://crates.io/crates/anki |
| `kerrickstaley/genanki` (Python) | write only | last release 0.13.1 (2023-11-12), last commit 2024-12-30, MIT | Writes `collection.anki2` at schema 11 plus a JSON `media` map; cannot load or modify a package; stable GUIDs needed so a re-import updates notes [H]: https://github.com/kerrickstaley/genanki (README, `package.py`), issue https://github.com/kerrickstaley/genanki/issues/66 |
| `ImGajeed76/ankipack` (TypeScript) | read, write, edit | pushed 2026-09-08, MIT, 5 stars | Schema 18 writer verified against Anki 26.08.1; reads all three layouts and converts schema 11; deps `fflate`, `fzstd`, `@bufbuild/protobuf`, `sql.js`; keeps review history and scheduling on edit [S]: https://github.com/ImGajeed76/ankipack |
| `clejacquet/ApkgIOSwift` (Swift) | read | last commit 2025-04-02, MIT, 6 stars | Reads Legacy 1, 2 and Latest since 2025-02-05; Package.swift depends on ZIPFoundation, SQLite.swift, `facebook/zstd` (libzstd), swift-protobuf; README calls it very basic and not for serious use [S]: https://github.com/clejacquet/ApkgIOSwift |
| `tamakondayo/AnkiLite` (Swift app) | read, write | pushed 2026-08-11, MIT | iOS app with `.apkg` import and export; reads `collection.anki21` and `collection.anki2` through GRDB and ZIPFoundation; no `anki21b` mention in its README [S]: https://github.com/tamakondayo/AnkiLite |
| `74Genesis/anki-apkg-parser` (Node) | read | pushed 2026-10-15, MIT | Parser for notes, cards, media, models [S]: https://github.com/74Genesis/anki-apkg-parser |
| `5mdld/anki-apkg-extractor` (Python) | read | pushed 2026-07-10, MIT | Handles 21b with optional `zstandard` and `protobuf` [S]: https://github.com/5mdld/anki-apkg-extractor |
| `eikowagenknecht/srs-converter` (TypeScript) | convert between SRS formats | pushed 2026-10-19, MIT, alpha | Anki `.apkg`/`.colpkg` to a universal format; names Mnemosyne, SuperMemo and Mochi as targets; its README warns of data loss [S]: https://github.com/eikowagenknecht/srs-converter |
| `FooSoft/anki-connect` | HTTP API of a running desktop Anki | GitHub repo archived; moved to https://git.sr.ht/~foosoft/anki-connect | Needs Anki desktop running; no use on iPhone [H]: https://github.com/FooSoft/anki-connect |
| `flimzy/anki` (Go) | read `.apkg` | last push 2020-07-04 | Predates the Latest layout [S]: https://github.com/flimzy/anki |

Minimal read recipe for Latest [I from the sources above]:

1. Open the ZIP (ZIPFoundation or equivalent).
2. Read `meta`; decode one varint field; version 3 means Latest, 2 means Legacy 2, absent means Legacy 1 or Legacy 2 by which collection entry exists.
3. Decompress the collection entry with zstd when Latest; write it to a temp file.
4. Open it with SQLite (system `libsqlite3` is enough; only `notes`, `cards`, `revlog`, and for names `decks` and `notetypes`/`fields` or the `col` JSON).
5. Split `notes.flds` on `0x1f`; map fields to question and answer by the note type's field order.
6. For media, decompress `media` (zstd) and decode `MediaEntries` (three fields; hand-written protobuf varint reader is enough), then decompress entry `N` for each entry.
7. Ignore `collection.anki2` when `meta` says 2 or 3.

Rendering of note-type templates (`{{Front}}`, cloze, CSS, JS) is a separate, larger problem; Mochi converts HTML to Markdown and drops CSS and JS on import [H]: https://mochi.cards/docs/import-and-export/importing/.

Writing: the least work is a Legacy 1 package, which is what genanki writes: `collection.anki2` at schema 11 (JSON config), a JSON `media` map, numbered media files, no `meta`, no zstd, no protobuf [H]: genanki `package.py`. Current rslib still reads a package without `meta` as Legacy 1 or 2 [H]: meta.rs. ankipack's author says Legacy 1 is the layout every client imports [S, search snippet; the thread needs JavaScript]: https://forums.ankiweb.net/t/ankipack-typescript-library-for-creating-reading-and-editing-apkg-files/70771 [U]. A Legacy 2 file additionally needs the one-field `meta` entry [I].

## 2. Other flashcard formats

| App or format | Import | Export | Detail and source |
|---|---|---|---|
| Anki text (TSV/CSV) | plain text, UTF-8; separator guessed or set by `#separator`; `#html`, `#tags`, `#columns`, `#notetype`, `#deck`, `#guid column` and similar headers | "Notes in Plain Text": tab-separated, HTML embedded, no scheduling | https://docs.ankiweb.net/importing/text-files.html [H]; header keys: `separator` (Comma, Semicolon, Tab, Space, Pipe, Colon), `html`, `tags`, `columns`, `notetype`, `deck`, `notetype column`, `deck column`, `tags column`, `guid column`; quotes escape separators and newlines; first non-comment line fixes the column count; first field decides duplicates unless a GUID column is used |
| Quizlet | paste text: term/definition separated by comma, tab or dash; rows by semicolon or newline | text only: the Export dialog arranges terms and definitions, "Copy text"; no images; sets copied from another user cannot be exported; website only | https://help.quizlet.com/hc/en-us/articles/360029977151-Creating-sets-by-importing-content (undated) [H]; https://help.quizlet.com/hc/en-us/articles/360034345672-Exporting-your-sets (undated) [H] |
| Mochi `.mochi` | `.mochi`, Anki `.apkg` (with review history), Markdown (one card per file, or one file split by a delimiter), CSV | `.mochi`, Markdown ZIP, CSV (field values, or pre-rendered Front/Back) | https://mochi.cards/docs/import-and-export/importing/ and /exporting/ (undated) [H] |
| Brainscape | upload `.csv`, `.txt`, `.xlsx`, `.ods`; paste | export of a deck to a file for Excel, Pro users only | https://brainscape.zendesk.com/hc/en-us/articles/115002369931 (2026-09-24) and https://brainscape.zendesk.com/hc/en-us/articles/115002383872 (2026-10-02) [H]; "CSV only" per third parties [S]: https://2anki.net/convert/brainscape-to-anki/ |
| RemNote | Anki `.apkg` with review history, CSV/TSV/XLSX (as tables), Markdown, Obsidian, Notion, Quizlet, Roam/Logseq, others | RemNote native, OPML, Anki `.apkg` (flashcards only, parent structure kept), HTML, Markdown, text | https://help.remnote.com/en/articles/6330674-notes-on-remnote-importers (2026-09-14), https://help.remnote.com/en/articles/7898019-exporting-and-printing-notes (updated about 2026-10) [H]; the source list of importers is from the search snippet of https://help.remnote.com/en/articles/7898005-importing-notes [S] |
| Mnemosyne | Anki 2 collections (`.anki2`, import only), tab-separated text, Mnemosyne `.cards`, `.db`, SuperMemo 7 text, others | `.cards`, tab-separated text | Source of the importers: https://github.com/mnemosyne-proj/mnemosyne/tree/master/mnemosyne/libmnemosyne/file_formats (repo pushed 2026-04-18) [H]. `.cards` is a ZIP of `cards.xml` (a log-entry XML), `METADATA` and media: https://github.com/mnemosyne-proj/mnemosyne/blob/master/mnemosyne/libmnemosyne/file_formats/mnemosyne2_cards.py [H] |
| SuperMemo (desktop, Windows) | XML (File > Import) and text via Excel-to-XML; Anki moved in through exported text and Excel | XML (File > Export > XML), carries the learning process | https://www.super-memory.com/archive/help16/faq/xml.htm (Q&A from 2002–2004) [H]; Anki-to-SuperMemo walk-through https://masterhowtolearn.wordpress.com/2018/10/28/how-i-moved-my-anki-collection-with-over-50000-cards-to-supermemo/ (2018-10-28) [S] |
| SuperMemo.com (web) | paste text with chosen separators, 2016 | export was only "planned" in 2015 | https://www.supermemo.com/en/blog/how-to-import-your-questions-and-answers-to-supermemo (2016-02-09), https://www.supermemo.com/en/blog/call-for-requests-import-and-export-in-supermemo (2015-12-04) [H]; current state [U] |
| Memrise | none documented | no course export; a personal-data download exists; third-party extensions export community courses; community courses left the main app on 2024-03-31 for a separate community site | https://memrise.zendesk.com/hc/en-us/articles/360015806377 [S, search snippet]; https://polidict.com/en/blog/memrise-import (updated 2026-10-20) [S] |
| Obsidian Spaced Repetition plugin | cards are Markdown in notes | none; the notes are the data | https://github.com/st3v3nmw/obsidian-spaced-repetition (MIT, 2590 stars, pushed 2026-10-05, release 1.15.4 on 2026-06-14) [H] |

Details worth keeping:

- Obsidian SR card syntax: `Question::Answer` single line; `Question:::Answer` reversed; multi-line separated by `?` and `??`; cloze as `==text==`, `**text**` or `{{text}}`; deck from `#flashcards/<subdeck>` tags. After a review the plugin appends an HTML comment with the due date, interval and ease, for example `<!--SR:!2021-08-20,13,290-->`; it uses FSRS or SM-2 [H]: https://stephenmwangi.com/obsidian-spaced-repetition/flashcards/q-and-a-cards/ and the repo README.
- `.mochi` is a ZIP with `data.edn` or `data.json` (JSON recommended for large sets) plus media. Top-level map: `:version` 2, `:decks`, `:cards`, `:templates`. Card: required `:content`; optional `:id`, `:name`, `:deck-id`. Deck: `:name`, optional `:id`, `:parent-id`, `:cards`. The format reference documents it for hand-made files; review history is included in exports [H]: https://mochi.cards/docs/import-and-export/mochi-format-reference/ (undated).
- Mochi also has a REST API with per-account API keys (HTTP Basic), JSON or transit+json, one concurrent request per account, 429 on bursts [H]: https://mochi.cards/docs/api/ (undated).
- Quizlet ToS (last updated May 28, 2026) forbids scraping and other automated extraction of the service or its content [H]: https://quizlet.com/tos.

Which are realistic interchange formats in 2026 [I from the table]:

1. Anki `.apkg`/`.colpkg`: every app above that exports structured data targets it (RemNote export, Mochi import, Mnemosyne import, srs-converter, the FSRS apps in awesome-fsrs). Only this format carries review history that other schedulers import.
2. CSV/TSV: every app imports it; Anki text headers make it self-describing; scheduling is not carried. Mochi's CSV export is aimed at Anki compatibility [H]: https://mochi.cards/docs/import-and-export/exporting/.
3. `.mochi`: documented, open (ZIP + JSON), carries review history; one app uses it.
4. Markdown with a card syntax (Obsidian SR): plain text, diff-friendly, no shared standard across apps.
5. Not realistic: Quizlet (text paste only, no API, ToS bans scraping), Memrise (no export), SuperMemo XML and Mnemosyne `.cards` (niche, legacy), Brainscape (CSV, Pro export).

## 3. Sources of ready-made decks

### 3.1 AnkiWeb shared decks

- No public API for shared decks was found. The AnkiWeb terms allow access through a browser and through the sync of the approved clients, and state that other clients and browser extensions are not currently allowed; they point to AnkiConnect for programmatic use on the local collection [H]: terms text embedded in the page's JS bundle (the page is client-rendered, so `oc` cannot read it): https://ankiweb.net/account/terms, node chunk `/_app/immutable/nodes/12.*.mjs` (undated).
- `robots.txt` disallows `/shared/decks/`, `/shared/download` and `/shared/downloadDeck` for all agents [H]: https://ankiweb.net/robots.txt (fetched 2026-10-21).
- Shared Deck License (same terms page): downloading grants a permanent personal-study licence; the deck may not be redistributed, re-uploaded or published, or used for other purposes without the copyright holder's permission. Decks with very few downloads are removed after 3 months [H]: https://ankiweb.net/account/terms.
- A 2024 forum thread asks for a dump of all shared decks; the only replies advise against bulk download [S]: https://forums.ankiweb.net/t/how-to-download-all-shared-decks-or-search-for-a-specific-term-tag-in-all-shared-decks/39232 (2024-01-05 to 2024-06-16).
- Third-party scrapers exist (https://github.com/pjf/anki-deck-scraper) [S]; they conflict with the robots rule above [I].
- Sanctioned path: the user finds and downloads a deck in the browser, then opens the `.apkg` in Mnemit. Whether the download button needs a login was not verified [U].

### 3.2 Quizlet

- Quizlet support told a developer in 2020 that the API is no longer supported for commercial or personal use and no new keys are issued [S]: Stack Overflow answer quoting the support reply, https://stackoverflow.com/questions/60425101/quizlet-api-not-available (2020-03-22).
- As of 2026-08-18 no self-service public API or developer portal is documented; the only supported routes are the one-time text export of one's own set, embeds and partner integrations [S, vendor-written]: https://flashcards-open-source-app.com/blog/quizlet-api/ (author builds a competing product).
- Quizlet ToS (May 28, 2026) forbids scraping [H]: https://quizlet.com/tos. `quizlet.com/robots.txt` returned a captcha page [H].

### 3.3 Mochi

- No public directory of community decks was found. A user can publish a deck as a read-only link (requires Mochi Pro); viewers can browse and clone it inside Mochi [H]: https://mochi.cards/docs/decks/sharing (undated). Exports travel as `.mochi` files.
- The REST API is per-account (API key from the app settings), so it reads the caller's own decks only [H]: https://mochi.cards/docs/api/. A public-deck endpoint was not seen in the docs [U].

### 3.4 Tatoeba

- Sentences are CC BY 2.0 FR with attribution of the author; a part is also CC0 1.0. Many English and Japanese sentences come from the public-domain Tanaka Corpus [H]: https://tatoeba.org/en/downloads and https://tatoeba.org/en/terms_of_use (undated).
- Weekly exports, updated Saturdays 06:30 UTC, at `https://downloads.tatoeba.org/exports/`: per-language files (for Greek `per_language/ell/ell_sentences.tsv.bz2`, 521 KB, and `ell_sentences_detailed.tsv.bz2`, 814 KB, both last modified 2026-10-17), links, `sentences_base`. Fields: `id TAB lang TAB text` (detailed adds username, added, modified) [H]: downloads page; sizes from HTTP HEAD on 2026-10-21.
- Custom export "Sentence pairs": all sentences in language A translated into language B, with the translations, generated on demand on the downloads page [H]: https://tatoeba.org/en/downloads.
- Read-only public API, no authentication: stable `/v1/sentences` and `/v1/sentences/{id}`, `/v1/audios/{id}/file`; `/unstable/*` endpoints may change. `sort` is a required parameter; filters include `lang`, `trans:lang`, `owner`, `is_orphan`, `is_unapproved`, `is_native`, `has_audio`, `tag`, `list`, `license`; `showtrans:lang` returns translations inline; cursor paging [H]: https://api.tatoeba.org/openapi.json, https://api.tatoeba.org/ and live calls on 2026-10-21.
- Greek (`ell`) counts: about 43,072 sentences on the stats page; `ell_sentences.tsv` has 42,878 lines (export of 2026-10-17); 40,616 Greek sentences with an English translation (API `paging.total`); 30,591 with a Russian translation; 40,120 with an English translation excluding unapproved and orphan sentences; 26,663 marked native with an English translation; 15,392 of the English-translated ones are owned by one user [H]: https://tatoeba.org/en/stats/sentences_by_language, API calls `GET /v1/sentences?lang=ell&trans:lang=eng&sort=random&limit=1` and variants, 2026-10-21. `has_audio=yes` returned 0 with this parameter spelling, so audio coverage for Greek is [U].
- `robots.txt` sets `Crawl-delay: 8` and disallows `/sentences/*` pages, so page scraping is excluded; downloads and the API are the intended routes [H]: https://tatoeba.org/robots.txt.
- Content quality: the Greek sample returned contains many short everyday sentences ("Tom" examples among them) [H, sample of 2]; level labelling (A2/B1) does not exist in the data [I].

### 3.5 Kaikki.org and Wiktextract

- Licence: the extracted data is under the same licences as Wiktionary, CC BY-SA and GFDL [H]: https://kaikki.org/dictionary/ and https://kaikki.org/ruwiktionary/ ("Copyright and license" sections, undated); https://en.wiktionary.org/wiki/Wiktionary:Copyrights is the cited reference. The extraction code (Wiktextract) is MIT; its test files follow the Wiktionary licence [H]: https://github.com/tatuylonen/wiktextract (LICENSE). Share-alike applies to a deck built from the entries [I].
- Download today: per-language post-processed JSONL on each language page (Greek: `https://kaikki.org/dictionary/Greek/kaikki.org-dictionary-Greek.jsonl`, 209.9 MB, extracted 2026-10-03 from the enwiktionary dump of 2026-09-02; file size from HTTP HEAD, the file was not downloaded). The Greek page marks this link DEPRECATED. The Wiktextract issue states the link is to be removed, will not be replaced by anything, and that users should take the complete raw dump and filter each line by `lang_code` (`el`) [H]: https://kaikki.org/dictionary/Greek/index.html, https://github.com/tatuylonen/wiktextract/issues/1178 (opened 2025-05-09, still open on 2026-10-21; the thread includes users objecting).
- The raw dump (English edition): JSONL, 23.9 GB, or 2.8 GB gzipped, extracted from the enwiktionary dump dated 2026-09-02, updated about weekly [H]: https://kaikki.org/dictionary/rawdata.html. Filtering Greek out of it means streaming a multi-gigabyte file once [I].
- "Greek" on the English edition is Modern Greek; "Ancient Greek" is a separate language with 90,475 senses against 112,952 for Greek [H]: https://kaikki.org/dictionary/ (language list).
- Counts on the English-edition Greek page: 81,903 distinct words (inflected forms included); senses by part of speech: Noun 58,012, Adjective 29,644, Verb 17,312, Proper name 3,880, Adverb 1,459, Pronoun 463, Interjection 307, Numeral 292, Phrase 230, Article 36 [H]: https://kaikki.org/dictionary/Greek/index.html.
- Live Wiktionary category counts (MediaWiki API, 2026-10-21): Greek lemmas 32,885; Greek non-lemma forms 50,745; nouns 16,696; verbs 4,923; adjectives 6,266; masculine nouns 4,819; feminine 8,582; neuter 5,908; terms with usage examples 3,323 [H]: `https://en.wiktionary.org/w/api.php?action=query&prop=categoryinfo&titles=Category:Greek_lemmas|…`.
- Entry shape, from the page for νερό: part of speech, IPA, an inflection table as a form list tagged by case and number (nominative singular νερό, plural νερά, genitive νερού, νερών, and so on), English gloss ("water (liquid H₂O)"), tag `neuter`, etymology, derived forms and sayings [H]: https://kaikki.org/dictionary/Greek/meaning/ν/νε/νερό.html.
- Gender is a tag (`masculine`, `feminine`, `neuter`) and not an article; the listed forms carry no article, so ο/η/το would be derived from the gender tag [H for the page, I for the conclusion]. Gender categories (19,309 in the three) sum above the noun category (16,696), so some entries carry two genders or sit in other parts of speech [I].
- English translations: glosses are in English because the English edition is the source. Russian: English-edition Greek entries have no Russian glosses; Russian lists translations only inside English headwords' translation tables, which would need inversion [I]. The Russian Wiktionary edition on Kaikki has Greek (`Греческий`) with Russian glosses, 13,246 senses, extracted 2026-10-20 from the dump of 2026-10-01 [H]: https://kaikki.org/ruwiktionary/. Ancient Greek there has 19,970 senses.
- Example sentences: about 3,323 Greek entries have usage examples in the English Wiktionary (category count above), that is roughly one in ten lemmas [I from the counts].
- Kaikki also lists a Greek Wiktionary edition (`elwiktionary`) with Greek-language definitions [H]: https://kaikki.org/ (index list).

### 3.6 Open frequency lists for Modern Greek

| List | Licence | Content | Source |
|---|---|---|---|
| OpenSubtitles-based lists (FrequencyWords, `el_50k.txt` and larger) | CC BY-SA 4.0 for content, MIT for code; repo last pushed 2022-02-07 | word, count per line, space-separated | https://github.com/hermitdave/FrequencyWords [H]; also listed on https://en.wiktionary.org/wiki/Wiktionary:Frequency_lists/Modern_Greek (the Wiktionary page also hosts a 5K list from opensubtitles.org) [H] |
| Leipzig Corpora Collection | CC BY 4.0 per the Wiktionary page | per-corpus word lists from news and Wikipedia; Greek files exist, for example `ell_news_2022_100K.tar.gz` (28 MB), `ell_news_2022_1M.tar.gz` (272 MB), `ell_wikipedia_2021_1M.tar.gz` (243 MB), URL base `https://downloads.wortschatz-leipzig.de/corpora/` | Wiktionary page above [S]; file existence and sizes by HTTP HEAD on 2026-10-21 [H]; the Leipzig site's own licence page needs JavaScript and was not read [U] |
| KELLY Greek list (CEFR A1–C2 levels, ipm) | CC BY-NC-SA 2.0; non-commercial | frequency list with CEFR level from web corpora; the Greek list is hosted at hdl.grnet.gr/11500/ATHENA-0000-0000-25C1-C | https://ssharoff.github.io/kelly/ (undated) [H]; the Wiktionary page gives a different licence string for the Leeds copies ("CC BY-ND-NC-SA 2.0"), so the exact licence is [U] |
| `wordfreq` (Python) | code Apache, data CC BY-SA 4.0 | Greek (`el`) supported; no further updates planned; last release 3.1.1 on 2023-11-21, repo last pushed 2025-01-04 | https://github.com/rspeer/wordfreq (README, SUNSET.md) [H] |

- A shared AnkiWeb deck "Greek Vocabulary" cites the KELLY CEFR list [S, search snippet]: https://ankiweb.net/shared/info/1696761937 (page needs JavaScript) [U].

## 4. SQLite in iCloud Drive and other syncing folders

- Anki: the manual does not recommend syncing the Anki folder through a third-party sync service because files synced while in use can corrupt the database; it advises a script that copies from the synced folder to a local folder before launch and back after exit. Anki syncs through AnkiWeb, not through file sync [H]: https://docs.ankiweb.net/files.html ("DropBox and File Syncing", undated).
- SQLite documentation, "How to corrupt": a backup copy taken during a transaction can mix old and new content; the journal (`-journal`) or WAL (`-wal`) file must be kept together with the database file; copying the database without its journal, or overwriting it without deleting a hot journal, is likely to corrupt it; filesystems with broken locking, network filesystems above all, put concurrent access at risk. Page last updated 2026-04-13 per the search snippet [H]: https://sqlite.org/howtocorrupt.html (sections 1.2, 1.4, 2.1). Safe live copies: the backup API, `VACUUM INTO`, `sqlite3_rsync` [H, same page].
- SQLite WAL: all processes must be on one host; WAL does not work over a network filesystem, since the wal-index is shared memory [H]: https://sqlite.org/wal.html (undated).
- Inference for iCloud Drive: a synced database folder holds `.db`, `-wal`, `-shm` as separate files that sync independently and at different times, so a receiving device can see a main file without the matching WAL [I from the two SQLite pages; no Apple page states this about SQLite].
- DEVONthink (DEVONtechnologies, package-based database): the developer's forum reply says never to put databases in cloud-synced, third-party-synchronised, encrypted or compressed folders, and that DEVONthink already blocks common folders such as Dropbox and iCloud Drive [H, vendor forum]: https://discourse.devontechnologies.com/t/nearly-my-entire-database-of-over-2000-documents-is-now-orphaned/57567 (2020-07-31).
- GRDB.swift: a 2019 issue asks whether a writable SQLite file in iCloud-synced Documents is safe; the maintainer does not endorse it, notes GRDB uses no `NSFileCoordinator`, and the asker concludes that CloudKit is the safer way [S]: https://github.com/groue/GRDB.swift/issues/547 (2019-06-11).
- A 2024 Stack Overflow answer says a database in a cloud-synced folder would probably corrupt or lose recent changes, and points to Core Data with CloudKit [S, low authority]: https://stackoverflow.com/questions/78048531/how-to-sync-sqlite-database-with-icloud (2024-02-26).
- Apple, archived and retired Core Data iCloud guide: iCloud-enabled SQLite stores kept the SQLite file local and saved and retrieved transaction logs (logs of changes) in the ubiquity container. The guide is marked deprecated and unsupported [H]: https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/UsingCoreDataWithiCloudPG/Introduction/Introduction.html and `.../UsingSQLiteStoragewithiCloud/UsingSQLiteStoragewithiCloud.html` (page date 2017-06-06 per the search snippet).
- Apple, current: `NSPersistentCloudKitContainer` mirrors select persistent stores to a CloudKit private database; the SQLite store stays local [H]: https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer and https://developer.apple.com/documentation/coredata/syncing-a-core-data-store-with-cloudkit (JSON endpoints, 2026-10-21).
- Apple, archived iCloud Design Guide for documents: documents are files or file packages; apps must use file coordination (`NSFileCoordinator`, `NSFilePresenter`) to access files in iCloud containers; `UIDocument` and `NSDocument` do it automatically; iCloud sends only the changed pieces of a file package, so a package format is the recommended choice for multi-part documents; conflicts surface as `NSFileVersion`; the app should not rewrite unchanged state, since that creates needless conflicts [H]: https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/Chapters/DesigningForDocumentsIniCloud.html (archive, undated).
- An unreviewed AI-written gist ("expo-file-system iCloud Drive sync SQLite", 2026-03-31) reports WAL as the main hazard when copying a live database [S, low authority; not relied on]: https://gist.github.com/minoru365/eb30301530a16af66eaaaaa3db7f8336.

## 5. Facts that bear on the Mnemit decision

These are my inferences from the sections above [I].

1. The native layout (a package with `deck.json` plus an append-only `reviews.jsonl`) follows Apple's file-package guidance and avoids the SQLite sidecar problem: no WAL, no shared memory, only changed pieces upload. No SQLite file lives in the synced folder; an `.apkg` import should write into the package, not keep a SQLite copy there.
2. A read-only `.apkg`/`.colpkg` importer for all three layouts needs ZIP, SQLite (system library), a zstd decoder (not in Apple frameworks) and a few-field protobuf reader. ApkgIOSwift's dependency list is the existence proof for that stack in Swift.
3. Embedding rslib is a licence decision (AGPL-3.0-or-later). The import subset above is small enough to write without it.
4. Importing Anki review history appends lines to `reviews.jsonl` and fits the append-only log; the scheduler state can then be rebuilt by replay under Mnemit's FSRS-6 parameters.
5. Export to Anki: a Legacy 1 or Legacy 2 `.apkg` (schema 11, JSON, no zstd) is the lowest-cost target, the shape genanki writes; scheduling state export is a larger job (`cards.data` keys above plus deck config protobuf).
6. CSV/TSV is already implemented; adding the Anki `#separator`/`#html` header lines on export and recognising them on import costs little and keeps files round-trippable with Anki.
7. Deck sources usable without breaking a rule: Tatoeba (download or API, CC BY with author attribution), Kaikki/Wiktextract (CC BY-SA; the per-language download is slated for removal and the raw dump is 2.8 GB gzipped, so extract Greek once and keep that file), frequency lists (FrequencyWords CC BY-SA, Leipzig CC BY; KELLY is non-commercial). AnkiWeb and Quizlet content: manual download by the user only.

## 6. Not verified

- The 2.1.x release that first wrote `collection.anki21`.
- Whether AnkiWeb's download button needs a login.
- Mochi public deck endpoints (none seen).
- Greek audio coverage on Tatoeba (the `has_audio` filter returned 0).
- Leipzig's own licence page; exact KELLY Greek licence string.
- Current SuperMemo.com import and export features.
- Memrise's official position on course export (only third-party sources read).
- The `0x1f` field separator of `notes.flds` was not re-read in the Anki source for this note.

## 7. Source index

Primary, Anki: https://github.com/ankitects/anki (main, read 2026-10-21): `proto/anki/import_export.proto`, `proto/anki/deck_config.proto`, `rslib/src/import_export/package/{meta,media,mod}.rs`, `rslib/src/import_export/package/apkg/export.rs`, `rslib/src/storage/schema11.sql`, `rslib/src/storage/upgrades/*.sql`, `rslib/src/storage/card/data.rs`, `rslib/src/revlog/mod.rs`; release notes via https://api.github.com/repos/ankitects/anki/releases; manual https://docs.ankiweb.net/exporting.html, /importing/text-files.html, /files.html, /deck-options.html.

Other: see the URLs inline. Search queries ran through `websearch` on 2026-10-21; pages that need JavaScript (AnkiWeb terms, Apple Developer Forums thread 76102, Anki forum threads) were read through their embedded JS or JSON, or not at all, as noted.
