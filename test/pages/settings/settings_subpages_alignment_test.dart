// Settings' own pages keep their 720 column in a wide window, but start it at
// the page's left edge under the back arrow and title — like every section of
// the shell — instead of floating it in the middle of the window.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/configuration.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratio_curve.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratios_editor_page.dart';
import 'package:bike_control/pages/settings/overlay_settings_page.dart';
import 'package:bike_control/pages/settings/virtual_shifting_settings_page.dart';
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/fake_overlay_controller.dart';
import '../../helpers/live_trainer.dart';
import '../../widget_snapshot.dart';

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
    core.settings.setTrainerApp(MyWhoosh());
    TrainerOverlayService.setForTest(FakeOverlayController());
    TrainerOverlayService.debugSupportedPlatform = true;
  });

  tearDown(() {
    TrainerOverlayService.resetForTest();
    TrainerOverlayService.debugSupportedPlatform = null;
    core.connection.devices.clear();
  });

  void expectLeftAligned(WidgetTester tester, Finder content) {
    final rect = tester.getRect(content.first);
    expect(rect.left, lessThan(40), reason: 'starts at the page edge, not centred in 1280');
    expect(rect.width, lessThanOrEqualTo(720), reason: 'keeps its column width');
  }

  testWidgets('Virtual shifting', (tester) async {
    final (:proxy, :definition) = attachLiveTrainer();
    await _pump(tester, VirtualShiftingSettingsPage(definition: definition, device: proxy));
    expectLeftAligned(tester, find.text(AppLocalizations.current.tuneGearsIntro));
  });

  testWidgets('Overlay', (tester) async {
    final (:proxy, :definition) = attachLiveTrainer();
    await _pump(tester, OverlaySettingsPage(definition: definition, device: proxy));
    expectLeftAligned(tester, find.byType(OverlayPreview));
  });

  testWidgets('Per-gear ratios', (tester) async {
    final (:proxy, :definition) = attachLiveTrainer();
    await _pump(tester, PerGearRatiosPage(definition: definition, device: proxy));
    expectLeftAligned(tester, find.byType(GearRatioCurve));
  });

  testWidgets('Connection settings', (tester) async {
    await _pump(tester, const TrainerConnectionSettingsPage());
    expectLeftAligned(tester, find.byType(ConfigurationPage));
  });
}
