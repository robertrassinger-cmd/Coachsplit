part of '../main.dart';

enum PointType { split, shootingEntry, shootingExit, finish }
enum AthleteStatus { waiting, running, finished, didNotFinish }
enum CompetitionStatus { draft, running, finished, archived }
enum ShootingPosition { prone, standing }

class ShootingResult {
  ShootingResult({required this.position, required this.misses});
  ShootingPosition position;
  int misses;
  Map<String, dynamic> toJson() => {'position': position.name, 'misses': misses};
  static ShootingResult fromJson(Map<String, dynamic> json) => ShootingResult(
        position: ShootingPosition.values.firstWhere(
          (value) => value.name == json['position'],
          orElse: () => ShootingPosition.prone,
        ),
        misses: ((json['misses'] as num?)?.toInt() ?? 0).clamp(0, 5) as int,
      );
}

class Athlete {
  Athlete({
    required this.bib,
    required this.name,
    required this.category,
    required this.isOwn,
    required this.scheduledStart,
    this.actualStart,
    this.status = AthleteStatus.waiting,
    Map<String, DateTime>? captures,
    Map<String, ShootingResult>? shootingResults,
  })  : captures = captures ?? {},
        shootingResults = shootingResults ?? {};

  int bib;
  String name;
  String category;
  bool isOwn;
  DateTime scheduledStart;
  DateTime? actualStart;
  AthleteStatus status;
  Map<String, DateTime> captures;
  Map<String, ShootingResult> shootingResults;

  DateTime get startTime => actualStart ?? scheduledStart;

  Map<String, dynamic> toJson() => {
        'bib': bib,
        'name': name,
        'category': category,
        'isOwn': isOwn,
        'scheduledStart': scheduledStart.toIso8601String(),
        'actualStart': actualStart?.toIso8601String(),
        'status': status.name,
        'captures': captures.map((k, v) => MapEntry(k, v.toIso8601String())),
        'shootingResults': shootingResults.map((k, v) => MapEntry(k, v.toJson())),
      };

  static Athlete fromJson(Map<String, dynamic> json) => Athlete(
        bib: (json['bib'] as num).toInt(),
        name: json['name'] as String,
        category: json['category'] as String,
        isOwn: json['isOwn'] as bool,
        scheduledStart: DateTime.parse(json['scheduledStart'] as String),
        actualStart: json['actualStart'] == null ? null : DateTime.parse(json['actualStart'] as String),
        status: AthleteStatus.values.firstWhere((s) => s.name == json['status'], orElse: () => AthleteStatus.waiting),
        captures: (json['captures'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, DateTime.parse(v as String))),
        shootingResults: (json['shootingResults'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, ShootingResult.fromJson(v as Map<String, dynamic>)),
        ),
      );
}

class SplitPoint {
  SplitPoint({required this.id, required this.name, required this.type, this.shootingRangeNumber, this.trainerNote});

  String id;
  String name;
  PointType type;
  int? shootingRangeNumber;
  String? trainerNote;

  bool get requiresShootingData => type == PointType.shootingExit;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'shootingRangeNumber': shootingRangeNumber,
        'trainerNote': trainerNote,
      };

  static SplitPoint fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String? ?? 'split';
    return SplitPoint(
      id: json['id'] as String,
      name: json['name'] as String,
      type: PointType.values.firstWhere((type) => type.name == rawType, orElse: () => rawType == 'finish' ? PointType.finish : PointType.split),
      shootingRangeNumber: (json['shootingRangeNumber'] as num?)?.toInt(),
      trainerNote: json['trainerNote'] as String?,
    );
  }
}

class RaceEvent {
  RaceEvent({
    required this.name,
    required this.firstStart,
    required this.intervalSeconds,
    required this.compareByCategory,
    required this.athletes,
    required this.points,
    this.timePenaltyEnabled = false,
    this.penaltySecondsPerMiss = 0,
    this.clockCalibration,
    this.status = CompetitionStatus.draft,
    this.schemaVersion = 3,
  });

  String name;
  DateTime firstStart;
  int intervalSeconds;
  bool compareByCategory;
  List<Athlete> athletes;
  List<SplitPoint> points;
  bool timePenaltyEnabled;
  int penaltySecondsPerMiss;
  CompetitionClockCalibration? clockCalibration;
  CompetitionStatus status;
  int schemaVersion;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'name': name,
        'firstStart': firstStart.toIso8601String(),
        'intervalSeconds': intervalSeconds,
        'compareByCategory': compareByCategory,
        'athletes': athletes.map((a) => a.toJson()).toList(),
        'points': points.map((p) => p.toJson()).toList(),
        'timePenaltyEnabled': timePenaltyEnabled,
        'penaltySecondsPerMiss': penaltySecondsPerMiss,
        'clockCalibration': clockCalibration?.toJson(),
        'status': status.name,
      };

  static RaceEvent fromJson(Map<String, dynamic> json) => RaceEvent(
        name: json['name'] as String,
        firstStart: DateTime.parse(json['firstStart'] as String),
        intervalSeconds: (json['intervalSeconds'] as num).toInt(),
        compareByCategory: json['compareByCategory'] as bool,
        athletes: (json['athletes'] as List<dynamic>).map((a) => Athlete.fromJson(a as Map<String, dynamic>)).toList(),
        points: (json['points'] as List<dynamic>).map((p) => SplitPoint.fromJson(p as Map<String, dynamic>)).toList(),
        timePenaltyEnabled: json['timePenaltyEnabled'] as bool? ?? false,
        penaltySecondsPerMiss: (json['penaltySecondsPerMiss'] as num?)?.toInt() ?? 0,
        clockCalibration: json['clockCalibration'] == null
            ? null
            : CompetitionClockCalibration.fromJson(json['clockCalibration'] as Map<String, dynamic>),
        status: CompetitionStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => (json['athletes'] as List<dynamic>? ?? const []).any((a) => (a as Map<String, dynamic>)['status'] != 'waiting')
              ? CompetitionStatus.running
              : CompetitionStatus.draft,
        ),
        schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      );
}

class RankRow {
  RankRow({
    required this.athlete,
    required this.elapsed,
    required this.place,
    required this.deltaToLeader,
    required this.sectionElapsed,
    required this.sectionDelta,
    required this.sectionPlace,
  });

  Athlete athlete;
  Duration elapsed;
  int place;
  Duration deltaToLeader;
  Duration? sectionElapsed;
  Duration? sectionDelta;
  int? sectionPlace;
}

class Candidate {
  Candidate({required this.athlete, required this.predictedTime, required this.quality});
  Athlete athlete;
  DateTime? predictedTime;
  String quality;
}
