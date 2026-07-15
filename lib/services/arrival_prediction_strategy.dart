/// Austauschbare Prognose-Schnittstelle. Die aktuelle Berechnung kann später
/// optimiert werden, ohne UI, Persistenz oder Messwerterfassung zu verändern.
abstract interface class ArrivalPredictionStrategy {
  DateTime? predict({
    required DateTime startTime,
    required List<Duration> completedSegments,
    required int nextSegmentIndex,
  });
}

class RecentAverageArrivalPrediction implements ArrivalPredictionStrategy {
  const RecentAverageArrivalPrediction();

  @override
  DateTime? predict({
    required DateTime startTime,
    required List<Duration> completedSegments,
    required int nextSegmentIndex,
  }) {
    if (completedSegments.isEmpty) return null;
    final averageMicros = completedSegments
            .map((duration) => duration.inMicroseconds)
            .reduce((a, b) => a + b) ~/
        completedSegments.length;
    return startTime.add(Duration(microseconds: averageMicros * (nextSegmentIndex + 1)));
  }
}
