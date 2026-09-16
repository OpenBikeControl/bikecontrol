// Support-UX: nine "Pro (unregistered device)" chats where the only hint was
// the title bar's status line. Riders in that state (Pro on the account, this
// device not registered) now get a banner on Home that says so and carries
// the fix — "Register this device" — and it stays until the state clears.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/home/home_page.dart';
import 'package:bike_control/pages/home/pro_unregistered_banner.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  const title = 'Pro is on your account, not on this device';
  const body = 'Virtual shifting stays limited here until you register this device.';
  const register = 'Register this device';

  tearDown(() => IAPManager.instance.setProForTesting(enabled: false));

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(child: home),
      ),
    );
    await tester.pump();
  }

  testWidgets('Home shows the banner and a register button when Pro is on the account but not this device', (
    tester,
  ) async {
    IAPManager.instance.setProForTesting(enabled: true, registeredDevice: false);
    await pump(tester, HomePage(isMobile: true, onUpdate: () {}));

    expect(find.byType(ProUnregisteredBanner), findsOneWidget);
    expect(find.text(title), findsOneWidget);
    expect(find.text(body), findsOneWidget);
    expect(find.widgetWithText(Button, register), findsOneWidget);
  });

  testWidgets('nothing when this device is registered for Pro', (tester) async {
    IAPManager.instance.setProForTesting(enabled: true, registeredDevice: true);
    await pump(tester, const ProUnregisteredBanner());

    expect(find.text(title), findsNothing);
    expect(find.text(register), findsNothing);
  });

  testWidgets('nothing without Pro at all', (tester) async {
    IAPManager.instance.setProForTesting(enabled: false);
    await pump(tester, const ProUnregisteredBanner());

    expect(find.text(title), findsNothing);
    expect(find.text(register), findsNothing);
  });

  testWidgets('follows the IAP notifiers without a remount', (tester) async {
    IAPManager.instance.setProForTesting(enabled: false);
    await pump(tester, const ProUnregisteredBanner());
    expect(find.text(title), findsNothing);

    // Pro lands on the account (e.g. a restore) while this device stays out.
    IAPManager.instance.setProForTesting(enabled: true, registeredDevice: false);
    await tester.pump();
    expect(find.text(title), findsOneWidget);

    // ...and clears again once the state is gone.
    IAPManager.instance.setProForTesting(enabled: false);
    await tester.pump();
    expect(find.text(title), findsNothing);
  });

  testWidgets('has no dismiss affordance', (tester) async {
    IAPManager.instance.setProForTesting(enabled: true, registeredDevice: false);
    await pump(tester, const ProUnregisteredBanner());

    expect(find.byType(Dismissible), findsNothing);
    expect(find.byIcon(LucideIcons.x), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('the button runs the registration', (tester) async {
    IAPManager.instance.setProForTesting(enabled: true, registeredDevice: false);
    var calls = 0;
    await pump(
      tester,
      ProUnregisteredBanner(register: (_) async {
        calls++;
        return true;
      }),
    );

    await tester.tap(find.widgetWithText(Button, register));
    await tester.pump();

    expect(calls, 1);
  });
}
