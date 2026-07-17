import '../../domain/v2/session.dart';

abstract interface class SessionRepository {
  Future<ActivitySession?> findById(String sessionId);
  Stream<ActivitySession?> watch(String sessionId);
  Future<void> save(ActivitySession session);
}
