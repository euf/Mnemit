# MacVocTrain NG

Ein Vokabeltrainer für den Mac. Der Lernende tippt zu einer Frage seine Eingabe, bewertet
sich selbst, und FSRS plant, wann er die Karte wiedersieht.

Stichwort ist der Begriff im Code, dahinter das deutsche Wort der Oberfläche. Beide gelten;
die Synonyme unter _Vermeiden_ nicht.

## Language

### Karten

**Card** (Karte):
Ein Paar aus Question und Answer, dazu ein optionaler Hint. Sie wird nur in eine Richtung
abgefragt, von der Question zur Answer.
_Vermeiden_: Vokabel, Eintrag, Karteikarte, Index card, Word, Entry

**Question** (Frage):
Die Seite einer Card, die gezeigt und abgefragt wird.
_Vermeiden_: Front, Vorderseite

**Answer** (Antwort):
Die erwartete Antwort einer Card; sie kann mehrere Alternatives enthalten.
_Vermeiden_: Back, Rückseite, Lösung; „Antwort“ für die Response oder die Review

**Alternatives** (Alternativen):
Mehrere gleichwertige Teile einer Answer, durch `/` getrennt. Ihre Reihenfolge ist egal;
wer nur einen Teil nennt, antwortet Incomplete. Besteht eine Answer oder Response nur aus
`/` und Leerraum, etwa `/`, ist sie als Ganzes eine einzige Alternative.
_Vermeiden_: Varianten, Synonyme

**Hint** (Hinweis):
Ein optionaler Zusatz, der zusammen mit der Question gezeigt wird.
_Vermeiden_: Remark, Bemerkung

**New card** (Neue Karte):
Eine Card, die noch nie in einer Study session abgefragt wurde.
_Vermeiden_: ungelernt, unseen

**Suspended card** (Ausgesetzte Karte):
Eine Card, die der Lernende ausgesetzt hat, auf dem Mac oder dem iPhone: Sie ist nie Due,
keine Session fragt sie ab, bis er sie auf dem Mac wieder aufnimmt (Resume). Ihr Learning
state bleibt derweil, wie er war.
_Vermeiden_: ignoriert, deaktiviert, zurückgestellt, Buried

### Abfragen und Bewerten

**Review** (Abfrage):
Einmal eine Card abfragen und bewerten.
_Vermeiden_: Answer, Antwort, Wiederholung, Rep

**Response** (Eingabe):
Was der Lernende auf eine Question hin eintippt.
_Vermeiden_: Answer, „deine Antwort“

**Review mode** (Abfrageart):
Wie eine Review lief: Typed (Getippt), der Lernende tippt eine Response, und die App
schlägt eine Grade vor; oder Revealed (Aufgedeckt), der Lernende deckt die Answer auf und
gibt die Grade ohne Response. Der Mac fragt Typed ab oder, im Modus „Flashcards“, Revealed;
das iPhone fragt Revealed. Eine Revealed Review, die die Card weiß, behält den Anteil
`revealedRecallWeight` der Stabilität, die FSRS hinzurechnet (im Fork voreingestellt 1,
einstellbar bis herunter auf ein Drittel); siehe `docs/adr/0004-aufgedeckte-abfragen-gedaempft.md` und
`docs/adr/0005-aufgedeckte-abfragen-zaehlen-im-fork-voll.md`.
_Vermeiden_: Karteikarten-Modus

**Check result** (Prüfergebnis):
Wie die Response zur Answer passt: Correct, Incomplete, Almost correct oder Wrong. Es
schlägt eine Grade nur vor.
_Vermeiden_: Bewertung, Urteil

**Correct** (Richtig):
Die Response enthält alle Alternatives der Answer.
_Vermeiden_: „richtig“ für eine Grade, siehe Recalled

**Incomplete** (Unvollständig):
Die Response enthält nur einen Teil der Alternatives und nichts Falsches.

**Almost correct** (Fast richtig):
Die Response verfehlt die Answer nur um wenige Tippfehler oder die Groß- und
Kleinschreibung. Wie viele Tippfehler, hängt von der Länge der Alternative ab: unter 4
Zeichen keiner, ab 4 einer, ab 8 zwei.
_Vermeiden_: Typo, Tippfehler (als Ergebnis)

**Wrong** (Falsch):
Die Response ist weder Correct, Incomplete noch Almost correct, oder sie ist leer.
_Vermeiden_: „falsch“ für eine Grade, siehe Again

**Grade** (Bewertung):
Wie gut der Lernende eine Card wusste: Again, Hard, Good oder Easy. Die App schlägt eine
Grade vor, entscheiden tut der Lernende.
_Vermeiden_: Rating, Note, Score

**Again** (Nochmal):
Die Grade für eine Card, die der Lernende nicht wusste.
_Vermeiden_: failed, Wrong, falsch

**Recalled** (Gewusst):
Jede Grade außer Again.
_Vermeiden_: Correct, richtig

**Mistake** (Fehler):
Eine Card, die in einer Session mindestens einmal Again bekam.
_Vermeiden_: failed card, „falsch beantwortet“

**Lapse** (Vergessen):
Again für eine Card in der Review phase; sie fällt damit in Relearning.
_Vermeiden_: forgotten, „vergessene Karte“ als Begriff

### Lernstand

**Learning state** (Lernstand):
Was die App über das Gedächtnis des Lernenden zu einer Card weiß: Phase, Stability,
Difficulty, wann sie Due ist und wie viele Reviews und Lapses sie hatte. Eine New card hat
keinen. Zurücksetzen macht die Card wieder zur New card und leert ihr Review log; ein Merge
lässt die Reviews von davor auch aus der anderen Fassung weg.
_Vermeiden_: Memory state, Memory, Gedächtnis; Reset progress, Lernfortschritt zurücksetzen

**Phase** (Phase):
Wo eine Card im Lernen steht: Learning, Review phase oder Relearning. Eine New card hat
noch keine.

**Learning** (Lernend):
Die Phase einer Card nach ihrer ersten Review, bis sie genug Steps gesammelt hat.
_Vermeiden_: „Lernend“ als Maturity, siehe Shaky

**Review phase** (Wiederholungsphase):
Die Phase einer gelernten Card, die erst nach einem Interval wieder drankommt.
_Vermeiden_: Review (für die Phase), Wiederholung (ohne „-phase“), graduated

**Relearning** (Erneut lernen):
Die Phase einer Card nach einem Lapse, bis sie wieder genug Steps gesammelt hat.
_Vermeiden_: Neu lernen

**Step** (Lernschritt):
Eine Good für eine Card in Learning oder Relearning. Hard hält die Card auf ihrem Step,
Again setzt sie auf null zurück, Easy bringt sie sofort in die Review phase.
_Vermeiden_: Learning step als Zeitstufe (wie in Anki), „richtige Antwort“

**Stability** (Stabilität):
Die Zahl der Tage, bis die Recall probability einer Card auf 90 % fällt.

**Difficulty** (Schwierigkeit):
Wie schwer eine Card dem Lernenden fällt, von 1 bis 10.

**Recall probability** (Abrufwahrscheinlichkeit):
Die geschätzte Chance, eine Card jetzt zu wissen; in FSRS „retrievability“. Die Zeit seit
der letzten Review zählt in ganzen Study days, am Tag einer Review ist sie also 100 %.
_Vermeiden_: Retrievability, chance of remembering, Erinnerungswahrscheinlichkeit

**Target recall** (Angestrebte Abrufquote):
Die Recall probability, bei der eine Card in der Review phase wieder abgefragt wird; in FSRS
„desired retention“.
_Vermeiden_: Desired retention; „Retention“ und „Behaltensquote“ heißen die gemessene Quote

**Retention** (Behaltensquote):
Der Anteil der Reviews einer Card in der Review phase, die der Lernende wusste (Hard, Good
oder Easy), je Zeitraum und getrennt nach Interval unter 21 Study days (Young) und ab 21
(Mature); in Anki „true retention“. Sie zeigt, was die Target recall tatsächlich erreicht.
Nicht gezählt werden Reviews in Learning und Relearning, die erste Review einer New card und
weitere Reviews am selben Study day. Code: `TrueRetention`.
_Vermeiden_: True retention, Retention für die Target recall

**Parameters** (Parameter):
Die 21 Gewichte des FSRS-Modells, je Deck in den Learning options. Sie beginnen mit den
Standardwerten von open-spaced-repetition und lassen sich aus dem Review log des Decks
berechnen. Dafür zählen nur Typed Reviews an einem späteren Study day als die vorige Review
derselben Card, und nur von Cards, deren Review log bis zur ersten Review reicht.

**Interval** (Abstand):
Die Zahl der Study days, bis eine Card in der Review phase wieder abgefragt wird.
_Vermeiden_: Wiederholungstermin, Pause

**Study day** (Lerntag):
Ein Tag, der um 4 Uhr morgens beginnt. Intervals zählen in Study days.
_Vermeiden_: Kalendertag, Tag

**Due** (Fällig):
Eine Card, die in der nächsten Study session drankommen kann: jede New card, jede Card in
Learning oder Relearning und jede Card, deren Interval abgelaufen ist, außer einer
Suspended card.
_Vermeiden_: anstehend, offen

**Maturity** (Reifegrad):
Wie gut eine Card sitzt, nach ihrer Stability: New (Neu), Shaky (Unsicher, unter 4 Tagen
oder in Learning oder Relearning), Young (Jung, 4–16 Tage), Maturing (Gefestigt,
16–64 Tage), Mature (Sicher, 64–256 Tage), Mastered (Gemeistert, ab 256 Tagen).
_Vermeiden_: Status, Learning, Lernend

### Stapel

**Deck** (Stapel):
Eine Sammlung von Cards mit ihren Learning options und ihrem Progress, gespeichert in einer
Datei. Sein Name ist der Dateiname.
_Vermeiden_: Dokument, Datei, Kartei, Box, Index card box

**Merge** (Zusammenführen):
Zwei Fassungen desselben Decks zu einer machen, etwa die von Mac und iPhone nach einem
Konflikt auf iCloud Drive. Die Review logs beider zählen; Cards und Learning options kommen
aus der Fassung, deren Inhalt zuletzt geändert wurde. Reviews ändern den Inhalt nicht,
Aussetzen auch nicht: Ob eine Card ausgesetzt ist, kommt aus der Fassung, die das zuletzt
geändert hat.
_Vermeiden_: Synchronisieren, Abgleich

**Learning options** (Lernoptionen):
Die Einstellungen, die für ein Deck gelten, etwa Target recall, die Zahl der Steps und die
Grenzen einer Session.
_Vermeiden_: Deck settings, Einstellungen

**Preferences** (Einstellungen):
Die Einstellungen der App, die für alle Decks gelten.
_Vermeiden_: Settings, Optionen

**Review log** (Verlauf):
Alle Reviews einer Card in einer Study session, jeweils mit Zeitpunkt und Grade und, wenn
gemessen, der Dauer: wie lange die Card bei aktiver App auf dem Bildschirm stand (`ms` in
`reviews.jsonl`). Die Dauer fließt nur ins Tempo ein, nie in den Zeitplan.
_Vermeiden_: History, Antwortverlauf, Kartenverlauf

**Progress** (Fortschritt):
Wie sich die Cards eines Decks über die Zeit gefestigt haben, als Folge von Daily
snapshots.
_Vermeiden_: History, Verlauf, Statistikverlauf

**Daily snapshot** (Tagesstand):
Wie viele Cards eines Decks am Ende eines Study day wie stabil waren.
_Vermeiden_: Tagesstatistik

### Sitzungen

**Session** (Sitzung):
Reviews über eine feste Auswahl von Cards am Stück, bis alle erledigt sind oder der Lernende
aufhört. Es gibt Study sessions und Practice.
_Vermeiden_: Runde, Durchgang

**Study session** (Lernsitzung):
Eine Session über die Due Cards, deren Reviews den Learning state der Cards ändern. Eine Card
bleibt darin, bis sie in der Review phase ist. „Lernen“ ist das Verb dazu.
_Vermeiden_: Abfragerunde

**Practice** (Üben):
Eine Session über die Mistakes einer vorigen Session. Sie ändert keinen Learning state und
schreibt nichts ins Review log.
_Vermeiden_: Drill, Training, Fehlerrunde

### MacVocTrain 1

**MacVocTrain 1**:
Die Vorgänger-App; ihre Dokumente lassen sich als Deck importieren.

**Level**:
Die Stufe einer Karte in MacVocTrain 1, die ihren nächsten Abstand fest vorgab. Beim Import
wird daraus eine Stability. Nur im Zusammenhang mit dem Import benutzen.

## Mnemit: the day, the ring, the streak

Terms of the fork, in English like its code and README. Each entry gives the term in code, the
words on screen (EN / DE) and the Russian word for CLAUDE.md and HANDOFF.md. The rule behind
them: **a card is never a review, and a review is never a card.** A day is measured in cards;
reviews only price the time. The day is cut into short rounds, and the app learns how many of them
the learner really does.

**Review** (on screen: not counted; RU «оценка»):
One grade of one card, as above: one swipe, button or key. A card can take several reviews on
one study day: the steps of a new card, an Again and its relearning. The review log
(`reviews.jsonl`) holds reviews. Counts of reviews are for the optimizer, statistics and pace,
never for the goal, the ring or the streak.
_Avoid_: card, answer (the answer is a side of the card), повторение, ответ

**Plan** (today's plan / heutiger Plan; RU «план дня»):
The cards a study day asks, as FSRS sets them: review cards due on the day, the backlog share,
cards in learning, and new cards within the day's limits and the deck's allowance
(`StudySession.counts`, `newCardAllowance`).
_Avoid_: session, queue, due count

**Round** (RU «раунд»):
A stretch of the day's work: 120 s at the learner's pace (`DailyGoal.roundSeconds`). A card costs
the pace of its kind, new at the day's start or other. Round k ends at the first card where the
cost reaches k × 120 s, and the last round ends at the goal; a card that costs more than a round
ends the rounds it spans (`DayRounds.ends`). The first round keeps the streak
(`DailyProgress.streakKeptToday`). `DailyProgress` holds `rounds`, `roundsDone`, `roundEnds`,
`cardsToNextRound` and `minutesToNextRound`, at the pace the day began with. A day that began with
an empty plan cuts the cards as they stand into rounds.
_Avoid_: session, lap, segment

**Capacity** (RU «ёмкость дня»):
How many rounds the day holds, 1 to 15 (`DailyProgress.capacity`). It comes from the review logs
alone, forward from the first study day, so every device that reads the same logs gets the same: 2
on the first day; each later day takes one step from the day before: one more if the ring was
closed on each of the two days before it, one fewer if the day before ended with its ring open (a
day without study is open when its plan had cards), else the same
(`DailyGoal.nextCapacity(after:yesterdayClosed:dayBeforeClosed:)`). The capacity sets the day's
time, capacity × 120 s.
_Avoid_: limit, quota, level

**Admission** (new-card allowance; RU «допуск новых»):
The new cards a day takes in: the time of the day less the day's plan cards that are not new, at
the pace the day began with (the seven study days before it), over the price of a new card, at
least 0 (`DailyGoal.newCardsAllowed`). The decks' own limits (`newCardsPerSession`,
`newProductionPerSession`) are ceilings. Across all decks the allowance is shared in proportion to
the ceilings, by largest remainder (`DailyGoal.split`); each deck's share is its
`newCardAllowance`, which the plan takes (`DailyProgress.newCardAllowances`). Cards first reviewed
today count against it, and "+10 new" comes beyond it.
_Avoid_: new-card limit, daily new cards

**Daily goal** (the K of "M of K cards" / „M von K Karten“; RU «цель дня»):
The cards of the plan, as it stood when the study day began at 04:00, that fit the day's time:
learning cards and reviews in the stream's order, then new cards, at the day's prices, up to the
capacity in rounds; at least one card if the plan has any (`DayRounds.goal`). With admission the
plan normally fits. After a break the reviews beyond the day's time stay in the plan and go to the
laps. The goal stays for the day: cards added later, "+10 new" and an Again don't raise it. A day
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

**Backlog** ("+N to catch up this week"; RU «хвост»):
Review cards that were due before the study day began.

**Backlog share** (RU «доля хвоста»):
The part of the backlog the plan takes: at least a seventh of it and at least what a normal day
asks, never more than the backlog (`DailyGoal.backlogShare`). The rest is **catch-up**, worked
off after the plan.

**Ring** (RU «кольцо»):
Done cards against the daily goal. Done cards beyond the goal fill **laps** (×2, ×3): catch-up,
review ahead and extra new cards. The ring is closed at done ≥ goal.

**Streak** (RU «стрик»):
Study days in a row that kept it. A day keeps it with its first round done (done ≥ the end of
round 1); an empty plan counts. One missed day is repaired when the next day closes its ring
(done ≥ goal): the first round of that day is not enough, and then the streak starts anew with
it. Two missed days in a row end the streak. Days before `DailyGoal.planRuleStart` (23.10.2026)
count with one review.

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

**Stream** (Study; RU «поток»):
Study without sessions: the plan, then a rest ("Done for today"), then catch-up, review ahead
and practice (`StudyStream`).
_Avoid_: session (except for the upstream types that still carry the name)

**Extra new cards** ("+10 new"; RU «новые сверх лимита»):
New cards beyond the day's limits, taken from the rest screen. Their cost is shown in cards a
day next week (`NewCardLoad`, which assumes every review Good, so a due day is one review of
one card).

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
today (the number at 04:00 below it, now at or above it). The decks add up (`MemoryEstimate.total`).
_Avoid_: words learned, vocabulary size, «выученные слова»

**Paused deck** (on screen: "Pause Deck", "Resume Deck", "Paused" / „Stapel pausieren“, „Stapel fortsetzen“,
„Pausiert“; RU «колода на паузе»):
A deck the learner paused (`LearningOptions.isPaused`, the key `paused` in `deck.json`, written only while
true): it takes no part in the day. It is left out of the plan, the goal, the rounds, the capacity, the
admission of new cards (the allowance is split over the other decks), the streak, the words in memory, the
widget, the reminders, Study on Today and the "Next: …" after a stream (`DailyProgress.evaluate`,
`DeckActivity.isPaused`). It stays open: its screen, the card browser and "Study This Deck" work, and the
reviews written there fill the ring only through the cards of the decks that take part. On resume its overdue
reviews are a backlog like any, spread by `DailyGoal.backlogShare`. The pause travels with the options: a
merge takes it from the version that changed them last, and an older app version drops the key, so the deck is
no longer paused there.
_Avoid_: suspended deck (a card is suspended, `Card.isSuspended`), archived deck, «заморозка»
