import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/button_simulator.dart';
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/utils/core.dart' show core;
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter/material.dart' as ma;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

import 'custom_frame.dart';

enum DeviceType {
  android,
  androidTablet,
  iPhone,
  iPad,
  desktop,
  noFrame,
}

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  PackageInfo.setMockInitialValues(
    appName: 'BikeControl',
    packageName: 'de.jonasbark.swiftcontrol',
    version: '5.0.0',
    buildNumber: '1',
    buildSignature: '',
  );
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({});
  IAPManager.instance.isPurchased.value = true;

  screenshotMode = true;

  await core.settings.init();
  await core.settings.reset();

  final keymap = MyWhoosh();

  final device =
      ZwiftRide(
          BleDevice(
            name: 'Controller',
            deviceId: '00:11:22:33:44:55',
          ),
        )
        ..firmwareVersion = '1.2.0'
        ..isConnected = true
        ..rssi = -51
        ..batteryLevel = 81;

  core.connection.addDevices([device]);

  final firstButton = ZwiftButtons.b.copyWith(sourceDeviceId: device.uniqueId);
  final keyEntry = keymap.keymap.getOrCreateKeyPair(firstButton, trigger: ButtonTrigger.longPress);
  keyEntry.inGameAction = InGameAction.steerRight;

  core.settings.setTrainerApp(keymap);
  core.settings.setKeyMap(keymap);
  core.settings.setLastTarget(Target.thisDevice);

  final List<({DeviceType type, TargetPlatform platform, Size size})> sizes = [
    (type: DeviceType.android, platform: TargetPlatform.android, size: Size(1320, 2868)),
    (type: DeviceType.androidTablet, platform: TargetPlatform.android, size: Size(3840, 2400)),
    (type: DeviceType.iPhone, platform: TargetPlatform.iOS, size: Size(1242, 2688)),
    (type: DeviceType.iPad, platform: TargetPlatform.iOS, size: Size(2752, 2064)),
    (type: DeviceType.desktop, platform: TargetPlatform.windows, size: Size(2560, 1600)),
    (type: DeviceType.noFrame, platform: TargetPlatform.windows, size: Size(1320, 2868) / 1.2),
    /*('iPhone', Size(1242, 2688)),
    ('macOS', Size(1280, 800)),
    ('GitHub', Size(600, 900)),*/
  ];

  debugDisableShadows = true;

  testGoldens('Init', (WidgetTester tester) async {
    screenshotMode = true;
    IAPManager.instance.isPurchased.value = true;
    await tester.loadAssets();
    for (final size in sizes) {
      await tester.pumpWidget(
        ScreenshotApp(
          device: ScreenshotDevice(
            platform: size.platform,
            resolution: size.size,
            pixelRatio: 3,
            goldenSubFolder: 'iphoneScreenshots/',
            frameBuilder:
                ({
                  required ScreenshotDevice device,
                  required ScreenshotFrameColors? frameColors,
                  required Widget child,
                }) => CustomFrame(
                  platform: size.type,
                  title: 'BikeControl connects to your favorite controller',
                  device: device,
                  child: child,
                ),
          ),
          home: BikeControlApp(),
        ),
      );

      await tester.pump();
    }
  });

  testGoldens('Trainer', (WidgetTester tester) async {
    IAPManager.instance.isPurchased.value = true;
    screenshotMode = true;
    for (final size in sizes) {
      await tester.pumpWidget(
        ScreenshotApp(
          device: ScreenshotDevice(
            platform: size.platform,
            resolution: size.size,
            pixelRatio: 3,
            goldenSubFolder: 'iphoneScreenshots/',
            frameBuilder:
                ({
                  required ScreenshotDevice device,
                  required ScreenshotFrameColors? frameColors,
                  required Widget child,
                }) => CustomFrame(
                  platform: size.type,
                  title: 'Connect BikeControl to your trainer',
                  device: device,
                  child: child,
                ),
          ),
          home: BikeControlApp(
            customChild: TrainerConnectionSettingsPage(),
          ),
        ),
      );

      await tester.pump();
      await expectLater(
        find.byType(ma.Scaffold),
        matchesGoldenFile(
          '../screenshots/trainer-${size.type.name}-${size.size.width.toInt()}x${size.size.height.toInt()}.png',
        ),
      );
    }
  });

  testGoldens('Customization', (WidgetTester tester) async {
    IAPManager.instance.isPurchased.value = true;
    screenshotMode = true;

    for (final size in sizes) {
      await tester.pumpWidget(
        ScreenshotApp(
          device: ScreenshotDevice(
            platform: size.platform,
            resolution: size.size,
            pixelRatio: 3,
            goldenSubFolder: 'iphoneScreenshots/',
            frameBuilder:
                ({
                  required ScreenshotDevice device,
                  required ScreenshotFrameColors? frameColors,
                  required Widget child,
                }) => CustomFrame(
                  platform: size.type,
                  title: 'Customize every controller button',
                  device: device,
                  child: child,
                ),
          ),
          home: BikeControlApp(
            customChild: ControllerSettingsPage(device: device),
          ),
        ),
      );

      await tester.pump();
      await expectLater(
        find.byType(ma.Scaffold),
        matchesGoldenFile(
          '../screenshots/customization-${size.type.name}-${size.size.width.toInt()}x${size.size.height.toInt()}.png',
        ),
      );
    }
  });

  testGoldens('Trainer Controls', (WidgetTester tester) async {
    IAPManager.instance.isPurchased.value = true;
    screenshotMode = true;

    core.settings.setMyWhooshLinkEnabled(true);
    core.whooshLink.isConnected.value = true;
    for (final size in sizes) {
      await tester.pumpWidget(
        ScreenshotApp(
          device: ScreenshotDevice(
            platform: size.platform,
            resolution: size.size,
            pixelRatio: 3,
            goldenSubFolder: 'iphoneScreenshots/',
            frameBuilder:
                ({
                  required ScreenshotDevice device,
                  required ScreenshotFrameColors? frameColors,
                  required Widget child,
                }) => CustomFrame(
                  platform: size.type,
                  title: 'Companion App mode with custom hotkeys',
                  device: device,
                  child: child,
                ),
          ),
          home: BikeControlApp(
            customChild: ButtonSimulator(),
          ),
        ),
      );

      await tester.pump();
      await expectLater(
        find.byType(ma.Scaffold),
        matchesGoldenFile(
          '../screenshots/companion-${size.type.name}-${size.size.width.toInt()}x${size.size.height.toInt()}.png',
        ),
      );
    }
  });
}
