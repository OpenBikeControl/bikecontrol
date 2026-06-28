import 'package:bike_control/utils/keymap/apps/supported_app.dart';

import '../keymap.dart';

/// BikeControl itself as a selectable trainer app. When active, controller
/// buttons drive in-app features (e.g. the Mini Workout on the smart-trainer
/// details page) rather than being forwarded to an external app.
class BikeControl extends SupportedApp {
  @override
  String? get logoAsset => 'icon.png';

  @override
  String? get officialUrl => 'https://bikecontrol.app';

  BikeControl()
    : super(
        name: 'BikeControl',
        packageName: 'de.jonasbark.swiftcontrol',
        officialIntegration: true,
        keymap: Keymap(
          keyPairs: [],
        ),
      );
}
