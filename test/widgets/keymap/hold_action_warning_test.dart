// Steering (and any other action that only works while held) on a single or
// double click does next to nothing: the press and its release go out back
// to back. The mapping says so where the action is picked, offers to move it
// to the long press in one tap, and marks the rows where it already sits on
// a click.
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/utils/prefs.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  final device = ZwiftClickV2(BleDevice(name: 'Zwift Click', deviceId: 'hold-click'))
    ..firmwareVersion = '1.2.0'
    ..isConnected = true
    ..batteryLevel = 81;
  const left = ZwiftButtons.navigationLeft;

  /// A custom mapping with [pairs] on the left button.
  Future<void> mapLeft(Map<ButtonTrigger, InGameAction> pairs) async {
    final app = CustomApp(profileName: 'Hold test');
    for (final MapEntry(key: trigger, value: action) in pairs.entries) {
      app.keymap.keyPairs.add(
        KeyPair(buttons: [left], physicalKey: null, logicalKey: null, inGameAction: action, trigger: trigger),
      );
    }
    await core.settings.setKeyMap(app);
    core.actionHandler.init(app);
    // Connecting seeds a button without a single click with its own action;
    // the left button here does exactly what [pairs] say.
    app.keymap.keyPairs.removeWhere((k) => k.buttons.contains(left) && !pairs.containsKey(k.trigger));
  }

  Keymap shown() => core.actionHandler.supportedApp!.keymap;
  InGameAction? actionOn(ButtonTrigger t) => shown().getKeyPair(left, trigger: t)?.inGameAction;

  setUp(() async {
    core.connection.devices
      ..clear()
      ..add(device);
    core.settings.setTrainerApp(MyWhoosh());
    await core.settings.setClickV2OnboardingDone(true);
    propPrefs.setZwiftClickV2LastUnlock(device.scanResult.deviceId, DateTime.now());
    IAPManager.instance.isLocalPro.value = false;
  });
  tearDown(() {
    core.connection.devices.clear();
    IAPManager.instance.isLocalPro.value = false;
  });

  Future<AppLocalizations> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        scaling: BkTheme.scaling,
        theme: BkTheme.build(Brightness.dark),
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: BkComponentThemes(child: ControllerSettingsPage(device: device)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    return AppLocalizations.of(tester.element(find.byType(ControllerSettingsPage)));
  }

  Finder marker(String key) =>
      find.descendant(of: find.byKey(ValueKey(key)), matching: find.byKey(const ValueKey('hold-action-marker')));

  Future<void> openLeft(WidgetTester tester) async {
    if (find.byKey(ValueKey('mapping-trigger-${left.name}-singleClick')).evaluate().isNotEmpty) return;
    final row = find.byKey(ValueKey('mapping-row-${left.name}'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Opens the phone's action picker for [trigger] of the left button.
  Future<void> openPicker(WidgetTester tester, ButtonTrigger trigger) async {
    await openLeft(tester);
    final row = find.byKey(ValueKey('mapping-trigger-${left.name}-${trigger.name}'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  Future<void> tapAssign(WidgetTester tester) async {
    final assign = find.byKey(const ValueKey('hold-action-assign-long-press'));
    await tester.ensureVisible(assign);
    await tester.tap(assign);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  group('390 wide', () {
    testWidgets('a hold action on a click marks its button row and its trigger row', (tester) async {
      await mapLeft({ButtonTrigger.singleClick: InGameAction.steerLeft});
      await pump(tester, const Size(390, 844));
      expect(marker('mapping-row-${left.name}'), findsOneWidget);
      await openLeft(tester);
      expect(marker('mapping-trigger-${left.name}-singleClick'), findsOneWidget);
      expect(marker('mapping-trigger-${left.name}-longPress'), findsNothing);
    });

    testWidgets('on a long press there is no marker and no warning', (tester) async {
      await mapLeft({ButtonTrigger.longPress: InGameAction.steerLeft});
      await pump(tester, const Size(390, 844));
      expect(marker('mapping-row-${left.name}'), findsNothing);
      await openPicker(tester, ButtonTrigger.longPress);
      expect(find.byKey(const ValueKey('hold-action-warning')), findsNothing);
    });

    testWidgets('picking it for a single click warns; one tap moves it to the long press', (tester) async {
      await mapLeft({ButtonTrigger.singleClick: InGameAction.steerLeft});
      final l = await pump(tester, const Size(390, 844));
      await openPicker(tester, ButtonTrigger.singleClick);
      expect(find.byKey(const ValueKey('hold-action-warning')), findsOneWidget);
      expect(find.text(l.holdWarningSteering), findsOneWidget);

      await tapAssign(tester);
      expect(actionOn(ButtonTrigger.longPress), InGameAction.steerLeft);
      expect(actionOn(ButtonTrigger.singleClick), isNull);
      expect(find.byKey(const ValueKey('hold-action-warning')), findsNothing, reason: 'the picker closes');
      expect(marker('mapping-row-${left.name}'), findsNothing);
    });

    testWidgets('a double click warns too', (tester) async {
      await mapLeft({ButtonTrigger.doubleClick: InGameAction.pushToTalk});
      final l = await pump(tester, const Size(390, 844));
      await openPicker(tester, ButtonTrigger.doubleClick);
      expect(find.text(l.holdWarningAction(InGameAction.pushToTalk.title)), findsOneWidget);
      await tapAssign(tester);
      expect(actionOn(ButtonTrigger.longPress), InGameAction.pushToTalk);
      expect(actionOn(ButtonTrigger.doubleClick), isNull);
    });

    testWidgets('a long press that does something else is replaced only after asking', (tester) async {
      IAPManager.instance.isLocalPro.value = true;
      await mapLeft({ButtonTrigger.singleClick: InGameAction.steerLeft, ButtonTrigger.longPress: InGameAction.shiftUp});
      final l = await pump(tester, const Size(390, 844));
      await openPicker(tester, ButtonTrigger.singleClick);

      await tapAssign(tester);
      final askPrefix = l.holdReplaceLongPress('\u0000', '\u0001').split('\u0000').first;
      expect(find.textContaining(askPrefix), findsOneWidget, reason: 'asks before replacing the long press');
      expect(find.text(l.goPro), findsNothing, reason: 'Pro would not resolve this');
      await tester.tap(find.text(l.cancel));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(actionOn(ButtonTrigger.longPress), InGameAction.shiftUp, reason: 'cancel changes nothing');
      expect(actionOn(ButtonTrigger.singleClick), InGameAction.steerLeft);

      await tapAssign(tester);
      await tester.tap(find.text(l.replaceExisting));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(actionOn(ButtonTrigger.longPress), InGameAction.steerLeft);
      expect(actionOn(ButtonTrigger.singleClick), isNull);
    });

    testWidgets('a long press that already does the same just takes over, without asking', (tester) async {
      await mapLeft({ButtonTrigger.singleClick: InGameAction.steerLeft, ButtonTrigger.longPress: InGameAction.steerLeft});
      final l = await pump(tester, const Size(390, 844));
      await openPicker(tester, ButtonTrigger.singleClick);
      await tapAssign(tester);
      expect(find.text(l.replaceExisting), findsNothing);
      expect(actionOn(ButtonTrigger.longPress), InGameAction.steerLeft);
      expect(actionOn(ButtonTrigger.singleClick), isNull);
    });

    testWidgets('without Pro, another trigger staying beside the long press asks Pro or replace first', (
      tester,
    ) async {
      await mapLeft({
        ButtonTrigger.singleClick: InGameAction.steerLeft,
        ButtonTrigger.doubleClick: InGameAction.shiftUp,
      });
      final l = await pump(tester, const Size(390, 844));
      await openPicker(tester, ButtonTrigger.singleClick);

      await tapAssign(tester);
      expect(find.text(l.additionalTriggerAssignment), findsOneWidget);
      expect(find.text(l.goPro), findsOneWidget);
      await tester.tap(find.text(l.replaceExisting));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(actionOn(ButtonTrigger.longPress), InGameAction.steerLeft);
      expect(actionOn(ButtonTrigger.singleClick), isNull);
      expect(actionOn(ButtonTrigger.doubleClick), isNull, reason: 'without Pro the button does one thing');
    });
  });

  group('1280 wide', () {
    testWidgets('the trigger card is marked; the inline picker warns and follows the move', (tester) async {
      await mapLeft({ButtonTrigger.doubleClick: InGameAction.steerRight});
      await pump(tester, const Size(1280, 800));
      final row = find.byKey(ValueKey('mapping-row-${left.name}'));
      expect(marker('mapping-row-${left.name}'), findsOneWidget);
      await tester.tap(row);
      await tester.pump(const Duration(milliseconds: 400));
      expect(marker('mapping-trigger-card-doubleClick'), findsOneWidget);
      expect(marker('mapping-trigger-card-longPress'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('mapping-trigger-card-doubleClick')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('hold-action-warning')), findsOneWidget);

      await tapAssign(tester);
      expect(actionOn(ButtonTrigger.longPress), InGameAction.steerRight);
      expect(find.byKey(const ValueKey('hold-action-warning')), findsNothing);
      expect(marker('mapping-trigger-card-doubleClick'), findsNothing);
    });
  });
}
