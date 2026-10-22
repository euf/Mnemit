# The same word in two decks

Research for Mnemit, 22.10.2026. Confidence: **[S]** from the cited source as read,
**[I]** our inference, **[U]** found only in secondary sources, not confirmed.

The case: deck X has «άπλος = simple», deck Y gets «απλός, -ή, -ό = plain; simple». Same word,
different spelling and different glosses, so neither the question text nor the answer text
matches.

## 1. What other clients do

### Anki (desktop; AnkiDroid shares its backend)

- **Duplicate check on adding.** Compares the first field of the note with every other note of
  the same note type, in the whole collection, whichever deck holds them. **[S]** The manual
  describes the first-field check and limits it to the current note type
  ([Adding/Editing](https://docs.ankiweb.net/manual/editing)). The code agrees:
  `is_duplicate` looks up first-field checksums of `note.notetype_id`, then compares the two
  strings after HTML stripping, with NFC normalisation when the "normalize text" option is on.
  No deck filter, no case folding, no accent folding. **[S]**
  [`rslib/src/notes/mod.rs`](https://github.com/ankitects/anki/blob/main/rslib/src/notes/mod.rs),
  main branch, read 22.10.2026.
- **The check warns and does not block.** The editor shows a link to the duplicates. A user
  with overlapping language decks asked for a check limited to the deck being added to
  (28.01.2024); the reply was to use a different note type per deck. **[S]**
  [forum 40428](https://forums.ankiweb.net/t/is-it-possible-for-duplicate-detection-to-check-the-deck-being-added-to-only/40428)
- **Other fields.** Not checked on adding, for efficiency; Browse ▸ Notes ▸ Find
  Duplicates searches any chosen field across all note types that have it. **[S]** manual, same
  page and [Browsing](https://docs.ankiweb.net/manual/browsing).
- **Importing text files.** The first field decides whether a row is a duplicate. Three
  resolutions: update the existing note (its scheduling is kept, and it stays in its current
  deck, not the deck chosen in the dialog), ignore the row, import as a new note. A "match
  scope" setting makes the comparison per note type or per note type and deck. **[S]**
  [Importing text files](https://docs.ankiweb.net/manual/importing/text-files); source names
  `DupeResolution::{Duplicate, Update, Preserve}` and `MatchScope::{Notetype, NotetypeAndDeck}`
  in `rslib/src/import_export/text/import.rs`. A row with a GUID that exists is never imported
  twice. **[S]**
- **`.apkg` import.** Notes that came from an earlier copy of the package are recognised, and
  the file's version replaces the local one when it is newer. **[S]**
  [Packaged decks](https://docs.ankiweb.net/manual/importing/packaged-decks)
- **Cards of one note can sit in different decks.** **[S]** A forum helper, 28.01.2024: the cards
  of one note may all go into different decks (forum 40428); the manual's burying section
  names the deck override feature as the example.
- **Burying crosses decks, by note.** The manual says siblings are buried even when they are in
  different decks. **[S]** [Studying ▸ Siblings and Burying](https://docs.ankiweb.net/manual/studying).
  The query behind it selects cards with the same `nid` and a new, review or interday-learning
  queue, with no deck condition (`rslib/src/storage/card/siblings_for_bury.sql`, called by
  `bury_siblings` in `scheduler/bury_and_suspend.rs`). **[S]** Learning cards are not buried;
  suspended cards cannot be buried. **[S]** manual.
- **Two notes of one word are not siblings.** Nothing in the check, the import or the burying
  query relates them. **[S]** The add-on ecosystem fills the gap: "Bury Cousins (related cards
  that aren't siblings)", "Bury related notes" and "Source Siblings Bury (Cousins)" are listed
  together in one add-on thread (28.07.2024). Cousins takes rules of note type pair, match field
  and a similarity matcher, and buries the similar card of the deck being reviewed until the
  next day. **[S]** [thread](https://forums.ankiweb.net/t/source-siblings-bury-cousins-addon-support-thread/47552),
  [README](https://github.com/noobj2/Anki-Cousins).
- **FSRS does not relate cards.** Expertium (FSRS developer), 11.09.2024: while a card is
  reviewed, FSRS and SM-2 in Anki cannot read the history of any other card; sibling terms would
  need an app built for them from the start. A user answers Easy on a reverse card seen
  minutes after its forward card and gets 19 days (11.09.2025). **[S]**
  [49267](https://forums.ankiweb.net/t/interval-determination-of-siblings/49267),
  [66404](https://forums.ankiweb.net/t/feature-request-fsrs-should-take-reverse-cards-into-account-when-scheduling/66404)
- **Burying has a cost.** A user who enabled review-sibling burying on tightly related notes saw
  low-interval cards buried again and again, reviewed at low retrievability (13.02.2025). **[S]**
  [55782](https://forums.ankiweb.net/t/on-review-sibling-burying/55782)
- **Overlapping vocabulary decks, the same use as ours.** A student of biblical Greek and Hebrew
  imports the vocabulary of two books with many shared words and wants the second import to
  keep the first one's progress (05.03.2024). The answer: a card lives in one deck; use tags on
  the note, find duplicates, and pull the tagged cards into the deck being worked on. **[S]**
  [forum 42001](https://forums.ankiweb.net/t/allowing-duplicates-to-be-reviewed-across-multiple-decks/42001)
- **AnkiHub, same note in two subscribed decks.** The add-on skips notes that another installed
  AnkiHub deck already holds (21.02.2023), after weighing a choice dialog and a keep-both option.
  **[S]** [thread](https://community.ankihub.net/t/problem-of-overlapping-note-ids-between-decks/780)
- **AnkiDroid** reuses the desktop Rust backend, so the rules above apply. **[S]**
  [Anki-Android-Backend README](https://github.com/ankidroid/Anki-Android-Backend). AnkiMobile:
  same author and manual, not checked against its code. **[U]**

### Mochi

- Every card is stored in a deck. **[S]** [Decks](https://mochi.cards/docs/decks/)
- No duplicate check. The admin, in a forum answer about a book with repeated vocabulary, says
  there is none yet; planned: compare the primary field, or the first line of a card without a
  template, with the other cards in the database. A second
  thread asks for the same for language vocabulary. **[S]**
  [Duplicate Cards](https://forum.mochi.cards/posts/148/answer/154),
  [Flag Duplicate Cards](https://forum.mochi.cards/posts/127/flag-duplicate-cards), both about
  a year old when read. The docs pages on cards, import and reverse review contain nothing on
  duplicates. **[S]**

### RemNote

- One note (a Rem) is shown in several places by reference or portal, with no copy made. **[S]**
  [Portals](https://www.remnote.com/feature/portals)
- A document is a query over cards: it gathers the cards of its descendants, of tagged bullets,
  of portals and tables, recursively and one way. The card belongs to the Rem. **[S]**
  [How does RemNote decide what flashcards are part of a document?](https://help.remnote.com/en/articles/8892109-how-does-remnote-decide-what-flashcards-are-part-of-a-document),
  updated 16.07.2026. A duplicate check was not found in the help center. **[U]**

### SuperMemo

- Duplicate detection exists for web imports of articles, by reference: the element menu's
  "Deprecate" makes the program stop treating a reference as a duplicate. **[S]**
  [Element menu help](https://www.super-memory.com/help/elmenu.htm). No item-level duplicate
  merge was found in the help pages or on supermemo.guru. **[U]**
- "Neural review" is a subset review guided by links in the collection (Ctrl+F2 on an element).
  It does not relate scheduling of similar items. **[S]**
  [supermemo.guru](https://supermemo.guru/wiki/Neural_review)
- Interference is handled by the author of the items: see section 2.

### Memrise (community courses, the Classic site)

- The Auto-Ignore button checked every word of a course against what the learner had learned
  anywhere on the site and ignored the items whose word and definition both matched. A 2013
  Reddit comment guesses that a slightly different definition makes the learner learn the word
  again. **[U]**
  [Memrise Users Wiki, FAQ](https://memrise-users.fandom.com/wiki/Frequently_Asked_Questions),
  [r/memrise](https://www.reddit.com/r/memrise/comments/1gjvte/do_courses_sync_with_each_other_so_you_dont/).
  The new Memrise has no community courses; its behaviour was not checked.

### Duolingo

- The memory model has one state per student and word. Exercises are indexed by the lexeme tags
  of their words, a tag being root lexeme, part of speech and morphology; a practice session
  takes exercises whose tags the model says are due. A course teaches 3,000–5,000 tags. **[S]**
  Settles & Meeder, ACL 2016, [P16-1174](https://aclanthology.org/P16-1174.pdf), §2, §3.4, A.1.
  The unit of memory is the word, whatever number of exercises carry it. **[I]**

### Lingvist

- The vendor describes algorithms that predict and track each user's knowledge, built on nearly
  half a billion learning events; nothing on duplicates. **[S]**
  [lingvist.com/blog](https://lingvist.com/blog/is-there-a-map-for-learning-a-language/) **[U]** for any further detail.

### Clozemaster

- A sentence reused in several collections has separate progress in each, as a community
  member answered (11.02.2025). **[U]**
  [forum 59086](https://forum.clozemaster.com/t/is-there-overlap-or-100-unique-content-in-each-collection/59086)
- The knowledge base describes copying sentences from one collection to another with an
  "include progress" option, one sentence at a time. **[S]**
  [article 107](https://docs.clozemaster.com/article/107-how-to-import-sentences-between-collections),
  updated 06.07.2026.

### Summary table

| Client | Duplicate check on adding | One word in two places | Cross-place coupling |
|---|---|---|---|
| Anki | first field, same note type, whole collection, exact string; warns | two notes: independent cards; one note: cards may sit in different decks | burying by note across decks; cousins only by add-on |
| Mochi | none; planned: primary field | independent cards | none |
| RemNote | none found | one Rem shown in many places | one card, many views |
| SuperMemo | web-import references only | independent items | none; interference left to the author |
| Memrise Classic | auto-ignore on word and definition | skipped | none |
| Duolingo | none: exercises are indexed by word tags | one state per word | the tag is the state |
| Clozemaster | none found | independent per collection | copy with progress, by hand |

## 2. What interference research says

No study of near-duplicate cards, or of one word held by two decks, was found: searches on
22.10.2026 for duplicate flashcards, redundant spaced-repetition items and overlapping decks
(DuckDuckGo, Bing, PubMed, Crossref, ERIC) returned practitioner material and the studies below.

- **Wozniak, rule 11 of the twenty rules, "Combat interference".** Similar items are confused;
  he calls interference probably the single greatest cause of forgetting in the collections of
  an experienced user, and the only hermetic procedure against it is to "detect and eliminate".
  The remedies are context cues, examples and labels on the confusable item. **[S]**
  [Twenty rules](https://www.supermemo.com/en/blog/twenty-rules-of-formulating-knowledge)
- **Rule 17, redundancy.** Redundancy need not contradict the minimum information principle;
  memorizing the same fact from different angles does little harm. **[S]** same page.
- **Nielsen.** Asking variants of the same question helps because, in memory terms, each variant
  makes associations on different triggers. **[S]**
  [Augmenting Long-term Memory](https://augmentingcognition.com/ltm.html), strategy list.
- **Retrieval-induced forgetting.** Practising some members of a category by retrieval impairs
  the unpractised members of the same category on a delayed test, mostly the frequent ones.
  **[S]** Anderson, Bjork & Bjork, JEP:LMC 1994, 20(5), abstract
  ([PubMed 7931095](https://pubmed.ncbi.nlm.nih.gov/7931095/)). In second-language learners,
  naming objects repeatedly in Spanish reduced the accessibility of the English names.
  **[S]** Levy, McVeigh, Marful & Anderson, Psychological Science 2007, abstract
  ([PubMed 17362374](https://pubmed.ncbi.nlm.nih.gov/17362374/)). Both concern competing
  answers to one cue. A review passage quoted in Gwern's [spaced repetition](https://gwern.net/spaced-repetition)
  essay, section "Downsides", with no author named at that point, judges such effects modest
  next to the testing effect. **[U]**
- **Semantic sets.** Words that are new, related in meaning and learned together are harder to
  learn than unrelated ones. **[S]** Tinkham 1993 (System 21), Waring 1997 (System 25), ERIC
  abstracts [EJ472775](https://eric.ed.gov/?id=EJ472775) and EJ547530. The items are different
  words.
- **Anki forums, grade inflation.** A card shown minutes after its reverse is answered from
  short-term memory and its interval grows (66404, section 1). `production-cards-research.md`
  §1.6 and §2 reach the same reading for siblings and bury them for that reason.

**Reading for Mnemit.** **[I]**

1. The studies concern different items that compete for one cue. Two cards whose answer is the
   same Greek word are one memory trace asked twice, so interference between them is not
   predicted. What they cost is review time, and, when they are asked in the same sitting, an
   inflated grade on the second.
2. Different words that share a spelling (κύριος "Mr" and κύριος "main", νέος and ο νέος,
   πώς and πως, συνέχεια and η συνέχεια) are the pairs interference predicts. They stay two
   items, and the article and the accent are the cues that keep them apart. Merging by a
   loose key would destroy that cue.
3. A second gloss for the same word (plain; simple) is the redundancy of rule 17 and Nielsen's
   variants. Nothing in the sources argues for removing it.

## 3. Mnemit before the word key

**Unit.** A deck is one package file. `Deck`, `StudySession.selection`, `notesReviewed`,
`notesAwaitingRecognition`, `Deck.siblings(of:)`, `CardImporter.candidates(of:existing:)` and
`LessonWords.plan(for:existingNotes:created:)` each see one deck. No code in VocabCore reads
two decks to decide about one card. Cross-deck inputs exist for counts only: the new-card
allowance and the round guide (`DailyRingModel`, `RoundGuide`).

**Adding the example today**

- «άπλος = simple» in deck X: key `άπλος`, cards recognition `άπλος → simple` and production
  `simple → άπλος`.
- «απλός, -ή, -ό = plain; simple» in deck Y: key `απλός`, cards `απλός, -ή, -ό → plain; simple`
  and `plain; simple → απλός, -ή, -ό`. Deck Y's check sees only deck Y, so the cards are added.
- Inside one deck the pair would be added as well: the keys differ by the accent, and
  `CardText.key(forQuestion:)` folds case only.
- Result: both decks ask the word, four cards for one word.

**Duplicate checks, all against the target deck only**

- Add Lesson Words: `LessonWords.plan` skips a word whose note, compared in NFC, is in the
  deck; the Mac sheet passes `document.deck.cards.compactMap(\.note)`
  (`MacVocTrainNg/Views/LessonWordsSheet.swift`), the iPhone sheet `notesInDeck` and
  `questionsInDeck` of its deck (`VocTrain/Decks/AddCardsSheet.swift`).
- CSV, TSV and Anki: `CardImporter.candidates(of:existing:)` flags `.inDeck` when the question
  matches an existing question after trim and case folding, `.inFile` against an earlier row;
  flagged rows start unticked (`CardImport.Preview.selection`). Callers pass
  `document.deck.cards` (`CardImport.swift:48`, `CardImport+Anki.swift:122–137`,
  `ImportPreviewSheet.swift:164,173`, `CardImportPanel.swift:20–29`).
- No check compares answers, glosses, accents or word endings.

**The word key** (`LessonWords.note(forGreek:)`, a copy of `key()` in
`greek-lessons/vocab/merge.py`) lowercases, composes to NFC, moves a leading article behind
`#` and cuts the lemma at the first comma or bracket. Run on probe strings on 22.10.2026
(the two functions copied verbatim into a scratch program):

| Typed | Note today | Question key today |
|---|---|---|
| άπλος | άπλος | άπλοσ |
| απλός, -ή, -ό | απλός | απλόσ, -ή, -ό |
| απλός -ή -ό | απλός -ή -ό | απλόσ -ή -ό |
| απλός-ή-ό | απλός-ή-ό | απλόσ-ή-ό |
| ΑΠΛΟΣ | απλος | απλοσ |
| ο ψεύτης / η ψεύτρα | ψεύτης / η ψεύτρα#ο | ο ψεύτησ / η ψεύτρα |
| ο/η οδηγός | οδηγός#ο/η | ο/η οδηγόσ |
| ο οδηγός | οδηγός#ο | ο οδηγόσ |
| κύριος, -α, -ο | κύριος | κύριοσ, -α, -ο |
| ο κύριος | κύριος#ο | ο κύριοσ |

Endings without a comma, hyphenated endings and " / " alternatives are left in the key;
`LegacyAnswer.forms` in `Tools/deck-from-tsv` already cuts at " / ", " · ", "; ", " (" and at the
hyphen of the last word.

**Study.** Burying is per deck: `notesReviewed(onDayOf:in:)` and `selectedNotes` read one deck's
cards. The study queue goes deck after deck ("Next: …" on the iPhone, `StudyRun`), so the same
word in X and Y is asked twice in one sitting, the second time with the first answer fresh.
Each card has its own FSRS state; `Scheduler.review` reads only that card's state
(`production-cards-research.md` §2). One review does not touch the other copy.

**Counts.** Plan, goal and ring count cards, so two copies are two cards of work.
`MemoryEstimate.total` adds the decks and says "a word is in one deck"
(`Statistics/MemoryEstimate.swift`; `DailyProgress.swift:910`): a word held by two decks adds
its recall probability twice to "≈ N words in memory". The README states that this number
cannot be inflated by counting more cards.

**Measured on the owner's decks** (`cards-a1a2.tsv`, `cards-b1.tsv` in
`~/Documents/greek-lessons/vocab`, 22.10.2026): 1,629 and 1,118 words, 5,494 cards.

- Identical word keys in both decks: 0. `merge.py` gives each word one level.
- Keys equal after dropping accents: 11 words.
  - 6 are the same word that the two decks spell with different articles: `ο/η` in one deck,
    `ο` in the other (αστυνομικός, διπλωμάτης, οδηγός, παραγωγός, συγγενής, χορτοφάγος). They are
    asked in both decks now: 12 cards, 0.2 % of the cards.
  - 5 are different words: κύριος (ο κύριος, "Mr"; κύριος, "main"), νέος (adjective; ο νέος,
    "young man"), οικονομικά (τα οικονομικά, "economics"; οικονομικά, "cheaply"), συνέχεια
    (adverb; η συνέχεια, "continuation"), πώς ("how?") and πως ("that").
- Article-presence tells 4 of the 5 apart; the accent tells πώς from πως. Stripping accents
  alone would have joined all 11.

## 4. The verdict for Mnemit

Words are linked across decks by a derived word key; nothing is merged and nothing is stored.
Overlap is caught when words are added or imported, an exact match is left out by default, a
match that differs only in accents is flagged and left in, the learner resolves a kept pair
with the existing Suspend, and "words in memory" counts a word once. Scheduling does not cross
decks in this step: no shared state, no burying.

### 4.1 The word key (`WordKey.same`)

Two cards hold the same word when their keys are equal after these steps, applied to
`Card.note`, or, for a card without a note whose question has Greek letters, to
`LessonWords.note(forGreek: question)`:

1. NFC; lowercase with the final sigma written ς (the existing `note(forGreek:)`).
2. Lemma = the text before the first of `,`, `;`, ` / `, ` · `, ` (` and ` -`, and before a
   trailing hyphen group of endings (`-ή-ό`, `-α-ο`). Hyphens inside a word stay.
3. Article = the leading definite article, as now (`ο/η`, `η/ο`, `ο`, `η`, `το`, `οι`, `τα`),
   plus the indefinite ones `LegacyAnswer.articles` knows (ένας, μια, μία, ένα).
4. The common-gender article `ο/η` (or `η/ο`) matches `ο` and `η` of the same lemma. `ο` does not
   match `η`; `το`, `οι`, `τα` match only themselves.
5. Presence of the article counts: `κύριος` and `κύριος#ο` are two words.
6. Accents stay. `πώς` and `πως` are two words.

Probe pairs and the verdict of `same`:

| Deck X | Deck Y | Same word |
|---|---|---|
| απλός | απλός, -ή, -ό | yes (step 2) |
| απλός | απλός -ή -ό, απλός-ή-ό, Απλός | yes (steps 1, 2) |
| ο ψεύτης | ο ψεύτης / η ψεύτρα | yes (step 2) |
| ο/η οδηγός | ο οδηγός | yes (step 4) |
| ο νέος | νέος, -α, -ο | no (step 5) |
| πώς | πως | no (step 6) |
| άπλος | απλός, -ή, -ό | no (step 6); 4.2 flags it |

Measured on the owner's decks (22.10.2026, the built key, both directions): 10 words are joined and no different
word. Six differ by the article only, `ο/η` in one deck and `ο` in the other (αστυνομικός, διπλωμάτης, οδηγός,
παραγωγός, συγγενής, χορτοφάγος); four differ by what follows the lemma, the ` / ` and `, ` cuts of step 2
(ο καθηγητής and ο καθηγητής / η καθηγήτρια, ο σερβιτόρος, ο ταξιτζής, πουλάω and πουλάω / πουλώ (πούλησα)). The
five different words of section 3 stay apart.

### 4.2 The loose key (`WordKey.looksLike`)

Equal when the lemma matches after folding accents and diacritics (the fold of
`CardSearchIndex`, made shareable), with steps 2–5 unchanged, and `same` does not hold. It
covers a mistyped or missing accent (άπλος and απλός; ΑΠΛΟΣ typed in capitals, which carry no accents). Greek
stress separates words (πότε/ποτέ, πού/που, νόμος/νομός), so a loose match only informs. On the
owner's decks it fires once, on πώς and πως, a false match that the two glosses in the notice
settle at a glance. Its value is for hand-typed and downloaded text; the measurement has none
of that. **[I]**

### 4.3 What is never compared

- Glosses and answers. They are free text in the learner's language and rarely equal («simple»
  and «plain; simple»). Anki compares the first field only; Memrise's word-and-definition rule
  is reported to leave a slightly different definition as a new word **[U]**. The glosses appear
  in the notice, so the learner judges.
- The deck, the kind and the creation date.

### 4.4 At import and when adding words

- **Scope.** Every known deck, the paused ones included.
- **`same`** → the word is left out by default: unticked, labelled with the deck. For Add Lesson
  Words the word is skipped as a whole, both cards, as an in-deck duplicate is. Ticking it adds
  the cards.
- **`looksLike`** → the word is ticked, with the notice "Looks like «άπλος» in Greek A1–A2".
- **Merging into the other deck** (Anki's "update existing notes") is not offered: it writes
  into a deck the app may not have open, where the card's text merges by `Card.contentChanged`
  against edits from another device.
- **A kept word** makes ordinary cards with their own state, independent of the other copy.
- **One card by hand.** The question is checked as a word key when it has Greek letters; the
  notice appears under the field and does not block.
- **Edge.** If the other deck holds only the recognition card, a skipped word gets no
  production card in this deck. The learner ticks the word to have it.

### 4.5 Burying across decks

Not in this step. The reasons:

1. Anki's cross-deck burying belongs to one note whose cards sit in different decks. Two notes
   of one word are cousins, and core Anki leaves them alone (section 1). Mnemit's analogue of
   "same note" is the same word key, and its decks are separate files with separate plans.
2. The day's plan is counted per deck at the start of the day, and the goal is that plan. A
   card buried afterwards by a review in another deck is in the goal and out of "cards left",
   so "M of K cards · N left" stops adding up (the Today line keeps M + N ≥ K) and the ring
   needs an extra card to close. **[I]**
3. Burying that is correct at day start needs a fixed claim order of decks, the claimed keys
   passed into each deck's selection, and a joint replay of past days in `DeckActivity.history`
   and `DayBreakdown`. The order cannot be the study queue, which puts the deck used last
   first.
4. The exposure is 12 cards of 5,494 today; pairs made after this change are kept on purpose
   in the sheet.
5. Suspend resolves a pair for good with machinery that exists (`setSuspended`, the Suspended
   filter, merge by `suspensionChanged`).

**Build it when** more than 1 % of the cards of the active decks are in a pair with both
copies active (our threshold, about 55 cards at today's size), or the learner reports the same
word asked twice in a sitting. **[I]** Rules for that build:

- The key is `WordKey.same`; kind does not matter, as in a deck: a recognition card is buried by
  a production sibling reviewed the same day.
- New and review cards are buried; learning and relearning cards never are; suspended cards are
  not candidates.
- The first deck in a fixed order (name, then file path) claims a key for the day when it has a
  due, unsuspended card of it in the plan; later decks leave theirs out. The claim holds at day
  start, so plan, goal, counts, widget forecast and "How Today Works" agree.
- Each deck's `StudySession.selection` takes the claimed keys as an input, next to
  `newCardAllowance`; `StudyCounts` returns the keys it selected; `DailyProgress.evaluate` and
  `DayBreakdown` pass them deck to deck in the same order.
- A card left out stays due and comes back the next day, as a buried card does now.

### 4.6 One card's review informs the other: no

FSRS state is per card and a review writes one log in one deck: undo, the merge of two devices
and the append-only `reviews.jsonl` rest on that. A review mirrored into another deck's log would
put one grade into two files, and each of the three would have to span both decks. Anki and FSRS
do not do it either (Expertium, section 1). Duolingo's one-state-per-word model has no analogue
in a deck-per-file design.

### 4.7 Counting

- **Words in memory** counts a word once: the recognition cards of all decks are grouped by
  `WordKey.same` and the highest recall probability of a group stands for the word, at the day's
  start as well as now **[I]**. Cards without a key count one each.
- **Cards, plan, goal, ring, streak** stay per card.

### 4.8 What the learner sees

- **Add Lesson Words and the import preview.** A line under the word or row: "Already in Greek
  A1–A2: ο/η οδηγός · driver", unticked; or "Looks like «άπλος» in Greek A1–A2 · simple", ticked.
  The preview's summary line counts the words left out per deck.
- **Card detail and the Mac inspector.** Beside the link to the sibling of the deck, as now,
  "Also in <deck>" with the other copy's question, answer and next due date; tapping opens it.
  Suspend and Resume are on the same screen.
- **Browser.** No new filter. The Suspended filter lists parked copies.
- **Today, Study, ring, widget.** No new element. A word asked twice because the learner kept
  both copies shows nothing special.
- **Words in memory.** The number is the number of words.

### 4.9 Where in code

Built (22.10.2026):

| Piece | Place |
|---|---|
| `WordKey`: `init?(_ text:)` for a note or typed Greek, `init?(card:)`, `same(as:)`, `looksLike(_:)`, `note`, `sameKeys`, `groups(of:)`; tests with the probe pairs of section 3 and the table of 4.1 | `Packages/VocabCore/Sources/VocabCore/Import/WordKey.swift`, `Tests/VocabCoreTests/WordKeyTests.swift` |
| `WordIndex`: key → word of one deck (`Match`: deck name, Greek question, answer's first line, card IDs) over `[(name, Deck)]`; `match(_:) -> Hit?` (`.same` or `.looksLike`) | `Import/WordIndex.swift` |
| `CardImporter.Duplicate.inOtherDeck(WordIndex.Match)`, `Candidate.similar`, the `elsewhere:` parameter; the first two checks are the deck's and the file's | `Exchange/CardImporter.swift`; unticked by default through `Preview.selection` (only a candidate without a duplicate is ticked), lines and the per-deck summary in `Shared/Support/OtherDecks.swift` |
| `LessonWords.plan(for:existingNotes:elsewhere:created:)`: notes compare as keys, `Plan.skippedElsewhere`, `Plan.similar`; `note(forGreek:)` is `WordKey(…).note` | `Import/LessonWords.swift`; sheets `MacVocTrainNg/Views/LessonWordsSheet.swift` (a toggle adds the words of other decks), `VocTrain/Decks/AddCardsSheet.swift` (`WordListPreview`, the notice under One Card) |
| Index of the other decks | iPhone: `KnownDeckFiles` (`VocTrain/Decks/KnownDeckFiles.swift`) in the environment, set by `StartScreen`, read with `DeckFileReader` off the main thread; Mac: `OpenDecks.wordIndex(excluding:)` over the open documents; paused decks included, the deck of the sheet left out, built at each sheet or screen, no cache |
| Words in memory once | `MemoryEstimate.recalls` (the learned recognition cards with a key), `MemoryEstimate.total(_:)` |
| "Also in" line | `VocTrain/Decks/CardDetailScreen.swift` and `MacVocTrainNg/Views/CardInspector.swift`, beside the sibling (`Deck.siblings(of:)`, `Model/CardFilter.swift:59`) |

The key is Greek only: a card gets one from its note, or from its question when the note has no Greek letters (the
note of an Anki card is a random string); a card with neither has none.

Not built: the same cut in `merge.py` `key()` of `greek-lessons`, so that the generator stops producing `ο/η` and `ο`
pairs; the next due date and a tap on the other copy in the "Also in" line; a cache of the index by file date;
burying across decks, whose pieces are `StudySession.selection` and `DayIndex`, `StudyCounts`,
`DailyProgress.evaluate`, `DayBreakdown`.

The detection is advisory: it only sets default ticks and adds lines of text, so removing the index parameter restores
the behaviour of one deck.

### 4.10 What would change the verdict

- Overlap above the threshold of 4.5 in the learner's own decks: build the burying.
- A learner who studies one deck at a time and finds the skip default in the way: make the
  default a setting. The skip default follows Anki's warning, AnkiHub's skip and Memrise's
  auto-ignore; no source measures it.
- A measurement of how often a second copy asked in the same sitting is graded Easy: the
  `reviews.jsonl` logs of both decks hold it, for the six pairs of section 3.

## 5. Not read

Anki's AnkiMobile code; the Memrise help center of the current product; RemNote's duplicate
handling beyond the help center; the full text of Roediger & Karpicke 2006, Tinkham 1993 and
Waring 1997 (abstracts only); SuperMemo's own item-level duplicate tools beyond the pages
named. The ankiweb.net add-on pages need JavaScript; the Cousins add-on was read through its
GitHub README and a forum thread.
