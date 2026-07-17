import '../../domain/v2/archive.dart';
import '../../domain/v2/domain_enums.dart';

abstract interface class ArchiveRepository {
  Future<void> archive(SessionArchiveSnapshot snapshot);
  Future<List<SessionArchiveSnapshot>> list({ActivityType? type});
}
