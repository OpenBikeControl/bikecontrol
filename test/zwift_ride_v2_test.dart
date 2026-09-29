// A Zwift Ride that reports firmware 1.3 or newer is a "Zwift Ride V2": Zwift
// locks it to its own app, and it is unlocked the same way as a Click V2 —
// through Zwift, for about 24 hours at a time.
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_left_side.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_right_side.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_play_fw2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_unlock.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/support/intake_options.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show Locale;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

ZwiftRide _ride(String? firmware, {String id = 'ride-1'}) =>
    ZwiftRide(BleDevice(deviceId: id, name: 'Zwift Ride'))..firmwareVersion = firmware;

BleDevice _clickV2Scan(int sideCode) => BleDevice(
  deviceId: 'click-$sideCode',
  name: 'Zwift Click',
  manufacturerDataList: [
    ManufacturerData(ZwiftConstants.ZWIFT_MANUFACTURER_ID, Uint8List.fromList([sideCode])),
  ],
  services: [ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID.toLowerCase()],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.actionHandler = StubActions();
    core.settings.prefs = await SharedPreferences.getInstance();
    propPrefs.initialize(core.settings.prefs);
    await AppLocalizations.load(const Locale('en'));
  });

  group('Zwift Ride V2 classification', () {
    test('firmware 1.3.0 is a Ride V2', () => expect(_ride('1.3.0').isRideV2, isTrue));
    test('firmware 1.3 is a Ride V2', () => expect(_ride('1.3').isRideV2, isTrue));
    test('firmware 1.4.2 is a Ride V2', () => expect(_ride('1.4.2').isRideV2, isTrue));
    test('firmware 1.2.0 is not', () => expect(_ride('1.2.0').isRideV2, isFalse));
    test('firmware 1.2.0.24 is not', () => expect(_ride('1.2.0.24').isRideV2, isFalse));
    test('unparseable firmware is not', () => expect(_ride('garbage').isRideV2, isFalse));
    test('unknown firmware is not', () => expect(_ride(null).isRideV2, isFalse));

    test('a Ride that later reports 1.2.x is a V1 again — nothing sticks', () {
      final ride = _ride('1.3.0');
      expect(ride.isRideV2, isTrue);
      ride.firmwareVersion = '1.2.0';
      expect(ride.isRideV2, isFalse);
    });

    test('Zwift Ride subclasses on 1.3 firmware are not a Ride V2', () {
      final clickV2 = ZwiftClickV2(BleDevice(deviceId: 'c2', name: 'Zwift Click'))..firmwareVersion = '1.3.0';
      final playFw2 = ZwiftPlayFw2(BleDevice(deviceId: 'p2', name: 'Zwift Play'))..firmwareVersion = '1.3.0';
      final right = ZwiftClickV2RightSide(BleDevice(deviceId: 'r2', name: 'Zwift Click'))..firmwareVersion = '1.3.0';
      expect(clickV2.isRideV2, isFalse);
      expect(playFw2.isRideV2, isFalse);
      expect(right.isRideV2, isFalse);
    });

    test('once known, a Ride V2 is called "Zwift Ride V2"', () {
      expect(_ride('1.3.0').toString(), 'Zwift Ride V2');
      expect(_ride('1.2.0').toString(), 'Zwift Ride');
      expect(_ride(null).toString(), 'Zwift Ride');
    });

    test('the pinned latest firmware stays 1.2.0', () {
      expect(_ride('1.3.0').latestFirmwareVersion, '1.2.0');
    });

    test('the old firmware notice no longer fires for a Ride V2', () {
      expect(ZwiftRide.hasUnsupportedFirmware(_ride('1.3.0')), isFalse);
    });

    test('the old firmware notice stays as the fallback for a Ride past 1.2.0 that is not a V2', () {
      expect(ZwiftRide.hasUnsupportedFirmware(_ride('1.2.5')), isTrue);
    });
  });

  group('requiresZwiftUnlock', () {
    test('a Ride V2 requires the Zwift unlock', () {
      expect(_ride('1.3.0').requiresZwiftUnlock, isTrue);
    });

    test('a Ride V1, or one whose firmware is not known yet, does not', () {
      expect(_ride('1.2.0').requiresZwiftUnlock, isFalse);
      expect(_ride(null).requiresZwiftUnlock, isFalse);
      expect(_ride('garbage').requiresZwiftUnlock, isFalse);
    });

    test('the legacy unified Click V2 always does', () {
      expect(ZwiftClickV2(BleDevice(deviceId: 'c2', name: 'Zwift Click')).requiresZwiftUnlock, isTrue);
    });

    test('the Click V2 left puck only in unlock-with-Zwift mode', () async {
      await core.settings.setUseNewUnlockMethod(true);
      final left = BluetoothDevice.fromScanResult(_clickV2Scan(ZwiftConstants.CLICK_V2_LEFT_SIDE));
      expect(left, isA<ZwiftClickV2LeftSide>());
      await core.settings.setUnlockWithZwift(true);
      expect((left as ZwiftUnlock).requiresZwiftUnlock, isTrue);
      await core.settings.setUnlockWithZwift(false);
      expect(left.requiresZwiftUnlock, isFalse);
    });

    test('the Click V2 right puck and a Play on firmware 2 never do', () {
      expect(ZwiftClickV2RightSide(BleDevice(deviceId: 'r2', name: 'Zwift Click')).requiresZwiftUnlock, isFalse);
      expect(ZwiftPlayFw2(BleDevice(deviceId: 'p2', name: 'Zwift Play')).requiresZwiftUnlock, isFalse);
    });

    test('Ride V2 never offers the Click V2 unlock modes', () {
      final ride = _ride('1.3.0');
      expect(ride.offersUnlockModes, isFalse);
      expect(ZwiftClickV2(BleDevice(deviceId: 'c2', name: 'Zwift Click')).offersUnlockModes, isTrue);
    });
  });

  group('Ride V2 unlock persistence', () {
    test('keeps its own 24-hour timestamp, separate from a Click V2', () {
      final ride = _ride('1.3.0');
      final click = ZwiftClickV2(BleDevice(deviceId: 'ride-1', name: 'Zwift Click'));
      expect(ride.unlockKeyPrefix, isNot(click.unlockKeyPrefix));

      // A Click V2 unlock stored under the same id does not unlock the Ride.
      propPrefs.setZwiftClickV2LastUnlock('ride-1', DateTime.now());
      expect(click.isPersistedUnlocked, isTrue);
      expect(ride.isPersistedUnlocked, isFalse);

      propPrefs.setZwiftClickV2LastUnlock('ride-1', DateTime.now(), keyPrefix: ride.unlockKeyPrefix);
      expect(ride.isPersistedUnlocked, isTrue);
      expect(ride.unlockedUntil, isNotNull);
    });

    test('marking a Ride V2 unlocked by hand writes its own key', () {
      final ride = _ride('1.3.0');
      ride.markUnlockedManually();
      expect(propPrefs.getZwiftClickV2LastUnlock('ride-1', keyPrefix: ride.unlockKeyPrefix), isNotNull);
      expect(propPrefs.getZwiftClickV2LastUnlock('ride-1'), isNull);
      expect(ride.isLikelyUnlocked, isTrue);
    });

    test('an unlock older than a day has run out', () {
      final ride = _ride('1.3.0');
      propPrefs.setZwiftClickV2LastUnlock(
        'ride-1',
        DateTime.now().subtract(const Duration(hours: 25)),
        keyPrefix: ride.unlockKeyPrefix,
      );
      expect(ride.isPersistedUnlocked, isFalse);
    });
  });

  group('a locked Ride V2 hiding the Zwift service', () {
    test('connects without throwing and reports itself locked', () async {
      final ride = _ride('1.3.0');
      final logs = <BaseNotification>[];
      final sub = ride.actionStream.listen(logs.add);
      propPrefs.setZwiftClickV2LastUnlock('ride-1', DateTime.now(), keyPrefix: ride.unlockKeyPrefix);

      await ride.handleServices(const <BleService>[]);
      await pumpEventQueue();
      await sub.cancel();

      expect(ride.unlockServiceHidden, isTrue);
      // Hidden means locked, whatever the stored timestamp says.
      expect(ride.isPersistedUnlocked, isFalse);
      // Not the old "firmware may not work" alert.
      expect(
        logs.whereType<AlertNotification>().where(
          (a) => a.alertMessage == AppLocalizations.current.zwiftRideFirmwareNoticeBody('1.3.0'),
        ),
        isEmpty,
      );
    });

    test('a Ride V1 without the service still fails as before', () async {
      final ride = _ride('1.1.0');
      await expectLater(ride.handleServices(const <BleService>[]), throwsA(isA<Exception>()));
    });
  });

  group('support intake', () {
    test('a Ride V2 maps to its own controller option', () {
      expect(controllerOptionIdFor(_ride('1.3.0')), 'zwift_ride_v2');
      expect(controllerOptionIdFor(_ride('1.2.0')), 'zwift_ride');
      expect(controllerOptions.map((o) => o.id), contains('zwift_ride_v2'));
    });

    test('the Ride V2 lock intake carries the firmware version', () {
      final answers = rideV2LockIntake(_ride('1.3.0.7'));
      expect(answers.category, IntakeCategory.controller);
      expect(answers.subcategoryValue, 'zwift_ride_v2');
      expect(answers.symptom, 'zwift_ride_v2_lock');
      expect(answers.firmware, '1.3.0.7');
      expect(answers.toJson()['firmware'], '1.3.0.7');
    });

    test('the lock symptom is offered for a Ride V2 only', () {
      expect(controllerSymptomsFor('zwift_ride_v2').map((s) => s.id), contains('zwift_ride_v2_lock'));
      expect(controllerSymptomsFor('zwift_ride').map((s) => s.id), isNot(contains('zwift_ride_v2_lock')));
      expect(controllerSymptomsFor(null).map((s) => s.id), isNot(contains('zwift_ride_v2_lock')));
    });
  });
}
