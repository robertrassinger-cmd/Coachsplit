import 'sync/sync_engine.dart';

/// UI-neutrale Anwendungsgrenze für den manuellen oder später automatischen Sync.
class SyncService {
  SyncService(this._engine);
  final SyncEngine _engine;
  Future<SyncRunResult> synchronize() => _engine.synchronize();
}
