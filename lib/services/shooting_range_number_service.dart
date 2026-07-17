part of coachsplit;

/// Nummeriert fachliche Schießstände, nicht deren Ein- und Ausgangspunkte.
class ShootingRangeNumberService {
  const ShootingRangeNumberService();

  int nextNumber(List<SplitPoint> points) {
    final usedNumbers = points
        .where((point) =>
            point.type == PointType.shootingEntry ||
            point.type == PointType.shootingExit)
        .map((point) => point.shootingRangeNumber)
        .whereType<int>()
        .where((number) => number > 0)
        .toSet();
    if (usedNumbers.isEmpty) return 1;
    return usedNumbers.reduce(max) + 1;
  }
}
