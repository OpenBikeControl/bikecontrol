import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/widgets/home/ready_banner.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

Future<void> pumpBanner(
  WidgetTester tester,
  ChainBanner banner, {
  VoidCallback? onAction,
  VoidCallback? onRevealOutstanding,
  List<ReadyBannerStep> steps = const [],
  bool settling = false,
}) async {
  await tester.pumpWidget(
    ShadcnApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.5),
      home: Scaffold(
        child: SingleChildScrollView(
          child: ReadyBanner(
            banner: banner,
            brokenLinkName: null,
            appName: 'MyWhoosh',
            onAction: onAction,
            onRevealOutstanding: onRevealOutstanding,
            steps: steps,
            settling: settling,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

const _controllerLinkMissing = SetupStep(
  id: SetupStepId.appConnected,
  done: false,
  variant: SetupStepVariant.controllerLinkMissing,
);

void main() async {
  await AppLocalizations.load(const Locale('en'));
  final l = AppLocalizations();

  // The trainer app's pairing screen has two BikeControl tiles. With the
  // trainer one done and the controller one all that is left, "finish the
  // Trainer app card" sends the rider back to a card they have already acted
  // on — the banner names the missing pairing instead.
  testWidgets('names the missing controller pairing when it is the one thing left', (tester) async {
    await pumpBanner(
      tester,
      const ChainBanner(
        kind: ChainBannerKind.pending,
        status: LinkStatus.attention,
        stepsLeft: 1,
        targetLinkId: 'app',
        targetKey: ChainLinkKey.app,
        outstandingKeys: [ChainLinkKey.app],
        soleStep: _controllerLinkMissing,
      ),
    );

    expect(find.text(l.chainPendingSubtitleController('MyWhoosh')), findsOneWidget);
    expect(find.text(l.chainPendingSubtitleSingle(l.chainAppTitle)), findsNothing);
  });

  testWidgets('keeps the card wording while other steps are outstanding too', (tester) async {
    await pumpBanner(
      tester,
      const ChainBanner(
        kind: ChainBannerKind.pending,
        status: LinkStatus.attention,
        stepsLeft: 3,
        targetLinkId: 'controller',
        targetKey: ChainLinkKey.controller,
        outstandingKeys: [ChainLinkKey.controller, ChainLinkKey.app],
      ),
    );

    expect(find.text(l.chainPendingSubtitleController('MyWhoosh')), findsNothing);
    expect(find.textContaining(l.chainAppTitle), findsOneWidget);
  });

  testWidgets('a sole step with the ordinary wording keeps the card wording', (tester) async {
    await pumpBanner(
      tester,
      const ChainBanner(
        kind: ChainBannerKind.pending,
        status: LinkStatus.attention,
        stepsLeft: 1,
        targetLinkId: 'app',
        targetKey: ChainLinkKey.app,
        outstandingKeys: [ChainLinkKey.app],
        soleStep: SetupStep(id: SetupStepId.appConnected, done: false),
      ),
    );

    expect(find.text(l.chainPendingSubtitleController('MyWhoosh')), findsNothing);
    expect(find.text(l.chainPendingSubtitleSingle(l.chainAppTitle)), findsOneWidget);
  });

  // "2 steps left" across two cards: opening whichever card happens to come
  // first reads as arbitrary, so the button takes the rider to the cards.
  group('the action button', () {
    testWidgets('with several outstanding cards reads Show and reveals them instead of opening the first', (
      tester,
    ) async {
      var opened = 0;
      var revealed = 0;
      await pumpBanner(
        tester,
        const ChainBanner(
          kind: ChainBannerKind.pending,
          status: LinkStatus.attention,
          stepsLeft: 2,
          targetLinkId: 'controller',
          targetKey: ChainLinkKey.controller,
          outstandingKeys: [ChainLinkKey.controller, ChainLinkKey.app],
          outstandingLinkIds: ['controller', 'app'],
        ),
        onAction: () => opened++,
        onRevealOutstanding: () => revealed++,
      );

      expect(find.text(l.chainBannerShow), findsOneWidget);
      await tester.tap(find.text(l.chainBannerShow));
      await tester.pump();

      expect(revealed, 1);
      expect(opened, 0);
    });

    testWidgets('with one outstanding card keeps opening that card', (tester) async {
      var opened = 0;
      var revealed = 0;
      await pumpBanner(
        tester,
        const ChainBanner(
          kind: ChainBannerKind.pending,
          status: LinkStatus.attention,
          stepsLeft: 2,
          targetLinkId: 'app',
          targetKey: ChainLinkKey.app,
          outstandingKeys: [ChainLinkKey.app],
          outstandingLinkIds: ['app'],
        ),
        onAction: () => opened++,
        onRevealOutstanding: () => revealed++,
      );

      expect(find.text(l.chainBannerShow), findsOneWidget);
      await tester.tap(find.text(l.chainBannerShow));
      await tester.pump();

      expect(opened, 1);
      expect(revealed, 0);
    });

    testWidgets('a break keeps Fix and goes straight to it, however many cards are outstanding', (tester) async {
      var opened = 0;
      var revealed = 0;
      await pumpBanner(
        tester,
        const ChainBanner(
          kind: ChainBannerKind.broken,
          status: LinkStatus.problem,
          stepsLeft: 2,
          targetLinkId: 'controller',
          targetKey: ChainLinkKey.controller,
          outstandingKeys: [ChainLinkKey.controller, ChainLinkKey.app],
          outstandingLinkIds: ['controller', 'app'],
        ),
        onAction: () => opened++,
        onRevealOutstanding: () => revealed++,
      );

      expect(find.text(l.chainBannerShow), findsNothing);
      await tester.tap(find.text(l.chainBannerFix));
      await tester.pump();

      expect(opened, 1);
      expect(revealed, 0);
    });
  });

  // A trainer app that went away after it worked was almost always closed.
  // The banner says so and where the app comes back from — as a step left,
  // with "Show", never as a break with "Fix".
  group('a trainer app that dropped after working', () {
    const dropped = ChainBanner(
      kind: ChainBannerKind.pending,
      status: LinkStatus.attention,
      stepsLeft: 1,
      targetLinkId: 'app',
      targetKey: ChainLinkKey.app,
      outstandingKeys: [ChainLinkKey.app],
      soleStep: SetupStep(id: SetupStepId.appConnected, done: false),
      appDropped: true,
    );

    testWidgets('says the app disconnected and how to get it back', (tester) async {
      await pumpBanner(tester, dropped, onAction: () {});

      expect(find.text(l.chainStepsLeftTitle(1)), findsOneWidget);
      expect(find.text(l.chainPendingSubtitleAppDropped('MyWhoosh')), findsOneWidget);
      expect(find.text(l.chainPendingSubtitleSingle(l.chainAppTitle)), findsNothing);
      expect(find.text(l.chainBrokenTitle('MyWhoosh')), findsNothing);
      expect(find.text(l.chainBannerShow), findsOneWidget);
      expect(find.text(l.chainBannerFix), findsNothing);
    });

    // Quitting the app with a bridged trainer leaves the trainer card waiting
    // for the same app: two cards, one cause — so "Show" opens the fix.
    testWidgets('with the trainer card waiting for the same app, opens the fix rather than revealing', (
      tester,
    ) async {
      var opened = 0;
      var revealed = 0;
      await pumpBanner(
        tester,
        const ChainBanner(
          kind: ChainBannerKind.pending,
          status: LinkStatus.attention,
          stepsLeft: 1,
          targetLinkId: 'app',
          targetKey: ChainLinkKey.app,
          outstandingKeys: [ChainLinkKey.trainer, ChainLinkKey.app],
          outstandingLinkIds: ['trainer', 'app'],
          appDropped: true,
        ),
        onAction: () => opened++,
        onRevealOutstanding: () => revealed++,
      );

      expect(find.text(l.chainStepsLeftTitle(1)), findsOneWidget);
      expect(find.text(l.chainPendingSubtitleAppDropped('MyWhoosh')), findsOneWidget);
      await tester.tap(find.text(l.chainBannerShow));
      await tester.pump();

      expect(opened, 1);
      expect(revealed, 0);
    });

    // With the trainer still held, the app is plainly open — "when you ride
    // again" would be wrong, and the missing controller tile is the answer.
    testWidgets('the missing controller tile still wins when the app holds the trainer', (tester) async {
      await pumpBanner(
        tester,
        const ChainBanner(
          kind: ChainBannerKind.pending,
          status: LinkStatus.attention,
          stepsLeft: 1,
          targetLinkId: 'app',
          targetKey: ChainLinkKey.app,
          outstandingKeys: [ChainLinkKey.app],
          soleStep: _controllerLinkMissing,
          appDropped: true,
        ),
      );

      expect(find.text(l.chainPendingSubtitleController('MyWhoosh')), findsOneWidget);
      expect(find.text(l.chainPendingSubtitleAppDropped('MyWhoosh')), findsNothing);
    });
  });

  // "3 steps left" with only a Show button said nothing about what was wrong.
  // The banner lists the steps themselves, each with the fix the Devices row
  // offers for it.
  group('the outstanding steps', () {
    const pending = ChainBanner(
      kind: ChainBannerKind.pending,
      status: LinkStatus.attention,
      stepsLeft: 4,
      targetLinkId: 'controller-a',
      targetKey: ChainLinkKey.controller,
      outstandingKeys: [ChainLinkKey.controller, ChainLinkKey.trainer, ChainLinkKey.app],
      outstandingLinkIds: ['controller-a', 'controller-b', 'trainer', 'app'],
    );

    List<ReadyBannerStep> fourSteps(List<String> fixed) => [
      ReadyBannerStep(
        linkId: 'controller-a',
        step: const SetupStep(id: SetupStepId.controllerPaired, done: false),
        actionLabel: l.chainSetUp,
        onFix: () => fixed.add('controller-a'),
      ),
      ReadyBannerStep(
        linkId: 'controller-b',
        step: const SetupStep(id: SetupStepId.controllerUnlocked, done: false),
        onFix: () => fixed.add('controller-b'),
      ),
      ReadyBannerStep(
        linkId: 'trainer',
        step: const SetupStep(id: SetupStepId.trainerGearOverlay, done: false),
        actionLabel: l.chainStepOverlayAction,
        onFix: () => fixed.add('trainer'),
      ),
      ReadyBannerStep(
        linkId: 'app',
        step: const SetupStep(id: SetupStepId.appLocalNetwork, done: false),
        onFix: () => fixed.add('app'),
      ),
    ];

    testWidgets('lists every step with its title, reason and fix', (tester) async {
      final fixed = <String>[];
      await pumpBanner(tester, pending, steps: fourSteps(fixed));

      expect(find.text(l.chainStepsLeftTitle(4)), findsOneWidget);
      for (final title in [
        l.chainStepControllerPairedPending,
        l.chainStepUnlockedPending,
        l.chainStepOverlayPending('MyWhoosh'),
        l.chainStepAppLocalNetworkPending,
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(find.text(l.chainStepControllerPairedHint), findsOneWidget);
      expect(find.text(l.chainSetUp), findsOneWidget);
      expect(find.text(l.chainStepOverlayAction), findsOneWidget);
      // No label of its own: the Devices row's default.
      expect(find.text(l.chainShowMeHow), findsNWidgets(2));
      // Nothing to reveal: every step is on screen.
      expect(find.text(l.chainBannerShow), findsNothing);

      await tester.tap(find.text(l.chainSetUp));
      await tester.tap(find.text(l.chainStepOverlayAction));
      await tester.tap(find.text(l.chainShowMeHow).last);
      await tester.pump();
      expect(fixed, ['controller-a', 'trainer', 'app']);
    });

    testWidgets('a step whose fix comes after an earlier one shows without a button', (tester) async {
      await pumpBanner(
        tester,
        pending,
        steps: const [
          ReadyBannerStep(
            linkId: 'controller-a',
            step: SetupStep(id: SetupStepId.controllerPaired, done: false),
          ),
        ],
      );
      expect(find.text(l.chainStepControllerPairedPending), findsOneWidget);
      expect(find.byType(PrimaryButton), findsNothing);
    });

    testWidgets('past four, the rest is "+N more", which reveals them on Devices', (tester) async {
      var revealed = 0;
      final fixed = <String>[];
      await pumpBanner(
        tester,
        pending,
        onRevealOutstanding: () => revealed++,
        steps: [
          ...fourSteps(fixed),
          const ReadyBannerStep(
            linkId: 'app',
            step: SetupStep(id: SetupStepId.appConnected, done: false),
          ),
          const ReadyBannerStep(
            linkId: 'app',
            step: SetupStep(id: SetupStepId.appLocalControl, done: false),
          ),
        ],
      );

      expect(find.text(l.chainStepAppLocalNetworkPending), findsOneWidget);
      expect(find.text(l.chainStepAppConnectedPending('MyWhoosh')), findsNothing);
      await tester.tap(find.text(l.readyBannerMoreSteps(2)));
      await tester.pump();
      expect(revealed, 1);
    });
  });

  // Right after launch the steps flip as devices turn up and drop again: one
  // calm line stands in for all of them until the setup has settled.
  testWidgets('while settling: one calm "Connecting…" line instead of the steps', (tester) async {
    await pumpBanner(
      tester,
      const ChainBanner(
        kind: ChainBannerKind.pending,
        status: LinkStatus.attention,
        stepsLeft: 2,
        targetLinkId: 'controller-a',
        targetKey: ChainLinkKey.controller,
        outstandingKeys: [ChainLinkKey.controller],
        outstandingLinkIds: ['controller-a'],
      ),
      settling: true,
      steps: [
        ReadyBannerStep(
          linkId: 'controller-a',
          step: const SetupStep(id: SetupStepId.controllerPaired, done: false),
          onFix: () {},
        ),
      ],
    );
    expect(find.text(l.chainStatusConnecting), findsOneWidget);
    expect(find.byKey(const ValueKey('ready-banner-steps')), findsNothing);
    expect(find.text(l.chainStepsLeftTitle(2)), findsNothing);
    expect(find.text(l.chainStepControllerPairedPending), findsNothing);
    expect(find.byType(PrimaryButton), findsNothing, reason: 'nothing to act on yet');
  });

  // Ready is calm: a green tick with a quiet halo, no wash, no outline.
  testWidgets('ready: the tick wears a quiet halo of the success colour', (tester) async {
    await pumpBanner(
      tester,
      const ChainBanner(kind: ChainBannerKind.ready, status: LinkStatus.ready, stepsLeft: 0),
    );
    final tick = tester.widget<Container>(find.byKey(const ValueKey('ready-banner-tick')));
    final shadows = (tick.decoration! as BoxDecoration).boxShadow!;
    expect(shadows, hasLength(1));
    expect(shadows.single.color, BkBrandColors.light.readyHalo);
    expect(shadows.single.blurRadius, 0, reason: 'a crisp ring, not a glow');
    expect(shadows.single.spreadRadius, 5);
  });
}
