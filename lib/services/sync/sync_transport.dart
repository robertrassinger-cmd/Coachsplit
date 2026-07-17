import '../../domain/v2/timing_event.dart';

enum SyncPushDecision {
  accepted,
  duplicate,
  acceptedWithConflict,
  rejectedUnauthorized,
  rejectedSessionClosed,
  rejectedInvalidData,
}

class SyncPushReceipt {
  const SyncPushReceipt({
    required this.eventId,
    required this.decision,
    this.serverReceivedAt,
    this.reason,
  });
  final String eventId;
  final SyncPushDecision decision;
  final DateTime? serverReceivedAt;
  final String? reason;
}

abstract interface class SyncTransport {
  Future<List<SyncPushReceipt>> push(List<TimingEvent> events);
  Future<List<TimingEvent>> pull({required String deviceId});
}
