import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';

Future<Database> openCoachSplitDatabase() {
  return databaseFactoryWeb.openDatabase('coachsplit_timing_v2');
}
