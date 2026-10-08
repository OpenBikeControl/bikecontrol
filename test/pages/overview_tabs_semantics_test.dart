// The Activity item's red dot says something only in colour; a screen reader
// has to hear it in the item's label — in the tab bar, the top tabs and the
// sidebar alike.
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
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

  for (final size in const [Size(400, 800), Size(700, 900), Size(1000, 800)]) {
    testWidgets('at ${size.width.toInt()} wide the Activity item says it has errors, not just shows a red dot', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpShell(tester, size);
      final l10n = AppLocalizations.current;
      expect(find.semantics.byLabel(l10n.a11yTabHasErrors(l10n.activity)), findsNothing);

      const button = ControllerButton('shiftUpRight');
      core.connection.signalNotification(ActionNotification(const Error('Could not shift', button: button)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.semantics.byLabel(l10n.a11yTabHasErrors(l10n.activity)), findsOne);
      semantics.dispose();
      await disposeShell(tester);
    });
  }
}
