import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/pages/device.dart';
import 'package:swift_control/theme.dart';
import 'package:swift_control/utils/keymap/apps/my_whoosh.dart';
import 'package:swift_control/utils/requirements/multi.dart';
import 'package:test_screenshot/test_screenshot.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Screenshot Tests', () {
    testWidgets('Requirements', (WidgetTester tester) async {
      // Set phone screen size (typical Android phone - 1140x2616 to match existing)
      binding.window.physicalSizeTestValue = const Size(1280, 800);
      binding.window.devicePixelRatioTestValue = 1.0;

      await settings.init();
      await settings.reset();
      screenshotMode = true;
      await tester.pumpWidget(
        Screenshotter(
          child: SwiftPlayApp(),
        ),
      );

      const wait = 3;

      try {
        await tester.pumpAndSettle(Duration(seconds: wait), EnginePhase.sendSemanticsUpdate, Duration(seconds: wait));
      } catch (e) {
        // Ignore timeout errors
      }

      await tester.screenshot(path: 'screenshot.png');
      // Reset
      binding.window.clearPhysicalSizeTestValue();
      binding.window.clearDevicePixelRatioTestValue();
    });
    testWidgets('Device', (WidgetTester tester) async {
      // Set phone screen size (typical Android phone - 1140x2616 to match existing)
      binding.window.physicalSizeTestValue = const Size(1280, 800);
      binding.window.devicePixelRatioTestValue = 1.0;

      screenshotMode = true;

      await settings.init();
      await settings.reset();
      settings.setTrainerApp(MyWhoosh());
      settings.setKeyMap(MyWhoosh());
      settings.setLastTarget(Target.thisDevice);

      connection.addDevices([
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

      await tester.pumpWidget(
        Screenshotter(
          child: MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'SwiftControl',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.system,
            home: const DevicePage(),
          ),
        ),
      );

      const wait = 3;

      try {
        await tester.pumpAndSettle(Duration(seconds: wait), EnginePhase.sendSemanticsUpdate, Duration(seconds: wait));
      } catch (e) {
        // Ignore timeout errors
      }

      await tester.screenshot(path: 'device.png');
      // Reset
      binding.window.clearPhysicalSizeTestValue();
      binding.window.clearDevicePixelRatioTestValue();
    });
  });
}
