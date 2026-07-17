# Regression – RC6.3.1

## Einzelgerät

- App ohne `COACHSPLIT_API_BASE_URL` bauen und bisherigen Ablauf vollständig testen.
- Bewerb erstellen, starten, erfassen, auswerten und archivieren.
- Sicherstellen, dass keine Netzwerkfunktion den lokalen Ablauf blockiert.

## Helfer verbinden

- Administrator aktiviert **Helfer verbinden**.
- Ein QR-Code wird angezeigt; keine Serveradresse ist im UI sichtbar.
- Drei Geräte scannen denselben QR-Code und geben unterschiedliche Namen ein.
- Alle Geräte erscheinen als unzugeordnet in der Leitstelle.

## Zuweisung

- Helfer per Drag-and-drop Start, Zwischenzeit und Ziel zuweisen.
- Helfergerät übernimmt die Aufgabe automatisch ohne erneuten Scan.
- Zuweisung ändern und prüfen, dass die reduzierte Oberfläche wechselt.
- Zwei Helfer demselben Messpunkt zuweisen und beide getrennt anzeigen.

## Offline-first

- Nach bestätigter Zuweisung Mobilfunk am Helfergerät deaktivieren.
- Mehrere Ereignisse erfassen; UI muss sofort bestätigen.
- Browser schließen und erneut öffnen; Ereignisse müssen lokal vorhanden sein.
- Mobilfunk aktivieren; ausstehende Ereignisse werden automatisch übertragen.

## Autorisierung

- Ein Zielgerät versucht technisch ein Ereignis für Start zu senden: Server lehnt ab.
- Wiederholter Upload derselben Event-ID erzeugt kein Duplikat.
- Unzugeordnetes Gerät kann keine Messereignisse serverseitig akzeptieren lassen.
