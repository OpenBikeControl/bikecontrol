import 'package:flutter/material.dart' as ma;
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/core.dart' show core;
import 'package:swift_control/utils/keymap/apps/my_whoosh.dart';
import 'package:swift_control/utils/requirements/multi.dart';
import 'package:universal_ble/universal_ble.dart';

import 'custom_frame.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  PackageInfo.setMockInitialValues(
    appName: 'BikeControl',
    packageName: 'de.jonasbark.swiftcontrol',
    version: '4.0.0',
    buildNumber: '1',
    buildSignature: '',
  );
  SharedPreferences.setMockInitialValues({});

  final List<(String type, Size size)> sizes = [
    ('Phone', Size(400, 800)),
    /*('iPhone', Size(1242, 2688)),
    ('macOS', Size(1280, 800)),
    ('GitHub', Size(600, 900)),*/
  ];

  debugDisableShadows = true;
  testGoldens('Requirements', (WidgetTester tester) async {
    screenshotMode = true;

    // Set phone screen size (typical Android phone - 1140x2616 to match existing)
    await core.settings.init();
    await core.settings.reset();

    core.settings.setTrainerApp(MyWhoosh());
    core.settings.setKeyMap(MyWhoosh());
    core.settings.setLastTarget(Target.thisDevice);

    core.connection.addDevices([
      ZwiftRide(
          BleDevice(
            name: 'Controller',
            deviceId: '00:11:22:33:44:55',
          ),
        )
        ..firmwareVersion = '1.2.0'
        ..rssi = -51
        ..batteryLevel = 81,
    ]);

    final device = ScreenshotDevice(
      platform: TargetPlatform.android,
      resolution: Size(1320, 2868),
      pixelRatio: 3,
      goldenSubFolder: 'iphoneScreenshots/',
      frameBuilder: CustomFrame.new,
    );

    await tester.pumpWidget(
      ScreenshotApp(device: device, home: BikeControlApp()),
    );

    await tester.loadAssets();
    await tester.pump();
    await expectLater(
      find.byType(ma.Scaffold),
      matchesGoldenFile('custom_frame_test.png'),
    );
  });
  /*testGoldens('Device', (WidgetTester tester) async {
    await tester.loadFonts();
    for (final size in sizes) {
      await _createDeviceScreenshot(tester, size);
    }
  });*/
}
