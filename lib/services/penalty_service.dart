part of coachsplit;

/// Zentrale Quelle der Wahrheit für Schießfehler und Zeitstrafen.
class PenaltyService {
  const PenaltyService();

  int totalMisses(Athlete athlete) => athlete.shootingResults.values
      .fold<int>(0, (sum, result) => sum + result.misses);


  Duration penaltyForMisses({
    required int misses,
    required bool enabled,
    required int secondsPerMiss,
  }) {
    if (!enabled || secondsPerMiss <= 0 || misses <= 0) return Duration.zero;
    return Duration(seconds: misses * secondsPerMiss);
  }

  Duration penaltyFor({
    required Athlete athlete,
    required bool enabled,
    required int secondsPerMiss,
  }) {
    return penaltyForMisses(
      misses: totalMisses(athlete),
      enabled: enabled,
      secondsPerMiss: secondsPerMiss,
    );
  }

  Duration officialElapsed({
    required Athlete athlete,
    required Duration rawElapsed,
    required bool applyPenalty,
    required bool enabled,
    required int secondsPerMiss,
  }) {
    if (!applyPenalty) return rawElapsed;
    return rawElapsed + penaltyFor(
      athlete: athlete,
      enabled: enabled,
      secondsPerMiss: secondsPerMiss,
    );
  }
}
