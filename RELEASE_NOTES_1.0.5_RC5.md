# CoachSplit 1.0.5 RC5 – V2-Durchstich Zeitmessung

Dieser Stand setzt den ersten produktiven V2-Durchstich praxisnah in einem Paket um.

## Neu

- Zeitnahmen werden vor der sichtbaren Bestätigung als unveränderliches `TimingEvent` gespeichert.
- Lokale transaktionale Speicherung mit Sembast:
  - IndexedDB im Browser/PWA
  - lokale Datenbankdatei auf Android, iOS und Desktop
- UUIDv7 für neue Bewerbe, Athleten, Teilnahmen, Geräte und TimingEvents.
- Doppelte Event-IDs werden idempotent ignoriert.
- Beim Neustart werden Messungen aus dem TimingEvent-Repository wiederhergestellt.
- Bestehende V1-Messungen werden beim ersten Laden automatisch in TimingEvents überführt.
- SharedPreferences speichert für aktive Bewerbe nur noch Metadaten; Messzeiten liegen im TimingEvent-Store.
- Speicherausfälle werden sichtbar angezeigt und erzeugen keine scheinbar erfolgreiche Messung.
- Rückgängig erzeugt ein Korrekturereignis und löscht die ursprüngliche Messung nicht.

## Bewusst unverändert

- Bedienoberfläche und Trainerablauf
- Ranking und Strafzeiten
- Schießstanddialog und Ergebnisdarstellung
- Exportfunktionen
- Archiv-Snapshots
- Cloud und Multiuser sind noch nicht enthalten.

## Technischer Ablauf

Zeit erfassen → TimingEvent erzeugen → lokal transaktional speichern → UI aktualisieren → Metadaten speichern → nach Neustart aus Repository projizieren.
