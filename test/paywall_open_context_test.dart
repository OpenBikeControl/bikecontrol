// Regression: "Go Pro" opened the paywall with openDrawer, which needs a
// DrawerOverlay ancestor (shadcn's Scaffold creates one) and does `parentLayer!`
// in release. The onboarding trainer picker passed the page State's own context
// — which sits ABOVE its Scaffold — so a rider on an expired trial got only a
// "Null check operator used on a null value" toast and no paywall, with no way
// forward. _showPaywall must not depend on callers getting the context right.
import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, navigatorKey;
import 'package:bike_control/pages/paywall.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/sheet_pull_to_dismiss.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  /// Mounts [home] and hands back the context captured by [capture], which the
  /// caller places above or below a Scaffold to choose whether a DrawerOverlay
  /// is in scope.
  Future<BuildContext> pumpApp(WidgetTester tester, Widget Function(void Function(BuildContext)) home) async {
    tester.view.physicalSize = const Size(390, 800) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late BuildContext captured;
    await tester.pumpWidget(
      ShadcnApp(
        // Toasts and the post-purchase dialogs go through the root navigator.
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.7),
        home: home((c) => captured = c),
      ),
    );
    await tester.pump();
    return captured;
  }

  /// Fire-and-forget: the dialog branch of _showPaywall awaits its route, so
  /// awaiting the call would hang until something dismisses the paywall.
  Future<void> tapGoPro(WidgetTester tester, BuildContext context) async {
    unawaited(IAPManager.instance.purchaseSubscription(context));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  setUp(() {
    // The paywall renders its plan cards off this; the harness leaves it true.
    IAPManager.instance.isPurchased.value = false;
    addTearDown(() => IAPManager.instance.isPurchased.value = true);
  });

  testWidgets('paywall opens from a context with no DrawerOverlay ancestor', (tester) async {
    // No Scaffold: exactly what the onboarding State's own context looked like.
    final context = await pumpApp(tester, (capture) => Builder(builder: (c) {
          capture(c);
          return const SizedBox.expand();
        }));
    expect(DrawerOverlay.maybeFind(context), isNull, reason: 'the test must actually reproduce the bad context');

    await tapGoPro(tester, context);

    expect(tester.takeException(), isNull, reason: 'openDrawer\'s parentLayer! used to throw here');
    expect(find.byType(Paywall), findsOneWidget);
    // The dialog fallback, not the drawer — SheetPullToDismiss is drawer-only.
    expect(find.byType(SheetPullToDismiss), findsNothing);
  });

  testWidgets('paywall still opens as a drawer when a DrawerOverlay is in scope', (tester) async {
    // Scaffold creates the DrawerOverlay, so this context is the healthy one —
    // guards against the fallback quietly becoming the only path.
    final context = await pumpApp(tester, (capture) => Scaffold(
          child: Builder(builder: (c) {
            capture(c);
            return const SizedBox.expand();
          }),
        ));
    expect(DrawerOverlay.maybeFind(context), isNotNull);

    await tapGoPro(tester, context);

    expect(tester.takeException(), isNull);
    expect(find.byType(Paywall), findsOneWidget);
    expect(find.byType(SheetPullToDismiss), findsOneWidget);
  });

  // Support-UX: twelve "bought Base, still 20-min trial" chats. The moment the
  // store confirms Base, the paywall closes itself (the entitlement listener)
  // — so the confirmation has to outlive the paywall: it is shown on the root
  // navigator, and it must fire off the state change, not off the purchase
  // call returning (RevenueCat's call can take seconds to come back).
  testWidgets('a Base purchase landing while the paywall is open closes it and confirms what Base covers', (
    tester,
  ) async {
    final context = await pumpApp(tester, (capture) => Scaffold(
          child: Builder(builder: (c) {
            capture(c);
            return const SizedBox.expand();
          }),
        ));
    await tapGoPro(tester, context);
    expect(find.byType(Paywall), findsOneWidget);

    // Pick Base (tap its card — the store note sits inside it) and press
    // Purchase; both sit below the fold of a phone-sized drawer. There is no
    // store behind the test, so the purchase call fails and toasts; the
    // confirmation must not depend on it succeeding in-line.
    final baseCard = find.textContaining('One-time purchase for the');
    await tester.ensureVisible(baseCard);
    await tester.pump();
    await tester.tap(baseCard);
    await tester.pump();
    final purchase = find.text('Purchase');
    await tester.ensureVisible(purchase);
    await tester.pump();
    await tester.tap(purchase);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('You now have Base'), findsNothing);

    // The store's answer arrives through the purchase flag.
    IAPManager.instance.isPurchased.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('You now have Base'), findsOneWidget);
    expect(find.textContaining('that part is Pro'), findsOneWidget);
    expect(find.byType(Paywall), findsNothing, reason: 'the drawer closes on the entitlement change');

    // Nothing is left running once the rider has read it.
    await tester.tap(find.text('Got it!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('You now have Base'), findsNothing);
  });

  testWidgets('a purchase flag that flips without a purchase attempt only closes the paywall', (tester) async {
    final context = await pumpApp(tester, (capture) => Scaffold(
          child: Builder(builder: (c) {
            capture(c);
            return const SizedBox.expand();
          }),
        ));
    await tapGoPro(tester, context);
    expect(find.byType(Paywall), findsOneWidget);

    // e.g. an entitlement refresh on resume, or a purchase made elsewhere.
    IAPManager.instance.isPurchased.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.byType(Paywall), findsNothing);
    expect(find.text('You now have Base'), findsNothing);
  });
}
