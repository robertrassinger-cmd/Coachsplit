/// Cloud- und offlinefähiger Vertrag für eine einzelne Erfassung.
/// Die bestehende UI wird schrittweise auf dieses unveränderliche Modell migriert.
enum RaceEventKind { start, split, shootingEntry, shootingExit, finish, correction, dnf }

class RaceEventRecord {
  const RaceEventRecord({
    required this.id,
    required this.competitionId,
    required this.athleteId,
    required this.measurementPointId,
    required this.kind,
    required this.competitionTimeMs,
    required this.deviceTime,
    required this.createdByUserId,
    this.shootingPosition,
    this.misses,
    this.correctionOfEventId,
  });

  final String id;
  final String competitionId;
  final String athleteId;
  final String measurementPointId;
  final RaceEventKind kind;
  final int competitionTimeMs;
  final DateTime deviceTime;
  final String createdByUserId;
  final String? shootingPosition;
  final int? misses;
  final String? correctionOfEventId;
}
