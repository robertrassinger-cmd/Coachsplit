import 'domain_enums.dart';
import 'route.dart';

class SessionConditions {
  const SessionConditions({
    this.temperatureCelsius,
    this.weather,
    this.snowCondition,
    this.trackCondition,
    this.wind,
    this.notes,
  });

  final double? temperatureCelsius;
  final String? weather;
  final String? snowCondition;
  final String? trackCondition;
  final String? wind;
  final String? notes;

  bool get isEmpty =>
      temperatureCelsius == null &&
      weather == null &&
      snowCondition == null &&
      trackCondition == null &&
      wind == null &&
      notes == null;

  Map<String, Object?> toJson() => {
        'temperatureCelsius': temperatureCelsius,
        'weather': weather,
        'snowCondition': snowCondition,
        'trackCondition': trackCondition,
        'wind': wind,
        'notes': notes,
      };

  factory SessionConditions.fromJson(Map<String, Object?> json) =>
      SessionConditions(
        temperatureCelsius:
            (json['temperatureCelsius'] as num?)?.toDouble(),
        weather: json['weather'] as String?,
        snowCondition: json['snowCondition'] as String?,
        trackCondition: json['trackCondition'] as String?,
        wind: json['wind'] as String?,
        notes: json['notes'] as String?,
      );
}

class ActivitySession {
  const ActivitySession({
    required this.id,
    required this.type,
    required this.title,
    required this.route,
    required this.status,
    required this.ownerId,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.location,
    this.conditions,
    this.schemaVersion = 1,
  })  : assert(id != ''),
        assert(ownerId != ''),
        assert(schemaVersion > 0);

  final String id;
  final ActivityType type;
  final String title;
  final RouteReference route;
  final ActivityStatus status;
  final String ownerId;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  // Optional und mobil nicht blockierend.
  final String? location;
  final SessionConditions? conditions;
  final int schemaVersion;

  bool get isEditable => status == ActivityStatus.draft;
  bool get isLive => status == ActivityStatus.running;
  bool get isHistorical =>
      status == ActivityStatus.completed || status == ActivityStatus.archived;

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'route': route.toJson(),
        'status': status.name,
        'ownerId': ownerId,
        'createdAt': createdAt.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'location': location,
        'conditions': conditions?.toJson(),
        'schemaVersion': schemaVersion,
      };

  factory ActivitySession.fromJson(Map<String, Object?> json) => ActivitySession(
        id: json['id']! as String,
        type: ActivityType.values.byName(json['type']! as String),
        title: json['title']! as String,
        route:
            RouteReference.fromJson(json['route']! as Map<String, Object?>),
        status: ActivityStatus.values.byName(json['status']! as String),
        ownerId: json['ownerId']! as String,
        createdAt: DateTime.parse(json['createdAt']! as String),
        startedAt: json['startedAt'] == null
            ? null
            : DateTime.parse(json['startedAt']! as String),
        finishedAt: json['finishedAt'] == null
            ? null
            : DateTime.parse(json['finishedAt']! as String),
        location: json['location'] as String?,
        conditions: json['conditions'] == null
            ? null
            : SessionConditions.fromJson(
                json['conditions']! as Map<String, Object?>,
              ),
        schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      );
}
