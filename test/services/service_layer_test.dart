import 'package:flutter_test/flutter_test.dart';
import 'package:coachsplit/main.dart';

void main() {
  test('first shooting range receives number 1 even when split labels contain numbers', () {
    const service = ShootingRangeNumberService();
    final points = [
      SplitPoint(id: 'split', name: 'Zwischenzeit 1', type: PointType.split, shootingRangeNumber: 1),
      SplitPoint(id: 'finish', name: 'Ziel', type: PointType.finish),
    ];
    expect(service.nextNumber(points), 1);
  });

  test('entry and exit count as one shooting range', () {
    const service = ShootingRangeNumberService();
    final points = [
      SplitPoint(id: 'in', name: 'Schießstand 1 ein', type: PointType.shootingEntry, shootingRangeNumber: 1),
      SplitPoint(id: 'out', name: 'Schießstand 1 aus', type: PointType.shootingExit, shootingRangeNumber: 1),
    ];
    expect(service.nextNumber(points), 2);
  });

  test('penalty service applies seconds per miss only when enabled', () {
    const service = PenaltyService();
    final athlete = Athlete(
      bib: 1,
      name: 'Test',
      category: 'AK',
      isOwn: true,
      scheduledStart: DateTime(2026),
      shootingResults: {
        'range': ShootingResult(position: ShootingPosition.prone, misses: 2),
      },
    );
    expect(service.penaltyFor(athlete: athlete, enabled: false, secondsPerMiss: 30), Duration.zero);
    expect(service.penaltyFor(athlete: athlete, enabled: true, secondsPerMiss: 30), const Duration(seconds: 60));
  });

  test('penalty can be calculated from misses already accumulated at a point', () {
    const service = PenaltyService();
    expect(
      service.penaltyForMisses(misses: 3, enabled: true, secondsPerMiss: 20),
      const Duration(seconds: 60),
    );
  });
}
