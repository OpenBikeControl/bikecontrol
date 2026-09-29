// Button mapping on a controller's page: on a phone one list, a group per
// button that opens into its three triggers; from 860 wide a master–detail,
// the buttons on the left and the picked button's triggers and actions on
// the right. Without Pro, a button's triggers beyond its one action carry
// the PRO badge.
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/keymap/mapping.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/utils/prefs.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  final device = ZwiftClickV2(BleDevice(name: 'Zwift Click', deviceId: 'mapping-click'))
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

  /// Opens [row]'s group unless it is the one already open.
  Future<void> openRow(WidgetTester tester, Finder row) async {
    final name = (tester.widget(row).key! as ValueKey<String>).value.replaceFirst('mapping-row-', '');
    if (find.byKey(ValueKey('mapping-trigger-$name-singleClick')).evaluate().isNotEmpty) return;
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pump(const Duration(milliseconds: 400));
  }

  final buttons = mappingButtonsOf(device);
  final keymap = MyWhoosh().keymap;
  // A button MyWhoosh gives a single-click action.
  final mapped = buttons.firstWhere((b) {
    final kp = keymap.getKeyPair(b, trigger: ButtonTrigger.singleClick);
    return kp != null && !kp.hasNoAction;
  });

  testWidgets('390 wide: one list, a group per button that opens into its triggers', (tester) async {
    await pump(tester, const Size(390, 844));
    expect(find.byKey(const ValueKey('mapping-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('mapping-detail')), findsNothing);
    for (final b in buttons) {
      expect(find.byKey(ValueKey('mapping-row-${b.name}')), findsOneWidget, reason: b.name);
    }

    // It opens on the first button; another one opens in its place.
    expect(find.byKey(ValueKey('mapping-trigger-${buttons.first.name}-singleClick')), findsOneWidget);
    final row = find.byKey(ValueKey('mapping-row-${mapped.name}'));
    await openRow(tester, row);
    for (final trigger in ButtonTrigger.values) {
      expect(find.byKey(ValueKey('mapping-trigger-${mapped.name}-${trigger.name}')), findsOneWidget);
    }
    final single = tester.getRect(find.byKey(ValueKey('mapping-trigger-${mapped.name}-singleClick')));
    expect(single.top, greaterThan(tester.getRect(row).top), reason: 'the triggers open under their button');
  });

  testWidgets('without Pro, the triggers beyond a button\'s one action carry PRO', (tester) async {
    await pump(tester, const Size(390, 844));
    await openRow(tester, find.byKey(ValueKey('mapping-row-${mapped.name}')));
    Finder badgeIn(ButtonTrigger t) => find.descendant(
      of: find.byKey(ValueKey('mapping-trigger-${mapped.name}-${t.name}')),
      matching: find.byType(ProBadge),
    );
    expect(badgeIn(ButtonTrigger.singleClick), findsNothing);
    expect(badgeIn(ButtonTrigger.doubleClick), findsOneWidget);
    expect(badgeIn(ButtonTrigger.longPress), findsOneWidget);
  });

  testWidgets('1180 wide: master–detail — buttons left, the picked one\'s triggers right', (tester) async {
    await pump(tester, const Size(1180, 820));
    final list = find.byKey(const ValueKey('mapping-list'));
    final detail = find.byKey(const ValueKey('mapping-detail'));
    expect(list, findsOneWidget);
    expect(detail, findsOneWidget);
    expect(tester.getRect(detail).left, greaterThan(tester.getRect(list).right));
    for (final trigger in ButtonTrigger.values) {
      expect(find.byKey(ValueKey('mapping-trigger-card-${trigger.name}')), findsOneWidget);
    }

    // Picking another button shows its detail.
    final other = buttons.firstWhere((b) => b.name != buttons.first.name);
    await tester.tap(find.byKey(ValueKey('mapping-row-${other.name}')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.descendant(of: detail, matching: find.byKey(ValueKey('mapping-detail-${other.name}'))),
      findsOneWidget,
    );
    // No trigger rows inline: the detail carries them.
    expect(find.byKey(ValueKey('mapping-trigger-${other.name}-singleClick')), findsNothing);
  });

  testWidgets('1180 wide: a built-in mapping asks to be copied; a custom one shows the actions inline', (
    tester,
  ) async {
    final l = await pump(tester, const Size(1180, 820));
    expect(find.text(l.mappingEditMakesCopy('MyWhoosh')), findsOneWidget);
    expect(find.byType(ButtonEditPage), findsNothing);

    await tester.tap(find.byKey(const ValueKey('mapping-trigger-card-singleClick')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(core.actionHandler.supportedApp, isA<CustomApp>(), reason: 'editing copies the built-in mapping');
    expect(find.byType(ButtonEditPage), findsOneWidget, reason: 'the action picker is inline');
  });
}
