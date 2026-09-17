import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/apps/biketerra.dart';
import 'package:bike_control/utils/keymap/apps/fulgaz.dart';
import 'package:bike_control/utils/keymap/apps/openbikecontrol.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/strappo.dart';
import 'package:bike_control/utils/keymap/apps/tacx.dart';
import 'package:bike_control/utils/keymap/apps/training_peaks.dart';
import 'package:bike_control/utils/keymap/apps/wahoo_element.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';

import '../buttons.dart';
import '../keymap.dart';
import 'custom_app.dart';
import 'my_whoosh.dart';

enum AppConnectionMethod {
  zwiftBle,
  zwiftMdns,
  rouvyMdns,
  obpBle,
  obpMdns,
  obpDirCon,
  myWhooshLink,
  local,
  remoteMouse,
  remoteKeyboard,
  di2Ble,
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

  /// Official website for this trainer app, surfaced as an external-link button
  /// next to the app in the trainer-app chooser. Null for apps without a site
  /// of their own (e.g. the generic custom app).
  String? get officialUrl => null;

  /// Slug for the bikecontrol.app `use-<controller>-with-<app>` how-to article.
  /// Apps without a dedicated page fall back to the generic guide.
  String get helpSlug => 'other-training-app';

  /// Extra mDNS TXT entries the Bridge adds to its `_wahoo-fitness-tnp._tcp`
  /// trainer advertisement while this app is selected, on top of the
  /// `mac-address` / `serial-number` / `ble-service-uuids` every advertisement
  /// carries.
  ///
  /// For apps that want to see a field of their own before they list a trainer
  /// (see [Tacx.mdnsProductId]). Values are ASCII; the caller encodes them.
  ///
  /// Scoped to the selected app on purpose: an identity a specific app needs
  /// is noise (at best) to every other one, and the emulator re-advertises on
  /// every trainer-app change, so switching apps swaps the TXT with it.
  Map<String, String> get trainerMdnsTxt => const {};

  /// Maps Zwift Click V2 actions to this app's corresponding actions.
  /// E.g. for Rouvy: {InGameAction.usePowerUp: InGameAction.pause, InGameAction.select: InGameAction.kudos}
  Map<InGameAction, InGameAction> get inGameActionsMapping => const {};

  /// Which Bridge transports this app can pick our trainer up on. Both by
  /// default; narrow it on apps that only look for trainers one way, so the
  /// picker stops offering a transport they will never find us on (see
  /// [FulGaz], which has no network trainer discovery at all).
  Set<TrainerConnectionType> get virtualShiftingTransports => const {
    TrainerConnectionType.bluetooth,
    TrainerConnectionType.wifi,
  };

  /// Whether button presses can reach this app as simulated input — keystrokes
  /// typed locally, or the Bluetooth keyboard/mouse we pair to another device.
  ///
  /// True for nearly every app: even those with no controller protocol of their
  /// own (see [Tacx]) still have keyboard shortcuts we can type into. False
  /// only where the app reads no key and no pointer input at all, so we stop
  /// offering methods that provably cannot reach it.
  bool get acceptsSimulatedInput => true;

  /// Whether button presses can reach this app at all — over a controller
  /// protocol it speaks, or as simulated input we type or click.
  ///
  /// False only for apps that read no controller input of any kind (see
  /// [FulGaz]). For those the Bridge's own virtual shifting is the whole
  /// integration, which settles three things at once: there is no connection
  /// method left to pick, so not picking one is not an error; there is no
  /// reason to run on the same device; and the one thing we can be to them is
  /// a trainer, seen from a second device.
  bool get receivesButtonEvents => connections.isNotEmpty || acceptsSimulatedInput;

  /// How many virtual gears this trainer app exposes in its shifter. Drives
  /// [FitnessBikeDefinition.maxGear] when this app is active. Default 24
  /// (Zwift's virtual shifting). Override on apps that use a different count
  /// (e.g. MyWhoosh → 30).
  int get virtualGearAmount => 24;

  /// Default OpenBikeControl supported buttons used by the ButtonEditor
  /// before (or without) a live OBP connection. Overridden by trainer-app
  /// subclasses that ship a known-good list.
  List<ControllerButton> get defaultObpSupportedButtons => const [];

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
    Strappo(),
    Tacx(),
    FulGaz(),
    BikeControl(),
    OpenBikeControl(),
    if (kDebugMode) WahooElement(),
    CustomApp(),
  ];

  @override
  String toString() {
    return runtimeType.toString();
  }
}

/// Reverse of [SupportedApp.inGameActionsMapping]: resolves an app-specific
/// action back to the Zwift controller action the emulators speak.
///
/// The forward mapping renames controller actions for the selected app — Rouvy
/// calls the Y button Kudos and the Z button Pause. Buttons are listed, stored
/// and delivered under the renamed action, so everything that reasons in
/// controller actions (the Zwift emulators' `sendAction`, and
/// [KeyPair.hasActiveAction]) has to undo the rename first.
///
/// Returns [action] unchanged when the selected app maps nothing onto it, which
/// covers both the apps without a mapping and the raw controller actions that
/// are the mapping's own keys.
InGameAction? resolveControllerAction(InGameAction? action) {
  final mapping = core.settings.getTrainerApp()?.inGameActionsMapping;
  return mapping?.entries.firstOrNullWhere((e) => e.value == action)?.key ?? action;
}
