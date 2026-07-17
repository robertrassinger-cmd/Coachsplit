# CoachSplit 1.0.6 RC6.3.2 – Firebase foundation

- REST/Node collaboration transport replaced with Firebase Authentication and Cloud Firestore
- anonymous device authentication initialized at application start
- Firestore-backed competition sessions, join codes, members, devices and assignments
- Firestore-backed TimingEvent synchronization by immutable event ID
- persistent Firestore cache enabled for the Flutter web/PWA build
- Netlify no longer needs `COACHSPLIT_API_BASE_URL`
- restrictive Firestore Security Rules and emulator configuration included
- Node prototype retained only as historical reference, not used by the app

Compilation and Flutter tests were not executed in the packaging environment.
Run `flutter pub get`, `flutter test` and `flutter build web --release` before production deployment.
