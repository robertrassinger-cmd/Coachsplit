# CoachSplit 1.0.3 RC2

## Laufender Bewerb
- Setup wird nach „Zum Start“ gesperrt; ein laufender Bewerb kann nicht versehentlich durch erneutes Parsen der Setup-Felder überschrieben werden.
- Noch ausstehende Setup-Autosaves werden beim Start abgebrochen.
- Neue Messpunkte können während des Rennens weiterhin vor dem Ziel ergänzt werden.
- Bereits im Ziel befindliche Athleten erhalten für später ergänzte Punkte einfach keinen Messwert; die Zielzeit bleibt unverändert.

## Messpunkte
- Bezeichnung und Standorthinweis können während des Rennens geändert werden.
- Erfassungen referenzieren weiterhin die unveränderliche interne Messpunkt-ID.
- Punkte ohne Erfassungen können gelöscht werden.
- Verwendete Punkte bleiben hinsichtlich Typ und Identität geschützt.
- Ein unbenutzter Schießstand wird als zusammengehöriges Ein-/Aus-Paar gelöscht.

## Wertung und Bedienung
- Strafzeit kann im laufenden Bewerb mit deutlicher Warnung rückwirkend aktiviert oder geändert werden.
- Rohzeiten bleiben unverändert; nur offizielle Zeiten werden neu berechnet.
- Athleten können als DNF markiert werden; bisherige Messungen bleiben erhalten und sie verschwinden aus der aktiven Erfassung.

## Architekturvorbereitung
- Schema-Version 3 und Bewerbs-Lebenszyklus ergänzt.
- Repository-Vertrag für zukünftige lokale und Firebase-basierte RaceEvents vorbereitet.
- Austauschbare Schnittstelle für die Ankunftsprognose ergänzt.
