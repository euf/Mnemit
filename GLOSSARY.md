# Mnemit glossary

A vocabulary trainer: the learner answers a question (typing on the Mac, or revealing the answer
in flashcard mode and on the iPhone), grades themself, and FSRS plans when they see the card again.

Each entry gives the term in code, which is also the English word on screen unless the entry says
otherwise, then the German word on screen (DE) and the Russian word for talking with EF (RU). The
synonyms under _Avoid_ are not used, in any of the three languages.

## Language

### Cards

**Card** (DE Karte; RU «карточка»):
A pair of Question and Answer, plus an optional Hint. It is asked in one direction only, from the
Question to the Answer.
_Avoid_: vocable, entry, index card, word, Vokabel, Eintrag, Karteikarte

**Question** (DE Frage; RU «вопрос»):
The side of a Card that is shown and asked.
_Avoid_: front, Vorderseite

**Answer** (DE Antwort; RU «ответ»):
The expected answer of a Card; it may hold several Alternatives.
_Avoid_: back, solution, Rückseite, Lösung; "answer" for the Response or the Review

**Alternatives** (DE Alternativen; RU «варианты ответа»):
Several equivalent parts of an Answer, separated by `/`. Their order doesn't matter; naming only one
part answers Incomplete. An Answer or Response made only of `/` and whitespace, such as `/`, is one
single Alternative as a whole.
_Avoid_: variants, synonyms

**Hint** (DE Hinweis; RU «подсказка»):
An optional addition shown together with the Question.
_Avoid_: remark, Bemerkung

**New card** (DE Neue Karte; RU «новая карточка»):
A Card never yet asked in a Study session.
_Avoid_: unlearned, unseen

**Suspended card** (DE Ausgesetzte Karte; RU «приостановленная карточка»):
A Card the learner suspended, on the Mac or the iPhone: it is never Due and no Session asks it
until they resume it (Resume). Its Learning state stays as it was meanwhile.
_Avoid_: ignored, disabled, deferred, buried

### Reviewing and grading

**Review** (DE Abfrage; RU «оценка»):
Asking a Card once and grading it.
_Avoid_: answer, repetition, rep, Wiederholung, «повторение»

**Response** (DE Eingabe; RU «ввод»):
What the learner types in reply to a Question.
_Avoid_: answer, "your answer"

**Review mode** (DE Abfrageart; RU «способ оценки»):
How a Review went: Typed (DE Getippt), the learner types a Response and the app suggests a Grade;
or Revealed (DE Aufgedeckt), the learner reveals the Answer and gives the Grade without a Response.
The Mac asks Typed or, in "Flashcards" mode, Revealed; the iPhone asks Revealed. A Revealed Review
the Card recalls keeps the share `revealedRecallWeight` of the stability FSRS adds (1 by default in
the fork, adjustable down to a third); see `docs/adr/0004-revealed-reviews-damped.md` and
`docs/adr/0005-revealed-reviews-count-fully-in-fork.md`.
_Avoid_: flashcard mode (for the review mode)

**Check result** (DE Prüfergebnis; RU «результат проверки»):
How the Response matches the Answer: Correct, Incomplete, Almost correct or Wrong. It only
suggests a Grade.
_Avoid_: rating, verdict

**Correct** (DE Richtig):
The Response contains all Alternatives of the Answer.
_Avoid_: "correct" for a Grade, see Recalled

**Incomplete** (DE Unvollständig):
The Response contains only part of the Alternatives and nothing wrong.

**Almost correct** (DE Fast richtig):
The Response misses the Answer only by a few typos or by letter case. How many typos depends on the
length of the Alternative: none under 4 characters, one from 4, two from 8.
_Avoid_: typo (as a result)

**Wrong** (DE Falsch):
The Response is neither Correct, Incomplete nor Almost correct, or it is empty.
_Avoid_: "wrong" for a Grade, see Again

**Grade** (DE Bewertung; RU «вариант оценки»):
How well the learner knew a Card: Again, Hard, Good or Easy. The app suggests a Grade; the learner
decides.
_Avoid_: rating, mark, score

**Again** (on the button: Forgot; DE Nochmal; RU «забыл»):
The Grade for a Card the learner didn't know. The scheduler calls it Again; its button and swipe
say Forgot.
_Avoid_: failed, wrong

**Recalled** (DE Gewusst; RU «вспомнил»):
Any Grade except Again.
_Avoid_: correct

**Mistake** (DE Fehler; RU «ошибка»):
A Card that got Again at least once in a Session.
_Avoid_: failed card, "answered wrong"

**Lapse** (DE Vergessen; RU «провал»):
Again for a Card in the Review phase; it falls into Relearning.
_Avoid_: forgotten, "forgotten card" as a term

### Learning state

**Learning state** (DE Lernstand; RU «состояние обучения»):
What the app knows about the learner's memory of a Card: Phase, Stability, Difficulty, when it is
Due and how many Reviews and Lapses it had. A New card has none. Resetting makes the Card a New card
again and empties its Review log; a Merge leaves out the earlier Reviews from the other version too.
_Avoid_: memory state, memory, reset progress

**Phase** (DE Phase; RU «фаза»):
Where a Card stands in learning: Learning, Review phase or Relearning. A New card has none yet.

**Learning** (DE Lernend; RU «обучение»):
The Phase of a Card after its first Review, until it has collected enough Steps.
_Avoid_: "learning" as a Maturity, see Shaky

**Review phase** (DE Wiederholungsphase; RU «фаза повторения»):
The Phase of a learned Card that comes back only after an Interval.
_Avoid_: review (for the phase), graduated

**Relearning** (DE Erneut lernen; RU «переучивание»):
The Phase of a Card after a Lapse, until it has collected enough Steps again.
_Avoid_: learning anew

**Step** (DE Lernschritt; RU «шаг обучения»):
A Good for a Card in Learning or Relearning. Hard keeps the Card on its Step, Again resets it to
zero, Easy moves it straight to the Review phase.
_Avoid_: learning step as a time delay (as in Anki), "right answer"

**Stability** (DE Stabilität; RU «стабильность»):
The number of days until a Card's Recall probability falls to 90 %.

**Difficulty** (DE Schwierigkeit; RU «сложность»):
How hard a Card is for the learner, from 1 to 10.

**Recall probability** (DE Abrufwahrscheinlichkeit; RU «вероятность вспомнить»):
The estimated chance of knowing a Card now; "retrievability" in FSRS. The time since the last Review
counts in whole Study days, so on the day of a Review it is 100 %.
_Avoid_: retrievability, chance of remembering

**Target recall** (DE Angestrebte Abrufquote; RU «целевая запоминаемость»):
The Recall probability at which a Card in the Review phase is asked again; "desired retention" in
FSRS.
_Avoid_: desired retention; "retention" is the measured rate

**Retention** (DE Behaltensquote; RU «фактическая запоминаемость»):
The share of a Card's Reviews in the Review phase the learner recalled (Hard, Good or Easy), per
period and split by Interval under 21 Study days (Young) and from 21 (Mature); "true retention" in
Anki. It shows what the Target recall actually achieves. Not counted: Reviews in Learning and
Relearning, the first Review of a New card, and further Reviews on the same Study day. Code:
`TrueRetention`.
_Avoid_: true retention, retention for the Target recall

**Parameters** (DE Parameter; RU «параметры»):
The 21 weights of the FSRS model, per Deck in the Learning options. They start with the defaults of
open-spaced-repetition and can be computed from the Deck's Review log. Only Reviews on a later Study
day than the previous Review of the same Card count for that, and only from Cards whose Review log
reaches back to the first Review.

**Interval** (DE Abstand; RU «интервал»):
The number of Study days until a Card in the Review phase is asked again.
_Avoid_: review date, pause

**Study day** (DE Lerntag; RU «учебный день»):
A day that starts at 4 am. Intervals count in Study days.
_Avoid_: calendar day, day

**Due** (DE Fällig; RU «к повторению», «due»):
A Card the next Study session may ask: every New card, every Card in Learning or Relearning and
every Card whose Interval has run out, except a Suspended card.
_Avoid_: pending, open

**Maturity** (DE Reifegrad; RU «зрелость»):
How firmly a Card sits, by its Stability: New (DE Neu), Shaky (DE Unsicher; under 4 days, or in
Learning or Relearning), Young (DE Jung; 4–16 days), Maturing (DE Gefestigt; 16–64 days), Mature
(DE Sicher; 64–256 days), Mastered (DE Gemeistert; from 256 days).
_Avoid_: status, learning

### Decks

**Deck** (DE Stapel; RU «колода»):
A collection of Cards with their Learning options and their Progress, stored in one file. Its name
is the file name.
_Avoid_: document, file, box, index card box, Kartei

**Merge** (DE Zusammenführen; RU «слияние»):
Making one of two versions of the same Deck, such as the Mac's and the iPhone's after a conflict on
iCloud Drive. The Review logs of both count; each part comes from the version that changed it last,
by the rules of `DeckChange.merging` (`references/deck-package.md`). Reviews don't change the content.
_Avoid_: sync, reconcile

**Learning options** (DE Lernoptionen; RU «опции колоды»):
The settings that apply to one Deck, such as Target recall, the number of Steps and the daily limits.
_Avoid_: deck settings, Einstellungen

**Preferences** (DE Einstellungen; RU «настройки приложения»):
The app's settings that apply to all Decks.
_Avoid_: settings, options

**Review log** (DE Verlauf; RU «лог оценок»):
All Reviews of a Card, each with its time and Grade and, when measured, the duration: how long the
Card stood on screen with the app active (`ms` in `reviews.jsonl`). The duration feeds only the
pace, never the schedule.
_Avoid_: history, answer history, card history

**Progress** (DE Fortschritt; RU «прогресс»):
How the Cards of a Deck have firmed up over time, as a sequence of Daily snapshots.
_Avoid_: history, statistics history

**Daily snapshot** (DE Tagesstand; RU «снимок дня»):
How many Cards of a Deck had which stability at the end of a Study day.
_Avoid_: daily statistics

### Sessions

**Session** (DE Sitzung; RU «сессия»):
Reviews over a fixed selection of Cards in one go, until all are done or the learner stops. There are
Study sessions and Practice. In the fork Study runs as a Stream; the types keep the name.
_Avoid_: round, pass

**Study session** (DE Lernsitzung; RU «учебная сессия»):
A Session over the Due Cards whose Reviews change the Cards' Learning state. A Card stays in it until
it is in the Review phase. "Study" is the verb for it.
_Avoid_: review round

**Practice** (DE Üben; RU «практика»):
A Session over the Mistakes of the day or the newest batch. It changes no Learning state and writes
nothing to the Review log.
_Avoid_: drill, training, mistake round

### MacVocTrain 1

**MacVocTrain 1**:
The predecessor app; its documents can be imported as a Deck.

**Level** (RU «уровень»):
A card's stage in MacVocTrain 1, which fixed its next interval. The import turns it into a
Stability. Use only in the context of the import.

## Mnemit: the day, the ring, the streak

Terms of the fork. Each entry gives the term in code, the words on screen (EN / DE) and the
Russian word. The rule behind them: **a card is never a review, and a review is never a card.**
A day is measured in cards; reviews only price the time. The day has a time in seconds, and the app learns it from the work
the learner really does.

**Review** (on screen: not counted; RU «оценка»):
One grade of one card, as above: one swipe, button or key. A card can take several reviews on
one study day: the steps of a new card, an Again and its relearning. The review log
(`reviews.jsonl`) holds reviews. Counts of reviews are for the optimizer, statistics and pace,
never for the goal, the ring or the streak.
_Avoid_: card, answer (the answer is a side of the card), повторение, ответ

**Plan** (today's plan / heutiger Plan; RU «план дня»):
The cards a study day asks, as FSRS sets them: every review card due, overdue ones included,
cards in learning, and new cards within the day's limits and the deck's allowance
(`StudySession.counts`, `newCardAllowance`).
_Avoid_: session, queue, due count

**Streak step** (RU «шаг стрика»):
The cards of the plan that fit the first 120 s of work at the learner's pace (`DailyGoal.streakSeconds`).
A card costs the pace of its kind, new at the day's start or other. The step ends at the first card
where the cost reaches 120 s, and the goal ends the day: `DayRounds.ends` has at most two ends, one
when they coincide. Doing the step keeps the streak (`DailyProgress.streakKeptToday`) and Study rests
there once; the goal is the ring's rest. `DailyProgress` holds `rounds` (the number of ends),
`roundsDone`, `roundEnds`, `cardsToNextRound` and `minutesToNextRound`, at the pace the day began with.
A day that began with an empty plan cuts the cards as they stand. Only How Today Works names the step
(`references/learning-flow.md`).
_Avoid_: round, session, lap, segment

**Day's time** (RU «время дня»):
The seconds of work the day asks, 120 to 3600, never rounded (`DailyProgress.time`). It comes from the
review logs alone, forward from the first study day, so every device that reads the same logs gets the
same: 150 s before any study; then the time of the last study day (a day with work) times 1.15 when its ring was
the second (fourth, …) in a row closed on a goal that filled the time, the same time after the first of such a run
or a ring closed on a smaller plan, and times 0.775 when it stayed open, held to 120 to 3600
(`DailyGoal.nextTime(after:)`). The learner is never told the rule. Nothing else changes it. The day's time
sets the goal and the admission of new cards.
_Avoid_: capacity, limit, quota, level

**Admission** (new-card allowance; RU «допуск новых»):
The new cards a day takes in: the time of the day less the day's plan cards that are not new, at
the pace the day began with (the seven study days before it), over the price of a new card, at
least 0 (`DailyGoal.newCardsAllowed`). The decks' own limits (`newCardsPerSession`,
`newProductionPerSession`) are ceilings. Across all decks the allowance is shared in proportion to
the ceilings, by largest remainder (`DailyGoal.split`); each deck's share is its
`newCardAllowance`, which the plan takes (`DailyProgress.newCardAllowances`). Cards first reviewed
today count against it, and Push On comes beyond it.
_Avoid_: new-card limit, daily new cards

**Daily goal** (the K of "M of K cards" / „M von K Karten“; RU «цель дня»):
The cards of the plan, as it stood when the study day began at 04:00, that fit the day's time:
learning cards and reviews in the stream's order, then new cards, at the day's prices, up to the
time in seconds; at least one card if the plan has any (`DayRounds.goal`). With admission the
plan normally fits. After a break the reviews beyond the day's time stay in the plan and are done
beyond the goal. The goal stays for the day: cards added later, Push On and an Again don't raise it. A day
that began with an empty plan takes the plan as it stands (`DailyGoal.goal`).
_Avoid_: reviews goal, target, quota

**Done card** (the M of "M of K cards"; RU «сделанная карточка»):
A card whose last review of the study day left it due on a later day: FSRS let it go. A review
card answered Hard, Good or Easy is done at once; a new card after its last learning step; a
card answered Again once it leaves relearning. It counts once a day, however many reviews it
took (`DeckActivity.done`).
_Avoid_: reviewed card, answered card, «повторённая карточка»

**Cards left** ("N cards left" / „noch N Karten“; RU «осталось»):
Cards of the plan not done yet (`StudySession.counts(...).total` now). Done + left = the plan,
which is the goal or more: the reviews beyond the day's time are left, too.

**Backlog** (RU «хвост»):
Overdue cards, part of the plan, worked off as the day's time allows.

**Ring** (RU «кольцо»):
Done cards against the daily goal, with the **cards underway**: a card reviewed today and still due
today counts as the part of a card its answers recalled made, recalled answers over those plus the
steps it still needs (`Card.credit`), so every answer recalled moves the ring and Forgot moves
nothing. The ring is full at done ≥ goal, in whole cards, and stays full: done cards beyond the goal
(Catch Up, extra new cards) count as cards done ("31 cards today"). `DailyRing.fraction` is capped
at 1.

**Streak** (RU «стрик»):
Study days in a row that kept it. A day keeps it with its streak step done (done ≥ the first end of
`DayRounds.ends`); an empty plan counts. One missed day is repaired when the next day closes its ring
(done ≥ goal): the streak step of that day is not enough, and then the streak starts anew with
it. Two missed days in a row end the streak. Days before `DailyGoal.planRuleStart` (23.10.2026)
count with one review. The streak is the flame in the middle of every ring: lit once the day has kept it
and is not at risk (`DailyProgress.isStreakLit`), grey otherwise.

**Pace** ("≈ 7 min" / „≈ 7 Min.“; RU «темп»):
Seconds per done card, in two prices (`Pace`): one for cards that were new when their study day
began (no review before the day), one for all others (review, relearning, learning carried over
from an earlier day). The time of a review is how long its card was on screen, from the question
shown to the grade, with the app active (`ReviewLogEntry.duration`, measured in `SessionDriver`;
the time in the background, with the phone locked or behind another app is left out, a card left
open in the active app is not capped). Where a kind has fewer than 20 reviews with a duration, as
in a log from before they were kept, the gap between consecutive reviews of a study day stands in
for the time: it goes to the card of the later review, in the kind that card had that day: the
steps of a new card are new, an Again on a review card and its relearning are other. A kind's price
is the typical seconds per review times the reviews each of its done cards took. With durations the
typical seconds are the mean of the lognormal that the durations of the kind follow, worked out
from the median m and the interquartile range of their logarithms (a duration is at least 1 s, s =
IQR / 1.349): exp(m + s² / 2); a duration has no break in it, as the time in the background is not
recorded, and the mean prices the long right tail of real times. With gaps the typical seconds are
their median: a break of minutes to hours is a gap too, over a quarter of the gaps on some days,
and would spread the logarithms until the lognormal mean ran away from the time a review takes. The
median ignores breaks while they are under half of the gaps; with a share p of breaks it is the 0.5
/ (1 − p) quantile of the work gaps, a little above their median. The reviews per done card are the
reviews of the cards of the kind that were done on the day they were reviewed, over the last 7
study days and today, the first review of each day (it has no gap) included, divided by those done
cards. A card left open at the day's end, in its steps or in relearning, is not done: its reviews,
the Agains among them, are in neither the reviews nor the cards, though the gaps around them still
count for the time of a review. The steps and the Again of a done card are in its price. A kind
with fewer than 20 times or fewer than 10 done cards is priced at 30 s for new and 10 s for other
(`DailyGoal.pace`). The gaps hold the time between cards (menus, the rest screen) as well, so a
price from gaps runs higher than one from durations. Time left = new cards left × new price + other
cards left × other price, in whole minutes (`DailyGoal.minutesLeft`); a new card started today and
still in its steps is among the new cards left (`StudyCounts.newAtDayStart`). The widget knows only
how many cards are left, and keeps one price: the time left over the cards left.
_Avoid_: seconds per review, seconds per answer

**Stack** (Study; RU «стопка дня»):
Study without sessions: the day's plan over all decks, mixed by FSRS's urgency, with a rest after its
streak step ("Streak kept"), then a rest at the ring ("Ring closed", where Catch Up goes on with the
plan); it ends with the plan (`StudyStream`; the type keeps the old name "stream"). A card is never
reviewed before it is due. The paths through a day: `references/learning-flow.md`, "The journey".
_Avoid_: session (except for the upstream types that still carry the name)

**Push On** (DE „Nachlegen“; RU «Поднажать»):
Ten new cards beyond the day's limits once the stack is done, shared over the decks that have new
cards left and asked mixed (`StudyModel.addNewCards`). It raises the stakes: their reviews come in
the next days ("More reviews in the days ahead"); the day's time stays as it is.
_Avoid_: +10 new, extra new cards, Go on

**Words in memory** ("≈ N words in memory"; RU «слов в памяти»):
The number of words the learner would recall right now, from FSRS alone: the sum, over the
recognition cards that have been reviewed and are not suspended, of each card's probability of
recall (`Scheduler.recallProbability`, `MemoryEstimate`). A word is its recognition card (a card
without a kind, from an older deck, is one too); a production card is the same word the other way
round and counts nothing, so a word with two cards counts once. A card never reviewed counts
nothing; one in learning or relearning counts by the same function from its state. Nothing is
stored, and the number is the model's own prediction, so it is honest by construction: it grows
when the learner learns, falls over days without reviews and grows back with the reviews, and no
count of cards or reviews can inflate it. The probability counts whole study days since the last
review, as everywhere in the app: the number moves at the study day's change (04:00), a day
without reviews has a gain of 0, and the fall shows against the day before. It is shown rounded
down, so "≈ 412" never promises more than the model says. The **gain of the day** is now minus the
number at 04:00, which takes each card as it stood before the day's reviews (replayed from its log,
as `DeckActivity.plan` does) and is rounded to the nearest word. **Milestones** are 50, 100, 250,
500, 1000, 1500, 2000, 3000 and 5000: the next one above the number now, and the one crossed
today (the number at 04:00 below it, now at or above it). The decks add up (`MemoryEstimate.total`), and a
word that several decks hold, or one deck holds twice, counts once, at the highest probability among its cards
(**Word key**).
_Avoid_: words learned, vocabulary size, «выученные слова»

**Word key** (on screen: "Word Key" in the card detail, "Also in <deck>", "Similar to … in <deck>"; RU «ключ слова»):
The word a Greek card is about, written `lemma#article` in `Card.note` and compared by `WordKey`. Two cards hold the
same word when the lemma is equal and the articles are compatible: the lemma is cut at a comma, `; `, ` / `, ` · `,
a bracket or ` -` and loses a trailing group of endings (`-ή-ό`); the article counts (`κύριος` is not `ο κύριος`);
`ο/η` matches `ο` and `η` of the lemma; accents stay (`πώς` is not `πως`). Words that differ by an accent only
**look like** each other, and only that is shown. The key is Greek only. `WordIndex` finds the word of a card in other
decks; it sets default ticks and adds lines of text, and merges nothing (`WordKey`, `WordIndex`,
`references/cross-deck-overlap.md`).
_Avoid_: duplicate (a duplicate is an equal question in one deck), merge, «дубликат слова»

**Paused deck** (on screen: "Pause Deck", "Resume Deck", "Paused" / „Stapel pausieren“, „Stapel fortsetzen“,
„Pausiert“; RU «колода на паузе»):
A deck the learner paused (`LearningOptions.isPaused`, the key `paused` in `deck.json`, written only while
true): it takes no part in the day. It is left out of the plan, the goal, the streak step, the day's time, the
admission of new cards (the allowance is split over the other decks), the streak, the words in memory, the
widget, the reminders, Study on Today and the "Next: …" after a stream (`DailyProgress.evaluate`,
`DeckActivity.isPaused`). It stays open: its screen, the card browser and "Study This Deck" work, and the
reviews written there fill the ring only through the cards of the decks that take part. On resume its overdue
reviews are due like any and come back into the plan. The pause travels with the options: a
merge takes it from the version that changed them last, and an older app version drops the key, so the deck is
no longer paused there.
_Avoid_: suspended deck (a card is suspended, `Card.isSuspended`), archived deck, «заморозка»

**Media** (on screen: not shown yet; RU «медиа»):
The images and sounds of a card: at most one image and one sound on each side (`Card.questionImage`,
`questionAudio`, `answerImage`, `answerAudio`, together `CardMedia`), each the name of a file in the
`media` folder of the deck's package. The name is the file's content: the first 16 hex characters of its
SHA-256 and the original extension in lower case, so a file never changes under its name, identical media
are stored once and two versions of a deck join by name (`DeckMedia`). The media of a card are content like
its texts: `Card.contentChanged` stamps a change and a merge takes them from the version that changed the
content last. A package keeps the files some card names; a file no card names is an orphan, and the next
save leaves it out. Anki import brings the first image and the first sound of each side along; a side may
have media and no text. Version 5 of the deck format added them (`DeckFile.currentVersion`).
_Avoid_: attachment, asset, «вложение»
