# CoachSplit 1.0.5 RC5.1 – Lokales Fundament

## Ziel

Aktive Bewerbe und Archiv-Snapshots werden jetzt in derselben transaktionalen
Sembast-Datenbank wie die TimingEvents gespeichert. SharedPreferences bleibt nur
für kleine Geräteeinstellungen wie Trainingsgruppen und Gerätekennung zuständig.

## Änderungen

- lokale Datenbank ist autoritative Quelle für aktive Bewerbe und Archive
- bestehende SharedPreferences-Bewerbe werden beim ersten Start automatisch importiert
- alte Bewerbs- und Archivschlüssel werden erst nach erfolgreichem Datenbank-Commit entfernt
- aktive Bewerbe speichern nur Metadaten; Messungen werden aus unveränderlichen TimingEvents rekonstruiert
- Archive bleiben vollständige, lokal gespeicherte Snapshots
- aktiver Bestand und Archiv werden gemeinsam in einer Transaktion gespeichert
- Ladefehler werden sichtbar gemeldet statt still verschluckt
- Repository-Tests für Neustart-Wiederherstellung, Archiv-Snapshot und atomisches Ersetzen

## Bewusst unverändert

Bedienung, Zeitnahme, Schießstandlogik, Ergebnisse und Exporte bleiben unverändert.
