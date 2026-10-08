// The button mapping's trigger labels and actions read whole on the store
// boards' sizes: the iPad's master–detail (917 px) keeps "Double Click",
// "Long Press" and "Auswählen" / "Sélectionner" from being cut or broken
// mid-word in its three trigger cards, and the phone's open row (414 px)
// shows "Nach rechts lenken" whole beside "Langes Drücken PRO".
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart' show ScreenshotTester;
import 'package:prop/utils/prefs.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../helpers/text_breaks.dart';
import '../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  final device = ZwiftClickV2(BleDevice(name: 'Zwift Click', deviceId: 'fit-click'))
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
    await core.settings.setClickV2OnboardingDone(true);
    propPrefs.setZwiftClickV2LastUnlock(device.scanResult.deviceId, DateTime.now());
  });
  tearDown(() => core.connection.devices.clear());

  Future<void> pump(WidgetTester tester, Size size, String locale) async {
    await AppLocalizations.load(Locale(locale));
    addTearDown(() => AppLocalizations.load(const Locale('en')));
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final app = ShadcnApp(
      debugShowCheckedModeBanner: false,
      scaling: BkTheme.scaling,
      theme: BkTheme.build(Brightness.light),
      locale: Locale(locale),
      localizationsDelegates: [
        ...ShadcnLocalizations.localizationsDelegates,
        const OtherLocalizationsDelegate(),
        AppLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: BkComponentThemes(child: ControllerSettingsPage(device: device)),
    );
    await tester.pumpWidget(app);
    await tester.loadAssets();
    await remountWithLoadedFonts(tester, app);
    await tester.pump(const Duration(milliseconds: 500));
  }

  for (final locale in const ['en', 'de', 'es', 'fr', 'it', 'pl']) {
    testWidgets('917 wide (iPad): the trigger cards read whole ($locale)', (tester) async {
      await pump(tester, const Size(917, 688), locale);
      expect(find.byKey(const ValueKey('mapping-detail')), findsOneWidget);
      for (final trigger in ButtonTrigger.values) {
        final card = find.byKey(ValueKey('mapping-trigger-card-${trigger.name}'));
        expect(card, findsOneWidget, reason: trigger.name);
        expectReadsWhole(tester, card, reason: '[$locale] ${trigger.name}');
      }
    });

    testWidgets('414 wide (iPhone): an open button\'s trigger rows read whole ($locale)', (tester) async {
      const a = ZwiftButtons.a;
      final app = CustomApp(profileName: 'Fit');
      app.keymap.keyPairs.add(
        KeyPair(
          buttons: [a],
          physicalKey: null,
          logicalKey: null,
          inGameAction: InGameAction.steerRight,
          trigger: ButtonTrigger.longPress,
        ),
      );
      await core.settings.setKeyMap(app);
      core.actionHandler.init(app);

      await pump(tester, const Size(414, 896), locale);
      final open = find.byKey(ValueKey('mapping-trigger-${a.name}-singleClick'));
      if (open.evaluate().isEmpty) {
        await tester.tap(find.byKey(ValueKey('mapping-row-${a.name}')));
        await tester.pump(const Duration(milliseconds: 400));
      }
      for (final trigger in ButtonTrigger.values) {
        final row = find.byKey(ValueKey('mapping-trigger-${a.name}-${trigger.name}'));
        await tester.ensureVisible(row);
        await tester.pump();
        expectReadsWhole(tester, row, reason: '[$locale] ${trigger.name}');
      }
    });
  }
}
