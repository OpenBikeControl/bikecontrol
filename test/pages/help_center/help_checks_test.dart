// Help answers that are a sequence of checks are shown as numbered checks.
// "My controller isn't found" only sends Zwift controllers to Zwift
// Companion for firmware; other controllers get their own step or none.
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/help_center/help_checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l = await AppLocalizations.load(const Locale('en'));

  bool linksCompanion(List<HelpCheck> checks) => checks.any((c) => c.linkUrl == ZwiftConstants.ZWIFT_COMPANION_URL);

  group('controller not found', () {
    test('Zwift controllers get the Zwift Companion firmware step', () {
      for (final id in ['zwift_click', 'zwift_click_v2', 'zwift_play_left', 'zwift_play_right', 'zwift_ride']) {
        expect(linksCompanion(controllerNotFoundChecks(l, controllerId: id)), isTrue, reason: id);
      }
    });

    test('Di2 and SRAM AXS get their own app for firmware, not Zwift Companion', () {
      final di2 = controllerNotFoundChecks(l, controllerId: 'shimano_di2');
      expect(linksCompanion(di2), isFalse);
      expect(di2.map((c) => c.body), contains(l.helpCheckFirmwareDi2Sub));

      final axs = controllerNotFoundChecks(l, controllerId: 'sram_axs');
      expect(linksCompanion(axs), isFalse);
      expect(axs.map((c) => c.body), contains(l.helpCheckFirmwareSramSub));
    });

    test('with no controller chosen, the firmware step does not assume Zwift', () {
      final checks = controllerNotFoundChecks(l, controllerId: null);
      expect(linksCompanion(checks), isFalse);
      expect(checks.map((c) => c.body), contains(l.helpCheckFirmwareMakerSub));
    });

    test('gamepads, keyboards and phone steering skip the firmware step', () {
      for (final id in ['gamepad', 'hid_keyboard', 'gyroscope']) {
        final checks = controllerNotFoundChecks(l, controllerId: id);
        expect(checks.map((c) => c.title), isNot(contains(l.onboardingScanEmptyFirmwareTitle)), reason: id);
        expect(checks, isNotEmpty);
      }
    });
  });

  test('app not reacting: the connection check comes first', () {
    final checks = appNotReactingChecks(l);
    expect(checks.first.title, l.helpCheckAppConnectedTitle);
  });

  testWidgets('checks are numbered in order', (tester) async {
    final checks = controllerNotFoundChecks(l, controllerId: 'zwift_click');
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(child: SingleChildScrollView(child: HelpCheckList(checks: checks))),
      ),
    );
    for (var i = 0; i < checks.length; i++) {
      expect(find.text('${i + 1}'), findsOneWidget);
      expect(find.text(checks[i].title), findsOneWidget);
    }
    expect(tester.getTopLeft(find.text('1')).dy, lessThan(tester.getTopLeft(find.text('2')).dy));
    expect(find.text(l.zwiftCompanionApp), findsOneWidget);
  });
}
