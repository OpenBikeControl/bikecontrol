// An incline device's page (Elite Rizer, KICKR Climb): the incline it was
// last set to and why, the follow-the-gradient switch and − / 0% / + by hand.
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/elite/elite_rizer.dart';
import 'package:bike_control/bluetooth/devices/elite/elite_rizer_protocol.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_click.dart';
import 'package:bike_control/bluetooth/incline/incline_manual_state.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/widgets/controller/incline_section.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  late EliteRizer rizer;
  late List<Uint8List> writes;

  setUp(() {
    writes = [];
    rizer = EliteRizer(BleDevice(name: 'RIZER', deviceId: 'rizer'))
      ..isConnected = true
      ..debugWriteSink = (b) async => writes.add(b);
    core.connection.devices
      ..clear()
      ..add(rizer);
    core.settings.setTrainerApp(MyWhoosh());
    core.settings.setKeyMap(MyWhoosh());
    core.actionHandler.init(MyWhoosh());
  });
  tearDown(() => core.connection.devices.clear());

  Future<AppLocalizations> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: BkTheme.build(Brightness.dark),
        home: BkComponentThemes(child: ControllerSettingsPage(device: rizer)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return AppLocalizations.current;
  }

  testWidgets('the Rizer page shows its incline next to its steering', (tester) async {
    final l = await pump(tester);
    expect(find.byType(InclineSection), findsOneWidget);
    expect(find.text(l.inclineFollowGradient), findsOneWidget);
    expect(find.text('–'), findsOneWidget, reason: 'nothing written yet');

    await rizer.writeInclineRaw(450);
    await tester.pump();
    expect(find.text('4.5%'), findsOneWidget);
  });

  testWidgets('+ leaves auto, steps 1% from the current incline and writes it', (tester) async {
    final l = await pump(tester);
    await rizer.writeInclineRaw(450);
    await tester.pump();

    await tester.ensureVisible(find.byKey(const ValueKey('incline-up')));
    await tester.tap(find.byKey(const ValueKey('incline-up')));
    await tester.pump();
    expect(rizer.inclineState.mode, InclineMode.manual);
    expect(find.text('5.5%'), findsOneWidget);
    expect(writes.last, [0x0a, 55, 0]);
    expect(find.text(l.inclineHeldByHand), findsOneWidget);
  });

  testWidgets('the switch turns following the gradient off and back on', (tester) async {
    await pump(tester);
    await rizer.writeInclineRaw(700);
    await tester.pump();

    final row = find.byKey(const ValueKey('incline-follow'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pump();
    expect(rizer.followsGrade, isFalse);
    expect(rizer.inclineState.grade001, 700, reason: 'holds where the grade had put it');

    await tester.tap(row);
    await tester.pump();
    expect(rizer.followsGrade, isTrue);
  });

  testWidgets('a locked Rizer says so on its page and on Ride instead of following the gradient', (tester) async {
    final l = await pump(tester);
    rizer.debugWriteSink = (b) async {
      await rizer.processCharacteristic(eliteRizerStatusCharacteristicUuid, Uint8List.fromList([0x80, 0x0a, 0x05]));
    };
    await rizer.writeInclineRaw(450);
    await tester.pump();
    expect(find.text(l.inclineLocked), findsOneWidget);
    expect(find.text(l.inclineFollowsGradient), findsNothing);
    expect(find.text(l.inclineWaitingForGradient), findsNothing);

    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: BkTheme.build(Brightness.dark),
        home: BkComponentThemes(
          child: Scaffold(child: InclineRideReadout(device: rizer)),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining(l.inclineLocked), findsOneWidget);
  });

  // A toast (the copied custom profile) keeps animating, so no pumpAndSettle.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('an accessory action goes on a button of the connected controller from a dropdown', (tester) async {
    final click = ZwiftClick(BleDevice(name: 'Zwift Click', deviceId: 'click'))..isConnected = true;
    core.connection.devices.add(click);
    final l = await pump(tester);

    final row = find.byKey(const ValueKey('accessory-action-inclineIncrease'));
    await tester.ensureVisible(row);
    expect(find.descendant(of: row, matching: find.text(l.accessoryActionNoButton)), findsOneWidget);
    await tester.tap(row);
    await settle(tester);
    await tester.tap(find.text(ZwiftButtons.shiftUpRight.displayName).last);
    await settle(tester);

    final keymap = core.actionHandler.supportedApp!.keymap;
    expect(
      keymap.getKeyPair(ZwiftButtons.shiftUpRight, trigger: ButtonTrigger.singleClick)?.inGameAction,
      InGameAction.inclineIncrease,
    );
    expect(find.descendant(of: row, matching: find.text(ZwiftButtons.shiftUpRight.displayName)), findsOneWidget);

    // Another button takes it over; the first one lets go.
    await tester.tap(row);
    await settle(tester);
    await tester.tap(find.text(ZwiftButtons.shiftUpLeft.displayName).last);
    await settle(tester);
    final current = core.actionHandler.supportedApp!.keymap;
    expect(
      current.getKeyPair(ZwiftButtons.shiftUpLeft, trigger: ButtonTrigger.singleClick)?.inGameAction,
      InGameAction.inclineIncrease,
    );
    expect(
      current.getKeyPair(ZwiftButtons.shiftUpRight, trigger: ButtonTrigger.singleClick)?.inGameAction,
      isNot(InGameAction.inclineIncrease),
    );

    // "No button" takes it off again.
    await tester.tap(row);
    await settle(tester);
    await tester.tap(find.text(l.accessoryActionNoButton).last);
    await settle(tester);
    expect(
      core.actionHandler.supportedApp!.keymap.keyPairs.where((k) => k.inGameAction == InGameAction.inclineIncrease),
      isEmpty,
    );
  });

  testWidgets('snapshot', (tester) async {
    await rizer.writeInclineRaw(450);
    for (final b in Brightness.values) {
      await captureWidget(
        tester,
        name: 'incline-section-${b.name}',
        brightness: b,
        builder: (_) => InclineSection(device: rizer),
      );
    }
    rizer.inclineState.holdAt(-200);
    await rizer.writeInclineRaw(-200);
    await captureWidget(
      tester,
      name: 'incline-ride-readout',
      builder: (_) => InclineRideReadout(device: rizer),
    );
  });
}
