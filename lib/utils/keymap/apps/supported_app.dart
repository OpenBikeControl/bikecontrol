import 'package:bike_control/utils/keymap/apps/biketerra.dart';
import 'package:bike_control/utils/keymap/apps/openbikecontrol.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/training_peaks.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/requirements/multi.dart';

import '../keymap.dart';
import 'custom_app.dart';
import 'my_whoosh.dart';

enum OpenBikeProtocolSupport {
  ble,
  network,
  dircon,
}

abstract class SupportedApp {
  final List<Target> compatibleTargets;
  final String packageName;
  final String name;
  final Keymap keymap;
  final bool supportsZwiftEmulation;
  final List<OpenBikeProtocolSupport> supportsOpenBikeProtocol;
  final bool star;

  const SupportedApp({
    required this.name,
    required this.packageName,
    required this.keymap,
    required this.compatibleTargets,
    required this.supportsZwiftEmulation,
    this.supportsOpenBikeProtocol = const [],
    this.star = false,
  });

  static final List<SupportedApp> supportedApps = [
    MyWhoosh(),
    Zwift(),
    TrainingPeaks(),
    Biketerra(),
    Rouvy(),
    OpenBikeControl(),
    CustomApp(),
  ];

  @override
  String toString() {
    return runtimeType.toString();
  }
}
