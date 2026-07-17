import '../domain/v2/domain_enums.dart';
import '../domain/v2/timing_event.dart';
import '../repositories/v2/timing_event_repository.dart';
import 'capture_timing_event_service.dart';

/// UI-neutrale Anwendungsgrenze für Messpunkt- und Admin-Oberflächen.
class TimingService {
  TimingService({
    required TimingEventRepository repository,
    required CaptureTimingEventService captureService,
  })  : _repository = repository,
        _captureService = captureService;

  final TimingEventRepository _repository;
  final CaptureTimingEventService _captureService;

  Stream<List<TimingEvent>> watchSession(String sessionId) =>
      _repository.watchForSession(sessionId);

  Future<TimingEvent> capture({
    required String sessionId,
    required String participationId,
    required String athleteId,
    required String measurementPointId,
    required TimingEventKind kind,
    required DateTime athleteStart,
    required DateTime capturedAt,
    ShootingData? shootingData,
  }) =>
      _captureService.capture(
        sessionId: sessionId,
        participationId: participationId,
        athleteId: athleteId,
        measurementPointId: measurementPointId,
        kind: kind,
        athleteStart: athleteStart,
        capturedAt: capturedAt,
        shootingData: shootingData,
      );

  Future<TimingEvent> cancel(TimingEvent event, DateTime cancelledAt) =>
      _captureService.cancel(event, cancelledAt);
}
