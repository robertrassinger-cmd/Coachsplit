# CoachSplit 1.0.6 RC6.3.1 – Kollaborativer Wettkampfbetrieb

## Nutzbarer Durchstich

- Der bisherige Einzelgerätebetrieb bleibt der Standard und benötigt keine Netzwerkverbindung.
- Erst **Helfer verbinden** öffnet eine gemeinsame CompetitionSession.
- Ein gemeinsamer QR-Code verbindet beliebig viele Helfer mit dem Bewerb.
- Helfer registrieren sich mit einem Anzeigenamen und warten anschließend auf ihre Aufgabe.
- Der Administrator sieht alle verbundenen Helfer in einer Leitstelle.
- Geräte werden per Drag-and-drop einem Messpunkt zugeordnet.
- Die Helferoberfläche übernimmt die Zuweisung automatisch beim nächsten Heartbeat.
- Bereits bestätigte Zuweisungen werden lokal gespeichert und bleiben in Funklöchern nutzbar.
- TimingEvents werden weiterhin zuerst dauerhaft lokal gespeichert und danach im Hintergrund übertragen.
- Ausstehende Ereignisse bleiben nach Browser-Neustart in der lokalen Outbox erhalten.
- Das Backend prüft Session, Rolle, Gerät und aktuelle Messpunktzuweisung erneut.

## Deployment

Die Netlify-PWA erhält die Backend-Adresse ausschließlich beim Build:

`COACHSPLIT_API_BASE_URL=https://<öffentliches-backend>`

Trainer und Helfer müssen keine Serveradresse eingeben. Der QR-Code enthält nur die öffentliche Join-URL der PWA und ein zeitlich begrenztes Einladungstoken.

Der enthaltene Node-Server besitzt weiterhin eine kleine dateibasierte Persistenz für den Feldtest. Seine HTTP-Verträge sind bewusst so getrennt, dass die Persistenz später durch Firebase/Firestore ersetzt werden kann, ohne die Flutter-Oberfläche neu zu bauen.
