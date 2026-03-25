import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/biketerra.dart';
import 'package:bike_control/utils/keymap/apps/openbikecontrol.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/training_peaks.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/requirements/multi.dart';

import '../keymap.dart';
import 'custom_app.dart';
import 'my_whoosh.dart';

enum AppConnectionMethod {
  zwiftBle,
  zwiftMdns,
  obpBle,
  obpMdns,
  obpDirCon,
  myWhooshLink,
  local,
  remoteMouse,
  remoteKeyboard,
}

enum ConnectionSupport {
  supported,
  beta,
  experimental,
}

abstract class SupportedApp {
  final List<Target> compatibleTargets;
  final String packageName;
  final String name;
  final Keymap keymap;
  final List<KeyPair> additionalKeyPairs;
  final bool star;

  const SupportedApp({
    required this.name,
    required this.packageName,
    required this.keymap,
    required this.compatibleTargets,
    this.additionalKeyPairs = const [],
    this.star = false,
  });

  List<(AppConnectionMethod, ConnectionSupport)> get connections => [];

  /// Whether this app supports the given connection method.
  /// Experimental methods are excluded unless the experimental setting is enabled.
  bool supports(AppConnectionMethod method) {
    final level = supportLevel(method);
    if (level == null) return false;
    if (level == ConnectionSupport.experimental && !core.settings.getShowExperimental()) return false;
    return true;
  }

  ConnectionSupport? supportLevel(AppConnectionMethod method) {
    final match = connections.where((c) => c.$1 == method);
    return match.isEmpty ? null : match.first.$2;
  }

  bool isBeta(AppConnectionMethod method) => supportLevel(method) == ConnectionSupport.beta;

  bool isExperimental(AppConnectionMethod method) => supportLevel(method) == ConnectionSupport.experimental;

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
