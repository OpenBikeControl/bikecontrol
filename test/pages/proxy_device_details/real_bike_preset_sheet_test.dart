// "Like my bike": the crank + cassette sheet, and its entry under the presets.
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/models/bike_drivetrain.dart';
import 'package:bike_control/pages/proxy_device_details/drivetrain_catalog.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratios_editor_page.dart';
import 'package:bike_control/pages/proxy_device_details/real_bike_preset_sheet.dart';
import 'package:bike_control/pages/settings/virtual_shifting_settings_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../helpers/text_breaks.dart';
import '../../widget_snapshot.dart';

const _locales = ['en', 'de', 'es', 'fr', 'it', 'pl', 'zh'];

Future<void> main() async {
  await ensureSnapshotHarness();

  final device = ProxyDevice(
    BleDevice(
      deviceId: 'kickr-real-bike',
      name: 'KICKR CORE',
      services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
    ),
  )..services = [BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [])];

  FitnessBikeDefinition definition() => FitnessBikeDefinition(
        connectedDevice: device.scanResult,
        connectedDeviceServices: device.services!,
        data: ValueNotifier(''),
      );

  Future<void> showForm(
    WidgetTester tester, {
    BikeDrivetrain? initial,
    required ValueChanged<BikeDrivetrain> onApply,
    String locale = 'en',
    String name = 'real_bike_sheet',
  }) =>
      captureWidget(
        tester,
        name: '${name}_$locale',
        width: 380,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        locales: [locale],
        settle: false,
        builder: (_) => RealBikePresetForm(initial: initial, onApply: onApply, onCancel: () {}),
      );

  testWidgets('defaults to 50/34 and a Shimano 12-speed 11-34', (tester) async {
    BikeDrivetrain? applied;
    await showForm(tester, onApply: (d) => applied = d);
    await tester.tap(find.byKey(const ValueKey('real-bike-apply')));
    expect(applied, BikeDrivetrain.tryCreate([50, 34], cassettes.firstWhere((c) => c.id == 'shimano-12-11-34').cogs));
  });

  testWidgets('a 1× crank gives a 1× drivetrain', (tester) async {
    BikeDrivetrain? applied;
    await showForm(tester, onApply: (d) => applied = d);
    await tester.tap(find.byKey(const ValueKey('real-bike-crank-1× 42')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('real-bike-apply')));
    expect(applied!.chainrings, [42]);
    expect(applied!.isDouble, isFalse);
  });

  testWidgets('custom cogs: invalid text disables Apply, a valid list applies', (tester) async {
    BikeDrivetrain? applied;
    await showForm(
      tester,
      // Not a catalog cassette, so the sheet opens on custom cogs.
      initial: BikeDrivetrain.tryCreate([46, 33], [10, 12, 14, 16, 18, 21, 24, 28, 33]),
      onApply: (d) => applied = d,
      name: 'real_bike_sheet_custom',
    );
    final field = find.byKey(const ValueKey('real-bike-cogs'));
    expect(field, findsOneWidget);
    expect(find.byKey(const ValueKey('real-bike-large')), findsOneWidget);

    await tester.enterText(field, '11-60');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('real-bike-apply')));
    expect(applied, isNull);

    await tester.enterText(field, '11, 13, 15, 17');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('real-bike-apply')));
    expect(applied!.cogs, [11, 13, 15, 17]);
    expect(applied!.chainrings, [46, 33]);
  });

  for (final locale in _locales) {
    testWidgets('the sheet lays out in $locale', (tester) async {
      await showForm(tester, onApply: (_) {}, locale: locale);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('real-bike-summary')), findsOneWidget);
    });

    testWidgets('"Like my bike" under the presets never breaks mid-word ($locale)', (tester) async {
      final def = definition()..setMaxGear(24);
      await captureWidget(
        tester,
        name: 'vs_settings_real_bike_$locale',
        width: 380,
        height: 1600,
        padding: EdgeInsets.zero,
        locales: [locale],
        settle: false,
        builder: (_) => VirtualShiftingSettingsPage(definition: def, device: device),
      );
      final button = find.byKey(const ValueKey('preset-real-bike'));
      expect(button, findsOneWidget);
      final context = tester.element(button);
      final label = find.descendant(of: button, matching: find.text(AppLocalizations.of(context).presetRealBike));
      expectBreaksOnlyBetweenWords(tester, label, reason: '[$locale] Like my bike');
    });
  }

  testWidgets('matchingGearRatioPreset names the drivetrain while the curve is its own', (tester) async {
    final d = BikeDrivetrain.tryCreate([50, 34], cassettes.firstWhere((c) => c.id == 'shimano-12-11-34').cogs)!;
    late BuildContext ctx;
    await captureWidget(tester, name: 'noop', settle: false, builder: (c) {
      ctx = c;
      return const SizedBox(width: 10, height: 10);
    });
    final match = matchingGearRatioPreset(ctx, d.ratios, drivetrain: d);
    expect(match?.range, '50/34 · 11-34');
    final edited = List<double>.of(d.ratios)..[0] += 0.1;
    expect(matchingGearRatioPreset(ctx, edited, drivetrain: d), isNull);
  });
}
