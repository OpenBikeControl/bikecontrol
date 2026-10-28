import 'package:bike_control/utils/keymap/apps/supported_app.dart';

import '../keymap.dart';

/// Velotoss (https://velotoss.de) — officially supported via the open
/// OpenBikeControl protocol over the network (mDNS). Button events are
/// delivered over the protocol, so Velotoss needs no keyboard keymap.
class Velotoss extends SupportedApp {
  @override
  List<(AppConnectionMethod, ConnectionSupport)> get connections => [
    (AppConnectionMethod.obpMdns, ConnectionSupport.supported),
  ];

  @override
  String? get logoAsset => 'assets/velotoss.png';

  @override
  String? get logoUrl => 'https://bikecontrol.app/images/partners/velotoss-icon.png';

  @override
  String? get officialUrl => 'https://velotoss.de';

  /// Velotoss finds trainers over Bluetooth only.
  @override
  Set<TrainerConnectionType> get virtualShiftingTransports => const {
    TrainerConnectionType.bluetooth,
  };

  Velotoss()
    : super(
        name: 'Velotoss',
        packageName: 'Velotoss',
        officialIntegration: true,
        keymap: Keymap(keyPairs: []),
      );
}
