import 'domain_enums.dart';

class ShootingData {
  const ShootingData({required this.position, required this.misses})
      : assert(misses >= 0 && misses <= 5);

  final ShootingPositionV2 position;
  final int misses;

  Map<String, Object?> toJson() => {
        'position': position.name,
        'misses': misses,
      };

  factory ShootingData.fromJson(Map<String, Object?> json) => ShootingData(
        position: ShootingPositionV2.values.byName(json['position']! as String),
        misses: (json['misses']! as num).toInt(),
      );
}

/// Unveränderliche fachliche Rohmessung.
///
/// Nur die Transport-Metadaten [syncState], [syncAttempts], [lastSyncError]
/// und [lastSyncAttemptAt] dürfen im Repository aktualisiert werden. Der
/// fachliche Inhalt bleibt unverändert; Korrekturen erzeugen ein neues Event.
class TimingEvent {
  const TimingEvent({
    required this.id,
    required this.sessionId,
    required this.participationId,
    required this.athleteId,
    required this.measurementPointId,
    required this.kind,
    required this.activityTimeMs,
    required this.deviceTime,
    required this.createdByUserId,
    required this.deviceId,
    this.serverReceivedAt,
    this.shootingData,
    this.correctionOfEventId,
    this.syncState = SyncState.localOnly,
    this.syncVersion = 1,
    this.syncAttempts = 0,
    this.lastSyncError,
    this.lastSyncAttemptAt,
    this.schemaVersion = 2,
  })  : assert(id != ''),
        assert(sessionId != ''),
        assert(participationId != ''),
        assert(athleteId != ''),
        assert(measurementPointId != ''),
        assert(activityTimeMs >= 0),
        assert(createdByUserId != ''),
        assert(deviceId != ''),
        assert(syncVersion > 0),
        assert(syncAttempts >= 0),
        assert(schemaVersion > 0),
        assert(
          kind == TimingEventKind.shootingExit || shootingData == null,
          'Schießdaten sind nur bei Schießstand aus zulässig.',
        ),
        assert(
          kind != TimingEventKind.shootingExit || shootingData != null,
          'Schießstand aus benötigt L/S und Fehlerzahl.',
        );

  final String id;
  final String sessionId;
  final String participationId;
  final String athleteId;
  final String measurementPointId;
  final TimingEventKind kind;
  final int activityTimeMs;
  final DateTime deviceTime;
  final DateTime? serverReceivedAt;
  final String createdByUserId;
  final String deviceId;
  final ShootingData? shootingData;
  final String? correctionOfEventId;
  final SyncState syncState;
  final int syncVersion;
  final int syncAttempts;
  final String? lastSyncError;
  final DateTime? lastSyncAttemptAt;
  final int schemaVersion;

  TimingEvent copyWith({
    DateTime? serverReceivedAt,
    SyncState? syncState,
    int? syncVersion,
    int? syncAttempts,
    String? lastSyncError,
    bool clearLastSyncError = false,
    DateTime? lastSyncAttemptAt,
  }) =>
      TimingEvent(
        id: id,
        sessionId: sessionId,
        participationId: participationId,
        athleteId: athleteId,
        measurementPointId: measurementPointId,
        kind: kind,
        activityTimeMs: activityTimeMs,
        deviceTime: deviceTime,
        serverReceivedAt: serverReceivedAt ?? this.serverReceivedAt,
        createdByUserId: createdByUserId,
        deviceId: deviceId,
        shootingData: shootingData,
        correctionOfEventId: correctionOfEventId,
        syncState: syncState ?? this.syncState,
        syncVersion: syncVersion ?? this.syncVersion,
        syncAttempts: syncAttempts ?? this.syncAttempts,
        lastSyncError:
            clearLastSyncError ? null : lastSyncError ?? this.lastSyncError,
        lastSyncAttemptAt: lastSyncAttemptAt ?? this.lastSyncAttemptAt,
        schemaVersion: schemaVersion,
      );

  /// Fachlicher Inhalt ohne lokale Transport-Metadaten.
  Map<String, Object?> canonicalPayload() => {
        'id': id,
        'sessionId': sessionId,
        'participationId': participationId,
        'athleteId': athleteId,
        'measurementPointId': measurementPointId,
        'kind': kind.name,
        'activityTimeMs': activityTimeMs,
        'deviceTime': deviceTime.toIso8601String(),
        'createdByUserId': createdByUserId,
        'deviceId': deviceId,
        'shootingData': shootingData?.toJson(),
        'correctionOfEventId': correctionOfEventId,
        'syncVersion': syncVersion,
      };

  Map<String, Object?> toJson() => {
        ...canonicalPayload(),
        'serverReceivedAt': serverReceivedAt?.toIso8601String(),
        'syncState': syncState.name,
        'syncAttempts': syncAttempts,
        'lastSyncError': lastSyncError,
        'lastSyncAttemptAt': lastSyncAttemptAt?.toIso8601String(),
        'schemaVersion': schemaVersion,
      };

  factory TimingEvent.fromJson(Map<String, Object?> json) => TimingEvent(
        id: json['id']! as String,
        sessionId: json['sessionId']! as String,
        participationId: json['participationId']! as String,
        athleteId: json['athleteId']! as String,
        measurementPointId: json['measurementPointId']! as String,
        kind: TimingEventKind.values.byName(json['kind']! as String),
        activityTimeMs: (json['activityTimeMs']! as num).toInt(),
        deviceTime: DateTime.parse(json['deviceTime']! as String),
        serverReceivedAt: json['serverReceivedAt'] == null
            ? null
            : DateTime.parse(json['serverReceivedAt']! as String),
        createdByUserId: json['createdByUserId']! as String,
        deviceId: json['deviceId']! as String,
        shootingData: json['shootingData'] == null
            ? null
            : ShootingData.fromJson(
                Map<String, Object?>.from(json['shootingData']! as Map),
              ),
        correctionOfEventId: json['correctionOfEventId'] as String?,
        syncState: SyncState.values.byName(
          json['syncState'] as String? ?? SyncState.localOnly.name,
        ),
        syncVersion: (json['syncVersion'] as num?)?.toInt() ?? 1,
        syncAttempts: (json['syncAttempts'] as num?)?.toInt() ?? 0,
        lastSyncError: json['lastSyncError'] as String?,
        lastSyncAttemptAt: json['lastSyncAttemptAt'] == null
            ? null
            : DateTime.parse(json['lastSyncAttemptAt']! as String),
        schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      );
}
