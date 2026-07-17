import 'package:flutter_test/flutter_test.dart';
import 'package:coachsplit/main.dart';

void main() {
  test('shooting position survives SplitPoint JSON roundtrip', () {
    final point = SplitPoint(
      id: 'shoot_1_out',
      name: 'Schießstand 1 aus',
      type: PointType.shootingExit,
      shootingRangeNumber: 1,
      shootingPosition: ShootingPosition.standing,
    );

    final restored = SplitPoint.fromJson(point.toJson());
    expect(restored.shootingPosition, ShootingPosition.standing);
  });
}
