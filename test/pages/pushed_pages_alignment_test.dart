// Pushed pages keep their content column in a wide window and centre it,
// with the back arrow and title inset to the same column. The shell's
// sections stay at the left edge (app_shell_test).
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/changelog_page.dart';
import 'package:bike_control/pages/click_v2_onboarding.dart';
import 'package:bike_control/pages/network_troubleshooting_page.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/changelog/changelog_view.dart' show changelogMaxWidth;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../helpers/live_trainer.dart';
import '../helpers/page_column.dart';
import '../widget_snapshot.dart';

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(
    ShadcnApp(
      localizationsDelegates: [
        ...ShadcnLocalizations.localizationsDelegates,
        const OtherLocalizationsDelegate(),
        AppLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      theme: BkTheme.build(Brightness.dark),
      home: home,
    ),
  );
  await tester.pump();
}

Future<void> main() async {
  await ensureSnapshotHarness();

  setUp(() {
    UniversalBle.setInstance(FakeUniversalBlePlatform());
    core.actionHandler = StubActions();
  });

  tearDown(() => core.connection.devices.clear());

  testWidgets('Smart trainer', (tester) async {
    final (:proxy, definition: _) = attachLiveTrainer();
    await _pump(tester, ProxyDeviceDetailsPage(device: proxy));
    expectCentredPageColumn(tester);
  });

  testWidgets('Network troubleshooting', (tester) async {
    await _pump(tester, const NetworkTroubleshootingPage());
    expectCentredPageColumn(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('Click V2 onboarding', (tester) async {
    await _pump(tester, const ClickV2OnboardingPage());
    expectCentredPageColumn(tester, hasHeader: false);
  });

  testWidgets('Changelog', (tester) async {
    await _pump(tester, const ChangelogPage());
    expectCentredPageColumn(tester, maxWidth: changelogMaxWidth);
  });
}
