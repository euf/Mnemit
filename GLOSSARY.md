# Mnemit glossary

A vocabulary trainer: the learner sees a question, reveals the answer, grades themself, and FSRS plans
when they see the card again.

Each entry gives the term in code, which is also the English word on screen unless the entry says
otherwise, then the German word on screen (DE) and the Russian word for talking with EF (RU). The
synonyms under _Avoid_ are not used, in any of the three languages.

## Language

### Cards

**Word** (the learner's unit; DE Wort; RU «слово»):
A note (`Card.note`) with its cards. A card without a note is a word with one card; a pair is Word → Meaning and
Meaning → Word. The learner adds, keeps and counts words; the stream asks cards. **Words learned** counts words.
_Avoid_: vocable, entry, Vokabel, Eintrag

**Card** (DE Karte; RU «карточка»):
A pair of Question and Answer, plus an optional Hint. It is asked in one direction only, from the
Question to the Answer. A Word has one Card or two.
_Avoid_: vocable, entry, index card, Vokabel, Eintrag, Karteikarte

**Question** (DE Frage; RU «вопрос»):
The side of a Card that is shown and asked.
_Avoid_: front, Vorderseite

**Answer** (DE Antwort; RU «ответ»):
The side of a Card the learner recalls and then reveals.
_Avoid_: back, solution, Rückseite, Lösung; "answer" for the Review

**Hint** (DE Hinweis; RU «подсказка»):
An optional addition shown together with the Question.
_Avoid_: remark, Bemerkung

**New card** (DE Neue Karte; RU «новая карточка»):
A Card never yet asked in a Study session. New cards come from one queue over all decks that aren't paused, newest
addition first: what was added on a later day before what was added earlier, within a day as it was added. A word's
Meaning → Word card joins the queue once it opens (see **Word → Meaning / Meaning → Word**) and alternates with the new
words one for one.
_Avoid_: unlearned, unseen

**Addition** (DE Hinzufügung; RU «добавление», «партия»):
The cards a deck got on one study day: Add Cards, a lesson list, an import, a `deck-from-tsv` run. The latest is
the newest batch. Renewing moves cards not started yet into the day's addition.
_Avoid_: import batch, generation

**Suspended card** (DE Ausgesetzte Karte; RU «приостановленная карточка»):
A Card the learner suspended, on the Mac or the iPhone, or that a Leech moment set aside: it is never Due and no
Session asks it until they resume it (Resume; Keep Card at the moment). Its Learning state stays as it was meanwhile.
_Avoid_: ignored, disabled, deferred, buried

**Leech** (DE Lernbremse; RU «приставучая»; EL βδέλλα):
A Card forgotten as often as its Deck's threshold says: its Forgots, the first answer of a new card apart, have reached
`LearningOptions.leechThreshold` (8 by default, 0 is off; `Card.isLeech(threshold:)`). The file holds no flag: the state
follows the log, so a card put back in
rotation is still a leech. The learner meets it at the **Leech moment**.
_Avoid_: Difficult, hard card, hard word, «пиявка»

**Leeches** (the filter of a deck's Cards; DE Lernbremsen; RU «приставучие»; EL βδέλλες):
Every card that is a Leech, suspended or not (`CardFilter.leeches`). Empty it says "Words you keep forgetting appear here."

### Reviewing and grading

**Review** (DE Abfrage; RU «оценка»):
Asking a Card once and grading it.
_Avoid_: answer, repetition, rep, Wiederholung, «повторение»

**Review mode** (DE Abfrageart; RU «способ оценки»):
How a Review is logged: Revealed (DE Aufgedeckt), the learner reveals the Answer and gives the Grade, which is
every Review the apps log; or Typed (DE Getippt), a value that logs of upstream decks still carry (the card's
history marks it "Typed"). Both apps ask by revealing: question, Show Answer, grade. A Revealed Review counts
in full, like any Review in FSRS.
_Avoid_: flashcard mode (for the review mode)

**Grade** (DE Bewertung; RU «вариант оценки»):
How well the learner knew a Card: Again, Hard, Good or Easy. The learner decides it.
_Avoid_: rating, mark, score

**Again** (on the button: Forgot; DE Nochmal; RU «забыл»):
The Grade for a Card the learner didn't know. The scheduler calls it Again; its button and swipe
say Forgot, and Don't know on a card's first showing.
_Avoid_: failed, wrong

**Recalled** (DE Gewusst; RU «вспомнил»):
Any Grade except Again.
_Avoid_: correct

**Mistake** (DE Fehler; RU «ошибка»):
A Card that got Again at least once in a Session.
_Avoid_: failed card, "answered wrong"

**Lapse** (DE Vergessen; RU «провал»):
Again for a Card in the Review phase; it falls into Relearning. The Card counts its lapses (`lapses`); enough of them make
it a Leech.
_Avoid_: forgotten, "forgotten card" as a term

**Leech moment** (on screen "Keeps slipping"; DE „Entgleitet immer wieder“; RU «момент приставучей карточки»):
The stop in the stack right after the Forgot that makes a Card a Leech, before the next card (`LeechMomentView`,
`SessionDriver.leechMoment`). The question and the answer stay on screen under a sentence that counts the lapses, with **Continue**,
**Edit** and **Suspend Card**. A
moment is the lapse that brings the lapses to the threshold T and every ceil(T / 2) lapses after that: 8, 12, 16, 20 for
T = 8 (`StudySession.isLeechMoment`). Undoing the grade takes the moment back.
_Avoid_: leech alert, leech warning

**Leech threshold** (the deck option, Anki's name for it; DE Schwellenwert Lernbremse; RU «порог для приставучих»):
`LearningOptions.leechThreshold`, the lapses that make a Card a Leech: 8 by default, "Off" (0) never marks one. The row shows
"Off" or "N lapses".

**Leech action** (the deck option, Anki's name for it; DE Aktion bei Lernbremsen; RU «что делать с приставучими»):
`LearningOptions.leechAction`: what a Leech does to its Card, **Keep Card** or **Suspend Card**.

**Keep Card** (the Deck's leech action, the default; DE Karte behalten; RU «оставить карточку»):
A Leech stays in rotation and FSRS goes on scheduling it (`LeechAction.keep`). An Anki import maps Anki's "tag only" action
to it.

**Suspend Card** (the Deck's other leech action; DE Karte aussetzen; RU «приостановить карточку»):
The review that makes a Card a Leech suspends it, and the card leaves the stack (`LeechAction.suspend`). Learning options
offer Keep Card and Suspend Card as the Leech action.

**Suspend Card** / **Keep Card** at the Leech moment (the same words as the Deck's leech action):
Suspend Card suspends the card from the moment and the stack goes on without it (`SessionCommand.setAside`). When the Deck's
action is Suspend the review has done that already, and the button reads Keep Card: it resumes the card and the stack asks it
again (`SessionCommand.keep`). Both are undoable.
_Avoid_: Set Aside, Keep It, bury, skip

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

**Learning steps** (the deck option, Anki's name for it; DE Lernstufen; RU «шаги изучения»):
`LearningOptions.steps`, how many Steps a Card needs to reach the Review phase: 2 by default, 1 to 5. A count of Good
grades, with no time delay between them.

**Stability** (DE Stabilität; RU «стабильность»):
The number of days until a Card's Recall probability falls to 90 %.

**Difficulty** (DE Schwierigkeit; RU «сложность»):
How hard a Card is for the learner, from 1 to 10.

**Recall probability** (DE Abrufwahrscheinlichkeit; RU «вероятность вспомнить»):
The estimated chance of knowing a Card now; "retrievability" in FSRS. The time since the last Review
counts in whole Study days, so on the day of a Review it is 100 %.
_Avoid_: retrievability, chance of remembering

**Desired retention** (the deck option, Anki's and FSRS's name for it; DE Gewünschte Erinnerungsquote; RU «желаемое усвоение»):
The Recall probability at which a Card in the Review phase is asked again (`LearningOptions.targetRecall`, 70 to 97 %, 90 %
by default). The section is called FSRS on the options screens.
_Avoid_: target recall; "retention" alone is the measured rate

**Retention** (DE Behaltensquote; RU «фактическая запоминаемость»):
The share of a Card's Reviews in the Review phase the learner recalled (Hard, Good or Easy), per
period and split by Interval under 21 Study days (Young) and from 21 (Mature); "true retention" in
Anki. It shows what the Desired retention actually achieves. Not counted: Reviews in Learning and
Relearning, the first Review of a New card, and further Reviews on the same Study day. Code:
`TrueRetention`.
_Avoid_: true retention, retention for the Desired retention

**Parameters** (DE Parameter; RU «параметры»):
The 21 weights of the FSRS model, per Deck in the Learning options. They start with the defaults of
open-spaced-repetition and can be computed from the Deck's Review log. Only Reviews on a later Study
day than the previous Review of the same Card count for that, and only from Cards whose Review log
reaches back to the first Review.

**Interval** (DE Abstand; RU «интервал»):
The number of Study days until a Card in the Review phase is asked again.
_Avoid_: review date, pause

**Maximum interval** (the deck option, Anki's name for it; DE Höchstintervall; RU «максимальный интервал»):
`LearningOptions.maximumInterval`, the longest Interval FSRS gives a Card: 36500 days by default, which holds no card back;
30 days at least.

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
The settings that apply to one Deck, such as Desired retention, Learning steps and New cards/day. The screens use Anki's
names; each row has a "?" with plain words for a newcomer.
_Avoid_: deck settings, Einstellungen

**Restore Defaults** (Anki's term; DE Standardwerte; RU «вернуть значения по умолчанию»):
The button at the bottom of the options screens. After a confirmation it puts every option of the Deck back to
`LearningOptions()` and keeps the FSRS Parameters, the note of the last automatic fit and the pause
(`LearningOptions.restoringDefaults()`). One undo step on the iPhone; on the Mac it fills the sheet, and Save applies it.

**New cards/day** (the deck option, Anki's name for it; DE „Tageshöchstwert für neue Karten“; RU «новых карточек в день»):
`LearningOptions.newCardsPerSession`, Auto by default, the ring decides. A deck that sets it takes exactly that many new cards a study day,
of both directions, as in Anki: outside the day's allowance (**Admission**), and without reducing what the other decks
get. It is the one option for new cards.
_Avoid_: new cards per session, new-card limit, quota

**Maximum reviews/day** (the deck option, Anki's name for it; DE „Tageshöchstwert für Wiederholungskarten“; RU «максимум повторяемых в день»):
`LearningOptions.maximumReviewsPerDay`, No limit by default: every Review that is due is asked. A number is the most cards in the
Review phase a study day asks from the Deck; Reviews already made today count against it, and the due ones beyond it
wait for the next days, the most urgent first. Learning cards and New cards are not part of it.
_Avoid_: review limit, review quota

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
The predecessor app. Mnemit reads none of its documents.

**Level** (RU «уровень»):
A card's stage in MacVocTrain 1, which fixed its next interval. Stability takes its place in Mnemit
(`docs/adr/0001-fsrs-instead-of-levels.md`).

## Mnemit: the day, the ring, the streak

Terms of the fork. Each entry gives the term in code, the words on screen (EN / DE) and the
Russian word. The product model, the one description of what Mnemit is, is `references/product-model.md`; this section
names its terms. Seven entities appear on screen: **Deck**, **Card**, **Stack**, **Ring**, **Streak**, **Words learned**
and **Medal**. The rule behind the numbers: **a card is never a review, and a review is never a card.**
A day is measured in cards; reviews only price the time. The day has a time in seconds, and the app learns it from the work
the learner really does. Minutes on screen ("≈ 2 min") translate cards into a decision and are estimates at the
learner's own pace.

**Review** (on screen: not counted; RU «оценка»):
One grade of one card, as above: one swipe, button or key. A card can take several reviews on
one study day: the steps of a new card, an Again and its relearning. The review log
(`reviews.jsonl`) holds reviews. Counts of reviews are for the optimizer, statistics and pace,
never for the goal, the ring or the streak.
_Avoid_: card, answer (the answer is a side of the card), повторение, ответ

**Plan** (today's plan / heutiger Plan; RU «план дня»):
The cards a study day asks, as FSRS sets them: every review card due, overdue ones included,
cards in learning, and new cards: the deck's share of the allowance (`newCardAllowance`), or exactly its
New cards/day where it sets one (`StudySession.counts`).
_Avoid_: session, queue, due count

**Streak step** (RU «шаг стрика»):
The cards of the plan that fit the first 120 s of work at the learner's pace (`DailyGoal.streakSeconds`).
A card costs the pace of its kind, new at the day's start or other. The step ends at the first card
where the cost reaches 120 s, and the goal ends the day: `DayRounds.ends` has at most two ends, one
when they coincide. Doing the step keeps the streak (`DailyProgress.streakKeptToday`) and Study rests
there once; the goal is the ring's rest. `DailyProgress` holds `rounds` (the number of ends),
`roundsDone`, `roundEnds`, `cardsToNextRound` and `minutesToNextRound`, at the pace the day began with.
A day that began with an empty plan cuts the cards as they stand. Before the step the next-moment figure of Today says
"To keep your streak" over "≈ 2 min"; How It Works names the step (`references/learning-flow.md`).
_Avoid_: round, session, lap, segment

**Day's time** (RU «время дня»):
The seconds of work the day asks, 120 to 3600, never rounded (`DailyProgress.time`). It comes from the
review logs alone, forward from the first study day, so every device that reads the same logs gets the
same: 150 s before any study; then a staircase on the last study day (a day with work): times 1.15 when its ring was
the second (fourth, …) in a row closed on a goal that filled the time, the same time after the first of such a run
or a ring closed on a smaller plan, times 0.775 when it stayed open; above it the sustained-overshoot step from the 8th
study day (rule D, `DailyGoal.nextTime(after:)`): when the work reached 1.5 × the day's time on 3 of the last 4 study days
(a day **past the ring**, the label of the Why column in How It Works), the time becomes the larger of the staircase's and
the 25th percentile of those four days' work, at most × 1.5 a day. Held to 120 to 3600. The learner is never told the rule.
Nothing else changes it. The day's time sets the goal and the admission of new cards.
_Avoid_: capacity, limit, quota, level

**Admission** (new-card allowance; RU «допуск новых»):
The new cards a day takes in: the time of the day less the day's plan cards that are not new, at
the pace the day began with (the seven study days before it), over the price of a new card, at
least 0 (`DailyGoal.newCardsAllowed`). The allowance is shared between the decks without New cards/day from one
queue over them (new words newest addition first, opened Meaning → Word cards alternating one for one):
`DailyGoal.split(_:overQueues:)` over each deck's `DailyGoal.NewQueue`. Each deck's share is its
`newCardAllowance`, which the plan takes (`DailyProgress.newCardAllowances`). A deck with New cards/day
takes its own count outside the allowance. Cards first reviewed today count against it, and Learn 10 New Words comes
beyond it and beyond New cards/day.
_Avoid_: new-card limit, daily new cards

**Daily goal** (in code and How It Works only, as "Daily goal (cards)"; DE „Tagesziel“; RU «цель дня»):
The cards of the plan, as it stood when the study day began at 04:00, that fit the day's time:
learning cards and reviews in the stream's order, then new cards, at the day's prices, up to the
time in seconds; at least one card if the plan has any (`DayRounds.goal`). With admission the
plan normally fits. After a break the reviews beyond the day's time stay in the plan and are done
beyond the goal. The goal stays for the day: cards added later, Learn 10 New Words, Study These Now and an Again don't raise
it. A day that began with an empty plan takes the plan as it stands (`DailyGoal.goal`).
_Avoid_: reviews goal, target, quota

**Done card** (the cards the ring counts; RU «сделанная карточка»):
A card whose last review of the study day left it due on a later day: FSRS let it go. A review
card answered Hard, Good or Easy is done at once; a new card after its last learning step; a
card answered Again once it leaves relearning. It counts once a day, however many reviews it
took (`DeckActivity.done`). A card deleted afterwards stays done (**Retired card**).
_Avoid_: reviewed card, answered card, «повторённая карточка»

**Retired card** (RU «списанная карточка»):
A card deleted after it had reviews (`Deck.retiredCards`, the key `retired` in `deck.json` from format version 6). Its answers
stay in the Review log and in the done count of the days it was done, so deleting a card never moves the ring back. It is in
no plan, count, browser, search, export, Words learned or statistics, and it still feeds the FSRS refit. A deleted card
without reviews is simply gone.
_Avoid_: deleted card, archived card

**Progress record** (code `LedgerDay`, all of them `DayLedger`, "the ledger"; RU «запись дня», «журнал дней»):
What the app keeps of a study day once it is over: reviews, done cards, the goal, the cards that keep the streak, kept,
closed, the day's time and its reason, the seconds worked, the words learned by its end. The past days of the ring, the
streak, the week, the medals and Words learned read these records; today is always worked out live from the logs. A record
only rises, when late reviews of that day arrive (another device's log, an Anki import). `DailyProgress.ledgerUpdates` lists
the days to write. Each device writes its own file, `.mnemit-progress/<device id>.jsonl` in the deck folder, holding the merge
of every file it has read (`references/daily-ring.md`, `references/deck-package.md`).
_Avoid_: history (that is the Review log), Daily snapshot (a Deck's cards by stability), statistics

**Backlog** (RU «хвост»):
Overdue cards, part of the plan, worked off as the day's time allows: after the ring they are the cards of Keep Going, priced
as "≈ 12 min of reviews left".

**Ring** (RU «кольцо»):
How far today is: done cards against the daily goal, with the **cards underway**: a card reviewed today and still due
today counts as the part of a card its answers recalled made, recalled answers over those plus the
steps it still needs (`Card.credit`), so every answer recalled moves the ring and Forgot moves
nothing. The ring is full at done ≥ goal, in whole cards, and goes on over itself past it, as the Fitness rings do,
to three laps: done cards beyond the goal (Keep Going, Learn 10 New Words, Study These Now) draw the second and third lap.
`DailyRing.fraction` is capped at 1 and says whether the goal is met; the drawing takes
`DailyRingFigure.fraction`. Past days draw their own share of their goal (`DayRecord.ringShare`). The ring is a picture: it holds
no number and no flame at any size, and the streak and the minutes are figures beside it (**Today card**).
_Avoid_: progress bar, goal ring, «счётчик»

**Streak** (RU «стрик»):
Study days in a row that kept it. A day keeps it with its streak step done (done ≥ the first end of
`DayRounds.ends`); an empty plan counts. One missed day is repaired when the next day closes its ring
(done ≥ goal): the streak step of that day is not enough, and then the streak starts anew with
it. Two missed days in a row end the streak; the best run stays in Progress. Days before `DailyGoal.planRuleStart` (23.10.2026)
count with one review. On screen the streak is the figure **Day streak**, the **Streak line** and "🔥 12" in the stream's
header; the sentences say no days: "≈ 2 min to keep your streak", "≈ 6 min to close the ring and save your streak"
(**Flame**).
_Avoid_: streak chip, series, «серия»

**Flame** (the streak's sign on every screen; RU «пламя»):
The streak's symbol, drawn by `StreakFlame(state:)` from the `StreakState` of the day
(`DailyProgress.streakState`), with three states in shape and colour: **open**, a grey outline, while today's
streak step is not done; **kept**, `flame.fill` in `Color.streak`, once it is done; **at risk**, an outline in
`Color.streak` followed by an `exclamationmark`, on the day after a missed one until the ring closes
(`DailyProgress.isStreakAtRisk`). It stands in the Day streak figure on Today and in the small widget, in the Streak line of
the rests and the rectangular widget, and on the streak card at the top of Progress; it is never inside a ring.
VoiceOver says the state: "12-day streak, kept today", "not kept yet" or "at risk".
_Avoid_: lit and unlit flame, streak icon

**Day streak** (the figure; DE „Tage in Folge“; RU «дней подряд»):
The streak as a figure (`StreakFigure`): the label "Day streak" over the flame and the days in `Color.streak`, in
secondary at 0 days. It is the first figure of the **Today card** and the small widget's.

**Streak line** (`StreakLine`; RU «строка стрика»):
The flame and "12-day streak" (`NextStep.streakText`) in one line, in the same form all day: on the rests, in the rectangular
widget. Hidden at 0 days.

**Today card** (on screen the first card of Today; DE „Heute“; RU «карточка дня»):
The picture of the day (`TodayCard`): the ring on the left, its three figures on the right (the **Day streak**, the next
moment of the day with its "≈ 2 min", **Words learned** with "+N today"), the week of small rings under a divider; the whole
card opens Progress. The Mac's Today page draws the same card, and an empty Mnemit an empty one (`EmptyTodayCard`). A deck's
screen opens with its own, `DeckTodayCard`: "≈ 4 min" and the figures Due, New, Learning.
_Avoid_: hero, summary, header

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
The cards left before the next moment of the day, drawn as up to four edges under the card, fewer at the end, never as a
number. Study without sessions: the day's plan over all decks, mixed by FSRS's urgency, in a stack that ends at each
moment (**Streak kept**, **Ring closed**, **All done**); after the ring the stack is the cards of Keep Going, of Learn 10 New
Words or of Study These Now. It ends with the plan (`StudyStream`; the type keeps the old name "stream"). A card is never
reviewed before it is due. The paths through a day: `references/learning-flow.md`, "The journey".
_Avoid_: session (except for the upstream types that still carry the name)

**Learn 10 New Words** (the button of the stack's end; DE „10 neue Wörter lernen“; RU «Выучить 10 новых слов»):
Ten new cards beyond the day's allowance and New cards/day, shared over the decks that have new cards
left and asked mixed (`StudyModel.addNewCards`). It raises the stakes: their reviews come in the next days;
the day's time stays as it is. Today carries it as the third button of the day after Study and Keep Going
(`DayAction`), the rests and the deck screen as well. The code keeps the old name `DayAction.pushOn`,
`StudyModel.Entry.pushOn`.
_Avoid_: +10 new, extra new cards, Go on

**Words learned** ("412 words learned · +12 today", "Words learned" in the totals of Progress; DE „Gelernte Wörter“; RU «выученные слова»):
The gain the app headlines: whole words whose Word → Meaning card has left learning, is in the review phase, is not
suspended and lies in an active deck (`WordsLearned`). A card without a kind counts as a word; a word held twice (the same
**Word key**) counts once, a card without a key is a word of its own. A lapse takes the word out until it is relearned. The
**gain of the day** (`shownGain`, "+12 today") is the count now less the count at 04:00 from the card states before the day's
reviews, and is left out on a day that has none. Words-learned medals: 10, 50, 100, 250, 500, 1000, then every 1000.
_Avoid_: words in memory (the sum of recall probabilities, a detail), vocabulary size

**Medal** (DE Medaille; RU «медаль»):
A moment worth remembering, shown as a toast when it is earned and kept on the shelf of Progress (All Medals): streak
milestones (3, 7, 14, 30, 61, 91, 183, 365, 548, 730 days), First ring, Perfect week, Comeback, **Double ring** and
**Triple ring**, and Words learned. A medal is for consistency and gain, never for the cards answered. The next tier of
a line shows as a grey medal.
_Avoid_: badge (that is the "1" on the app's icon), achievement (the code's name, `Achievement`), «достижение»

**Double ring** / **Triple ring** (DE „Doppelter Ring“ / „Dreifacher Ring“; RU «Двойное кольцо» / «Тройное кольцо»):
Medals for a day whose ring reached two or three laps of the goal (`DayRecord.ringShare` ≥ 2 or 3). They are earned on
the first such day, derived from the day records, so history earns them; a three-lap day earns both. The goal's size keeps
them rare (sustained overshoot, **Day's time**).

**Streak kept** (the first moment of the day; DE „Serie gehalten“; RU «стрик сохранён»):
The end of the first stack, when the streak step is done: today counts in the streak and the flame fills. The rest shows the
streak, the medal and the price of the ring, with **Keep Going** and **Done for Now**. After a missed day there is no such
rest: only the closed ring keeps the streak ("Streak saved").

**Ring closed** (the second moment; DE „Ring geschlossen“; RU «кольцо закрыто»):
The end of the stack that closes the goal: the day's learning is done and the ring bursts. The rest shows the medal, the
words learned, the week and "≈ 12 min of reviews left" when due cards remain, with **Keep Going** (the default) and **Done for Now**,
or **Done** and **Learn 10 New Words** when none remain.

**All done** (the third moment; on screen "All done for today"; DE „Alles für heute erledigt“; RU «всё на сегодня сделано»):
The end of the plan's last due card, Keep Going included: nothing is due until tomorrow. It is also the title of a rest that
stands where the ring's moment lies behind the stream. On most days the ring takes the whole plan and this moment does not
exist.

**Study These Now** (the button of Add Cards and of the import into a new deck; DE „Diese jetzt lernen“; RU «Учить их сейчас»):
A stream over the one deck the cards went to: the cards just added first, then that deck's plan (`StudyModel.Entry.studyNow`,
`StudyStream.addCards`). It asks only the cards a stream would ask now (new, unlocked and not buried, so the Meaning → Word card of a word waits until its
Word → Meaning card has an interval of 7 days). The added cards go beyond New cards/day and take the place of the day's new
cards, counting against the allowance, so tomorrow's load is the same as if the queue had chosen them, and they count toward
the ring and its laps. The import offers it for a table of 1 to 50
cards into an empty deck.
_Avoid_: Study Now, Learn Added, «учить добавленные»

**Word → Meaning / Meaning → Word** (the direction of a card; DE „Wort → Bedeutung“ / „Bedeutung → Wort“;
RU «Слово → значение» / «Значение → слово»):
Which side a card asks. Word → Meaning is the recognition card (`CardKind.recognition`): the Greek word, the
learner gives the meaning. Meaning → Word is the production card (`CardKind.production`): the meaning, the
learner gives the Greek word. The card detail shows it as the row Direction, the Mac's table as the Kind
column (`CardKind.title`). A word's Meaning → Word card opens when its Word → Meaning card is in the review phase with
an interval of 7 days or more (`StudySession.unlockDays`, a constant); opened cards alternate with the new words one for
one, the oldest learned word first. No option sets either.
_Avoid_: Greek → translation, translation → Greek, direction (alone, on screen)

**How It Works** (DE „So funktioniert es“; RU «Как это работает»):
The screen that tells the learner the three moments of the day in plain sentences (the first minutes keep the streak; the
ring is the goal and Keep Going studies the reviews waiting; nothing due means all done), and then the numbers under the day:
the plan, the day's time, the pace, the streak, the words in memory, the swipes (iPhone), the options and the FSRS figures of
each deck. The last row of the Progress screen; on the Mac a sheet of the Progress page. The types keep the old name:
`HowTodayWorks`, `HowTodayWorksView`.
_Avoid_: How Today Works, statistics (those are of a deck)

**Don't know / Know** (the names of the two buttons on a card's first showing; DE „Weiß ich nicht“ / „Weiß ich“; RU «Не знаю» / «Знаю»; EL «Δεν ξέρω» / «Ξέρω»):
The names of the grades Again and Good while the card has no learning state (`Card.isNew`), in the buttons, the receipt chip,
VoiceOver and the history of Card Detail. On every later showing the same buttons read **Forgot** and **Good**. The grades,
the positions, the keys, the swipes and the colours are the same, and FSRS records Again and Good as it does for any card
(`Grade.buttonTitle(isNew:)`, `docs/adr/0007-first-showing-is-asked-as-dont-know.md`).
_Avoid_: introduction, new word (as a card state), unknown

**Hard and Easy Buttons** (the setting of Preferences, `ShowsFourAnswerButtons`; DE „Tasten für Schwer und Leicht“; RU «Кнопки „Трудно“ и „Легко“»; EL «Κουμπιά Δύσκολο και Εύκολο»):
Every showing has two wide buttons, Forgot and Good. With the setting on, a card's later showings have four: Forgot on a row
of its own, Hard, Good and Easy under it, Good the widest (`GradeChoice.buttonGrades`). A first showing stays two. Hard and
Easy come with their buttons and only then: the swipe down and up on the iPhone, the keys 2 and 4 on the Mac.
_Avoid_: four-button mode

**Words in memory** ("In memory now" in How It Works, the Memory section of Progress; DE „Wörter im Gedächtnis“; RU «слов в памяти»):
The number of words the learner would recall right now, from FSRS alone: the sum, over the
recognition cards that have been reviewed and are not suspended, of each card's probability of
recall (`Scheduler.recallProbability`, `MemoryEstimate`). A word is its recognition card (a card
without a kind, from an older deck, is one too); a production card is the same word the other way
round and counts nothing, so a word with two cards counts once. A card never reviewed counts
nothing. Nothing is stored; the number is the model's own prediction: it grows when the learner learns, falls over days
without reviews and grows back with the reviews. The probability counts whole study days since the last review, so the
number moves at the study day's change (04:00). The decks add up (`MemoryEstimate.total`), and a word that several decks
hold, or one deck holds twice, counts once, at the highest probability among its cards (**Word key**). It is a detail for
the learner who looks; the gain Today headlines is **Words learned**.
_Avoid_: vocabulary size

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
true): it asks nothing of the day. It is left out of the plan, the goal, the streak step, the day's time, the
admission of new cards (the allowance is split over the other decks), the widget's count, the reminders, Study on
Today and the "Next: …" after a stream (`DailyProgress.evaluate`, `DeckActivity.isPaused`). What was done in it
counts like any work: the cards done, the pace, the streak, the words in memory and the words learned, so a pause
takes nothing from today, the ring closed with its cards stays closed. It stays open: its screen, the card browser
and "Study This Deck" work, and what is studied there fills the ring like Learn 10 New Words. On resume its overdue
reviews are due like any and come back into the plan. The pause travels with the options: a
merge takes it from the version that changed them last, and an older app version drops the key, so the deck is
no longer paused there.
_Avoid_: suspended deck (a card is suspended, `Card.isSuspended`), archived deck, «заморозка»

**Sidebar** (the Mac's; RU «боковая панель»):
The left column of the Mac's one window: Today with the cards left of the day as its badge, Progress, then the
decks in the sections Decks, Paused and Other Decks, each with its cards left as the badge. The pages are
chosen there; the stream takes the whole window and hides it until Done (`Shell`, `SidebarContent`).
_Avoid_: deck list, navigator, «список колод»

**Other Decks** (on screen: "Other Decks" / „Weitere Stapel“; RU «другие колоды»):
The sidebar section for decks opened from outside the Mnemit folder, from Finder or Open Deck…, until the app
quits. A deck of the folder is never listed there.
_Avoid_: recent decks, external decks

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
