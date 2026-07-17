# Regression – CoachSplit 1.0.6 RC6.1

## Einzelgeräte-Hauptablauf

1. Bewerb anlegen und speichern.
2. App beziehungsweise Browser neu starten.
3. Bewerb öffnen und Stammdaten kontrollieren.
4. Start, Zwischenzeit, Schießen und Ziel erfassen.
5. Erfassung korrigieren und erneut öffnen.
6. Ergebnis und Exporte kontrollieren.
7. Bewerb archivieren.
8. Archiv öffnen und vollständige Messdaten prüfen.
9. Zum Setup zurückkehren und neuen Bewerb anlegen.
10. Aktiven sowie archivierten Bewerb löschen.

## Persistenz

- Aktive Messungen werden nach Neustart aus TimingEvents rekonstruiert.
- Archiv-Snapshots enthalten weiterhin alle Messungen.
- Eine alte RC5-Datenbasis wird ohne Datenverlust geladen.
- Ein beschädigter oder unbekannter Schema-Datensatz erzeugt einen sichtbaren Ladefehler.

## Abnahme

RC6.1 ist abgenommen, wenn der komplette Einzelgeräteablauf gegenüber RC5.3 unverändert funktioniert.
