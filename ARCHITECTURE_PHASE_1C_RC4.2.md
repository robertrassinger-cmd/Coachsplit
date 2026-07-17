# Phase 1C – Praxisstabilisierung RC4.2

Dieser Stand korrigiert fachliche Abläufe, ohne die Zielarchitektur zu verändern.

- `CompetitionClock` ist Zeitbasis für Planung, Countdown, AutoStart und Erfassung.
- `RankingService` verwendet gewertete Zeiten inklusive bis zum Punkt angefallener Strafen.
- Die Ankunftsprognose verwendet bewusst ausschließlich Laufzeiten.
- DNF und Laufabbruch sind UI-Abläufe; historische Messungen werden beim DNF erhalten.
- Leere Erfassungsbereiche werden nicht gerendert.
