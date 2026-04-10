import 'package:bike_control/utils/keymap/apps/supported_app.dart';

import '../keymap.dart';

class OpenBikeControl extends SupportedApp {
  @override
  List<(AppConnectionMethod, ConnectionSupport)> get connections => [
    (AppConnectionMethod.obpMdns, ConnectionSupport.supported),
    (AppConnectionMethod.obpBle, ConnectionSupport.supported),
  ];

  OpenBikeControl()
    : super(
        name: 'OpenBikeControl Compatible',
        packageName: "org.openbikecontrol",
        keymap: Keymap(
          keyPairs: [],
        ),
      );
}
