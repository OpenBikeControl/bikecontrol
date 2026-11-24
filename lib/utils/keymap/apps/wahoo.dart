import 'package:bike_control/utils/keymap/apps/supported_app.dart';

import '../keymap.dart';

/// The Wahoo app ("Wahoo: Ride, Run, Train"; not SYSTM).
///
/// It takes no controller input and finds trainers over Bluetooth only, so
/// BikeControl is a Bluetooth trainer to it on a second device and does the
/// virtual shifting itself.
class WahooApp extends SupportedApp {
  @override
  List<(AppConnectionMethod, ConnectionSupport)> get connections => const [];

  @override
  Set<TrainerConnectionType> get virtualShiftingTransports => const {TrainerConnectionType.bluetooth};

  @override
  bool get acceptsSimulatedInput => false;

  /// Its scanner drops adverts without a local name before looking at the
  /// services.
  @override
  bool get needsNamedBluetoothTrainer => true;

  @override
  String? get officialUrl => 'https://www.wahoofitness.com/wahoo-app';

  WahooApp()
    : super(
        name: 'Wahoo App',
        packageName: 'WahooApp',
        officialIntegration: false,
        keymap: Keymap(keyPairs: []),
      );
}
