// Task 7: composer, thanks, and email link-up steps. `_FakeSubmissionService`
// is a lightweight subclass override — no real Supabase client construction
// needed, just override the four methods the flow calls (transport-level
// faking, as in feedback_submission_service_test.dart, is overkill here since
// these widget tests only care what the flow does with the results).
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/services/feedback_prompt_service.dart';
import 'package:bike_control/services/feedback_submission_service.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:bike_control/widgets/feedback_prompt/feedback_prompt_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeSubmissionService extends FeedbackSubmissionService {
  _FakeSubmissionService({this.anonymous = true, this.shouldFail = false})
    : super(
        client: SupabaseClient(
          'https://example.test',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  bool anonymous;
  bool shouldFail;

  final List<({FeedbackSentiment sentiment, FeedbackKind kind, String body})> submitted = [];
  final List<String> emailLinkRequests = [];
  final List<String> confirmRequests = [];

  @override
  bool get isAnonymous => anonymous;

  @override
  Future<void> submit({required FeedbackSentiment sentiment, required FeedbackKind kind, required String body}) async {
    submitted.add((sentiment: sentiment, kind: kind, body: body));
    if (shouldFail) throw const FeedbackSubmissionException('boom');
  }

  @override
  Future<void> beginEmailLink(String email) async {
    emailLinkRequests.add(email);
  }

  @override
  Future<void> confirmEmailLink({required String email, required String token}) async {
    confirmRequests.add('$email:$token');
  }
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
  required FeedbackSubmissionService submissionService,
  FeedbackFlowStep initialStep = FeedbackFlowStep.composer,
  FeedbackSentiment initialSentiment = FeedbackSentiment.up,
  FeedbackKind initialKind = FeedbackKind.suggestion,
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
          submissionService: submissionService,
          initialStep: initialStep,
          initialSentiment: initialSentiment,
          initialKind: initialKind,
          onRate: onRate ?? () async {},
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('typing and sending calls submit with suggestion+up and advances to thanks', (tester) async {
    final service = await _service();
    final submission = _FakeSubmissionService(anonymous: false);
    await _pump(tester, service, submissionService: submission);
    await tester.pump();

    await tester.enterText(find.byType(TextArea), 'more gear ranges please');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('feedback-send')));
    await tester.pumpAndSettle();

    expect(submission.submitted, hasLength(1));
    expect(submission.submitted.single.sentiment, FeedbackSentiment.up);
    expect(submission.submitted.single.kind, FeedbackKind.suggestion);
    expect(submission.submitted.single.body, 'more gear ranges please');
    expect(find.byKey(const ValueKey('feedback-step-thanks')), findsOneWidget);
    expect(service.settings.getReviewCompleted(), isTrue);
  });

  testWidgets('a failed send keeps the typed text in the field and shows retry', (tester) async {
    final service = await _service();
    final submission = _FakeSubmissionService(shouldFail: true);
    await _pump(tester, service, submissionService: submission);
    await tester.pump();

    await tester.enterText(find.byType(TextArea), 'this crashed on connect');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('feedback-send')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('feedback-step-composer')), findsOneWidget);
    expect(find.text('this crashed on connect'), findsOneWidget);
    expect(find.byKey(const ValueKey('feedback-retry')), findsOneWidget);
    expect(service.settings.getReviewCompleted(), isFalse);
  });

  testWidgets('thanks step offers email link-up for an anonymous session', (tester) async {
    final service = await _service();
    final anonymous = _FakeSubmissionService(anonymous: true);
    await _pump(tester, service, submissionService: anonymous, initialStep: FeedbackFlowStep.thanks);
    await tester.pump();

    expect(find.byKey(const ValueKey('feedback-email-field')), findsOneWidget);
  });

  testWidgets('thanks step hides email link-up for a non-anonymous session', (tester) async {
    final service = await _service();
    final named = _FakeSubmissionService(anonymous: false);
    await _pump(tester, service, submissionService: named, initialStep: FeedbackFlowStep.thanks);
    await tester.pump();

    expect(find.byKey(const ValueKey('feedback-email-field')), findsNothing);
  });

  testWidgets('complaint variant sends down+complaint and hides the also-rate link', (tester) async {
    final service = await _service();
    final submission = _FakeSubmissionService(anonymous: false);
    await _pump(
      tester,
      service,
      submissionService: submission,
      initialStep: FeedbackFlowStep.composer,
      initialSentiment: FeedbackSentiment.down,
      initialKind: FeedbackKind.complaint,
    );
    await tester.pump();

    await tester.enterText(find.byType(TextArea), 'the app crashed');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('feedback-send')));
    await tester.pumpAndSettle();

    expect(submission.submitted.single.sentiment, FeedbackSentiment.down);
    expect(submission.submitted.single.kind, FeedbackKind.complaint);
    expect(find.byKey(const ValueKey('feedback-also-rate')), findsNothing);
  });

  testWidgets('suggestion variant shows the also-rate link on the thanks step', (tester) async {
    final service = await _service();
    final submission = _FakeSubmissionService(anonymous: false);
    var rateCalled = false;
    await _pump(
      tester,
      service,
      submissionService: submission,
      onRate: () async {
        rateCalled = true;
      },
    );
    await tester.pump();

    await tester.enterText(find.byType(TextArea), 'love it');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('feedback-send')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('feedback-also-rate')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('feedback-also-rate')));
    await tester.pumpAndSettle();
    expect(rateCalled, isTrue);
  });
}
