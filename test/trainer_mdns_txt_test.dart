import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/tacx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/prop.dart';

void main() {
  String txt(Map<String, Uint8List> map, String key) => String.fromCharCodes(map[key]!);

  test('every trainer advertisement carries mac-address and serial-number', () {
    // Tacx keys discovered peripherals on mac-address and bails on a scan
    // result without one; Rouvy keys its device map on the same field.
    final map = ProxyDevice.trainerMdnsTxtFor(Rouvy(), serialNumber: '123456789');
    expect(txt(map, 'mac-address'), BikeControlMdnsMarkers.macAddress);
    expect(txt(map, 'serial-number'), '123456789');
  });

  test('16-bit service UUIDs go bare only for Tacx', () {
    // Rouvy parses '0x1826' and silently drops a bare '1826' — its device
    // list then has no FTMS service for the bridge; Tacx does the opposite.
    expect(ProxyDevice.bareShortServiceUuidsFor(Tacx()), isTrue);
    expect(ProxyDevice.bareShortServiceUuidsFor(Rouvy()), isFalse);
    expect(ProxyDevice.bareShortServiceUuidsFor(null), isFalse);
  });

  test('the IPv4-only listener follows Rouvy, and only Rouvy', () {
    expect(ProxyDevice.needsIPv4For(Rouvy()), isTrue);
    expect(ProxyDevice.needsIPv4For(Tacx()), isFalse);
    expect(ProxyDevice.needsIPv4For(null), isFalse);
  });

  test('Tacx adds the Garmin product-id, other apps leave the record alone', () {
    final forTacx = ProxyDevice.trainerMdnsTxtFor(Tacx(), serialNumber: '1');
    expect(txt(forTacx, 'product-id'), Tacx.mdnsProductId);

    for (final app in [Rouvy(), null]) {
      final map = ProxyDevice.trainerMdnsTxtFor(app, serialNumber: '1');
      expect(map.keys, unorderedEquals(['mac-address', 'serial-number']));
    }
  });
}
