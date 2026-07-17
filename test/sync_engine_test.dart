import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:coachsplit/domain/v2/domain_enums.dart';
import 'package:coachsplit/domain/v2/timing_event.dart';
import 'package:coachsplit/repositories/v2/timing_event_repository.dart';
import 'package:coachsplit/services/sync/sync_engine.dart';
import 'package:coachsplit/services/sync/sync_transport.dart';

class MemoryRepository implements TimingEventRepository {
  final Map<String, TimingEvent> events = {};
  @override Future<void> append(TimingEvent event) async => events[event.id] = event;
  @override Future<TimingEvent?> findById(String id) async => events[id];
  @override Future<List<TimingEvent>> forSession(String id) async => events.values.where((e) => e.sessionId == id).toList();
  @override Stream<List<TimingEvent>> watchForSession(String id) async* { yield await forSession(id); }
  @override Future<List<TimingEvent>> pendingSync({String? sessionId, int limit = 100}) async => events.values.where((e) => (sessionId == null || e.sessionId == sessionId) && e.syncState != SyncState.synced && e.syncState != SyncState.conflict).take(limit).toList();
  @override Future<void> markPending(String id, {DateTime? attemptedAt}) async { final e=events[id]!; events[id]=e.copyWith(syncState: SyncState.pending, syncAttempts: e.syncAttempts+1, lastSyncAttemptAt: attemptedAt); }
  @override Future<void> markSynced(String id, {DateTime? serverReceivedAt}) async { events[id]=events[id]!.copyWith(syncState: SyncState.synced, serverReceivedAt: serverReceivedAt); }
  @override Future<void> markFailed(String id, String reason, {DateTime? attemptedAt}) async { events[id]=events[id]!.copyWith(syncState: SyncState.failed, lastSyncError: reason, lastSyncAttemptAt: attemptedAt); }
  @override Future<void> markConflict(String id, String reason) async { events[id]=events[id]!.copyWith(syncState: SyncState.conflict, lastSyncError: reason); }
  @override Future<RemoteEventImportResult> importRemote(TimingEvent event) async {
    final old=events[event.id];
    if(old==null){events[event.id]=event.copyWith(syncState: SyncState.synced); return RemoteEventImportResult.inserted;}
    if(old.canonicalPayload().toString()==event.canonicalPayload().toString()) return RemoteEventImportResult.alreadyPresent;
    events[event.id]=old.copyWith(syncState: SyncState.conflict); return RemoteEventImportResult.conflict;
  }
}

class MemoryTransport implements SyncTransport {
  List<TimingEvent> incoming = [];
  @override Future<List<TimingEvent>> pull({required String deviceId}) async => incoming;
  @override Future<List<SyncPushReceipt>> push(List<TimingEvent> events) async => events.map((e) => SyncPushReceipt(eventId: e.id, decision: SyncPushDecision.accepted)).toList();
}

TimingEvent event(String id, {String device='device-a'}) => TimingEvent(
  id:id, sessionId:'session', participationId:'p', athleteId:'a',
  measurementPointId:'start', kind:TimingEventKind.start, activityTimeMs:0,
  deviceTime:DateTime.utc(2026), createdByUserId:'trainer', deviceId:device,
  syncState:SyncState.pending,
);

void main(){
  test('push marks local event synced and imports remote event idempotently', () async {
    final repository=MemoryRepository();
    await repository.append(event('local'));
    final transport=MemoryTransport()..incoming=[event('remote', device:'device-b')];
    final engine=SyncEngine(repository:repository, transport:transport, deviceId:'device-a', sessionId:'session');
    final result=await engine.synchronize();
    expect(result.pushed,1);
    expect(result.received,1);
    expect(repository.events['local']!.syncState,SyncState.synced);
    expect(repository.events['remote']!.syncState,SyncState.synced);
    final second=await engine.synchronize();
    expect(second.received,0);
  });
}
