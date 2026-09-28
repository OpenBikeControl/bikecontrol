// With reduced motion the overview's tabs jump instead of sliding, and new
// activity entries appear in place instead of growing open.
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
  // The blog fetch fails without a network; a plain log is all these tests
  // need (the app's listener would start the full diagnostics gather).
  installLoggerErrorListener();
  Logger.onRecordError = (message, error, _) => debugPrint('recordError($message): $error');

  Future<void> pump(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const Scaffold(child: OverviewPage(isMobile: true)),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a tab tap jumps straight to its page', (tester) async {
    await pump(tester, size: const Size(400, 800));
    final pager = tester.widget<PageView>(find.byType(PageView)).controller!;

    await tester.tap(find.text(AppLocalizations.current.activity));
    await tester.pump();

    expect(pager.page, 1, reason: 'no slide: the page is there on the next frame');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a new activity entry appears without growing open', (tester) async {
    await pump(tester, size: const Size(1200, 900));

    const button = ControllerButton('shiftUpRight');
    core.connection.signalNotification(ActionNotification(const Success('Shifted up', button: button)));
    await tester.pump(); // delivers the notification
    await tester.pump(); // the next frame

    expect(find.text('Shifted up'), findsOneWidget);
    expect(find.ancestor(of: find.text('Shifted up'), matching: find.byType(SizeTransition)), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => throw const SocketException('no network in tests');
}
