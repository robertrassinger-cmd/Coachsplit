import 'domain_enums.dart';

class RoutePointDefinition {
  const RoutePointDefinition({
    required this.id,
    required this.type,
    required this.order,
    required this.label,
    this.trainerNote,
    this.distanceFromStartMeters,
    this.shootingRangeId,
    this.shootingRangeNumber,
  })  : assert(id != ''),
        assert(order >= 0),
        assert(distanceFromStartMeters == null || distanceFromStartMeters >= 0);

  final String id;
  final RoutePointType type;
  final int order;
  final String label;
  final String? trainerNote;
  final int? distanceFromStartMeters;
  final String? shootingRangeId;
  final int? shootingRangeNumber;

  bool get isMandatory =>
      type == RoutePointType.start || type == RoutePointType.finish;

  bool get requiresShootingData => type == RoutePointType.shootingExit;

  RoutePointDefinition copyWith({
    String? label,
    String? trainerNote,
    int? order,
    int? distanceFromStartMeters,
  }) {
    return RoutePointDefinition(
      id: id,
      type: type,
      order: order ?? this.order,
      label: label ?? this.label,
      trainerNote: trainerNote ?? this.trainerNote,
      distanceFromStartMeters:
          distanceFromStartMeters ?? this.distanceFromStartMeters,
      shootingRangeId: shootingRangeId,
      shootingRangeNumber: shootingRangeNumber,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.name,
        'order': order,
        'label': label,
        'trainerNote': trainerNote,
        'distanceFromStartMeters': distanceFromStartMeters,
        'shootingRangeId': shootingRangeId,
        'shootingRangeNumber': shootingRangeNumber,
      };

  factory RoutePointDefinition.fromJson(Map<String, Object?> json) {
    return RoutePointDefinition(
      id: json['id']! as String,
      type: RoutePointType.values.byName(json['type']! as String),
      order: (json['order']! as num).toInt(),
      label: json['label']! as String,
      trainerNote: json['trainerNote'] as String?,
      distanceFromStartMeters:
          (json['distanceFromStartMeters'] as num?)?.toInt(),
      shootingRangeId: json['shootingRangeId'] as String?,
      shootingRangeNumber:
          (json['shootingRangeNumber'] as num?)?.toInt(),
    );
  }
}

class RouteDefinition {
  RouteDefinition({
    required this.id,
    required this.version,
    required this.name,
    required this.type,
    required List<RoutePointDefinition> points,
    this.distanceMeters,
    this.lapCount,
    this.description,
    this.location,
    this.elevationMeters,
    this.surface,
    this.isActive = true,
  })  : assert(id != ''),
        assert(version > 0),
        assert(distanceMeters == null || distanceMeters > 0),
        assert(lapCount == null || lapCount > 0),
        points = List.unmodifiable(
          [...points]..sort((a, b) => a.order.compareTo(b.order)),
        ) {
    _validateStructure(this.points);
  }

  final String id;
  final int version;
  final String name;
  final RouteType type;
  final List<RoutePointDefinition> points;

  // Bewusst optional: Diese Werte können später am Desktop ergänzt werden.
  final int? distanceMeters;
  final int? lapCount;
  final String? description;
  final String? location;
  final int? elevationMeters;
  final String? surface;
  final bool isActive;

  RoutePointDefinition get start =>
      points.firstWhere((point) => point.type == RoutePointType.start);

  RoutePointDefinition get finish =>
      points.firstWhere((point) => point.type == RoutePointType.finish);

  RouteDefinition addPointBeforeFinish(RoutePointDefinition point) {
    if (point.isMandatory) {
      throw ArgumentError('Start und Ziel werden nicht manuell hinzugefügt.');
    }
    final next = [...points];
    final finishIndex =
        next.indexWhere((item) => item.type == RoutePointType.finish);
    next.insert(finishIndex, point);
    final reordered = [
      for (var index = 0; index < next.length; index++)
        next[index].copyWith(order: index),
    ];
    return copyWith(points: reordered);
  }

  RouteDefinition copyWith({
    int? version,
    String? name,
    RouteType? type,
    List<RoutePointDefinition>? points,
    int? distanceMeters,
    int? lapCount,
    String? description,
    String? location,
    int? elevationMeters,
    String? surface,
    bool? isActive,
  }) {
    return RouteDefinition(
      id: id,
      version: version ?? this.version,
      name: name ?? this.name,
      type: type ?? this.type,
      points: points ?? this.points,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      lapCount: lapCount ?? this.lapCount,
      description: description ?? this.description,
      location: location ?? this.location,
      elevationMeters: elevationMeters ?? this.elevationMeters,
      surface: surface ?? this.surface,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'version': version,
        'name': name,
        'type': type.name,
        'points': points.map((point) => point.toJson()).toList(),
        'distanceMeters': distanceMeters,
        'lapCount': lapCount,
        'description': description,
        'location': location,
        'elevationMeters': elevationMeters,
        'surface': surface,
        'isActive': isActive,
      };

  factory RouteDefinition.fromJson(Map<String, Object?> json) {
    return RouteDefinition(
      id: json['id']! as String,
      version: (json['version']! as num).toInt(),
      name: json['name']! as String,
      type: RouteType.values.byName(json['type']! as String),
      points: (json['points']! as List<Object?>)
          .map((item) =>
              RoutePointDefinition.fromJson(item! as Map<String, Object?>))
          .toList(),
      distanceMeters: (json['distanceMeters'] as num?)?.toInt(),
      lapCount: (json['lapCount'] as num?)?.toInt(),
      description: json['description'] as String?,
      location: json['location'] as String?,
      elevationMeters: (json['elevationMeters'] as num?)?.toInt(),
      surface: json['surface'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  static void _validateStructure(List<RoutePointDefinition> points) {
    if (points.isEmpty ||
        points.first.type != RoutePointType.start ||
        points.last.type != RoutePointType.finish) {
      throw ArgumentError('Eine Strecke muss mit Start beginnen und mit Ziel enden.');
    }
    if (points.where((point) => point.type == RoutePointType.start).length != 1 ||
        points.where((point) => point.type == RoutePointType.finish).length != 1) {
      throw ArgumentError('Eine Strecke benötigt genau einen Start und ein Ziel.');
    }
    final ids = points.map((point) => point.id).toSet();
    if (ids.length != points.length) {
      throw ArgumentError('Messpunkt-IDs müssen innerhalb einer Strecke eindeutig sein.');
    }
  }
}

class RouteReference {
  const RouteReference({required this.routeId, required this.routeVersion})
      : assert(routeId != ''),
        assert(routeVersion > 0);

  final String routeId;
  final int routeVersion;

  Map<String, Object?> toJson() => {
        'routeId': routeId,
        'routeVersion': routeVersion,
      };

  factory RouteReference.fromJson(Map<String, Object?> json) => RouteReference(
        routeId: json['routeId']! as String,
        routeVersion: (json['routeVersion']! as num).toInt(),
      );
}
