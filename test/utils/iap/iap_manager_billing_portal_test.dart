// Pro bought through Stripe on the computer (Windows download, Linux) and then
// used on a phone: the store's subscription settings know nothing about it, so
// "Manage subscription" must open the Stripe billing portal there too.
import 'package:bike_control/models/subscription_term.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

IAPManager get iap => IAPManager.instance;

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'iap-manager-billing-portal-test-anon-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  setUp(() => iap.setProForTesting(enabled: true));
  tearDown(() {
    iap.setProForTesting(enabled: false);
    iap.setSubscriptionTermForTesting(null);
    iap.stripePortalForTesting = null;
  });

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    );
    return captured;
  }

  testWidgets('a Stripe subscription opens the Stripe billing portal', (tester) async {
    var opened = 0;
    iap.stripePortalForTesting = (_) async {
      opened++;
      return true;
    };
    iap.setSubscriptionTermForTesting(
      SubscriptionTerm(
        renewal: SubscriptionRenewal.unknown,
        until: DateTime(2026, 12, 1),
        store: SubscriptionStore.billingPortal,
      ),
    );

    final context = await pumpContext(tester);
    expect(await iap.openBillingPortal(context), isTrue);
    expect(opened, 1);
  });

  testWidgets('a store subscription does not open the Stripe billing portal', (tester) async {
    var opened = 0;
    iap.stripePortalForTesting = (_) async {
      opened++;
      return true;
    };
    iap.setSubscriptionTermForTesting(
      SubscriptionTerm(
        renewal: SubscriptionRenewal.renews,
        until: DateTime(2026, 12, 1),
        store: SubscriptionStore.playStore,
      ),
    );

    final context = await pumpContext(tester);
    await iap.openBillingPortal(context);
    expect(opened, 0);
  });
}
