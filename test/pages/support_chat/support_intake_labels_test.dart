// The intake form's options are shown in the rider's language, while the
// answers it hands on (and that support filters by) stay the stable ids.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
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

  Future<AppLocalizations> pump(WidgetTester tester, Widget child, {Locale locale = const Locale('de')}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        locale: locale,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(child: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(Scaffold)));
  }

  testWidgets('a chosen smart-trainer symptom shows its localized label', (tester) async {
    final l = await pump(
      tester,
      SupportIntakeForm(
        service: _NoIssuesService(),
        initial: const IntakeAnswers(
          category: IntakeCategory.smartTrainer,
          subcategory: 'issue',
          subcategoryValue: 'no_data',
        ),
        onContinue: (_) {},
      ),
    );
    expect(find.text(l.intakeTrainerNoData), findsOneWidget);
  });

  testWidgets('a chosen controller and symptom show their localized labels', (tester) async {
    final l = await pump(
      tester,
      SupportIntakeForm(
        service: _NoIssuesService(),
        initial: const IntakeAnswers(
          category: IntakeCategory.controller,
          subcategory: 'device',
          subcategoryValue: 'other',
          symptom: 'buttons_partial',
        ),
        onContinue: (_) {},
      ),
    );
    expect(find.text(l.intakeControllerOther), findsOneWidget);
    expect(find.text(l.intakeControllerButtonsPartial), findsOneWidget);
  });

  testWidgets('the summary chip uses the localized labels, not the ids', (tester) async {
    final l = await pump(
      tester,
      const SupportIntakeSummaryChip(
        answers: IntakeAnswers(
          category: IntakeCategory.account,
          subcategory: 'issue',
          subcategoryValue: 'refund_request',
        ),
      ),
    );
    expect(find.textContaining(l.intakeAccountRefund), findsOneWidget);
  });

  test('every option in every locale has a label, and ids are unchanged in the payload', () async {
    for (final locale in AppLocalizations.delegate.supportedLocales) {
      final l = await AppLocalizations.load(locale);
      for (final o in controllerOptions) {
        expect(controllerOptionLabel(l, o.id), isNotEmpty);
      }
      for (final (category, options) in [
        (IntakeCategory.controller, controllerSymptoms),
        (IntakeCategory.trainerApp, trainerAppSymptoms),
        (IntakeCategory.smartTrainer, smartTrainerSymptoms),
        (IntakeCategory.account, accountSymptoms),
      ]) {
        for (final o in options) {
          expect(symptomLabel(l, category, o.id), isNotEmpty, reason: '${category.id}/${o.id}');
        }
      }
    }
    const answers = IntakeAnswers(
      category: IntakeCategory.smartTrainer,
      subcategory: 'issue',
      subcategoryValue: 'wrong_resistance',
    );
    expect(answers.toJson()['subcategory_value'], 'wrong_resistance');
  });
}
