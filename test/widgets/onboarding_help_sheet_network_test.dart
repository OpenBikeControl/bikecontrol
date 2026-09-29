// The onboarding help sheet's Network-troubleshooting button must dismiss
// the sheet before pushing the page (mirroring `_openSupportChat`), so the
// page does not open underneath a still-visible sheet.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/network_troubleshooting_page.dart';
import 'package:bike_control/pages/onboarding/onboarding_models.dart';
import 'package:bike_control/pages/onboarding/onboarding_sheets.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  setUp(() async {
    // Gate for the button: a trainer app that speaks OBC over mDNS, with the
    // Network method enabled.
    core.settings.setTrainerApp(MyWhoosh());
    await core.settings.setObpMdnsEnabled(true);
    // "Already connected" makes the pushed page show its refusal card instead
    // of auto-running the production engine (DebugDiagnostics.gather).
    core.obpMdnsEmulator.isConnected.value = true;
  });

  tearDown(() {
    core.obpMdnsEmulator.isConnected.value = false;
  });

  testWidgets('the Network troubleshooting button closes the sheet first, then pushes the page', (tester) async {
    bool? pageAbsentWhenClosed;
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
          child: SingleChildScrollView(
            child: Builder(
              builder: (context) => onboardingHelpSheetBody(
                context,
                step: OnboardingStep.connection,
                onClose: () => pageAbsentWhenClosed = find.byType(NetworkTroubleshootingPage).evaluate().isEmpty,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold).first));
    final button = find.widgetWithText(Button, l10n.networkTroubleshootingTitle);
    expect(button, findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.byType(NetworkTroubleshootingPage), findsOneWidget);
    expect(pageAbsentWhenClosed, isTrue, reason: 'onClose must run, and run before the page is pushed');
  });

  // "Contact support" opens the in-app chat. An external-link mark promised
  // a browser or a mail client instead.
  testWidgets('the support channel is marked as in-app, not external', (tester) async {
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
          child: SingleChildScrollView(
            child: Builder(
              builder: (context) => onboardingHelpSheetBody(context, step: OnboardingStep.done, onClose: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold).first));
    final support = find.widgetWithText(Button, l10n.onboardingHelpSupport);
    expect(support, findsOneWidget);
    expect(
      find.descendant(of: support, matching: find.byIcon(LucideIcons.externalLink)),
      findsNothing,
    );
  });
}
