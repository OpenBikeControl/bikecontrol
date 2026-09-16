import 'dart:math';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/widgets/home/ampel.dart';
import 'package:bike_control/widgets/home/chain_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

ChainLink link({
  LinkStatus status = LinkStatus.ready,
  List<bool> steps = const [true, true, true],
  bool optional = false,
  bool dismissible = false,
}) {
  return ChainLink(
    key: ChainLinkKey.controller,
    id: 'controller:test',
    status: status,
    title: 'Zwift Click V2',
    optional: optional,
    dismissible: dismissible,
    deviceId: 'test',
    steps: [
      for (final (i, done) in steps.indexed)
        SetupStep(
          id: [
            SetupStepId.controllerBluetoothReady,
            SetupStepId.controllerPaired,
            SetupStepId.controllerButtonsMapped,
            SetupStepId.controllerInRange,
          ][i % 4],
          done: done,
        ),
    ],
  );
}

Future<void> pumpCard(
  WidgetTester tester,
  ChainLink l, {
  VoidCallback? onInstructions,
  VoidCallback? onSecondaryAction,
  String? secondaryActionLabel,
  VoidCallback? onDismissed,
  VoidCallback? onTap,
  VoidCallback? onEdit,
  List<Widget> statusBadges = const [],
  Widget? footer,
  String? subtitle,
  String? appName,
}) async {
  await tester.pumpWidget(
    ShadcnApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.5),
      home: Scaffold(
        child: SingleChildScrollView(
          child: l.dismissible
              ? Dismissible(
                  key: const ValueKey('dismiss'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => onDismissed?.call(),
                  child: ChainCard(
                    link: l,
                    tile: const Icon(LucideIcons.gamepad),
                    title: l.title,
                    statusLabel: 'status',
                    statusBadges: statusBadges,
                    appName: appName,
                    onInstructions: onInstructions,
                    onSecondaryAction: onSecondaryAction,
                    secondaryActionLabel: secondaryActionLabel,
                    onTap: onTap,
                    onEdit: onEdit,
                  ),
                )
              : ChainCard(
                  link: l,
                  tile: const Icon(LucideIcons.gamepad),
                  title: l.title,
                  statusLabel: 'status',
                  statusBadges: statusBadges,
                  appName: appName,
                  onInstructions: onInstructions,
                  onSecondaryAction: onSecondaryAction,
                  secondaryActionLabel: secondaryActionLabel,
                  onTap: onTap,
                  onEdit: onEdit,
                  footer: footer,
                  subtitle: subtitle,
                ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() async {
  await AppLocalizations.load(const Locale('en'));
  final l = AppLocalizations();

  group('only outstanding steps are shown', () {
    testWidgets('a finished card shows no checklist at all', (tester) async {
      await pumpCard(tester, link());

      expect(find.byType(StepRow), findsNothing);
      // No summary, no counter, no way to unfold a list of ticked boxes.
      expect(find.textContaining('steps done'), findsNothing);
      expect(find.byIcon(LucideIcons.chevronDown), findsNothing);
      expect(find.byIcon(LucideIcons.chevronUp), findsNothing);
    });

    testWidgets('only the pending steps are rendered', (tester) async {
      await pumpCard(tester, link(status: LinkStatus.attention, steps: [true, false, false]));

      expect(find.byType(StepRow), findsNWidgets(2));
      // The two that are done have nothing left to say.
      expect(find.text(l.chainStepBluetoothReady), findsNothing);
    });

    testWidgets('a card with no steps renders no checklist', (tester) async {
      await pumpCard(tester, link(status: LinkStatus.off, steps: []));
      expect(find.byType(StepRow), findsNothing);
    });

    testWidgets('every rendered step is genuinely outstanding', (tester) async {
      await pumpCard(tester, link(status: LinkStatus.attention, steps: [false, true, false, true]));

      final rows = tester.widgetList<StepRow>(find.byType(StepRow)).toList();
      expect(rows, hasLength(2));
      expect(rows.every((r) => !r.step.done), isTrue);
    });
  });

  group('the active step', () {
    testWidgets('is the first outstanding one, and the only one offering instructions', (tester) async {
      var opened = 0;
      await pumpCard(
        tester,
        link(status: LinkStatus.attention, steps: [true, false, false]),
        onInstructions: () => opened++,
      );

      final rows = tester.widgetList<StepRow>(find.byType(StepRow)).toList();
      expect(rows.map((r) => r.active), [true, false]);
      // Exactly one next action on the card, never two.
      expect(find.text(l.chainShowMeHow), findsOneWidget);

      await tester.tap(find.text(l.chainShowMeHow));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });

    testWidgets('offers nothing when every step is done', (tester) async {
      await pumpCard(tester, link(status: LinkStatus.attention), onInstructions: () {});
      expect(find.text(l.chainShowMeHow), findsNothing);
    });
  });

  // A required step that is really an offer — the gear overlay — needs a
  // second answer, or "required" turns into "demanded". The second answer
  // rides the active step beside its primary action, and only there: like
  // the instructions button, it is part of the one next action on the card.
  group('a secondary action', () {
    testWidgets('sits beside the primary action on the active step and fires its own callback', (tester) async {
      var primary = 0;
      var secondary = 0;
      await pumpCard(
        tester,
        link(status: LinkStatus.attention, steps: [true, false, false]),
        onInstructions: () => primary++,
        onSecondaryAction: () => secondary++,
        secondaryActionLabel: 'Not now',
      );

      expect(find.text('Not now'), findsOneWidget);
      // Beside, not below: the two answers read as one choice.
      final primaryRect = tester.getRect(find.text(l.chainShowMeHow));
      final secondaryRect = tester.getRect(find.text('Not now'));
      expect(secondaryRect.left, greaterThan(primaryRect.right));
      expect(secondaryRect.center.dy, moreOrLessEquals(primaryRect.center.dy, epsilon: 1));

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(secondary, 1);
      expect(primary, 0);
    });

    testWidgets('is absent without a callback, and never rides a non-active step', (tester) async {
      await pumpCard(
        tester,
        link(status: LinkStatus.attention, steps: [true, false, false]),
        onInstructions: () {},
        secondaryActionLabel: 'Not now',
      );
      expect(find.text('Not now'), findsNothing);

      await pumpCard(
        tester,
        link(status: LinkStatus.attention, steps: [true, false, false]),
        onInstructions: () {},
        onSecondaryAction: () {},
        secondaryActionLabel: 'Not now',
      );
      final rows = tester.widgetList<StepRow>(find.byType(StepRow)).toList();
      expect(rows.map((r) => r.onSecondaryAction != null), [true, false]);
    });
  });

  testWidgets('an unfilled optional card is tagged as such', (tester) async {
    await pumpCard(tester, link(status: LinkStatus.off, optional: true, steps: []));
    expect(find.text(l.chainOptional.toUpperCase()), findsOneWidget);
  });

  testWidgets('a required card carries no optional tag', (tester) async {
    await pumpCard(tester, link());
    expect(find.text(l.chainOptional.toUpperCase()), findsNothing);
  });

  // OPTIONAL reassures a rider looking at an empty slot. Once a smart trainer
  // is actually connected the card is doing a job, and captioning live hardware
  // "optional" is just noise — even though the link stays optional underneath,
  // which is what keeps a trainer nobody owns from blocking "Ready to ride".
  testWidgets('a connected optional card drops the tag', (tester) async {
    for (final status in [LinkStatus.ready, LinkStatus.attention, LinkStatus.problem]) {
      await pumpCard(tester, link(status: status, optional: true, steps: []));
      expect(find.text(l.chainOptional.toUpperCase()), findsNothing, reason: status.name);
    }
  });

  // Local control: an offer that lives in the checklist rather than in a
  // toast that scrolls away. It has to read as an offer on the line itself,
  // otherwise a rider who doesn't want it sees a card that is never finished.
  // (The gear overlay used to be this fixture; it is a required step now.)
  group('an optional step', () {
    ChainLink localControlLink({bool alone = true}) => ChainLink(
      key: ChainLinkKey.app,
      id: 'app',
      status: LinkStatus.ready,
      title: 'MyWhoosh',
      steps: [
        const SetupStep(id: SetupStepId.appSelected, done: true),
        const SetupStep(id: SetupStepId.appConnectionMethod, done: true),
        SetupStep(id: SetupStepId.appConnected, done: alone),
        const SetupStep(id: SetupStepId.appLocalControl, done: false, optional: true),
      ],
    );

    testWidgets('is tagged optional on its own line', (tester) async {
      await pumpCard(tester, localControlLink());

      expect(find.text(l.chainStepLocalControl), findsOneWidget);
      // The card is connected, so its header has dropped the tag — the only one
      // left is the step's own, sitting beside the step rather than in the
      // title row.
      expect(find.text(l.chainOptional.toUpperCase()), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(l.chainOptional.toUpperCase())).dy,
        greaterThan(tester.getTopLeft(find.text(l.chainStepLocalControl)).dy - 1),
      );
    });

    testWidgets('states why it exists before it is the active step', (tester) async {
      await pumpCard(tester, localControlLink(alone: false));

      final rows = tester.widgetList<StepRow>(find.byType(StepRow)).toList();
      expect(rows.map((r) => r.step.id), [SetupStepId.appConnected, SetupStepId.appLocalControl]);
      // Not the active step, so no button — but the reason is on screen anyway:
      // it is the whole content of the offer.
      expect(rows.last.active, isFalse);
      expect(find.text(l.chainStepLocalControlHint(l.chainAppTitle)), findsOneWidget);
    });
  });

  // The gear overlay's pending line names the consequence for the rider's
  // app; a card with no app chosen gets a sentence of its own instead of the
  // generic "Trainer app" glued into the placeholder.
  group('the gear overlay step', () {
    ChainLink overlayLink() => const ChainLink(
      key: ChainLinkKey.trainer,
      id: 'trainer',
      status: LinkStatus.attention,
      title: 'KICKR CORE',
      optional: true,
      steps: [
        SetupStep(id: SetupStepId.trainerPaired, done: true),
        SetupStep(id: SetupStepId.trainerAppBridged, done: true),
        SetupStep(id: SetupStepId.trainerGearOverlay, done: false),
      ],
    );

    testWidgets('names the app that will keep showing its own gear', (tester) async {
      await pumpCard(tester, overlayLink(), appName: 'MyWhoosh');
      expect(find.text(l.chainStepOverlayPending('MyWhoosh')), findsOneWidget);
      expect(find.text(l.chainStepOverlayHint('MyWhoosh')), findsOneWidget);
      // Required now: no OPTIONAL tag on the line.
      expect(find.text(l.chainOptional.toUpperCase()), findsNothing);
    });

    testWidgets('falls back to a whole sentence when no app is chosen', (tester) async {
      await pumpCard(tester, overlayLink());
      expect(find.text(l.chainStepOverlayPendingNoApp), findsOneWidget);
    });
  });

  group('alignment', () {
    testWidgets('every step tick shares one left edge', (tester) async {
      await pumpCard(tester, link(status: LinkStatus.attention, steps: [false, false, false]));

      final ticks = find.byKey(stepTickKey);
      expect(ticks, findsNWidgets(3));
      final first = tester.getTopLeft(ticks.at(0)).dx;
      for (var i = 1; i < 3; i++) {
        expect(tester.getTopLeft(ticks.at(i)).dx, moreOrLessEquals(first, epsilon: 0.5));
      }
    });

    testWidgets('every step label shares one left edge', (tester) async {
      await pumpCard(tester, link(status: LinkStatus.attention, steps: [false, false]));

      final a = tester.getTopLeft(find.text(l.chainStepBluetoothReadyPending)).dx;
      final b = tester.getTopLeft(find.text(l.chainStepControllerPairedPending)).dx;
      expect(b, moreOrLessEquals(a, epsilon: 0.5));
    });
  });

  group('animating a status change', () {
    testWidgets('a card that becomes ready collapses its checklist over time, not instantly', (tester) async {
      await pumpCard(tester, link(status: LinkStatus.attention, steps: [true, true, false]));
      // Two done, one outstanding — only the outstanding one is on screen.
      expect(find.byType(StepRow), findsOneWidget);

      // The last step lands: the card is now ready and should fold away.
      await tester.pumpWidget(
        ShadcnApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.5),
          home: Scaffold(
            child: SingleChildScrollView(
              child: ChainCard(
                link: link(),
                tile: const Icon(LucideIcons.gamepad),
                title: 'Zwift Click V2',
                statusLabel: 'status',
              ),
            ),
          ),
        ),
      );

      // Mid-flight the card is still taller than its resting height — proof the
      // collapse is animating rather than snapping shut in one frame.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final midHeight = tester.getSize(find.byType(ChainCard)).height;

      await tester.pumpAndSettle();
      final restHeight = tester.getSize(find.byType(ChainCard)).height;

      expect(midHeight, greaterThan(restHeight));
      expect(find.byType(StepRow), findsNothing);
    });
  });

  group('swipe to forget', () {
    testWidgets('a disconnected card can be swiped away', (tester) async {
      var dismissed = 0;
      await pumpCard(
        tester,
        link(status: LinkStatus.attention, steps: [true, true, false], dismissible: true),
        onDismissed: () => dismissed++,
      );

      await tester.drag(find.byType(ChainCard), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(dismissed, 1);
    });

    testWidgets('a connected card has no dismiss gesture wrapped around it', (tester) async {
      await pumpCard(tester, link());
      expect(find.byType(Dismissible), findsNothing);
    });
  });

  // Battery / firmware / signal warnings ride beside the status rather than in
  // the body: they qualify "Connected" — it works, but not for much longer.
  testWidgets('status badges render beside the status label', (tester) async {
    await pumpCard(
      tester,
      link(),
      statusBadges: const [Icon(LucideIcons.batteryWarning, key: ValueKey('badge-battery'))],
    );

    expect(find.byKey(const ValueKey('badge-battery')), findsOneWidget);
    expect(
      find.ancestor(of: find.byKey(const ValueKey('badge-battery')), matching: find.byType(StatusLine)),
      findsOneWidget,
    );
  });

  testWidgets('a healthy card carries no badges', (tester) async {
    await pumpCard(tester, link());

    expect(find.byKey(const ValueKey('badge-battery')), findsNothing);
  });

  group('the whole card opens the device', () {
    testWidgets('tapping the card body opens it', (tester) async {
      var opened = 0;
      await pumpCard(tester, link(), onTap: () => opened++);

      await tester.tap(find.text('Zwift Click V2'));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });

    testWidgets('Edit still gets its own tap, not the card underneath it', (tester) async {
      var opened = 0;
      var edited = 0;
      await pumpCard(tester, link(), onTap: () => opened++, onEdit: () => edited++);

      await tester.tap(find.text(l.chainEdit));
      await tester.pumpAndSettle();
      // Both land the rider in the same place today, but a card that fires two
      // navigations from one tap would push the page twice.
      expect(edited, 1);
      expect(opened, 0);
    });

    testWidgets("the active step's own button still gets its own tap", (tester) async {
      var opened = 0;
      var instructed = 0;
      await pumpCard(
        tester,
        link(status: LinkStatus.attention, steps: [true, false, false]),
        onTap: () => opened++,
        onInstructions: () => instructed++,
      );

      await tester.tap(find.text(l.chainShowMeHow));
      await tester.pumpAndSettle();
      expect(instructed, 1);
      expect(opened, 0);
    });

    testWidgets('a card with nowhere to go takes no taps', (tester) async {
      await pumpCard(tester, link());
      expect(find.byType(Button), findsNothing);
    });
  });

  // The Sensors card is optional in the model — an idle broadcast must not
  // block "Ready to ride" — but it is never an empty slot: the kit draws it
  // with a solid border and a plain SENSORS eyebrow in every state.
  testWidgets('an idle sensors card is not drawn as an empty optional slot', (tester) async {
    await pumpCard(
      tester,
      ChainLink(key: ChainLinkKey.sensors, id: 'sensors', status: LinkStatus.off, title: '', optional: true, steps: []),
    );
    expect(find.text(l.chainOptional.toUpperCase()), findsNothing);
    final container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
    final shape = (container.decoration as ShapeDecoration).shape as RoundedRectangleBorder;
    final theme = Theme.of(tester.element(find.byType(ChainCard)));
    expect(shape.side.color, theme.colorScheme.border);
  });

  testWidgets('a subtitle sits under the status line', (tester) async {
    await pumpCard(tester, link(steps: []), subtitle: 'with Assioma DUO');
    final status = tester.getTopLeft(find.text('status'));
    final subtitle = tester.getTopLeft(find.byKey(chainCardSubtitleKey));
    expect(find.text('with Assioma DUO'), findsOneWidget);
    expect(subtitle.dy, greaterThan(status.dy));
    expect(subtitle.dx, status.dx);
  });

  // The banner's "Show" takes the rider to every outstanding card, and each of
  // them has to jump out once it is on screen: a short pulse, a shake, and an
  // accent border that outlasts the movement.
  group('the highlight', () {
    const linkId = 'controller:test';
    final highlight = find.byKey(chainCardHighlightKey(linkId));

    /// [accessibility] is the platform's own setting, the way a phone reports
    /// it — not a MediaQuery override, which animation controllers never see.
    Future<ValueNotifier<int>> pumpHighlightable(
      WidgetTester tester, {
      ChainLink? card,
      FakeAccessibilityFeatures? accessibility,
      VoidCallback? onTap,
    }) async {
      if (accessibility != null) {
        tester.platformDispatcher.accessibilityFeaturesTestValue = accessibility;
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      }
      final tick = ValueNotifier(0);
      addTearDown(tick.dispose);
      final l = card ?? link(status: LinkStatus.attention, steps: [true, false]);
      await tester.pumpWidget(
        ShadcnApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.5),
          home: Scaffold(
            child: SingleChildScrollView(
              child: ChainCard(
                link: l,
                tile: const Icon(LucideIcons.gamepad),
                title: l.title,
                statusLabel: 'status',
                onTap: onTap,
                highlight: tick,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tick;
    }

    /// A transform between the card and its own surface: the pulse and the
    /// shake. Anything the card draws inside its surface does not count.
    Finder motion() {
      final card = find.byType(ChainCard);
      final surface = find.descendant(of: card, matching: find.byType(AnimatedContainer)).first;
      return find.descendant(
        of: card,
        matching: find.ancestor(of: surface, matching: find.byType(Transform)),
      );
    }

    Matrix4 motionMatrix(WidgetTester tester) => tester.widget<Transform>(motion()).transform;

    testWidgets('is not shown until asked for', (tester) async {
      await pumpHighlightable(tester);
      expect(highlight, findsNothing);
    });

    testWidgets('pulses, shakes, then fades its border out', (tester) async {
      final tick = await pumpHighlightable(tester);

      tick.value++;
      await tester.pump();
      expect(highlight, findsOneWidget);

      // Mid-pulse the card is a touch bigger than at rest.
      await tester.pump(const Duration(milliseconds: 125));
      expect(motionMatrix(tester).getMaxScaleOnAxis(), greaterThan(1.02));
      expect(motionMatrix(tester).getMaxScaleOnAxis(), lessThanOrEqualTo(1.03 + 1e-6));

      // Then it shakes sideways, never further than 4 px.
      var widest = 0.0;
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        widest = max(widest, motionMatrix(tester).getTranslation().x.abs());
      }
      expect(widest, greaterThan(3));
      expect(widest, lessThanOrEqualTo(4 + 1e-6));

      // The movement is over while the border is still there ...
      await tester.pump(const Duration(milliseconds: 250));
      expect(highlight, findsOneWidget);
      expect(motionMatrix(tester).isIdentity(), isTrue);

      // ... and then the border is gone too.
      await tester.pump(const Duration(milliseconds: 600));
      expect(highlight, findsNothing);
      expect(motionMatrix(tester).isIdentity(), isTrue);
    });

    /// Plays a highlight and expects the border alone, for its whole length.
    Future<void> expectBorderOnly(WidgetTester tester, ValueNotifier<int> tick) async {
      tick.value++;
      await tester.pump();
      expect(highlight, findsOneWidget);
      expect(motion(), findsNothing);

      // Where the pulse and the shake would be — and the border is still
      // there, not squeezed into a single frame.
      for (final step in const [125, 250, 200]) {
        await tester.pump(Duration(milliseconds: step));
        expect(highlight, findsOneWidget);
        expect(motion(), findsNothing);
      }

      await tester.pump(const Duration(milliseconds: 700));
      expect(highlight, findsNothing);
      expect(motion(), findsNothing);
    }

    // Android's "Remove animations": the platform reports it to MediaQuery and
    // to every animation controller alike.
    testWidgets('with animations turned off, only the border flashes — the card never moves', (tester) async {
      final tick = await pumpHighlightable(
        tester,
        accessibility: const FakeAccessibilityFeatures(disableAnimations: true),
      );
      expect(MediaQuery.disableAnimationsOf(tester.element(find.byType(ChainCard))), isTrue);

      await expectBorderOnly(tester, tick);
    });

    // iOS's Reduce Motion arrives on its own flag, which MediaQuery knows
    // nothing about.
    testWidgets('with Reduce Motion on, only the border flashes — the card never moves', (tester) async {
      final tick = await pumpHighlightable(
        tester,
        accessibility: const FakeAccessibilityFeatures(reduceMotion: true),
      );
      expect(MediaQuery.disableAnimationsOf(tester.element(find.byType(ChainCard))), isFalse);

      await expectBorderOnly(tester, tick);
    });

    testWidgets('every tick plays it again', (tester) async {
      final tick = await pumpHighlightable(tester);

      tick.value++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      expect(highlight, findsNothing);

      tick.value++;
      await tester.pump();
      expect(highlight, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1200));
    });

    // An empty controller slot is grey — a grey flash would not jump out of
    // anything. The banner is amber, and so is what it points at.
    testWidgets('a card that was never set up flashes amber, not its own grey', (tester) async {
      final tick = await pumpHighlightable(
        tester,
        card: link(status: LinkStatus.off, steps: [false, false]),
      );

      tick.value++;
      await tester.pump();

      final box = tester.widget<DecoratedBox>(highlight);
      final side = ((box.decoration as ShapeDecoration).shape as RoundedRectangleBorder).side;
      final amber = AmpelStyle.of(tester.element(highlight), LinkStatus.attention).color;
      expect(side.color, isSameColorAs(amber));
      await tester.pump(const Duration(milliseconds: 1200));
    });

    testWidgets('the card still takes its tap while it is highlighted', (tester) async {
      var opened = 0;
      final tick = await pumpHighlightable(tester, onTap: () => opened++);

      tick.value++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(highlight, findsOneWidget);

      await tester.tap(find.text('Zwift Click V2'));
      await tester.pump();
      expect(opened, 1);
      await tester.pump(const Duration(milliseconds: 1200));
    });
  });

  group('footer', () {
    testWidgets('is rendered last, under everything else', (tester) async {
      await pumpCard(
        tester,
        link(status: LinkStatus.attention, steps: [true, false, false]),
        onTap: () {},
        footer: ChainCardFooterRow(question: 'No smart trainer?', action: 'Use sensors only', onPressed: () {}),
      );
      final footer = find.byKey(chainCardFooterKey);
      expect(footer, findsOneWidget);
      final card = tester.getRect(find.byType(ChainCard));
      final strip = tester.getRect(footer);
      // Flush with the card's bottom edge, inside its 1.5 border.
      expect(strip.bottom, closeTo(card.bottom, 2));
      expect(strip.top, greaterThan(tester.getRect(find.byKey(stepTickKey).last).bottom));
    });

    testWidgets('tapping it fires its own action, not the card underneath', (tester) async {
      var opened = 0;
      var pressed = 0;
      await pumpCard(
        tester,
        link(steps: []),
        onTap: () => opened++,
        footer: ChainCardFooterRow(
          question: 'No smart trainer?',
          action: 'Use sensors only',
          onPressed: () => pressed++,
        ),
      );
      await tester.tap(find.text('Use sensors only'));
      await tester.pumpAndSettle();
      expect(pressed, 1);
      expect(opened, 0);
    });
  });
}
