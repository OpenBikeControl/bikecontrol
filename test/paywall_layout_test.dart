// Regression: the paywall and SelectableCard are rendered inside scrolling
// drawers, where the cross axis is unbounded. Stretching a Row against that
// (or passing the constraints through a Stack) hands children an infinite
// height and layout dies with "RenderBox was not laid out".
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/button_edit.dart' show SelectableCard;
import 'package:bike_control/pages/paywall.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  Future<void> pumpInScrollView(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 800) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.7),
        // An unbounded-height host, exactly like the drawer's scroll view.
        home: SingleChildScrollView(child: child),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('paywall lays out inside a scroll view', (tester) async {
    IAPManager.instance.isPurchased.value = false;
    addTearDown(() => IAPManager.instance.isPurchased.value = true);
    await pumpInScrollView(tester, const Paywall(defaultToFullVersion: false));
    expect(tester.takeException(), isNull);
  });

  // Support-UX: riders bought Base expecting BikeControl-driven virtual
  // shifting — the old table's "Connect to your trainer ✓" for Base read as
  // exactly that, and later a "20 min/day" Base cell drew a Pro trial as if
  // Base had some of it. BikeControl's virtual shifting now leads the table
  // (Pro only; the trial is a footnote — see paywall_plan_chooser_test.dart),
  // then what Base covers: the app shifts, BikeControl presses the buttons.
  testWidgets('paywall rows spell out Base vs Pro, virtual shifting first', (tester) async {
    IAPManager.instance.isPurchased.value = false;
    addTearDown(() => IAPManager.instance.isPurchased.value = true);
    await pumpInScrollView(tester, const Paywall(defaultToFullVersion: false));
    expect(tester.takeException(), isNull);

    final l10n = AppLocalizations.current;
    final labelsInOrder = [
      l10n.paywall_vsByBikeControl,
      l10n.paywall_amountOfActions,
      l10n.paywall_shiftInYourApp,
      l10n.paywall_configure3ActionsPerButton,
      l10n.paywall_useBikecontrolOnAllPlatforms,
    ];
    for (final label in labelsInOrder) {
      expect(find.text(label), findsOneWidget, reason: 'row "$label" missing');
    }
    final tops = [for (final label in labelsInOrder) tester.getTopLeft(find.text(label)).dy];
    for (var i = 1; i < tops.length; i++) {
      expect(
        tops[i],
        greaterThan(tops[i - 1]),
        reason: '"${labelsInOrder[i]}" must sit below "${labelsInOrder[i - 1]}"',
      );
    }

    // The replaced rows are gone for good, not merely reordered.
    expect(find.text('Connect to your trainer'), findsNothing);
    expect(find.text('Add virtual shifting capability'), findsNothing);
    expect(find.text('Amount of actions'), findsNothing);
    expect(find.text(l10n.paywall_bikeControlShifts), findsNothing);
  });

  // Cross-store restores: Base is bound to the storefront it was bought on.
  // The note names that storefront under the Base card.
  testWidgets('Base card names the store its one-time purchase is bound to', (tester) async {
    IAPManager.instance.isPurchased.value = false;
    addTearDown(() => IAPManager.instance.isPurchased.value = true);

    // flutter_test reports Android unless overridden; reset inside the body so
    // the binding's foundation-variable check at the end of the test is clean.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pumpInScrollView(tester, const Paywall(defaultToFullVersion: true));
      expect(
        find.text(
          "One-time purchase for the App Store version. It doesn't transfer to other stores or platforms — Pro does.",
        ),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }

    await pumpInScrollView(tester, const Paywall(defaultToFullVersion: true));
    expect(
      find.text(
        "One-time purchase for the Google Play version. It doesn't transfer to other stores or platforms — Pro does.",
      ),
      findsOneWidget,
    );
  });

  test('paywallStoreName picks the storefront per platform and Windows build', () {
    String name(TargetPlatform p, {bool outsideStore = false}) =>
        paywallStoreName(p, isOutsideStoreWindowsBuild: outsideStore, directDownload: 'direct download');
    expect(name(TargetPlatform.iOS), 'App Store');
    expect(name(TargetPlatform.macOS), 'App Store');
    expect(name(TargetPlatform.android), 'Google Play');
    expect(name(TargetPlatform.windows), 'Microsoft Store');
    expect(name(TargetPlatform.windows, outsideStore: true), 'direct download');
  });

  // Which confirmation a finished purchase/restore calls for. Base bought →
  // say what Base doesn't cover; Pro landed on the account but not on this
  // device → say so and offer the registration; everything else → nothing.
  group('paywallConfirmationFor', () {
    PaywallConfirmation? outcome({
      bool basePurchase = false,
      bool wasPurchased = false,
      bool wasPro = false,
      bool isPurchased = false,
      bool isPro = false,
      bool isProForDevice = false,
      bool deviceLimitReached = false,
    }) => paywallConfirmationFor(
      isBasePurchase: basePurchase,
      wasPurchased: wasPurchased,
      wasPro: wasPro,
      isPurchased: isPurchased,
      isPro: isPro,
      isProForDevice: isProForDevice,
      deviceLimitReached: deviceLimitReached,
    );

    // The store took the payment, but the account's device limit kept this
    // device from being activated, so no entitlement arrived at all.
    test('a Pro purchase stopped by the device limit says so', () {
      expect(outcome(isPurchased: true, deviceLimitReached: true), PaywallConfirmation.proDeviceLimit);
      expect(outcome(deviceLimitReached: true), PaywallConfirmation.proDeviceLimit, reason: 'restore too');
    });

    test('the device limit is not reported for a Base purchase, or once Pro works here', () {
      expect(outcome(basePurchase: true, isPurchased: true, deviceLimitReached: true), PaywallConfirmation.baseDone);
      expect(outcome(isPro: true, isProForDevice: true, deviceLimitReached: true), isNull);
      expect(outcome(wasPro: true, deviceLimitReached: true), isNull);
    });

    test('a Base purchase that went through confirms Base', () {
      expect(outcome(basePurchase: true, isPurchased: true), PaywallConfirmation.baseDone);
    });

    test('a cancelled Base purchase confirms nothing', () {
      expect(outcome(basePurchase: true), isNull);
    });

    test('a Pro purchase that leaves this device unregistered says so', () {
      expect(outcome(isPurchased: true, isPro: true), PaywallConfirmation.proUnregistered);
    });

    test('a restore that leaves this device unregistered says so too', () {
      expect(outcome(isPurchased: true, isPro: true, wasPurchased: true), PaywallConfirmation.proUnregistered);
    });

    test('a Pro purchase that works on this device needs no dialog', () {
      expect(outcome(isPurchased: true, isPro: true, isProForDevice: true), isNull);
    });

    test('Pro that was already on the account before the attempt is not news', () {
      expect(outcome(wasPurchased: true, wasPro: true, isPurchased: true, isPro: true), isNull);
    });

    test('a Base attempt that turns out to unlock account Pro reports the Pro state, not Base', () {
      expect(outcome(basePurchase: true, isPurchased: true, isPro: true), PaywallConfirmation.proUnregistered);
    });
  });

  testWidgets('SelectableCard lays out inside a scroll view', (tester) async {
    await pumpInScrollView(
      tester,
      Column(
        children: [
          SelectableCard(title: const Text('Option'), isActive: true, onPressed: () {}),
          SelectableCard(title: const Text('Other'), subtitle: const Text('sub'), isActive: false, onPressed: () {}),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
  });

  // A long translation at a large text size used to shrink both links to fit
  // one line (FittedBox) until they were unreadably small; they wrap instead.
  testWidgets('terms and privacy links keep their size at large text instead of shrinking', (tester) async {
    IAPManager.instance.isPurchased.value = false;
    addTearDown(() => IAPManager.instance.isPurchased.value = true);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpInScrollView(tester, const Paywall(defaultToFullVersion: false));
    expect(tester.takeException(), isNull);

    final l10n = AppLocalizations.current;
    for (final link in [l10n.termsOfUse, l10n.privacyPolicy]) {
      expect(
        find.ancestor(of: find.text(link), matching: find.byType(FittedBox)),
        findsNothing,
        reason: link,
      );
    }
  });
}
