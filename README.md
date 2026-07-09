# CoachSplit 1.0 – PWA für Netlify

Dieses Paket enthält ein vollständiges Flutter-Projekt für ein Netlify-PWA-Deployment.

## Lokal testen

```bash
flutter clean
flutter pub get
flutter run -d chrome
```

## PWA-Build erstellen

```bash
flutter build web --release --pwa-strategy=offline-first
```

Der fertige Output liegt danach hier:

```text
build/web
```

## Netlify Deployment

### Variante A: per Git

Netlify erkennt `netlify.toml`.

Build command:

```text
flutter build web --release --pwa-strategy=offline-first
```

Publish directory:

```text
build/web
```

### Variante B: Drag & Drop

Lokal bauen:

```bash
flutter build web --release --pwa-strategy=offline-first
```

Dann den kompletten Ordner `build/web` bei Netlify hochladen.

## Installation durch Endnutzer

### Android / Chrome

1. Website öffnen
2. Browser-Menü öffnen
3. „App installieren“ oder „Zum Startbildschirm hinzufügen“
4. CoachSplit erscheint wie eine App am Gerät

### iOS / Safari

1. Website in Safari öffnen
2. Teilen-Button
3. „Zum Home-Bildschirm“
4. CoachSplit wird als Web-App hinzugefügt

## Hinweis

Eine PWA ersetzt auf iOS/Android nicht in allen Punkten eine native App. Für echte Wettkampfnutzung am Streckenrand bleibt die APK/native App weiterhin die robustere Variante.


## Struktur ab dieser Version

Die App wurde in mehrere Dart-Dateien aufgeteilt:

```text
lib/main.dart
lib/src/coachsplit_app.dart
lib/src/coachsplit_home.dart
lib/src/models.dart
```

Die bestehende App-Logik bleibt erhalten; `main.dart` startet nur noch die App.
