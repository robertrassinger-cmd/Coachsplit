import 'package:flutter_test/flutter_test.dart';
import 'package:coachsplit/domain/v2/domain_models.dart';

void main() {
  group('RouteDefinition', () {
    final start = RoutePointDefinition(
      id: 'start',
      type: RoutePointType.start,
      order: 0,
      label: 'Start',
    );
    final finish = RoutePointDefinition(
      id: 'finish',
      type: RoutePointType.finish,
      order: 1,
      label: 'Ziel',
    );

    test('requires exactly one start and finish', () {
      expect(
        () => RouteDefinition(
          id: 'route',
          version: 1,
          name: 'Test',
          type: RouteType.trainingCourse,
          points: [finish],
        ),
        throwsArgumentError,
      );
    });

    test('adds a point directly before finish', () {
      final route = RouteDefinition(
        id: 'route',
        version: 1,
        name: 'Test',
        type: RouteType.trainingCourse,
        points: [start, finish],
      );
      final updated = route.addPointBeforeFinish(
        const RoutePointDefinition(
          id: 'split-1',
          type: RoutePointType.split,
          order: 1,
          label: 'Zwischenzeit',
        ),
      );

      expect(updated.points.map((point) => point.id),
          ['start', 'split-1', 'finish']);
    });
  });

  group('TimingEvent', () {
    test('shooting exit requires shooting data', () {
      expect(
        () => TimingEvent(
          id: 'e1',
          sessionId: 's1',
          participationId: 'p1',
          athleteId: 'a1',
          measurementPointId: 'shooting-out',
          kind: TimingEventKind.shootingExit,
          activityTimeMs: 1000,
          deviceTime: DateTime(2026),
          createdByUserId: 'u1',
          deviceId: 'd1',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('supports 0 to 5 misses', () {
      for (var misses = 0; misses <= 5; misses++) {
        final event = TimingEvent(
          id: 'e$misses',
          sessionId: 's1',
          participationId: 'p1',
          athleteId: 'a1',
          measurementPointId: 'shooting-out',
          kind: TimingEventKind.shootingExit,
          activityTimeMs: 1000,
          deviceTime: DateTime(2026),
          createdByUserId: 'u1',
          deviceId: 'd1',
          shootingData: ShootingData(
            position: ShootingPositionV2.prone,
            misses: misses,
          ),
        );
        expect(event.shootingData!.misses, misses);
      }
    });
  });
}
