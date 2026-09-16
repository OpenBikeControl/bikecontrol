import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/widgets/home/ready_banner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

Future<void> pumpBanner(WidgetTester tester, ChainBanner banner) async {
  await tester.pumpWidget(
    ShadcnApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.5),
      home: Scaffold(child: ReadyBanner(banner: banner, brokenLinkName: null, appName: 'MyWhoosh')),
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
}
