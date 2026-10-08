// The paywall in both themes and to assistive tech: text reads against what
// is painted behind it, plan cards are selectable buttons, and the purchase
// button is a real, focusable button.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/paywall.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'helpers/contrast.dart';
import 'helpers/touch_targets.dart';
import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  Future<ThemeData> pump(WidgetTester tester, Brightness brightness) async {
    tester.view.physicalSize = const Size(390, 1400) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    IAPManager.instance.isPurchased.value = false;
    addTearDown(() => IAPManager.instance.isPurchased.value = true);
    // A store build, where Restore purchases is on the paywall.
    IAPManager.instance.purchaseChannelForTesting = PurchaseChannel.appStore;
    addTearDown(() => IAPManager.instance.purchaseChannelForTesting = null);
    final theme = BkTheme.build(brightness);
    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: theme,
        darkTheme: theme,
        themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        home: const SingleChildScrollView(child: Paywall(defaultToFullVersion: false)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return theme;
  }

  for (final brightness in Brightness.values) {
    testWidgets('$brightness: all paywall text is legible', (tester) async {
      final theme = await pump(tester, brightness);
      expectLegibleText(tester, find.byType(Paywall), pageBackground: theme.colorScheme.background);
    });
  }

  testWidgets('plan cards are buttons that report which one is selected', (tester) async {
    await pump(tester, Brightness.light);
    final handle = tester.ensureSemantics();
    final l10n = AppLocalizations.of(tester.element(find.byType(Paywall)));

    final yearly = find.semantics.byLabel(RegExp(l10n.paywall_yearly));
    final monthly = find.semantics.byLabel(RegExp(l10n.paywall_monthly));
    expect(yearly, findsOne);
    expect(monthly, findsOne);
    expect(yearly, isSemantics(isButton: true, isSelected: true, hasTapAction: true));
    expect(monthly, isSemantics(isButton: true, isSelected: false, hasTapAction: true));

    await tester.ensureVisible(find.text(l10n.paywall_monthly));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(l10n.paywall_monthly));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.semantics.byLabel(RegExp(l10n.paywall_monthly)), isSemantics(isSelected: true));
    expect(find.semantics.byLabel(RegExp(l10n.paywall_yearly)), isSemantics(isSelected: false));
    handle.dispose();
  });

  testWidgets('the purchase button is a focusable, labelled button', (tester) async {
    await pump(tester, Brightness.light);
    final handle = tester.ensureSemantics();
    final l10n = AppLocalizations.of(tester.element(find.byType(Paywall)));
    expect(
      // Named after the plan it buys; Pro yearly is preselected.
      find.semantics.byLabel(l10n.paywall_startProYearly),
      isSemantics(isButton: true, hasTapAction: true, isFocusable: true, isEnabled: true),
    );
    handle.dispose();
  });

  testWidgets('paywall meets the labelled tap-target guideline', (tester) async {
    await pump(tester, Brightness.light);
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets("the paywall's purchase and restore buttons meet Android's 48 dp target on a phone", (tester) async {
    await pump(tester, Brightness.light);
    final handle = tester.ensureSemantics();
    final l10n = AppLocalizations.of(tester.element(find.byType(Paywall)));
    for (final label in [l10n.paywall_startProYearly, l10n.restorePurchases]) {
      final rect = find.semantics.byLabel(label).evaluate().first.rect;
      expect(rect.height, greaterThanOrEqualTo(47.5), reason: '$label: $rect');
      expect(rect.width, greaterThanOrEqualTo(47.5), reason: '$label: $rect');
    }
    expect(actionButtonsBelowAndroidTarget(tester), isEmpty);
    handle.dispose();
  });
}
