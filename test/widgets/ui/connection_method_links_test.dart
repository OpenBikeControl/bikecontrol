// The network method's card: its links read as one set — "Instructions" opens
// the same numbered steps the onboarding showed for the rider's trainer app,
// and the network check is a link like it, named for what it does and set
// against the card's right edge. On the Trainer Controls page the card is
// there to get the method connected, not to switch it off, so it has no switch.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/widgets/apps/openbikecontrol_mdns_tile.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/connection_method.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  setUp(() {
    core.settings.setTrainerApp(MyWhoosh());
    core.settings.setObpMdnsEnabled(false);
  });

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    String locale = 'en',
    bool embedded = false,
    double width = 414,
  }) async {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await AppLocalizations.load(Locale(locale));
    addTearDown(() => AppLocalizations.load(const Locale('en')));
    const tile = OpenBikeControlMdnsTile(small: false);
    await tester.pumpWidget(
      ShadcnApp(
        theme: BkTheme.build(Brightness.light),
        locale: Locale(locale),
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('de')],
        home: BkComponentThemes(
          child: Scaffold(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: embedded ? const ConnectionMethodWithoutSwitch(child: tile) : tile,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return AppLocalizations.current;
  }

  testWidgets('the network check is a link named for what it does, at the right edge', (tester) async {
    // Wide, because the test font is far wider than the app's: at phone
    // width it cannot fit both links on one line.
    final l = await pump(tester, width: 700);
    expect(find.text(l.networkTroubleshootTroubleshoot), findsNothing);
    final analyze = find.text(l.networkAnalyze);
    expect(analyze, findsOneWidget);

    final instructions = tester.getRect(find.text(l.instructions));
    final check = tester.getRect(analyze);
    expect(check.left, greaterThan(instructions.right), reason: 'after the instructions');
    // The card spans 16..684 with 16 inner padding: the link ends at 668.
    expect(check.right, closeTo(668, 2), reason: 'set against the right edge');
    // Same look as "Instructions": the accent text, no outline, no icon.
    final style = tester.widget<Text>(analyze).style;
    final instructionsStyle = tester.widget<Text>(find.text(l.instructions)).style;
    expect(style?.color, instructionsStyle?.color);
    expect(style?.fontWeight, instructionsStyle?.fontWeight);
  });

  testWidgets('Instructions opens the onboarding steps for the trainer app', (tester) async {
    final l = await pump(tester, width: 700);
    await tester.tap(find.text(l.instructions));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(l.onboardingGuideMyWhoosh1), findsOneWidget);
  });

  testWidgets('on its own the card has its switch', (tester) async {
    await pump(tester);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('embedded where the method is in use, the card has no switch', (tester) async {
    await pump(tester, embedded: true);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('German names the check for what it does', (tester) async {
    final l = await pump(tester, locale: 'de');
    expect(find.text('Netzwerk analysieren'), findsOneWidget);
    expect(find.text(l.networkTroubleshootTroubleshoot), findsNothing);
  });
}
