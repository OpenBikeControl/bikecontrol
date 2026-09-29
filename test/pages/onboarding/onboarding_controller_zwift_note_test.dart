// A Zwift-made controller works best in Zwift. When one shows up in the
// onboarding controller list, the step says what to expect in the selected
// trainer app — and says nothing for other controllers.
import 'package:bike_control/bluetooth/devices/sram/sram_axs.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_click.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/onboarding/onboarding_models.dart';
import 'package:bike_control/pages/onboarding/steps/step_controller.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_note.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/tacx.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ensureSnapshotAppState);

  Future<void> pump(WidgetTester tester, {required List devices, required SupportedApp? app}) async {
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
              builder: (c) => onboardingControllerBody(
                c,
                phase: ControllerPhase.list,
                devices: devices.cast(),
                appName: app?.name ?? '',
                trainerApp: app,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  AppLocalizations l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(Scaffold)));

  ZwiftClick click() => ZwiftClick(BleDevice(deviceId: 'click', name: 'Zwift Click'));

  testWidgets('Zwift selected: says Zwift reads the controller natively', (tester) async {
    final device = click();
    await pump(tester, devices: [device], app: Zwift());
    final l = l10n(tester);
    final name = device.displayName(tester.element(find.byType(Scaffold)));
    expect(find.widgetWithText(OnboardingNote, l.onboardingZwiftNoteZwift(name)), findsOneWidget);
  });

  testWidgets('officially supported app: tier A note', (tester) async {
    final device = click();
    await pump(tester, devices: [device], app: MyWhoosh());
    final l = l10n(tester);
    final name = device.displayName(tester.element(find.byType(Scaffold)));
    expect(find.widgetWithText(OnboardingNote, l.onboardingZwiftNoteOfficial(name, 'MyWhoosh')), findsOneWidget);
  });

  testWidgets('other app with a keymap: lists the actions BikeControl can trigger', (tester) async {
    final device = click();
    await pump(tester, devices: [device], app: Tacx());
    final l = l10n(tester);
    final name = device.displayName(tester.element(find.byType(Scaffold)));
    final note = tester.widget<OnboardingNote>(find.byType(OnboardingNote));
    expect(note.text, startsWith(l.onboardingZwiftNoteActions(name, 'Tacx Training', '').split(':').first));
    for (final a in [InGameAction.pause, InGameAction.back, InGameAction.skipInterval]) {
      expect(note.text, contains(a.title));
    }
  });

  testWidgets('other app with no preset: explains the rider picks what each button does', (tester) async {
    final device = click();
    final app = CustomApp();
    await pump(tester, devices: [device], app: app);
    final l = l10n(tester);
    final name = device.displayName(tester.element(find.byType(Scaffold)));
    expect(find.widgetWithText(OnboardingNote, l.onboardingZwiftNoteCustom(name, app.name)), findsOneWidget);
  });

  testWidgets('non-Zwift controller: no note', (tester) async {
    await pump(
      tester,
      devices: [SramAxs(BleDevice(deviceId: 'sram', name: 'SRAM Rival AXS'))],
      app: Tacx(),
    );
    expect(find.byType(OnboardingNote), findsNothing);
  });

  testWidgets('no trainer app selected: no note', (tester) async {
    await pump(tester, devices: [click()], app: null);
    expect(find.byType(OnboardingNote), findsNothing);
  });
}
