// The gear editor's parts at phone width, with real fonts, in every locale:
// the presets on Settings → Virtual shifting, the steppers on Per-gear ratios.
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratio_presets.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratios_editor_page.dart';
import 'package:bike_control/pages/settings/virtual_shifting_settings_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../helpers/text_breaks.dart';
import '../../widget_snapshot.dart';

const _locales = ['en', 'de', 'es', 'fr', 'it', 'pl'];

Future<void> main() async {
  await ensureSnapshotHarness();

  final device = ProxyDevice(
    BleDevice(
      deviceId: 'kickr-editor',
      name: 'KICKR CORE',
      services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
    ),
  )..services = [BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [])];

  FitnessBikeDefinition definition({int gears = 24}) => FitnessBikeDefinition(
        connectedDevice: device.scanResult,
        connectedDeviceServices: device.services!,
        data: ValueNotifier(''),
      )..setMaxGear(gears);

  Future<void> show(WidgetTester tester, Widget page, String name, String locale) => captureWidget(
        tester,
        name: '${name}_$locale',
        width: 380,
        height: 1600,
        padding: EdgeInsets.zero,
        locales: [locale],
        settle: false,
        builder: (_) => page,
      );

  Future<void> showSettings(WidgetTester tester, FitnessBikeDefinition def, String locale) =>
      show(tester, VirtualShiftingSettingsPage(definition: def, device: device), 'vs_settings', locale);

  Future<void> showPerGear(WidgetTester tester, FitnessBikeDefinition def, String locale) =>
      show(tester, PerGearRatiosPage(definition: def, device: device), 'per_gear_ratios', locale);

  for (final locale in _locales) {
    testWidgets('preset chips never break a label mid-word ($locale)', (tester) async {
      final def = definition();
      await showSettings(tester, def, locale);

      final context = tester.element(find.byType(GearRatioPresetChips));
      for (final preset in gearRatioPresets(context, def.maxGear)) {
        // The config picker above can be called "Default" too.
        final label = find.descendant(of: find.byType(GearRatioPresetChips), matching: find.text(preset.label));
        expect(label, findsOneWidget, reason: preset.label);
        expectBreaksOnlyBetweenWords(tester, label, reason: '[$locale] preset "${preset.label}"');
      }
    });
  }

  for (final gears in [30, 18]) {
    testWidgets('the per-gear list says how many gears it lists ($gears gears)', (tester) async {
      await showPerGear(tester, definition(gears: gears), 'en');

      final l10n = AppLocalizations.of(tester.element(find.byType(PerGearRatiosPage)));
      final header = find.ancestor(of: find.text(l10n.perGearLabel), matching: find.byType(Row)).first;
      expect(find.descendant(of: header, matching: find.textContaining('$gears')), findsOneWidget,
          reason: 'the per-gear header should count $gears gears');
    });
  }

  testWidgets('every tap target on the per-gear page is labelled', (tester) async {
    final handle = tester.ensureSemantics();
    await showPerGear(tester, definition(gears: 12), 'en');
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('every tap target on Settings → Virtual shifting is labelled', (tester) async {
    final handle = tester.ensureSemantics();
    await showSettings(tester, definition(gears: 12), 'en');
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
