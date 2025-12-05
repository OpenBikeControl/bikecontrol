import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/devices/zwift/protocol/zp.pb.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/gen/l10n.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/utils/requirements/multi.dart';

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

  Future<void> startServer() async {
    try {
      // Create and bind server socket
      _server = await ServerSocket.bind(
        InternetAddress.anyIPv6,
        21587,
        shared: true,
        v6Only: false,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Failed to start server: $e');
      }
      isConnected.value = false;
      isStarted.value = false;
      rethrow;
    }
    isStarted.value = true;
    if (kDebugMode) {
      print('Server started on port ${_server!.port}');
    }

    // Accept connection
    _server!.listen(
      (Socket socket) {
        _socket = socket;
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_INFO, AppLocalizations.current.myWhooshLinkConnected),
        );
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
      },
    );
  }

  ActionResult sendAction(InGameAction action, int? value, {required bool isKeyDown, required bool isKeyUp}) {
    if (!isKeyDown) {
      return Success('Done');
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
          'Steering': isKeyDown ? '-1' : '0',
        },
      },
      InGameAction.steerRight => {
        'MessageType': 'Controls',
        'InGameControls': {
          'Steering': isKeyDown ? '1' : '0',
        },
      },
      InGameAction.increaseResistance => null,
      InGameAction.decreaseResistance => null,
      InGameAction.navigateLeft => null,
      InGameAction.navigateRight => null,
      InGameAction.toggleUi => null,
      _ => null,
    };

    if (jsonObject != null) {
      final jsonString = jsonEncode(jsonObject);
      _socket?.writeln(jsonString);
      return Success('Sent action to MyWhoosh: $action ${value ?? ''}');
    } else {
      return Error('No action available for button: $action');
    }
  }

  bool isCompatible(Target target) {
    return kIsWeb
        ? false
        : switch (target) {
            Target.thisDevice => !Platform.isIOS,
            _ => true,
          };
  }
}
