# CoachSplit – Architekturgrundlage für Datenbank und Multiuser

## Zeitmodell

Die App verwendet eine fachliche `CompetitionClock` als einzige Zeitquelle für Start-, Mess- und Zielereignisse.

- Ohne Kalibrierung entspricht die Wettkampfzeit zunächst der lokalen Administratorzeit.
- Bei der Kalibrierung gibt der Administrator eine offizielle Uhrzeit knapp in der Zukunft ein und drückt beim Erreichen dieser Uhrzeit auf **Jetzt übernehmen**.
- Intern wird nur die Differenz zwischen Gerätezeit und offizieller Wettkampfuhr gespeichert.
- Gerätespezifische Details bleiben für Trainer verborgen. Nur bei relevanter Zeitabweichung soll später eine Warnung erscheinen.
- Im Multiuserbetrieb muss der Server die gemeinsame Zeitreferenz bestätigen. Jedes Gerät berechnet seinen technischen Offset im Hintergrund.

## Persistenzstrategie

Das Zielmodell ist **cloud-first, aber offline-fähig**, nicht cloud-only:

1. Die Cloud ist die autoritative Quelle für Bewerb, Rollen, Messpunktzuweisungen und synchronisierte Messereignisse.
2. Jedes Gerät hält einen lokalen Cache und eine ausgehende Ereigniswarteschlange.
3. Eine Erfassung wird zuerst lokal dauerhaft gespeichert und anschließend synchronisiert.
4. Ereignisse erhalten stabile UUIDs, damit Wiederholungen keine doppelten Messungen erzeugen.
5. Korrekturen überschreiben nicht still, sondern erzeugen nachvollziehbare Revisionen/Audit-Ereignisse.

## Kernobjekte für das künftige Cloudschema

- `competitions`
- `competition_members`
- `measurement_points`
- `athletes`
- `race_events`
- `device_clock_calibrations`
- `competition_clock_reference`
- `audit_events`

Ein `race_event` enthält mindestens:

- `id`
- `competitionId`
- `athleteId`
- `measurementPointId`
- `eventType`
- `competitionTimestamp`
- `deviceTimestamp`
- `createdByUserId`
- `deviceId`
- `revision`
- `syncState`
- optional `shootingPosition` und `misses`

## Fachliche Regeln

- Start und Ziel sind verpflichtend und nicht löschbar.
- Neue Messpunkte werden immer unmittelbar vor dem Ziel eingefügt.
- Ein Schießstand wird als Einheit angelegt, erzeugt intern aber `Schießstand n ein` und `Schießstand n aus`.
- Nur `Schießstand aus` verlangt L/S und 0–5 Fehler.
- Zeitstrafen verändern niemals die Rohzeit; die offizielle Zielzeit ist Rohzeit plus berechnete Strafzeit.
- Die Prognoselogik soll hinter einer austauschbaren Strategie liegen und nicht an UI oder Datenbank gekoppelt werden.

## Empfohlener nächster technischer Schritt

Vor Auswahl eines konkreten Cloudanbieters:

1. Repository-Schnittstellen definieren.
2. Messungen von veränderlichen Athletenfeldern auf eigenständige Ereignisse umstellen.
3. Unit-Tests für Pflichtmesspunkte, Schießstandpaar, Schießerfassung und Strafzeit ergänzen.
4. Danach einen Multiuser-Durchstich mit Startgerät, Schießstandgerät und Zielgerät implementieren.
