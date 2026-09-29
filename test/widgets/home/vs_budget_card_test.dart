// Base owners lose the trial card the moment they buy — but BikeControl's
// virtual shifting is Pro, so its daily budget still applies to them
// (ProxyDevice._syncBridgeTracking). They hit the limit without ever seeing
// it coming. With a bridged trainer, a Base owner now sees today's budget
// and that Pro removes it.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/widgets/home/trial_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() async {
  await AppLocalizations.load(const Locale('en'));
  final l = AppLocalizations();

  group('vsBudgetCardState', () {
    VsBudgetCardState? state({
      bool purchased = true,
      bool pro = false,
      bool bridged = true,
      Duration remaining = const Duration(minutes: 14),
    }) => vsBudgetCardState(
      isPurchased: purchased,
      isProForDevice: pro,
      trainerBridged: bridged,
      remainingToday: remaining,
      dailyLimit: const Duration(minutes: 20),
    );

    test('a Base owner with a bridged trainer gets the budget', () {
      final s = state()!;
      expect(s.minutesRemaining, 14);
      expect(s.minutesTotal, 20);
    });

    test('nothing without a bridged trainer, for Pro, or before buying (the trial card covers that)', () {
      expect(state(bridged: false), isNull);
      expect(state(pro: true), isNull);
      expect(state(purchased: false), isNull);
    });

    test('a negative remainder reads as zero', () {
      expect(state(remaining: const Duration(minutes: -3))!.minutesRemaining, 0);
    });
  });

  testWidgets('the card shows the budget and that Pro removes it', (tester) async {
    var upgraded = 0;
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.5),
        home: Scaffold(
          child: VsBudgetCard(
            state: const VsBudgetCardState(minutesRemaining: 14, minutesTotal: 20),
            onUpgrade: () => upgraded++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l.chainTrialBridgeMeter), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('/ 20 ${l.chainTrialBridgeMeterSuffix}'), findsOneWidget);
    expect(find.text(l.vsBudgetProRemovesLimit), findsOneWidget);
    await tester.tap(find.text(l.vsBudgetProRemovesLimit));
    expect(upgraded, 1);
  });
}
