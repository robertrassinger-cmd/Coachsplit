import 'dart:convert';

import 'package:sembast/sembast.dart';

import '../../domain/v2/domain_enums.dart';
import '../../domain/v2/timing_event.dart';
import '../../infrastructure/local_database_factory.dart';
import 'timing_event_repository.dart';

class SembastTimingEventRepository implements TimingEventRepository {
  SembastTimingEventRepository({Future<Database> Function()? openDatabase})
      : _openDatabase = openDatabase ?? openCoachSplitDatabase;

  final Future<Database> Function() _openDatabase;
  final StoreRef<String, Map<String, Object?>> _store =
      stringMapStoreFactory.store('timing_events');
  Future<Database>? _database;

  Future<Database> get _db => _database ??= _openDatabase();

  String _canonical(TimingEvent event) => jsonEncode(event.canonicalPayload());

  @override
  Future<void> append(TimingEvent event) async {
    final db = await _db;
    await db.transaction((transaction) async {
      final record = _store.record(event.id);
      final existing = await record.get(transaction);
      if (existing != null) {
        final stored = TimingEvent.fromJson(existing);
        if (_canonical(stored) != _canonical(event)) {
          throw StateError(
            'TimingEvent-ID ${event.id} existiert bereits mit anderem Inhalt.',
          );
        }
        return;
      }
      await record.put(transaction, event.toJson());
    });
  }

  @override
  Future<TimingEvent?> findById(String eventId) async {
    final value = await _store.record(eventId).get(await _db);
    return value == null ? null : TimingEvent.fromJson(value);
  }

  @override
  Future<List<TimingEvent>> forSession(String sessionId) async {
    final snapshots = await _store.find(
      await _db,
      finder: Finder(
        filter: Filter.equals('sessionId', sessionId),
        sortOrders: [SortOrder('activityTimeMs'), SortOrder('deviceTime')],
      ),
    );
    return snapshots.map((snapshot) => TimingEvent.fromJson(snapshot.value)).toList();
  }

  @override
  Stream<List<TimingEvent>> watchForSession(String sessionId) async* {
    final db = await _db;
    final query = _store.query(
      finder: Finder(
        filter: Filter.equals('sessionId', sessionId),
        sortOrders: [SortOrder('activityTimeMs'), SortOrder('deviceTime')],
      ),
    );
    yield* query.onSnapshots(db).map(
          (snapshots) => snapshots
              .map((snapshot) => TimingEvent.fromJson(snapshot.value))
              .toList(),
        );
  }

  @override
  Future<List<TimingEvent>> pendingSync({String? sessionId, int limit = 100}) async {
    if (limit <= 0) return const [];
    final snapshots = await _store.find(
      await _db,
      finder: Finder(
        filter: Filter.and([
          Filter.inList('syncState', [
            SyncState.localOnly.name,
            SyncState.pending.name,
            SyncState.failed.name,
          ]),
          if (sessionId != null) Filter.equals('sessionId', sessionId),
        ]),
        sortOrders: [SortOrder('deviceTime')],
        limit: limit,
      ),
    );
    return snapshots.map((snapshot) => TimingEvent.fromJson(snapshot.value)).toList();
  }

  Future<void> _update(
    String eventId,
    TimingEvent Function(TimingEvent event) transform,
  ) async {
    final db = await _db;
    await db.transaction((transaction) async {
      final record = _store.record(eventId);
      final value = await record.get(transaction);
      if (value == null) {
        throw StateError('TimingEvent $eventId wurde nicht gefunden.');
      }
      await record.put(transaction, transform(TimingEvent.fromJson(value)).toJson());
    });
  }

  @override
  Future<void> markPending(String eventId, {DateTime? attemptedAt}) => _update(
        eventId,
        (event) => event.copyWith(
          syncState: SyncState.pending,
          syncAttempts: event.syncAttempts + 1,
          lastSyncAttemptAt: attemptedAt ?? DateTime.now().toUtc(),
          clearLastSyncError: true,
        ),
      );

  @override
  Future<void> markSynced(String eventId, {DateTime? serverReceivedAt}) => _update(
        eventId,
        (event) => event.copyWith(
          syncState: SyncState.synced,
          serverReceivedAt: serverReceivedAt,
          clearLastSyncError: true,
        ),
      );

  @override
  Future<void> markFailed(
    String eventId,
    String reason, {
    DateTime? attemptedAt,
  }) =>
      _update(
        eventId,
        (event) => event.copyWith(
          syncState: SyncState.failed,
          lastSyncError: reason,
          lastSyncAttemptAt: attemptedAt ?? DateTime.now().toUtc(),
        ),
      );

  @override
  Future<void> markConflict(String eventId, String reason) => _update(
        eventId,
        (event) => event.copyWith(
          syncState: SyncState.conflict,
          lastSyncError: reason,
        ),
      );

  @override
  Future<RemoteEventImportResult> importRemote(TimingEvent event) async {
    final db = await _db;
    return db.transaction((transaction) async {
      final record = _store.record(event.id);
      final existingJson = await record.get(transaction);
      if (existingJson == null) {
        await record.put(
          transaction,
          event.copyWith(syncState: SyncState.synced).toJson(),
        );
        return RemoteEventImportResult.inserted;
      }
      final existing = TimingEvent.fromJson(existingJson);
      if (_canonical(existing) == _canonical(event)) {
        if (existing.syncState != SyncState.synced) {
          await record.put(
            transaction,
            existing.copyWith(syncState: SyncState.synced).toJson(),
          );
        }
        return RemoteEventImportResult.alreadyPresent;
      }
      await record.put(
        transaction,
        existing
            .copyWith(
              syncState: SyncState.conflict,
              lastSyncError: 'Gleiche Event-ID mit abweichendem Inhalt empfangen.',
            )
            .toJson(),
      );
      return RemoteEventImportResult.conflict;
    });
  }
}
