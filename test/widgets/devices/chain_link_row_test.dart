// A Devices row's checklist must never hide its own button: whatever the
// steps under a row change to, the row is as tall as what it shows.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/widgets/devices/chain_link_row.dart';
import 'package:bike_control/widgets/home/chain_card.dart' show StepRow;
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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

Future<ValueNotifier<ChainLink>> _pump(WidgetTester tester, ChainLink initial) async {
  // Jonas's phone: ~390 dp wide, German, dark.
  tester.view.physicalSize = const Size(390, 2000);
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
  final cta = tester.getRect(find.byType(PrimaryButton));
  final card = _card(tester);
  expect(cta.top, greaterThanOrEqualTo(card.top), reason: when);
  expect(
    card.bottom - cta.bottom,
    greaterThanOrEqualTo(10),
    reason: '$when: the button ends ${card.bottom - cta.bottom}px above the card\'s bottom edge',
  );
}

void main() {
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
    final lastStep = tester.getRect(find.byType(StepRow).last);
    // The last line (its own 2px gap included) and the checklist's 10px bottom inset.
    expect(row.bottom, lastStep.bottom + 10);
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
}
