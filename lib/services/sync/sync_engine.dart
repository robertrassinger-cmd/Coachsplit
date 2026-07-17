import '../../repositories/v2/timing_event_repository.dart';
import 'sync_transport.dart';

class SyncRunResult {
  const SyncRunResult({
    required this.pushed,
    required this.received,
    required this.conflicts,
    required this.failed,
  });
  final int pushed;
  final int received;
  final int conflicts;
  final int failed;
}

class SyncEngine {
  SyncEngine({
    required TimingEventRepository repository,
    required SyncTransport transport,
    required this.deviceId,
    required this.sessionId,
    this.batchSize = 100,
  })  : _repository = repository,
        _transport = transport;

  final TimingEventRepository _repository;
  final SyncTransport _transport;
  final String deviceId;
  final String sessionId;
  final int batchSize;
  Future<SyncRunResult>? _activeRun;

  Future<SyncRunResult> synchronize() => _activeRun ??= _run().whenComplete(() {
        _activeRun = null;
      });

  Future<SyncRunResult> _run() async {
    var pushed = 0;
    var received = 0;
    var conflicts = 0;
    var failed = 0;
    final outgoing = await _repository.pendingSync(sessionId: sessionId, limit: batchSize);

    if (outgoing.isNotEmpty) {
      final attemptTime = DateTime.now().toUtc();
      for (final event in outgoing) {
        await _repository.markPending(event.id, attemptedAt: attemptTime);
      }
      try {
        final receipts = await _transport.push(outgoing);
        final receiptById = {for (final receipt in receipts) receipt.eventId: receipt};
        for (final event in outgoing) {
          final receipt = receiptById[event.id];
          if (receipt == null) {
            failed++;
            await _repository.markFailed(
              event.id,
              'Transport hat keine Bestätigung geliefert.',
            );
          } else {
            switch (receipt.decision) {
              case SyncPushDecision.accepted:
              case SyncPushDecision.duplicate:
                pushed++;
                await _repository.markSynced(
                  event.id,
                  serverReceivedAt: receipt.serverReceivedAt,
                );
                break;
              case SyncPushDecision.acceptedWithConflict:
                conflicts++;
                await _repository.markConflict(
                  event.id,
                  receipt.reason ?? 'Server hat einen fachlichen Konflikt erkannt.',
                );
                break;
              case SyncPushDecision.rejectedUnauthorized:
              case SyncPushDecision.rejectedSessionClosed:
              case SyncPushDecision.rejectedInvalidData:
                failed++;
                await _repository.markFailed(
                  event.id,
                  receipt.reason ?? 'Server hat das Ereignis abgelehnt.',
                );
                break;
            }
          }
        }
      } catch (error) {
        failed += outgoing.length;
        for (final event in outgoing) {
          await _repository.markFailed(event.id, error.toString());
        }
      }
    }

    try {
      final incoming = await _transport.pull(deviceId: deviceId);
      for (final event in incoming) {
        final result = await _repository.importRemote(event);
        switch (result) {
          case RemoteEventImportResult.inserted:
            received++;
            break;
          case RemoteEventImportResult.alreadyPresent:
            break;
          case RemoteEventImportResult.conflict:
            conflicts++;
        }
      }
    } catch (_) {
      failed++;
    }

    return SyncRunResult(
      pushed: pushed,
      received: received,
      conflicts: conflicts,
      failed: failed,
    );
  }
}
