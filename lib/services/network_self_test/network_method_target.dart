import 'package:bike_control/bluetooth/devices/openbikecontrol/obp_mdns_backend.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/openbikecontrol_device.dart' show OpenBikeControlConstants;
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart' show ftmsEmulator;
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:prop/mdns/service_advertiser.dart';

/// Which mDNS network method the self-test examines.
enum NetworkMethodKind { openBikeControl, rouvyMdns, zwiftMdns }

/// The port prop's `ClickEmulator` binds when nothing else holds it. Mirrors
/// its private `_port`; the TCP server it creates carries the same value as
/// `preferredPort`, which is how [methodListeningCheck] tells a leaked
/// previous instance (walked one port up) from a healthy one.
const int kClickEmulatorPreferredPort = 36860;

/// The network method the self-test should examine for the selected trainer
/// app: which emulator serves it, what its TCP server is labelled, which port
/// it prefers, and how to read its state.
///
/// The troubleshooting page used to read `core.obpMdnsEmulator` regardless
/// of the app. Rouvy never speaks OpenBikeControl — its method is the Click
/// server behind `core.rouvyMdnsEmulator` — so a Rouvy rider was told the
/// method was "not started" while Rouvy was connected through it.
class NetworkMethodTarget {
  final NetworkMethodKind kind;

  /// `ResilientTcpServer.label` of the server behind the method.
  final String serverLabel;

  /// The port that server binds when nothing else holds it.
  final int preferredPort;

  final ValueListenable<bool> isStarted;
  final ValueListenable<bool> isConnected;

  const NetworkMethodTarget({
    required this.kind,
    required this.serverLabel,
    required this.preferredPort,
    required this.isStarted,
    required this.isConnected,
  });

  /// Which mDNS backend registers the method's advertisement. Only the
  /// OpenBikeControl advertisement can be handed to the OS responder (the
  /// backend pref is per-service, see [ObpMdnsBackend]); Click and DirCon
  /// always go through `ServiceAdvertiser.instance`, which is what
  /// [ObpMdnsBackend.platformDefault] denotes.
  ObpMdnsBackend get backend => switch (kind) {
    NetworkMethodKind.openBikeControl => core.obpMdnsEmulator.activeBackend,
    NetworkMethodKind.rouvyMdns || NetworkMethodKind.zwiftMdns => ObpMdnsBackend.platformDefault,
  };

  /// The hostname the method's advertisement resolves under; null when
  /// unknown (stopped, or an advertiser whose host record we cannot read
  /// back — `resolveOwnHostnameCheck` skips on null). Mirrors
  /// `OpenBikeControlMdnsEmulator.advertisedHostname` for the in-process
  /// advertiser the other two methods always register through.
  String? get advertisedHostname {
    switch (kind) {
      case NetworkMethodKind.openBikeControl:
        return core.obpMdnsEmulator.advertisedHostname;
      case NetworkMethodKind.rouvyMdns:
      case NetworkMethodKind.zwiftMdns:
        if (!isStarted.value) return null;
        final advertiser = ServiceAdvertiser.instance;
        if (advertiser is ResponderServiceAdvertiser) {
          final label = advertiser.hostLabel;
          return label == null ? null : '$label.local';
        }
        return null;
    }
  }

  /// Stops and starts the method's server — the `restartMethod` fix. Each
  /// emulator serializes its own start/stop, so a stop that has not finished
  /// tearing down is waited for by the start that follows it.
  Future<void> restart() async {
    switch (kind) {
      case NetworkMethodKind.openBikeControl:
        await core.obpMdnsEmulator.stopServer();
        await core.obpMdnsEmulator.startServer();
      case NetworkMethodKind.rouvyMdns:
        core.rouvyMdnsEmulator.stop();
        await core.rouvyMdnsEmulator.startServer();
      case NetworkMethodKind.zwiftMdns:
        core.zwiftMdnsEmulator.stop();
        await core.zwiftMdnsEmulator.startServer();
    }
  }

  /// What to tell the rider when [restart] threw.
  String get restartFailedMessage => switch (kind) {
    NetworkMethodKind.openBikeControl => AppLocalizations.current.errorStartingOpenBikeControlServer,
    NetworkMethodKind.rouvyMdns || NetworkMethodKind.zwiftMdns => AppLocalizations.current.networkFixFailed,
  };
}

/// The method [app] rides on over the network. OpenBikeControl when the app
/// lists it (the historical behaviour, and the fallback when no app is
/// selected or it has no mDNS method at all); otherwise Rouvy's Click server
/// or Zwift's DirCon server.
NetworkMethodTarget resolveNetworkMethodTarget(SupportedApp? app) {
  bool lists(AppConnectionMethod method) => app?.connections.any((c) => c.$1 == method) ?? false;

  if (lists(AppConnectionMethod.obpMdns)) return _openBikeControl;
  if (lists(AppConnectionMethod.rouvyMdns)) return _rouvyMdns;
  if (lists(AppConnectionMethod.zwiftMdns)) return _zwiftMdns;
  return _openBikeControl;
}

/// [resolveNetworkMethodTarget] for the trainer app currently selected.
NetworkMethodTarget currentNetworkMethodTarget() => resolveNetworkMethodTarget(core.settings.getTrainerApp());

NetworkMethodTarget get _openBikeControl => NetworkMethodTarget(
  kind: NetworkMethodKind.openBikeControl,
  serverLabel: 'OpenBikeControl',
  preferredPort: OpenBikeControlConstants.TCP_PORT,
  isStarted: core.obpMdnsEmulator.isStarted,
  isConnected: core.obpMdnsEmulator.isConnected,
);

NetworkMethodTarget get _rouvyMdns => NetworkMethodTarget(
  kind: NetworkMethodKind.rouvyMdns,
  serverLabel: 'Click',
  preferredPort: kClickEmulatorPreferredPort,
  isStarted: core.rouvyMdnsEmulator.isStarted,
  isConnected: core.rouvyMdnsEmulator.isConnected,
);

NetworkMethodTarget get _zwiftMdns => NetworkMethodTarget(
  kind: NetworkMethodKind.zwiftMdns,
  serverLabel: 'DirCon',
  preferredPort: ftmsEmulator.preferredPort,
  isStarted: core.zwiftMdnsEmulator.isStarted,
  isConnected: core.zwiftMdnsEmulator.isConnected,
);
