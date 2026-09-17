import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/widgets/home/ready_banner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

Future<void> pumpBanner(
  WidgetTester tester,
  ChainBanner banner, {
  VoidCallback? onAction,
  VoidCallback? onRevealOutstanding,
}) async {
  await tester.pumpWidget(
    ShadcnApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.5),
      home: Scaffold(
        child: ReadyBanner(
          banner: banner,
          brokenLinkName: null,
          appName: 'MyWhoosh',
          onAction: onAction,
          onRevealOutstanding: onRevealOutstanding,
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
}
