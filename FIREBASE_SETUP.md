# CoachSplit Firebase foundation (RC6.3.2)

## Already completed in the Firebase console

- Project: `coachsplit`
- Web app registered
- Cloud Firestore created
- Anonymous Authentication enabled

## Local one-time setup

Install the Firebase CLI and authenticate:

```bash
npm install -g firebase-tools
firebase login
firebase use --add coachsplit
```

Deploy the provided Firestore rules and indexes:

```bash
firebase deploy --only firestore
```

The Flutter app uses the registered web app through `lib/firebase_options.dart`.
When adding Android, iOS, macOS or another Firebase app, install FlutterFire CLI
and regenerate the file:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=coachsplit --platforms=web
```

## Netlify

No `COACHSPLIT_API_BASE_URL` variable is required anymore. Netlify continues to
host the PWA; Firebase Authentication and Firestore provide collaboration and
synchronization.

Trigger a fresh Netlify deploy after committing this release.

## Firestore structure

```text
joinCodes/{joinToken}
competitionSessions/{sessionId}
  competition/current
  checkpoints/{checkpointId}
  members/{firebaseUid}
  devices/{deviceId}
  timingEvents/{eventId}
  conflictGroups/{conflictId}
```

## Current vertical slice

- anonymous Firebase identity at app startup
- administrator creates a collaboration session
- one join QR/link for all helpers
- helper registers as a session member and device
- administrator sees helper devices and assigns checkpoints
- helper receives assignment through heartbeat refresh
- timing events are written idempotently by event ID
- Firestore persistent cache is enabled for PWA offline operation

## Important limitation

Firestore currently queues timing events offline, but the existing SyncEngine
marks a successful local Firestore enqueue as accepted. A later hardening step
must expose Firestore `hasPendingWrites` metadata so the UI distinguishes:

- locally queued
- confirmed by Firestore backend

Likewise, semantic duplicate detection across two different event IDs is the
next domain increment; raw events remain immutable.
