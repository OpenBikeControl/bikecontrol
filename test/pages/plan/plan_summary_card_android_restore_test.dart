// The trial plan card on Android: riders who bought BikeControl on Google Play
// before it became a free download with in-app purchases, and whose restore
// finds nothing, get a way to reach support from the card.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/plan/plan_summary_card.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  tearDown(() {
    debugHostPlatformOverride = null;
    IAPManager.instance.isPurchased.value = true;
    IAPManager.instance.setProForTesting(enabled: false);
  });

  Future<void> pumpCard(WidgetTester tester, {VoidCallback? onBoughtBefore}) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        theme: BkTheme.build(Brightness.dark),
        home: SingleChildScrollView(
          child: PlanSummaryCard(
            manageTarget: null,
            onManage: () {},
            onRegister: () {},
            registering: false,
            onQuestions: () {},
            onBoughtBefore: onBoughtBefore ?? () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  const item = ValueKey('plan-bought-before');

  testWidgets('Android, on the trial: the item is there and opens support', (tester) async {
    debugHostPlatformOverride = TargetPlatform.android;
    IAPManager.instance.isPurchased.value = false;
    var opened = 0;
    await pumpCard(tester, onBoughtBefore: () => opened++);

    expect(find.byKey(item), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(item), matching: find.byType(Button)));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('not on Base, not on Pro', (tester) async {
    debugHostPlatformOverride = TargetPlatform.android;
    IAPManager.instance.isPurchased.value = true;
    await pumpCard(tester);
    expect(find.byKey(item), findsNothing);

    IAPManager.instance.setProForTesting(enabled: true, registeredDevice: true);
    await pumpCard(tester);
    expect(find.byKey(item), findsNothing);
  });

  testWidgets('not on other platforms: the 2025 paid download was Android only', (tester) async {
    IAPManager.instance.isPurchased.value = false;
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS, TargetPlatform.windows]) {
      debugHostPlatformOverride = platform;
      await pumpCard(tester);
      expect(find.byKey(item), findsNothing, reason: '$platform');
    }
  });
}
