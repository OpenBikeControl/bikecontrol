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

  // The Pro card says what riding with Pro feels like, in five moments, led
  // by the shifting; Base is one line, and never claims BikeControl's
  // virtual shifting (riders bought Base expecting it).
  testWidgets('the Pro card leads with shifting, then drivetrain, buttons, screen and devices; Base has one line', (
    tester,
  ) async {
    IAPManager.instance.isPurchased.value = false;
    addTearDown(() => IAPManager.instance.isPurchased.value = true);
    await pumpInScrollView(tester, Paywall(debugNativeTrainer: () => null));
    expect(tester.takeException(), isNull);

    final l10n = AppLocalizations.current;
    final titlesInOrder = [
      l10n.paywallFeelShiftTitle,
      l10n.paywallFeelDrivetrainTitle,
      l10n.paywallFeelGesturesTitle,
      l10n.paywallFeelScreenTitle,
      l10n.paywallFeelDevicesTitle,
    ];
    final proCard = find.byKey(const ValueKey('paywall-pro-card'));
    final baseCard = find.byKey(const ValueKey('paywall-base-card'));
    Finder inPro(String label) => find.descendant(of: proCard, matching: find.text(label));
    expect(inPro(l10n.paywallProTagline.toUpperCase()), findsOneWidget);
    for (final title in titlesInOrder) {
      expect(inPro(title), findsOneWidget, reason: 'moment "$title" missing');
    }
    final tops = [for (final title in titlesInOrder) tester.getTopLeft(inPro(title)).dy];
    for (var i = 1; i < tops.length; i++) {
      expect(
        tops[i],
        greaterThan(tops[i - 1]),
        reason: '"${titlesInOrder[i]}" must sit below "${titlesInOrder[i - 1]}"',
      );
    }

    // Base: one line, and the trainer app does the shifting.
    expect(find.descendant(of: baseCard, matching: find.text(l10n.paywallBaseShift)), findsOneWidget);
    for (final title in titlesInOrder) {
      expect(find.descendant(of: baseCard, matching: find.text(title)), findsNothing);
    }

    // The old feature list is gone.
    expect(find.text(l10n.paywall_vsByBikeControl), findsNothing);
    expect(find.text(l10n.paywall_amountOfActions), findsNothing);
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
      bool isSignedIn = true,
    }) => paywallConfirmationFor(
      isBasePurchase: basePurchase,
      wasPurchased: wasPurchased,
      wasPro: wasPro,
      isPurchased: isPurchased,
      isPro: isPro,
      isProForDevice: isProForDevice,
      deviceLimitReached: deviceLimitReached,
      isSignedIn: isSignedIn,
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

    // Store Pro bought without an account stays on this device only; the
    // rider needs to hear that signing in brings it to their other devices.
    test('Pro bought while signed out asks to sign in', () {
      expect(
        outcome(isPurchased: true, isPro: true, isProForDevice: true, isSignedIn: false),
        PaywallConfirmation.proSignIn,
      );
      expect(
        outcome(isPurchased: true, isPro: true, isSignedIn: false),
        PaywallConfirmation.proSignIn,
        reason: 'registering needs an account, so sign-in comes first',
      );
    });

    test('signed out, Base or no new Pro asks nothing about signing in', () {
      expect(outcome(basePurchase: true, isPurchased: true, isSignedIn: false), PaywallConfirmation.baseDone);
      expect(outcome(wasPro: true, isPro: true, isProForDevice: true, isSignedIn: false), isNull);
      expect(outcome(isSignedIn: false), isNull);
    });

    test('a Base attempt that turns out to unlock account Pro reports the Pro state, not Base', () {
      expect(outcome(basePurchase: true, isPurchased: true, isPro: true), PaywallConfirmation.proUnregistered);
    });
  });

  // Base is free on Linux: the Base card is the rider's plan from the start,
  // and the store note (a one-time purchase bound to a store) does not apply.
  testWidgets('on Linux Base is the rider\'s free plan, without a store note', (tester) async {
    IAPManager.instance.isPurchased.value = true;
    IAPManager.instance.purchaseChannelForTesting = PurchaseChannel.linuxDirect;
    addTearDown(() => IAPManager.instance.purchaseChannelForTesting = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await pumpInScrollView(tester, const Paywall(defaultToFullVersion: false));
      final l10n = AppLocalizations.current;
      expect(find.text(l10n.paywall_baseFreeOnLinux), findsOneWidget);
      expect(find.textContaining(l10n.paywall_baseStoreNote('').split(' ').first), findsNothing);
      expect(find.text(l10n.paywall_buyBase), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  // Restore asks the app store; the Windows download and the Microsoft Store
  // build have nothing for it to find, so the button would do nothing there.
  group('restore purchases on the paywall', () {
    tearDown(() => IAPManager.instance.purchaseChannelForTesting = null);

    for (final channel in PurchaseChannel.values) {
      testWidgets('${channel.name}: shown only where the store can restore', (tester) async {
        IAPManager.instance.isPurchased.value = false;
        addTearDown(() => IAPManager.instance.isPurchased.value = true);
        IAPManager.instance.purchaseChannelForTesting = channel;
        await pumpInScrollView(tester, const Paywall(defaultToFullVersion: false));
        final l10n = AppLocalizations.current;
        expect(find.text(l10n.restorePurchases), channel.canRestore ? findsOneWidget : findsNothing);
      });
    }
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
