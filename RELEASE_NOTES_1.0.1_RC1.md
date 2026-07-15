# CoachSplit 1.0.1 RC1

Behoben:
- vergangene Startzeit wird dem nächsten Tag zugeordnet
- AutoStart startet keine Athleten rückwirkend
- 24-Stunden-Anzeige im Startzeitdialog
- mehrere neue Bewerbe können direkt hintereinander angelegt werden
- Ergebnisbild öffnet zuerst eine zoombare Vorschau
- PNG-Download auf Web/Desktop, Teilen zusätzlich auf Mobilgeräten
- originales CoachSplit-Icon in PWA, Header und PNG-Export
- Intervall wird im Header nicht mehr angezeigt
- Messpunkt-Auswahl mit automatischer Nummerierung
- Ziel ist einmalig und immer der letzte Messpunkt

Bewusst unverändert:
- Erfassungslogik
- Ranking- und Ergebnisberechnung
- Prognoselogik
- Archivdaten

## Architektur-/Biathlon-Erweiterung (technischer Arbeitsstand)

- Messpunktwahl ohne Dropdown: Zwischenzeit, Schießstand oder freier Messpunkt direkt anwählbar.
- Start und Ziel bleiben verpflichtend; neue Punkte werden vor dem Ziel eingefügt.
- Ein Schießstand erzeugt automatisch Ein- und Ausgang mit gemeinsamer Nummer.
- Bei Schießstand aus werden L/S und 0–5 Fehler erfasst.
- Optionale Zeitstrafe pro Schießfehler; Rohzeit bleibt unverändert, Zielwertung berücksichtigt die Strafzeit.
- Kalibrierbare offizielle Wettkampfuhr mit Fallback auf Administratorzeit.
- Persistierte Schema-Version und rückwärtskompatible JSON-Felder als Vorbereitung für Datenbankmigration.
