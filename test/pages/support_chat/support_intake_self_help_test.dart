// When the intake choice matches an answer the help center already has, the
// form shows it inline and asks "Did this solve it?" — Yes closes the chat,
// No continues to the composer with the same answers.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/support_chat/widgets/support_intake_form.dart';
import 'package:bike_control/services/support_chat_models.dart';
import 'package:bike_control/services/support_chat_service.dart';
import 'package:bike_control/utils/support/intake_options.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class _NoIssuesService implements SupportChatService {
  @override
  Future<List<SupportIssue>> fetchOpenIssues({
    String? problemCategory,
    Iterable<String> problemSubcategories = const [],
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = await AppLocalizations.load(const Locale('en'));

  Future<void> pump(
    WidgetTester tester,
    IntakeAnswers initial, {
    ValueChanged<IntakeAnswers>? onContinue,
    VoidCallback? onSolved,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [...ShadcnLocalizations.localizationsDelegates, AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: SingleChildScrollView(
            child: SupportIntakeForm(
              service: _NoIssuesService(),
              initial: initial,
              onContinue: onContinue ?? (_) {},
              onSolved: onSolved,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const notPairing = IntakeAnswers(category: IntakeCategory.controller, subcategory: 'device', subcategoryValue: 'zwift_click', symptom: 'no_pairing');

  testWidgets('a matching answer shows inline with "Did this solve it?"', (tester) async {
    await pump(tester, notPairing);
    expect(find.text(l10n.helpCenterControllerNotFoundEntry), findsOneWidget);
    expect(find.text(l10n.helpAnswerControllerNotFoundBody), findsOneWidget);
    expect(find.text(l10n.supportIntakeDidThisSolveIt), findsOneWidget);
  });

  testWidgets('No continues to the composer with the same answers', (tester) async {
    IntakeAnswers? continued;
    await pump(tester, notPairing, onContinue: (a) => continued = a);
    await tester.tap(find.text(l10n.supportIntakeSolvedNo));
    expect(continued?.symptom, 'no_pairing');
  });

  testWidgets('Yes closes', (tester) async {
    var solved = 0;
    await pump(tester, notPairing, onSolved: () => solved++);
    await tester.tap(find.text(l10n.supportIntakeSolvedYes));
    expect(solved, 1);
  });

  testWidgets('without a matching answer the form continues as before', (tester) async {
    await pump(tester, const IntakeAnswers(category: IntakeCategory.somethingElse));
    expect(find.text(l10n.supportIntakeDidThisSolveIt), findsNothing);
    expect(find.text(l10n.supportIntakeContinue), findsOneWidget);
  });
}
