@Tags(['screenshots'])
library;

// A press the log shows by its button ("P" for a Zwift Play paddle): the
// button is the row's tile, big enough to read, not a speck in a grey circle.
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/pages/activity/activity_log.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  testWidgets('activity rows with a button glyph', (tester) async {
    final log = ActivityLogController();
    final now = DateTime.now();
    for (final (i, gear) in [17, 16, 15].indexed) {
      log.insert(
        ActivityEntry(
          button: ZwiftButtons.paddleRight,
          time: now.subtract(Duration(minutes: 2, seconds: i * 10)),
          result: Ignored('Hochgeschaltet auf Gang $gear', button: ZwiftButtons.paddleRight),
          deviceName: 'Zwift Play (Right)',
        ),
      );
    }
    await captureWidget(tester, name: 'activity_button_glyph', width: 390, locales: const ['de'], settle: false,
        builder: (c) => ActivityLogView(controller: log, fixAction: (_) => null));
    log.dispose();
  });
}
