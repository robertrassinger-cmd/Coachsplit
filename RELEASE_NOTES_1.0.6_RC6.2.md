# CoachSplit 1.0.6 RC6.2 – Offline-Synchronisationsfundament

## Enthalten

- dauerhaft gespeicherte, installationseindeutige `deviceId`
- TimingEvents mit Sync-Zustand, Sync-Version, Versuchszähler und Fehlerdiagnose
- neue Ereignisse gelangen unmittelbar in die lokale Outbox (`pending`)
- atomare Statuswechsel `pending`, `synced`, `failed`, `conflict`
- idempotenter Import fremder TimingEvents
- explizite Konflikterkennung bei gleicher ID und abweichendem fachlichem Inhalt
- transportneutrale `SyncEngine`
- transportneutraler `SyncTransport`-Vertrag für RC6.3
- UI-neutrale `TimingService`- und `SyncService`-Grenzen
- Wiederholbarkeit nach Neustart über die persistierte Outbox
- Tests für Geräte-ID, Push/Pull, Idempotenz und Statuswechsel

## Bewusst nicht enthalten

- noch kein Netzwerk-, Cloud-, WLAN- oder Bluetooth-Transport
- noch keine Messpunkt- oder Live-Oberfläche
- keine Änderung des bestehenden Trainer-Workflows

Version: `1.0.6+20`
