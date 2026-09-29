// The app shell: four sections (Ride / Devices / Activity / Settings) behind a
// bottom tab bar on a phone, a floating tab bar at medium widths and a
// permanent sidebar from 840. From 1200 Ride carries the activity log as a
// permanent right column.
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/activity/activity_log.dart';
import 'package:bike_control/pages/devices/devices_page.dart';
import 'package:bike_control/pages/home/home_page.dart';
import 'package:bike_control/pages/settings/settings_page.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/pages/trainer_connection_settings.dart' show LanguageSelect;
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/shell_harness.dart';
import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();
  quietShellEnvironment();

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
    expect(find.byKey(const ValueKey('activity-column')), findsNothing, reason: 'not below 1200');

    await tester.tap(find.descendant(of: sidebar, matching: find.text(l10n().activity)));
    await tester.pump();
    expect(find.byType(ActivityLogView), findsOneWidget);
    await disposeShell(tester);
  });

  testWidgets('wide: Ride shows the activity log as a permanent right column', (tester) async {
    await pumpShell(tester, const Size(1300, 800));

    expect(find.byKey(const ValueKey('activity-column')), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const ValueKey('activity-column'))).left,
      greaterThan(tester.getRect(find.byType(HomePage)).right),
    );

    // The Activity item still opens the full log.
    await tester.tap(find.descendant(of: find.byType(ShellSidebar), matching: find.text(l10n().activity)));
    await tester.pump();
    expect(find.byKey(const ValueKey('activity-column')), findsNothing);
    expect(find.byType(ActivityLogView), findsOneWidget);
    await disposeShell(tester);
  });

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

  testWidgets('Settings holds the language picker, and there is no Blog tab any more', (tester) async {
    await pumpShell(tester, const Size(390, 844));
    expect(find.text(l10n().blogTab), findsNothing, reason: 'no Blog tab');

    await tester.tap(find.descendant(of: find.byType(ShellTabBar), matching: find.text(l10n().navSettings)));
    await tester.pump();
    expect(find.descendant(of: find.byType(SettingsPage), matching: find.byType(LanguageSelect)), findsOneWidget);
    expect(find.descendant(of: find.byType(SettingsPage), matching: find.text(l10n().blogTab)), findsOneWidget);
    expect(find.descendant(of: find.byType(SettingsPage), matching: find.text(l10n().helpCenterTitle)), findsOneWidget);
    await disposeShell(tester);
  });
}
