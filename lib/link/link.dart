import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

class WhooshLink {
  Socket? _socket;
  ServerSocket? _server;

  final ValueNotifier<bool> isConnected = ValueNotifier(false);
  final ValueNotifier<bool> isStarted = ValueNotifier(false);

  Future<void> startServer() async {
    // Create and bind server socket
    _server = await ServerSocket.bind(
      InternetAddress.anyIPv6,
      21587,
      shared: true,
      v6Only: false,
    );
    isStarted.value = true;
    if (kDebugMode) {
      print('Server started on port ${_server!.port}');
    }

    // Accept connection
    _server!.listen((Socket socket) {
      _socket = socket;
      isConnected.value = true;
      if (kDebugMode) {
        print('Client connected: ${socket.remoteAddress.address}:${socket.remotePort}');
      }

      // Listen for data from the client
      socket.listen(
        (List<int> data) {
          try {
            if (kDebugMode) {
              // TODO we could check if virtual shifting is enabled
              final message = utf8.decode(data);
              print('Received message: $message');
            }
          } catch (_) {}
        },
        onDone: () {
          print('Client disconnected: $socket');
          isConnected.value = false;
        },
      );
    });
  }

  String sendAction(InGameAction action) {
    if (!isConnected.value) {
      return 'Not connected to MyWhoosh.';
    }
    final jsonObject = switch (action) {
      InGameAction.shiftUp => {
        'MessageType': 'Controls',
        'InGameControls': {
          'GearShifting': '1',
        },
      },
      InGameAction.shiftDown => {
        'MessageType': 'Controls',
        'InGameControls': {
          'GearShifting': '-1',
        },
      },
      InGameAction.cameraAngle => {
        'MessageType': 'Controls',
        'InGameControls': {
          'CameraAngle': '1',
        },
      },
      InGameAction.emote => {
        'MessageType': 'Controls',
        'InGameControls': {
          'Emote': '1',
        },
      },
      InGameAction.uturn => {
        'MessageType': 'Controls',
        'InGameControls': {
          'UTurn': 'true',
        },
      },
      InGameAction.steering => {
        'MessageType': 'Controls',
        'InGameControls': {
          'Steering': '0',
        },
      },
      InGameAction.increaseResistance => null,
      InGameAction.decreaseResistance => null,
      InGameAction.navigateLeft => null,
      InGameAction.navigateRight => null,
      InGameAction.toggleUi => null,
    };

    if (jsonObject != null) {
      final jsonString = jsonEncode(jsonObject);
      _socket?.writeln(jsonString);
      return 'Sent action to MyWhoosh: $action';
    } else {
      return 'No action available for button: $action';
    }
  }
}
