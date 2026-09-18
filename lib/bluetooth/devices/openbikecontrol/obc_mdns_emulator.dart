import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/openbikecontrol/obc_bike_definition.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/obp_mdns_backend.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/openbikecontrol_device.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/services/bonjour/bonjour_service_advertiser.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/apps/openbikecontrol_mdns_tile.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/transporter/network_transporter.dart';
import 'package:prop/mdns/dnssd_service_advertiser.dart';
import 'package:prop/mdns/service_advertiser.dart';
import 'package:prop/prop.dart';
import 'package:prop/utils/self_advertisement_registry.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide ButtonState;
import 'package:prop/utils/network_address.dart';
import 'package:prop/utils/resilient_tcp_server.dart';
import 'package:prop/utils/serialized_lifecycle.dart';

class OpenBikeControlMdnsEmulator extends TrainerConnection implements OnMessage {
  ResilientTcpServer? _server;
  ServiceAdvertisement? _mdnsRegistration;
  ({String name, int port})? _registeredEntry;

  final ValueNotifier<AppInfo?> connectedApp = ValueNotifier(null);

  NetworkTransporter? _dirCon;

  /// The nsd-backed advertiser for [ObpMdnsBackend.osResponder]; lazy so the
  /// nsd plugin is only touched when the rider opted in.
  NsdServiceAdvertiser? _osAdvertiser;
  BonjourServiceAdvertiser? _bonjourAdvertiser;

  /// The backend the RUNNING registration actually resolved to. May differ
  /// from the rider's *preference* (`core.settings.getObpMdnsBackend()`):
  /// on Windows without Bonjour installed, [ObpMdnsBackend.osResponder]
  /// degrades to [ObpMdnsBackend.platformDefault] because the record ends up
  /// served by [ServiceAdvertiser.instance], not by any OS responder. Callers
  /// that want to know what is actually running (diagnostics, the
  /// hostname-resolution probe) must read this, not the raw preference.
  ObpMdnsBackend _activeBackend = ObpMdnsBackend.platformDefault;
  ObpMdnsBackend get activeBackend => _activeBackend;

  /// The concrete advertiser the RUNNING registration was made through.
  /// [advertisedHostname] reads the hostname off of this instance directly
  /// rather than re-deriving it from [_activeBackend], so the two can never
  /// disagree about which advertiser is actually serving.
  ServiceAdvertiser? _activeAdvertiser;

  /// The advertiser's [ServiceAdvertiser.advertisedAddress] we are watching for
  /// mid-session network moves, and the listener + last value that let us fire
  /// a single alert per change. Null while the server is stopped.
  ValueListenable<String?>? _watchedAddress;
  VoidCallback? _addressListener;
  String? _lastAdvertisedAddress;

  @visibleForTesting
  ServiceAdvertiser? debugAdvertiserOverride;

  /// Test seam for the Windows branch: swaps in a fake in place of a real
  /// `BonjourServiceAdvertiser()`, so "Bonjour available" can be exercised
  /// off Windows. Always called fresh (never cached) so tests can change it
  /// between calls without stale state leaking across them.
  @visibleForTesting
  BonjourServiceAdvertiser Function()? debugBonjourFactory;

  /// Test seam: overrides the effective [Platform.isWindows] check so the
  /// Windows branch of [resolveAdvertiser] can run on any host.
  @visibleForTesting
  bool Function()? debugIsWindows;

  bool get _isWindows => (debugIsWindows ?? (() => !kIsWeb && Platform.isWindows))();

  /// Resolves [requested] to the concrete advertiser that will serve the
  /// registration AND the backend that advertiser actually represents.
  ///
  /// [debugAdvertiserOverride], when set, always wins and resolves to
  /// [requested] verbatim — tests control both sides directly. Otherwise the
  /// Windows-without-Bonjour fallback resolves to
  /// [ObpMdnsBackend.platformDefault] even though [requested] was
  /// [ObpMdnsBackend.osResponder]: the MyWhoosh button cannot work without
  /// Bonjour anyway, and the record ends up served by whatever
  /// [ServiceAdvertiser.instance] is, not by an OS responder.
  @visibleForTesting
  ({ServiceAdvertiser advertiser, ObpMdnsBackend resolved}) resolveAdvertiser(ObpMdnsBackend requested) {
    final override = debugAdvertiserOverride;
    if (override != null) return (advertiser: override, resolved: requested);
    if (requested == ObpMdnsBackend.platformDefault) {
      return (advertiser: ServiceAdvertiser.instance, resolved: ObpMdnsBackend.platformDefault);
    }
    // Windows: Bonjour owns the record (spec §12) — the daemon MyWhoosh's
    // getaddrinfo actually asks. Elsewhere the OS responder is nsd. When
    // Bonjour is not installed the switch degrades to the platform default:
    // the MyWhoosh button cannot work without Bonjour anyway.
    if (_isWindows) {
      final bonjour = debugBonjourFactory != null
          ? debugBonjourFactory!()
          : (_bonjourAdvertiser ??= BonjourServiceAdvertiser());
      if (bonjour.isAvailable) {
        return (advertiser: bonjour, resolved: ObpMdnsBackend.osResponder);
      }
      return (advertiser: ServiceAdvertiser.instance, resolved: ObpMdnsBackend.platformDefault);
    }
    return (advertiser: _osAdvertiser ??= NsdServiceAdvertiser(), resolved: ObpMdnsBackend.osResponder);
  }

  /// The hostname the OBC advertisement resolves under, for diagnostics and
  /// the hostname-resolution probe. Null when unknown: stopped, web, or an
  /// advertiser whose host record we cannot read back.
  ///
  /// Only three advertisers let us know the name for sure: our own responder
  /// and the iOS dns_sd bridge (both publish the record themselves) and Bonjour on Windows, whose default host record
  /// is the machine's computer name — which is what [Platform.localHostname]
  /// returns there. The nsd backend (macOS/Android/Linux) is deliberately
  /// `null`: the OS publishes under its Bonjour LocalHostName, which is NOT
  /// gethostname() (macOS: `0891….fritz.box` vs `MacBook-Pro.local`;
  /// Android: `localhost`), so guessing would make the hostname-resolution
  /// probe fail on a perfectly healthy switch and put a wrong `host=` in the
  /// support bundle. The probe skips with 'hostname unknown' instead.
  String? get advertisedHostname {
    if (!isStarted.value) return null;
    final advertiser = _activeAdvertiser;
    if (advertiser is ResponderServiceAdvertiser || advertiser is DnsSdServiceAdvertiser) {
      final label = advertiser is ResponderServiceAdvertiser
          ? advertiser.hostLabel
          : (advertiser as DnsSdServiceAdvertiser).hostLabel;
      return label == null ? null : '$label.local';
    }
    if (advertiser is BonjourServiceAdvertiser) {
      if (kIsWeb) return null;
      return '${Platform.localHostname}.local';
    }
    return null;
  }

  OpenBikeControlMdnsEmulator()
    : super(
        title: () => AppLocalizations.current.connectDirectlyOverNetwork,
        type: ConnectionMethodType.openBikeControl,
        supportedActions: InGameAction.values,
      );

  bool get _useDirCon => core.settings.getTrainerApp()?.supports(AppConnectionMethod.obpDirCon) ?? false;

  /// [startServer] and [stopServer] each span several awaits (address pick,
  /// bind, mDNS register / unregister, socket close) and callers fire them
  /// without awaiting — the trainer-app switch stops and the enabled-method
  /// pass starts, the unlock page stops and its dispose starts, a fast double
  /// toggle. They run one at a time so the two can no longer interleave; see
  /// [SerializedLifecycle] for what that used to leave behind (here: the
  /// 36867 → 36871 walk).
  final _lifecycle = SerializedLifecycle();

  Future<void> startServer() => _lifecycle.run(_startServerNow);

  Future<void> _startServerNow() async {
    // Idempotent: a previous start's server and advertisement — one this
    // start raced, or one that failed after binding — go first, so this one
    // rebinds the preferred port with exactly one advertisement behind it.
    await _teardown();
    print('Starting mDNS server...');
    isStarted.value = true;

    // Policy-based pick: prefer the real LAN interface over VPN tunnels /
    // virtualization bridges / cellular CLAT / link-local adapters —
    // "first non-loopback IPv4" advertised unreachable addresses (e.g.
    // Android's 192.0.0.8 CLAT dummy address).
    final localIP = await AdvertisedAddressPicker.pick();
    if (localIP == null) {
      isStarted.value = false;
      throw 'Could not find network interface';
    }

    await _createTcpServer();
    // The port walks under contention (ResilientTcpServer's default fallback),
    // so advertise the ACTUAL bound port — companion apps read it from the SRV
    // record. Hardcoding 36867 here would point clients at the wrong port.
    final boundPort = _server!.boundPort;

    try {
      // Create service
      final requestedBackend = core.settings.isInitialized
          ? core.settings.getObpMdnsBackend()
          : ObpMdnsBackend.platformDefault;
      final selection = resolveAdvertiser(requestedBackend);
      _mdnsRegistration = await selection.advertiser.register(
        AdvertisedService(
          name: 'BikeControl',
          type: _useDirCon ? '_wahoo-fitness-tnp._tcp' : '_openbikecontrol._tcp',
          port: boundPort,
          address: localIP,
          txt: _useDirCon
              ? {
                  'ble-service-uuids': Uint8List.fromList(OpenBikeControlConstants.SERVICE_UUID.codeUnits),
                  'mac-address': Uint8List.fromList(BikeControlMdnsMarkers.obcMacAddress.codeUnits),
                  'serial-number': Uint8List.fromList('1234567890'.codeUnits),
                  // The mac-address is per-install now, so this constant is
                  // what marks the advertisement as ours to the WiFi scanner.
                  'manufacturer-data': Uint8List.fromList(BikeControlMdnsMarkers.manufacturerData.codeUnits),
                }
              : {
                  'version': Uint8List.fromList([0x01]),
                  'id': Uint8List.fromList('1337'.codeUnits),
                  'name': Uint8List.fromList('BikeControl'.codeUnits),
                  'service-uuids': Uint8List.fromList(OpenBikeControlConstants.SERVICE_UUID.codeUnits),
                  'manufacturer': Uint8List.fromList('OpenBikeControl'.codeUnits),
                  'model': Uint8List.fromList('BikeControl app'.codeUnits),
                },
        ),
      );
      _activeBackend = selection.resolved;
      _activeAdvertiser = selection.advertiser;
      _watchAdvertisedAddress(selection.advertiser);
      _registeredEntry = (name: 'BikeControl', port: boundPort);
      SelfAdvertisementRegistry.instance.add(name: 'BikeControl', port: boundPort);
      print('Server started - advertising service at ${localIP.address}:$boundPort!');
    } catch (e) {
      // Keep the flag honest so the UI doesn't show a phantom-running server
      // and the user can cleanly retry. Rethrown with its stack intact for
      // the caller to record.
      isStarted.value = false;
      core.connection.signalNotification(AlertNotification(LogLevel.LOGLEVEL_ERROR, 'Failed to start mDNS server: $e'));
      rethrow;
    }
  }

  /// Flips [isStarted] synchronously, so a caller that does not await (the
  /// trainer-app switch, which then decides whether to start again on the
  /// flag) observes stopped right away; the unregister and socket close
  /// complete in the returned future, queued behind any start in flight.
  Future<void> stopServer() {
    isStarted.value = false;
    return _lifecycle.run(_stopServerNow);
  }

  Future<void> _stopServerNow() async {
    if (kDebugMode) {
      print('Stopping OpenBikeControl mDNS server...');
    }
    isStarted.value = false;
    await _teardown();
  }

  /// Withdraws the advertisement and stops the server, if any, and forgets
  /// the client it served. Handles are nulled before the first await, so a
  /// teardown can never clobber a successor's. Shared by [stopServer] and —
  /// for idempotence — [startServer].
  Future<void> _teardown() async {
    final reg = _mdnsRegistration;
    _mdnsRegistration = null;
    final entry = _registeredEntry;
    _registeredEntry = null;
    final server = _server;
    _server = null;
    isConnected.value = false;
    connectedApp.value = null;
    _activeBackend = ObpMdnsBackend.platformDefault;
    _activeAdvertiser = null;
    _stopWatchingAdvertisedAddress();
    if (reg != null) {
      try {
        await reg.unregister();
      } catch (e, s) {
        recordError(e, s, context: 'ObcMdnsEmulator.unregister');
      }
    }
    if (entry != null) {
      SelfAdvertisementRegistry.instance.remove(name: entry.name, port: entry.port);
    }
    await server?.stop();
  }

  /// Watch [advertiser] for a mid-session address move (Wi-Fi switch, Ethernet
  /// unplug, DHCP renumber). The responder backend re-pins its socket and
  /// re-announces the new A record on its own; this only surfaces the change to
  /// the rider — a WARNING alert naming the address we now advertise, so a
  /// trainer app that briefly lost us is explained rather than mysterious.
  ///
  /// The initial address is the baseline, not a change, so registering fires
  /// nothing. Backends whose daemon owns the records report
  /// [ServiceAdvertiser.untrackedAddress] (a constant null), so this is inert
  /// for them.
  void _watchAdvertisedAddress(ServiceAdvertiser advertiser) {
    _stopWatchingAdvertisedAddress();
    final listenable = advertiser.advertisedAddress;
    _lastAdvertisedAddress = listenable.value;
    void onChange() {
      final next = listenable.value;
      // A drop to null is the server winding down, not a move to announce.
      if (next == null || next == _lastAdvertisedAddress) return;
      _lastAdvertisedAddress = next;
      core.connection.signalNotification(AlertNotification(
        LogLevel.LOGLEVEL_WARNING,
        'Network changed — re-advertising BikeControl at $next',
        connectionType: ConnectionMethodType.network,
      ));
    }

    listenable.addListener(onChange);
    _watchedAddress = listenable;
    _addressListener = onChange;
  }

  void _stopWatchingAdvertisedAddress() {
    final listener = _addressListener;
    if (listener != null) _watchedAddress?.removeListener(listener);
    _watchedAddress = null;
    _addressListener = null;
    _lastAdvertisedAddress = null;
  }

  /// Binds the OpenBikeControl TCP server. The preferred port is
  /// [OpenBikeControlConstants.TCP_PORT] but it walks to the next free port
  /// under contention (ResilientTcpServer's default fallback); [startServer]
  /// advertises whichever port was actually bound, so companion apps must
  /// read the port from the mDNS SRV record.
  Future<void> _createTcpServer() async {
    final server = ResilientTcpServer(
      preferredPort: OpenBikeControlConstants.TCP_PORT,
      // This emulator is the owner: a (re)start supersedes any server of ours
      // still registered — one whose stop is still closing, or one a
      // previous start lost track of — so it rebinds the preferred port
      // instead of walking past it. Only a foreign process still forces the
      // walk, and the self-test then offers the restart.
      owner: this,
      label: 'OpenBikeControl',
      onClientConnected: (socket) {
        SharedLogic.keepAlive();
        if (kDebugMode) {
          print('Client connected: ${socket.remoteAddress.address}:${socket.remotePort}');
        }
        if (_useDirCon) {
          _dirCon = NetworkTransporter(
            socket: socket,
            definition: ObcBikeDefinition(onMessageCallback: this),
          );
        }
      },
      onData: (socket, data) {
        if (kDebugMode) {
          print('Received message: ${bytesToHex(data)}');
        }
        if (_dirCon != null) {
          _dirCon!.handleIncomingData(data);
          return;
        }
        onMessage(data);
      },
      onClientDisconnected: () {
        _dirCon = null;
        SharedLogic.stopKeepAlive();
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_INFO, 'Disconnected from app: ${connectedApp.value?.appId}'),
        );
        isConnected.value = false;
        connectedApp.value = null;
      },
    );
    try {
      await server.start();
    } catch (e) {
      // A blocked fixed port (foreign holder) reaches here — reset the flag so
      // the start is honestly reported as failed and can be retried.
      isStarted.value = false;
      core.connection.signalNotification(AlertNotification(LogLevel.LOGLEVEL_ERROR, 'Failed to start server: $e'));
      rethrow;
    }
    _server = server;
    if (kDebugMode) {
      print('Server started on port ${server.boundPort}');
    }
  }

  @override
  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp}) async {
    final inGameAction = keyPair.inGameAction;

    final app = connectedApp.value;

    if (inGameAction == null) {
      return Error(
        'Invalid in-game action for key pair: $keyPair',
        button: keyPair.buttons.firstOrNull,
      );
    } else if (_server?.client == null) {
      print('No client connected, cannot send button press');
      return Error(
        'No client connected',
        button: keyPair.buttons.firstOrNull,
      );
    } else if (app == null) {
      return Error(
        'No app info received from central',
        button: keyPair.buttons.firstOrNull,
      );
    }

    final mappedButtons = app.supportedButtons.filter(
      (supportedButton) => supportedButton.action == inGameAction,
    );

    if (mappedButtons.isEmpty) {
      return NotHandled(
        'App does not support: ${inGameAction.title}',
        button: keyPair.buttons.firstOrNull,
      );
    }

    if (isKeyDown && isKeyUp) {
      final responseDataDown = OpenBikeProtocolParser.encodeButtonState(
        mappedButtons.map((b) => ButtonState(b, 1)).toList(),
      );
      _write(_server!.client!, responseDataDown);
      final responseDataUp = OpenBikeProtocolParser.encodeButtonState(
        mappedButtons.map((b) => ButtonState(b, 0)).toList(),
      );
      _write(_server!.client!, responseDataUp);
    } else {
      final responseData = OpenBikeProtocolParser.encodeButtonState(
        mappedButtons.map((b) => ButtonState(b, isKeyDown ? 1 : 0)).toList(),
      );
      _write(_server!.client!, responseData);
    }

    return Success(
      'Sent ${inGameAction.title} button press',
      button: keyPair.buttons.firstOrNull,
    );
  }

  void _write(Socket socket, List<int> responseData) {
    debugPrint('Sending response: ${bytesToHex(responseData)}');
    if (_dirCon != null) {
      _dirCon!.sendCharacteristicNotification(OpenBikeControlConstants.BUTTON_STATE_CHARACTERISTIC_UUID, responseData);
      return;
    } else {
      socket.add(responseData);
      //socket.flush();
    }
  }

  @override
  void onMessage(List<int> message) {
    if (kDebugMode) {
      print('Received message from OBC: ${bytesToHex(message)}');
    }
    final messageType = message[0];
    switch (messageType) {
      case OpenBikeProtocolParser.MSG_TYPE_APP_INFO:
        try {
          final appInfo = OpenBikeProtocolParser.parseAppInfo(Uint8List.fromList(message));
          isConnected.value = true;
          connectedApp.value = appInfo;

          supportedActions = appInfo.supportedButtons.mapNotNull((b) => b.action).toList();
          final trainerApp = core.settings.getTrainerApp();
          if (trainerApp != null) {
            unawaited(core.settings.setObpSupportedButtons(trainerApp.name, appInfo.supportedButtons));
          }
          core.connection.signalNotification(
            AlertNotification(LogLevel.LOGLEVEL_INFO, 'Connected to app: ${appInfo.appId}'),
          );
        } catch (e) {
          core.connection.signalNotification(LogNotification('Failed to parse app info: $e'));
        }
        break;
      case OpenBikeProtocolParser.MSG_TYPE_HAPTIC_FEEDBACK:
        // noop
        break;
      default:
        print('Unknown message type: $messageType');
    }
  }

  @override
  TrainerConnectionType? get virtualShiftingTransport => TrainerConnectionType.wifi;

  @override
  Widget getTile({bool small = false}) => OpenBikeControlMdnsTile(small: small);
}
