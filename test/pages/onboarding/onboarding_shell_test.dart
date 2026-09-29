// The wizard's frame: "Step N of 6" with Help, a segmented progress bar in
// the accent, a display headline (no eyebrow), a full-width pill
// with Back as text under it, and the list of steps (a tick and what the
// step settled on for the finished ones, which take you back to them).
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/onboarding/onboarding_models.dart';
import 'package:bike_control/pages/onboarding/onboarding_page.dart';
import 'package:bike_control/pages/onboarding/steps/step_done.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_headline.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_status_dot.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  Future<AppLocalizations> pump(
    WidgetTester tester,
    Widget Function(BuildContext) builder, {
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        scaling: BkTheme.scaling,
        theme: BkTheme.build(Brightness.dark),
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: BkComponentThemes(child: Builder(builder: builder)),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    return AppLocalizations.of(tester.element(find.byType(Scaffold)));
  }

  Widget shell(
    BuildContext c, {
    OnboardingStep step = OnboardingStep.controller,
    VoidCallback? onBack,
    VoidCallback? onHelp,
    VoidCallback? onContinue,
    void Function(OnboardingStep)? onSelectStep,
  }) => onboardingShell(
    c,
    step: step,
    body: const OnboardingHeadline('Your controller is ready'),
    footerActions: [
      PrimaryButton(onPressed: onContinue ?? () {}, child: Text(AppLocalizations.of(c).onboardingContinue)),
    ],
    onBack: onBack ?? () {},
    onHelp: onHelp ?? () {},
    onSelectStep: onSelectStep ?? (_) {},
    stepValues: const {OnboardingStep.app: 'MyWhoosh', OnboardingStep.where: 'This device'},
  );

  testWidgets('phone: step count, accent progress up to the step and display headline, no eyebrow', (tester) async {
    final l = await pump(tester, (c) => shell(c));
    expect(find.text(l.onboardingStepOf('3', '6')), findsOneWidget);
    expect(find.text('${l.onboardingStepController} · ${l.onboardingStepControllerSub}'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp('${RegExp.escape(l.onboardingStepOf('3', '6'))}.*${l.onboardingStepController}')),
      findsOneWidget,
      reason: 'the step count tells a screen reader which step this is',
    );

    final primary = BkTheme.build(Brightness.dark).colorScheme.primary;
    for (var i = 0; i < 6; i++) {
      final bar = tester.widget<AnimatedContainer>(find.byKey(ValueKey('onboarding-progress-$i')));
      final color = (bar.decoration! as BoxDecoration).color;
      expect(color == primary, i <= 2, reason: 'segment $i');
    }

    final headline = tester.renderObject<RenderParagraph>(find.text('YOUR CONTROLLER IS READY'));
    expect(headline.text.style!.fontFamily, BkNumerals.family);
    expect(find.bySemanticsLabel('Your controller is ready'), findsOneWidget, reason: 'read in its own case');
  });

  testWidgets('phone: Continue is a full-width pill, Back is text under it, Help is the ? button', (tester) async {
    var back = 0, help = 0, next = 0;
    final l = await pump(
      tester,
      (c) => shell(c, onBack: () => back++, onHelp: () => help++, onContinue: () => next++),
    );
    final continueButton = find.ancestor(of: find.text(l.onboardingContinue), matching: find.byType(Button)).first;
    final rect = tester.getRect(continueButton);
    expect(rect.width, greaterThan(390 - 2 * 16 - 1), reason: 'full width');
    expect(rect.height, greaterThanOrEqualTo(48));
    final backText = tester.getRect(find.text(l.onboardingBack));
    expect(backText.top, greaterThan(rect.bottom), reason: 'Back sits under Continue');

    await tester.tap(find.text(l.onboardingContinue));
    await tester.tap(find.text(l.onboardingBack));
    await tester.tap(find.bySemanticsLabel(l.onboardingHelp));
    expect((next, back, help), (1, 1, 1));
  });

  testWidgets('phone: the list of steps ticks finished steps with their answer; a tap goes back', (tester) async {
    final visited = <OnboardingStep>[];
    await pump(tester, (c) => shell(c, onSelectStep: visited.add));
    final list = find.byType(BkGroupedSection);
    expect(list, findsOneWidget);
    expect(find.descendant(of: list, matching: find.text('MyWhoosh')), findsOneWidget);
    expect(find.descendant(of: list, matching: find.text('This device')), findsOneWidget);
    expect(find.descendant(of: list, matching: find.byIcon(LucideIcons.check)), findsNWidgets(2));

    await tester.ensureVisible(find.byKey(const ValueKey('onboarding-step-row-app')));
    await tester.tap(find.byKey(const ValueKey('onboarding-step-row-app')));
    await tester.ensureVisible(find.byKey(const ValueKey('onboarding-step-row-connection')));
    await tester.tap(find.byKey(const ValueKey('onboarding-step-row-connection')));
    expect(visited, [OnboardingStep.app], reason: 'steps ahead are not a shortcut');
  });

  testWidgets('wide: the steps are a rail beside the step, not repeated under it', (tester) async {
    final l = await pump(tester, (c) => shell(c), width: 1000);
    expect(find.byType(BkGroupedSection), findsNWidgets(2), reason: 'the rail list and Help & support');
    final rail = tester.getRect(find.byKey(const ValueKey('onboarding-step-row-app')));
    final headline = tester.getRect(find.text('YOUR CONTROLLER IS READY'));
    expect(rail.right, lessThan(headline.left));
    expect(find.text(l.onboardingHelpAndSupport), findsOneWidget);
  });

  testWidgets('done: success tile, display headline, summary with status dots, trial card', (tester) async {
    final l = await pump(
      tester,
      (c) => SingleChildScrollView(
        child: onboardingDoneBody(
          c,
          app: MyWhoosh(),
          controllerName: 'Zwift Play',
          trainerName: 'KICKR CORE',
          appConnected: true,
          trainerAppConnected: true,
          reduceMotion: true,
          showTestMode: true,
        ),
      ),
    );
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
    expect(find.text(l.onboardingDoneTitle.toUpperCase()), findsOneWidget);
    final summary = find.byType(BkGroupedSection);
    expect(summary, findsOneWidget);
    expect(find.descendant(of: summary, matching: find.byType(BkStatusDot)), findsNWidgets(3));
    expect(find.text(l.onboardingTestModeTitle), findsOneWidget);
    expect(find.byIcon(LucideIcons.clock), findsOneWidget);
    // Honest about what each plan lifts: Base or Pro for commands, Pro for
    // virtual shifting.
    expect(find.text(l.onboardingTrialUnlimited), findsOneWidget);
    expect(find.text(l.onboardingTrialKeepVs), findsOneWidget);
  });
}
