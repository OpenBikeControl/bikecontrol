import 'dart:io';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/wifi_trainer_scanner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsd/nsd.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/utils/constants.dart';
import 'package:prop/utils/self_advertisement_registry.dart';

void main() {
  setUp(() => SelfAdvertisementRegistry.instance.clear());

  group('isSelfAdvertisement', () {
    test('excludes a service whose name we registered (Zwift Hub / Rouvy case)', () {
      SelfAdvertisementRegistry.instance.add(name: 'Zwift Hub', port: 36868);
      final service = Service(name: 'Zwift Hub', type: '_wahoo-fitness-tnp._tcp', port: 36868,
          addresses: [InternetAddress('192.168.1.50')]);
      expect(WifiTrainerScanner.isSelfAdvertisement(service, localAddresses: {'192.168.1.10'}), isTrue);
    });

    test('excludes a service carrying our TXT fingerprint (other BikeControl on LAN)', () {
      final service = Service(name: 'KICKR - BikeControl', type: '_wahoo-fitness-tnp._tcp', port: 36870,
          addresses: [InternetAddress('192.168.1.99')],
          txt: {'mac-address': Uint8List.fromList(BikeControlMdnsMarkers.macAddress.codeUnits)});
      expect(WifiTrainerScanner.isSelfAdvertisement(service, localAddresses: {'192.168.1.10'}), isTrue);
    });

    test('excludes a service resolving to our own address on a registered port', () {
      SelfAdvertisementRegistry.instance.add(name: 'Some Other Name', port: 36868);
      final service = Service(name: 'Renamed Mid-Restart', type: '_wahoo-fitness-tnp._tcp', port: 36868,
          addresses: [InternetAddress('192.168.1.10')]);
      expect(WifiTrainerScanner.isSelfAdvertisement(service, localAddresses: {'192.168.1.10'}), isTrue);
    });

    test('passes a legitimate trainer through', () {
      final service = Service(name: 'KICKR CORE 1A2B', type: '_wahoo-fitness-tnp._tcp', port: 36866,
          addresses: [InternetAddress('192.168.1.50')],
          txt: {'ble-service-uuids': Uint8List.fromList('1826'.codeUnits)});
      expect(WifiTrainerScanner.isSelfAdvertisement(service, localAddresses: {'192.168.1.10'}), isFalse);
    });
  });

  group('syntheticDeviceFor', () {
    test('builds a stable id and normalized service uuids from TXT', () {
      final service = Service(name: 'KICKR CORE 1A2B', type: '_wahoo-fitness-tnp._tcp', port: 36866,
          txt: {'ble-service-uuids': Uint8List.fromList('1826,1818'.codeUnits)});
      final device = WifiTrainerScanner.syntheticDeviceFor(service);
      expect(device.deviceId, 'dircon://KICKR CORE 1A2B');
      expect(device.name, 'KICKR CORE 1A2B');
      expect(device.services, [
        '00001826-0000-1000-8000-00805f9b34fb',
        '00001818-0000-1000-8000-00805f9b34fb',
      ]);
    });

    test('keeps long-form uuids as-is (lowercased)', () {
      final service = Service(name: 'T', type: '_wahoo-fitness-tnp._tcp', port: 1,
          txt: {'ble-service-uuids': Uint8List.fromList('00001826-0000-1000-8000-00805F9B34FB'.codeUnits)});
      expect(WifiTrainerScanner.syntheticDeviceFor(service).services,
          ['00001826-0000-1000-8000-00805f9b34fb']);
    });

    test('falls back to FTMS when the TXT record is missing', () {
      final service = Service(name: 'Mystery Trainer', type: '_wahoo-fitness-tnp._tcp', port: 1);
      expect(WifiTrainerScanner.syntheticDeviceFor(service).services,
          [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID.toLowerCase()]);
    });
  });

  group('handleService', () {
    test('found service reaches onFound with host/port; lost triggers onLost', () async {
      final found = <WifiTrainer>[];
      final lost = <String>[];
      final scanner = WifiTrainerScanner(onFound: found.add, onLost: lost.add);

      final service = Service(name: 'KICKR CORE 1A2B', type: '_wahoo-fitness-tnp._tcp', port: 36866,
          addresses: [InternetAddress('192.168.1.50')],
          txt: {'ble-service-uuids': Uint8List.fromList('1826'.codeUnits)});

      scanner.handleService(service, ServiceStatus.found);
      expect(found.single.host, '192.168.1.50');
      expect(found.single.port, 36866);
      expect(found.single.syntheticDevice.deviceId, 'dircon://KICKR CORE 1A2B');

      scanner.handleService(service, ServiceStatus.lost);
      expect(lost.single, 'dircon://KICKR CORE 1A2B');
    });
  });
}
