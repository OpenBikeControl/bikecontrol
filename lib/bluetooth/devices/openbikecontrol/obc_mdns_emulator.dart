import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/openbikecontrol/obc_bike_definition.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/openbikecontrol_device.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/apps/openbikecontrol_mdns_tile.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/transporter/network_transporter.dart';
import 'package:prop/mdns/service_advertiser.dart';
import 'package:prop/prop.dart';
import 'package:prop/utils/self_advertisement_registry.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide ButtonState;
import 'package:prop/utils/network_address.dart';
import 'package:prop/utils/resilient_tcp_server.dart';

class OpenBikeControlMdnsEmulator extends TrainerConnection implements OnMessage {
  ResilientTcpServer? _server;
  ServiceAdvertisement? _mdnsRegistration;
  ({String name, int port})? _registeredEntry;

  final ValueNotifier<AppInfo?> connectedApp = ValueNotifier(null);

  NetworkTransporter? _dirCon;

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
                  'mac-address': Uint8List.fromList(BikeControlMdnsMarkers.obcMacAddress.codeUnits),
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
      _registeredEntry = (name: 'BikeControl', port: 36867);
      SelfAdvertisementRegistry.instance.add(name: 'BikeControl', port: 36867);
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
        recordError(e, s, context: 'ObcMdnsEmulator.unregister');
      }
    }
    final entry = _registeredEntry;
    if (entry != null) {
      SelfAdvertisementRegistry.instance.remove(name: entry.name, port: entry.port);
      _registeredEntry = null;
    }
    isStarted.value = false;
    isConnected.value = false;
    await _server?.stop();
    _server = null;
    connectedApp.value = null;
  }

  /// OpenBikeControl is a fixed-port protocol contract (36867): companion
  /// apps may connect without reading the port from the advertisement, so
  /// there is NO port fallback here — a blocked port must fail loudly.
  Future<void> _createTcpServer() async {
    final server = ResilientTcpServer(
      preferredPort: 36867,
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

    final mappedButtons = connectedApp.value!.supportedButtons.filter(
      (supportedButton) => supportedButton.action == inGameAction,
    );

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
