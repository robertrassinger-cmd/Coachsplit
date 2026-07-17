part of coachsplit;

typedef CaptureTimeResolver = DateTime? Function(Athlete athlete, SplitPoint point);
typedef ElapsedResolver = Duration Function(Athlete athlete, SplitPoint point, DateTime time);
typedef SectionDurationResolver = Duration? Function(Athlete athlete, SplitPoint point);
typedef RankingGroupResolver = String Function(Athlete athlete);

/// Berechnet Platz, Rückstand und Abschnittswerte unabhängig von der UI.
class RankingService {
  const RankingService();

  List<RankRow> calculate({
    required List<Athlete> athletes,
    required SplitPoint point,
    required bool compareByCategory,
    required CaptureTimeResolver captureTime,
    required ElapsedResolver elapsed,
    required SectionDurationResolver sectionDuration,
    required RankingGroupResolver groupFor,
  }) {
    final raw = <MapEntry<Athlete, Duration>>[];
    for (final athlete in athletes) {
      final time = captureTime(athlete, point);
      if (time == null) continue;
      raw.add(MapEntry(athlete, elapsed(athlete, point, time)));
    }

    final grouped = <String, List<MapEntry<Athlete, Duration>>>{};
    for (final item in raw) {
      grouped.putIfAbsent(groupFor(item.key), () => []).add(item);
    }

    final rows = <RankRow>[];
    for (final groupRows in grouped.values) {
      groupRows.sort((a, b) => a.value.compareTo(b.value));
      if (groupRows.isEmpty) continue;

      final leader = groupRows.first.value;
      final athletesInGroup = groupRows.map((entry) => entry.key).toList();
      final sectionPlaces = _sectionPlaces(
        point: point,
        athletes: athletesInGroup,
        sectionDuration: sectionDuration,
      );
      final sectionDeltas = _sectionDeltas(
        point: point,
        athletes: athletesInGroup,
        sectionDuration: sectionDuration,
      );

      for (var index = 0; index < groupRows.length; index++) {
        final athlete = groupRows[index].key;
        rows.add(RankRow(
          athlete: athlete,
          elapsed: groupRows[index].value,
          place: index + 1,
          deltaToLeader: groupRows[index].value - leader,
          sectionElapsed: sectionDuration(athlete, point),
          sectionDelta: sectionDeltas[athlete.bib],
          sectionPlace: sectionPlaces[athlete.bib],
        ));
      }
    }

    rows.sort((a, b) {
      if (compareByCategory) {
        final category = a.athlete.category.compareTo(b.athlete.category);
        if (category != 0) return category;
      }
      return a.place.compareTo(b.place);
    });
    return rows;
  }

  Map<int, int> _sectionPlaces({
    required SplitPoint point,
    required List<Athlete> athletes,
    required SectionDurationResolver sectionDuration,
  }) {
    final values = <MapEntry<int, Duration>>[];
    for (final athlete in athletes) {
      final duration = sectionDuration(athlete, point);
      if (duration != null) values.add(MapEntry(athlete.bib, duration));
    }
    values.sort((a, b) => a.value.compareTo(b.value));
    return {for (var index = 0; index < values.length; index++) values[index].key: index + 1};
  }

  Map<int, Duration> _sectionDeltas({
    required SplitPoint point,
    required List<Athlete> athletes,
    required SectionDurationResolver sectionDuration,
  }) {
    final values = <int, Duration>{};
    for (final athlete in athletes) {
      final duration = sectionDuration(athlete, point);
      if (duration != null) values[athlete.bib] = duration;
    }
    if (values.isEmpty) return const {};
    final best = values.values.reduce((a, b) => a <= b ? a : b);
    return values.map((bib, duration) => MapEntry(bib, duration - best));
  }
}
