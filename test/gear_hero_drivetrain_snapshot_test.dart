@Tags(['screenshots'])
library;

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/pages/proxy_device_details/gear_hero_card.dart';
import 'package:bike_control/widgets/drivetrain/drivetrain_controls.dart';
import 'package:bike_control/widgets/drivetrain/trainer_drivetrain.dart';
import 'package:bike_control/utils/core.dart' show core;
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import 'widget_snapshot.dart';

/// The gear hero with the drivetrain above the number, which is the whole
/// surface a rider watches while shifting. Run:
/// `flutter test --run-skipped test/gear_hero_drivetrain_snapshot_test.dart`
Future<void> main() async {
  await ensureSnapshotHarness();

  final proxy =
      ProxyDevice(
          BleDevice(
            name: 'Smart Trainer',
            deviceId: '00:11:22:33:44:55',
            services: [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
          ),
        )
        ..services = [BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [])]
        ..isConnected = true;

  final definition =
      FitnessBikeDefinition(
          connectedDevice: proxy.scanResult,
          connectedDeviceServices: proxy.services!,
          data: ValueNotifier(''),
        )
        ..setDebugValues()
        ..setFrontShiftEnabled(true);

  await core.shiftingConfigs.upsert(
    ShiftingConfig.defaults(trainerKey: proxy.trainerKey).copyWith(
      frontShiftEnabled: true,
      smallChainringTeeth: 34,
      largeChainringTeeth: 50,
    ),
  );

  testWidgets('GearHeroCard with the drivetrain → PNG', (tester) async {
    await captureWidget(
      tester,
      name: 'gear_hero_drivetrain',
      width: 380,
      builder: (context) => GearHeroCard(definition: definition, onEditSettings: () {}),
    );
    await captureWidget(
      tester,
      name: 'gear_hero_drivetrain_dark',
      width: 380,
      brightness: Brightness.dark,
      builder: (context) => GearHeroCard(definition: definition, onEditSettings: () {}),
    );
  });

  /// Under the plain test binding every glyph is a uniform Ahem box, so a
  /// column that drifts because Geist's "1" is narrower than its "2" measures
  /// as perfectly still. This one runs on the real font, which is the only
  /// place that drift is visible — and over both layouts, because the phone
  /// stacks the shifter and the desktop stands it beside the picture.
  testWidgets('the shifter holds its place across every gear, in both layouts', (tester) async {
    definition.setMaxGear(24);

    Future<void> show({required double screenWidth, required double cardWidth}) async {
      await tester.pumpWidget(
        ShadcnApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(size: Size(screenWidth, 900)),
            child: Scaffold(
              child: SizedBox(
                width: cardWidth,
                child: GearHeroCard(definition: definition),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.loadAssets();
      // Fonts arriving after the first layout leave intrinsic sizes measured
      // against the placeholder font cached (e.g. shadcn Tabs' IntrinsicHeight
      // clips descenders). The app loads its fonts before the first frame, so
      // re-measure everything as it would have been.
      await tester.binding.reassembleApplication();
      await tester.pump();
    }

    for (final layout in [
      (name: 'stacked (phone)', screenWidth: 400.0, cardWidth: 380.0),
      (name: 'side by side (desktop)', screenWidth: 1200.0, cardWidth: 620.0),
    ]) {
      await show(screenWidth: layout.screenWidth, cardWidth: layout.cardWidth);
      Offset? minus;
      Offset? plus;
      for (var gear = 1; gear <= 24; gear++) {
        definition.setTargetGear(gear);
        await tester.pump();
        final atMinus = tester.getCenter(find.byIcon(LucideIcons.minus));
        final atPlus = tester.getCenter(find.byIcon(LucideIcons.plus));
        minus ??= atMinus;
        plus ??= atPlus;
        // Not "close enough": a button that moves at all moves under a thumb
        // already on its way down, and the rider gets a gear they didn't ask for.
        expect(atMinus, minus, reason: 'shift-down moved on gear $gear, ${layout.name}');
        expect(atPlus, plus, reason: 'shift-up moved on gear $gear, ${layout.name}');
      }
      await tester.pump(const Duration(milliseconds: 600));
    }
  });

  testWidgets('the phone stacks the shifter, the desktop stands it beside', (tester) async {
    definition.setMaxGear(24);

    Future<void> show(double screenWidth) async {
      await tester.pumpWidget(
        ShadcnApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(size: Size(screenWidth, 900)),
            // The same card width either side of the breakpoint, so only the
            // arrangement can account for the difference.
            child: Scaffold(
              child: SizedBox(width: 380, child: GearHeroCard(definition: definition)),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Rect rectOf(Finder f) => Rect.fromPoints(tester.getTopLeft(f), tester.getBottomRight(f));

    await show(400);
    var picture = rectOf(find.byType(TrainerDrivetrain));
    var shifter = rectOf(find.byIcon(LucideIcons.minus));
    expect(shifter.top, greaterThanOrEqualTo(picture.bottom), reason: 'the phone puts the shifter below');
    final stackedHeight = rectOf(find.byType(DrivetrainControls)).height;

    await show(1200);
    picture = rectOf(find.byType(TrainerDrivetrain));
    shifter = rectOf(find.byIcon(LucideIcons.minus));
    expect(shifter.left, greaterThanOrEqualTo(picture.right), reason: 'the desktop puts it alongside');
    expect(rectOf(find.byType(DrivetrainControls)).height, lessThan(stackedHeight));

    await tester.pump(const Duration(milliseconds: 600));
  });
}
