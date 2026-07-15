import '../domain/race_event_contract.dart';

/// Schnittstelle zwischen Fachlogik und lokaler/Cloud-Persistenz.
abstract interface class RaceEventRepository {
  Stream<List<RaceEventRecord>> watchEvents(String competitionId);
  Future<void> append(RaceEventRecord event);
  Future<List<RaceEventRecord>> pendingSync(String competitionId);
}
