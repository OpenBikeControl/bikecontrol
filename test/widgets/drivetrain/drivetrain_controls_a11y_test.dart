import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/widgets/drivetrain/drivetrain_controls.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../widget_snapshot.dart';

// The shift buttons are drawn circles inside a ghost button: without a label a
// screen reader announced two anonymous "button"s, and the home card's
// compact circles were a 40 px target.
Future<void> main() async {
  await ensureSnapshotHarness();

  final device = ProxyDevice(
    BleDevice(
      deviceId: 'kickr-a11y',
      name: 'KICKR CORE',
      services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
    ),
  )..services = [BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [])];

  FitnessBikeDefinition definition() => FitnessBikeDefinition(
    connectedDevice: device.scanResult,
    connectedDeviceServices: device.services!,
    data: ValueNotifier(''),
  )..setMaxGear(24);

  for (final compact in [true, false]) {
    for (final width in [390.0, 900.0]) {
      testWidgets('shift buttons are labelled, >= 48 px targets (compact card: $compact, ${width.toInt()} px)', (tester) async {
        final def = definition();
        final handle = tester.ensureSemantics();
        await captureWidget(
          tester,
          name: 'drivetrain_controls_a11y',
          width: width,
          settle: false,
          builder: (_) => DrivetrainControls(definition: def, compact: compact),
        );
        final before = def.currentGear.value;
        expect(find.semantics.byLabel('Shift Up'), containsSemantics(isButton: true, hasTapAction: true));
        expect(find.semantics.byLabel('Shift Down'), containsSemantics(isButton: true, hasTapAction: true));
        tester.semantics.tap(find.semantics.byLabel('Shift Up'));
        expect(def.currentGear.value, before + 1);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }
  }
}
