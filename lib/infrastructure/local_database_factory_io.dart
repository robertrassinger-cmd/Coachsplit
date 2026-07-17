import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openCoachSplitDatabase() async {
  final directory = await getApplicationDocumentsDirectory();
  return databaseFactoryIo.openDatabase(
    p.join(directory.path, 'coachsplit_timing_v2.db'),
  );
}
