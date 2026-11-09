import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/dircon_emulator.dart' show RetrofitMode;

/// The name the UI tells a rider to pick in their trainer app. Windows can't
/// name a Bluetooth advertisement, so a phone lists the PC under its own name;
/// pointing the rider at `<trainer> - BikeControl` sent them looking for an
/// entry that never appears (GH #451).
void main() {
  const advertised = 'KICKR CORE AF81 - BikeControl';

  test('on Windows over Bluetooth it is the computer name', () {
    expect(
      ProxyDevice.listedNameFor(
        advertised: advertised,
        mode: RetrofitMode.bluetooth,
        isWindows: true,
        computerName: 'JONO-LAPTOP',
      ),
      'JONO-LAPTOP',
    );
  });

  test('on Windows over WiFi the advertised name holds', () {
    expect(
      ProxyDevice.listedNameFor(
        advertised: advertised,
        mode: RetrofitMode.wifi,
        isWindows: true,
        computerName: 'JONO-LAPTOP',
      ),
      advertised,
    );
  });

  test('off Windows Bluetooth advertises the name itself', () {
    expect(
      ProxyDevice.listedNameFor(
        advertised: advertised,
        mode: RetrofitMode.bluetooth,
        isWindows: false,
        computerName: 'MacBook',
      ),
      advertised,
    );
  });

  test('falls back to the advertised name when the computer name is unknown', () {
    for (final name in [null, '', '  ']) {
      expect(
        ProxyDevice.listedNameFor(
          advertised: advertised,
          mode: RetrofitMode.bluetooth,
          isWindows: true,
          computerName: name,
        ),
        advertised,
        reason: 'computer name "$name"',
      );
    }
  });
}
