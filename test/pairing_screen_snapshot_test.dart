@Tags(['screenshots'])
library;

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/pages/proxy.dart';
import 'package:bike_control/utils/core.dart' show core;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:universal_ble/universal_ble.dart';

import 'widget_snapshot.dart';

/// Two real moments of `ProxyPage` (`lib/pages/proxy.dart`) — the FTMS smart
/// trainer scanning/listing screen — captured separately and stacked by the
/// website tooling into one PNG for the "Pair Your Smart Trainer to
/// BikeControl" section (bikecontrol_6_6/02_connection_card.png):
///
///  1. scanning, no trainer found yet ("Looking for Smart Trainers…")
///  2. a paired Wahoo KICKR, with the live stats row `showInformation()`
///     renders for a connected proxy device.
///
/// `ProxyPage` isn't reachable from current navigation (trainers are now
/// paired via the home screen's trainer sheet, `step_trainer.dart`), but it
/// is still real, compiled, unmodified production UI — the same
/// `showInformation()`/`showMetaInformation()` code path the reachable
/// `ProxyDeviceDetailsPage` device card uses. It renders the scanning +
/// connected-list states this website section describes without dragging in
/// the Virtual Shifting demo carousel that `step_trainer.dart`'s scan card
/// always includes (which would duplicate the sibling
/// `03_virtual_shifting.jpg` image on the same page).
///
/// Run: flutter test --run-skipped test/pairing_screen_snapshot_test.dart
Future<void> main() async {
  await ensureSnapshotHarness();

  tearDown(() => core.connection.devices.clear());

  testWidgets('pairing screen: scanning for nearby trainers', (tester) async {
    core.connection.devices.clear();
    core.connection.isScanning.value = true;

    await captureWidget(
      tester,
      name: 'pairing_screen_scanning',
      width: 380,
      builder: (context) => ProxyPage(isMobile: true, onUpdate: () {}),
    );
  });

  testWidgets('pairing screen: paired Wahoo KICKR', (tester) async {
    core.connection.devices.clear();
    core.connection.isScanning.value = false;

    final trainer = ProxyDevice(
      BleDevice(
        deviceId: '00:11:22:33:44:55',
        name: 'Wahoo KICKR 1EB7',
        services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
      ),
    )
      ..services = [BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [])]
      ..isConnected = true;
    core.connection.devices.add(trainer);

    await captureWidget(
      tester,
      name: 'pairing_screen_connected',
      width: 380,
      builder: (context) => ProxyPage(isMobile: true, onUpdate: () {}),
    );
  });
}
