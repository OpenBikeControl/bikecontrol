import 'package:bike_control/utils/keymap/apps/supported_app.dart';

import '../keymap.dart';

/// Wahoo ELEMNT trainer-app target. The ELEMNT consumes Shimano Di2 D-Fly
/// indications, so this target advertises BikeControl as a virtual Di2
/// peripheral via the [Di2Emulator] connection. The four D-Fly channels are
/// surfaced to the user as the only supported in-game actions — they're
/// assigned per-button in the Button Editor rather than baked in here, so
/// this app's keymap is intentionally empty.
class WahooElement extends SupportedApp {
  @override
  List<(AppConnectionMethod, ConnectionSupport)> get connections => [
    (AppConnectionMethod.di2Ble, ConnectionSupport.beta),
  ];

  WahooElement()
    : super(
        name: 'Wahoo ELEMNT',
        packageName: 'WahooElement',
        officialIntegration: false,
        keymap: Keymap(keyPairs: []),
      );
}
