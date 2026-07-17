enum MultiuserRole { administrator, helper }

enum CollaborationSessionStatus { openForJoining, active, closed }

class MultiuserConnection {
  const MultiuserConnection({
    required this.serverUrl,
    required this.sessionId,
    required this.accessToken,
    required this.role,
    required this.deviceId,
    this.deviceName,
    this.checkpointId,
    this.checkpointName,
    this.assignmentRevision = 0,
  });

  final String serverUrl;
  final String sessionId;
  final String accessToken;
  final MultiuserRole role;
  final String deviceId;
  final String? deviceName;
  final String? checkpointId;
  final String? checkpointName;
  final int assignmentRevision;

  bool get isAdministrator => role == MultiuserRole.administrator;
  bool get isAssigned => checkpointId != null && checkpointId!.isNotEmpty;

  MultiuserConnection copyWith({
    String? checkpointId,
    String? checkpointName,
    int? assignmentRevision,
    bool clearAssignment = false,
  }) =>
      MultiuserConnection(
        serverUrl: serverUrl,
        sessionId: sessionId,
        accessToken: accessToken,
        role: role,
        deviceId: deviceId,
        deviceName: deviceName,
        checkpointId: clearAssignment ? null : checkpointId ?? this.checkpointId,
        checkpointName: clearAssignment ? null : checkpointName ?? this.checkpointName,
        assignmentRevision: assignmentRevision ?? this.assignmentRevision,
      );

  Map<String, Object?> toJson() => {
        'serverUrl': serverUrl,
        'sessionId': sessionId,
        'accessToken': accessToken,
        'role': role.name,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'checkpointId': checkpointId,
        'checkpointName': checkpointName,
        'assignmentRevision': assignmentRevision,
      };

  factory MultiuserConnection.fromJson(Map<String, Object?> json) =>
      MultiuserConnection(
        serverUrl: json['serverUrl']! as String,
        sessionId: json['sessionId']! as String,
        accessToken: json['accessToken']! as String,
        role: MultiuserRole.values.byName(json['role']! as String),
        deviceId: (json['deviceId'] as String?) ?? '',
        deviceName: json['deviceName'] as String?,
        checkpointId: json['checkpointId'] as String?,
        checkpointName: json['checkpointName'] as String?,
        assignmentRevision: (json['assignmentRevision'] as num?)?.toInt() ?? 0,
      );
}

class ConnectedHelperDevice {
  const ConnectedHelperDevice({
    required this.deviceId,
    required this.displayName,
    required this.lastSeenAt,
    required this.online,
    required this.pendingEventCount,
    this.checkpointId,
    this.checkpointName,
    this.assignmentRevision = 0,
  });

  final String deviceId;
  final String displayName;
  final DateTime lastSeenAt;
  final bool online;
  final int pendingEventCount;
  final String? checkpointId;
  final String? checkpointName;
  final int assignmentRevision;

  factory ConnectedHelperDevice.fromJson(Map<String, Object?> json) =>
      ConnectedHelperDevice(
        deviceId: json['deviceId']! as String,
        displayName: (json['displayName'] as String?) ?? 'Helfergerät',
        lastSeenAt: DateTime.tryParse((json['lastSeenAt'] as String?) ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        online: json['online'] == true,
        pendingEventCount: (json['pendingEventCount'] as num?)?.toInt() ?? 0,
        checkpointId: json['checkpointId'] as String?,
        checkpointName: json['checkpointName'] as String?,
        assignmentRevision: (json['assignmentRevision'] as num?)?.toInt() ?? 0,
      );
}

class CreatedMultiuserSession {
  const CreatedMultiuserSession({
    required this.connection,
    required this.joinToken,
    required this.joinUrl,
  });
  final MultiuserConnection connection;
  final String joinToken;
  final String joinUrl;
}

class JoinedMultiuserSession {
  const JoinedMultiuserSession({
    required this.connection,
    required this.competition,
  });
  final MultiuserConnection connection;
  final Map<String, Object?> competition;
}

class CollaborationState {
  const CollaborationState({
    required this.status,
    required this.revision,
    required this.devices,
  });
  final CollaborationSessionStatus status;
  final int revision;
  final List<ConnectedHelperDevice> devices;
}
