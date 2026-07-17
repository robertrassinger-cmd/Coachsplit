# RC6.2 – Offline-Synchronisationsfundament

## Laufzeitfluss

```text
UI (Admin / Messpunkt / Live)
        ↓
Application Services
        ↓
TimingEventRepository ← lokale Sembast-Datenbank
        ↓
persistente Outbox (pending / failed)
        ↓
SyncEngine
        ↓
SyncTransport (wird in RC6.3 konkret implementiert)
```

## Garantien

1. Eine Messung wird lokal gespeichert, bevor ein Transport aufgerufen wird.
2. Ein Transportfehler verändert den fachlichen Inhalt nicht.
3. Noch nicht bestätigte Events bleiben nach Neustart auffindbar.
4. Gleiche Event-ID mit gleichem fachlichem Inhalt ist idempotent.
5. Gleiche Event-ID mit anderem Inhalt wird als Konflikt markiert.
6. Die Domäne kennt weder QR-Code, Browserroute, WLAN noch Cloudanbieter.
7. Alle künftigen Oberflächen bleiben innerhalb derselben Flutter-App.

## Grenze zu RC6.3

RC6.2 enthält keinen echten Kommunikationskanal. RC6.3 implementiert einen
`SyncTransport` für den Zwei-Handy-Durchstich und ergänzt den minimalen
Beitritts- und Messpunktmodus innerhalb derselben App.
