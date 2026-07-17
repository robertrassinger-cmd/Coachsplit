import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:coachsplit/domain/v2/domain_enums.dart';
import 'package:coachsplit/domain/v2/timing_event.dart';
import 'package:coachsplit/repositories/v2/timing_event_repository.dart';
import 'package:coachsplit/services/capture_timing_event_service.dart';

class MemoryTimingEventRepository implements TimingEventRepository {
  final Map<String, TimingEvent> events = {};

  @override
  Future<void> append(TimingEvent event) async {
    events.putIfAbsent(event.id, () => event);
  }

  @override
  Future<List<TimingEvent>> forSession(String sessionId) async =>
      events.values.where((event) => event.sessionId == sessionId).toList();

  @override
  Future<List<TimingEvent>> pendingSync({String? sessionId, int limit = 100}) async => events.values.take(limit).toList();
  @override
  Future<TimingEvent?> findById(String eventId) async => events[eventId];

  @override
  Future<void> markPending(String eventId, {DateTime? attemptedAt}) async {}

  @override
  Future<void> markSynced(String eventId, {DateTime? serverReceivedAt}) async {}

  @override
  Future<void> markFailed(String eventId, String reason, {DateTime? attemptedAt}) async {}

  @override
  Future<void> markConflict(String eventId, String reason) async {}

  @override
  Future<RemoteEventImportResult> importRemote(TimingEvent event) async {
    final existing = events[event.id];
    if (existing == null) { events[event.id] = event; return RemoteEventImportResult.inserted; }
    return RemoteEventImportResult.alreadyPresent;
  }


  @override
  Stream<List<TimingEvent>> watchForSession(String sessionId) async* {
    yield await forSession(sessionId);
  }
}

void main() {
  test('capture persists an immutable timing event before returning', () async {
    final repository = MemoryTimingEventRepository();
    final service = CaptureTimingEventService(
      repository: repository,
      createdByUserId: 'trainer',
      deviceId: 'device-1',
    );
    final start = DateTime.utc(2026, 7, 17, 10);

    final event = await service.capture(
      sessionId: 'session-1',
      participationId: 'participation-1',
      athleteId: 'athlete-1',
      measurementPointId: 'split-1',
      kind: TimingEventKind.split,
      athleteStart: start,
      capturedAt: start.add(const Duration(seconds: 42)),
    );

    expect(repository.events[event.id], same(event));
    expect(event.activityTimeMs, 42000);
  });

  test('cancel appends a correction instead of deleting the original', () async {
    final repository = MemoryTimingEventRepository();
    final service = CaptureTimingEventService(
      repository: repository,
      createdByUserId: 'trainer',
      deviceId: 'device-1',
    );
    final start = DateTime.utc(2026, 7, 17, 10);
    final original = await service.capture(
      sessionId: 'session-1',
      participationId: 'participation-1',
      athleteId: 'athlete-1',
      measurementPointId: 'split-1',
      kind: TimingEventKind.split,
      athleteStart: start,
      capturedAt: start.add(const Duration(seconds: 42)),
    );

    final correction = await service.cancel(
      original,
      start.add(const Duration(seconds: 45)),
    );

    expect(repository.events, hasLength(2));
    expect(repository.events.containsKey(original.id), isTrue);
    expect(correction.kind, TimingEventKind.correction);
    expect(correction.correctionOfEventId, original.id);
  });
}
