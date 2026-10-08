// The store boards hide the trainer app's name. Wherever a screen hides it,
// every label on that screen uses the same generic name — a "Trainer app"
// keymap under a "for MyWhoosh" header gave the real name away and read as a
// mismatch. Outside screenshot mode the real name shows everywhere.
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, screenshotMode, screenshotTrainerAppName;
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/pages/navigation.dart';
import 'package:bike_control/pages/shell/app_shell.dart' show AppSection;
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/utils/prefs.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  final device = ZwiftClickV2(BleDevice(name: 'Zwift Click', deviceId: 'names-click'))
    ..firmwareVersion = '1.2.0'
    ..isConnected = true
    ..batteryLevel = 81;

  setUp(() async {
    core.connection.devices
      ..clear()
      ..add(device);
    core.settings.setTrainerApp(MyWhoosh());
    core.settings.setKeyMap(MyWhoosh());
    core.actionHandler.init(MyWhoosh());
    await core.settings.setLastTarget(Target.thisDevice);
    await core.settings.setClickV2OnboardingDone(true);
    propPrefs.setZwiftClickV2LastUnlock(device.scanResult.deviceId, DateTime.now());
  });
  tearDown(() => core.connection.devices.clear());

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        theme: BkTheme.build(Brightness.light),
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: BkComponentThemes(child: page),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  final pages = <String, Widget Function()>{
    'controller settings': () => ControllerSettingsPage(device: device),
    'connection settings': () => const TrainerConnectionSettingsPage(),
    // The Ride tab's ready banner ("Your buttons are reaching …") and, on
    // wide layouts, the shell's trainer chip both name the app.
    'ride': () => const Navigation(),
    'devices': () => const Navigation(initialSection: AppSection.devices),
  };

  for (final MapEntry(key: name, value: page) in pages.entries) {
    testWidgets('$name: screenshot mode shows only the generic name', (tester) async {
      screenshotMode = true;
      await pump(tester, page());
      expect(find.textContaining('MyWhoosh'), findsNothing);
      expect(find.textContaining(screenshotTrainerAppName), findsWidgets);
    });
  }

  testWidgets('controller settings: the mapping header names the same app as the keymap', (tester) async {
    screenshotMode = true;
    await pump(tester, ControllerSettingsPage(device: device));
    expect(find.text(AppLocalizations.current.mappingForApp(screenshotTrainerAppName)), findsOneWidget);
  });

  testWidgets('controller settings: outside screenshot mode the real name shows', (tester) async {
    screenshotMode = false;
    addTearDown(() => screenshotMode = true);
    await pump(tester, ControllerSettingsPage(device: device));
    expect(find.text(AppLocalizations.current.mappingForApp('MyWhoosh')), findsOneWidget);
  });

  testWidgets('the generic name is in the rider\'s language', (tester) async {
    await AppLocalizations.load(const Locale('de'));
    addTearDown(() => AppLocalizations.load(const Locale('en')));
    expect(screenshotTrainerAppName, 'Trainer-App');
  });
}
