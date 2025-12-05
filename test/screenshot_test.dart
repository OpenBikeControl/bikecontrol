import 'package:flutter/material.dart' as ma;
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/pages/navigation.dart';
import 'package:swift_control/utils/core.dart' show core;
import 'package:swift_control/utils/keymap/apps/my_whoosh.dart';
import 'package:swift_control/utils/requirements/multi.dart';
import 'package:universal_ble/universal_ble.dart';

import 'custom_frame.dart';

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  PackageInfo.setMockInitialValues(
    appName: 'BikeControl',
    packageName: 'de.jonasbark.swiftcontrol',
    version: '4.0.0',
    buildNumber: '1',
    buildSignature: '',
  );
  SharedPreferences.setMockInitialValues({});

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

  final List<(TargetPlatform type, Size size)> sizes = [
    (TargetPlatform.android, Size(1320, 2868)),
    (TargetPlatform.iOS, Size(1320, 2868)),
    /*('iPhone', Size(1242, 2688)),
    ('macOS', Size(1280, 800)),
    ('GitHub', Size(600, 900)),*/
  ];

  debugDisableShadows = true;
  screenshotMode = true;

  testGoldens('Device', (WidgetTester tester) async {
    await tester.loadAssets();

    for (final size in sizes) {
      await tester.pumpWidget(
        ScreenshotApp(
          device: ScreenshotDevice(
            platform: size.$1,
            resolution: size.$2,
            pixelRatio: 3,
            goldenSubFolder: 'iphoneScreenshots/',
            frameBuilder:
                ({
                  required ScreenshotDevice device,
                  required ScreenshotFrameColors? frameColors,
                  required Widget child,
                }) => CustomFrame(
                  platform: size.$1,
                  title: 'BikeControl connects to your favorite controller',
                  device: device,
                  child: child,
                ),
          ),
          home: BikeControlApp(
            page: BCPage.devices,
          ),
        ),
      );

      await tester.pump();
      await expectLater(
        find.byType(ma.Scaffold),
        matchesGoldenFile(
          '../screenshots/device-${size.$1.name}-${size.$2.width.toInt()}-${size.$2.height.toInt()}.png',
        ),
      );
    }
  });

  testGoldens('Trainer', (WidgetTester tester) async {
    for (final size in sizes) {
      await tester.pumpWidget(
        ScreenshotApp(
          device: ScreenshotDevice(
            platform: size.$1,
            resolution: size.$2,
            pixelRatio: 3,
            goldenSubFolder: 'iphoneScreenshots/',
            frameBuilder:
                ({
                  required ScreenshotDevice device,
                  required ScreenshotFrameColors? frameColors,
                  required Widget child,
                }) => CustomFrame(
                  platform: size.$1,
                  title: 'BikeControl connects to your favorite controller',
                  device: device,
                  child: child,
                ),
          ),
          home: BikeControlApp(
            page: BCPage.trainer,
          ),
        ),
      );

      await tester.pump();
      await expectLater(
        find.byType(ma.Scaffold),
        matchesGoldenFile(
          '../screenshots/trainer-${size.$1.name}-${size.$2.width.toInt()}-${size.$2.height.toInt()}.png',
        ),
      );
    }
  });

  testGoldens('Customization', (WidgetTester tester) async {
    screenshotMode = true;

    for (final size in sizes) {
      await tester.pumpWidget(
        ScreenshotApp(
          device: ScreenshotDevice(
            platform: size.$1,
            resolution: size.$2,
            pixelRatio: 3,
            goldenSubFolder: 'iphoneScreenshots/',
            frameBuilder:
                ({
                  required ScreenshotDevice device,
                  required ScreenshotFrameColors? frameColors,
                  required Widget child,
                }) => CustomFrame(
                  platform: size.$1,
                  title: 'Customize every controller button',
                  device: device,
                  child: child,
                ),
          ),
          home: BikeControlApp(
            page: BCPage.customization,
          ),
        ),
      );

      await tester.pump();
      await expectLater(
        find.byType(ma.Scaffold),
        matchesGoldenFile(
          '../screenshots/customization-${size.$1.name}-${size.$2.width.toInt()}-${size.$2.height.toInt()}.png',
        ),
      );
    }
  });
}
