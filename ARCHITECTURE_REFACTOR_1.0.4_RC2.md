# Architektur-Refactoring 1.0.4 RC2

## Ziel

Diese Version verändert keine fachliche Funktion. Sie teilt die bisherige `lib/main.dart`
in risikoarmen Dart-`part`-Modulen auf.

## Modulstruktur

- `lib/main.dart` – Bibliotheksdefinition, Imports, Part-Deklarationen und Einstiegspunkt
- `lib/app/coach_split_app.dart` – MaterialApp und Theme
- `lib/domain/models.dart` – Bewerb, Athleten, Messpunkte, Schießergebnisse und Rangmodelle
- `lib/features/competition/coach_split_home.dart` – bestehender Hauptbildschirm und Zustandslogik
- `lib/ui/widgets.dart` – wiederverwendbare UI-Komponenten
- `lib/services/competition_clock.dart` – Wettkampfuhr
- `lib/services/arrival_prediction_strategy.dart` – vorbereitete Prognosestrategie
- `lib/domain/race_event_contract.dart` – vorbereitete Eventverträge
- `lib/repositories/race_event_repository.dart` – vorbereitete Repository-Schnittstelle

## Warum zunächst `part`

Private Klassen und Methoden bleiben in derselben Dart-Bibliothek sichtbar. Dadurch kann die
Datei aufgeteilt werden, ohne gleichzeitig Zustandsmanagement, Datenfluss oder UI-Verhalten zu
verändern. Spätere Schritte können die Module kontrolliert in eigenständige Libraries überführen.

## Nächste Refactoring-Schritte

1. Domänenmodelle mit unveränderlichen IDs und Tests stabilisieren.
2. Berechnungen aus dem Widget-State in Services auslagern.
3. lokale Persistenz hinter Repository-Schnittstellen führen.
4. Zeitmessungen schrittweise auf RaceEvents umstellen.
5. erst danach Firebase-Implementierungen ergänzen.
