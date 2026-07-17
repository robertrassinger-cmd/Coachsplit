import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/multiuser_models.dart';

/// Firebase-backed collaboration gateway.
///
/// The historic class name is intentionally retained so the existing UI stays
/// stable while the transport changes from REST to Firestore.
class MultiuserApiClient {
  MultiuserApiClient({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Firebase-Anmeldung ist noch nicht verfügbar.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _firestore.collection('competitionSessions');

  String _joinToken() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(8, (_) => alphabet[random.nextInt(alphabet.length)])
        .join();
  }

  Future<CreatedMultiuserSession> createSession({
    required String serverUrl,
    required String appBaseUrl,
    required String deviceId,
    required String deviceName,
    required Map<String, Object?> competition,
    required List<Map<String, Object?>> checkpoints,
  }) async {
    final sessionRef = _sessions.doc();
    final token = _joinToken();
    final now = FieldValue.serverTimestamp();

    // Create the parent first. Firestore Security Rules can then authorize all
    // owner-only subcollection writes without relying on getAfter().
    await sessionRef.set({
      'ownerUid': _uid,
      'status': CollaborationSessionStatus.openForJoining.name,
      'revision': 1,
      'joinToken': token,
      'createdAt': now,
      'updatedAt': now,
    });

    final batch = _firestore.batch();
    batch.set(sessionRef.collection('competition').doc('current'), {
      'payload': competition,
      'revision': 1,
      'updatedAt': now,
    });
    for (final checkpoint in checkpoints) {
      final id = checkpoint['id']! as String;
      batch.set(sessionRef.collection('checkpoints').doc(id), {
        ...checkpoint,
        'updatedAt': now,
      });
    }
    batch.set(sessionRef.collection('members').doc(_uid), {
      'firebaseUid': _uid,
      'deviceId': deviceId,
      'role': MultiuserRole.administrator.name,
      'createdAt': now,
    });
    batch.set(sessionRef.collection('devices').doc(deviceId), {
      'deviceId': deviceId,
      'firebaseUid': _uid,
      'displayName': deviceName,
      'role': MultiuserRole.administrator.name,
      'lastSeenAt': now,
      'pendingEventCount': 0,
      'assignmentRevision': 0,
      'createdAt': now,
    });
    batch.set(_firestore.collection('joinCodes').doc(token), {
      'sessionId': sessionRef.id,
      'ownerUid': _uid,
      'status': CollaborationSessionStatus.openForJoining.name,
      'createdAt': now,
    });
    await batch.commit();

    final joinUrl = Uri.parse(appBaseUrl).replace(
      queryParameters: {'join': token},
    ).toString();
    return CreatedMultiuserSession(
      connection: MultiuserConnection(
        serverUrl: 'firebase://coachsplit',
        sessionId: sessionRef.id,
        accessToken: _uid,
        role: MultiuserRole.administrator,
        deviceId: deviceId,
        deviceName: deviceName,
      ),
      joinToken: token,
      joinUrl: joinUrl,
    );
  }

  Future<JoinedMultiuserSession> join({
    required String serverUrl,
    required String joinToken,
    required String deviceId,
    required String displayName,
  }) async {
    final token = joinToken.trim().toUpperCase();
    final joinDoc = await _firestore.collection('joinCodes').doc(token).get();
    if (!joinDoc.exists) throw StateError('Der Beitrittscode ist ungültig.');
    final joinData = joinDoc.data()!;
    if (joinData['status'] != CollaborationSessionStatus.openForJoining.name) {
      throw StateError('Diese Helfersitzung ist nicht mehr geöffnet.');
    }
    final sessionId = joinData['sessionId']! as String;
    final sessionRef = _sessions.doc(sessionId);

    // Register membership first. Security Rules then allow this authenticated
    // device to read the session's competition snapshot.
    final joinBatch = _firestore.batch();
    joinBatch.set(sessionRef.collection('members').doc(_uid), {
      'firebaseUid': _uid,
      'deviceId': deviceId,
      'role': MultiuserRole.helper.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    joinBatch.set(sessionRef.collection('devices').doc(deviceId), {
      'deviceId': deviceId,
      'firebaseUid': _uid,
      'displayName': displayName.trim(),
      'role': MultiuserRole.helper.name,
      'lastSeenAt': FieldValue.serverTimestamp(),
      'pendingEventCount': 0,
      'assignmentRevision': 0,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await joinBatch.commit();

    final competitionDoc =
        await sessionRef.collection('competition').doc('current').get();
    if (!competitionDoc.exists) {
      throw StateError('Die Bewerbsdaten konnten nicht geladen werden.');
    }

    return JoinedMultiuserSession(
      connection: MultiuserConnection(
        serverUrl: 'firebase://coachsplit',
        sessionId: sessionId,
        accessToken: _uid,
        role: MultiuserRole.helper,
        deviceId: deviceId,
        deviceName: displayName.trim(),
      ),
      competition: Map<String, Object?>.from(
        competitionDoc.data()!['payload'] as Map,
      ),
    );
  }

  Future<CollaborationState> fetchState(MultiuserConnection connection) async {
    final sessionDoc = await _sessions.doc(connection.sessionId).get();
    if (!sessionDoc.exists) throw StateError('Sitzung nicht gefunden.');
    final session = sessionDoc.data()!;
    final deviceDocs =
        await _sessions.doc(connection.sessionId).collection('devices').get();
    final now = DateTime.now();
    final devices = deviceDocs.docs
        .where((doc) => doc.data()['role'] == MultiuserRole.helper.name)
        .map((doc) {
          final data = doc.data();
          final lastSeen = (data['lastSeenAt'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return ConnectedHelperDevice(
            deviceId: doc.id,
            displayName: data['displayName'] as String? ?? 'Helfergerät',
            lastSeenAt: lastSeen,
            online: now.difference(lastSeen) < const Duration(seconds: 15),
            pendingEventCount:
                (data['pendingEventCount'] as num?)?.toInt() ?? 0,
            checkpointId: data['checkpointId'] as String?,
            checkpointName: data['checkpointName'] as String?,
            assignmentRevision:
                (data['assignmentRevision'] as num?)?.toInt() ?? 0,
          );
        })
        .toList();
    return CollaborationState(
      status: CollaborationSessionStatus.values.byName(
        session['status'] as String? ??
            CollaborationSessionStatus.openForJoining.name,
      ),
      revision: (session['revision'] as num?)?.toInt() ?? 0,
      devices: devices,
    );
  }

  Future<MultiuserConnection> heartbeat({
    required MultiuserConnection connection,
    required int pendingEventCount,
  }) async {
    final deviceRef = _sessions
        .doc(connection.sessionId)
        .collection('devices')
        .doc(connection.deviceId);
    await deviceRef.set({
      'lastSeenAt': FieldValue.serverTimestamp(),
      'pendingEventCount': pendingEventCount,
    }, SetOptions(merge: true));
    final snapshot = await deviceRef.get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    final checkpointId = data['checkpointId'] as String?;
    return connection.copyWith(
      checkpointId: checkpointId,
      checkpointName: data['checkpointName'] as String?,
      assignmentRevision:
          (data['assignmentRevision'] as num?)?.toInt() ?? 0,
      clearAssignment: checkpointId == null,
    );
  }

  Future<void> assignDevice({
    required MultiuserConnection connection,
    required String deviceId,
    String? checkpointId,
  }) async {
    String? checkpointName;
    if (checkpointId != null) {
      final checkpoint = await _sessions
          .doc(connection.sessionId)
          .collection('checkpoints')
          .doc(checkpointId)
          .get();
      checkpointName = checkpoint.data()?['name'] as String?;
    }
    await _sessions
        .doc(connection.sessionId)
        .collection('devices')
        .doc(deviceId)
        .set({
      'checkpointId': checkpointId,
      'checkpointName': checkpointName,
      'assignmentRevision': FieldValue.increment(1),
      'assignedByUid': _uid,
      'assignedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateCompetition({
    required MultiuserConnection connection,
    required Map<String, Object?> competition,
  }) async {
    await _sessions
        .doc(connection.sessionId)
        .collection('competition')
        .doc('current')
        .set({
      'payload': competition,
      'revision': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, Object?>> fetchCompetition(
    MultiuserConnection connection,
  ) async {
    final doc = await _sessions
        .doc(connection.sessionId)
        .collection('competition')
        .doc('current')
        .get();
    if (!doc.exists) throw StateError('Bewerbsdaten nicht gefunden.');
    return Map<String, Object?>.from(doc.data()!['payload'] as Map);
  }
}
