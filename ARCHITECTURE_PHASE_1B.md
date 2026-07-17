# Phase 1B – Domänenfundament

Diese Version verändert keine sichtbare Funktion.

## Neu

Unter `lib/domain/v2/` wurden immutable Zielmodelle eingeführt für:

- versionierte Strecken und Messpunkte
- Training, Rennen, Leistungstest und sonstige Sessions
- Athletenteilnahmen inklusive DNF, DNS und DSQ
- unveränderliche Zeitereignisse
- Schießdaten
- Offline-/Synchronisationsstatus
- archivierte Session-Snapshots

Unter `lib/repositories/v2/` liegen die dazugehörigen Datenzugriffsverträge.

## Übergangsstrategie

Die bestehende UI verwendet weiterhin die bewährten Legacy-Modelle aus
`lib/domain/models.dart`. Dadurch bleibt der aktuelle Funktionsstand unverändert.

Die Migration erfolgt später Use-Case für Use-Case über Adapter. Erst nach einem
erfolgreichen Build und Regressionstest wird ein vorhandener Ablauf auf die neuen
Modelle umgestellt.

## Mobile-first

Fast alle ergänzenden Strecken- und Bedingungsdaten sind optional. Die Datenmodelle
können sie aufnehmen; die mobile Oberfläche muss sie nicht beim Start einer Einheit
abfragen. Detaillierte Pflege kann später am Desktop erfolgen.
