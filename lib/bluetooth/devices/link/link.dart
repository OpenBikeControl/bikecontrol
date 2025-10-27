import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

class WhooshLink {
  Socket? _socket;
  ServerSocket? _server;

  static final List<InGameAction> supportedActions = [
    InGameAction.shiftUp,
    InGameAction.shiftDown,
    InGameAction.cameraAngle,
    InGameAction.emote,
    InGameAction.uturn,
    InGameAction.steerLeft,
    InGameAction.steerRight,
  ];

  final ValueNotifier<bool> isStarted = ValueNotifier(false);
  final ValueNotifier<bool> isConnected = ValueNotifier(false);

  void stopServer() async {
    if (isStarted.value) {
      await _socket?.close();
      await _server?.close();
      isConnected.value = false;
      isStarted.value = false;
      if (kDebugMode) {
        print('Server stopped.');
      }
    }
  }

  Future<void> startServer({
    required void Function(Socket socket) onConnected,
    required void Function(Socket socket) onDisconnected,
  }) async {
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
      onConnected(socket);
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
          onDisconnected(socket);
          isConnected.value = false;
        },
      );
    });
  }

  String sendAction(InGameAction action, int? value) {
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
          'CameraAngle': '$value',
        },
      },
      InGameAction.emote => {
        'MessageType': 'Controls',
        'InGameControls': {
          'Emote': '$value',
        },
      },
      InGameAction.uturn => {
        'MessageType': 'Controls',
        'InGameControls': {
          'UTurn': 'true',
        },
      },
      InGameAction.steerLeft => {
        'MessageType': 'Controls',
        'InGameControls': {
          'Steering': '-1',
        },
      },
      InGameAction.steerRight => {
        'MessageType': 'Controls',
        'InGameControls': {
          'Steering': '1',
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
