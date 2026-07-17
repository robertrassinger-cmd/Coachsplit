part of coachsplit;

/// Fachliche Persistenzgrenze für aktive und archivierte Bewerbe.
///
/// Aufrufer kennen weder Sembast noch dessen Store-Struktur. Damit kann die
/// lokale Implementierung später um Synchronisation oder einen anderen
/// Speicher ergänzt werden, ohne die UI zu verändern.
abstract interface class CompetitionRepository {
  Future<CompetitionSnapshot> load();

  /// Speichert oder aktualisiert einen aktiven Bewerb.
  Future<void> saveActive(RaceEvent event);

  /// Verschiebt einen Bewerb atomar in das Archiv und speichert dort einen
  /// vollständigen, unveränderlichen Snapshot.
  Future<void> archive(RaceEvent event);

  /// Entfernt einen Bewerb unabhängig davon, ob er aktiv oder archiviert ist.
  Future<void> delete(String competitionId);

  /// Atomarer Gesamtabgleich. Wird für Migration und bestehende gebündelte
  /// UI-Speichervorgänge beibehalten; neue fachliche Abläufe sollen bevorzugt
  /// die gezielten Methoden verwenden.
  Future<void> replaceAll({
    required Iterable<RaceEvent> activeEvents,
    required Iterable<RaceEvent> archivedEvents,
  });
}

class CompetitionSnapshot {
  const CompetitionSnapshot({
    required this.activeEvents,
    required this.archivedEvents,
  });

  final List<RaceEvent> activeEvents;
  final List<RaceEvent> archivedEvents;

  bool get isEmpty => activeEvents.isEmpty && archivedEvents.isEmpty;
}

class SembastCompetitionRepository implements CompetitionRepository {
  SembastCompetitionRepository({Future<Database> Function()? openDatabase})
      : _openDatabase = openDatabase ?? openCoachSplitDatabase;

  static const int _schemaVersion = 1;
  static const String _activeBucket = 'active';
  static const String _archiveBucket = 'archive';

  final Future<Database> Function() _openDatabase;
  final StoreRef<String, Map<String, Object?>> _store =
      stringMapStoreFactory.store('competitions');
  Future<Database>? _database;

  Future<Database> get _db => _database ??= _openDatabase();

  @override
  Future<CompetitionSnapshot> load() async {
    final db = await _db;
    final records = await _store.find(db);
    final active = <RaceEvent>[];
    final archived = <RaceEvent>[];

    for (final record in records) {
      final value = record.value;
      final schemaVersion = value['schemaVersion'];
      if (schemaVersion != _schemaVersion) {
        throw FormatException(
          'Bewerbsdatensatz ${record.key}: unbekannte Schema-Version $schemaVersion.',
        );
      }
      final rawEvent = value['event'];
      if (rawEvent is! Map) {
        throw FormatException(
          'Beschädigter Bewerbsdatensatz ${record.key}: Event fehlt.',
        );
      }
      final event = RaceEvent.fromJson(Map<String, dynamic>.from(rawEvent));
      if (event.id != record.key) {
        throw FormatException(
          'Beschädigter Bewerbsdatensatz ${record.key}: ID stimmt nicht überein.',
        );
      }
      final bucket = value['bucket'];
      if (bucket == _archiveBucket) {
        archived.add(event);
      } else if (bucket == _activeBucket) {
        active.add(event);
      } else {
        throw FormatException(
          'Beschädigter Bewerbsdatensatz ${record.key}: unbekannter Bereich.',
        );
      }
    }

    active.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    archived.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return CompetitionSnapshot(
      activeEvents: active,
      archivedEvents: archived,
    );
  }

  @override
  Future<void> saveActive(RaceEvent event) async {
    _validateEvent(event);
    final db = await _db;
    await db.transaction((transaction) async {
      await _store.record(event.id).put(
        transaction,
        _recordFor(event, bucket: _activeBucket),
      );
    });
  }

  @override
  Future<void> archive(RaceEvent event) async {
    _validateEvent(event);
    final archivedCopy = RaceEvent.fromJson(event.toJson())
      ..status = CompetitionStatus.archived;
    final db = await _db;
    await db.transaction((transaction) async {
      await _store.record(event.id).put(
        transaction,
        _recordFor(archivedCopy, bucket: _archiveBucket),
      );
    });
  }

  @override
  Future<void> delete(String competitionId) async {
    if (competitionId.trim().isEmpty) {
      throw ArgumentError('Zum Löschen wird eine Bewerbs-ID benötigt.');
    }
    final db = await _db;
    await db.transaction((transaction) async {
      await _store.record(competitionId).delete(transaction);
    });
  }

  @override
  Future<void> replaceAll({
    required Iterable<RaceEvent> activeEvents,
    required Iterable<RaceEvent> archivedEvents,
  }) async {
    final active = activeEvents.toList(growable: false);
    final archived = archivedEvents.toList(growable: false);
    final ids = <String>{};
    for (final event in [...active, ...archived]) {
      _validateEvent(event);
      if (!ids.add(event.id)) {
        throw StateError('Bewerbs-ID ${event.id} ist mehrfach vorhanden.');
      }
    }

    final db = await _db;
    await db.transaction((transaction) async {
      await _store.drop(transaction);
      for (final event in active) {
        await _store.record(event.id).put(
          transaction,
          _recordFor(event, bucket: _activeBucket),
        );
      }
      for (final event in archived) {
        await _store.record(event.id).put(
          transaction,
          _recordFor(event, bucket: _archiveBucket),
        );
      }
    });
  }

  Map<String, Object?> _recordFor(
    RaceEvent event, {
    required String bucket,
  }) {
    return {
      'bucket': bucket,
      'schemaVersion': _schemaVersion,
      'event': bucket == _archiveBucket
          ? RaceEvent.fromJson(event.toJson()).toJson()
          : _eventMetadataJsonForStorage(event),
    };
  }

  static void _validateEvent(RaceEvent event) {
    if (event.id.trim().isEmpty) {
      throw ArgumentError('Bewerbe benötigen eine stabile ID.');
    }
  }

  static Map<String, dynamic> _eventMetadataJsonForStorage(RaceEvent event) {
    final json = RaceEvent.fromJson(event.toJson()).toJson();
    final athletes = json['athletes'] as List<dynamic>;
    for (final raw in athletes) {
      final athlete = raw as Map<String, dynamic>;
      athlete['captures'] = <String, String>{};
      athlete['shootingResults'] = <String, dynamic>{};
    }
    return json;
  }
}

// Übergangs-Aliase für bestehende Tests und Integrationen. Neue Aufrufer sollen
// ausschließlich die vereinheitlichten Namen verwenden.
typedef LocalCompetitionRepository = CompetitionRepository;
typedef LocalCompetitionSnapshot = CompetitionSnapshot;
typedef SembastLocalCompetitionRepository = SembastCompetitionRepository;
