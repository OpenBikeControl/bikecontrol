// Bug 5b (usage-fixes round): `showFeedbackPromptFlow` used to switch from a
// bottom drawer to a centered dialog (`ModalContainer`) at `width >= 600`.
// Jonas wants the bottom sheet everywhere, matching the approved mockups —
// this pins that no width opens the dialog path anymore, only the drawer
// (`DrawerWrapper`), and that the gate content itself still renders.
//
// Unlike feedback_prompt_flow_test.dart (which pumps `FeedbackPromptFlow`
// directly, with no ambient route to open into), this exercises the actual
// entry point so the presentation choice itself — the part that changed —
// is under test.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/services/feedback_prompt_service.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:bike_control/widgets/feedback_prompt/feedback_prompt_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<FeedbackPromptService> _service() async {
  SharedPreferences.setMockInitialValues({});
  final settings = Settings();
  settings.prefs = await SharedPreferences.getInstance();
  return FeedbackPromptService(
    settings: settings,
    trainerConnections: [ValueNotifier(false)],
    ownsPaidTier: () => true,
  );
}

Future<BuildContext> _pumpHostAndGetContext(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    ShadcnApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        ...ShadcnLocalizations.localizationsDelegates,
        const OtherLocalizationsDelegate(),
        AppLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: Scaffold(
        child: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  await tester.pump();
  return captured;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens as a bottom drawer, never the old dialog, on a wide (desktop-sized) window', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final service = await _service();
    final context = await _pumpHostAndGetContext(tester);

    showFeedbackPromptFlow(context, service: service);
    await tester.pumpAndSettle();

    expect(find.byType(DrawerWrapper), findsOneWidget, reason: 'always the bottom drawer now, regardless of width');
    expect(find.byType(ModalContainer), findsNothing, reason: 'the centered-dialog branch was removed (Bug 5b)');
    expect(find.byKey(const ValueKey('feedback-thumbs-up')), findsOneWidget);
  });

  testWidgets('still opens as a bottom drawer on a narrow (phone-sized) window', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final service = await _service();
    final context = await _pumpHostAndGetContext(tester);

    showFeedbackPromptFlow(context, service: service);
    await tester.pumpAndSettle();

    expect(find.byType(DrawerWrapper), findsOneWidget);
    expect(find.byKey(const ValueKey('feedback-thumbs-up')), findsOneWidget);
  });
}
