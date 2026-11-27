// Task 3: gate step of the feedback prompt flow. `FeedbackPromptFlow` is
// pumped directly (not via `showFeedbackPromptFlow`), so it has no ambient
// dialog/drawer route to pop into — these tests pin the gate's contents
// (thumbs, not-now), the step transition on thumbs-down, and that the old
// star-rating language never leaks into the sentiment gate.
//
// Design round 1 dropped the negative step's "Tell me what's wrong" composer
// route: "Get help" marks feedback completed and pushes `HelpCenterPage`
// focused on "Your setup"; the negative step's own "Not now" also marks
// feedback completed (unlike the gate's, which only snoozes for 10
// sessions) — a rider who already said "having trouble" and declined help
// shouldn't be re-asked. The composer itself still supports
// `FeedbackKind.complaint` for direct callers — see
// feedback_composer_test.dart — it just isn't reachable from here anymore.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/help_center/help_center_page.dart';
import 'package:bike_control/services/feedback_prompt_service.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:bike_control/widgets/feedback_prompt/feedback_prompt_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<FeedbackPromptService> _service() async {
  SharedPreferences.setMockInitialValues({});
  final settings = Settings();
  settings.prefs = await SharedPreferences.getInstance();
  // These tests drive the sheet's UI directly; the service's eligibility
  // gates don't come into it, so this stands for a rider who owns Base/Pro.
  return FeedbackPromptService(
    settings: settings,
    trainerConnections: [ValueNotifier(false)],
    ownsPaidTier: () => true,
  );
}

Future<void> _pump(
  WidgetTester tester,
  FeedbackPromptService service, {
  FeedbackFlowStep initialStep = FeedbackFlowStep.gate,
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
        child: FeedbackPromptFlow(
          service: service,
          initialStep: initialStep,
        ),
      ),
    ),
  );
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The get-help test pushes the real HelpCenterPage, whose "Guides &
  // videos" section needs date-format locale data and a Supabase client
  // (only ever read, never hit — no session, so no request goes out).
  setUpAll(() async {
    await initializeDateFormatting();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'feedback-flow-test-anon-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  testWidgets('gate shows thumbs and not-now, tapping down goes to negative step', (tester) async {
    final service = await _service();
    await _pump(tester, service);

    expect(find.byKey(const ValueKey('feedback-thumbs-up')), findsOneWidget);
    expect(find.byKey(const ValueKey('feedback-thumbs-down')), findsOneWidget);
    expect(find.byKey(const ValueKey('feedback-not-now')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('feedback-thumbs-down')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('feedback-step-negative')), findsOneWidget);
  });

  testWidgets('tapping thumbs up goes to positive step', (tester) async {
    final service = await _service();
    await _pump(tester, service);

    await tester.tap(find.byKey(const ValueKey('feedback-thumbs-up')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('feedback-step-positive')), findsOneWidget);
  });

  testWidgets('not-now dismisses and snoozes', (tester) async {
    final service = await _service();
    await _pump(tester, service);

    expect(service.settings.getFeedbackPromptDismissedAtSessionCount(), isNull);

    await tester.tap(find.byKey(const ValueKey('feedback-not-now')));
    await tester.pumpAndSettle();

    expect(service.settings.getFeedbackPromptDismissedAtSessionCount(), isNotNull);
  });

  testWidgets('gate never contains the word rate or a star icon', (tester) async {
    final service = await _service();
    await _pump(tester, service);

    expect(find.textContaining(RegExp('rate', caseSensitive: false)), findsNothing);
    expect(find.byIcon(Icons.star_rate), findsNothing);
  });

  testWidgets('negative step shows only get-help and not-now, never mentions the store', (tester) async {
    final service = await _service();
    await _pump(tester, service, initialStep: FeedbackFlowStep.negative);

    expect(find.byKey(const ValueKey('feedback-get-help')), findsOneWidget);
    expect(find.byKey(const ValueKey('feedback-negative-not-now')), findsOneWidget);
    expect(find.byKey(const ValueKey('feedback-tell-whats-wrong')), findsNothing);
    expect(find.textContaining(RegExp('store', caseSensitive: false)), findsNothing);
  });

  testWidgets('get-help marks feedback completed and pushes Help Center focused on your setup', (tester) async {
    final service = await _service();
    await _pump(tester, service, initialStep: FeedbackFlowStep.negative);

    expect(service.settings.getReviewCompleted(), isFalse);

    await tester.tap(find.byKey(const ValueKey('feedback-get-help')));
    await tester.pumpAndSettle();

    expect(service.settings.getReviewCompleted(), isTrue);
    final helpCenterPage = tester.widget<HelpCenterPage>(find.byType(HelpCenterPage));
    expect(helpCenterPage.focus, HelpCenterFocus.yourSetup);
  });

  testWidgets('negative not-now marks feedback completed, unlike the gate it does not just snooze', (tester) async {
    final service = await _service();
    await _pump(tester, service, initialStep: FeedbackFlowStep.negative);

    expect(service.settings.getReviewCompleted(), isFalse);
    expect(service.settings.getFeedbackPromptDismissedAtSessionCount(), isNull);

    await tester.tap(find.byKey(const ValueKey('feedback-negative-not-now')));
    await tester.pumpAndSettle();

    expect(service.settings.getReviewCompleted(), isTrue);
    expect(service.settings.getFeedbackPromptDismissedAtSessionCount(), isNull);
  });
}
