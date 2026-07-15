# CoachSplit 1.0.4 RC1

Professioneller Konsolidierungsstand auf Basis der zuletzt bestätigten, funktionierenden Version 1.0.2.

## Enthalten

- direkte Auswahl von Standardmesspunkten und freien Messpunkten
- Schießstand als gekoppeltes Ein-/Aus-Paar
- L/S und 0–5 Fehler bei Schießstand aus
- optionale Zeitstrafe pro Fehler
- Wettkampfuhr-Kalibrierung für dafür konfigurierte Bewerbe
- Setup-Schutz nach Rennstart
- Messpunkte während eines laufenden Bewerbs ergänzen
- Bezeichnung und Standorthinweis während des Rennens ändern
- Schutz strukturell verwendeter Messpunkte
- DNF-Status
- Platzierung sowie Vorsprung/Rückstand nach Schießstand aus
- vorbereitete Schnittstellen für RaceEvents, Repository und Prognosestrategien

## Release-Basis

Dieser Stand wurde nicht auf einem späteren fehlerhaften Paket aufgebaut. Ausgangspunkt war ausschließlich `coachsplit_1_0_2_biathlon_architecture`, das als letzter funktionierender Stand bestätigt wurde.

## PWA / Netlify

Build-Befehl:

```bash
flutter pub get
flutter build web --release --no-wasm-dry-run
```

Netlify veröffentlicht `build/web`.
