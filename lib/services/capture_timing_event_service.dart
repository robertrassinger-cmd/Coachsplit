import 'package:uuid/uuid.dart';

import '../domain/v2/domain_enums.dart';
import '../domain/v2/timing_event.dart';
import '../repositories/v2/timing_event_repository.dart';

class CaptureTimingEventService {
  CaptureTimingEventService({
    required TimingEventRepository repository,
    required this.createdByUserId,
    required this.deviceId,
  }) : _repository = repository;

  final TimingEventRepository _repository;
  final String createdByUserId;
  final String deviceId;
  static const Uuid _uuid = Uuid();

  Future<TimingEvent> capture({
    required String sessionId,
    required String participationId,
    required String athleteId,
    required String measurementPointId,
    required TimingEventKind kind,
    required DateTime athleteStart,
    required DateTime capturedAt,
    ShootingData? shootingData,
  }) async {
    final elapsed = capturedAt.difference(athleteStart).inMilliseconds;
    if (elapsed < 0) {
      throw StateError('Die Messzeit liegt vor der Startzeit des Athleten.');
    }

    final event = TimingEvent(
      id: _uuid.v7(),
      sessionId: sessionId,
      participationId: participationId,
      athleteId: athleteId,
      measurementPointId: measurementPointId,
      kind: kind,
      activityTimeMs: elapsed,
      deviceTime: capturedAt,
      createdByUserId: createdByUserId,
      deviceId: deviceId,
      shootingData: shootingData,
      syncState: SyncState.pending,
    );
    await _repository.append(event);
    return event;
  }

  Future<TimingEvent> cancel(TimingEvent original, DateTime cancelledAt) async {
    final cancellation = TimingEvent(
      id: _uuid.v7(),
      sessionId: original.sessionId,
      participationId: original.participationId,
      athleteId: original.athleteId,
      measurementPointId: original.measurementPointId,
      kind: TimingEventKind.correction,
      activityTimeMs: original.activityTimeMs,
      deviceTime: cancelledAt,
      createdByUserId: createdByUserId,
      deviceId: deviceId,
      correctionOfEventId: original.id,
      syncState: SyncState.pending,
    );
    await _repository.append(cancellation);
    return cancellation;
  }
}
