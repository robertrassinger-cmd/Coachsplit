enum PointType { split, finish }
enum AthleteStatus { waiting, running, finished }

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
  }) : captures = captures ?? {};

  int bib;
  String name;
  String category;
  bool isOwn;
  DateTime scheduledStart;
  DateTime? actualStart;
  AthleteStatus status;
  Map<String, DateTime> captures;

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
      };

  static Athlete fromJson(Map<String, dynamic> json) => Athlete(
        bib: json['bib'] as int,
        name: json['name'] as String,
        category: json['category'] as String,
        isOwn: json['isOwn'] as bool,
        scheduledStart: DateTime.parse(json['scheduledStart'] as String),
        actualStart: json['actualStart'] == null ? null : DateTime.parse(json['actualStart'] as String),
        status: AthleteStatus.values.firstWhere((s) => s.name == json['status'], orElse: () => AthleteStatus.waiting),
        captures: (json['captures'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, DateTime.parse(v as String))),
      );
}

class SplitPoint {
  SplitPoint({required this.id, required this.name, required this.type});

  String id;
  String name;
  PointType type;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type.name};

  static SplitPoint fromJson(Map<String, dynamic> json) => SplitPoint(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] == 'finish' ? PointType.finish : PointType.split,
      );
}

class RaceEvent {
  RaceEvent({
    required this.name,
    required this.firstStart,
    required this.intervalSeconds,
    required this.compareByCategory,
    required this.athletes,
    required this.points,
  });

  String name;
  DateTime firstStart;
  int intervalSeconds;
  bool compareByCategory;
  List<Athlete> athletes;
  List<SplitPoint> points;

  Map<String, dynamic> toJson() => {
        'name': name,
        'firstStart': firstStart.toIso8601String(),
        'intervalSeconds': intervalSeconds,
        'compareByCategory': compareByCategory,
        'athletes': athletes.map((a) => a.toJson()).toList(),
        'points': points.map((p) => p.toJson()).toList(),
      };

  static RaceEvent fromJson(Map<String, dynamic> json) => RaceEvent(
        name: json['name'] as String,
        firstStart: DateTime.parse(json['firstStart'] as String),
        intervalSeconds: json['intervalSeconds'] as int,
        compareByCategory: json['compareByCategory'] as bool,
        athletes: (json['athletes'] as List<dynamic>).map((a) => Athlete.fromJson(a as Map<String, dynamic>)).toList(),
        points: (json['points'] as List<dynamic>).map((p) => SplitPoint.fromJson(p as Map<String, dynamic>)).toList(),
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

