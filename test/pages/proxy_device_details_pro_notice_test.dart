import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details/virtual_shifting_pro_notice.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../widget_snapshot.dart';

Future<void> main() async {
  // The notice reads IAPManager, whose entitlements client needs the harness's
  // Supabase bootstrap.
  await ensureSnapshotHarness();

  setUp(() => IAPManager.instance.setProForTesting(enabled: false));
  tearDown(() => IAPManager.instance.setProForTesting(enabled: false));

  Future<void> pumpNotice(WidgetTester tester, {Duration remaining = const Duration(minutes: 20)}) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: VirtualShiftingProNotice(
            trainerAppName: 'Zwift',
            remainingToday: remaining,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows virtual-shifting Pro note and Go Pro button', (tester) async {
    await pumpNotice(tester);

    expect(find.textContaining('Virtual shifting is a Pro feature'), findsOneWidget);
    expect(find.textContaining('20 min per day'), findsOneWidget);
    expect(find.text('Go Pro'), findsOneWidget);
  });

  testWidgets('shows remaining minutes line', (tester) async {
    await pumpNotice(tester, remaining: const Duration(minutes: 12, seconds: 30));
    expect(find.text('13 min remaining today'), findsOneWidget); // 12m30s ceils to 13
  });

  // Support-UX: a rider whose account already has Pro was told to "Go Pro" —
  // the actual fix is registering this device.
  testWidgets('Pro on the account but not this device: register CTA instead of Go Pro', (tester) async {
    IAPManager.instance.setProForTesting(enabled: true, registeredDevice: false);
    await pumpNotice(tester, remaining: const Duration(minutes: 12, seconds: 30));

    expect(find.text('Register this device'), findsOneWidget);
    expect(find.text('Go Pro'), findsNothing);
    expect(find.textContaining('Virtual shifting stays limited here until you register this device'), findsOneWidget);
    expect(find.textContaining('Virtual shifting is a Pro feature'), findsNothing);
    // The daily budget still applies here, so the counter stays.
    expect(find.text('13 min remaining today'), findsOneWidget);
  });

  testWidgets('Pro on this device: nothing to say', (tester) async {
    IAPManager.instance.setProForTesting(enabled: true, registeredDevice: true);
    await pumpNotice(tester);

    expect(find.text('Register this device'), findsNothing);
    expect(find.text('Go Pro'), findsNothing);
    expect(find.textContaining('Virtual shifting'), findsNothing);
  });
}
