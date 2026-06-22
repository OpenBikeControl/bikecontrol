import 'dart:typed_data';

import 'package:bike_control/services/mdns_discovery_scan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsd/nsd.dart' as nsd;

void main() {
  test('fromService decodes txt, carries host/port and self flag', () {
    final service = nsd.Service(
      name: 'KICKR ABCD',
      type: '_wahoo-fitness-tnp._tcp',
      port: 36866,
      txt: {
        'serial-number': Uint8List.fromList('1234'.codeUnits),
        'version': Uint8List.fromList([0x01]),
      },
    );

    final d = DiscoveredMdnsService.fromService(
      service,
      host: '192.168.1.50',
      port: 36866,
      isSelf: false,
    );

    expect(d.name, 'KICKR ABCD');
    expect(d.type, '_wahoo-fitness-tnp._tcp');
    expect(d.host, '192.168.1.50');
    expect(d.port, 36866);
    expect(d.isSelf, isFalse);
    expect(d.txt['serial-number'], '1234');
    expect(d.txt['version'], '0x01');
  });
}
