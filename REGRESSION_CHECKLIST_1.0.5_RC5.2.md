# Regressionstest CoachSplit 1.0.5 RC5.2

## Versionsanzeige

- App starten.
- Im Kopfbereich steht `CoachSplit 1.0.5 RC5.2`.

## Vollständiger Ablauf

1. Einen Testbewerb anlegen.
2. Mindestens einen Athleten starten.
3. Zwischenzeit, optional Schießstand und Ziel erfassen.
4. Ergebnisansicht öffnen.
5. CSV/HTML/PNG bei Bedarf kurz prüfen.
6. `Archivieren` wählen.

Erwartung:

- Meldung `Bewerb archiviert · zurück im Setup` erscheint.
- Die Setup-Seite ist unmittelbar sichtbar.
- Kein Bewerb ist mehr aktiv geladen.
- Der archivierte Bewerb befindet sich im Archiv und kann eingesehen werden.
- Ein neuer Bewerb kann direkt angelegt werden.

## Persistenz

- Browser/App vollständig schließen und neu öffnen.
- Der archivierte Bewerb ist weiterhin vorhanden.
- Bereits vorhandene aktive Bewerbe und Archive sind unverändert verfügbar.

## Kurzer Regressionstest

- Neuer Bewerb → Start → Messung → Ziel → Ergebnis funktioniert.
- Schießfehler und Strafzeit werden korrekt dargestellt.
- Export funktioniert.
- Archiv kann geöffnet und als Vorlage verwendet werden.
