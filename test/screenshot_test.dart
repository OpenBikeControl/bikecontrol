import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/pages/device.dart';
import 'package:swift_control/theme.dart';
import 'package:swift_control/utils/keymap/apps/my_whoosh.dart';
import 'package:swift_control/utils/requirements/multi.dart';
import 'package:test_screenshot/test_screenshot.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  PackageInfo.setMockInitialValues(
    appName: 'BikeControl',
    packageName: 'de.jonasbark.swiftcontrol',
    version: '3.5.0',
    buildNumber: '1',
    buildSignature: '',
  );
  SharedPreferences.setMockInitialValues({});

  group('Screenshot Tests', () {
    final List<(String type, Size size)> sizes = [
      ('Phone', Size(400, 800)),
      ('macOS', Size(1280, 800)),
      ('GitHub', Size(600, 900)),
    ];

    testWidgets('Requirements', (WidgetTester tester) async {
      await tester.loadFonts();
      for (final size in sizes) {
        await _createRequirementScreenshot(tester, size);
      }

      // Reset
    });
    testWidgets('Device', (WidgetTester tester) async {
      await tester.loadFonts();
      for (final size in sizes) {
        await _createDeviceScreenshot(tester, size);
      }
    });
  });
}

Future<void> _createDeviceScreenshot(WidgetTester tester, (String type, Size size) spec) async {
  // Set phone screen size (typical Android phone - 1140x2616 to match existing)
  tester.view.physicalSize = spec.$2;
  tester.view.devicePixelRatio = 1;

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
        title: 'BikeControl',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.light,
        home: const DevicePage(),
      ),
    ),
  );

  const wait = 1;

  try {
    await tester.pumpAndSettle(Duration(seconds: wait), EnginePhase.sendSemanticsUpdate, Duration(seconds: wait));
  } catch (e) {
    // Ignore timeout errors
  }

  await _takeScreenshot(tester, 'device-${spec.$1}-${spec.$2.width.toInt()}x${spec.$2.height.toInt()}.png');
}

Future<void> _createRequirementScreenshot(WidgetTester tester, (String type, Size size) spec) async {
  // Set phone screen size (typical Android phone - 1140x2616 to match existing)
  tester.view.physicalSize = spec.$2;
  tester.view.devicePixelRatio = 1;

  await settings.init();
  await settings.reset();
  screenshotMode = true;
  await tester.pumpWidget(
    Screenshotter(
      child: SwiftPlayApp(),
    ),
  );
  await tester.pumpAndSettle();

  await _takeScreenshot(tester, 'screenshot-${spec.$1}-${spec.$2.width.toInt()}x${spec.$2.height.toInt()}.png');
}

Future<void> _takeScreenshot(WidgetTester tester, String path) async {
  const FileSystem fs = LocalFileSystem();
  final file = fs.file('screenshots/$path');
  await fs.directory('screenshots').create();
  print('File path: ${file.absolute.path}');

  await tester.screenshot(path: 'screenshots/$path');
  final decodedImage = await decodeImageFromList(file.readAsBytesSync());
  print(decodedImage);
}
