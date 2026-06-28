import 'package:bike_control/utils/keymap/apps/supported_app.dart';

import '../keymap.dart';

/// Strappo (https://getstrappo.com) — officially supported via the open
/// OpenBikeControl protocol (network/mDNS and BLE). Button events are delivered
/// over the protocol, so Strappo needs no keyboard keymap.
class Strappo extends SupportedApp {
  @override
  List<(AppConnectionMethod, ConnectionSupport)> get connections => [
    (AppConnectionMethod.obpMdns, ConnectionSupport.supported),
    (AppConnectionMethod.obpBle, ConnectionSupport.supported),
  ];

  @override
  String? get logoAsset => 'assets/strappo.png';

  @override
  String? get officialUrl => 'https://getstrappo.com';

  Strappo()
    : super(
        name: 'Strappo',
        packageName: 'Strappo',
        officialIntegration: true,
        keymap: Keymap(keyPairs: []),
      );
}
