import 'domain_enums.dart';

class AthleteParticipation {
  const AthleteParticipation({
    required this.id,
    required this.sessionId,
    required this.athleteId,
    required this.status,
    this.bibNumber,
    this.scheduledStartTimeMs,
    this.actualStartTimeMs,
    this.finishTimeMs,
  })  : assert(id != ''),
        assert(sessionId != ''),
        assert(athleteId != '');

  final String id;
  final String sessionId;
  final String athleteId;
  final ParticipationStatus status;
  final int? bibNumber;
  final int? scheduledStartTimeMs;
  final int? actualStartTimeMs;
  final int? finishTimeMs;

  bool get isActive =>
      status == ParticipationStatus.started ||
      status == ParticipationStatus.racing;

  bool get hasFinished => status == ParticipationStatus.finished;

  Map<String, Object?> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'athleteId': athleteId,
        'status': status.name,
        'bibNumber': bibNumber,
        'scheduledStartTimeMs': scheduledStartTimeMs,
        'actualStartTimeMs': actualStartTimeMs,
        'finishTimeMs': finishTimeMs,
      };

  factory AthleteParticipation.fromJson(Map<String, Object?> json) =>
      AthleteParticipation(
        id: json['id']! as String,
        sessionId: json['sessionId']! as String,
        athleteId: json['athleteId']! as String,
        status:
            ParticipationStatus.values.byName(json['status']! as String),
        bibNumber: (json['bibNumber'] as num?)?.toInt(),
        scheduledStartTimeMs:
            (json['scheduledStartTimeMs'] as num?)?.toInt(),
        actualStartTimeMs:
            (json['actualStartTimeMs'] as num?)?.toInt(),
        finishTimeMs: (json['finishTimeMs'] as num?)?.toInt(),
      );
}
