import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';

import '../keymap.dart';

class OpenBikeControl extends SupportedApp {
  OpenBikeControl()
    : super(
        name: 'OpenBikeControl Compatible',
        packageName: "org.openbikecontrol",
        compatibleTargets: Target.values,
        supportsZwiftEmulation: false,
        supportsOpenBikeProtocol: [OpenBikeProtocolSupport.network, OpenBikeProtocolSupport.ble],
        keymap: Keymap(
          keyPairs: [],
        ),
      );
}
