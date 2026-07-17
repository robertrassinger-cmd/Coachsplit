library coachsplit;


import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:sembast/sembast.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

import 'domain/v2/domain_enums.dart';
import 'domain/v2/timing_event.dart';
import 'repositories/v2/timing_event_repository.dart';
import 'repositories/v2/sembast_timing_event_repository.dart';
import 'infrastructure/local_database_factory.dart';
import 'services/capture_timing_event_service.dart';
import 'services/sync/sync_engine.dart';
import 'services/sync/firestore_sync_transport.dart';
import 'services/multiuser_api_client.dart';
import 'services/firebase_bootstrap.dart';
import 'domain/multiuser_models.dart';

import 'web_download_stub.dart' if (dart.library.html) 'web_download_web.dart';
import 'services/competition_clock.dart';


part 'app/coach_split_app.dart';
part 'domain/models.dart';
part 'features/competition/coach_split_home.dart';
part 'repositories/local_competition_repository.dart';
part 'ui/widgets.dart';
part 'services/penalty_service.dart';
part 'services/ranking_service.dart';
part 'services/shooting_range_number_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
  runApp(const CoachSplitApp());
}
