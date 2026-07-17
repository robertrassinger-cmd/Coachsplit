# Phase 1C – Service Layer

Keine sichtbare Funktion wurde neu gestaltet.

Aus dem Widget-State ausgelagert wurden:

- Zeitstrafen und Gesamtfehler (`PenaltyService`)
- Platzierung, Rückstand und Abschnittsrang (`RankingService`)
- Schießstandnummerierung (`ShootingRangeNumberService`)

Die bestehende `CompetitionClock` bleibt die zentrale Zeitquelle. UI, Speicherung,
Prognose und Bedienabläufe bleiben unverändert.

Der erste Schießstand erhält nun sicher Nummer 1; Ein- und Ausgang zählen gemeinsam
als ein Schießstand.
