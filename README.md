# CoachSplit 1.0.1 Grafik-Fix

Basis: aktuell veröffentlichte Netlify/GitHub-Version.

Änderungen:
- keine neuen Funktionen
- keine Änderung an Start-/Erfassungs-/Ergebnislogik
- Desktop-Oberfläche nicht mehr breitgezogen
- mobile/desktop Bedienung wieder einheitlicher
- störende Logo-Karte aus der Startansicht entfernt
- Ergebnis-PNG etwas kompakter und weiterhin CI-konform

Netlify Build:
flutter build web --release --pwa-strategy=offline-first

Publish directory:
build/web
