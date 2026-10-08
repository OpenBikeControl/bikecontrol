// Task 13: entry points for the network troubleshooter. `ConnectionMethod`
// gains an optional `onTroubleshoot` callback that renders a Troubleshoot
// button in the full-card footer `Wrap` (which previously only existed when
// `instructionLink` was set) — these tests pin down its presence/absence,
// tap behavior, and style (outline while started-but-not-connected, ghost
// otherwise).
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/ui/connection_method.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../widget_snapshot.dart';

class _FakeConnection extends TrainerConnection {
  _FakeConnection() : super(title: () => 'Direct connection', type: ConnectionMethodType.network, supportedActions: const []);

  @override
  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp}) async =>
      NotHandled('', button: null);

  @override
  Widget getTile({bool small = false}) => const SizedBox.shrink();
}

const _troubleshootKey = ValueKey('connection-troubleshoot');

Future<void> _pump(
  WidgetTester tester, {
  required TrainerConnection connection,
  VoidCallback? onTroubleshoot,
}) {
  return tester.pumpWidget(
    ShadcnApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        ...ShadcnLocalizations.localizationsDelegates,
        const OtherLocalizationsDelegate(),
        AppLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: Scaffold(
        child: ConnectionMethod(
          trainerConnection: connection,
          title: 'Direct connection',
          description: 'desc',
          isRecommended: false,
          isEnabled: true,
          small: false,
          onChange: (_) {},
          requirements: const [],
          onTroubleshoot: onTroubleshoot,
        ),
      ),
    ),
  );
}

Future<void> main() async {
  await ensureSnapshotHarness();

  testWidgets('shows the Troubleshoot button and fires the callback when onTroubleshoot is set', (tester) async {
    var tapped = false;

    await _pump(tester, connection: _FakeConnection(), onTroubleshoot: () => tapped = true);
    await tester.pumpAndSettle();

    final finder = find.byKey(_troubleshootKey);
    expect(finder, findsOneWidget);

    await tester.tap(finder);
    await tester.pump();

    expect(tapped, isTrue, reason: 'tapping the Troubleshoot button should fire onTroubleshoot');
  });

  testWidgets('hides the Troubleshoot button when onTroubleshoot is null', (tester) async {
    await _pump(tester, connection: _FakeConnection(), onTroubleshoot: null);
    await tester.pumpAndSettle();

    expect(find.byKey(_troubleshootKey), findsNothing);
  });

  // The network check is a link like "Instructions" in every state — it used
  // to turn into an outlined button while waiting, which read as the next
  // step rather than a diagnostic.
  for (final (name, started, connected) in const [('waiting', true, false), ('connected', true, true)]) {
    testWidgets('is a plain link while $name', (tester) async {
      final connection = _FakeConnection()
        ..isStarted.value = started
        ..isConnected.value = connected;
      await _pump(tester, connection: connection, onTroubleshoot: () {});
      await tester.pump();
      final button = tester.widget<Button>(
        find.descendant(of: find.byKey(_troubleshootKey), matching: find.byType(Button)),
      );
      final style = button.style;
      expect(style is ButtonStyle && identical(style.variance, ButtonVariance.outline), isFalse,
          reason: 'never the outlined button');
      expect(find.descendant(of: find.byKey(_troubleshootKey), matching: find.byType(Icon)), findsNothing,
          reason: 'a text link like Instructions, no wrench');
    });
  }
}
