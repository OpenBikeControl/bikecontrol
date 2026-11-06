import 'package:bike_control/bluetooth/scan_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

BleDevice _device({String? name, List<String> services = const ['180f']}) =>
    BleDevice(deviceId: 'onelap', name: name, services: services);

void main() {
  test('accepts the first sighting and a later packet that adds the name', () {
    final unnamed = _device();
    expect(scanResultAddsIdentity(const [], unnamed), isTrue);
    expect(
      scanResultAddsIdentity([unnamed], _device(name: 'Onelap Key_12224')),
      isTrue,
    );
  });

  test('ignores a repeat once the name is known', () {
    final named = _device(name: 'Onelap Key_12224');
    expect(
      scanResultAddsIdentity([named], _device(name: 'Onelap Key_12224')),
      isFalse,
    );
    expect(scanResultAddsIdentity([named], _device()), isFalse);
    expect(
      scanResultAddsIdentity([
        _device(),
        named,
      ], _device(name: 'Onelap Key_12224')),
      isFalse,
    );
  });

  test('a different service list is a new sighting', () {
    expect(
      scanResultAddsIdentity(
        [_device(name: 'Onelap Key_12224')],
        _device(
          name: 'Onelap Key_12224',
          services: const ['180f', '8ce5cc01-0a4d-11e9-ab14-d663bd873d93'],
        ),
      ),
      isTrue,
    );
  });
}
