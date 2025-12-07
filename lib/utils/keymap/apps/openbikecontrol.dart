import 'package:swift_control/utils/keymap/apps/supported_app.dart';
import 'package:swift_control/utils/requirements/multi.dart';

import '../keymap.dart';

class OpenBikeControl extends SupportedApp {
  OpenBikeControl()
    : super(
        name: 'OpenBikeControl compatible app',
        packageName: "org.openbikecontrol",
        compatibleTargets: Target.values,
        supportsZwiftEmulation: false,
        supportsOpenBikeProtocol: true,
        keymap: Keymap(
          keyPairs: [],
        ),
      );
}
