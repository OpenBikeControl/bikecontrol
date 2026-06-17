import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_left_side.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_right_side.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

BleDevice _clickV2(int sideCode) => BleDevice(
  deviceId: 'click-$sideCode',
  name: 'Zwift Click',
  manufacturerDataList: [
    ManufacturerData(ZwiftConstants.ZWIFT_MANUFACTURER_ID, Uint8List.fromList([sideCode])),
  ],
  services: [ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID.toLowerCase()],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('getUseNewUnlockMethod persistence', () {
    late Settings settings;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = Settings();
      settings.prefs = await SharedPreferences.getInstance();
    });

    test('defaults to on', () {
      expect(settings.getUseNewUnlockMethod(), isTrue);
    });

    test('round-trips', () async {
      await settings.setUseNewUnlockMethod(false);
      expect(settings.getUseNewUnlockMethod(), isFalse);

      await settings.setUseNewUnlockMethod(true);
      expect(settings.getUseNewUnlockMethod(), isTrue);
    });

    test('returns the default when prefs are not initialised', () {
      // A Settings whose prefs were never assigned (e.g. device detection in a
      // pure unit test) must not throw and should fall back to the default.
      expect(Settings().getUseNewUnlockMethod(), isTrue);
    });
  });

  group('Click V2 factory honours the unlock method toggle', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      core.actionHandler = StubActions();
      core.settings.prefs = await SharedPreferences.getInstance();
    });

    test('new method on: left/right connect as separate controllers (no Pro gate)', () async {
      await core.settings.setUseNewUnlockMethod(true);

      expect(
        BluetoothDevice.fromScanResult(_clickV2(ZwiftConstants.CLICK_V2_LEFT_SIDE)),
        isA<ZwiftClickV2LeftSide>(),
      );
      expect(
        BluetoothDevice.fromScanResult(_clickV2(ZwiftConstants.CLICK_V2_RIGHT_SIDE)),
        isA<ZwiftClickV2RightSide>(),
      );
    });

    test('new method off: falls back to the legacy single controller', () async {
      await core.settings.setUseNewUnlockMethod(false);

      final left = BluetoothDevice.fromScanResult(_clickV2(ZwiftConstants.CLICK_V2_LEFT_SIDE));
      expect(left, isA<ZwiftClickV2>());
      expect(left, isNot(isA<ZwiftClickV2LeftSide>()));

      expect(BluetoothDevice.fromScanResult(_clickV2(ZwiftConstants.CLICK_V2_RIGHT_SIDE)), isNull);
    });
  });
}
