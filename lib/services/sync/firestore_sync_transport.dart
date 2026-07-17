import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/v2/timing_event.dart';
import 'sync_transport.dart';

class FirestoreSyncTransport implements SyncTransport {
  FirestoreSyncTransport({
    required this.sessionId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String sessionId;
  final FirebaseFirestore _firestore;
  final Set<String> _seenEventIds = <String>{};

  CollectionReference<Map<String, dynamic>> get _events => _firestore
      .collection('competitionSessions')
      .doc(sessionId)
      .collection('timingEvents');

  @override
  Future<List<SyncPushReceipt>> push(List<TimingEvent> events) async {
    if (events.isEmpty) return const [];
    final receipts = <SyncPushReceipt>[];
    for (final event in events) {
      final ref = _events.doc(event.id);
      final existing = await ref.get();
      if (existing.exists) {
        receipts.add(SyncPushReceipt(
          eventId: event.id,
          decision: SyncPushDecision.duplicate,
          serverReceivedAt:
              (existing.data()?['serverReceivedAt'] as Timestamp?)?.toDate(),
        ));
        continue;
      }
      await ref.set({
        ...event.canonicalPayload(),
        'serverReceivedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      receipts.add(SyncPushReceipt(
        eventId: event.id,
        decision: SyncPushDecision.accepted,
        serverReceivedAt: DateTime.now().toUtc(),
        reason: 'Lokal in Firestore-Warteschlange übernommen.',
      ));
    }
    return receipts;
  }

  @override
  Future<List<TimingEvent>> pull({required String deviceId}) async {
    final snapshot = await _events.orderBy('deviceTime').get();
    final result = <TimingEvent>[];
    for (final doc in snapshot.docs) {
      if (!_seenEventIds.add(doc.id)) continue;
      final data = Map<String, Object?>.from(doc.data());
      final serverTimestamp = data['serverReceivedAt'];
      data['serverReceivedAt'] = serverTimestamp is Timestamp
          ? serverTimestamp.toDate().toIso8601String()
          : null;
      data['syncState'] = 'synced';
      data['schemaVersion'] = 2;
      result.add(TimingEvent.fromJson(data));
    }
    return result;
  }
}
