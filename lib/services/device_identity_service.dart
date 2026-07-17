import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

abstract interface class DeviceIdentityStore {
  Future<String?> read();
  Future<void> write(String deviceId);
}

class SharedPreferencesDeviceIdentityStore implements DeviceIdentityStore {
  static const _key = 'coachsplit.device_id.v1';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String deviceId) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      _key,
      deviceId,
    );
    if (!saved) throw StateError('Geräte-ID konnte nicht gespeichert werden.');
  }
}

class DeviceIdentityService {
  DeviceIdentityService({DeviceIdentityStore? store, Uuid? uuid})
      : _store = store ?? SharedPreferencesDeviceIdentityStore(),
        _uuid = uuid ?? const Uuid();

  final DeviceIdentityStore _store;
  final Uuid _uuid;
  Future<String>? _resolved;

  Future<String> getOrCreate() => _resolved ??= _loadOrCreate();

  Future<String> _loadOrCreate() async {
    final existing = await _store.read();
    if (existing != null && existing.trim().isNotEmpty) return existing;
    final created = _uuid.v7();
    await _store.write(created);
    return created;
  }
}
