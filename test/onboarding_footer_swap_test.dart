// Repro for the paint crash Jonas hit with a SRAM connected: swapping the
// wizard footer's actions (GhostButton -> OnboardingButtonHint) while the
// shell's shadcn Row/Column is live must not corrupt shadcn's sorted paint
// order ("Null check operator used on a null value" in PaintOrderMixin.paintSorted).
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/onboarding/onboarding_models.dart';
import 'package:bike_control/pages/onboarding/onboarding_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'widget_snapshot.dart';

class _SwapHost extends StatefulWidget {
  const _SwapHost({super.key});

  @override
  State<_SwapHost> createState() => _SwapHostState();
}

class _SwapHostState extends State<_SwapHost> {
  bool connected = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1000,
      height: 700,
      child: onboardingShell(
        context,
        step: OnboardingStep.gear,
        body: const Text('body'),
        footerActions: [
          if (connected)
            PrimaryButton(onPressed: () {}, child: const Text('Continue'))
          else
            GhostButton(onPressed: () {}, child: const Text('cant find')),
        ],
        onBack: () {},
        onHelp: () {},
        onClose: () {},
      ),
    );
  }
}

Future<void> main() async {
  await ensureSnapshotHarness();

  testWidgets('footer action swap does not crash shadcn paint order', (tester) async {
    tester.view.physicalSize = const Size(1000, 700) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey<_SwapHostState>();
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
        home: _SwapHost(key: key),
      ),
    );
    await tester.pump();

    // Simulate the SRAM connecting: footer swaps to the button hint.
    key.currentState!.setState(() => key.currentState!.connected = true);
    // The hint animates forever — pump several frames like the live app does.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: 'paint crashed after footer swap (frame $i)');
    }

    // Swap back (device drops) and forward again — exercise both directions.
    key.currentState!.setState(() => key.currentState!.connected = false);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull, reason: 'paint crashed after swap-back');
    key.currentState!.setState(() => key.currentState!.connected = true);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: 'paint crashed after second swap (frame $i)');
    }
  });
}
