class CompetitionClockCalibration {
  const CompetitionClockCalibration({
    required this.deviceReferenceTime,
    required this.officialReferenceTime,
    required this.offsetMilliseconds,
  });

  final DateTime deviceReferenceTime;
  final DateTime officialReferenceTime;
  final int offsetMilliseconds;

  String get officialReferenceLabel {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(officialReferenceTime.hour)}:${two(officialReferenceTime.minute)}:${two(officialReferenceTime.second)}';
  }

  Map<String, dynamic> toJson() => {
        'deviceReferenceTime': deviceReferenceTime.toIso8601String(),
        'officialReferenceTime': officialReferenceTime.toIso8601String(),
        'offsetMilliseconds': offsetMilliseconds,
      };

  static CompetitionClockCalibration fromJson(Map<String, dynamic> json) => CompetitionClockCalibration(
        deviceReferenceTime: DateTime.parse(json['deviceReferenceTime'] as String),
        officialReferenceTime: DateTime.parse(json['officialReferenceTime'] as String),
        offsetMilliseconds: (json['offsetMilliseconds'] as num).toInt(),
      );
}

/// Gemeinsame fachliche Zeitquelle der Anwendung.
/// Ohne Kalibrierung entspricht sie der lokalen Administratorzeit.
/// Eine spätere Cloud-Implementierung kann den Offset serverseitig bestätigen,
/// ohne dass UI oder Messlogik geändert werden müssen.
class CompetitionClock {
  CompetitionClockCalibration? _calibration;

  CompetitionClockCalibration? get calibration => _calibration;
  bool get isCalibrated => _calibration != null;

  void calibrate({required DateTime officialTime, DateTime? capturedDeviceTime}) {
    final deviceTime = capturedDeviceTime ?? DateTime.now();
    _calibration = CompetitionClockCalibration(
      deviceReferenceTime: deviceTime,
      officialReferenceTime: officialTime,
      offsetMilliseconds: officialTime.difference(deviceTime).inMilliseconds,
    );
  }

  void restore(CompetitionClockCalibration? calibration) => _calibration = calibration;
  void clear() => _calibration = null;

  DateTime nowDateTime() {
    final now = DateTime.now();
    return now.add(Duration(milliseconds: _calibration?.offsetMilliseconds ?? 0));
  }

  String formatNow() {
    final value = nowDateTime();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }
}
