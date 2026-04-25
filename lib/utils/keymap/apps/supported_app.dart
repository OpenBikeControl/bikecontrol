import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/apps/biketerra.dart';
import 'package:bike_control/utils/keymap/apps/openbikecontrol.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/training_peaks.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';

import '../buttons.dart';
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

/// Which Bridge (virtual shifting) connection transports a trainer app can
/// actually consume. Used by the connection-mode picker on the proxy device
/// details page to disable unsupported modes with a contextual hint.
enum TrainerConnectionType { bluetooth, wifi }

abstract class SupportedApp {
  final String packageName;
  final String name;
  final Keymap keymap;
  final List<KeyPair> additionalKeyPairs;
  final bool star;
  final bool officialIntegration;

  const SupportedApp({
    required this.name,
    required this.packageName,
    required this.keymap,
    required this.officialIntegration,
    this.additionalKeyPairs = const [],
    this.star = false,
  });

  List<(AppConnectionMethod, ConnectionSupport)> get connections => [];

  /// Optional asset path for the trainer app logo (only for officially supported apps).
  String? get logoAsset => null;

  /// Maps Zwift Click V2 actions to this app's corresponding actions.
  /// E.g. for Rouvy: {InGameAction.usePowerUp: InGameAction.pause, InGameAction.select: InGameAction.kudos}
  Map<InGameAction, InGameAction> get inGameActionsMapping => const {};

  /// How many virtual gears this trainer app exposes in its shifter. Drives
  /// [FitnessBikeDefinition.maxGear] when this app is active. Default 24
  /// (Zwift's virtual shifting). Override on apps that use a different count
  /// (e.g. MyWhoosh → 30).
  int get virtualGearAmount => 24;

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
    BikeControl(),
    OpenBikeControl(),
    CustomApp(),
  ];

  @override
  String toString() {
    return runtimeType.toString();
  }
}
