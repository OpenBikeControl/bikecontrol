// A Devices row's checklist must never hide its own button: whatever the
// steps under a row change to, the row is as tall as what it shows.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/widgets/devices/chain_link_row.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

/// The trainer-app link as Jonas saw it: a network method on, the advertised
/// address flagged, the app not connected yet.
ChainLink _appLink({required bool addressWarning, bool pickedUp = false, bool allDone = false}) => ChainLink(
  key: ChainLinkKey.app,
  id: 'app',
  status: allDone ? LinkStatus.ready : LinkStatus.attention,
  title: 'MyWhoosh',
  steps: [
    const SetupStep(id: SetupStepId.appSelected, done: true),
    const SetupStep(id: SetupStepId.appConnectionMethod, done: true),
    if (addressWarning && !allDone)
      const SetupStep(id: SetupStepId.appNetworkAddress, done: false, hintArg: '192.168.178.133'),
    SetupStep(
      id: SetupStepId.appConnected,
      done: allDone,
      variant: pickedUp ? SetupStepVariant.controllerLinkMissing : SetupStepVariant.standard,
    ),
  ],
);

class _Host extends StatelessWidget {
  const _Host(this.link);

  final ValueListenable<ChainLink> link;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ValueListenableBuilder<ChainLink>(
          valueListenable: link,
          builder: (context, link, _) => BkGroupedSection(
            key: const ValueKey('section'),
            header: 'Trainer-App',
            children: [
              ChainLinkRow(
                link: link,
                leading: const SizedBox(width: 36, height: 36),
                title: 'MyWhoosh',
                subtitle: 'Netzwerk',
                appName: 'MyWhoosh',
                statusLabel: 'Dein Netzwerk sieht ungewöhnlich aus',
                onTap: () {},
                onInstructions: () {},
                instructionsLabel: 'Netzwerk prüfen',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<ValueNotifier<ChainLink>> _pump(WidgetTester tester, ChainLink initial, {double width = 390}) async {
  // Jonas's phone: ~390 dp wide, German, dark.
  tester.view.physicalSize = Size(width, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final link = ValueNotifier(initial);
  await tester.pumpWidget(
    ShadcnApp(
      locale: const Locale('de'),
      localizationsDelegates: [
        ...ShadcnLocalizations.localizationsDelegates,
        const OtherLocalizationsDelegate(),
        AppLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      theme: BkTheme.build(Brightness.dark),
      home: _Host(link),
    ),
  );
  await tester.pumpAndSettle();
  return link;
}

/// The grouped card the row sits in — it clips to its own bounds.
Rect _card(WidgetTester tester) => tester.getRect(
  find.descendant(of: find.byKey(const ValueKey('section')), matching: find.byType(ClipRRect)).first,
);

/// The fix button of the active step, and the card it has to fit in.
void _expectCtaInsideWithPadding(WidgetTester tester, String when) {
  final cta = tester.getRect(find.byKey(chainRowStepActionKey));
  final card = _card(tester);
  expect(cta.top, greaterThanOrEqualTo(card.top), reason: when);
  expect(
    card.bottom - cta.bottom,
    greaterThanOrEqualTo(10),
    reason: '$when: the button ends ${card.bottom - cta.bottom}px above the card\'s bottom edge',
  );
}

Future<void> main() async {
  // Real fonts: where the fix goes depends on how wide its label really is.
  await ensureSnapshotHarness();

  testWidgets('the address step appearing on a checklist shows its button in full at once', (tester) async {
    final link = await _pump(tester, _appLink(addressWarning: false));

    link.value = _appLink(addressWarning: true);
    await tester.pump();
    _expectCtaInsideWithPadding(tester, 'first frame after the step appeared');
    await tester.pump(const Duration(milliseconds: 100));
    _expectCtaInsideWithPadding(tester, '100 ms after the step appeared');
  });

  testWidgets('the row is exactly as tall as its content once the checklist has settled', (tester) async {
    final link = await _pump(tester, _appLink(addressWarning: false));
    link.value = _appLink(addressWarning: true);
    await tester.pumpAndSettle();

    final row = tester.getRect(find.byType(ChainLinkRow));
    final lastStep = tester.getRect(find.byKey(chainRowLaterStepKey(SetupStepId.appConnected)));
    // The last step's line and the checklist's 12px bottom inset.
    expect(row.bottom, lastStep.bottom + 12);
    expect(row.bottom, _card(tester).bottom);
  });

  testWidgets('the last step ticking still shrinks the row as a movement', (tester) async {
    final link = await _pump(tester, _appLink(addressWarning: false));
    final before = tester.getSize(find.byType(ChainLinkRow)).height;

    link.value = _appLink(addressWarning: false, allDone: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final during = tester.getSize(find.byType(ChainLinkRow)).height;
    await tester.pumpAndSettle();
    final after = tester.getSize(find.byType(ChainLinkRow)).height;

    expect(during, lessThan(before));
    expect(during, greaterThan(after));
  });

  group('a tappable row says so with a trailing chevron', () {
    Future<void> pumpRow(WidgetTester tester, {VoidCallback? onTap}) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ShadcnApp(
          localizationsDelegates: [
            ...ShadcnLocalizations.localizationsDelegates,
            const OtherLocalizationsDelegate(),
            AppLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          theme: BkTheme.build(Brightness.dark),
          home: Scaffold(
            child: BkGroupedSection(
              children: [
                ChainLinkRow(
                  link: _appLink(addressWarning: false, allDone: true),
                  leading: const SizedBox(width: 36, height: 36),
                  title: 'MyWhoosh',
                  statusLabel: 'Empfängt Befehle',
                  onTap: onTap,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('present, at the end of the header, when the row opens something', (tester) async {
      await pumpRow(tester, onTap: () {});
      final chevron = find.byKey(chainRowChevronKey);
      expect(chevron, findsOneWidget);
      expect(tester.widget<Icon>(chevron).icon, LucideIcons.chevronRight);
      // After the status, not before it.
      expect(tester.getCenter(chevron).dx, greaterThan(tester.getRect(find.text('Empfängt Befehle')).right));
    });

    testWidgets('absent when the row opens nothing', (tester) async {
      await pumpRow(tester);
      expect(find.byKey(chainRowChevronKey), findsNothing);
    });
  });

  // The store's Devices capture: "Lokale Steuerung aktivieren" beside the name
  // took most of the row, squeezed "Trainer-App" to "Train…" and wrapped the
  // status into a tall empty column. The fix always goes under the hint now,
  // whatever its length, so the card has one place for its actions.
  group('where the step in front\'s fix goes', () {
    Future<void> pumpRow(WidgetTester tester, String label) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = ShadcnApp(
        locale: const Locale('de'),
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: BkTheme.build(Brightness.light),
        home: Scaffold(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: BkGroupedSection(
              header: 'Trainer-App',
              children: [
                ChainLinkRow(
                  link: _appLink(addressWarning: false),
                  leading: const SizedBox(width: 30, height: 30),
                  title: 'Trainer-App',
                  subtitle: 'Netzwerk',
                  appName: 'MyWhoosh',
                  statusLabel: 'Warte auf Verbindung',
                  onTap: () {},
                  onInstructions: () {},
                  instructionsLabel: label,
                ),
              ],
            ),
          ),
        ),
      );
      // The real fonts: where the fix goes depends on how wide its label is.
      await tester.pumpWidget(app);
      await tester.pump();
      await tester.loadAssets(alsoLoadTheseFonts: const [BkNumerals.family]);
      await remountWithLoadedFonts(tester, app);
      await tester.pumpAndSettle();
    }

    for (final label in ['Lokale Steuerung aktivieren', 'Zeig mir wie']) {
      testWidgets('"$label" goes under the hint, and the name keeps its room', (tester) async {
        await pumpRow(tester, label);
        final fix = tester.getRect(find.byKey(chainRowStepActionKey));
        final title = tester.getRect(find.text('Trainer-App').last);
        expect(fix.top, greaterThan(title.bottom), reason: 'under the header, not beside the name');
        final name = tester.renderObject<RenderParagraph>(
          find.descendant(of: find.text('Trainer-App').last, matching: find.byType(RichText)),
        );
        expect(name.didExceedMaxLines, isFalse, reason: 'the name is not cut off');
      });
    }

    testWidgets('the status and the transport share one line', (tester) async {
      await pumpRow(tester, 'Zeig mir wie');
      final status = tester.getRect(find.text('Warte auf Verbindung'));
      final transport = tester.getRect(find.text('Netzwerk'));
      expect((status.center.dy - transport.center.dy).abs(), lessThan(2));
      expect(transport.left, greaterThan(status.right));
    });
  });

  // "○ Add keyboard and mouse actions [OPTIONAL]" with a separate "Enable
  // local control" under it: the circle read as a stray dot and the button
  // only repeated the line. The optional line is the button now.
  testWidgets('an optional later step with an offer is itself the button', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var offered = 0;
    await tester.pumpWidget(
      ShadcnApp(
        locale: const Locale('de'),
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: BkTheme.build(Brightness.light),
        home: Scaffold(
          child: BkGroupedSection(
            children: [
              ChainLinkRow(
                link: const ChainLink(
                  key: ChainLinkKey.app,
                  id: 'app',
                  status: LinkStatus.attention,
                  title: 'MyWhoosh',
                  steps: [
                    SetupStep(id: SetupStepId.appConnected, done: false),
                    SetupStep(id: SetupStepId.appLocalControl, done: false, optional: true),
                  ],
                ),
                leading: const SizedBox(width: 30, height: 30),
                title: 'MyWhoosh',
                appName: 'MyWhoosh',
                statusLabel: 'Warte auf MyWhoosh',
                offerLabel: (_) => 'Deinen Gang über MyWhoosh einblenden',
                onOffer: (_) => offered++,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l = AppLocalizations.current;

    final offer = find.byKey(chainRowOfferKey(SetupStepId.appLocalControl));
    expect(offer, findsOneWidget);
    // The line is the offer — what tapping does — not the step's title.
    expect(
      find.descendant(
        of: offer,
        matching: find.textContaining('Deinen Gang über MyWhoosh einblenden', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(find.textContaining(l.chainStepLocalControl, findRichText: true), findsNothing);
    expect(find.byIcon(LucideIcons.circle), findsNothing);
    await tester.tap(offer);
    expect(offered, 1);
  });

  // "Öffne die App …" and its button sat centred under the name on a wide
  // window: the checklist's slide was anchored top-centre, and a checklist
  // narrower than the row (a one-line hint) took that centre — at rest too.
  testWidgets('a checklist narrower than the row stays at the row\'s text edge', (tester) async {
    // A desktop window and the real font, so the hint fits one line.
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = ShadcnApp(
      locale: const Locale('de'),
      localizationsDelegates: [
        ...ShadcnLocalizations.localizationsDelegates,
        const OtherLocalizationsDelegate(),
        AppLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      theme: BkTheme.build(Brightness.light),
      home: Scaffold(
        child: BkGroupedSection(
          key: const ValueKey('section'),
          children: [
            ChainLinkRow(
              link: _appLink(addressWarning: false),
              leading: const BkIconTile(icon: LucideIcons.monitor),
              title: 'MyWhoosh',
              appName: 'MyWhoosh',
              statusLabel: 'Warte auf MyWhoosh',
              onInstructions: () {},
              instructionsLabel: 'Fehler beheben',
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(app);
    await tester.pump();
    await tester.loadAssets(alsoLoadTheseFonts: const [BkNumerals.family]);
    await remountWithLoadedFonts(tester, app);
    await tester.pumpAndSettle();

    final title = tester.getRect(find.text('MyWhoosh').last);
    final hint = tester.getRect(find.textContaining('Kopplungsbildschirm'));
    final card = _card(tester);
    expect(hint.width, lessThan(card.width - chainRowTextInset * 2), reason: 'the hint is narrower than the row');
    expect(hint.left, moreOrLessEquals(title.left, epsilon: 1));
    expect(tester.getRect(find.byKey(chainRowStepActionKey)).left, moreOrLessEquals(title.left, epsilon: 1));
  });
}
