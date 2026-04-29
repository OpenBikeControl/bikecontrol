import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/button_simulator.dart';
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratios_editor_page.dart';
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/utils/core.dart' show core;
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter/material.dart' as ma;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/dircon_emulator.dart';
import 'package:prop/emulators/transporter/network_transporter.dart';
import 'package:prop/protocol/zp.pbenum.dart';
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
    version: '5.4.0',
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
      ZwiftClickV2(
          BleDevice(
            name: 'Controller',
            deviceId: '00:11:22:33:44:55',
          ),
        )
        ..firmwareVersion = '1.2.0'
        ..isConnected = true
        ..rssi = -51
        ..batteryLevel = 81;

  final proxy =
      ProxyDevice(
          BleDevice(
            name: 'Smart Trainer',
            deviceId: '00:11:22:33:44:55',
            services: [
              FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID,
            ],
          ),
        )
        ..services = [
          BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, []),
        ]
        ..firmwareVersion = '1.2.0'
        ..isConnected = true
        ..rssi = -51;

  proxy.emulator.debugSetTransporter(
    NetworkTransporter(
      definition: FitnessBikeDefinition(
        connectedDevice: proxy.scanResult,
        connectedDeviceServices: proxy.services!,
        data: ValueNotifier(''),
      )..setDebugValues(),
    ),
  );

  core.connection.addDevices([device, proxy]);

  final firstButton = ZwiftButtons.b.copyWith(sourceDeviceId: device.uniqueId);
  final keyEntry = keymap.keymap.getOrCreateKeyPair(firstButton, trigger: ButtonTrigger.longPress);
  keyEntry.inGameAction = InGameAction.steerRight;

  core.settings.setRetrofitMode(proxy.trainerKey, RetrofitMode.wifi);
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

  testGoldens('Device', (WidgetTester tester) async {
    IAPManager.instance.isPurchased.value = true;
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
                  title: 'Control any trainer with ANY controller',
                  device: device,
                  child: child,
                ),
          ),
          home: BikeControlApp(),
        ),
      );

      await tester.pump();

      core.connection.signalNotification(
        AlertNotification(LogLevel.LOGLEVEL_INFO, 'Connecting to: ${device.toString()}'),
      );
      core.connection.signalNotification(
        AlertNotification(LogLevel.LOGLEVEL_INFO, 'Connection finished: ${device.toString()}'),
      );

      await tester.pump();
      await expectLater(
        find.byType(ma.Scaffold),
        matchesGoldenFile(
          '../screenshots/device-${size.type.name}-${size.size.width.toInt()}x${size.size.height.toInt()}.png',
        ),
      );
    }
  });

  testGoldens('Trainer', (WidgetTester tester) async {
    IAPManager.instance.isPurchased.value = true;
    core.settings.setTrainerApp(BikeControl());
    core.settings.setKeyMap(BikeControl());
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
    core.settings.setTrainerApp(keymap);
    core.settings.setKeyMap(keymap);
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

    core.settings.setTrainerApp(keymap);
    core.settings.setKeyMap(keymap);
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

  testGoldens('Virtual Shifting', (WidgetTester tester) async {
    IAPManager.instance.isPurchased.value = true;
    screenshotMode = true;

    core.settings.setTrainerApp(keymap);
    core.settings.setKeyMap(keymap);
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
                  title: 'Add or adjust Virtual Shifting functionality',
                  device: device,
                  child: child,
                ),
          ),
          home: BikeControlApp(
            customChild: ProxyDeviceDetailsPage(device: proxy),
          ),
        ),
      );

      await tester.pump();
      await expectLater(
        find.byType(ma.Scaffold),
        matchesGoldenFile(
          '../screenshots/virtualshifting-${size.type.name}-${size.size.width.toInt()}x${size.size.height.toInt()}.png',
        ),
      );
    }
  });

  testGoldens('Virtual Shifting Settings', (WidgetTester tester) async {
    IAPManager.instance.isPurchased.value = true;
    screenshotMode = true;

    core.settings.setTrainerApp(Zwift());
    core.settings.setKeyMap(Zwift());
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
                  title: 'Full Control of Virtual Shifting',
                  device: device,
                  child: child,
                ),
          ),
          home: BikeControlApp(
            customChild: GearRatiosEditorPage(
              device: proxy,
              definition: proxy.emulator.activeDefinition as FitnessBikeDefinition,
            ),
          ),
        ),
      );

      await tester.pump();
      await expectLater(
        find.byType(ma.Scaffold),
        matchesGoldenFile(
          '../screenshots/virtualshifting-settings-${size.type.name}-${size.size.width.toInt()}x${size.size.height.toInt()}.png',
        ),
      );
    }
  });
}
