import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/widgets/home/trial_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

Future<void> pumpTrial(WidgetTester tester, TrialCardState state) async {
  await tester.pumpWidget(
    ShadcnApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.5),
      home: Scaffold(child: SingleChildScrollView(child: TrialCard(state: state))),
    ),
  );
  await tester.pumpAndSettle();
}

TrialCardState trial({
  int daysRemaining = 3,
  bool expired = false,
  int commandsRemaining = 62,
  int commandsTotal = 80,
  int? bridgeMinutesRemaining,
  int? bridgeMinutesTotal,
  int? commandsAfterTrial,
}) {
  return TrialCardState(
    daysRemaining: daysRemaining,
    daysTotal: 5,
    expired: expired,
    commandsRemaining: commandsRemaining,
    commandsTotal: commandsTotal,
    bridgeMinutesRemaining: bridgeMinutesRemaining,
    bridgeMinutesTotal: bridgeMinutesTotal,
    commandsAfterTrial: commandsAfterTrial,
  );
}

void main() async {
  await AppLocalizations.load(const Locale('en'));
  final l = AppLocalizations();

  // Commands are capped during the trial too: RevenueCatService.canExecuteCommand
  // enforces the daily limit whatever the trial state — it only raises the
  // ceiling to 80 while the trial runs. Claiming "unlimited" here was wrong.
  testWidgets('the trial shows how many commands are left, not a promise of unlimited', (tester) async {
    await pumpTrial(tester, trial());

    expect(find.text(l.chainTrialCommandsMeter), findsOneWidget);
    expect(find.text('62'), findsOneWidget);
    expect(find.text('/ 80'), findsOneWidget);
    expect(find.textContaining('nlimited'), findsNothing);
  });

  testWidgets('the trial also shows the days left', (tester) async {
    await pumpTrial(tester, trial());
    expect(find.text(l.chainTrialDaysMeter), findsOneWidget);
  });

  testWidgets('an expired trial drops the days meter and keeps the command budget', (tester) async {
    await pumpTrial(tester, trial(expired: true, daysRemaining: 0, commandsRemaining: 4, commandsTotal: 15));

    expect(find.text(l.chainTrialDaysMeter), findsNothing);
    expect(find.text(l.chainTrialCommandsMeter), findsOneWidget);
    expect(find.text('/ 15'), findsOneWidget);
    expect(find.text(l.chainTrialExpiredTitle), findsOneWidget);
  });

  testWidgets('virtual-shifting minutes only appear when a trainer is bridged', (tester) async {
    await pumpTrial(tester, trial());
    expect(find.text(l.chainTrialBridgeMeter), findsNothing);

    await pumpTrial(tester, trial(bridgeMinutesRemaining: 12, bridgeMinutesTotal: 20));
    expect(find.text(l.chainTrialBridgeMeter), findsOneWidget);
  });

  // A rider who thinks the app is free learns mid-ride that the buttons stop;
  // the card says up front what is left once the trial ends.
  testWidgets('during the trial, the card says what remains after it', (tester) async {
    await pumpTrial(tester, trial(commandsAfterTrial: 40));
    expect(find.text(l.chainTrialAfterTrial(40)), findsOneWidget);
  });

  testWidgets('an expired trial needs no after-trial line', (tester) async {
    await pumpTrial(tester, trial(expired: true, daysRemaining: 0, commandsTotal: 40, commandsAfterTrial: 40));
    expect(find.text(l.chainTrialAfterTrial(40)), findsNothing);
  });

  // The Windows Store trial has no daily cap: commandsRemainingToday is -1
  // there. The card showed that raw as "-1 / 40".
  testWidgets('an uncapped trial shows no presses meter instead of -1', (tester) async {
    await pumpTrial(tester, trial(commandsRemaining: -1, commandsTotal: 40, commandsAfterTrial: 40));

    expect(find.text(l.chainTrialCommandsMeter), findsNothing);
    expect(find.text('-1'), findsNothing);
    expect(find.text('/ 40'), findsNothing);
    expect(find.text(l.chainTrialDaysMeter), findsOneWidget);
    expect(find.text(l.chainTrialAfterTrial(40)), findsOneWidget);
  });

  testWidgets('running low on presses turns the card amber', (tester) async {
    expect(trial(commandsRemaining: 10, commandsTotal: 120).urgent, isTrue);
    expect(trial(commandsRemaining: 62, commandsTotal: 120).urgent, isFalse);
  });

  group('urgency is earned', () {
    test('a comfortable trial is calm', () {
      expect(trial().urgent, isFalse);
    });

    test('the last day is urgent', () {
      expect(trial(daysRemaining: 1).urgent, isTrue);
    });

    test('an expired trial is urgent', () {
      expect(trial(expired: true).urgent, isTrue);
    });

    test('running low on virtual-shifting minutes is urgent', () {
      expect(trial(bridgeMinutesRemaining: 4, bridgeMinutesTotal: 20).urgent, isTrue);
      expect(trial(bridgeMinutesRemaining: 12, bridgeMinutesTotal: 20).urgent, isFalse);
    });
  });
}
