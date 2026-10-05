// The ready banner changes as the rider works through setup: steps come and
// go, the count ticks down, and the list gives way to "Ready to ride". Each
// of those animates rather than jumping — and under reduced motion each is
// instant.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/widgets/home/ready_banner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

ChainBanner _pending(int steps) => ChainBanner(
  kind: ChainBannerKind.pending,
  status: LinkStatus.attention,
  stepsLeft: steps,
  targetLinkId: 'controller',
  targetKey: ChainLinkKey.controller,
  outstandingKeys: const [ChainLinkKey.controller, ChainLinkKey.app],
  outstandingLinkIds: const ['controller', 'app'],
);

const _ready = ChainBanner(kind: ChainBannerKind.ready, status: LinkStatus.ready, stepsLeft: 0);

const _unlock = ReadyBannerStep(
  linkId: 'controller',
  linkTitle: 'Zwift Click',
  step: SetupStep(id: SetupStepId.controllerUnlocked, done: false),
);
const _app = ReadyBannerStep(
  linkId: 'app',
  linkTitle: 'MyWhoosh',
  step: SetupStep(id: SetupStepId.appConnected, done: false),
);

Future<void> _pump(WidgetTester tester, ChainBanner banner, List<ReadyBannerStep> steps, {bool reduce = false}) =>
    tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.5),
        home: MediaQuery(
          data: MediaQueryData(size: const Size(390, 844), disableAnimations: reduce),
          child: Scaffold(
            child: SingleChildScrollView(
              child: ReadyBanner(banner: banner, brokenLinkName: null, appName: 'MyWhoosh', steps: steps),
            ),
          ),
        ),
      ),
    );

double _height(WidgetTester tester) => tester.getSize(find.byType(ReadyBanner)).height;

Finder _stepRow(ReadyBannerStep step) => find.byKey(ValueKey('ready-step-${step.linkId}-${step.step.id.name}'));

void main() async {
  await AppLocalizations.load(const Locale('en'));
  final l = AppLocalizations();

  testWidgets('a step that gets done shrinks out of the list instead of vanishing', (tester) async {
    await _pump(tester, _pending(2), const [_unlock, _app]);
    await tester.pumpAndSettle();
    final before = _height(tester);

    await _pump(tester, _pending(1), const [_app]);
    await tester.pump(const Duration(milliseconds: 50));
    expect(_stepRow(_unlock), findsOneWidget, reason: 'still on its way out');
    final mid = _height(tester);

    await tester.pumpAndSettle();
    final after = _height(tester);
    expect(_stepRow(_unlock), findsNothing);
    expect(mid, lessThan(before));
    expect(mid, greaterThan(after), reason: 'part-way between the two heights');
  });

  testWidgets('a new step grows in', (tester) async {
    await _pump(tester, _pending(1), const [_app]);
    await tester.pumpAndSettle();
    final before = _height(tester);

    await _pump(tester, _pending(2), const [_unlock, _app]);
    await tester.pump(const Duration(milliseconds: 50));
    final mid = _height(tester);
    await tester.pumpAndSettle();
    final after = _height(tester);
    expect(mid, greaterThan(before));
    expect(mid, lessThan(after));
  });

  testWidgets('the count crossfades to its new number', (tester) async {
    await _pump(tester, _pending(2), const [_unlock, _app]);
    await tester.pumpAndSettle();

    await _pump(tester, _pending(1), const [_app]);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(l.chainStepsLeftTitle(2)), findsOneWidget, reason: 'the old count fading out');
    expect(find.text(l.chainStepsLeftTitle(1)), findsOneWidget, reason: 'the new one fading in');

    await tester.pumpAndSettle();
    expect(find.text(l.chainStepsLeftTitle(2)), findsNothing);
  });

  testWidgets('steps → ready: crossfades while the height eases, no jump', (tester) async {
    await _pump(tester, _pending(1), const [_app]);
    await tester.pumpAndSettle();
    final before = _height(tester);

    await _pump(tester, _ready, const []);
    await tester.pump(const Duration(milliseconds: 50));
    final mid = _height(tester);
    expect(find.text(l.chainReadyTitle), findsOneWidget);
    expect(_stepRow(_app), findsOneWidget, reason: 'the list fades out underneath');

    await tester.pumpAndSettle();
    final after = _height(tester);
    expect(_stepRow(_app), findsNothing);
    expect(mid, lessThan(before));
    expect(mid, greaterThan(after));
  });

  testWidgets('reduced motion: every change is instant', (tester) async {
    await _pump(tester, _pending(2), const [_unlock, _app], reduce: true);
    await tester.pump();

    await _pump(tester, _pending(1), const [_app], reduce: true);
    await tester.pump();
    expect(_stepRow(_unlock), findsNothing);
    expect(find.text(l.chainStepsLeftTitle(2)), findsNothing);
    final settled = _height(tester);
    await tester.pumpAndSettle();
    expect(_height(tester), settled);

    await _pump(tester, _ready, const [], reduce: true);
    await tester.pump();
    expect(_stepRow(_app), findsNothing);
    expect(find.text(l.chainReadyTitle), findsOneWidget);
  });
}
