import 'domain_enums.dart';
import 'participation.dart';
import 'route.dart';
import 'session.dart';
import 'timing_event.dart';

class AthleteSnapshot {
  const AthleteSnapshot({
    required this.athleteId,
    required this.displayName,
    this.category,
  });

  final String athleteId;
  final String displayName;
  final String? category;
}

class SessionArchiveSnapshot {
  SessionArchiveSnapshot({
    required this.session,
    required this.route,
    required List<AthleteSnapshot> athletes,
    required List<AthleteParticipation> participations,
    required List<TimingEvent> events,
    required this.archivedAt,
    required this.archivedByUserId,
    this.schemaVersion = 1,
  })  : athletes = List.unmodifiable(athletes),
        participations = List.unmodifiable(participations),
        events = List.unmodifiable(events);

  final ActivitySession session;
  final RouteDefinition route;
  final List<AthleteSnapshot> athletes;
  final List<AthleteParticipation> participations;
  final List<TimingEvent> events;
  final DateTime archivedAt;
  final String archivedByUserId;
  final int schemaVersion;

  ActivityType get activityType => session.type;
}
