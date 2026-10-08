// With reduced motion the sections switch in place, and new activity entries
// appear in place instead of growing open.
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/activity/activity_log.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/shell_harness.dart';
import '../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();
  quietShellEnvironment();

  testWidgets('a tab tap shows its section on the next frame, without a transition', (tester) async {
    await pumpShell(tester, const Size(400, 800), reduceMotion: true);

    await tester.tap(
      find.descendant(of: find.byType(ShellTabBar), matching: find.text(AppLocalizations.current.activity)),
    );
    await tester.pump();

    expect(find.byType(ActivityLogView), findsOneWidget, reason: 'no slide: the section is there on the next frame');
    expect(find.ancestor(of: find.byType(ActivityLogView), matching: find.byType(AnimatedSwitcher)), findsNothing);
    expect(find.ancestor(of: find.byType(ActivityLogView), matching: find.byType(PageView)), findsNothing);
    await disposeShell(tester);
  });

  testWidgets('a new activity entry appears without growing open', (tester) async {
    await pumpShell(tester, const Size(1300, 900), reduceMotion: true);

    const button = ControllerButton('shiftUpRight');
    core.connection.signalNotification(ActionNotification(const Success('Shifted up', button: button)));
    await tester.pump(); // delivers the notification
    await tester.pump(); // the next frame

    expect(find.text('Shifted up'), findsOneWidget);
    expect(find.ancestor(of: find.text('Shifted up'), matching: find.byType(SizeTransition)), findsNothing);
    await disposeShell(tester);
  });
}
