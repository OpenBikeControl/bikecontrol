// Settings' own pages keep their 720 column in a wide window and centre it,
// with the back arrow and title inset to the same column (the shell's
// sections, by contrast, stay at the left edge).
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
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
import '../../helpers/page_column.dart';
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

  testWidgets('Virtual shifting', (tester) async {
    final (:proxy, :definition) = attachLiveTrainer();
    await _pump(tester, VirtualShiftingSettingsPage(definition: definition, device: proxy));
    expectCentredPageColumn(tester);
  });

  testWidgets('Overlay', (tester) async {
    final (:proxy, :definition) = attachLiveTrainer();
    await _pump(tester, OverlaySettingsPage(definition: definition, device: proxy));
    expectCentredPageColumn(tester);
  });

  testWidgets('Per-gear ratios', (tester) async {
    final (:proxy, :definition) = attachLiveTrainer();
    await _pump(tester, PerGearRatiosPage(definition: definition, device: proxy));
    expectCentredPageColumn(tester);
  });

  testWidgets('Connection settings', (tester) async {
    await _pump(tester, const TrainerConnectionSettingsPage());
    expectCentredPageColumn(tester);
  });
}
