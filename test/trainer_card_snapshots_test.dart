@Tags(['screenshots'])
library;

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/widgets/drivetrain/drivetrain_controls.dart';
import 'package:bike_control/widgets/home/chain_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import 'widget_snapshot.dart';

/// One connection card per smart trainer, for the website's
/// /virtual-shifting-with-{trainer}/ landing pages.
///
/// The card shows the trainer's MARKETING name ("Wahoo KICKR V6"), not the
/// Bluetooth name the app really displays ("KICKR 1EB7") — deliberate, for
/// recognisability. The website's alt text says "illustrated with", never
/// implying this is a capture of a live session. Do not change the wording on
/// one side without the other.
///
/// Keep this list in sync with SMART_TRAINERS in the website's
/// src/data/trainers.ts. The website build warns for any trainer with no
/// snapshot, so a drift is visible rather than silent.
///
/// Run: flutter test --run-skipped test/trainer_card_snapshots_test.dart
const trainerNames = <String>[
  'Wahoo KICKR V4', 'Wahoo KICKR V5', 'Wahoo KICKR V6', 'Wahoo KICKR Move',
  'Wahoo KICKR Bike Shift', 'Wahoo KICKR Core 1', 'Wahoo KICKR Core 2',
  'Zwift Hub', 'Elite Direto XR', 'Elite Rivo COG', 'Elite Suito', 'Elite Justo',
  'Van Rysel D900E', 'Xplova NOVA SE', 'Tacx Neo 2T', 'Tacx Neo 3M',
  'ThinkRider X7 NEO', 'ThinkRider X5 NEO', 'ThinkRider X3 PRO', 'ThinkRider A8 Plus',
  'Wahoo KICKR Snap', 'Wahoo KICKR Rollr', 'Wahoo KICKR Bike V1', 'Wahoo KICKR Bike V2',
  'Van Rysel D900F', "BTwin In'Ride 500", 'Van Rysel HT RCR',
  'Tacx Flux 2', 'Tacx Flux S', 'Tacx Flux Smart', 'Tacx Boost',
  'Elite Avanti', 'Elite Zumo', 'Elite Volare', 'Elite Direto X',
];

/// Mirrors generateSlug() in the website's src/utils/slugUtils.ts: lowercase,
/// drop anything that is not a word character, space or hyphen, collapse
/// whitespace to single hyphens. "BTwin In'Ride 500" -> "btwin-inride-500".
String slugify(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r"[^\w\s-]"), '')
    .replaceAll(RegExp(r'\s+'), '-')
    .replaceAll(RegExp(r'-+'), '-')
    .trim();

Future<void> main() async {
  await ensureSnapshotHarness();

  for (final name in trainerNames) {
    testWidgets('trainer card: $name', (tester) async {
      final proxy =
          ProxyDevice(
              BleDevice(
                name: name,
                deviceId: '00:11:22:33:44:55',
                services: [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
              ),
            )
            ..services = [BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [])]
            ..isConnected = true;

      final definition = FitnessBikeDefinition(
        connectedDevice: proxy.scanResult,
        connectedDeviceServices: proxy.services!,
        data: ValueNotifier(''),
      )
        ..setDebugValues()
        ..setMaxGear(24)
        ..setFrontShiftEnabled(true);

      final link = ChainLink(
        key: ChainLinkKey.trainer,
        id: 'trainer',
        status: LinkStatus.ready,
        title: name,
        steps: [],
        optional: true,
      );

      await captureWidget(
        tester,
        name: 'trainer_card-${slugify(name)}',
        width: 380,
        builder: (context) => ChainCard(
          link: link,
          tile: const Icon(LucideIcons.bike, size: 22),
          title: name,
          statusLabel: 'Connected',
          editLabel: 'Edit',
          onEdit: () {},
          onTap: () {},
          body: DrivetrainControls(definition: definition, compact: true, dim: false),
        ),
      );
    });
  }
}
