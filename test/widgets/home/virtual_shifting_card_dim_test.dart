// Ride's shifting card while the trainer is not connected: − / + still move
// the number, but nothing the rider feels changes. The card says so, and the
// buttons only buzz when a shift actually lands on the trainer.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/home/virtual_shifting_card.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/live_trainer.dart';

void main() {
  late List<String> haptics;

  // A shift reports itself to the action handler; nothing here acts on it.
  setUpAll(() => core.actionHandler = StubActions());

  setUp(() {
    haptics = [];
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add('${call.arguments}');
        return null;
      },
    );
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  Future<void> pumpCard(
    WidgetTester tester,
    FitnessBikeDefinition definition, {
    bool dim = false,
    String? trialNotice,
  }) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [...ShadcnLocalizations.localizationsDelegates, AppLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: VirtualShiftingCard(
              definition: definition,
              trainerName: 'KICKR CORE',
              dim: dim,
              dimNotice: dim ? 'not connected notice' : null,
              trialNotice: trialNotice,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// A shift paces its write to the trainer on a timer; let it run out.
  Future<void> settleShift(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  Finder shiftUp() => find.bySemanticsLabel(AppLocalizations.current.actionShiftUp);

  testWidgets('dimmed, the card says why the gears do nothing', (tester) async {
    final definition = attachLiveTrainer(register: false).definition;
    await pumpCard(tester, definition, dim: true);
    expect(find.byKey(const ValueKey('ride-vs-dim-notice')), findsOneWidget);
    expect(find.text('not connected notice'), findsOneWidget);
  });

  testWidgets('connected, there is no such line', (tester) async {
    final definition = attachLiveTrainer(register: false).definition;
    await pumpCard(tester, definition);
    expect(find.byKey(const ValueKey('ride-vs-dim-notice')), findsNothing);
  });

  testWidgets('a shift that lands buzzes', (tester) async {
    final definition = attachLiveTrainer(register: false).definition;
    await pumpCard(tester, definition);
    final before = definition.currentGear.value;
    await tester.tap(shiftUp());
    await tester.pump();
    expect(definition.currentGear.value, before + 1);
    expect(haptics, isNotEmpty);
    await settleShift(tester);
  });

  testWidgets('at the top gear, + does not buzz', (tester) async {
    final definition = attachLiveTrainer(register: false).definition;
    definition.setTargetGear(definition.maxGear);
    await pumpCard(tester, definition);
    await tester.tap(shiftUp());
    await tester.pump();
    expect(definition.currentGear.value, definition.maxGear);
    expect(haptics, isEmpty);
    await settleShift(tester);
  });

  testWidgets('dimmed, a shift does not buzz: nothing changes on the trainer', (tester) async {
    final definition = attachLiveTrainer(register: false).definition;
    await pumpCard(tester, definition, dim: true);
    await tester.tap(shiftUp());
    await tester.pump();
    expect(haptics, isEmpty);
    await settleShift(tester);
  });

  // The daily trial running out mid-ride used to leave the card looking
  // exactly as before.
  testWidgets('a trial that is over for today shows on the card', (tester) async {
    final definition = attachLiveTrainer(register: false).definition;
    await pumpCard(tester, definition, trialNotice: 'trial over notice');
    expect(find.byKey(const ValueKey('ride-vs-trial-notice')), findsOneWidget);
    expect(find.text('trial over notice'), findsOneWidget);
  });

  testWidgets('no trial notice, no line', (tester) async {
    final definition = attachLiveTrainer(register: false).definition;
    await pumpCard(tester, definition);
    expect(find.byKey(const ValueKey('ride-vs-trial-notice')), findsNothing);
  });
}
