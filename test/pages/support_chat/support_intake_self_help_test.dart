// When the intake choice matches an answer the help center already has, the
// form shows it inline and asks "Did this solve it?" — Yes closes the chat,
// No continues to the composer with the same answers.
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/help_center/help_checks.dart';
import 'package:bike_control/pages/support_chat/widgets/support_intake_form.dart';
import 'package:bike_control/services/support_chat_models.dart';
import 'package:bike_control/services/support_chat_service.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/support/intake_options.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  Future<void> pump(
    WidgetTester tester,
    IntakeAnswers initial, {
    ValueChanged<IntakeAnswers>? onContinue,
    VoidCallback? onSolved,
    ProxyDevice? trainer,
    VoidCallback? onOpenPlanAccount,
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
              debugTrainer: trainer == null ? null : () => trainer,
              debugOpenPlanAccount: onOpenPlanAccount,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const notPairing = IntakeAnswers(
    category: IntakeCategory.controller,
    subcategory: 'device',
    subcategoryValue: 'zwift_click',
    symptom: 'no_pairing',
  );

  testWidgets('a matching answer shows inline with "Did this solve it?"', (tester) async {
    await pump(tester, notPairing);
    expect(find.text(l10n.helpCenterControllerNotFoundEntry), findsOneWidget);
    expect(find.byType(HelpCheckList), findsOneWidget);
    expect(find.text(l10n.supportIntakeDidThisSolveIt), findsOneWidget);
  });

  testWidgets('a Zwift controller that is not found is sent to Zwift Companion for firmware', (tester) async {
    await pump(tester, notPairing);
    expect(find.text(l10n.zwiftCompanionApp), findsOneWidget);
  });

  testWidgets('a Di2 that is not found gets no Zwift step', (tester) async {
    await pump(
      tester,
      const IntakeAnswers(
        category: IntakeCategory.controller,
        subcategory: 'device',
        subcategoryValue: 'shimano_di2',
        symptom: 'no_pairing',
      ),
    );
    expect(find.text(l10n.zwiftCompanionApp), findsNothing);
    expect(find.text(l10n.helpCheckFirmwareDi2Sub), findsOneWidget);
  });

  testWidgets('the app not reacting leads with the connection check and the network test', (tester) async {
    await pump(
      tester,
      const IntakeAnswers(
        category: IntakeCategory.trainerApp,
        subcategory: 'app',
        subcategoryValue: 'MyWhoosh',
        symptom: 'shifts_not_recognized',
      ),
    );
    expect(find.text(l10n.helpCheckAppConnectedTitle), findsOneWidget);
    final network = find.text(l10n.intakeSelfHelpNetworkAction);
    expect(network, findsOneWidget);
    expect(
      tester.getTopLeft(network).dy,
      lessThan(tester.getTopLeft(find.text(l10n.helpCheckGearOverlayTitle)).dy),
      reason: 'the connection check comes before the overlay advice',
    );
  });

  const resistance = IntakeAnswers(
    category: IntakeCategory.smartTrainer,
    subcategory: 'issue',
    subcategoryValue: 'wrong_resistance',
  );

  testWidgets('the self-test answer runs the self-test directly on a connected trainer', (tester) async {
    final trainer = ProxyDevice(BleDevice(deviceId: 't1', name: 'KICKR CORE'))..isConnected = true;
    await pump(tester, resistance, trainer: trainer);
    expect(find.byKey(const ValueKey('intake-run-self-test')), findsOneWidget);
    expect(find.text(l10n.helpSelfTestNeedsTrainer), findsNothing);
  });

  testWidgets('without a connected trainer the self-test answer says to connect it first', (tester) async {
    final trainer = ProxyDevice(BleDevice(deviceId: 't1', name: 'KICKR CORE'));
    await pump(tester, resistance, trainer: trainer);
    expect(find.byKey(const ValueKey('intake-run-self-test')), findsNothing);
    expect(find.text(l10n.helpSelfTestNeedsTrainer), findsOneWidget);
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

  IntakeAnswers account(String value) =>
      IntakeAnswers(category: IntakeCategory.account, subcategory: 'issue', subcategoryValue: value);

  for (final value in ['wrong_plan_shown', 'trial_expired_after_purchase', 'purchase_not_restored']) {
    testWidgets('$value: an inline answer whose button opens Plan & account', (tester) async {
      var opened = 0;
      await pump(tester, account(value), onOpenPlanAccount: () => opened++);
      expect(find.text(l10n.supportIntakeDidThisSolveIt), findsOneWidget);
      expect(find.byType(HelpCheckList), findsOneWidget);
      final open = find.byKey(const ValueKey('intake-open-plan-account'));
      expect(open, findsOneWidget);
      await tester.tap(open);
      expect(opened, 1);
    });
  }

  testWidgets('a refund question gets the store refund steps, not a Plan & account detour', (tester) async {
    await pump(tester, account('refund_request'));
    expect(find.text(l10n.supportIntakeDidThisSolveIt), findsOneWidget);
    expect(find.byType(HelpCheckList), findsOneWidget);
    expect(find.byKey(const ValueKey('intake-open-plan-account')), findsNothing);
  });

  testWidgets('refunds: only App Store and Microsoft Store get self-service steps; Google Play and the Windows download are mine to refund', (tester) async {
    await pump(tester, account('refund_request'));
    final steps = tester.widget<HelpCheckList>(find.byType(HelpCheckList)).checks;
    expect(steps.map((c) => c.linkUrl), ['https://reportaproblem.apple.com', 'https://account.microsoft.com/billing/orders']);
    expect(find.text(l10n.intakeSelfHelpRefundTitle), findsOneWidget);
  });

  testWidgets('after an account answer, No still continues to the composer', (tester) async {
    IntakeAnswers? continued;
    await pump(tester, account('refund_request'), onContinue: (a) => continued = a);
    await tester.tap(find.text(l10n.supportIntakeSolvedNo));
    expect(continued?.subcategoryValue, 'refund_request');
  });

  testWidgets('without a matching answer the form continues as before', (tester) async {
    await pump(tester, const IntakeAnswers(category: IntakeCategory.somethingElse));
    expect(find.text(l10n.supportIntakeDidThisSolveIt), findsNothing);
    expect(find.text(l10n.supportIntakeContinue), findsOneWidget);
  });
}
