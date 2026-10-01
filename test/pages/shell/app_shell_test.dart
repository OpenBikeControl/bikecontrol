// The app shell: four sections (Ride / Devices / Activity / Settings) behind a
// bottom tab bar on a phone, a floating tab bar at medium widths and a
// permanent sidebar from 840. Every width from 840 lays Ride out the same way:
// two columns, with the latest activity under the buttons.
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/pages/activity/activity_log.dart';
import 'package:bike_control/pages/activity/activity_preview.dart';
import 'package:bike_control/pages/devices/devices_page.dart';
import 'package:bike_control/pages/home/home_page.dart';
import 'package:bike_control/pages/settings/settings_page.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/pages/trainer_connection_settings.dart' show LanguageSelect;
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/plan/vs_trial_meter.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter/services.dart' show StandardMessageCodec;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../helpers/shell_harness.dart';
import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();
  quietShellEnvironment();
  // With screenshot mode off the shell keeps the screen awake; the test host
  // has no wakelock plugin.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
  );

  AppLocalizations l10n() => AppLocalizations.current;

  Finder navItem(String label) => find.bySemanticsLabel(RegExp('^${RegExp.escape(label)}'));

  testWidgets('phone: a bottom tab bar with four sections switches the content', (tester) async {
    await pumpShell(tester, const Size(390, 844));

    expect(find.byType(ShellTabBar), findsOneWidget);
    expect(find.byType(ShellSidebar), findsNothing);
    expect(find.byType(ShellTopTabs), findsNothing);
    for (final label in [l10n().navRide, l10n().navDevices, l10n().activity, l10n().navSettings]) {
      expect(
        find.descendant(of: find.byType(ShellTabBar), matching: find.text(label)),
        findsOneWidget,
        reason: '$label tab',
      );
    }
    expect(find.byType(HomePage), findsOneWidget, reason: 'Ride is the first section');

    // The tab bar sits below the content, never on top of it.
    final bar = tester.getRect(find.byType(ShellTabBar));
    final page = tester.getRect(find.byType(HomePage).first);
    expect(tester.getRect(find.byKey(const ValueKey('shell-content'))).bottom, lessThanOrEqualTo(bar.top + 0.5));
    expect(page.top, lessThan(bar.top));

    await tester.tap(find.descendant(of: find.byType(ShellTabBar), matching: find.text(l10n().navSettings)));
    await tester.pump();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing, reason: 'Ride is kept, but offstage');

    await tester.tap(find.descendant(of: find.byType(ShellTabBar), matching: find.text(l10n().navDevices)));
    await tester.pump();
    expect(find.byType(DevicesPage), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(ShellTabBar), matching: find.text(l10n().activity)));
    await tester.pump();
    expect(find.byType(ActivityLogView), findsOneWidget);

    await disposeShell(tester);
  });

  testWidgets('phone: the tab items are labelled 48 dp buttons that say which one is selected', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpShell(tester, const Size(390, 844));

    expect(
      tester.getSemantics(navItem(l10n().navRide).first),
      isSemantics(isButton: true, isSelected: true, isFocusable: true),
    );
    expect(
      tester.getSemantics(navItem(l10n().navSettings).first),
      isSemantics(isButton: true, isSelected: false),
    );

    for (final item in tester.widgetList(find.byType(ShellNavItem))) {
      final size = tester.getSize(find.byWidget(item));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    semantics.dispose();
    await disposeShell(tester);
  });

  testWidgets('medium: a top tab bar and one wide column', (tester) async {
    await pumpShell(tester, const Size(700, 1000));

    expect(find.byType(ShellTopTabs), findsOneWidget);
    expect(find.byType(ShellTabBar), findsNothing);
    expect(find.byType(ShellSidebar), findsNothing);
    final column = tester.getRect(find.byType(HomePage));
    expect(column.width, lessThanOrEqualTo(720));

    await tester.tap(find.descendant(of: find.byType(ShellTopTabs), matching: find.text(l10n().navSettings)));
    await tester.pump();
    expect(find.byType(SettingsPage), findsOneWidget);
    await disposeShell(tester);
  });

  testWidgets('expanded: a permanent sidebar with the sections, the plan and Help', (tester) async {
    await pumpShell(tester, const Size(1000, 760));

    expect(find.byType(ShellSidebar), findsOneWidget);
    expect(find.byType(ShellTabBar), findsNothing);
    expect(find.byType(ShellTopTabs), findsNothing);
    final sidebar = find.byType(ShellSidebar);
    expect(find.descendant(of: sidebar, matching: find.text(l10n().navDevices)), findsOneWidget);
    expect(find.descendant(of: sidebar, matching: find.text(l10n().troubleshootingGuide)), findsOneWidget);
    expect(find.descendant(of: sidebar, matching: find.text(l10n().currentPlan)), findsOneWidget);
    expect(find.byKey(const ValueKey('activity-column')), findsNothing);

    await tester.tap(find.descendant(of: sidebar, matching: find.text(l10n().activity)));
    await tester.pump();
    expect(find.byType(ActivityLogView), findsOneWidget);
    await disposeShell(tester);
  });

  for (final size in const [Size(1300, 800), Size(1440, 900)]) {
    testWidgets('${size.width.toInt()} wide: Ride keeps the tablet layout, no activity column', (tester) async {
      await pumpShell(tester, size);

      expect(find.byKey(const ValueKey('activity-column')), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
      // The latest few events sit under the buttons, as from 840.
      expect(find.byType(RideActivityPreview), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(ShellSidebar), matching: find.text(l10n().activity)));
      await tester.pump();
      expect(find.byType(ActivityLogView), findsOneWidget);
      await disposeShell(tester);
    });
  }

  testWidgets('an error marks the Activity item, in colour and in its spoken label', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpShell(tester, const Size(390, 844));
    final spoken = l10n().a11yTabHasErrors(l10n().activity);
    expect(find.bySemanticsLabel(spoken), findsNothing);
    expect(find.byKey(const ValueKey('activity-error-dot')), findsNothing);

    const button = ControllerButton('shiftUpRight');
    core.connection.signalNotification(ActionNotification(const Error('Could not shift', button: button)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.bySemanticsLabel(spoken), findsOneWidget);
    expect(find.byKey(const ValueKey('activity-error-dot')), findsOneWidget);
    semantics.dispose();
    await disposeShell(tester);
  });

  testWidgets('Settings holds the language picker, and no Blog row: the blog is Activity → News', (tester) async {
    await pumpShell(tester, const Size(390, 844));
    expect(find.text(l10n().blogTab), findsNothing, reason: 'no Blog tab');

    await tester.tap(find.descendant(of: find.byType(ShellTabBar), matching: find.text(l10n().navSettings)));
    await tester.pump();
    expect(find.descendant(of: find.byType(SettingsPage), matching: find.byType(LanguageSelect)), findsOneWidget);
    expect(find.descendant(of: find.byType(SettingsPage), matching: find.text(l10n().blogTab)), findsNothing);
    expect(find.descendant(of: find.byType(SettingsPage), matching: find.text(l10n().helpCenterTitle)), findsOneWidget);
    await disposeShell(tester);
  });

  group('sidebar plan card', () {
    tearDown(() {
      IAPManager.instance.setProForTesting(enabled: false);
      screenshotMode = true;
    });

    testWidgets('without Pro: what is left of today\'s virtual shifting, as in Settings', (tester) async {
      IAPManager.instance.setProForTesting(enabled: false);
      screenshotMode = false;
      await pumpShell(tester, const Size(1000, 760));
      final card = find.byKey(const ValueKey('plan-card'));
      final minutes = core.bridgeUsageTracker.remainingToday.inMinutes;
      expect(find.descendant(of: card, matching: find.byType(VsTrialMeter)), findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text(l10n().bridgeMinutesRemainingToday(minutes))),
        findsOneWidget,
      );
      await disposeShell(tester);
    });

    testWidgets('with Pro on this device, or in a store render: no meter', (tester) async {
      IAPManager.instance.setProForTesting(enabled: true, registeredDevice: true);
      screenshotMode = false;
      await pumpShell(tester, const Size(1000, 760));
      expect(find.byType(VsTrialMeter), findsNothing);
      await disposeShell(tester);

      IAPManager.instance.setProForTesting(enabled: false);
      screenshotMode = true;
      await pumpShell(tester, const Size(1000, 760));
      expect(find.byType(VsTrialMeter), findsNothing);
      await disposeShell(tester);
    });
  });

  group('desktop header device chips', () {
    final controller = ZwiftClickV2(BleDevice(name: 'Zwift Click', deviceId: 'shell-chip-click'))
      ..isConnected = true
      ..batteryLevel = 81;
    tearDown(() {
      core.connection.devices.clear();
      core.connection.hasDevices.value = false;
    });

    testWidgets('from 840: the controller with its battery; a tap opens Devices', (tester) async {
      core.connection.devices
        ..clear()
        ..add(controller);
      core.connection.hasDevices.value = true;
      await pumpShell(tester, const Size(1280, 800));
      final chips = find.byKey(const ValueKey('shell-device-chips'));
      expect(chips, findsOneWidget);
      expect(find.descendant(of: chips, matching: find.text(controller.toString())), findsOneWidget);
      expect(find.descendant(of: chips, matching: find.text('81%')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('shell-device-chip-controller')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DevicesPage), findsOneWidget);
      await disposeShell(tester);
    });

    testWidgets('no devices, no chips; none on the phone', (tester) async {
      await pumpShell(tester, const Size(1280, 800));
      expect(find.byKey(const ValueKey('shell-device-chips')), findsNothing);
      await disposeShell(tester);

      core.connection.devices
        ..clear()
        ..add(controller);
      core.connection.hasDevices.value = true;
      await pumpShell(tester, const Size(390, 844));
      expect(find.byKey(const ValueKey('shell-device-chips')), findsNothing);
      await disposeShell(tester);
    });
  });

  testWidgets('from 840: Settings\' column is centred in the content area', (tester) async {
    await pumpShell(tester, const Size(1280, 800));
    await tester.tap(find.descendant(of: find.byType(ShellSidebar), matching: find.text(l10n().navSettings)));
    await tester.pump();
    final sidebar = tester.getRect(find.byType(ShellSidebar));
    final settings = tester.getRect(find.byType(SettingsPage));
    final contentCentre = (sidebar.right + 1280) / 2;
    expect(settings.width, lessThanOrEqualTo(720));
    expect((settings.center.dx - contentCentre).abs(), lessThan(2));
    await disposeShell(tester);
  });
}
