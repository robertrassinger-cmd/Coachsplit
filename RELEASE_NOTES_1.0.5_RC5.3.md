# CoachSplit 1.0.6 RC6.1 – Fundament abschließend stabilisiert

## Technische Stabilisierung

- Sichere Migrationsreihenfolge: Alte SharedPreferences-Bewerbsdaten werden erst entfernt, nachdem alle Messungen als TimingEvents übernommen und die Bewerbsdaten erfolgreich in Sembast gespeichert wurden.
- Eine unterbrochene Migration kann beim nächsten Start idempotent erneut ausgeführt werden, ohne die Originaldaten zu verlieren.
- Lokale Schreibvorgänge werden serialisiert. Ein älterer Speichervorgang kann damit keinen neueren Zustand mehr überschreiben.
- Jeder Schreibvorgang arbeitet mit unveränderlichen Snapshots der aktiven Bewerbe und Archive.
- Die App wartet beim Start auf die lokale Datenbank, bevor ein neuer Standardbewerb erzeugt wird.
- Bei beschädigten oder nicht lesbaren lokalen Daten wird die App nicht mit einem leeren Zustand fortgesetzt. Stattdessen erscheint ein klarer Fehlerbildschirm mit „Erneut versuchen“.
- Beschädigte Bewerbsdatensätze werden nicht mehr still übersprungen.
- Doppelte Bewerbs-IDs über aktive Bewerbe und Archiv hinweg werden abgewiesen.
- Eine bereits vorhandene TimingEvent-ID bleibt idempotent, wird aber bei abweichendem Inhalt als Konflikt gemeldet.
- Lokale Datensätze enthalten eine Schema-Version als Grundlage für spätere Migrationen.

## Unverändert

- Bedienoberfläche und Trainerablauf
- Zeitnahme und Schießstandlogik
- Ergebnisse, Ranking und Exporte
- Archiv-Workflow zurück ins Setup
- Offline-Nutzung

## Versionsstand

- Sichtbare Version: `CoachSplit 1.0.6 RC6.1`
- Buildnummer: `1.0.5+18`
