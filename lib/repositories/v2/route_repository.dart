import '../../domain/v2/route.dart';

abstract interface class RouteRepository {
  Future<RouteDefinition?> findById(String routeId, int version);
  Future<List<RouteDefinition>> listActive();
  Future<void> save(RouteDefinition route);
}
