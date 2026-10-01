// The activity log ages its entries ("5s ago") and flags errors on its
// navigation item. Both used to rebuild the whole OverviewPage — and with it the home
// chain inside it — every five seconds and on every controller press.
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/navigation.dart';
import 'package:bike_control/pages/overview.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter/widgets.dart' as w;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/shell_harness.dart';
import '../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();
  quietShellEnvironment();

  testWidgets('a press and the ticking timestamps rebuild the log, not the page', (tester) async {
    var now = DateTime(2026, 9, 28, 12);
    activityLogClock = () => now;
    addTearDown(() => activityLogClock = DateTime.now);
    // Wide enough for Ride's latest-events preview.
    await pumpShell(tester, const Size(1300, 900));

    final pageRebuilds = <w.Element>[];
    w.debugOnRebuildDirtyWidget = (element, _) {
      if (element.widget is OverviewPage || element.widget is Navigation) pageRebuilds.add(element);
    };
    addTearDown(() => w.debugOnRebuildDirtyWidget = null);

    const button = ControllerButton('shiftUpRight');
    core.connection.signalNotification(ActionNotification(const Success('Shifted up', button: button)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Shifted up'), findsOneWidget);

    final l10n = AppLocalizations.current;
    expect(find.text(l10n.justNow), findsOneWidget);

    now = now.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text(l10n.secondsAgo('5')), findsOneWidget, reason: 'the entry still ages');

    expect(pageRebuilds, isEmpty, reason: 'neither the press nor the tick may rebuild the whole page');

    // Dispose the page so its periodic tick doesn't outlive the test.
    await disposeShell(tester);
  });
}
