// Generated configuration for the CoachSplit Firebase web app.
// Re-run `flutterfire configure --project=coachsplit --platforms=web`
// when another platform or Firebase app is added.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'CoachSplit Firebase ist derzeit nur für Web konfiguriert. '
          'Bitte flutterfire configure für die gewünschte Plattform ausführen.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCN0ZaaZr55tENxPUzy0rgHYdL4mpcI9yU',
    appId: '1:599525473187:web:5266b0da1df7bd8cb27816',
    messagingSenderId: '599525473187',
    projectId: 'coachsplit',
    authDomain: 'coachsplit.firebaseapp.com',
    storageBucket: 'coachsplit.firebasestorage.app',
    measurementId: 'G-9615TN2T3X',
  );
}
