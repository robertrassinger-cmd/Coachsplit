# CoachSplit Collaboration Backend

Kleiner HTTP-Backend-Adapter für den RC6.3.1-Feldtest.

## Lokal starten

```bash
npm start
```

## Prüfen

```bash
npm run check
npm run smoke
```

## Öffentlich bereitstellen

Der Server benötigt HTTPS und dauerhaften Speicher. `Dockerfile` und `render.yaml` sind als einfache Referenz enthalten. Nach dem Deployment wird die URL in Netlify als Build-Variable gesetzt:

```text
COACHSPLIT_API_BASE_URL=https://coachsplit-sync.example
```

Die Adresse erscheint nicht in der Traineroberfläche. Alle Helfer öffnen die Netlify-PWA über denselben Join-QR-Code.

## Firebase

Die dateibasierte Persistenz ist nur für den Durchstich vorgesehen. Für den späteren produktiven Betrieb sollen Sessions, Geräte, Zuweisungen und Events in Firebase/Firestore gespeichert werden. Die Flutter-App ist dafür über `MultiuserApiClient` und `SyncTransport` vom Speicheradapter entkoppelt.
