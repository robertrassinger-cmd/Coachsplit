# CoachSplit 1.0.6 RC6.1 – Repository Consolidation

## Ziel

Die lokale Datenhaltung besitzt jetzt eine einzige fachliche Persistenzgrenze für Bewerbe. UI und Anwendungsabläufe kennen keine Sembast-Details.

## Änderungen

- `CompetitionRepository` als verbindlicher Vertrag für aktive Bewerbe und Archive
- `SembastCompetitionRepository` als lokale Implementierung
- gezielte Operationen für `saveActive`, `archive` und `delete`
- atomarer Gesamtabgleich bleibt für Migration und bestehende gebündelte Speicherabläufe erhalten
- Schema-Version wird beim Laden validiert
- aktive Bewerbe speichern weiterhin nur Metadaten; Messungen werden aus `TimingEvent` rekonstruiert
- Archive bleiben vollständige Snapshots
- bisherige Repository-Namen bestehen nur noch als Übergangs-Aliase
- Version auf 1.0.6 RC6.1 / Build 19 aktualisiert

## Bewusst unverändert

- Trainer-Workflow
- Zeitnahme
- Schießstandlogik
- Ergebnisberechnung
- Export
- Archivbedienung

RC6.1 ist ein strukturelles Release ohne neue Benutzerfunktion.
