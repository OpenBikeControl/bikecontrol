// Task 4: thumbs-up path — the positive step offers "rate" or "suggest",
// plus a one-shot confetti celebration behind the content. Rating never hits
// the real store API in tests: `onRate` is injected as a spy.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/services/feedback_prompt_service.dart';
import 'package:bike_control/services/feedback_submission_service.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:bike_control/widgets/feedback_prompt/confetti_burst.dart';
import 'package:bike_control/widgets/feedback_prompt/feedback_prompt_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The "suggest" button now hands off into the real composer step (Task 7),
/// which needs a [FeedbackSubmissionService] — a bare subclass is enough
/// here since these tests never reach send/submit, they only check the
/// hand-off happens at all.
class _FakeSubmissionService extends FeedbackSubmissionService {
  _FakeSubmissionService()
    : super(
        client: SupabaseClient(
          'https://example.test',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
}

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
  Future<void> Function()? onRate,
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
          submissionService: _FakeSubmissionService(),
          initialStep: FeedbackFlowStep.positive,
          onRate: onRate ?? () async {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('positive step shows rate/suggest buttons and confetti', (tester) async {
    final service = await _service();
    await _pump(tester, service);
    await tester.pump();

    expect(find.byKey(const ValueKey('feedback-rate')), findsOneWidget);
    expect(find.byKey(const ValueKey('feedback-suggest')), findsOneWidget);
    expect(find.byType(ConfettiBurst), findsOneWidget);
  });

  testWidgets('tapping rate calls onRate and marks feedback completed', (tester) async {
    final service = await _service();
    var rateCalled = false;
    await _pump(
      tester,
      service,
      onRate: () async {
        rateCalled = true;
      },
    );
    await tester.pump();

    expect(service.settings.getReviewCompleted(), isFalse);

    await tester.tap(find.byKey(const ValueKey('feedback-rate')));
    await tester.pumpAndSettle();

    expect(rateCalled, isTrue);
    expect(service.settings.getReviewCompleted(), isTrue);
  });

  testWidgets('tapping suggest switches to composer step', (tester) async {
    final service = await _service();
    await _pump(tester, service);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('feedback-suggest')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('feedback-step-composer')), findsOneWidget);
  });
}
