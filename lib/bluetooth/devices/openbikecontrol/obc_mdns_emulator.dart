import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/openbikecontrol/obc_bike_definition.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/openbikecontrol_device.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/apps/openbikecontrol_mdns_tile.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/mdns/service_advertiser.dart';
import 'package:prop/emulators/transporter/network_transporter.dart';
import 'package:prop/prop.dart';
import 'package:prop/utils/network_address.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide ButtonState;

class OpenBikeControlMdnsEmulator extends TrainerConnection implements OnMessage {
  /// Zwift (and other LAN exercise devices) drop the DirCon connection after
  /// ~30s without any traffic — see issue #367. While a client is connected we
  /// re-emit a neutral button-state notification well inside that window so the
  /// connection survives idle stretches (no pedalling, no button presses).
  /// This mirrors qdomyos-zwift, whose DirconManager pushes a notification on a
  /// fixed timer regardless of whether the data changed.
  static const Duration keepAliveInterval = Duration(seconds: 5);

  ServerSocket? _server;
  ServiceAdvertisement? _mdnsRegistration;

  final ValueNotifier<AppInfo?> connectedApp = ValueNotifier(null);

  Socket? _socket;
  NetworkTransporter? _dirCon;
  Timer? _keepAliveTimer;

  StreamSubscription<Socket>? _streamSubscription;

  /// Test seam: when set, overrides the [NetworkTransporter] built for an
  /// incoming DirCon client. Production callers must leave this `null`.
  @visibleForTesting
  NetworkTransporter Function(Socket socket)? transporterFactory;

  OpenBikeControlMdnsEmulator()
    : super(
        title: AppLocalizations.current.connectDirectlyOverNetwork,
        type: ConnectionMethodType.openBikeControl,
        supportedActions: InGameAction.values,
      );

  bool get _useDirCon => core.settings.getTrainerApp()?.supports(AppConnectionMethod.obpDirCon) ?? false;

  Future<void> startServer() async {
    print('Starting mDNS server...');
    isStarted.value = true;

    // Policy-based pick: prefer the real LAN interface over VPN tunnels /
    // virtualization bridges / cellular CLAT / link-local adapters —
    // "first non-loopback IPv4" advertised unreachable addresses (e.g.
    // Android's 192.0.0.8 CLAT dummy address).
    final localIP = await AdvertisedAddressPicker.pick();
    if (localIP == null) {
      throw 'Could not find network interface';
    }

    await _createTcpServer();

    try {
      // Create service
      _mdnsRegistration = await ServiceAdvertiser.instance.register(
        AdvertisedService(
          name: 'BikeControl',
          type: _useDirCon ? '_wahoo-fitness-tnp._tcp' : '_openbikecontrol._tcp',
          port: 36867,
          address: localIP,
          txt: _useDirCon
              ? {
                  'ble-service-uuids': Uint8List.fromList(OpenBikeControlConstants.SERVICE_UUID.codeUnits),
                  'mac-address': Uint8List.fromList('00:11:22:33:44:55'.codeUnits),
                  'serial-number': Uint8List.fromList('1234567890'.codeUnits),
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
      print('Server started - advertising service at ${localIP.address}:36867!');
    } catch (e, s) {
      core.connection.signalNotification(AlertNotification(LogLevel.LOGLEVEL_ERROR, 'Failed to start mDNS server: $e'));
      rethrow;
    }
  }

  Future<void> stopServer() async {
    if (kDebugMode) {
      print('Stopping OpenBikeControl mDNS server...');
    }
    final reg = _mdnsRegistration;
    _mdnsRegistration = null;
    if (reg != null) {
      try {
        await reg.unregister();
      } catch (e, s) {
        debugPrint('ObcMdnsEmulator: mDNS unregister failed: $e\n$s');
      }
    }
    isStarted.value = false;
    isConnected.value = false;
    _stopKeepAlive();
    await _streamSubscription?.cancel();
    _socket?.destroy();
    _socket = null;
    await _server?.close();
    _server = null;
    connectedApp.value = null;
  }

  Future<void> _createTcpServer() async {
    try {
      _server = await ServerSocket.bind(
        InternetAddress.anyIPv6,
        36867,
        shared: true,
        v6Only: false,
      );
    } catch (e) {
      core.connection.signalNotification(AlertNotification(LogLevel.LOGLEVEL_ERROR, 'Failed to start server: $e'));
      rethrow;
    }
    if (kDebugMode) {
      print('Server started on port ${_server!.port}');
    }

    // Accept connection
    _streamSubscription = _server!.listen(
      (Socket socket) {
        if (kDebugMode) {
          print('Client connected: ${socket.remoteAddress.address}:${socket.remotePort}');
        }

        final dirCon = _useDirCon ? _makeDirConTransporter(socket) : null;
        beginSession(socket: socket, dirCon: dirCon);

        // Listen for data from the client
        socket.listen(
          (List<int> data) {
            if (kDebugMode) {
              print('Received message: ${bytesToHex(data)}');
            }
            if (dirCon != null) {
              dirCon.handleIncomingData(data);
              return;
            }
            onMessage(data);
          },
          onDone: () {
            core.connection.signalNotification(
              AlertNotification(LogLevel.LOGLEVEL_INFO, 'Disconnected from app: ${connectedApp.value?.appId}'),
            );
            endSession();
          },
        );
      },
    );
  }

  NetworkTransporter _makeDirConTransporter(Socket socket) {
    final factory = transporterFactory;
    if (factory != null) return factory(socket);
    return NetworkTransporter(socket: socket, definition: ObcBikeDefinition(onMessageCallback: this));
  }

  /// Begins a client session: records the active transport and starts pushing
  /// keepalives. Exposed for tests so the keepalive can be exercised without a
  /// real socket or mDNS registration.
  @visibleForTesting
  void beginSession({Socket? socket, NetworkTransporter? dirCon}) {
    SharedLogic.keepAlive();
    _socket = socket;
    _dirCon = dirCon;
    _startKeepAlive();
  }

  /// Tears the session down: stops keepalives and clears connection state.
  @visibleForTesting
  void endSession() {
    _stopKeepAlive();
    _dirCon = null;
    isConnected.value = false;
    connectedApp.value = null;
    _socket = null;
    SharedLogic.stopKeepAlive();
  }

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(keepAliveInterval, (_) => sendKeepAlive());
  }

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  /// Re-emits the neutral "nothing pressed" button state to keep the connection
  /// from being torn down for inactivity. An empty button-state frame is a
  /// no-op for the receiver — it never registers a phantom press — but the
  /// bytes on the wire reset the peer's inactivity watchdog.
  @visibleForTesting
  void sendKeepAlive() {
    if (_dirCon == null && _socket == null) return;
    _write(OpenBikeProtocolParser.encodeButtonState(const []));
  }

  @override
  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp}) async {
    final inGameAction = keyPair.inGameAction;

    final mappedButtons = connectedApp.value!.supportedButtons.filter(
      (supportedButton) => supportedButton.action == inGameAction,
    );

    if (inGameAction == null) {
      return Error(
        'Invalid in-game action for key pair: $keyPair',
        button: keyPair.buttons.firstOrNull,
      );
    } else if (_socket == null) {
      print('No client connected, cannot send button press');
      return Error(
        'No client connected',
        button: keyPair.buttons.firstOrNull,
      );
    } else if (connectedApp.value == null) {
      return Error(
        'No app info received from central',
        button: keyPair.buttons.firstOrNull,
      );
    } else if (mappedButtons.isEmpty) {
      return NotHandled(
        'App does not support: ${inGameAction.title}',
        button: keyPair.buttons.firstOrNull,
      );
    }

    if (isKeyDown && isKeyUp) {
      final responseDataDown = OpenBikeProtocolParser.encodeButtonState(
        mappedButtons.map((b) => ButtonState(b, 1)).toList(),
      );
      _write(responseDataDown);
      final responseDataUp = OpenBikeProtocolParser.encodeButtonState(
        mappedButtons.map((b) => ButtonState(b, 0)).toList(),
      );
      _write(responseDataUp);
    } else {
      final responseData = OpenBikeProtocolParser.encodeButtonState(
        mappedButtons.map((b) => ButtonState(b, isKeyDown ? 1 : 0)).toList(),
      );
      _write(responseData);
    }

    return Success(
      'Sent ${inGameAction.title} button press',
      button: keyPair.buttons.firstOrNull,
    );
  }

  void _write(List<int> responseData) {
    debugPrint('Sending response: ${bytesToHex(responseData)}');
    final dirCon = _dirCon;
    if (dirCon != null) {
      dirCon.sendCharacteristicNotification(OpenBikeControlConstants.BUTTON_STATE_CHARACTERISTIC_UUID, responseData);
      return;
    }
    _socket?.add(responseData);
    //_socket?.flush();
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
