@Tags(['screenshots'])
library;

// A press the log shows by its button ("P" for a Zwift Play paddle): the
// button is the row's tile, big enough to read, not a speck in a grey circle.
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/connect_error_text.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/activity/activity_log.dart';
import 'package:prop/prop.dart' show LogLevel;
import 'package:universal_ble/universal_ble.dart';
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
          button: ZwiftButtons.paddleRightOutward,
          time: now.subtract(Duration(minutes: 2, seconds: i * 10)),
          result: Ignored('Hochgeschaltet auf Gang $gear', button: ZwiftButtons.paddleRightOutward),
          deviceName: 'Zwift Play (Right)',
        ),
      );
    }
    await captureWidget(tester, name: 'activity_button_glyph', width: 390, locales: const ['de'], settle: false,
        builder: (c) => ActivityLogView(controller: log, fixAction: (_) => null));
    log.dispose();
  });

  testWidgets('a failed connect reads in words', (tester) async {
    final l = await AppLocalizations.load(const Locale('de'));
    final log = ActivityLogController();
    final now = DateTime.now();
    log.insert(ActivityEntry(time: now.subtract(const Duration(minutes: 3)), alertMessage: 'HEADWIND 792D getrennt', alertLevel: LogLevel.LOGLEVEL_WARNING));
    log.insert(
      ActivityEntry(
        time: now.subtract(const Duration(minutes: 3)),
        alertMessage: l.connectionFailed(
          'HEADWIND 792D',
          connectErrorReason(
            l,
            UniversalBleException(code: UniversalBleErrorCode.deviceNotFound, message: 'Unknown deviceId'),
            retrying: true,
          ),
        ),
        alertLevel: LogLevel.LOGLEVEL_ERROR,
      ),
    );
    await captureWidget(tester, name: 'activity_connect_failed', width: 390, locales: const ['de'], settle: false,
        builder: (c) => ActivityLogView(controller: log, fixAction: (_) => null));
    log.dispose();
  });
}
