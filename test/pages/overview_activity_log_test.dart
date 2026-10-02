// On phones the activity log is the middle page of a PageView that does not
// keep its pages alive. Clearing the log (or logging while the page was
// off-screen) used to leave the list's item count stale, so swiping back to
// the page threw a RangeError per row (grey error boxes in release builds),
// or silently showed too few rows.
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

import '../widget_snapshot.dart' show ensureSnapshotAppState;

Future<void> main() async {
  // The plain test binding (not the snapshot harness's integration binding);
  // ensureSnapshotAppState() only brings up settings/Supabase so the page
  // mounts. In setUpAll: Supabase's initialisation needs a running test zone.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await ensureSnapshotAppState();
    // After the bootstrap (Supabase's init needs an HttpClient): the blog tab
    // fetches bikecontrol.app, which must fail at once instead of hanging.
    HttpOverrides.global = _NoNetwork();
  });
  installLoggerErrorListener();
  Logger.onRecordError = (message, error, _) => debugPrint('recordError($message): $error');

  const button = ControllerButton('shiftUpRight');

  Future<void> pumpPhoneOverview(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
  }

  Future<void> log(WidgetTester tester, String message) async {
    core.connection.signalNotification(ActionNotification(Success(message, button: button)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> goToPage(WidgetTester tester, int page) async {
    tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(page);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> rebuildPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 760);
    await tester.pump();
  }

  Future<void> disposePage(WidgetTester tester) async {
    // Dispose the page so its periodic tick doesn't outlive the test.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  }

  testWidgets('clearing the log, then swiping away and back, does not throw', (tester) async {
    await pumpPhoneOverview(tester);
    await goToPage(tester, 1);
    for (var i = 0; i < 5; i++) {
      await log(tester, 'Shifted $i');
    }
    expect(find.text('Shifted 4'), findsOneWidget);

    // Anything that rebuilds the page while the log holds entries (here the
    // window resizing, e.g. split screen) bakes the current count into it.
    await rebuildPage(tester);

    await tester.tap(find.text(AppLocalizations.current.clear));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Shifted 4'), findsNothing);

    await goToPage(tester, 2);
    await goToPage(tester, 1);

    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.textContaining('Shifted'), findsNothing);

    await disposePage(tester);
  });

  testWidgets('entries logged while the activity page is off-screen show when it comes back', (tester) async {
    await pumpPhoneOverview(tester);
    await goToPage(tester, 1);
    await log(tester, 'Shifted 0');

    await goToPage(tester, 2);
    await log(tester, 'Shifted 1');
    await log(tester, 'Shifted 2');

    await goToPage(tester, 1);

    expect(tester.takeException(), isNull);
    expect(find.text('Shifted 0'), findsOneWidget);
    expect(find.text('Shifted 1'), findsOneWidget);
    expect(find.text('Shifted 2'), findsOneWidget);

    await disposePage(tester);
  });
}

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => throw const SocketException('no network in tests');
}
