import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:coachsplit/domain/v2/domain_enums.dart';
import 'package:coachsplit/domain/v2/timing_event.dart';
import 'package:coachsplit/repositories/v2/sembast_timing_event_repository.dart';

void main() {
  test('append is idempotent and events survive repository recreation', () async {
    final database = await databaseFactoryMemory.openDatabase('timing-test.db');
    Future<Database> openDatabase() async => database;
    final firstRepository = SembastTimingEventRepository(openDatabase: openDatabase);
    final event = TimingEvent(
      id: 'event-1',
      sessionId: 'session-1',
      participationId: 'participation-1',
      athleteId: 'athlete-1',
      measurementPointId: 'split-1',
      kind: TimingEventKind.split,
      activityTimeMs: 42000,
      deviceTime: DateTime.utc(2026, 7, 17, 10, 0, 42),
      createdByUserId: 'trainer',
      deviceId: 'device-1',
    );

    await firstRepository.append(event);
    await firstRepository.append(event);

    final secondRepository = SembastTimingEventRepository(openDatabase: openDatabase);
    final restored = await secondRepository.forSession('session-1');

    expect(restored, hasLength(1));
    expect(restored.single.id, event.id);
    expect(restored.single.activityTimeMs, 42000);

    await database.close();
  });

  test('same event id with different payload is rejected', () async {
    final database =
        await databaseFactoryMemory.openDatabase('timing-conflict-test.db');
    Future<Database> openDatabase() async => database;
    final repository = SembastTimingEventRepository(openDatabase: openDatabase);
    final original = TimingEvent(
      id: 'event-conflict',
      sessionId: 'session-1',
      participationId: 'participation-1',
      athleteId: 'athlete-1',
      measurementPointId: 'split-1',
      kind: TimingEventKind.split,
      activityTimeMs: 42000,
      deviceTime: DateTime.utc(2026, 7, 17, 10, 0, 42),
      createdByUserId: 'trainer',
      deviceId: 'device-1',
    );
    final conflicting = TimingEvent(
      id: original.id,
      sessionId: original.sessionId,
      participationId: original.participationId,
      athleteId: original.athleteId,
      measurementPointId: original.measurementPointId,
      kind: original.kind,
      activityTimeMs: 43000,
      deviceTime: original.deviceTime,
      createdByUserId: original.createdByUserId,
      deviceId: original.deviceId,
    );

    await repository.append(original);
    await expectLater(repository.append(conflicting), throwsStateError);
    expect(await repository.forSession('session-1'), hasLength(1));

    await database.close();
  });
}
