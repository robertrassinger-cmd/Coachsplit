import 'package:flutter_test/flutter_test.dart';
import 'package:coachsplit/services/competition_clock.dart';

void main() {
  test('calibrated clock applies the official-time offset', () {
    final clock = CompetitionClock();
    final deviceReference = DateTime(2026, 7, 16, 17, 0, 0);
    final officialReference = DateTime(2026, 7, 16, 10, 0, 0);

    clock.calibrate(
      officialTime: officialReference,
      capturedDeviceTime: deviceReference,
    );

    expect(clock.calibration, isNotNull);
    expect(clock.calibration!.offsetMilliseconds,
        officialReference.difference(deviceReference).inMilliseconds);
  });
}
