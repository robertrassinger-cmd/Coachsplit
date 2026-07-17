import 'package:flutter_test/flutter_test.dart';
import 'package:coachsplit/services/device_identity_service.dart';

class MemoryDeviceIdentityStore implements DeviceIdentityStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String deviceId) async => value = deviceId;
}

void main() {
  test('device id is created once and remains stable', () async {
    final store = MemoryDeviceIdentityStore();
    final first = DeviceIdentityService(store: store);
    final id = await first.getOrCreate();
    final second = DeviceIdentityService(store: store);
    expect(await second.getOrCreate(), id);
    expect(id, isNotEmpty);
  });
}
