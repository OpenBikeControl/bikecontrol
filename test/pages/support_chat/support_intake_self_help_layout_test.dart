// The intake's inline self-help on a phone: "Yes, all good" and "No, contact
// support" carry the same weight and each stays on one line, and every text
// in the panel reaches 4.5:1 in both themes.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/support_chat/widgets/support_intake_form.dart';
import 'package:bike_control/services/support_chat_models.dart';
import 'package:bike_control/services/support_chat_service.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/support/intake_options.dart';
import 'package:bike_control/utils/support/intake_self_help.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart' show ScreenshotTester;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/contrast.dart';
import '../../widget_snapshot.dart';

class _NoIssuesService implements SupportChatService {
  @override
  Future<List<SupportIssue>> fetchOpenIssues({
    String? problemCategory,
    Iterable<String> problemSubcategories = const [],
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _notPairing = IntakeAnswers(
  category: IntakeCategory.controller,
  subcategory: 'device',
  subcategoryValue: 'zwift_click',
  symptom: 'no_pairing',
);
const _appNotReacting = IntakeAnswers(
  category: IntakeCategory.trainerApp,
  subcategory: 'app',
  subcategoryValue: 'MyWhoosh',
  symptom: 'shifts_not_recognized',
);

Future<void> main() async {
  await ensureSnapshotHarness();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  Future<AppLocalizations> pump(
    WidgetTester tester,
    IntakeAnswers initial, {
    String locale = 'en',
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(390, 2400) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final l = await AppLocalizations.load(Locale(locale));
    addTearDown(() => AppLocalizations.load(const Locale('en')));
    await tester.pumpWidget(
      ShadcnApp(
        locale: Locale(locale),
        theme: BkTheme.build(brightness),
        scaling: BkTheme.mobileScaling,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SupportIntakeForm(
              service: _NoIssuesService(),
              initial: initial,
              onContinue: (_) {},
              onSolved: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Real fonts, so the one-line check measures what riders see.
    await tester.loadAssets();
    await tester.pumpAndSettle();
    return l;
  }

  /// Whether [text] is drawn whole on one line: its natural width fits the
  /// width it got.
  bool oneLine(WidgetTester tester, Finder text) {
    final p = tester.renderObject<RenderParagraph>(text);
    final painter = TextPainter(text: p.text, textDirection: TextDirection.ltr, textScaler: p.textScaler)..layout();
    final fits = painter.width <= p.size.width + 1 && p.size.height <= painter.height + 1;
    painter.dispose();
    return fits;
  }

  for (final locale in ['en', 'de', 'es', 'fr', 'it', 'pl']) {
    testWidgets('$locale: "Yes" and "No" carry the same weight and stay on one line at 390 px', (tester) async {
      final l = await pump(tester, _notPairing, locale: locale);
      final yes = find.text(l.supportIntakeSolvedYes);
      final no = find.text(l.supportIntakeSolvedNo);
      final yesButton = find.ancestor(of: yes, matching: find.byType(Button)).first;
      final noButton = find.ancestor(of: no, matching: find.byType(Button)).first;

      expect(tester.widget<Button>(noButton).style, tester.widget<Button>(yesButton).style);
      expect(tester.widget<Button>(noButton).style, isNot(ButtonVariance.primary));
      expect(tester.getSize(noButton).height, tester.getSize(yesButton).height);
      expect(tester.getSize(noButton).width, closeTo(tester.getSize(yesButton).width, 0.5));
      expect(oneLine(tester, yes), isTrue);
      expect(oneLine(tester, no), isTrue);
    });
  }

  for (final brightness in Brightness.values) {
    for (final (name, answers, help) in [
      ('not found', _notPairing, IntakeSelfHelp.controllerNotFound),
      ('app not reacting', _appNotReacting, IntakeSelfHelp.appNotReacting),
    ]) {
      testWidgets('${brightness.name}: the $name panel text clears 4.5:1', (tester) async {
        await pump(tester, answers, brightness: brightness);
        expectLegibleText(
          tester,
          find.byKey(ValueKey('intake-self-help-${help.name}')),
          pageBackground: BkTheme.build(brightness).colorScheme.background,
        );
      });
    }
  }
}
