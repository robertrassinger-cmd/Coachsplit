import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:coachsplit/main.dart';

RaceEvent _event({required String id, required String name}) {
  final start = DateTime.utc(2026, 7, 17, 10);
  final athlete = Athlete(
    id: 'athlete-$id',
    participationId: 'participation-$id',
    bib: 1,
    name: 'Test Athlete',
    category: 'AK',
    isOwn: true,
    scheduledStart: start,
    captures: {'split-1': start.add(const Duration(seconds: 42))},
  );
  return RaceEvent(
    id: id,
    name: name,
    firstStart: start,
    intervalSeconds: 30,
    compareByCategory: false,
    athletes: [athlete],
    points: [
      SplitPoint(id: 'split-1', name: 'Zwischenzeit', type: PointType.split),
      SplitPoint(id: 'finish', name: 'Ziel', type: PointType.finish),
    ],
  );
}

void main() {
  test('active metadata and archive snapshots survive repository recreation',
      () async {
    final database =
        await databaseFactoryMemory.openDatabase('competition-test.db');
    Future<Database> openDatabase() async => database;

    final repository =
        SembastLocalCompetitionRepository(openDatabase: openDatabase);
    final active = _event(id: 'active-1', name: 'Aktiv');
    final archived = _event(id: 'archive-1', name: 'Archiv');
    archived.status = CompetitionStatus.archived;

    await repository.replaceAll(
      activeEvents: [active],
      archivedEvents: [archived],
    );

    final restored = await SembastLocalCompetitionRepository(
      openDatabase: openDatabase,
    ).load();

    expect(restored.activeEvents, hasLength(1));
    expect(restored.archivedEvents, hasLength(1));
    expect(restored.activeEvents.single.id, 'active-1');
    expect(
      restored.activeEvents.single.athletes.single.captures,
      isEmpty,
      reason: 'Aktive Messungen werden aus TimingEvents rekonstruiert.',
    );
    expect(
      restored.archivedEvents.single.athletes.single.captures,
      isNotEmpty,
      reason: 'Das Archiv bleibt ein vollständiger Snapshot.',
    );

    await database.close();
  });

  test('replaceAll is atomic and removes records no longer present', () async {
    final database =
        await databaseFactoryMemory.openDatabase('replace-test.db');
    Future<Database> openDatabase() async => database;
    final repository =
        SembastLocalCompetitionRepository(openDatabase: openDatabase);

    await repository.replaceAll(
      activeEvents: [
        _event(id: 'one', name: 'Eins'),
        _event(id: 'two', name: 'Zwei'),
      ],
      archivedEvents: const [],
    );
    await repository.replaceAll(
      activeEvents: [_event(id: 'two', name: 'Zwei')],
      archivedEvents: const [],
    );

    final restored = await repository.load();
    expect(restored.activeEvents.map((event) => event.id), ['two']);

    await database.close();
  });

  test('duplicate competition ids across active and archive are rejected',
      () async {
    final database =
        await databaseFactoryMemory.openDatabase('duplicate-id-test.db');
    Future<Database> openDatabase() async => database;
    final repository =
        SembastLocalCompetitionRepository(openDatabase: openDatabase);

    await expectLater(
      repository.replaceAll(
        activeEvents: [_event(id: 'same-id', name: 'Aktiv')],
        archivedEvents: [_event(id: 'same-id', name: 'Archiv')],
      ),
      throwsStateError,
    );

    await database.close();
  });

  test('corrupt competition records are reported instead of ignored', () async {
    final database =
        await databaseFactoryMemory.openDatabase('corrupt-test.db');
    Future<Database> openDatabase() async => database;
    final store = stringMapStoreFactory.store('competitions');
    await store.record('broken').put(database, {
      'bucket': 'active',
      'schemaVersion': 1,
      'event': 'not-a-map',
    });

    final repository =
        SembastLocalCompetitionRepository(openDatabase: openDatabase);
    await expectLater(repository.load(), throwsFormatException);

    await database.close();
  });

  test('targeted save archive and delete operations are atomic', () async {
    final database =
        await databaseFactoryMemory.openDatabase('targeted-operations-test.db');
    Future<Database> openDatabase() async => database;
    final CompetitionRepository repository =
        SembastCompetitionRepository(openDatabase: openDatabase);
    final event = _event(id: 'targeted-1', name: 'Gezielt');

    await repository.saveActive(event);
    var restored = await repository.load();
    expect(restored.activeEvents.map((item) => item.id), ['targeted-1']);
    expect(restored.archivedEvents, isEmpty);
    expect(restored.activeEvents.single.athletes.single.captures, isEmpty);

    await repository.archive(event);
    restored = await repository.load();
    expect(restored.activeEvents, isEmpty);
    expect(restored.archivedEvents.map((item) => item.id), ['targeted-1']);
    expect(restored.archivedEvents.single.status, CompetitionStatus.archived);
    expect(restored.archivedEvents.single.athletes.single.captures, isNotEmpty);

    await repository.delete(event.id);
    restored = await repository.load();
    expect(restored.isEmpty, isTrue);

    await database.close();
  });

  test('unknown competition schema version is rejected', () async {
    final database =
        await databaseFactoryMemory.openDatabase('schema-version-test.db');
    Future<Database> openDatabase() async => database;
    final store = stringMapStoreFactory.store('competitions');
    final event = _event(id: 'future', name: 'Zukunft');
    await store.record(event.id).put(database, {
      'bucket': 'active',
      'schemaVersion': 999,
      'event': event.toJson(),
    });

    final repository =
        SembastCompetitionRepository(openDatabase: openDatabase);
    await expectLater(repository.load(), throwsFormatException);

    await database.close();
  });

}
