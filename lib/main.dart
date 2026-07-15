
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

import 'web_download_stub.dart' if (dart.library.html) 'web_download_web.dart';
import 'services/competition_clock.dart';

part 'app/coachsplit_app.dart';
part 'domain/models.dart';
part 'presentation/coachsplit_home.dart';
part 'presentation/widgets.dart';

void main() => runApp(const CoachSplitApp());
