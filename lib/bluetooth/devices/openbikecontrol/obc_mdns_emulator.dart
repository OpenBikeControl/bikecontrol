import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:mdns_dart/mdns_dart.dart';
import 'package:swift_control/bluetooth/devices/openbikecontrol/openbikecontrol_device.dart';
import 'package:swift_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:swift_control/bluetooth/devices/zwift/ftms_mdns_emulator.dart';
import 'package:swift_control/bluetooth/devices/zwift/protocol/zp.pb.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

class OpenBikeControlMdnsEmulator {
  late ServerSocket _server;
  late MDNSServer _mDNSServer;

  final ValueNotifier<bool> isStarted = ValueNotifier<bool>(false);
  final ValueNotifier<AppInfo?> isConnected = ValueNotifier<AppInfo?>(null);

  Socket? _socket;

  Future<void> startServer() async {
    print('Starting mDNS server...');

    // Get local IP
    final interfaces = await NetworkInterface.list();
    InternetAddress? localIP;

    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          localIP = addr;
          break;
        }
      }
      if (localIP != null) break;
    }

    if (localIP == null) {
      print('Could not find network interface');
      return;
    }

    _createTcpServer();

    // Create service
    final service = await MDNSService.create(
      instance: 'BikeControl',
      service: '_openbikecontrol._tcp',
      port: 36867,
      //hostName: 'KICKR BIKE SHIFT B84D.local',
      ips: [localIP],
      txt: [
        'version=1',
        'id=1337',
        'name=BikeControl',
        'service-uuids=${OpenBikeControlConstants.SERVICE_UUID}',
        'manufacturer=OpenBikeControl',
        'model=BikeControl app',
      ],
    );

    print('Service: ${service.instance} at ${localIP.address}:${service.port}');

    // Start server
    _mDNSServer = MDNSServer(
      MDNSServerConfig(
        zone: service,
        reusePort: !Platform.isAndroid,
        logger: (log) {},
      ),
    );

    try {
      await _mDNSServer.start();
      isStarted.value = true;
      print('Server started - advertising service!');
    } catch (e, s) {
      core.connection.signalNotification(AlertNotification(LogLevel.LOGLEVEL_ERROR, 'Failed to start mDNS server: $e'));
      rethrow;
    }
  }

  Future<void> stopServer() async {
    if (kDebugMode) {
      print('Stopping OpenBikeControl mDNS server...');
    }
    await _mDNSServer.stop();
    isStarted.value = false;
    isConnected.value = null;
    _socket?.destroy();
    _socket = null;
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
    if (true) {
      print('Server started on port ${_server.port}');
    }

    // Accept connection
    _server.listen(
      (Socket socket) {
        _socket = socket;

        if (kDebugMode) {
          print('Client connected: ${socket.remoteAddress.address}:${socket.remotePort}');
        }

        // Listen for data from the client
        socket.listen(
          (List<int> data) {
            print('Received message: ${bytesToHex(data)}');
            final messageType = data[0];
            switch (messageType) {
              case OpenBikeProtocolParser.MSG_TYPE_APP_INFO:
                final appInfo = OpenBikeProtocolParser.parseAppInfo(Uint8List.fromList(data));
                isConnected.value = appInfo;
                core.connection.signalNotification(
                  AlertNotification(LogLevel.LOGLEVEL_INFO, 'Connected to app: ${appInfo.appId}'),
                );
                break;
              default:
                print('Unknown message type: $messageType');
            }
          },
          onDone: () {
            core.connection.signalNotification(
              AlertNotification(LogLevel.LOGLEVEL_INFO, 'Disconnected from app: ${isConnected.value?.appId}'),
            );
            isConnected.value = null;
            _socket = null;
          },
        );
      },
    );
  }

  ActionResult sendButtonPress(List<ControllerButton> buttons) {
    if (_socket == null) {
      print('No client connected, cannot send button press');
      return Error('No client connected');
    } else if (isConnected.value == null) {
      return Error('No app info received from central');
    } else if (!isConnected.value!.supportedButtons.containsAll(buttons)) {
      return Error('App does not support all buttons: ${buttons.map((b) => b.name).join(', ')}');
    }

    final responseData = OpenBikeProtocolParser.encodeButtonState(buttons.map((b) => ButtonState(b, 1)).toList());
    _write(_socket!, responseData);
    final responseDataReleased = OpenBikeProtocolParser.encodeButtonState(
      buttons.map((b) => ButtonState(b, 0)).toList(),
    );
    _write(_socket!, responseDataReleased);
    return Success('Sent ${buttons.map((b) => b.name).join(', ')} button press');
  }

  void _write(Socket socket, List<int> responseData) {
    print('Sending response: ${bytesToHex(responseData)}');
    socket.add(responseData);
  }
}
