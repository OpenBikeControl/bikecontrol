// A steering input's page (phone steering, Elite Sterzo / Rizer): what it
// does, the live angle, which trainer-app action each direction drives, the
// dead zone, calibration and how to turn it off — and none of a button's
// single / double / long-press triggers.
import 'package:bike_control/bluetooth/devices/elite/elite_sterzo.dart';
import 'package:bike_control/bluetooth/devices/gyroscope/gyroscope_steering.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/pages/customize.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  late GyroscopeSteering phone;

  setUp(() {
    phone = GyroscopeSteering()..isConnected = true;
    phone.isCalibratedNotifier.value = true;
    phone.steeringAngle.value = 8;
    core.connection.devices
      ..clear()
      ..add(phone);
    core.settings.setTrainerApp(MyWhoosh());
    core.settings.setKeyMap(MyWhoosh());
    core.actionHandler.init(MyWhoosh());
    core.settings.setPhoneSteeringEnabled(true);
    core.settings.setPhoneSteeringThreshold(5);
  });
  tearDown(() => core.connection.devices.clear());

  Future<AppLocalizations> pump(WidgetTester tester, {Object? device, Size size = const Size(390, 1600)}) async {
    await AppLocalizations.load(const Locale('de'));
    addTearDown(() => AppLocalizations.load(const Locale('en')));
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        locale: const Locale('de'),
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: BkTheme.build(Brightness.dark),
        home: BkComponentThemes(child: ControllerSettingsPage(device: (device ?? phone) as dynamic)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return AppLocalizations.current;
  }

  for (final size in const [Size(390, 1600), Size(1280, 1000)]) {
    testWidgets('${size.width.toInt()} wide: no button mapping, no triggers', (tester) async {
      final l = await pump(tester, size: size);
      expect(find.byType(CustomizePage), findsNothing);
      expect(find.text(l.triggerSingleClick), findsNothing);
      expect(find.text(l.triggerDoubleClick), findsNothing);
      expect(find.text(l.triggerLongPress), findsNothing);
      expect(find.text(l.steeringDescription), findsOneWidget);
      expect(find.byKey(const ValueKey('steering-angle-readout')), findsOneWidget);
    });
  }

  testWidgets('each direction names the action it drives', (tester) async {
    final l = await pump(tester);
    final left = find.byKey(const ValueKey('steering-direction-left'));
    final right = find.byKey(const ValueKey('steering-direction-right'));
    expect(find.descendant(of: left, matching: find.text(l.actionSteerLeft)), findsOneWidget);
    expect(find.descendant(of: right, matching: find.text(l.actionSteerRight)), findsOneWidget);
  });

  testWidgets('a direction opens its action editor without any trigger', (tester) async {
    final l = await pump(tester);
    final left = find.byKey(const ValueKey('steering-direction-left'));
    await tester.ensureVisible(left);
    await tester.tap(left);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byType(ButtonEditPage), findsOneWidget);
    expect(find.textContaining(l.editingTrigger(l.triggerLongPress)), findsNothing);
    expect(find.text(l.repeatSingleClick), findsNothing);
    expect(find.text(l.steeringTurnLeft), findsWidgets);
  });

  testWidgets('the dead zone is set from its row', (tester) async {
    await pump(tester);
    final row = find.byKey(const ValueKey('steering-dead-zone'));
    expect(find.descendant(of: row, matching: find.text('±5°')), findsOneWidget);
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.text('±8°').last);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(core.settings.getPhoneSteeringThreshold(), 8);
    expect(find.descendant(of: row, matching: find.text('±8°')), findsOneWidget);
  });

  testWidgets('recalibrate starts a new calibration', (tester) async {
    final l = await pump(tester);
    final row = find.byKey(const ValueKey('steering-recalibrate'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pump();
    expect(phone.steeringCalibrated.value, isFalse);
    expect(find.text(l.calibratingSensorsHint), findsOneWidget);
  });

  testWidgets('phone steering turns off from its page', (tester) async {
    final l = await pump(tester);
    expect(find.text(l.disconnectAndForget), findsNothing);
    final row = find.byKey(const ValueKey('steering-turn-off'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pump();
    expect(core.settings.getPhoneSteeringEnabled(), isFalse);
  });

  testWidgets('an Elite Sterzo keeps its fixed dead zone and Bluetooth disconnect', (tester) async {
    final sterzo = EliteSterzo(BleDevice(name: 'STERZO', deviceId: 'sterzo'))..isConnected = true;
    sterzo.steeringCalibratedN.value = true;
    core.connection.devices.add(sterzo);
    final l = await pump(tester, device: sterzo);
    expect(find.byType(CustomizePage), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('steering-dead-zone')), matching: find.text('±10°')), findsOneWidget);
    expect(find.byKey(const ValueKey('steering-turn-off')), findsNothing);
    expect(find.byKey(const ValueKey('steering-recalibrate')), findsNothing);
    expect(find.text(l.disconnectAndForget), findsOneWidget);
  });
}
