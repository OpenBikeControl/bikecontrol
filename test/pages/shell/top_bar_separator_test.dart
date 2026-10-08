// The top bar over a tab: flush with the page at the top, separated by a
// hairline once the content scrolls under it.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/home/home_page.dart';
import 'package:bike_control/pages/settings/settings_page.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:flutter/services.dart' show StandardMessageCodec;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/shell_harness.dart';
import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();
  quietShellEnvironment();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
  );

  double separatorOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(of: find.byKey(const ValueKey('shell-top-bar-separator')), matching: find.byType(AnimatedOpacity)),
      )
      .opacity;

  testWidgets('phone: no line at the top, a line once the tab scrolls, gone again on another tab', (tester) async {
    await pumpShell(tester, const Size(390, 844));
    await tester.tap(find.descendant(of: find.byType(ShellTabBar), matching: find.text(AppLocalizations.current.navSettings)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(separatorOpacity(tester), 0);

    await tester.drag(find.byType(SettingsPage), const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 500));
    expect(separatorOpacity(tester), 1);

    await tester.drag(find.byType(SettingsPage), const Offset(0, 600));
    await tester.pump(const Duration(milliseconds: 500));
    expect(separatorOpacity(tester), 0, reason: 'back at the top');

    await tester.drag(find.byType(SettingsPage), const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.descendant(of: find.byType(ShellTabBar), matching: find.text(AppLocalizations.current.navDevices)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(separatorOpacity(tester), 0, reason: 'a new tab starts at its top');
    await disposeShell(tester);
  });

  testWidgets('phone: Ride, the first tab, gets the line too', (tester) async {
    await pumpShell(tester, const Size(390, 844));
    expect(separatorOpacity(tester), 0);
    await tester.drag(find.byType(HomePage).first, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 500));
    expect(separatorOpacity(tester), 1);
    await disposeShell(tester);
  });
}
