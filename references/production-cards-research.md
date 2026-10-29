# Production cards: when to introduce the reverse direction

Research for Mnemit, 22.10.2026. Confidence: **[S]** from the cited source as read,
**[I]** our inference, **[U]** found only in secondary sources, not confirmed.

Rule in the code: a word's production card (meaning → Greek) waits until its recognition card
(Greek → meaning) is in the review phase with a scheduled interval of at least
7 days (`StudySession.unlockDays`, a constant). Opened production cards alternate with the new recognition
cards one for one, oldest-learned first: by the first review of the word's recognition card, whatever the
deck's new-card order. A new or
review card is buried for the study day when its sibling was reviewed that day or is already
selected; learning cards are never buried (`StudySession.selectCards`, `notesAwaitingRecognition`).
Decks in use: Greek A1–A2 (known words), Greek B1 (new words), see HANDOFF.md.

## 1. Findings

### 1.1 The delay itself has not been tested

- Mondria and Wiersma name five earlier experiments that compared receptive and productive
  learning (Schuyten 1906, Stoddard 1929, Griffin & Harley 1996, Waring 1997, Schneider, Healy &
  Bourne 2002) and say none of them had a condition in which the words were learned in both
  directions. **[S]** Mondria & Wiersma 2004, short Dutch version, p. 30,
  [PDF](https://www.rug.nl/staff/j.a.mondria/ltt_2004_3.pdf).
- Searches on 22.10.2026 (DuckDuckGo, Bing, Tavily, Crossref abstracts) found no study that adds the
  second direction later than the first, in spaced repetition or without it. **[I]**
- Where the design was read, the experiments below are short list-learning studies with school
  pupils or undergraduates: 6 to 30 minutes of study, 10 to 50 words, one or two sessions (Webb 2009
  6 min / 10 words and Griffin & Harley 8 min / 20 words as reported by Yanagisawa, Stoddard 20 min
  / 50 words, Mondria & Wiersma 15 min / 16 words, Yanagisawa about 30 min / 24 words, Schneider et
  al. two sessions a week apart). None is spaced over months. **[I]**

### 1.2 Production is the harder direction and receptive study buys little of it

Mondria and Wiersma, 198 Dutch pupils (3 vwo), 16 French words, 15 minutes of study, delayed test
after two weeks, maximum 16. **[S]** Table 2, p. 32.

| Learned | Tested L2 → L1 (receptive) | Tested L1 → L2 (productive) |
|---|---|---|
| L2 → L1 only | 7.7 | 1.9 |
| L1 → L2 only | 6.6 | 4.1 |
| both | 7.9 | 3.8 |

- Receptive study yields a productive score of 1.9, productive study 4.1 (p < .01); the productive
  score of the combined group is 3.8, half its receptive score of 7.9 (p. 33–34). **[S]**
- Studied in one direction, the other direction still gets a share: 6.6 receptive after productive
  study against 7.7 after receptive study, not significantly different (p = .07). **[S]** p. 33–34.
- The authors' conclusion: receptive study alone does not lead to substantial productive
  retention, so a learner who needs production must study production (p. 36–37). **[S]**
- Stoddard (1929), as reported by Nation: receptive test 15.1 after receptive and 13.1 after
  productive study; productive test 6.0 after receptive and 8.0 after productive study (maximum 25
  per test). Receptive tests are about twice as easy as productive tests, and the effect of test
  type is larger than the effect of study direction. **[U]** Nation 2013, p. 54–55.
- Waring (1997), as reported by Nation: receptive study took less time than productive study,
  productive scores stayed below receptive scores over time and were close to zero after three
  months, and receptive and productive learning times correlated only .29. **[U]** Nation 2013,
  p. 55–56.
- Productive knowledge declines faster than receptive knowledge (Waring 1997; Schneider et al.
  2002), as summarised by Mondria and Wiersma. **[U]** Mondria & Wiersma, p. 30.
- Laufer and Goldstein, 435 learners: a hierarchy of difficulty holds at all frequency levels,
  passive recognition (easiest), active recognition, passive recall, active recall (hardest); passive
  recall (the ordinary L2 → L1 card) was the best predictor of classroom performance. **[S]**
  Language Learning 54, 399–436, abstract.

### 1.3 Adding the second direction

- Combined study gave the same receptive retention as receptive study alone (7.9 against 7.7,
  p = .36) and the same productive retention as productive study alone (3.8 against 4.1, p = .75).
  The immediate productive test was lower after combined study (14.1 against 15.5, p < .01); the
  gap was gone after two weeks. **[S]** Mondria & Wiersma, p. 33–35. The authors expected a gain
  from the second direction and found none; they offer a ceiling effect on the immediate receptive
  test and the extra time the second direction takes from the first.
- Production practice lifts comprehension: adults learning an artificial language who practised
  production outperformed comprehension-practice participants on vocabulary comprehension and on
  grammatical comprehension. **[S]** Hopman & MacDonald 2018, Psychological Science 29, 961–971,
  abstract.
- With enough time per word (84 s of retrieval practice per word against 24–36 s in the older
  studies), retrieval of the form from a picture (production) gave receptive knowledge as good as
  retrieval of the meaning (receptive; d = 0.29, p = .14), and a better productive score one week
  later (p = .005, d = 0.61). Receptive retrieval did not beat the control condition on the
  delayed productive test. N = 18, 24 pseudo-words. **[S]** Yanagisawa, KATE Journal 30,
  p. 146–149.
- Webb (2009, RELC Journal 40, 360–376): productive learning of word pairs gave larger gains in
  receptive and productive orthography and in productive knowledge of meaning, syntax and
  grammatical functions; receptive learning gave larger gains only in receptive knowledge of
  meaning. Conclusion: if only one method is used, productive learning might be more effective.
  **[S]** abstract.
- Griffin and Harley (1996), pupils aged 11–13 learning French: presenting pairs in L1–L2 order was
  the more versatile form if both production and comprehension were required. **[S]** Applied
  Psycholinguistics 17, 443–460, abstract. Nation reads it as advice to study productively when
  time or motivation allows only one direction. **[U]** Nation 2013, p. 458.
- Schneider, Healy and Bourne (2002): relearning savings were larger and forgetting over one week
  smaller when initial learning used the harder English → French direction. **[S]** Journal of
  Memory and Language 46, 419–440, abstract.

### 1.4 Receptive first, and what depends on proficiency

- Nation's guideline "Learn receptively, then productively": recalling a meaning for a form is
  usually easier than recalling a form for a meaning, and early in a language there is little other
  knowledge for a word to attach to, so receptive learning goes first. If both receptive and
  productive use is needed, the words are to be learned both ways; the governing principle is
  "Learn what you need to know". No interval, count or stage is given. **[S]** Nation 2013,
  §11.2 p. 458 and ch. 2 p. 56–57 (page numbers as printed in the full-text copy at
  [dokumen.pub](https://dokumen.pub/learning-vocabulary-in-another-language-2nbsped.html)).
- Terai, Yamashita and Pasich (2021): 28 Japanese learners of English, novel words studied in both
  directions. For lower-proficiency learners L2 → L1 study was more effective than L1 → L2; for
  higher-proficiency learners L1 → L2 was more effective. The authors link this to the strength of
  the lexical links between L2 and L1, which differs with proficiency. **[S]** Studies in Second
  Language Acquisition 43, 1116–1137, abstract (full text closed; the cut-off between the
  proficiency groups was not read).
- Teng and Xu (2022): for 18 words the learners already knew receptively, productive exercises
  (gap-filling, sentence translation, sentence writing) gave higher productive scores two weeks
  later than receptive exercises; repetition helped, with the effect declining after the first
  several retrievals. N = 146. **[S]** Language Teaching Research 29, 588–606, abstract.
- Across 1.2–1.4 the studies disagree on which single direction is better, the disagreement
  tracks study time per word and proficiency, and none of them shows that adding production early
  harms recognition. None supplies a threshold for "ready for production". **[I]**

### 1.5 Retrieval of a pair in one direction partly serves the other

- Retrieval practice on a pair transfers to a test with cue and response rearranged: strong
  transfer for pairs against a restudy control, none for triplets whose responses differ.
  **[S]** Rickard & Pan 2020, Memory & Cognition 48, 1146–1160, abstract.
- Forward and backward recall of the same pair correlate near unity, which favours a holistic
  (symmetric) association over two independent one-way links. **[S]** Kahana 2002, Memory &
  Cognition 30, 823–840, abstract. Both results concern English word pairs in one language; L2
  production adds form retrieval and spelling, which the Mondria and Stoddard numbers show as a
  large extra difficulty. **[I]**

### 1.6 Spaced-repetition sources

- Anki: when one card of a note is answered, its siblings (front → back and back → front are the
  manual's first example) can be buried until the next day; learning cards are not buried; "bury
  new siblings" names reverse cards explicitly. **[S]** Anki manual, Studying → Siblings and
  Burying; Deck Options → Burying.
- Anki's new-card sort "Card type, then order gathered" shows all front → back cards before any
  back → front cards when burying is off. The manual gives no advice on whether to create reversed
  cards or when. **[S]** Deck Options → Display Order.
- FSRS Helper (open-spaced-repetition): "Disperse Siblings" spreads the due dates of cards of one
  note "to avoid interference & reminder", listed as always worth enabling. The README cites no
  study. **[S]** [README](https://github.com/open-spaced-repetition/fsrs4anki-helper), features
  table and "Disperse Siblings".
- Anki Forums, "FSRS should take reverse cards into account when scheduling" (11.09.2025): a user
  answers Easy on a reverse card seen minutes after its sibling and gets a 19-day interval;
  Expertium, an FSRS developer: taking sibling history into account "would require massive changes
  to Anki, so the realistic answer is no". Related thread (10.09.2024, Expertium): FSRS in Anki
  cannot read the history of any other card, and it needs a Markov state per card; a scheduler with
  sibling terms would have to be built that way from the start. **[S]**
  [66404](https://forums.ankiweb.net/t/feature-request-fsrs-should-take-reverse-cards-into-account-when-scheduling/66404),
  [49267](https://forums.ankiweb.net/t/interval-determination-of-siblings/49267).
- SuperMemo, "Twenty rules of formulating knowledge", rule 17: for word pairs, recalling the
  foreign word does not guarantee recognising it, so swapped items are worth adding, and the
  redundancy does not break the minimum-information principle. No order or delay is given. **[S]**
  [text](https://www.supermemo.com/en/blog/twenty-rules-of-formulating-knowledge).
- Community practice of delayed reverse cards: an Anki add-on suspends all reversed cards of a deck
  and unsuspends one when its forward card has a review interval of at least 30 days. **[S]**
  [README](https://github.com/theandrewdavis/anki-add-reversed-when-learned). No evidence is
  attached to the 30.

## 2. What this means for flashcards with FSRS

- **A production card is a separate memory.** `Scheduler.review` reads only the card's own
  `learningState`; stability, difficulty and lapses are per card, and nothing a recognition review
  does reaches the sibling. **[S]** `Scheduler.swift`. By 1.2 the two memories differ: production
  is about half as strong at the same age, and by 1.5 they overlap. A production card started
  after successful recognition reviews gets a head start that FSRS cannot see; it shows up as Good
  or Easy grades on the first reviews, which then lengthen the interval. **[I]**
- **Interval is stability at the default target.** `FSRS.interval(stability:targetRecall:)` returns
  the stability itself at 0.9, so "interval ≥ N days" is "stability ≥ N days" on a deck at the
  default target recall; at 0.85 the same interval means a smaller stability, at 0.95 a larger
  one. **[S]** `FSRS.swift`; **[I]** for the consequence.
- **Burying keeps the sibling's answer out of the next grade.** A reverse card shown minutes after
  its sibling is answered from short-term memory, the grade is inflated and the interval grows
  (the forum case in 1.6). With burying, the siblings are at least a calendar day apart, which is
  also what FSRS Helper's dispersal aims at. **[I]** The studies in 1.5 predict positive transfer
  between the directions, so the risk of siblings is inflated grades and double counting;
  evidence for negative interference between a pair's two directions was not found. **[I]**
- **Which gate type.** Count of successful recognitions: reached at the same moment as the
  interval on an all-Good path and earlier than it after Hard grades or lapses, so a count unlocks
  a weaker memory. Stability: equal to the interval at 0.9, not shown in the options UI. Interval
  days: lapse-aware, already stored per deck, shown in both option screens. None: no study shows
  harm from both directions at once (1.3), and none supports it for new words either (1.4). **[I]**
- **How soon each threshold opens.** Model: FSRS-6 default weights (`FSRSParameters.default`), the
  `Scheduler` policy (two Good grades in the first session, review-phase interval = rounded
  stability at 0.9), no fuzz, every review on its due day unless stated. Cell = study day on which
  the recognition card first has an interval at or above the threshold (reviews so far in the
  default case).

  | Recognition history | ≥ 7 d | ≥ 14 d | ≥ 21 d | ≥ 30 d |
  |---|---|---|---|---|
  | Good, Good on day 0, Good at each review | day 2 (3 reviews, interval 11) | day 13 (4 reviews, interval 46) | day 13 | day 13 |
  | Easy on first sight, Good after | day 0 (interval 8) | day 8 | day 8 | day 8 |
  | Hard at the first review (day 2), Good after | day 2 (interval 8) | day 10 | day 10 | day 36 |
  | Hard at the first two reviews, Good after | day 2 | day 10 | day 29 | day 29 |
  | Good, every review 3 days late | day 5 | day 5 | day 26 | day 26 |

  **[I]** (own simulation of the formulas in `FSRS.swift`). Fuzz (up to ±10 % at these intervals)
  can turn an interval of 8 into 6, which delays the cells with an 8 by one review. Any threshold
  from 12 to 46 days behaves like 21 on the all-Good path; 7 days means "after the first spaced
  recognition review passed", 21 means "after the second".
- **The gate decides when a word becomes eligible; the alternation decides when its production
  card is introduced.** Opened production cards alternate with the new recognition cards one for
  one (`StudySession.alternatingUnlocked`), so while both have cards waiting the day's new cards
  split about evenly between the two directions. Taken newest-created first, the eligible production
  cards would leave the oldest eligible ones waiting longest; the oldest learned word first avoids
  that. **[I]** A gate of 7 instead of 21 moves the start of the production stream from day 13 to day 2
  and leaves its steady rate at the rate of new words.

## 3. Verdict for Mnemit

**Rule.** The production card of a word is introduced when its recognition card is in the review
phase with a scheduled interval of at least **7 days**. The two cards of a word are never asked on
the same study day (bury; learning-phase cards exempt). Opened production cards alternate with the new
recognition cards one for one.

Reasons:

1. The evidence supports "receptive first" only as a short guard. Nation's order and Terai's
   lower-proficiency result favour L2 → L1 study before L1 → L2 study; nothing in the studies
   supports a wait of three weeks, and the studies that measured it show no loss to recognition
   from adding production (1.3). **[I]**
2. Waiting costs production. Receptive study gives about 1.9 of 16 on the productive test where
   production study gives 4.1, and productive knowledge decays faster (1.2). Starting production
   later starts its spaced reviews later. **[I]**
3. A first spaced review passed (interval 7 days or more on FSRS-6 defaults) means the meaning link
   has survived one retrieval after a delay, the stage Nation's and Terai's argument is about. The
   learner has passed A2 and keeps 1629 A1–A2 words under review, plausibly closer to Terai's
   higher-proficiency group than to a beginner. **[I]**
4. Interval is the right unit: lapse-aware, stored per deck, equal to stability at the default
   target. **[I]**
5. Confidence is low: the base is short list-learning experiments with no spaced schedule and no
   staged-introduction condition, and the 7 against 21 choice rests on points 1–3, not on a
   measured difference. With one production card for every new word the two values differ mostly in
   the first two weeks of a new deck (section 2, last point). **[I]**

Greek A1–A2 deck: its words are known, and a word's production card opens as soon as its recognition
card has an interval of 7 days (Teng & Xu: productive exercises on receptively known words raise productive
scores).

### Where the rule lives in code

- The constant `StudySession.unlockDays` = 7, no option. A `productionUnlockDays` in an older `deck.json`
  reads, and the next save leaves it out.
- Gate: `StudySession.notesAwaitingRecognition` compares `calendar.days(from: lastReview, to: due)`
  with `unlockDays`.
- Order: opened new production cards are sorted by the first review of the word's recognition
  card, oldest first, and alternate with the new recognition cards one for one
  (`StudySession.alternatingUnlocked`), so the backlog of opened words is worked through from the
  oldest. Tests in `NoteSelectionTests`.

### What evidence would change it

- A staged-against-simultaneous experiment with equal study time and a delayed productive and
  receptive test: staged wins on both → raise the gate (14 or 21); simultaneous wins on
  production without losing recognition → 0 days with burying.
- Mnemit's own log, per card kind (the retention tables by kind in the statistics screen): the share
  of Forgot on production cards' first two review-phase reviews. FSRS at 0.9 expects about 10 %.
  Above 25 % on a deck with the 7-day gate → raise to 14; at or below 10 % on a deck with
  production gated at 14 or more → lower to 7 or drop the gate. The thresholds are our choice. **[I]**
- The full text of Terai et al. (2021) naming the vocabulary size of the two proficiency groups,
  to place a B1 learner in it.
- A measurement of how much a recognition review raises the production card's first-review pass
  rate (Rickard & Pan's transfer in a spaced setting), to decide whether production needs the
  later start at all.

## 4. Not read

Full text of Webb 2009, Griffin & Harley 1996, Terai et al. 2021 (paywalled; abstracts read), the
English chapter of Mondria & Wiersma 2004 (the short Dutch article was read, pp. 29–37), Waring 1997
and Stoddard 1929 (read through Nation). A Reddit thread on FSRS and card interference could not be
fetched.
