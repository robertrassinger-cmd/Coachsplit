import '../../domain/v2/timing_event.dart';

enum RemoteEventImportResult { inserted, alreadyPresent, conflict }

abstract interface class TimingEventRepository {
  Stream<List<TimingEvent>> watchForSession(String sessionId);
  Future<void> append(TimingEvent event);
  Future<List<TimingEvent>> forSession(String sessionId);
  Future<List<TimingEvent>> pendingSync({String? sessionId, int limit = 100});
  Future<TimingEvent?> findById(String eventId);
  Future<void> markPending(String eventId, {DateTime? attemptedAt});
  Future<void> markSynced(String eventId, {DateTime? serverReceivedAt});
  Future<void> markFailed(String eventId, String reason, {DateTime? attemptedAt});
  Future<void> markConflict(String eventId, String reason);
  Future<RemoteEventImportResult> importRemote(TimingEvent event);
}
