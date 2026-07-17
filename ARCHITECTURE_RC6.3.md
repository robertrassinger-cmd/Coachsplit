# RC6.3 – erster Multiuser-Durchstich

## Umfang

- eine Flutter/PWA mit Administrator- und Helfermodus
- externer kleiner HTTP-Sync-Server
- Bewerb inklusive Athleten und Messpunkten wird beim Beitritt übertragen
- jeder Messpunkt besitzt einen eigenen, zwölf Stunden gültigen Verbindungscode
- Helfer sehen in der Erfassung nur den zugewiesenen Messpunkt
- der Server prüft Token, Session, Rolle, Messpunkt und Ereignistyp
- TimingEvents werden immer zuerst lokal gespeichert
- Upload ist idempotent; gleiche ID mit abweichendem Inhalt wird als Konflikt quittiert
- automatische Synchronisation alle drei Sekunden sowie manuelle Synchronisation
- Offline-Erfassung und Wiederaufnahme nach erneutem Öffnen

## Bewusste Grenzen

- noch kein QR-Renderer; Codes werden angezeigt und eingegeben
- noch keine öffentliche Cloudbereitstellung
- noch kein komfortabler Geräte-/Einladungsdialog
- noch keine Streckenrevisionen und automatische Timeline
- noch kein endgültiger Konflikteditor
- lokale Helferoberfläche verwendet weiterhin die bestehende Erfassungsseite, jedoch gefiltert

## Sicherheitsmodell

Die UI ist keine Sicherheitsgrenze. Jede eingehende Messung wird serverseitig gegen das Zugriffstoken und den zugeordneten Messpunkt geprüft. Unberechtigte Ereignisse werden mit einer expliziten Quittung abgelehnt.
