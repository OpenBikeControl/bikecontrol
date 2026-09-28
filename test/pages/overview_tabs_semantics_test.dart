// The Activity tab's red dot and the Blog tab's blue dot say something only
// in colour; a screen reader has to hear it in the tab's label.
import 'dart:io';

import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show installLoggerErrorListener;
import 'package:bike_control/pages/overview.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/utils/shared.dart' show Logger;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();
  HttpOverrides.global = _NoNetwork();
  installLoggerErrorListener();
  Logger.onRecordError = (message, error, _) => debugPrint('recordError($message): $error');

  testWidgets('the Activity tab says it has errors, not just shows a red dot', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: const Scaffold(child: OverviewPage(isMobile: true)),
      ),
    );
    await tester.pump();
    final l10n = AppLocalizations.current;
    expect(find.semantics.byLabel(l10n.a11yTabHasErrors(l10n.activity)), findsNothing);

    const button = ControllerButton('shiftUpRight');
    core.connection.signalNotification(ActionNotification(const Error('Could not shift', button: button)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.semantics.byLabel(l10n.a11yTabHasErrors(l10n.activity)), findsOne);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => throw const SocketException('no network in tests');
}
