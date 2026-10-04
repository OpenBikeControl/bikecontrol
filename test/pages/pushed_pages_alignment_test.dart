// Pushed pages keep their content column in a wide window but start it at
// the page's left edge under the back arrow and title — like the shell's
// sections and Settings' own pages — instead of centring it in the window.
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/click_v2_onboarding.dart';
import 'package:bike_control/pages/network_troubleshooting_page.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_page_column.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../helpers/live_trainer.dart';
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

  void expectLeftAligned(WidgetTester tester) {
    final column = find.byKey(BkPageColumn.columnKey);
    expect(column, findsOneWidget);
    final rect = tester.getRect(column);
    expect(rect.left, lessThan(40), reason: 'starts at the page edge, not centred in 1280');
    expect(rect.width, lessThanOrEqualTo(BkPageColumn.defaultMaxWidth), reason: 'keeps the page column width');
  }

  testWidgets('Smart trainer', (tester) async {
    final (:proxy, definition: _) = attachLiveTrainer();
    await _pump(tester, ProxyDeviceDetailsPage(device: proxy));
    expectLeftAligned(tester);
  });

  testWidgets('Network troubleshooting', (tester) async {
    await _pump(tester, const NetworkTroubleshootingPage());
    expectLeftAligned(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('Click V2 onboarding', (tester) async {
    await _pump(tester, const ClickV2OnboardingPage());
    expectLeftAligned(tester);
  });
}
