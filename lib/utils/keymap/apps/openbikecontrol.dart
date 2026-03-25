import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';

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
        compatibleTargets: Target.values,
        keymap: Keymap(
          keyPairs: [],
        ),
      );
}
