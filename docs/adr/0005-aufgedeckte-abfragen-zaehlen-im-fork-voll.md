# Im Fork zählen aufgedeckte Abfragen voll

Mnemit lernt standardmäßig mit Karteikarten: Auf dem iPhone deckt der Lernende die Antwort
immer auf, auf dem Mac tut er es im Modus „Flashcards“, der Voreinstellung. Fast jede Abfrage
des Forks ist deshalb eine aufgedeckte (`ReviewMode.revealed`). ADR 0004 dämpft sie auf ein
Drittel des Stabilitätsgewinns, und der Optimierer (ADR 0002) nimmt nur getippte Abfragen als
Lernbeispiele. Beides trifft hier fast alle Abfragen:

- Der Optimierer sieht die Abfragen des Lernenden praktisch nicht. Die Schwelle von 400
  Lernbeispielen zählt nur Abfragen, die auf dem Mac im Modus „Typing“ entstanden.
- Jedes „Gut“ verlängert den Abstand nur um ein Drittel dessen, was FSRS vorsieht. Bei
  gleicher Zielquote kommen die Karten öfter, als das Modell für nötig hält.

Anki kennt den Unterschied nicht. Dort sind alle Abfragen selbst bewertet, FSRS wird auf
diesen Bewertungen trainiert, und die Zielquote beschreibt genau diese Bewertungen. Der Fork
übernimmt das.

## Entscheidung

Eine Option je Stapel, `LearningOptions.revealedRecallWeight`, von 1/3 bis 1, im Fork
voreingestellt auf 1. Sie ersetzt den festen Faktor aus ADR 0004: Eine aufgedeckte Abfrage,
die die Karte weiß (Schwer, Gut, Leicht), behält diesen Anteil der Stabilität, die FSRS
hinzurechnet: `S' = S + (S_FSRS − S) · Gewicht`. Bei 1 rechnet FSRS unverändert. „Nochmal“,
die erste Abfrage einer Karte und die Schwierigkeit bleiben wie in ADR 0004 unberührt.

Das Gewicht gilt überall, wo ADR 0004 den Faktor anwendet: beim Bewerten
(`Scheduler.memory`), beim Nachrechnen aus dem Verlauf (Zusammenführen, neue Gewichte) und im
Modell des Optimierers (`FSRSGradient`, `FSRSOptimizer.evaluate`).

Eine zweite Option, `LearningOptions.optimizeFromRevealed`, voreingestellt auf `true`: Der
Optimierer nimmt aufgedeckte Abfragen als Lernbeispiele. Ausgeschaltet sind nur getippte
Abfragen Ziele, wie bisher; aufgedeckte zählen dann nur in der Vorgeschichte späterer
Beispiele.

Beide Optionen stehen auf dem Mac unter „Learning Options“, das Gewicht unter „Advanced“, der
Schalter beim Berechnen der Parameter. Die Optionen bekommen kein neues Dateiformat; siehe
Folgen.

## Zurückrollen

In den Learning Options das Gewicht auf 0,33 stellen und „Learn from revealed reviews“
ausschalten. Das Gewicht rastet bei 0,33 auf exakt 1/3 ein (`revealedRecallWeightRange`), und
beide Optionen zusammen ergeben das Verhalten von ADR 0004 und ADR 0002. Mit dem Speichern
rechnet die App Stabilität und Schwierigkeit jeder Karte mit vollständigem Verlauf neu;
Fälligkeiten bleiben. Dasselbe Nachrechnen läuft beim Zusammenführen mit einer Fassung, die
mit einem anderen Gewicht gespeichert wurde.

## Erwogene Optionen

- **Dämpfung auf ein Drittel behalten.** Die Zahl ist gesetzt, nicht gemessen (ADR 0004).
  Unter Anki-Bedingungen ist sie nicht begründet, denn dort gibt es keine Abfrageart, und
  für diesen Lernenden bremst sie fast jede Abfrage.
- **Das Gewicht aus dem Verlauf schätzen.** Mit `FSRSOptimizer.evaluate` ließen sich Gewichte
  wie 1/3, 1/2, 2/3 und 1 an den eigenen Daten vergleichen. Das braucht Wochen an Daten und
  eine Statistik der tatsächlichen Quote (Backlog in `references/anki-parity.md`, Punkt 2).
  Die Option macht diesen Vergleich möglich, ohne ihn jetzt zu verlangen.
- **Gewicht auch unter 1/3 erlauben.** Unter einem Drittel verlängert ein „Gut“ die
  Abstände kaum noch; dann wäre es besser, aufgedeckte Abfragen gar nicht zu planen.
- **Nur `optimizeFromRevealed`, ohne Gewicht.** Der Optimierer lernte dann aus Abfragen,
  deren Modell eine andere Stabilität annimmt, als der Scheduler anwendet.

## Folgen

Kein neues Dateiformat: Beide Optionen sind neue Schlüssel in `deck.json`. Fehlen sie, gelten
die Voreinstellungen des Forks, also Gewicht 1 und Optimierer mit aufgedeckten Abfragen. Ältere
App-Versionen lassen die Schlüssel beim Speichern fallen, dämpfen mit ihrem festen Drittel und
trainieren auf getippten Abfragen, bis eine neuere Version das Dokument wieder schreibt;
beide Geräte laufen deshalb vom selben Stand.

Bestehende Karten tragen die mit einem Drittel gerechnete Stabilität, bis ihr Verlauf
nachgerechnet wird (neue Parameter oder neues Gewicht beim Speichern der Optionen, Zusammenführen
mit einer anderen Fassung). Neue Abfragen rechnen sofort mit dem Gewicht der Optionen. Der
Optimierer rechnet den Verlauf stets mit dem Gewicht der Optionen durch.

Mit Gewicht 1 rechnet der Optimierer wie fsrs-rs: Die Tests gegen die Referenzwerte
(`Tools/fsrs-reference`) laufen unverändert, weil deren Abfragen getippt sind.
