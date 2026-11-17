import 'package:bike_control/models/subscription_term.dart';
import 'package:bike_control/pages/paywall.dart';
import 'package:bike_control/pages/plan/plan_summary_card.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_snapshot.dart';

/// Renders the paywall for design review: `build/snapshots/paywall_lifetime-<locale>.png`.
Future<void> main() async {
  await ensureSnapshotHarness();

  testWidgets('paywall with the Pro forever link', (tester) async {
    IAPManager.instance.isPurchased.value = false;
    addTearDown(() => IAPManager.instance.isPurchased.value = true);
    await captureWidget(
      tester,
      name: 'paywall_lifetime',
      width: 390,
      locales: const ['en', 'de'],
      builder: (_) => Paywall(
        debugYearlyStorePrice: '24,99 €',
        debugLifetimePrice: '49,99 €',
        debugNativeTrainer: () => null,
      ),
    );
  });

  for (final (name, term, manage) in [
    (
      'plan_card_yearly',
      SubscriptionTerm(
        renewal: SubscriptionRenewal.renews,
        until: DateTime(2027, 11, 17),
        period: SubscriptionPeriod.yearly,
        store: SubscriptionStore.playStore,
      ),
      SubscriptionStore.playStore,
    ),
    (
      'plan_card_lifetime',
      const SubscriptionTerm(renewal: SubscriptionRenewal.lifetime, store: SubscriptionStore.playStore),
      null,
    ),
  ]) {
    testWidgets(name, (tester) async {
      IAPManager.instance.setProForTesting(enabled: true);
      IAPManager.instance.setSubscriptionTermForTesting(term);
      addTearDown(() {
        IAPManager.instance.setProForTesting(enabled: false);
        IAPManager.instance.setSubscriptionTermForTesting(null);
      });
      await captureWidget(
        tester,
        name: name,
        width: 390,
        locales: const ['en', 'de'],
        builder: (_) => PlanSummaryCard(
          manageTarget: manage,
          onManage: () {},
          onRegister: () {},
          registering: false,
          onQuestions: () {},
        ),
      );
    });
  }
}
