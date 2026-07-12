
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

void main() => runApp(const CoachSplitApp());

class CoachSplitApp extends StatelessWidget {
  const CoachSplitApp({super.key});


  String _formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CoachSplit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1118),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF67C7FF),
          brightness: Brightness.dark,
        ),
      ),
      home: const CoachSplitHome(),
    );
  }
}

enum PointType { split, finish }
enum AthleteStatus { waiting, running, finished }

class Athlete {
  Athlete({
    required this.bib,
    required this.name,
    required this.category,
    required this.isOwn,
    required this.scheduledStart,
    this.actualStart,
    this.status = AthleteStatus.waiting,
    Map<String, DateTime>? captures,
  }) : captures = captures ?? {};

  int bib;
  String name;
  String category;
  bool isOwn;
  DateTime scheduledStart;
  DateTime? actualStart;
  AthleteStatus status;
  Map<String, DateTime> captures;

  DateTime get startTime => actualStart ?? scheduledStart;

  Map<String, dynamic> toJson() => {
        'bib': bib,
        'name': name,
        'category': category,
        'isOwn': isOwn,
        'scheduledStart': scheduledStart.toIso8601String(),
        'actualStart': actualStart?.toIso8601String(),
        'status': status.name,
        'captures': captures.map((k, v) => MapEntry(k, v.toIso8601String())),
      };

  static Athlete fromJson(Map<String, dynamic> json) => Athlete(
        bib: json['bib'] as int,
        name: json['name'] as String,
        category: json['category'] as String,
        isOwn: json['isOwn'] as bool,
        scheduledStart: DateTime.parse(json['scheduledStart'] as String),
        actualStart: json['actualStart'] == null ? null : DateTime.parse(json['actualStart'] as String),
        status: AthleteStatus.values.firstWhere((s) => s.name == json['status'], orElse: () => AthleteStatus.waiting),
        captures: (json['captures'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, DateTime.parse(v as String))),
      );
}

class SplitPoint {
  SplitPoint({required this.id, required this.name, required this.type});

  String id;
  String name;
  PointType type;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type.name};

  static SplitPoint fromJson(Map<String, dynamic> json) => SplitPoint(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] == 'finish' ? PointType.finish : PointType.split,
      );
}

class RaceEvent {
  RaceEvent({
    required this.name,
    required this.firstStart,
    required this.intervalSeconds,
    required this.compareByCategory,
    required this.athletes,
    required this.points,
  });

  String name;
  DateTime firstStart;
  int intervalSeconds;
  bool compareByCategory;
  List<Athlete> athletes;
  List<SplitPoint> points;

  Map<String, dynamic> toJson() => {
        'name': name,
        'firstStart': firstStart.toIso8601String(),
        'intervalSeconds': intervalSeconds,
        'compareByCategory': compareByCategory,
        'athletes': athletes.map((a) => a.toJson()).toList(),
        'points': points.map((p) => p.toJson()).toList(),
      };

  static RaceEvent fromJson(Map<String, dynamic> json) => RaceEvent(
        name: json['name'] as String,
        firstStart: DateTime.parse(json['firstStart'] as String),
        intervalSeconds: json['intervalSeconds'] as int,
        compareByCategory: json['compareByCategory'] as bool,
        athletes: (json['athletes'] as List<dynamic>).map((a) => Athlete.fromJson(a as Map<String, dynamic>)).toList(),
        points: (json['points'] as List<dynamic>).map((p) => SplitPoint.fromJson(p as Map<String, dynamic>)).toList(),
      );
}

class RankRow {
  RankRow({
    required this.athlete,
    required this.elapsed,
    required this.place,
    required this.deltaToLeader,
    required this.sectionElapsed,
    required this.sectionDelta,
    required this.sectionPlace,
  });

  Athlete athlete;
  Duration elapsed;
  int place;
  Duration deltaToLeader;
  Duration? sectionElapsed;
  Duration? sectionDelta;
  int? sectionPlace;
}

class Candidate {
  Candidate({required this.athlete, required this.predictedTime, required this.quality});
  Athlete athlete;
  DateTime? predictedTime;
  String quality;
}

class CoachSplitHome extends StatefulWidget {
  const CoachSplitHome({super.key});

  @override
  State<CoachSplitHome> createState() => _CoachSplitHomeState();
}

class _CoachSplitHomeState extends State<CoachSplitHome> {
  static const _eventsKey = 'coachsplit_v03_events';
  static const _archiveKey = 'coachsplit_v03_archive';
  static const _groupsKey = 'coachsplit_v03_groups';

  final _eventName = TextEditingController(text: 'Trainingsrennen Demo');
  final _athletesText = TextEditingController(text: _defaultAthletes);
  final _pointsText = TextEditingController(text: 'Messpunkt 1, split\nMesspunkt 2, split\nZiel, ziel');
  final _groupsText = TextEditingController(text: _defaultGroups);

  final Map<String, RaceEvent> _savedEvents = {};
  final Map<String, RaceEvent> _archivedEvents = {};
  String? _currentEventKey;
  bool _setupReady = false;
  bool _viewingArchivedEvent = false;
  Timer? _setupAutosaveTimer;
  RaceEvent? _event;

  int _page = 0;
  int _intervalSeconds = 30;
  bool _compareByCategory = false;
  bool _autoStartEnabled = false;
  TimeOfDay _firstStartTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(minutes: 2)));

  Timer? _timer;

  static const _defaultAthletes =
      '1, Anna Berger, U12w, *\n'
      '2, Marie Steiner, U14w, *\n'
      '3, Lena Hofer, U12w, *\n'
      '4, Emma Gruber, U12w, *\n'
      '5, Laura Fink, U10w, *\n'
      '6, Sophie Auer, U12w, *\n'
      '7, Leon Huber, U12m, *\n'
      '8, Jonas Leitner, U14m, *\n'
      '9, Elias Moser, U12m, *\n'
      '10, Paul Winkler, U10m, *\n'
      '11, Jakob Brandner, U8m\n'
      '12, Tobias Reiter, U8m\n'
      '13, Simon Fischer, U8m';

  static const _defaultGroups =
      '[TG 1]\n'
      '1, Anna Berger, U12w, *\n'
      '2, Marie Steiner, U14w, *\n'
      '3, Lena Hofer, U12w, *\n'
      '4, Emma Gruber, U12w, *\n'
      '5, Laura Fink, U10w, *\n'
      '6, Sophie Auer, U12w, *\n'
      '7, Leon Huber, U12m, *\n'
      '8, Jonas Leitner, U14m, *\n'
      '9, Elias Moser, U12m, *\n'
      '10, Paul Winkler, U10m, *\n\n'
      '[TG 2]\n'
      '11, Jakob Brandner, U8m\n'
      '12, Tobias Reiter, U8m\n'
      '13, Simon Fischer, U8m';

  @override
  void initState() {
    super.initState();
    _loadStorage();
    _createEventFromSetup(silent: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _autoStart();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _setupAutosaveTimer?.cancel();
    _eventName.dispose();
    _athletesText.dispose();
    _pointsText.dispose();
    _groupsText.dispose();
    super.dispose();
  }

  Future<void> _loadStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final rawGroups = prefs.getString(_groupsKey);
    if (rawGroups != null && rawGroups.trim().isNotEmpty) _groupsText.text = rawGroups;

    final rawEvents = prefs.getString(_eventsKey);
    if (rawEvents != null) {
      try {
        final decoded = jsonDecode(rawEvents) as Map<String, dynamic>;
        _savedEvents
          ..clear()
          ..addAll(decoded.map((k, v) => MapEntry(k, RaceEvent.fromJson(v as Map<String, dynamic>))));
      } catch (_) {}
    }

    final rawArchive = prefs.getString(_archiveKey);
    if (rawArchive != null) {
      try {
        final decoded = jsonDecode(rawArchive) as Map<String, dynamic>;
        _archivedEvents
          ..clear()
          ..addAll(decoded.map((k, v) => MapEntry(k, RaceEvent.fromJson(v as Map<String, dynamic>))));
      } catch (_) {}
    }

    if (mounted) setState(() {});
  }

  Future<void> _saveStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_groupsKey, _groupsText.text);
    await prefs.setString(_eventsKey, jsonEncode(_savedEvents.map((k, v) => MapEntry(k, v.toJson()))));
    await prefs.setString(_archiveKey, jsonEncode(_archivedEvents.map((k, v) => MapEntry(k, v.toJson()))));
  }

  DateTime _futureDateForTime(TimeOfDay time, {DateTime? reference}) {
    final now = reference ?? DateTime.now();
    var result = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (result.isBefore(now)) result = result.add(const Duration(days: 1));
    return result;
  }

  DateTime _firstStartDateTime() => _futureDateForTime(_firstStartTime);

  void _createEventFromSetup({bool silent = false}) {
    final firstStart = _firstStartDateTime();
    final athletes = _parseAthletes(_athletesText.text, firstStart);
    final points = _parsePoints(_pointsText.text);

    setState(() {
      _event = RaceEvent(
        name: _eventName.text.trim().isEmpty ? 'Unbenannter Bewerb' : _eventName.text.trim(),
        firstStart: firstStart,
        intervalSeconds: _intervalSeconds,
        compareByCategory: _compareByCategory,
        athletes: athletes,
        points: points,
      );
      if (!silent) _page = 1;
    });

    if (!silent) _show('Bewerb geladen');
  }


  bool _hasRaceData([RaceEvent? event]) {
    final e = event ?? _event;
    if (e == null) return false;
    return e.athletes.any((a) => a.status != AthleteStatus.waiting || a.captures.isNotEmpty);
  }

  void _scheduleSetupAutosave() {
    _setupReady = false;
    _setupAutosaveTimer?.cancel();
    _setupAutosaveTimer = Timer(const Duration(milliseconds: 400), () {
      _saveSetupFromFields();
    });
  }

  Future<void> _saveSetupFromFields() async {
    if (_viewingArchivedEvent) return;
    final current = _event;
    if (_hasRaceData(current)) {
      await _saveEvent();
      return;
    }

    final firstStart = _firstStartDateTime();
    final name = _eventName.text.trim().isEmpty ? 'Unbenannter Bewerb' : _eventName.text.trim();

    final draft = RaceEvent(
      name: name,
      firstStart: firstStart,
      intervalSeconds: _intervalSeconds,
      compareByCategory: _compareByCategory,
      athletes: _parseAthletes(_athletesText.text, firstStart),
      points: _parsePoints(_pointsText.text),
    );

    _event = draft;

    final previousKey = _currentEventKey;
    if (previousKey != null && previousKey != name && _savedEvents.containsKey(previousKey)) {
      _savedEvents.remove(previousKey);
    }

    _savedEvents[name] = RaceEvent.fromJson(draft.toJson());
    _currentEventKey = name;
    await _saveStorage();
  }

  String _nextPointName(List<SplitPoint> points, String prefix) {
    var highest = 0;
    final pattern = RegExp('^${RegExp.escape(prefix)}\\s+(\\d+)\$');
    for (final point in points) {
      final match = pattern.firstMatch(point.name.trim());
      final value = match == null ? null : int.tryParse(match.group(1) ?? '');
      if (value != null && value > highest) highest = value;
    }
    return '$prefix ${highest + 1}';
  }

  String _suggestPointName(List<SplitPoint> points, String type) {
    switch (type) {
      case 'round': return _nextPointName(points, 'Runde');
      case 'shootIn': return _nextPointName(points, 'Schießstand ein');
      case 'shootOut': return _nextPointName(points, 'Schießstand aus');
      default: return _nextPointName(points, 'Messpunkt');
    }
  }

  Future<SplitPoint?> _pointFromTemplateDialog(List<SplitPoint> points) async {
    var type = 'point';
    final controller = TextEditingController(text: _suggestPointName(points, type));
    return showDialog<SplitPoint>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Messpunkt hinzufügen'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(labelText: 'Vorlage'),
              items: const [
                DropdownMenuItem(value: 'point', child: Text('Messpunkt')),
                DropdownMenuItem(value: 'round', child: Text('Runde')),
                DropdownMenuItem(value: 'shootIn', child: Text('Schießstand ein')),
                DropdownMenuItem(value: 'shootOut', child: Text('Schießstand aus')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setDialogState(() {
                  type = value;
                  controller.text = _suggestPointName(points, type);
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Name', helperText: 'Der Vorschlag kann angepasst werden.'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim().isEmpty ? _suggestPointName(points, type) : controller.text.trim();
                Navigator.pop(context, SplitPoint(
                  id: 'p_${DateTime.now().microsecondsSinceEpoch}',
                  name: name,
                  type: PointType.split,
                ));
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addSplitPointFromSetup() async {
    final points = _parsePoints(_pointsText.text);
    final newPoint = await _pointFromTemplateDialog(points);
    if (newPoint == null) return;
    final finishIndex = points.lastIndexWhere((p) => p.type == PointType.finish);
    if (finishIndex >= 0) {
      points.insert(finishIndex, newPoint);
    } else {
      points.add(newPoint);
      points.add(SplitPoint(id: 'p_finish', name: 'Ziel', type: PointType.finish));
    }
    setState(() {
      _pointsText.text = points.map((p) => '${p.name}, ${p.type == PointType.finish ? 'ziel' : 'split'}').join('\n');
      if (_event != null && !_hasRaceData()) _event!.points = points;
    });
    await _saveSetupFromFields();
    _show('Messpunkt hinzugefügt');
  }

  Future<void> _archiveCurrentEvent() async {
    final event = _event;
    if (event == null) return;

    event.name = _eventName.text.trim().isEmpty ? event.name : _eventName.text.trim();
    final copy = RaceEvent.fromJson(event.toJson());

    _archivedEvents[copy.name] = copy;
    _savedEvents.remove(copy.name);
    if (_currentEventKey == copy.name) _currentEventKey = null;

    await _saveStorage();
    setState(() {});
    _show('Bewerb archiviert');
  }

  void _viewArchivedEvent(RaceEvent archived) {
    final copy = RaceEvent.fromJson(archived.toJson());

    setState(() {
      _event = copy;
      _viewingArchivedEvent = true;
      _eventName.text = copy.name;
      _intervalSeconds = copy.intervalSeconds;
      _compareByCategory = copy.compareByCategory;
      _autoStartEnabled = false;
      _setupReady = true;
      _currentEventKey = null;
      _firstStartTime = TimeOfDay.fromDateTime(copy.firstStart);
      _athletesText.text = copy.athletes
          .map((a) => '${a.bib}, ${a.name}, ${a.category}${a.isOwn ? ', *' : ''}, ${_formatClock(a.scheduledStart)}')
          .join('\n');
      _pointsText.text = copy.points
          .map((p) => '${p.name}, ${p.type == PointType.finish ? 'ziel' : 'split'}')
          .join('\n');
      _page = 3;
    });

    _show('Archiv-Bewerb geöffnet');
  }

  Future<void> _deleteArchivedEvent(String name) async {
    final event = _archivedEvents[name];
    if (event == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archiv-Bewerb löschen?'),
        content: Text('"$name" endgültig aus dem Archiv löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Endgültig löschen')),
        ],
      ),
    );

    if (confirmed != true) return;

    _archivedEvents.remove(name);

    if (_viewingArchivedEvent && _event?.name == name) {
      _event = null;
      _viewingArchivedEvent = false;
      _setupReady = false;
      _page = 0;
    }

    await _saveStorage();
    setState(() {});
    _show('Archiv-Bewerb gelöscht');
  }

  void _loadTemplateFromArchived(RaceEvent archived) {
    final now = DateTime.now().add(const Duration(minutes: 2));
    final copy = RaceEvent.fromJson(archived.toJson());

    for (var i = 0; i < copy.athletes.length; i++) {
      copy.athletes[i].status = AthleteStatus.waiting;
      copy.athletes[i].actualStart = null;
      copy.athletes[i].captures.clear();
      copy.athletes[i].scheduledStart = now.add(Duration(seconds: i * copy.intervalSeconds));
    }

    final templateStamp = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';
    copy.name = _uniqueEventName('Neu aus Vorlage $templateStamp');
    copy.firstStart = now;

    setState(() {
      _currentEventKey = null;
      _setupReady = false;
      _viewingArchivedEvent = false;
      _event = copy;
      _viewingArchivedEvent = false;
      _eventName.text = copy.name;
      _intervalSeconds = copy.intervalSeconds;
      _compareByCategory = copy.compareByCategory;
      _autoStartEnabled = false;
      _firstStartTime = TimeOfDay.fromDateTime(copy.firstStart);
      _athletesText.text = copy.athletes
          .map((a) => '${a.bib}, ${a.name}, ${a.category}${a.isOwn ? ', *' : ''}, ${_formatClock(a.scheduledStart)}')
          .join('\n');
      _pointsText.text = copy.points
          .map((p) => '${p.name}, ${p.type == PointType.finish ? 'ziel' : 'split'}')
          .join('\n');
      _page = 0;
    });

    _saveEvent();
  }

  List<Athlete> _parseAthletes(String text, DateTime firstStart) {
    final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty && !e.startsWith('[')).toList();
    final result = <Athlete>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final parts = line.split(RegExp(r'[,;\t]')).map((e) => e.trim()).toList();
      final bib = parts.isNotEmpty ? int.tryParse(parts[0]) ?? i + 1 : i + 1;
      final name = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : 'Athlet $bib';
      final cat = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : 'AK';
      final own = line.contains('*') || line.contains('⭐');
      final autoStart = firstStart.add(Duration(seconds: i * _intervalSeconds));
      String? startText;
      for (final part in parts.skip(3)) {
        if (_parseClock(part) != null) startText = part;
      }
      final scheduledStart = startText == null ? autoStart : _dateWithClock(startText, fallback: autoStart);

      result.add(Athlete(
        bib: bib,
        name: name,
        category: cat,
        isOwn: own,
        scheduledStart: scheduledStart,
      ));
    }
    return result;
  }

  List<SplitPoint> _parsePoints(String text) {
    final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final splits = <SplitPoint>[];
    for (var i = 0; i < lines.length; i++) {
      final parts = lines[i].split(RegExp(r'[,;\t]')).map((e) => e.trim()).toList();
      final rawName = parts.isNotEmpty ? parts[0] : '';
      final typeRaw = parts.length > 1 ? parts[1].toLowerCase() : 'split';
      final isFinish = typeRaw.contains('ziel') || typeRaw.contains('finish') || rawName.toLowerCase() == 'ziel';
      if (!isFinish) {
        splits.add(SplitPoint(
          id: 'p_$i',
          name: rawName.isEmpty ? 'Messpunkt ${splits.length + 1}' : rawName,
          type: PointType.split,
        ));
      }
    }
    return [...splits, SplitPoint(id: 'p_finish', name: 'Ziel', type: PointType.finish)];
  }

  Map<String, String> _parseGroups() {
    final groups = <String, List<String>>{};
    var current = 'Standard';

    for (final raw in _groupsText.text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('[') && line.endsWith(']')) {
        current = line.substring(1, line.length - 1).trim();
        groups.putIfAbsent(current, () => []);
      } else {
        groups.putIfAbsent(current, () => []).add(line);
      }
    }

    return groups.map((k, v) => MapEntry(k, v.join('\n')));
  }

  Future<void> _saveEvent() async {
    if (_viewingArchivedEvent) return;
    final current = _event;
    if (current == null) return;

    final eventName = _eventName.text.trim().isEmpty ? current.name : _eventName.text.trim();

    current.name = eventName;
    current.intervalSeconds = _intervalSeconds;
    current.compareByCategory = _compareByCategory;

    final previousKey = _currentEventKey;
    if (previousKey != null && previousKey != eventName && _savedEvents.containsKey(previousKey)) {
      _savedEvents.remove(previousKey);
    }

    _savedEvents[eventName] = RaceEvent.fromJson(current.toJson());
    _currentEventKey = eventName;

    await _saveStorage();
  }

  String _uniqueEventName(String base) {
    if (!_savedEvents.containsKey(base)) return base;
    var index = 2;
    while (_savedEvents.containsKey('$base ($index)')) index++;
    return '$base ($index)';
  }

  void _newEvent() {
    _currentEventKey = null;
    _setupReady = false;
    _viewingArchivedEvent = false;
    final now = DateTime.now().add(const Duration(minutes: 2));
    setState(() {
      final stamp = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';
      _eventName.text = _uniqueEventName('Neuer Bewerb $stamp');
      _intervalSeconds = 30;
      _compareByCategory = false;
      _autoStartEnabled = false;
      _athletesText.text = _defaultAthletes;
      _pointsText.text = 'Messpunkt 1, split\nMesspunkt 2, split\nZiel, ziel';
      _event = RaceEvent(
        name: _eventName.text,
        firstStart: now,
        intervalSeconds: _intervalSeconds,
        compareByCategory: _compareByCategory,
        athletes: _parseAthletes(_athletesText.text, now),
        points: _parsePoints(_pointsText.text),
      );
      _page = 0;
    });
    _saveEvent();
  }

  DateTime _setupFirstStartDateTime() => _futureDateForTime(_firstStartTime);

  Future<void> _prepareStartTimesInSetup() async {
    final firstStart = _setupFirstStartDateTime();
    final athletes = _parseAthletes(_athletesText.text, firstStart);
    final points = _parsePoints(_pointsText.text);
    final eventName = _eventName.text.trim().isEmpty ? 'Unbenannter Bewerb' : _eventName.text.trim();

    for (var i = 0; i < athletes.length; i++) {
      athletes[i].scheduledStart = firstStart.add(Duration(seconds: i * _intervalSeconds));
    }

    setState(() {
      _event = RaceEvent(
        name: eventName,
        firstStart: firstStart,
        intervalSeconds: _intervalSeconds,
        compareByCategory: _compareByCategory,
        athletes: athletes,
        points: points,
      );

      _athletesText.text = athletes
          .map((a) => '${a.bib}, ${a.name}, ${a.category}${a.isOwn ? ', *' : ''}, ${_clock(a.scheduledStart)}')
          .join('\n');

      _pointsText.text = points
          .map((p) => '${p.name}, ${p.type == PointType.finish ? 'ziel' : 'split'}')
          .join('\n');
    });

    await _saveEvent();
    _show('Startzeiten übernommen');
  }

  void _goToStart() {
    final hasRaceData = _hasRaceData();
    if (!hasRaceData) {
      _createEventFromSetup(silent: true);
    }
    _setupReady = true;
    _saveEvent();
    setState(() => _page = 1);
  }

  Future<void> _addSplitPointFromCapture() async {
    final event = _event;
    if (event == null) return;
    final newPoint = await _pointFromTemplateDialog(event.points);
    if (newPoint == null) return;
    setState(() {
      final finishIndex = event.points.lastIndexWhere((p) => p.type == PointType.finish);
      if (finishIndex >= 0) {
        event.points.insert(finishIndex, newPoint);
      } else {
        event.points.add(newPoint);
        event.points.add(SplitPoint(id: 'p_finish', name: 'Ziel', type: PointType.finish));
      }
      _pointsText.text = event.points.map((p) => '${p.name}, ${p.type == PointType.finish ? 'ziel' : 'split'}').join('\n');
    });
    await _saveEvent();
    _show('Messpunkt hinzugefügt');
  }

  Future<void> _deleteEvent(String name) async {
    final event = _savedEvents[name];
    if (event == null) return;

    final hasResults = _hasRaceData(event);

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(hasResults ? 'Bewerb mit Ergebnissen' : 'Bewerb löschen?'),
        content: Text(
          hasResults
              ? 'Dieser Bewerb enthält Ergebnisse. Du kannst ihn archivieren oder endgültig löschen.'
              : 'Diesen Bewerb wirklich löschen?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('Abbrechen')),
          if (hasResults)
            OutlinedButton(onPressed: () => Navigator.pop(context, 'archive'), child: const Text('Archivieren')),
          FilledButton(onPressed: () => Navigator.pop(context, 'delete'), child: const Text('Löschen')),
        ],
      ),
    );

    if (action == null || action == 'cancel') return;

    final removed = _savedEvents.remove(name);
    if (removed == null) return;

    if (action == 'archive') {
      _archivedEvents[name] = RaceEvent.fromJson(removed.toJson());
    }

    if (_currentEventKey == name) {
      _currentEventKey = null;
    }

    await _saveStorage();
    setState(() {});
    _show(action == 'archive' ? 'Bewerb archiviert' : 'Bewerb gelöscht');
  }

  void _loadEvent(RaceEvent event) {
    final copy = RaceEvent.fromJson(event.toJson());
    _currentEventKey = copy.name;
    setState(() {
      _event = copy;
      _eventName.text = copy.name;
      _intervalSeconds = copy.intervalSeconds;
      _compareByCategory = copy.compareByCategory;
      _firstStartTime = TimeOfDay.fromDateTime(copy.firstStart);
      _athletesText.text = copy.athletes.map((a) => '${a.bib}, ${a.name}, ${a.category}${a.isOwn ? ', *' : ''}, ${_formatClock(a.scheduledStart)}').join('\n');
      _pointsText.text = copy.points.map((p) => '${p.name}, ${p.type == PointType.finish ? 'ziel' : 'split'}').join('\n');
      _autoStartEnabled = false;
      _setupReady = _hasRaceData(copy);
      _page = 0;
    });
    _show('Bewerb geladen: ${copy.name}');
  }

  Future<void> _saveGroups() async {
    await _saveStorage();
    _show('Standardgruppen gespeichert');
  }

  void _loadGroup(String athletesText, {bool append = false}) {
    setState(() {
      if (append && _athletesText.text.trim().isNotEmpty) {
        _athletesText.text = '${_athletesText.text.trim()}\n$athletesText';
      } else {
        _athletesText.text = athletesText;
      }
    });
    _show(append ? 'Gruppe ergänzt' : 'Gruppe geladen');
  }

  void _csvImportDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CSV importieren'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: ctrl,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'Startnummer;Name;AK;Startzeit\n12;Max;U12m;10:00:00',
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              setState(() => _athletesText.text = _normalizeImportText(ctrl.text));
              Navigator.pop(context);
              _show('CSV übernommen');
            },
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
  }


  String _normalizeImportText(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final output = <String>[];

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('startnummer') && lower.contains('name')) continue;
      final sep = line.contains(';') ? ';' : (line.contains('\t') ? '\t' : ',');
      final parts = line.split(sep).map((part) => part.trim()).toList();
      if (parts.length < 3) continue;
      final bib = parts[0];
      final name = parts[1];
      final category = parts[2];
      final start = parts.length > 3 ? parts[3] : '';
      final own = parts.any((part) => part == '*' || part.toLowerCase() == 'trainer' || part == '1');
      output.add('$bib, $name, $category${own ? ', *' : ''}${start.isNotEmpty ? ', $start' : ''}');
    }
    return output.join('\n');
  }

  void _photoImportDemo() {
    setState(() {
      _athletesText.text =
          '101, Laura, U12w, *\n102, Tobias, U12m\n103, Marie, U14w, *\n104, Elias, U14m\n105, Nina, U12w\n106, Jakob, U12m, *';
    });
    _show('Fotoimport simuliert. V2: Kamera → OCR → Korrektur.');
  }

  String _formatTimeOfDay24(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  void _toggleAutoStart() {
    final enable = !_autoStartEnabled;
    if (enable && _event != null) {
      final now = DateTime.now();
      for (final athlete in _event!.athletes.where((a) => a.status == AthleteStatus.waiting)) {
        while (athlete.scheduledStart.isBefore(now)) {
          athlete.scheduledStart = athlete.scheduledStart.add(const Duration(days: 1));
        }
      }
      _saveEvent();
    }
    setState(() => _autoStartEnabled = enable);
  }

  void _autoStart() {
    if (!_autoStartEnabled) return;
    final event = _event;
    if (event == null) return;
    final now = DateTime.now();
    var changed = false;
    for (final athlete in event.athletes) {
      if (athlete.status == AthleteStatus.waiting && !now.isBefore(athlete.scheduledStart)) {
        athlete.status = AthleteStatus.running;
        athlete.actualStart = athlete.scheduledStart;
        changed = true;
      }
    }
    if (changed) { setState(() {}); _saveEvent(); }
  }

  void _manualStart(Athlete athlete) {
    if (athlete.status != AthleteStatus.waiting) return;
    final oldStatus = athlete.status;
    final oldStart = athlete.actualStart;

    setState(() {
      athlete.status = AthleteStatus.running;
      athlete.actualStart = DateTime.now();
    });

    _undoSnack('${athlete.bib} ${athlete.name} gestartet', () {
      setState(() {
        athlete.status = oldStatus;
        athlete.actualStart = oldStart;
      });
    });
    _saveEvent();
  }

  void _massStart() {
    final event = _event;
    if (event == null) return;

    final waiting = event.athletes.where((a) => a.status == AthleteStatus.waiting).take(15).toList();
    if (waiting.isEmpty) return;

    final now = DateTime.now();
    final old = waiting.map((a) => MapEntry(a, MapEntry(a.status, a.actualStart))).toList();

    setState(() {
      for (final a in waiting) {
        a.status = AthleteStatus.running;
        a.actualStart = now;
        a.scheduledStart = now;
      }
    });
    _saveEvent();

    _undoSnack('Massenstart: ${waiting.length} Athleten gestartet', () {
      setState(() {
        for (final entry in old) {
          entry.key.status = entry.value.key;
          entry.key.actualStart = entry.value.value;
        }
      });
    });
  }


  (int, int, int)? _parseClock(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(value.trim());
    if (match == null) return null;
    final h = int.tryParse(match.group(1) ?? '');
    final m = int.tryParse(match.group(2) ?? '');
    final s = int.tryParse(match.group(3) ?? '0') ?? 0;
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59 || s < 0 || s > 59) return null;
    return (h, m, s);
  }

  DateTime _dateWithClock(String value, {required DateTime fallback}) {
    final parsed = _parseClock(value);
    if (parsed == null) return fallback;
    var result = DateTime(fallback.year, fallback.month, fallback.day, parsed.$1, parsed.$2, parsed.$3);
    if (result.isBefore(DateTime.now())) result = result.add(const Duration(days: 1));
    return result;
  }

  void _removeAthleteFromEvent(Athlete athlete) {
    final event = _event;
    if (event == null) return;

    final index = event.athletes.indexWhere((a) => a.bib == athlete.bib);
    if (index < 0) return;

    final removed = event.athletes[index];

    setState(() {
      event.athletes.removeAt(index);
    });

    _saveEvent();

    _undoSnack('${removed.name} aus Startliste entfernt', () {
      setState(() {
        event.athletes.insert(index, removed);
      });
    });
  }

  Future<void> _editAthleteStart(Athlete athlete) async {
    final controller = TextEditingController(text: _formatClock(athlete.scheduledStart));

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Startzeit: ${athlete.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.datetime,
          decoration: const InputDecoration(
            labelText: 'HH:MM:SS',
            helperText: 'z. B. 10:00:30',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              final old = athlete.scheduledStart;
              final next = _dateWithClock(controller.text, fallback: athlete.scheduledStart);
              setState(() => athlete.scheduledStart = next);
              _saveEvent();
              Navigator.pop(context);
              _undoSnack('${athlete.name}: Startzeit geändert', () {
                setState(() => athlete.scheduledStart = old);
              });
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _capture(Athlete athlete, SplitPoint point) {
    if (athlete.status != AthleteStatus.running) return;
    final key = _key(point);
    if (athlete.captures.containsKey(key)) return;

    final oldStatus = athlete.status;
    final now = DateTime.now();

    setState(() {
      athlete.captures[key] = now;
      if (point.type == PointType.finish) athlete.status = AthleteStatus.finished;
    });
    _saveEvent();

    _undoSnack(_feedbackText(athlete, point), () {
      setState(() {
        athlete.captures.remove(key);
        athlete.status = oldStatus;
      });
    });
  }

  String _feedbackText(Athlete athlete, SplitPoint point) {
    final rows = _ranking(point);
    final match = rows.where((r) => r.athlete.bib == athlete.bib).toList();
    if (match.isEmpty) return '✓ ${athlete.bib} ${athlete.name}';

    final row = match.first;
    if (point.type == PointType.finish) {
      return '✓ ${athlete.bib} ${athlete.name} · Ziel · ${_fmtDuration(row.elapsed)} · Pl ${row.place} · +${_fmtDuration(row.deltaToLeader)}';
    }

    final trend = row.sectionDelta == null ? 'Trend —' : 'Trend +${_fmtDuration(row.sectionDelta!)}';
    return '✓ ${athlete.bib} ${athlete.name} · ${point.name} · Pl ${row.place} · +${_fmtDuration(row.deltaToLeader)} · $trend';
  }

  String _key(SplitPoint point) => point.type == PointType.finish ? 'finish:${point.id}' : point.id;
  DateTime? _captureTime(Athlete athlete, SplitPoint point) => athlete.captures[_key(point)];
  Duration _elapsed(Athlete athlete, DateTime time) => time.difference(athlete.startTime);
  int _pointIndex(SplitPoint point) => _event?.points.indexWhere((p) => p.id == point.id) ?? -1;

  SplitPoint? _previousPoint(SplitPoint point) {
    final event = _event;
    if (event == null) return null;
    final index = _pointIndex(point);
    if (index <= 0) return null;
    return event.points[index - 1];
  }

  DateTime? _anchorTime(Athlete athlete, SplitPoint point) {
    final previous = _previousPoint(point);
    if (previous == null) return athlete.startTime;
    return _captureTime(athlete, previous);
  }

  Duration? _sectionDuration(Athlete athlete, SplitPoint point) {
    final current = _captureTime(athlete, point);
    if (current == null) return null;
    final anchor = _anchorTime(athlete, point);
    if (anchor == null) return null;
    return current.difference(anchor);
  }

  String _group(Athlete athlete) => (_event?.compareByCategory ?? true) ? athlete.category : 'ALLE';

  Duration? _baseSection(SplitPoint point, String group) {
    final event = _event;
    if (event == null) return null;

    var samples = <Duration>[];
    for (final athlete in event.athletes) {
      if (_group(athlete) != group) continue;
      final section = _sectionDuration(athlete, point);
      if (section != null && !section.isNegative) samples.add(section);
    }

    if (samples.isEmpty && event.compareByCategory) {
      for (final athlete in event.athletes) {
        final section = _sectionDuration(athlete, point);
        if (section != null && !section.isNegative) samples.add(section);
      }
    }

    if (samples.isEmpty) return null;
    samples.sort();
    return samples[samples.length ~/ 2];
  }

  int _sampleCount(SplitPoint point, String group) {
    final event = _event;
    if (event == null) return 0;
    var count = 0;
    for (final athlete in event.athletes) {
      if (_group(athlete) != group) continue;
      if (_sectionDuration(athlete, point) != null) count++;
    }
    return count;
  }

  Duration _trendCorrection(Athlete athlete, SplitPoint point) {
    final previous = _previousPoint(point);
    if (previous == null) return Duration.zero;
    final prevRows = _ranking(previous);
    final own = prevRows.where((r) => r.athlete.bib == athlete.bib).toList();
    if (own.isEmpty) return Duration.zero;
    final totalDelta = own.first.deltaToLeader;
    final sectionDelta = own.first.sectionDelta ?? Duration.zero;
    return Duration(milliseconds: (totalDelta.inMilliseconds * 0.25 + sectionDelta.inMilliseconds * 0.45).round());
  }

  Candidate _candidate(Athlete athlete, SplitPoint point) {
    final anchor = _anchorTime(athlete, point);
    final base = _baseSection(point, _group(athlete));
    DateTime? prediction;
    var quality = 'keine Prognose';

    if (anchor != null && base != null) {
      prediction = anchor.add(base).add(_trendCorrection(athlete, point));
      final samples = _sampleCount(point, _group(athlete));
      quality = samples <= 1 ? 'erste Schätzung' : (samples < 5 ? 'Schätzung' : 'stabiler');
    }
    return Candidate(athlete: athlete, predictedTime: prediction, quality: quality);
  }

  List<Candidate> _candidatesFor(SplitPoint point) {
    final event = _event;
    if (event == null) return [];
    final key = _key(point);
    final previous = _previousPoint(point);

    final candidates = event.athletes
        .where((a) => a.status == AthleteStatus.running && !a.captures.containsKey(key))
        .map((a) => _candidate(a, point))
        .toList();

    candidates.sort((a, b) {
      final at = a.predictedTime;
      final bt = b.predictedTime;

      if (at != null && bt != null) return at.compareTo(bt);
      if (at != null) return -1;
      if (bt != null) return 1;

      if (previous != null) {
        final aPrev = _captureTime(a.athlete, previous);
        final bPrev = _captureTime(b.athlete, previous);

        if (aPrev != null && bPrev != null) return aPrev.compareTo(bPrev);
        if (aPrev != null) return -1;
        if (bPrev != null) return 1;
      }

      return a.athlete.startTime.compareTo(b.athlete.startTime);
    });

    final isFirstPoint = _pointIndex(point) == 0;
    return candidates.take(isFirstPoint ? 15 : 6).toList();
  }

  List<RankRow> _ranking(SplitPoint point) {
    final event = _event;
    if (event == null) return [];
    final raw = <MapEntry<Athlete, Duration>>[];
    for (final athlete in event.athletes) {
      final time = _captureTime(athlete, point);
      if (time == null) continue;
      raw.add(MapEntry(athlete, _elapsed(athlete, time)));
    }

    final grouped = <String, List<MapEntry<Athlete, Duration>>>{};
    for (final item in raw) {
      grouped.putIfAbsent(_group(item.key), () => []).add(item);
    }

    final rows = <RankRow>[];
    for (final groupRows in grouped.values) {
      groupRows.sort((a, b) => a.value.compareTo(b.value));
      if (groupRows.isEmpty) continue;
      final leader = groupRows.first.value;
      final athletesInGroup = groupRows.map((e) => e.key).toList();
      final sectionDeltas = _sectionDeltas(point, athletesInGroup);
      final sectionPlaces = _sectionPlaces(point, athletesInGroup);

      for (var i = 0; i < groupRows.length; i++) {
        final athlete = groupRows[i].key;
        rows.add(RankRow(
          athlete: athlete,
          elapsed: groupRows[i].value,
          place: i + 1,
          deltaToLeader: groupRows[i].value - leader,
          sectionElapsed: _sectionDuration(athlete, point),
          sectionDelta: sectionDeltas[athlete.bib],
          sectionPlace: sectionPlaces[athlete.bib],
        ));
      }
    }

    rows.sort((a, b) {
      final event = _event;
      if (event != null && event.compareByCategory) {
        final cat = a.athlete.category.compareTo(b.athlete.category);
        if (cat != 0) return cat;
      }
      return a.place.compareTo(b.place);
    });
    return rows;
  }

  Map<int, int> _sectionPlaces(SplitPoint point, List<Athlete> athletes) {
    final values = <MapEntry<int, Duration>>[];
    for (final athlete in athletes) {
      final section = _sectionDuration(athlete, point);
      if (section != null) values.add(MapEntry(athlete.bib, section));
    }
    values.sort((a, b) => a.value.compareTo(b.value));
    return {for (var i = 0; i < values.length; i++) values[i].key: i + 1};
  }

  Map<int, Duration> _sectionDeltas(SplitPoint point, List<Athlete> athletes) {
    final values = <int, Duration>{};
    for (final athlete in athletes) {
      final section = _sectionDuration(athlete, point);
      if (section != null) values[athlete.bib] = section;
    }
    if (values.isEmpty) return {};
    final best = values.values.reduce((a, b) => a <= b ? a : b);
    return values.map((bib, duration) => MapEntry(bib, duration - best));
  }

  String _lastStand(Athlete athlete) {
    if (athlete.status == AthleteStatus.finished) return 'Ziel';
    if (athlete.captures.isEmpty) return 'gestartet';
    final lastKey = athlete.captures.keys.last;
    final event = _event;
    if (event == null) return 'Messpunkt';
    for (final point in event.points) {
      if (lastKey.contains(point.id)) return point.name;
    }
    return 'Messpunkt';
  }

  String _finishSummary(Athlete athlete) {
    final event = _event;
    if (event == null) return '';
    final finish = event.points.where((p) => p.type == PointType.finish).toList();
    if (finish.isEmpty) return '';
    final own = _ranking(finish.first).where((r) => r.athlete.bib == athlete.bib).toList();
    if (own.isEmpty) return '';
    final row = own.first;
    return '${_fmtDuration(row.elapsed)} · Pl ${row.place} · +${_fmtDuration(row.deltaToLeader)}';
  }

  Duration? _liveGapToLeader(Athlete athlete, SplitPoint point) {
    final rows = _ranking(point);
    final currentElapsed = DateTime.now().difference(athlete.startTime);

    if (rows.isEmpty) {
      return currentElapsed;
    }

    final leaderElapsed = rows.map((r) => r.elapsed).reduce((a, b) => a <= b ? a : b);
    return currentElapsed - leaderElapsed;
  }

  String _liveGapText(Athlete athlete, SplitPoint point) {
    final rows = _ranking(point);
    final value = _liveGapToLeader(athlete, point);
    if (value == null) return '—';

    if (rows.isEmpty) return _fmtLiveDuration(value);

    if (value.inSeconds == 0) return '0:00';
    final sign = value.isNegative ? '-' : '+';
    return '$sign${_fmtLiveDuration(value.abs())}';
  }

  String _eta(DateTime? time) {
    if (time == null) return '—';
    final diff = time.difference(DateTime.now());
    final sign = diff.isNegative ? '+' : '';
    return '$sign${_fmtCountdown(diff.abs())}';
  }

  String _fmtCountdown(Duration d) => '${(d.inSeconds ~/ 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  String _fmtLiveDuration(Duration d) {
    final abs = d.abs();
    final totalSeconds = abs.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final sign = d.isNegative ? '-' : '';
    if (hours > 0) {
      return '$sign${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$sign${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _fmtDuration(Duration d) {
    final neg = d.isNegative;
    final abs = d.abs();
    final totalMs = abs.inMilliseconds;
    final min = totalMs ~/ 60000;
    final sec = (totalMs % 60000) / 1000.0;
    final sign = neg ? '-' : '';
    if (min > 0) return '$sign$min:${sec.toStringAsFixed(1).padLeft(4, '0').replaceAll('.', ',')}';
    return '$sign${sec.toStringAsFixed(1).replaceAll('.', ',')}s';
  }

  String _clock(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _csvExport() {
    final event = _event;
    if (event == null) return '';
    final buffer = StringBuffer();
    buffer.writeln('Bewerb;${event.name}');
    buffer.writeln('Wertung;${event.compareByCategory ? 'Altersklasse' : 'Gesamt'}');
    buffer.writeln();
    buffer.writeln('Messpunkt;Platz;Startnummer;Name;AK;Gesamtzeit;Rückstand;Abschnitt;Trend');
    for (final point in event.points) {
      for (final row in _ranking(point)) {
        buffer.writeln([point.name, row.place, row.athlete.bib, row.athlete.name, row.athlete.category, _fmtDuration(row.elapsed), _fmtDuration(row.deltaToLeader), row.sectionElapsed == null ? '' : _fmtDuration(row.sectionElapsed!), row.sectionDelta == null ? '' : _fmtDuration(row.sectionDelta!)].join(';'));
      }
    }
    return buffer.toString();
  }

  String _htmlExport() {
    final event = _event;
    if (event == null) return '';
    final buffer = StringBuffer();
    buffer.writeln('<!doctype html><html><head><meta charset="utf-8"><title>${event.name}</title>');
    buffer.writeln('<style>body{font-family:Arial,sans-serif}table{border-collapse:collapse;margin-bottom:24px}td,th{border:1px solid #ccc;padding:6px 8px}th{background:#eee}</style>');
    buffer.writeln('</head><body><h1>CoachSplit · ${event.name}</h1><p>Wertung: ${event.compareByCategory ? 'Altersklasse' : 'Gesamt'}</p>');
    for (final point in event.points) {
      buffer.writeln('<h2>${point.name}</h2><table><tr><th>Platz</th><th>Nr</th><th>Name</th><th>AK</th><th>Gesamt</th><th>Rückstand</th><th>Abschnitt</th><th>Trend</th></tr>');
      for (final row in _ranking(point)) {
        buffer.writeln('<tr><td>${row.place}</td><td>${row.athlete.bib}</td><td>${row.athlete.name}</td><td>${row.athlete.category}</td><td>${_fmtDuration(row.elapsed)}</td><td>${_fmtDuration(row.deltaToLeader)}</td><td>${row.sectionElapsed == null ? '' : _fmtDuration(row.sectionElapsed!)}</td><td>${row.sectionDelta == null ? '' : _fmtDuration(row.sectionDelta!)}</td></tr>');
      }
      buffer.writeln('</table>');
    }
    buffer.writeln('</body></html>');
    return buffer.toString();
  }



  String _padCell(String value, int width) {
    final clean = value.length > width ? value.substring(0, width) : value;
    return clean.padRight(width);
  }

  String _sectionPlaceText(Athlete athlete, SplitPoint point) {
    final rows = _ranking(point);
    final own = rows.where((r) => r.athlete.bib == athlete.bib).toList();
    if (own.isEmpty) return '—';

    final row = own.first;
    if (point.type == PointType.finish) {
      return row.deltaToLeader == Duration.zero
          ? _fmtDuration(row.elapsed)
          : '+${_fmtDuration(row.deltaToLeader)}';
    }

    final section = row.sectionElapsed;
    if (section == null) return '—';
    return '${_fmtDuration(section)} (${row.sectionPlace ?? row.place})';
  }

  String _shareTableText({bool compact = false}) {
    final event = _event;
    if (event == null) return '';

    final finishPoints = event.points.where((p) => p.type == PointType.finish).toList();
    final rankingPoint = finishPoints.isNotEmpty ? finishPoints.last : event.points.last;
    final finalRows = _ranking(rankingPoint);

    final buffer = StringBuffer();
    final date = DateTime.now();

    buffer.writeln('CoachSplit');
    buffer.writeln(event.name);
    buffer.writeln('${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} · Startintervall: ${event.intervalSeconds}s');
    buffer.writeln(event.compareByCategory ? 'Wertung: Altersklassen' : 'Wertung: Gesamt');
    buffer.writeln();

    if (finalRows.isEmpty) {
      buffer.writeln('Noch keine Zielzeiten erfasst.');
      return buffer.toString();
    }

    final rowsByGroup = <String, List<RankRow>>{};
    for (final row in finalRows) {
      final group = event.compareByCategory ? row.athlete.category : 'Gesamt';
      rowsByGroup.putIfAbsent(group, () => <RankRow>[]).add(row);
    }

    for (final groupEntry in rowsByGroup.entries) {
      buffer.writeln('--- ${groupEntry.key} ---');

      final splitPoints = event.points.where((p) => p.type != PointType.finish).toList();
      final columns = <String>['Pl', 'Nr', 'Name', ...splitPoints.map((p) => p.name), 'Gesamt'];

      final widths = <int>[];
      for (var i = 0; i < columns.length; i++) {
        if (i == 0) {
          widths.add(3);
        } else if (i == 1) {
          widths.add(4);
        } else if (i == 2) {
          widths.add(compact ? 14 : 18);
        } else {
          widths.add(compact ? 12 : 14);
        }
      }

      buffer.writeln([
        for (var i = 0; i < columns.length; i++) _padCell(columns[i], widths[i]),
      ].join(' | '));

      buffer.writeln([
        for (var i = 0; i < columns.length; i++) ''.padRight(widths[i], '-'),
      ].join('-+-'));

      for (final finalRow in groupEntry.value) {
        final athlete = finalRow.athlete;

        final values = <String>[
          '${finalRow.place}',
          '${athlete.bib}',
          athlete.name,
          for (final point in splitPoints) _sectionPlaceText(athlete, point),
          _sectionPlaceText(athlete, rankingPoint),
        ];

        buffer.writeln([
          for (var i = 0; i < values.length; i++) _padCell(values[i], widths[i]),
        ].join(' | '));
      }

      buffer.writeln();
    }

    buffer.writeln('Erstellt mit CoachSplit');
    return buffer.toString();
  }

  String _shareText() {
    return _shareTableText();
  }

  String _imageExportPreviewText() {
    return _shareTableText(compact: true);
  }

  List<List<String>> _resultTableRowsForExport() {
    final event = _event;
    if (event == null) return [];
    final finishPoints = event.points.where((p) => p.type == PointType.finish).toList();
    final rankingPoint = finishPoints.isNotEmpty ? finishPoints.last : event.points.last;
    final finalRows = _ranking(rankingPoint);
    final splitPoints = event.points.where((p) => p.type != PointType.finish).toList();
    final rows = <List<String>>[];
    rows.add(['Pl', 'Nr', 'Name', ...splitPoints.map((p) => p.name), 'Ziel']);
    for (final finalRow in finalRows) {
      final athlete = finalRow.athlete;
      rows.add(['${finalRow.place}', '${athlete.bib}', athlete.name, for (final p in splitPoints) _sectionPlaceText(athlete, p), _sectionPlaceText(athlete, rankingPoint)]);
    }
    return rows;
  }

  Future<Uint8List> _createResultsPngBytes() async {
    final event = _event;
    if (event == null) throw StateError('Kein Bewerb geladen');
    final rows = _resultTableRowsForExport();
    if (rows.length <= 1) throw StateError('Noch keine Zielzeiten erfasst');

    const scale = 2.0;
    final splitCount = max(0, rows.first.length - 4);
    final width = max(1280.0, 780.0 + splitCount * 150.0);
    final rowHeight = 42.0;
    final headerHeight = 132.0;
    final tableHeight = rows.length * rowHeight;
    final chartHeight = 340.0;
    final height = headerHeight + tableHeight + chartHeight + 118.0;

    final logoData = await rootBundle.load('assets/icon/coachsplit_icon.png');
    final logoCodec = await ui.instantiateImageCodec(logoData.buffer.asUint8List(), targetWidth: 96, targetHeight: 96);
    final logoFrame = await logoCodec.getNextFrame();
    final logoImage = logoFrame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);

    final bg = Paint()..color = const Color(0xFF0B1118);
    final panel = Paint()..color = const Color(0xFF101923);
    final headerPaint = Paint()..color = const Color(0xFF172431);
    final stripePaint = Paint()..color = const Color(0xFF13202B);
    final linePaint = Paint()..color = const Color(0xFF42505E)..strokeWidth = 1;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bg);

    void drawPanel(Rect r) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(12)), panel);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(12)), Paint()..color = const Color(0xFF4B5A67)..style = PaintingStyle.stroke..strokeWidth = 1);
    }

    void drawText(String v, double x, double y, double s, Color c, {FontWeight w = FontWeight.normal, double maxWidth = 300}) {
      final p = TextPainter(
        text: TextSpan(text: v, style: TextStyle(color: c, fontSize: s, fontWeight: w, fontFamily: 'Roboto')),
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
      p.paint(canvas, Offset(x, y));
    }

    final date = DateTime.now();
    final dateText = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    canvas.drawImageRect(logoImage, Rect.fromLTWH(0, 0, logoImage.width.toDouble(), logoImage.height.toDouble()), const Rect.fromLTWH(38, 18, 76, 76), Paint());
    drawText('CoachSplit', 126, 25, 30, Colors.white, w: FontWeight.w900, maxWidth: 190);
    drawText('ZEIT. ANALYSIERT. VERBESSERT.', 126, 63, 11, const Color(0xFFC7D2DC), maxWidth: 210);
    drawText(event.name, 350, 24, 32, Colors.white, w: FontWeight.w800, maxWidth: width - 580);
    drawText('Ergebnisliste', 330, 66, 22, const Color(0xFF2F8CFF), maxWidth: 280);
    drawText(dateText, width - 190, 42, 18, const Color(0xFFD8E0E8), maxWidth: 150);

    final tableRect = Rect.fromLTWH(24, headerHeight, width - 48, tableHeight);
    drawPanel(tableRect);
    canvas.drawRect(Rect.fromLTWH(tableRect.left, tableRect.top, tableRect.width, rowHeight), headerPaint);

    final colCount = rows.first.length;
    final fixed = [70.0, 80.0, 230.0];
    final remaining = tableRect.width - fixed.reduce((a, b) => a + b);
    final flexWidth = remaining / (colCount - 3);
    final colWidths = <double>[...fixed, for (var i = 3; i < colCount; i++) flexWidth];

    for (var r = 0; r < rows.length; r++) {
      final isHeader = r == 0;
      final y = tableRect.top + r * rowHeight;
      if (r > 0 && r.isEven) canvas.drawRect(Rect.fromLTWH(tableRect.left, y, tableRect.width, rowHeight), stripePaint);
      canvas.drawLine(Offset(tableRect.left, y), Offset(tableRect.right, y), linePaint);
      var x = tableRect.left;
      for (var c = 0; c < colCount; c++) {
        canvas.drawLine(Offset(x, y), Offset(x, y + rowHeight), linePaint);
        drawText(rows[r][c], x + 10, y + 11, isHeader ? 16 : 15, isHeader ? Colors.white : const Color(0xFFE8EEF4), w: isHeader ? FontWeight.w700 : FontWeight.w500, maxWidth: colWidths[c] - 20);
        x += colWidths[c];
      }
      canvas.drawLine(Offset(tableRect.right, y), Offset(tableRect.right, y + rowHeight), linePaint);
    }

    final chartTop = tableRect.bottom + 24;
    final chartRect = Rect.fromLTWH(24, chartTop, width - 360, chartHeight);
    final legendRect = Rect.fromLTWH(width - 312, chartTop, 288, chartHeight);
    drawPanel(chartRect);
    drawPanel(legendRect);
    drawText('PLATZIERUNGSVERLAUF', chartRect.left + 20, chartRect.top + 18, 18, const Color(0xFF2F8CFF), w: FontWeight.w800, maxWidth: 260);
    drawText('(nach Gesamtzeit bis zu jedem Messpunkt)', chartRect.left + 250, chartRect.top + 20, 14, const Color(0xFFC7D2DC), maxWidth: 360);
    drawText('LEGENDE', legendRect.left + 20, legendRect.top + 24, 18, const Color(0xFF2F8CFF), w: FontWeight.w800, maxWidth: 180);

    final points = event.points;
    final finishPointsForChart = event.points.where((p) => p.type == PointType.finish).toList();
    final finishPoint = finishPointsForChart.isNotEmpty ? finishPointsForChart.last : event.points.last;
    final finalRows = _ranking(finishPoint).take(10).toList();
    final progression = <int, List<int?>>{};
    for (final row in finalRows) {
      progression[row.athlete.bib] = [for (final p in points) (() {
        final m = _ranking(p).where((r) => r.athlete.bib == row.athlete.bib).toList();
        return m.isEmpty ? null : m.first.place;
      })()];
    }

    final chartLeft = chartRect.left + 74;
    final chartRight = chartRect.right - 32;
    final chartBottom = chartRect.bottom - 44;
    final chartAreaTop = chartRect.top + 72;
    final maxPlace = max(1, finalRows.length);
    double yForPlace(int place) => maxPlace <= 1 ? chartAreaTop : chartAreaTop + (place - 1) * ((chartBottom - chartAreaTop) / (maxPlace - 1));
    final gridPaint = Paint()..color = const Color(0xFF3C4650)..strokeWidth = 1;

    for (var place = 1; place <= maxPlace; place++) {
      final y = yForPlace(place);
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);
      drawText('$place', chartRect.left + 30, y - 9, 16, Colors.white, w: FontWeight.w600, maxWidth: 36);
    }

    for (var i = 0; i < points.length; i++) {
      final x = points.length <= 1 ? chartLeft : chartLeft + i * ((chartRight - chartLeft) / (points.length - 1));
      drawText(points[i].type == PointType.finish ? 'Ziel' : points[i].name, x - 28, chartBottom + 18, 14, const Color(0xFFE8EEF4), maxWidth: 80);
    }

    final colors = [const Color(0xFF2F8CFF), const Color(0xFFFF3B30), const Color(0xFF4CAF50), const Color(0xFF9B59B6), const Color(0xFFFF8C00), const Color(0xFF00A6B2), const Color(0xFFFFC107), const Color(0xFFE91E63), const Color(0xFF8BC34A), const Color(0xFF03A9F4)];

    void drawMarker(Offset p, int shape, Color color, String label) {
      final paint = Paint()..color = color;
      if (shape % 5 == 0) canvas.drawCircle(p, 8, paint);
      else if (shape % 5 == 1) canvas.drawRect(Rect.fromCenter(center: p, width: 16, height: 16), paint);
      else if (shape % 5 == 2) {
        canvas.drawPath(Path()..moveTo(p.dx, p.dy - 9)..lineTo(p.dx + 9, p.dy + 8)..lineTo(p.dx - 9, p.dy + 8)..close(), paint);
      } else if (shape % 5 == 3) {
        canvas.drawPath(Path()..moveTo(p.dx, p.dy - 9)..lineTo(p.dx + 9, p.dy)..lineTo(p.dx, p.dy + 9)..lineTo(p.dx - 9, p.dy)..close(), paint);
      } else {
        final path = Path();
        for (var k = 0; k < 10; k++) {
          final a = -pi / 2 + k * pi / 5;
          final rr = k.isEven ? 10.0 : 4.5;
          final q = Offset(p.dx + cos(a) * rr, p.dy + sin(a) * rr);
          if (k == 0) path.moveTo(q.dx, q.dy); else path.lineTo(q.dx, q.dy);
        }
        path.close();
        canvas.drawPath(path, paint);
      }
      if (label.isNotEmpty) drawText(label, p.dx - 5, p.dy - 8, 11, Colors.white, w: FontWeight.w800, maxWidth: 18);
    }

    for (var i = 0; i < finalRows.length; i++) {
      final row = finalRows[i];
      final color = colors[i % colors.length];
      final line = Paint()..color = color..strokeWidth = 2.5..style = PaintingStyle.stroke;
      final places = progression[row.athlete.bib] ?? [];
      Offset? prev;
      for (var pIndex = 0; pIndex < places.length; pIndex++) {
        final place = places[pIndex];
        if (place == null) continue;
        final x = places.length <= 1 ? chartLeft : chartLeft + pIndex * ((chartRight - chartLeft) / (places.length - 1));
        final y = yForPlace(place);
        final current = Offset(x, y);
        if (prev != null) canvas.drawLine(prev, current, line);
        drawMarker(current, i, color, '$place');
        prev = current;
      }
      final ly = legendRect.top + 72 + i * 30;
      canvas.drawLine(Offset(legendRect.left + 20, ly + 8), Offset(legendRect.left + 58, ly + 8), line);
      drawMarker(Offset(legendRect.left + 36, ly + 8), i, color, '');
      drawText('${row.athlete.name} (${row.athlete.bib})', legendRect.left + 72, ly, 14, const Color(0xFFE8EEF4), maxWidth: legendRect.width - 88);
    }

    drawText('Erstellt mit CoachSplit', 42, height - 42, 16, const Color(0xFFC7D2DC), maxWidth: 260);

    final picture = recorder.endRecording();
    final image = await picture.toImage((width * scale).round(), (height * scale).round());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw StateError('PNG konnte nicht erstellt werden');
    return byteData.buffer.asUint8List();
  }

  String _resultPngName() {
    final safeName = (_event?.name ?? 'Ergebnis').replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return 'coachsplit_${safeName}.png';
  }

  Future<File> _writePngFile(Uint8List bytes, {bool persistent = false}) async {
    final Directory dir;
    if (persistent) {
      dir = (await getDownloadsDirectory()) ?? (await getExternalStorageDirectory()) ?? await getApplicationDocumentsDirectory();
    } else {
      dir = await getTemporaryDirectory();
    }
    final file = File('${dir.path}/${_resultPngName()}');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _downloadPng(Uint8List bytes) async {
    if (kIsWeb) {
      downloadBytes(bytes, _resultPngName(), 'image/png');
      _show('PNG heruntergeladen');
      return;
    }
    final file = await _writePngFile(bytes, persistent: true);
    _show('PNG gespeichert: ${file.path}');
  }

  Future<void> _sharePng(Uint8List bytes) async {
    try {
      final file = await _writePngFile(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'CoachSplit Ergebnis: ${_event?.name ?? ''}');
    } catch (_) {
      if (kIsWeb) {
        downloadBytes(bytes, _resultPngName(), 'image/png');
        _show('Teilen nicht verfügbar – PNG wurde heruntergeladen');
      } else {
        rethrow;
      }
    }
  }

  Future<void> _exportPngImage() async {
    try {
      final bytes = await _createResultsPngBytes();
      if (!mounted) return;
      final isDesktop = MediaQuery.of(context).size.width >= 800;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF0B1118),
        builder: (sheetContext) => SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.94,
            child: Column(children: [
              ListTile(
                title: const Text('Ergebnisvorschau'),
                subtitle: const Text('Zoomen und verschieben, danach herunterladen oder teilen.'),
                trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(sheetContext)),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: Colors.black,
                  child: InteractiveViewer(
                    minScale: 0.4,
                    maxScale: 5,
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(80),
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                  FilledButton.icon(onPressed: () => _downloadPng(bytes), icon: const Icon(Icons.download), label: const Text('PNG herunterladen')),
                  if (!isDesktop) OutlinedButton.icon(onPressed: () => _sharePng(bytes), icon: const Icon(Icons.ios_share), label: const Text('Teilen')),
                  TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Schließen')),
                ]),
              ),
            ]),
          ),
        ),
      );
    } catch (e) {
      _show(e.toString().replaceFirst('Bad state: ', ''));
    }
  }

  void _exportDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: SelectableText(content.isEmpty ? 'Keine Daten' : content))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen')),
          FilledButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              Navigator.pop(context);
              _show('$title in Zwischenablage kopiert');
            },
            child: const Text('Kopieren'),
          ),
        ],
      ),
    );
  }

  void _show(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _undoSnack(String text, VoidCallback onUndo) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration: const Duration(seconds: 2), content: Text(text), action: SnackBarAction(label: 'Rückgängig', onPressed: onUndo)));
  }


  String _formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Image.asset('assets/icon/coachsplit_icon.png', width: 38, height: 38),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('CoachSplit 1.0.1 RC1'),
            Text(event == null ? 'Kein Bewerb' : '${event.name} · ${event.compareByCategory ? 'AK' : 'Alle'}', style: Theme.of(context).textTheme.bodySmall),
          ])),
        ]),
      ),
      body: SafeArea(
        child: Column(children: [
          _Stats(event: event),
          _Nav(selected: _page, onChanged: (i) {
            if (i > 0 && !_setupReady) {
              _show('Bitte zuerst im Setup auf "Zum Start" tippen.');
              return;
            }
            setState(() => _page = i);
          }),
          Expanded(child: IndexedStack(index: _page, children: [_setupPage(), _startPage(), _capturePage(), _resultsPage()])),
        ]),
      ),
    );
  }

  Widget _setupPage() => ListView(padding: const EdgeInsets.all(12), children: [
        _Section(title: 'Bewerbe', subtitle: 'zuhause vorbereiten, vor Ort laden', child: Column(children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _newEvent,
                  icon: const Icon(Icons.add),
                  label: const Text('Neuer Bewerb'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_savedEvents.isEmpty) const ListTile(title: Text('Noch keine gespeicherten Bewerbe')),
          for (final event in _savedEvents.values)
            Card(child: ListTile(title: Text(event.name), subtitle: Text('${event.athletes.length} Athleten · ${event.points.length} Messpunkte'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteEvent(event.name)), const Icon(Icons.chevron_right)]), onTap: () => _loadEvent(event))),

          if (_archivedEvents.isNotEmpty)
            ExpansionTile(
              title: const Text('Archiv'),
              subtitle: Text('${_archivedEvents.length} Bewerbe'),
              children: [
                for (final event in _archivedEvents.values)
                  ListTile(
                    title: Text(event.name),
                    subtitle: Text('${event.athletes.length} Athleten · ${event.points.length} Messpunkte'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'view') _viewArchivedEvent(event);
                        if (value == 'template') _loadTemplateFromArchived(event);
                        if (value == 'delete') _deleteArchivedEvent(event.name);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'view', child: Text('Einsehen')),
                        PopupMenuItem(value: 'template', child: Text('Als Vorlage verwenden')),
                        PopupMenuItem(value: 'delete', child: Text('Löschen')),
                      ],
                    ),
                    onTap: () => _viewArchivedEvent(event),
                  ),
              ],
            ),
        ])),
        _Section(title: 'Bewerb bearbeiten', subtitle: 'Startzeit, Startliste und Messpunkte', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: _eventName, decoration: const InputDecoration(labelText: 'Bewerb / Training'), onChanged: (_) => _scheduleSetupAutosave()),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _firstStartTime,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                ),
              );
              if (picked != null) { setState(() => _firstStartTime = picked); _scheduleSetupAutosave(); }
            }, icon: const Icon(Icons.schedule), label: Text('Start: ${_formatTimeOfDay24(_firstStartTime)}'))),
            const SizedBox(width: 8),
            DropdownButton<int>(value: _intervalSeconds, items: const [DropdownMenuItem(value: 15, child: Text('15s')), DropdownMenuItem(value: 30, child: Text('30s')), DropdownMenuItem(value: 60, child: Text('60s'))], onChanged: (v) {
              if (v != null) { setState(() => _intervalSeconds = v); _scheduleSetupAutosave(); }
            }),
          ]),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _prepareStartTimesInSetup,
            icon: const Icon(Icons.schedule),
            label: const Text('Startzeiten übernehmen'),
          ),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Altersklassen getrennt werten'), subtitle: const Text('Auch in Ergebnisansicht umschaltbar'), value: _compareByCategory, onChanged: (v) { setState(() => _compareByCategory = v); _scheduleSetupAutosave(); }),
          TextField(controller: _athletesText, maxLines: 8, onChanged: (_) => _scheduleSetupAutosave(), decoration: const InputDecoration(labelText: 'Athleten im Bewerb', hintText: '12, Max, U12m, *', alignLabelWithHint: true)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: _csvImportDialog, icon: const Icon(Icons.table_chart), label: const Text('CSV importieren')),
            OutlinedButton.icon(onPressed: _addSplitPointFromSetup, icon: const Icon(Icons.add_location_alt), label: const Text('Messpunkt hinzufügen')),
          ]),
          const SizedBox(height: 8),
          TextField(controller: _pointsText, maxLines: 5, onChanged: (_) => _scheduleSetupAutosave(), decoration: const InputDecoration(labelText: 'Messpunkte', hintText: 'Messpunkt 1, split\nMesspunkt 2, split\nZiel, ziel', alignLabelWithHint: true)),
          const SizedBox(height: 12),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: _goToStart, icon: const Icon(Icons.arrow_forward), label: const Text('Zum Start')),
        ])),
        _Section(title: 'Meine Standardathleten', subtitle: 'Gruppen einklappbar, dauerhaft speicherbar', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final entry in _parseGroups().entries)
            ExpansionTile(title: Text(entry.key), subtitle: Text('${entry.value.split('\n').where((l) => l.trim().isNotEmpty).length} Athleten'), children: [
              Padding(padding: const EdgeInsets.all(8), child: Text(entry.value)),
              Wrap(spacing: 8, children: [
                OutlinedButton(onPressed: () => _loadGroup(entry.value), child: const Text('Als Startliste')),
                OutlinedButton(onPressed: () => _loadGroup(entry.value, append: true), child: const Text('Ergänzen')),
              ]),
              const SizedBox(height: 8),
            ]),
          const SizedBox(height: 8),
          TextField(controller: _groupsText, maxLines: 10, decoration: const InputDecoration(labelText: 'Gruppen bearbeiten', hintText: '[U12]\n12, Max, U12m, *', alignLabelWithHint: true)),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _saveGroups, icon: const Icon(Icons.save), label: const Text('Standardgruppen speichern')),
        ]))
      ]);

  Widget _startPage() {
    final event = _event;
    if (event == null) return const Center(child: Text('Kein Bewerb geladen'));
    final waiting = event.athletes.where((a) => a.status == AthleteStatus.waiting).take(15).toList();
    final running = event.athletes.where((a) => a.status == AthleteStatus.running).toList();
    final finished = event.athletes.where((a) => a.status == AthleteStatus.finished).toList().reversed.take(5).toList();
    return ListView(padding: const EdgeInsets.all(12), children: [
      _Section(title: 'Startliste', subtitle: 'Countdown + manueller Start + Massenstart bis 15', child: Column(children: [
        if (waiting.isNotEmpty) Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _massStart,
                icon: const Icon(Icons.groups),
                label: Text('Massenstart (${min(15, waiting.length)})'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _toggleAutoStart,
                icon: Icon(_autoStartEnabled ? Icons.timer : Icons.timer_off),
                label: Text(_autoStartEnabled ? 'AutoStart EIN' : 'AutoStart AUS'),
              ),
            ),
          ]),
        ),
        if (waiting.isEmpty) const ListTile(title: Text('Alle Athleten gestartet')),
        for (final athlete in waiting) _StartRow(athlete: athlete, autoStartEnabled: _autoStartEnabled, onStart: () => _manualStart(athlete)),
      ])),
      _Section(title: 'Unterwegs', subtitle: 'letzter bekannter Stand', child: Column(children: [
        if (running.isEmpty) const ListTile(title: Text('Noch niemand unterwegs')),
        for (final athlete in running) ListTile(leading: _Bib(bib: athlete.bib), title: Text(athlete.name.toUpperCase()), subtitle: Text('${athlete.category} · ${_lastStand(athlete)}'), trailing: const Text('läuft')),
      ])),
      _Section(title: 'Zuletzt im Ziel', subtitle: 'Laufzeit · Platz · Rückstand', child: Column(children: [
        if (finished.isEmpty) const ListTile(title: Text('Noch keine Zielzeit')),
        for (final athlete in finished) ListTile(leading: _Bib(bib: athlete.bib), title: Text(athlete.name.toUpperCase()), subtitle: Text(athlete.category), trailing: Text(_finishSummary(athlete))),
      ])),
    ]);
  }

  Widget _capturePage() {
    final event = _event;
    if (event == null) return const Center(child: Text('Kein Bewerb geladen'));
    return ListView(padding: const EdgeInsets.all(12), children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: OutlinedButton.icon(
          onPressed: _addSplitPointFromCapture,
          icon: const Icon(Icons.add_location_alt),
          label: const Text('Messpunkt hinzufügen'),
        ),
      ),
      for (final point in event.points)
        _Section(title: point.name, subtitle: point.type == PointType.finish ? 'Ziel · Prognose lernt nach ersten Durchgängen' : 'Messpunkt · Prognose lernt nach ersten Durchgängen', child: Column(children: [
          if (_candidatesFor(point).isEmpty) const ListTile(title: Text('Keine Athleten erwartet')),
          for (final c in _candidatesFor(point)) _CaptureRow(candidate: c, etaText: _eta(c.predictedTime), liveGapText: _liveGapText(c.athlete, point), onTap: () => _capture(c.athlete, point)),
        ])),
    ]);
  }

  Widget _resultsPage() {
    final event = _event;
    if (event == null) return const Center(child: Text('Kein Bewerb geladen'));
    return Column(children: [
      if (_viewingArchivedEvent) const ListTile(title: Text('Archivansicht'), subtitle: Text('Dieser Bewerb ist schreibgeschützt.')),
      SwitchListTile(title: const Text('Altersklassen getrennt anzeigen'), value: event.compareByCategory, onChanged: (v) => setState(() {
        event.compareByCategory = v;
        _compareByCategory = v;
      })),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(onPressed: () => _exportDialog('CSV Export', _csvExport()), icon: const Icon(Icons.table_chart), label: const Text('CSV')),
        OutlinedButton.icon(onPressed: () => _exportDialog('HTML Export', _htmlExport()), icon: const Icon(Icons.html), label: const Text('HTML')),
          OutlinedButton.icon(onPressed: () => _exportDialog('CoachSplit Share', _shareText()), icon: const Icon(Icons.ios_share), label: const Text('Share')),
        OutlinedButton.icon(onPressed: _exportPngImage, icon: const Icon(Icons.image), label: const Text('Bild-Export')),
        OutlinedButton.icon(onPressed: _archiveCurrentEvent, icon: const Icon(Icons.archive), label: const Text('Archivieren')),
      ])),
      const SizedBox(height: 8),
      Expanded(child: DefaultTabController(length: event.points.length, child: Column(children: [
        TabBar(isScrollable: true, tabs: [for (final p in event.points) Tab(text: p.name)]),
        Expanded(child: TabBarView(children: [for (final p in event.points) _Results(point: p, rows: _ranking(p), compareByCategory: event.compareByCategory, fmt: _fmtDuration)])),
      ]))),
    ]);
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.event});
  final RaceEvent? event;

  String _formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final athletes = event?.athletes ?? [];
    final waiting = athletes.where((a) => a.status == AthleteStatus.waiting).length;
    final running = athletes.where((a) => a.status == AthleteStatus.running).length;
    final finished = athletes.where((a) => a.status == AthleteStatus.finished).length;
    return Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: Row(children: [
      Expanded(child: _Stat(label: 'warten', value: '$waiting')),
      const SizedBox(width: 8),
      Expanded(child: _Stat(label: 'unterwegs', value: '$running')),
      const SizedBox(width: 8),
      Expanded(child: _Stat(label: 'fertig', value: '$finished')),
    ]));
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(children: [Text(value, style: Theme.of(context).textTheme.titleLarge), Text(label, style: Theme.of(context).textTheme.labelSmall)])));
}


class CoachSplitLogo extends StatelessWidget {
  const CoachSplitLogo({super.key, this.size = 34, this.showText = false});

  final double size;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF07121F),
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: const Color(0xFF2F8CFF), width: max(1.0, size * 0.055)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.timer_outlined, color: const Color(0xFF2F8CFF), size: size * 0.62),
          Positioned(
            bottom: size * 0.15,
            child: Text(
              'CS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.28,
                letterSpacing: -1,
              ),
            ),
          ),
        ],
      ),
    );

    if (!showText) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 10),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
            children: [
              TextSpan(text: 'Coach'),
              TextSpan(text: 'Split', style: TextStyle(color: Color(0xFF2F8CFF))),
            ],
          ),
        ),
      ],
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav({required this.selected, required this.onChanged});
  final int selected;
  final ValueChanged<int> onChanged;

  String _formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final items = const [(Icons.settings, 'Setup'), (Icons.play_arrow, 'Start'), (Icons.touch_app, 'Erfassen'), (Icons.leaderboard, 'Ergebnis')];
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: SegmentedButton<int>(segments: [for (var i = 0; i < items.length; i++) ButtonSegment(value: i, icon: Icon(items[i].$1, size: 18), label: Text(items[i].$2))], selected: {selected}, onSelectionChanged: (s) => onChanged(s.first)));
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium), Text(subtitle, style: Theme.of(context).textTheme.bodySmall), const Divider(), child])));
}

class _AthletePreview extends StatelessWidget {
  const _AthletePreview({required this.event, required this.onEditStart, required this.onRemove});
  final RaceEvent? event;
  final Future<void> Function(Athlete athlete) onEditStart;
  final void Function(Athlete athlete) onRemove;

  String _formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final athletes = event?.athletes ?? [];
    if (athletes.isEmpty) return const Text('Keine Athleten geladen');
    return Column(children: [for (final a in athletes) ListTile(dense: true, leading: _Bib(bib: a.bib), title: Text(a.name), subtitle: Text('${a.category} · Start ${_clock(a.scheduledStart)}'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.edit), onPressed: () => onEditStart(a)),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => onRemove(a)),
          ]))]);
  }
  String _clock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}

class _StartRow extends StatelessWidget {
  const _StartRow({
    required this.athlete,
    required this.autoStartEnabled,
    required this.onStart,
  });

  final Athlete athlete;
  final bool autoStartEnabled;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final diff = athlete.scheduledStart.difference(DateTime.now());
    final late = diff.isNegative;

    return Card(
      child: ListTile(
        dense: true,
        leading: _Bib(bib: athlete.bib),
        title: Text(
          athlete.name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(athlete.category),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (autoStartEnabled) ...[
              Text(
                late ? '+${_countdown(diff.abs())}' : _countdown(diff),
                style: TextStyle(
                  color: late ? Colors.redAccent : Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
            ],
            FilledButton(
              onPressed: onStart,
              child: const Text('START'),
            ),
          ],
        ),
      ),
    );
  }

  String _countdown(Duration d) {
    final totalSeconds = d.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _CaptureRow extends StatelessWidget {
  const _CaptureRow({
    required this.candidate,
    required this.etaText,
    required this.liveGapText,
    required this.onTap,
  });

  final Candidate candidate;
  final String etaText;
  final String liveGapText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasEta = candidate.predictedTime != null;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              _Bib(bib: candidate.athlete.bib, large: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.athlete.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${candidate.athlete.category}${candidate.athlete.isOwn ? ' · ★' : ''} · ${hasEta ? etaText : '—'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                liveGapText,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.point, required this.rows, required this.compareByCategory, required this.fmt});
  final SplitPoint point;
  final List<RankRow> rows;
  final bool compareByCategory;
  final String Function(Duration) fmt;

  String _formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Center(child: Text('Noch keine Zeiten erfasst'));
    final groups = <String, List<RankRow>>{};
    for (final row in rows) {
      final key = compareByCategory ? row.athlete.category : 'ALLE';
      groups.putIfAbsent(key, () => []).add(row);
    }
    return ListView(padding: const EdgeInsets.all(12), children: [for (final entry in groups.entries) _Section(title: entry.key, subtitle: point.type == PointType.finish ? 'Zielwertung' : 'Gesamtzeit + letzter Abschnitt', child: Column(children: [for (final row in entry.value) ListTile(leading: _Bib(bib: row.athlete.bib), title: Text(row.athlete.name), subtitle: Text(point.type == PointType.finish ? '${row.athlete.category} · Zeit ${fmt(row.elapsed)}' : '${row.athlete.category} · Gesamt ${fmt(row.elapsed)} · Abschnitt ${row.sectionElapsed == null ? '—' : '${fmt(row.sectionElapsed!)} (${row.sectionPlace ?? row.place})'}'), trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text('Pl ${row.place}'), Text('+${fmt(row.deltaToLeader)}')]))]))]);
  }
}

class _Bib extends StatelessWidget {
  const _Bib({required this.bib, this.large = false});
  final int bib;
  final bool large;
  @override
  Widget build(BuildContext context) => CircleAvatar(radius: large ? 23 : 20, backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Text('$bib', style: TextStyle(fontWeight: FontWeight.w900, fontSize: large ? 18 : 15)));
}
