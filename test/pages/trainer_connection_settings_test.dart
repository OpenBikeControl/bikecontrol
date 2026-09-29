// Connection settings in the new look: the trainer app as a card with Change,
// the recommended methods as cards with their switch and status, and the
// network check at the foot. The methods' own logic is unchanged — a card
// still flips its method.
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, screenshotMode;
import 'package:bike_control/pages/configuration.dart';
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_status_dot.dart';
import 'package:bike_control/widgets/ui/connection_method.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../widget_snapshot.dart';

class _FakeConnection extends TrainerConnection {
  _FakeConnection()
    : super(title: () => 'Direct connection', type: ConnectionMethodType.network, supportedActions: const []);

  @override
  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp}) async =>
      NotHandled('', button: null);

  @override
  Widget getTile({bool small = false}) => const SizedBox.shrink();
}

Widget _app(Widget child) => ShadcnApp(
  localizationsDelegates: [
    ...ShadcnLocalizations.localizationsDelegates,
    const OtherLocalizationsDelegate(),
    AppLocalizations.delegate,
  ],
  supportedLocales: const [Locale('en')],
  theme: BkTheme.build(Brightness.dark),
  home: child,
);

Future<void> main() async {
  await ensureSnapshotHarness();
  late AppLocalizations l;

  setUp(() async {
    l = AppLocalizations.current;
    core.settings.setTrainerApp(MyWhoosh());
    await core.settings.setLastTarget(Target.thisDevice);
  });

  testWidgets('the trainer app card names the app, and Change opens the picker', (tester) async {
    // The store renders hide the app's name; this is the real page.
    screenshotMode = false;
    addTearDown(() => screenshotMode = true);
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const TrainerConnectionSettingsPage()));
    await tester.pump();

    final card = find.byKey(const ValueKey('connection-trainer-app'));
    expect(find.descendant(of: card, matching: find.text(l.chainAppTitle)), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('MyWhoosh')), findsOneWidget);
    expect(find.byType(TrainerAppSelect), findsNothing);
    // The protocol note is a card in the page's card language, not a loose link.
    final note = find.byKey(const ValueKey('connection-obc-announcement'));
    expect(note, findsOneWidget);
    expect(find.descendant(of: note, matching: find.text(l.openBikeControlAnnouncement('MyWhoosh'))), findsOneWidget);
    // The target question in plain words, naming the same app.
    expect(find.text(l.onboardingWhereTitle('MyWhoosh')), findsOneWidget);

    await tester.tap(find.descendant(of: card, matching: find.text(l.rideChange)));
    await tester.pump();
    expect(find.byType(TrainerAppSelect), findsOneWidget);

    expect(find.text(l.recommendedConnectionMethods.toUpperCase()), findsWidgets);
    // Under that header a method doesn't repeat "Recommended" as a pill.
    expect(find.byType(ConnectionMethod), findsWidgets);
    expect(find.text(l.recommended), findsNothing);
    if (!kIsWeb) {
      expect(find.byKey(const ValueKey('connection-network-troubleshooting')), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a method card flips its method from the switch and from the card, and says when it is connected', (
    tester,
  ) async {
    // The status names the real app; the store renders hide it.
    screenshotMode = false;
    addTearDown(() => screenshotMode = true);
    final connection = _FakeConnection();
    var enabled = false;
    await tester.pumpWidget(
      _app(
        Scaffold(
          child: StatefulBuilder(
            builder: (context, setState) => ConnectionMethod(
              trainerConnection: connection,
              title: 'Direct connection',
              description: 'Lets the app connect directly.',
              isRecommended: true,
              isEnabled: enabled,
              small: false,
              requirements: const [],
              onChange: (value) => setState(() => enabled = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(enabled, isTrue);

    await tester.tap(find.text('Lets the app connect directly.'));
    await tester.pump();
    expect(enabled, isFalse);

    expect(find.byType(BkStatusDot), findsNothing);
    connection.isConnected.value = true;
    enabled = true;
    await tester.pumpWidget(
      _app(
        Scaffold(
          child: ConnectionMethod(
            trainerConnection: connection,
            title: 'Direct connection',
            description: 'Lets the app connect directly.',
            isRecommended: true,
            isEnabled: true,
            small: false,
            requirements: const [],
            onChange: (_) {},
          ),
        ),
      ),
    );
    expect(find.text(l.chainStepAppConnected('MyWhoosh')), findsOneWidget);
  });

  testWidgets('the Recommended pill only shows where no Recommended header says it already', (tester) async {
    screenshotMode = false;
    addTearDown(() => screenshotMode = true);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const title = 'Connect directly over Network';
    Widget method() => ConnectionMethod(
      trainerConnection: _FakeConnection(),
      title: title,
      description: 'Lets the app connect directly.',
      isRecommended: true,
      isEnabled: true,
      small: false,
      requirements: const [],
      onChange: (_) {},
    );

    await tester.pumpWidget(
      _app(
        Scaffold(
          child: Padding(padding: const EdgeInsets.all(16), child: method()),
        ),
      ),
    );
    expect(find.text(l.recommended), findsOneWidget);

    await tester.pumpWidget(
      _app(
        Scaffold(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: RecommendedConnectionMethods(child: method()),
          ),
        ),
      ),
    );
    expect(find.text(l.recommended), findsNothing);
    // The title gets the row: it runs right up to the switch.
    final titleRight = tester.getTopRight(find.text(title)).dx;
    final switchLeft = tester.getTopLeft(find.byType(Switch)).dx;
    expect(switchLeft - titleRight, lessThanOrEqualTo(8));
    await tester.pumpWidget(const SizedBox());
  });
}
