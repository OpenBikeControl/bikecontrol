// Detecting a Zwift Ride whose firmware is newer than the last supported
// version (>1.2.0 = the server-locked firmware that stops the Ride working
// with third-party apps). The check must tolerate extra version components and
// must NOT fire for ZwiftRide subclasses like the Click v2.
import 'package:bike_control/bluetooth/devices/zwift/firmware_support.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show Locale;
import 'package:universal_ble/universal_ble.dart';

/// A Zwift controller whose "last supported" firmware the test controls, so the
/// beyond-supported branch can be exercised without pinning a real product's
/// version. Nothing here touches BLE: the no-custom-service branch of
/// [ZwiftDevice.handleServices] returns before the first UniversalBle call.
class _FakeZwiftDevice extends ZwiftRide {
  _FakeZwiftDevice({String? firmware, String? latest = '1.2.0'})
    : _latest = latest,
      super(BleDevice(deviceId: 'fake-zwift', name: 'Zwift Ride')) {
    firmwareVersion = firmware;
  }

  final String? _latest;

  @override
  String? get latestFirmwareVersion => _latest;
}

/// Runs [ZwiftDevice.handleServices] with a service list that has no Zwift
/// custom service (what a server-locked Ride actually exposes) and collects the
/// alerts it emitted before bailing out.
Future<List<AlertNotification>> _alertsFromServiceless(ZwiftDevice device) async {
  final alerts = <AlertNotification>[];
  final sub = device.actionStream.where((n) => n is AlertNotification).cast<AlertNotification>().listen(alerts.add);
  await expectLater(device.handleServices(const <BleService>[]), throwsA(isA<Exception>()));
  await pumpEventQueue();
  await sub.cancel();
  return alerts;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isFirmwareBeyondSupported', () {
    test('firmware equal to the supported version is not beyond', () {
      expect(isFirmwareBeyondSupported('1.2.0', '1.2.0'), isFalse);
    });

    test('a patch bump past supported is beyond', () {
      expect(isFirmwareBeyondSupported('1.2.1', '1.2.0'), isTrue);
    });

    test('a minor bump past supported is beyond', () {
      expect(isFirmwareBeyondSupported('1.3.0', '1.2.0'), isTrue);
    });

    test('a fourth build component is ignored: 1.2.0.24 is not beyond 1.2.0', () {
      expect(isFirmwareBeyondSupported('1.2.0.24', '1.2.0'), isFalse);
    });

    test('older firmware is not beyond', () {
      expect(isFirmwareBeyondSupported('1.1.0', '1.2.0'), isFalse);
    });

    test('null, empty or unparseable firmware is never beyond (fail safe)', () {
      expect(isFirmwareBeyondSupported(null, '1.2.0'), isFalse);
      expect(isFirmwareBeyondSupported('', '1.2.0'), isFalse);
      expect(isFirmwareBeyondSupported('unknown', '1.2.0'), isFalse);
    });
  });

  group('handleServices when the Zwift custom service is missing', () {
    setUpAll(() async {
      await AppLocalizations.load(const Locale('en'));
    });

    test('firmware beyond the last supported version points at support, not a firmware update', () async {
      final device = _FakeZwiftDevice(firmware: '1.3.0', latest: '1.2.0');
      final alerts = await _alertsFromServiceless(device);

      expect(alerts, hasLength(1));
      expect(alerts.single.alertMessage, AppLocalizations.current.zwiftRideFirmwareNoticeBody('1.3.0'));
      expect(alerts.single.alertMessage, isNot(AppLocalizations.current.firmwareUpdateRequired(device.name)));
      expect(alerts.single.buttonTitle, isNot(AppLocalizations.current.zwiftCompanionApp));
    });

    test('firmware beyond the last supported version is not blamed on a missing update in the thrown error', () async {
      final device = _FakeZwiftDevice(firmware: '1.3.0', latest: '1.2.0');
      await expectLater(
        device.handleServices(const <BleService>[]),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            isNot(contains('update the firmware')),
          ),
        ),
      );
    });

    test('firmware older than the last supported version still asks for a firmware update', () async {
      final device = _FakeZwiftDevice(firmware: '1.1.0', latest: '1.2.0');
      final alerts = await _alertsFromServiceless(device);

      expect(alerts, hasLength(1));
      expect(alerts.single.alertMessage, AppLocalizations.current.firmwareUpdateRequired(device.name));
      expect(alerts.single.buttonTitle, AppLocalizations.current.zwiftCompanionApp);
    });
  });

  group('ZwiftDevice.hasNewerFirmwareVersion', () {
    test('firmware older than the latest we know offers an update', () {
      expect(_FakeZwiftDevice(firmware: '1.1.0', latest: '1.2.0').hasNewerFirmwareVersion, isTrue);
    });

    test('firmware equal to the latest we know offers no update', () {
      expect(_FakeZwiftDevice(firmware: '1.2.0', latest: '1.2.0').hasNewerFirmwareVersion, isFalse);
    });

    test('firmware beyond the latest we know never offers an update', () {
      expect(_FakeZwiftDevice(firmware: '1.3.0', latest: '1.2.0').hasNewerFirmwareVersion, isFalse);
    });

    test('a fourth build component still compares: 1.2.0.24 is older than 1.3.0', () {
      expect(_FakeZwiftDevice(firmware: '1.2.0.24', latest: '1.3.0').hasNewerFirmwareVersion, isTrue);
    });

    test('a fourth build component beyond the latest we know offers no update: 1.3.0.5 vs 1.2.0', () {
      expect(_FakeZwiftDevice(firmware: '1.3.0.5', latest: '1.2.0').hasNewerFirmwareVersion, isFalse);
    });

    test('missing, empty or unparseable firmware never offers an update (fail safe)', () {
      expect(_FakeZwiftDevice(firmware: null, latest: '1.2.0').hasNewerFirmwareVersion, isFalse);
      expect(_FakeZwiftDevice(firmware: '', latest: '1.2.0').hasNewerFirmwareVersion, isFalse);
      expect(_FakeZwiftDevice(firmware: 'unknown', latest: '1.2.0').hasNewerFirmwareVersion, isFalse);
      expect(_FakeZwiftDevice(firmware: '1.1.0', latest: null).hasNewerFirmwareVersion, isFalse);
    });
  });

  group('ZwiftRide.hasUnsupportedFirmware', () {
    ZwiftRide ride(String? fw) =>
        ZwiftRide(BleDevice(deviceId: 'zr', name: 'Zwift Ride'))..firmwareVersion = fw;

    test('a Ride on firmware past 1.2.0 is flagged', () {
      expect(ZwiftRide.hasUnsupportedFirmware(ride('1.3.0')), isTrue);
    });

    test('a Ride on the last good 1.2.0 is not flagged', () {
      expect(ZwiftRide.hasUnsupportedFirmware(ride('1.2.0')), isFalse);
    });

    test('a Ride with unknown firmware is not flagged', () {
      expect(ZwiftRide.hasUnsupportedFirmware(ride(null)), isFalse);
    });

    test('a Click v2 (ZwiftRide subclass) on 1.3.0 does NOT trigger the Ride prompt', () {
      final clickV2 = ZwiftClickV2(BleDevice(deviceId: 'c2', name: 'Zwift Click'))
        ..firmwareVersion = '1.3.0';
      expect(ZwiftRide.hasUnsupportedFirmware(clickV2), isFalse);
    });
  });
}
