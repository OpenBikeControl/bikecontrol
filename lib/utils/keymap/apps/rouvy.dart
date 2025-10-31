import 'package:swift_control/utils/keymap/apps/supported_app.dart';
import 'package:swift_control/utils/requirements/multi.dart';

import '../keymap.dart';

class Rouvy extends SupportedApp {
  Rouvy()
    : super(
        name: 'Rouvy',
        packageName: "eu.virtualtraining.rouvy.android",
        compatibleTargets: Target.values,
        keymap: Keymap(
          keyPairs: [],
        ),
      );
}
